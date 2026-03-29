// Intelligent Spacing System Tests
// Validates mathematical models, optical compensation and adaptive combination.
library;

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/src/layout/spacing/spacing.dart';

void main() {
  group('SpacingCalculator', () {
    test('Square-root model approximates Gould table', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.0,
      );

      // Validate against Gould table
      final errors = calculator.validateAgainstGould();

      // All errors must be < 10%
      errors.forEach((duration, errorPercent) {
        expect(
          errorPercent,
          lessThan(10.0),
          reason:
              'Duration $duration has error of ${errorPercent.toStringAsFixed(2)}%',
        );
      });
    });

    test('Notes of the same duration have identical spacing', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.5,
      );

      final shortestDuration = 0.125; // eighth note
      final quarterDuration = 0.25; // quarter note

      // calculateTeste spacing for several quarter notes
      final space1 = calculator.calculateSpace(
        quarterDuration,
        shortestDuration,
      );
      final space2 = calculator.calculateSpace(
        quarterDuration,
        shortestDuration,
      );
      final space3 = calculator.calculateSpace(
        quarterDuration,
        shortestDuration,
      );

      expect(space1, equals(space2));
      expect(space2, equals(space3));
    });

    test('Longer notes have more space', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.5,
      );

      final shortestDuration = 0.125; // eighth note
      final eighthSpace = calculator.calculateSpace(0.125, shortestDuration);
      final quarterSpace = calculator.calculateSpace(0.25, shortestDuration);
      final halfSpace = calculator.calculateSpace(0.5, shortestDuration);
      final wholeSpace = calculator.calculateSpace(1.0, shortestDuration);

      expect(quarterSpace, greaterThan(eighthSpace));
      expect(halfSpace, greaterThan(quarterSpace));
      expect(wholeSpace, greaterThan(halfSpace));
    });

    test('sqrt(2) factor between consecutive durations (square-root model)', () {
      final calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.0,
      );

      final shortestDuration = 0.125;
      final eighthSpace = calculator.calculateSpace(0.125, shortestDuration);
      final quarterSpace = calculator.calculateSpace(0.25, shortestDuration);

      // Ratio should be ≈ √2 ≈ 1.41
      final ratio = quarterSpace / eighthSpace;
      expect(ratio, closeTo(1.41, 0.05));
    });
  });

  group('OpticalCompensator', () {
    late OpticalCompensator compensator;

    setUp(() {
      compensator = OpticalCompensator(
        staffSpace: 12.0,
        enabled: true,
        intensity: 1.0,
      );
    });

    test('Alternating stems generate compensation', () {
      final prevContext = OpticalContext.note(stemUp: true, duration: 0.25);
      final currContext = OpticalContext.note(stemUp: false, duration: 0.25);

      final compensation = compensator.calculateCompensation(
        prevContext,
        currContext,
      );

      // Stem up → stem down: should push apart
      expect(compensation, greaterThan(0));
    });

    test('Rest before stem-up note generates compensation', () {
      final prevContext = OpticalContext.rest(duration: 0.25);
      final currContext = OpticalContext.note(stemUp: true, duration: 0.25);

      final compensation = compensator.calculateCompensation(
        prevContext,
        currContext,
      );

      expect(compensation, greaterThan(0));
    });

    test('Accidentals add space', () {
      final prevContext = OpticalContext.note(stemUp: true, duration: 0.25);
      final currContext = OpticalContext.note(
        stemUp: true,
        duration: 0.25,
        hasAccidental: true,
      );

      final compensation = compensator.calculateCompensation(
        prevContext,
        currContext,
      );

      expect(compensation, greaterThan(0));
    });

    test('Compensation can be disabled', () {
      final disabled = OpticalCompensator(staffSpace: 12.0, enabled: false);

      final prevContext = OpticalContext.note(stemUp: true, duration: 0.25);
      final currContext = OpticalContext.note(stemUp: false, duration: 0.25);

      final compensation = disabled.calculateCompensation(
        prevContext,
        currContext,
      );

      expect(compensation, equals(0));
    });
  });

  group('IntelligentSpacingEngine', () {
    late IntelligentSpacingEngine engine;

    setUp(() {
      engine = IntelligentSpacingEngine(preferences: SpacingPreferences.normal);
      engine.initializeOpticalCompensator(12.0);
    });

    test('Textual spacing avoids collisions', () {
      final symbols = [
        MusicalSymbolInfo(
          index: 0,
          musicalTime: 0.0,
          duration: 0.25,
          glyphWidth: 1.18,
        ),
        MusicalSymbolInfo(
          index: 1,
          musicalTime: 0.25,
          duration: 0.25,
          glyphWidth: 1.18,
        ),
      ];

      final textual = engine.computeTextualSpacing(
        symbols: symbols,
        minGap: 0.25,
        staffSpace: 12.0,
      );

      // Second note must appear after the first
      expect(textual[1].xPosition, greaterThan(textual[0].xPosition));

      // There must be a minimum gap
      final gap =
          textual[1].xPosition - (textual[0].xPosition + textual[0].width);
      expect(gap, greaterThanOrEqualTo(0.25 * 12.0));
    });

    test('Durational spacing is proportional to time', () {
      final symbols = [
        MusicalSymbolInfo(
          index: 0,
          musicalTime: 0.0,
          duration: 0.25, // quarter note
        ),
        MusicalSymbolInfo(
          index: 1,
          musicalTime: 0.25,
          duration: 0.5, // half note
        ),
      ];

      final durational = engine.computeDurationalSpacing(
        symbols: symbols,
        shortestDuration: 0.125,
        staffSpace: 12.0,
      );

      // Second note (longer duration) must have more space
      expect(durational[1].width, greaterThan(durational[0].width));
    });

    test('Adaptive combination preserves minimum widths', () {
      final symbols = List.generate(
        3,
        (i) => MusicalSymbolInfo(
          index: i,
          musicalTime: i * 0.25,
          duration: 0.25,
          glyphWidth: 1.18,
        ),
      );

      final textual = engine.computeTextualSpacing(
        symbols: symbols,
        minGap: 0.25,
        staffSpace: 12.0,
      );

      final durational = engine.computeDurationalSpacing(
        symbols: symbols,
        shortestDuration: 0.125,
        staffSpace: 12.0,
      );

      final combined = engine.combineSpacings(
        textual: textual,
        durational: durational,
        targetWidth: 500.0,
      );

      // Final width should be approximately targetWidth
      final finalWidth = combined.last.xPosition + combined.last.width;
      expect(finalWidth, closeTo(500.0, 10.0));
    });
  });

  group('SpacingPreferences', () {
    test('Presets have valid values', () {
      expect(
        SpacingPreferences.compact.spacingFactor,
        lessThan(SpacingPreferences.normal.spacingFactor),
      );
      expect(
        SpacingPreferences.normal.spacingFactor,
        lessThan(SpacingPreferences.spacious.spacingFactor),
      );
      expect(
        SpacingPreferences.spacious.spacingFactor,
        lessThan(SpacingPreferences.pedagogical.spacingFactor),
      );
    });

    test('copyWith creates new instance with modifications', () {
      final original = SpacingPreferences.normal;
      final modified = original.copyWith(spacingFactor: 2.0);

      expect(modified.spacingFactor, equals(2.0));
      expect(modified.model, equals(original.model));
      expect(original.spacingFactor, equals(1.5)); // Original not modified
    });
  });

  group('Spacing Regression Profile', () {
    late IntelligentSpacingEngine engine;

    setUp(() {
      engine = IntelligentSpacingEngine(preferences: SpacingPreferences.normal);
    });

    test('Mixed profile maintains expected density at target', () {
      final symbols = <MusicalSymbolInfo>[
        const MusicalSymbolInfo(
          index: 0,
          musicalTime: 0.0,
          duration: 0.25,
          glyphWidth: 1.2,
        ),
        const MusicalSymbolInfo(
          index: 1,
          musicalTime: 0.25,
          duration: 0.25,
          glyphWidth: 1.18,
          hasAccidental: true,
        ),
        const MusicalSymbolInfo(
          index: 2,
          musicalTime: 0.5,
          duration: 0.5,
          glyphWidth: 1.0,
          isRest: true,
        ),
        const MusicalSymbolInfo(
          index: 3,
          musicalTime: 1.0,
          duration: 0.125,
          glyphWidth: 1.18,
        ),
      ];

      final textual = engine.computeTextualSpacing(
        symbols: symbols,
        minGap: 0.25,
        staffSpace: 12.0,
      );
      final durational = engine.computeDurationalSpacing(
        symbols: symbols,
        shortestDuration: 0.125,
        staffSpace: 12.0,
      );
      final combined = engine.combineSpacings(
        textual: textual,
        durational: durational,
        targetWidth: 180.0,
      );

      // Guard-rail against subtle visual drift in spacing density.
      final totalWidth = combined.last.xPosition + combined.last.width;
      expect(totalWidth, closeTo(180.0, 0.001));

      final expectedWidths = <double>[
        46.47064087299501,
        48.03165223246735,
        50.85846990787118,
        34.63923698666647,
      ];
      final expectedX = <double>[
        0.0,
        46.47064087299501,
        94.50229310546237,
        145.36076301333355,
      ];

      for (int i = 0; i < combined.length; i++) {
        expect(combined[i].width, closeTo(expectedWidths[i], 0.001));
        expect(combined[i].xPosition, closeTo(expectedX[i], 0.001));
      }
    });
  });

  group('CollisionDetector', () {
    late CollisionDetector detector;

    setUp(() {
      detector = CollisionDetector(minSafeDistance: 2.0);
    });

    test('Detects collision between overlapping rectangles', () {
      final box1 = Rect.fromLTWH(0, 0, 10, 10);
      final box2 = Rect.fromLTWH(5, 0, 10, 10);

      expect(detector.checkCollision(box1, box2), isTrue);
    });

    test('Does not detect collision between separated rectangles', () {
      final box1 = Rect.fromLTWH(0, 0, 10, 10);
      final box2 = Rect.fromLTWH(20, 0, 10, 10);

      expect(detector.checkCollision(box1, box2), isFalse);
    });

    test('Calculates minimum required separation', () {
      final box1 = Rect.fromLTWH(0, 0, 10, 10);
      final box2 = Rect.fromLTWH(11, 0, 10, 10);

      final separation = detector.calculateMinimumSeparation(box1, box2);

      // Current gap is 1, min safe distance is 2, so required separation is 1
      expect(separation, equals(1.0));
    });
  });
}
