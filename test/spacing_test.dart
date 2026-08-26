// Intelligent Spacing System Tests.
//
// F-31 (false coverage): this file used to exercise ONLY the dual-algorithm
// experiment (computeTextualSpacing / computeDurationalSpacing /
// combineSpacings) — ~390 green lines over code the renderer never runs.
//
// It now tests the API that `LayoutEngine` actually calls:
//   * IntelligentSpacingEngine.interNoteSpacing  — the rhythmic law
//   * IntelligentSpacingEngine.durationShapeFactor
//   * IntelligentSpacingEngine.opticalAdjustment — optical compensation
//   * IntelligentSpacingEngine.analyzeMeasure    — measurement report
//
// The few remaining tests over the experiment live in a group explicitly
// labelled "ANALYSIS PATH", so nobody mistakes them for render evidence.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/core/core.dart';
import 'package:flutter_notemus/src/layout/spacing/spacing.dart';

/// One staff space, in pixels, used throughout these tests.
const double kStaffSpace = 12.0;

/// Same default as `LayoutEngine.noteMinSpacing`.
const double kBaseSpacing = IntelligentSpacingEngine.defaultBaseSpacing;

Note _note(
  DurationType type, {
  int dots = 0,
  double alter = 0.0,
  BeamType? beam,
}) {
  return Note(
    pitch: Pitch(step: 'C', octave: 5, alter: alter),
    duration: Duration(type, dots: dots),
    beam: beam,
  );
}

Rest _rest(DurationType type, {int dots = 0}) =>
    Rest(duration: Duration(type, dots: dots));

/// All 15 [DurationType] values, ordered from shortest to longest.
List<DurationType> _ascendingDurations() {
  final list = List<DurationType>.from(DurationType.values);
  list.sort((a, b) => a.value.compareTo(b.value));
  return list;
}

void main() {
  // ===========================================================================
  // PRODUCTION PATH — the law LayoutEngine calls.
  // ===========================================================================

  group('interNoteSpacing (production rhythmic law)', () {
    late IntelligentSpacingEngine engine;

    setUp(() {
      engine = IntelligentSpacingEngine(preferences: SpacingPreferences.normal);
    });

    test('a quarter note yields exactly baseSpacing * staffSpace', () {
      final spacing = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.quarter),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );

      expect(spacing, kBaseSpacing * kStaffSpace);
      expect(spacing, 42.0); // 3.5 * 12
    });

    test('a whole note yields exactly twice the quarter-note spacing', () {
      final quarter = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.quarter),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      final whole = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.whole),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );

      // sqrt(1.0 / 0.25) == 2.0 exactly.
      expect(whole, 2.0 * quarter);
    });

    test('consecutive halvings differ by exactly sqrt(2)', () {
      final quarter = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.quarter),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      final eighth = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.eighth),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );

      expect(quarter / eighth, closeTo(math.sqrt(2), 1e-12));
    });

    test('MONOTONIC across all 15 DurationType values', () {
      // Regression guard for the old lookup table: it covered only 7 durations
      // and fell back to 1.0 for the rest, so a breve was spaced like a quarter
      // (narrower than a whole note) and a 128th got MORE space than a 64th.
      final durations = _ascendingDurations();

      expect(
        durations.length,
        15,
        reason: 'MEI v5 defines 15 durations (maxima..2048th)',
      );

      double? previousSpacing;
      DurationType? previousType;

      for (final type in durations) {
        final spacing = engine.interNoteSpacing(
          previousDuration: Duration(type),
          previousIsRest: false,
          staffSpace: kStaffSpace,
        );

        expect(spacing.isFinite, isTrue, reason: '${type.name} is not finite');
        expect(
          spacing,
          greaterThan(0.0),
          reason: '${type.name} must consume space',
        );

        if (previousSpacing != null) {
          expect(
            spacing,
            greaterThan(previousSpacing),
            reason:
                '${type.name} (${type.value}) must get MORE space than '
                '${previousType!.name} (${previousType.value})',
          );
        }

        previousSpacing = spacing;
        previousType = type;
      }
    });

    test('every DurationType produces a distinct factor (no 1.0 fallback)', () {
      final factors = <double>{};
      for (final type in DurationType.values) {
        factors.add(engine.durationShapeFactor(Duration(type)));
      }
      expect(factors.length, DurationType.values.length);
    });

    test('extreme durations keep their rhythmic proportion', () {
      double spacingFor(DurationType type) => engine.interNoteSpacing(
        previousDuration: Duration(type),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );

      // breve (2 whole notes) must be wider than a whole note.
      expect(
        spacingFor(DurationType.breve),
        greaterThan(spacingFor(DurationType.whole)),
      );
      // maxima is the widest of all.
      expect(
        spacingFor(DurationType.maxima),
        greaterThan(spacingFor(DurationType.long)),
      );
      // A 128th must be NARROWER than a 64th.
      expect(
        spacingFor(DurationType.oneHundredTwentyEighth),
        lessThan(spacingFor(DurationType.sixtyFourth)),
      );
      // ...all the way down to the shortest MEI value.
      expect(
        spacingFor(DurationType.twoThousandFortyEighth),
        lessThan(spacingFor(DurationType.thousandTwentyFourth)),
      );
    });

    test('a rest is scaled by restSpacingRatio', () {
      const prefs = SpacingPreferences.normal;
      final engine = IntelligentSpacingEngine(preferences: prefs);

      final noteSpacing = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.quarter),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      final restSpacing = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.quarter),
        previousIsRest: true,
        staffSpace: kStaffSpace,
      );

      expect(restSpacing, noteSpacing * prefs.restSpacingRatio);
      expect(restSpacing, lessThan(noteSpacing));
      expect(prefs.restSpacingRatio, 0.8); // Gould's ~80%
    });

    test('restSpacingRatio is configurable', () {
      final engine = IntelligentSpacingEngine(
        preferences: SpacingPreferences.normal.copyWith(restSpacingRatio: 0.5),
      );

      final noteSpacing = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.half),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      final restSpacing = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.half),
        previousIsRest: true,
        staffSpace: kStaffSpace,
      );

      expect(restSpacing, noteSpacing * 0.5);
    });

    test('augmentation dots widen the gap', () {
      double spacingFor(int dots) => engine.interNoteSpacing(
        previousDuration: Duration(DurationType.quarter, dots: dots),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );

      expect(spacingFor(1), greaterThan(spacingFor(0)));
      expect(spacingFor(2), greaterThan(spacingFor(1)));

      // A dotted quarter is 0.375 -> sqrt(1.5) ~= 1.2247.
      expect(
        spacingFor(1),
        closeTo(kBaseSpacing * math.sqrt(1.5) * kStaffSpace, 1e-9),
      );
    });

    test('spacing is linear in staffSpace and baseSpacing', () {
      final a = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.eighth),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      final doubleStaff = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.eighth),
        previousIsRest: false,
        staffSpace: kStaffSpace * 2,
      );
      final doubleBase = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.eighth),
        previousIsRest: false,
        staffSpace: kStaffSpace,
        baseSpacing: kBaseSpacing * 2,
      );

      expect(doubleStaff, closeTo(a * 2, 1e-12));
      expect(doubleBase, closeTo(a * 2, 1e-12));
    });

    test('reproduces the LayoutEngine formula bit for bit', () {
      // This is the exact expression `_calculateRhythmicSpacing` evaluates.
      double reference(Duration duration) =>
          kBaseSpacing *
          math.sqrt(duration.absoluteValue / DurationType.quarter.value) *
          kStaffSpace;

      for (final type in DurationType.values) {
        for (final dots in const [0, 1, 2]) {
          final duration = Duration(type, dots: dots);
          expect(
            engine.interNoteSpacing(
              previousDuration: duration,
              previousIsRest: false,
              staffSpace: kStaffSpace,
            ),
            reference(duration),
            reason: 'drift on ${type.name} with $dots dot(s)',
          );
        }
      }
    });

    test('a non-squareRoot model is respected', () {
      final linear = IntelligentSpacingEngine(
        preferences: SpacingPreferences.normal.copyWith(
          model: SpacingModel.linear,
        ),
      );

      // The linear model is normalised the same way: quarter -> 1.0.
      expect(
        linear.interNoteSpacing(
          previousDuration: const Duration(DurationType.quarter),
          previousIsRest: false,
          staffSpace: kStaffSpace,
        ),
        closeTo(kBaseSpacing * kStaffSpace, 1e-12),
      );

      // ...but a whole note is NOT 2x under the linear model.
      final linearWhole = linear.interNoteSpacing(
        previousDuration: const Duration(DurationType.whole),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      final sqrtWhole = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.whole),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      expect(linearWhole, isNot(closeTo(sqrtWhole, 1e-6)));
    });

    test('spacingFactor is NOT applied twice', () {
      // The global scale lives in the caller's baseSpacing; applying
      // preferences.spacingFactor here as well would silently double it.
      final spacious = IntelligentSpacingEngine(
        preferences: SpacingPreferences.spacious,
      );

      expect(
        spacious.interNoteSpacing(
          previousDuration: const Duration(DurationType.quarter),
          previousIsRest: false,
          staffSpace: kStaffSpace,
        ),
        kBaseSpacing * kStaffSpace,
      );
    });

    test('is pure: repeated calls return identical values', () {
      final first = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.sixteenth),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      final second = engine.interNoteSpacing(
        previousDuration: const Duration(DurationType.sixteenth),
        previousIsRest: false,
        staffSpace: kStaffSpace,
      );
      expect(first, second);
    });
  });

  group('opticalAdjustment (production optical compensation)', () {
    late IntelligentSpacingEngine engine;

    setUp(() {
      engine = IntelligentSpacingEngine(preferences: SpacingPreferences.normal);
    });

    test('returns 0 when there is no previous element', () {
      expect(
        engine.opticalAdjustment(
          previous: null,
          current: _note(DurationType.quarter),
          staffSpace: kStaffSpace,
        ),
        0.0,
      );
    });

    test('returns 0 when optical spacing is disabled in the preferences', () {
      final disabled = IntelligentSpacingEngine(
        preferences: SpacingPreferences.normal.copyWith(
          enableOpticalSpacing: false,
        ),
      );

      expect(
        disabled.opticalAdjustment(
          previous: _rest(DurationType.quarter),
          current: _note(DurationType.quarter),
          staffSpace: kStaffSpace,
          currentStemUp: true,
        ),
        0.0,
      );
    });

    test('a rest before a stem-up note pushes the note away', () {
      final adjustment = engine.opticalAdjustment(
        previous: _rest(DurationType.quarter),
        current: _note(DurationType.quarter),
        staffSpace: kStaffSpace,
        currentStemUp: true,
      );

      expect(adjustment, greaterThan(0.0));
      expect(adjustment, closeTo(0.08 * kStaffSpace, 1e-9));
    });

    test('alternating stems (up -> down) push apart', () {
      final adjustment = engine.opticalAdjustment(
        previous: _note(DurationType.quarter),
        current: _note(DurationType.quarter),
        staffSpace: kStaffSpace,
        previousStemUp: true,
        currentStemUp: false,
      );

      expect(adjustment, greaterThan(0.0));
    });

    test('an accidental on the current note adds space', () {
      final plain = engine.opticalAdjustment(
        previous: _note(DurationType.quarter),
        current: _note(DurationType.quarter),
        staffSpace: kStaffSpace,
      );
      final sharpened = engine.opticalAdjustment(
        previous: _note(DurationType.quarter),
        current: _note(DurationType.quarter, alter: 1.0),
        staffSpace: kStaffSpace,
      );

      expect(sharpened, greaterThan(plain));
    });

    test('two identical stem-less neighbours need no compensation', () {
      expect(
        engine.opticalAdjustment(
          previous: _note(DurationType.quarter),
          current: _note(DurationType.quarter),
          staffSpace: kStaffSpace,
        ),
        0.0,
      );
    });

    test('a dotted previous note reserves room for its dot', () {
      final adjustment = engine.opticalAdjustment(
        previous: _note(DurationType.quarter, dots: 1),
        current: _note(DurationType.eighth),
        staffSpace: kStaffSpace,
      );

      // 0.12 SS for the previous dot, minus 0.05 SS for the shorter successor.
      expect(adjustment, closeTo((0.12 - 0.05) * kStaffSpace, 1e-9));
    });

    test('non-rhythmic elements are ignored', () {
      expect(
        engine.opticalAdjustment(
          previous: Clef(),
          current: _note(DurationType.quarter),
          staffSpace: kStaffSpace,
        ),
        0.0,
      );
    });

    test('works without calling initializeOpticalCompensator', () {
      final fresh = IntelligentSpacingEngine(
        preferences: SpacingPreferences.normal,
      );

      expect(
        fresh.opticalAdjustment(
          previous: _rest(DurationType.quarter),
          current: _note(DurationType.quarter),
          staffSpace: kStaffSpace,
          currentStemUp: true,
        ),
        greaterThan(0.0),
      );
    });

    test('scales with staffSpace', () {
      double at(double staffSpace) => engine.opticalAdjustment(
        previous: _rest(DurationType.quarter),
        current: _note(DurationType.quarter),
        staffSpace: staffSpace,
        currentStemUp: true,
      );

      expect(at(kStaffSpace * 2), closeTo(at(kStaffSpace) * 2, 1e-9));
    });
  });

  group('analyzeMeasure / SpacingResult', () {
    late IntelligentSpacingEngine engine;

    setUp(() {
      engine = IntelligentSpacingEngine(preferences: SpacingPreferences.normal);
    });

    test('reports one entry per rhythmic element, in order', () {
      final elements = <MusicalElement>[
        Clef(),
        _note(DurationType.quarter),
        _rest(DurationType.quarter),
        _note(DurationType.half),
      ];

      final result = engine.analyzeMeasure(
        elements: elements,
        staffSpace: kStaffSpace,
      );

      // The clef is skipped: its spacing belongs to the layout engine.
      expect(result.elements.length, 3);
      expect(result.elements.map((e) => e.index), [1, 2, 3]);
      expect(result.elements.first.leadingGap, 0.0);
      expect(result.elements[1].xPosition, greaterThan(0.0));
    });

    test('gaps come from the production law', () {
      final result = engine.analyzeMeasure(
        elements: <MusicalElement>[
          _note(DurationType.quarter),
          _note(DurationType.quarter),
        ],
        staffSpace: kStaffSpace,
      );

      expect(
        result.elements[1].leadingGap,
        engine.interNoteSpacing(
          previousDuration: const Duration(DurationType.quarter),
          previousIsRest: false,
          staffSpace: kStaffSpace,
        ),
      );
    });

    test('a rest gets the reduced gap after it', () {
      final afterRest = engine.analyzeMeasure(
        elements: <MusicalElement>[
          _rest(DurationType.quarter),
          _note(DurationType.eighth),
        ],
        staffSpace: kStaffSpace,
      );
      final afterNote = engine.analyzeMeasure(
        elements: <MusicalElement>[
          _note(DurationType.quarter),
          _note(DurationType.eighth),
        ],
        staffSpace: kStaffSpace,
      );

      expect(
        afterRest.elements[1].leadingGap,
        lessThan(afterNote.elements[1].leadingGap),
      );
    });

    test('reports the shortest sounding duration', () {
      final result = engine.analyzeMeasure(
        elements: <MusicalElement>[
          _note(DurationType.half),
          _note(DurationType.sixteenth),
          _note(DurationType.quarter),
        ],
        staffSpace: kStaffSpace,
      );

      expect(result.shortestDuration, closeTo(0.0625, 1e-12));
    });

    test('totalWidth spans first glyph to last glyph', () {
      final result = engine.analyzeMeasure(
        elements: <MusicalElement>[
          _note(DurationType.quarter),
          _note(DurationType.quarter),
        ],
        staffSpace: kStaffSpace,
      );

      expect(result.totalWidth, result.elements.last.right);
      expect(result.totalWidth, greaterThan(result.elements[1].xPosition));
    });

    test('a healthy measure has no collisions', () {
      final result = engine.analyzeMeasure(
        elements: <MusicalElement>[
          _note(DurationType.quarter),
          _note(DurationType.quarter),
          _note(DurationType.quarter),
          _note(DurationType.quarter),
        ],
        staffSpace: kStaffSpace,
      );

      expect(result.hasCollisions, isFalse);
      expect(result.collisions, isEmpty);
    });

    test('ultra-short values are reported as colliding', () {
      // At 1/128 the bare rhythmic gap is narrower than a notehead, which is
      // exactly why LayoutEngine applies an anti-collision floor on top.
      final result = engine.analyzeMeasure(
        elements: List<MusicalElement>.generate(
          6,
          (_) => _note(DurationType.oneHundredTwentyEighth),
        ),
        staffSpace: kStaffSpace,
      );

      expect(result.hasCollisions, isTrue);
    });

    test('an empty measure yields an empty, collision-free report', () {
      final result = engine.analyzeMeasure(
        elements: const <MusicalElement>[],
        staffSpace: kStaffSpace,
      );

      expect(result.elements, isEmpty);
      expect(result.totalWidth, 0.0);
      expect(result.shortestDuration, 0.0);
      expect(result.collisions, isEmpty);
    });

    test('gaps/widths convenience views match the entries', () {
      final result = engine.analyzeMeasure(
        elements: <MusicalElement>[
          _note(DurationType.quarter),
          _note(DurationType.eighth),
        ],
        staffSpace: kStaffSpace,
      );

      expect(result.gaps, [
        result.elements[0].leadingGap,
        result.elements[1].leadingGap,
      ]);
      expect(result.widths, [
        result.elements[0].width,
        result.elements[1].width,
      ]);
    });

    test('does not mutate the elements handed to it', () {
      final note = _note(DurationType.quarter, beam: BeamType.start);
      engine.analyzeMeasure(
        elements: <MusicalElement>[note, _note(DurationType.quarter)],
        staffSpace: kStaffSpace,
      );

      expect(note.beam, BeamType.start);
      expect(note.duration, const Duration(DurationType.quarter));
    });
  });

  group('SpacingPreferences', () {
    test('presets are ordered from compact to pedagogical', () {
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

    test('copyWith creates a new instance without touching the original', () {
      final original = SpacingPreferences.normal;
      final modified = original.copyWith(spacingFactor: 2.0);

      expect(modified.spacingFactor, 2.0);
      expect(modified.model, original.model);
      expect(original.spacingFactor, 1.5);
    });
  });

  group('CollisionDetector', () {
    late CollisionDetector detector;

    setUp(() {
      detector = const CollisionDetector(minSafeDistance: 2.0);
    });

    test('detects collision between overlapping rectangles', () {
      expect(
        detector.checkCollision(
          const Rect.fromLTWH(0, 0, 10, 10),
          const Rect.fromLTWH(5, 0, 10, 10),
        ),
        isTrue,
      );
    });

    test('does not detect collision between separated rectangles', () {
      expect(
        detector.checkCollision(
          const Rect.fromLTWH(0, 0, 10, 10),
          const Rect.fromLTWH(20, 0, 10, 10),
        ),
        isFalse,
      );
    });

    test('calculates the minimum required separation', () {
      final separation = detector.calculateMinimumSeparation(
        const Rect.fromLTWH(0, 0, 10, 10),
        const Rect.fromLTWH(11, 0, 10, 10),
      );

      // Current gap is 1, min safe distance is 2 -> 1 more is required.
      expect(separation, 1.0);
    });
  });

  // ===========================================================================
  // ANALYSIS PATH.
  //
  // Everything below exercises code the RENDERER NEVER RUNS: the
  // dual-algorithm (textual + durational) experiment. These tests protect the
  // experiment from bit-rot; they are NOT evidence about engraved output.
  // Do not add spacing-quality assertions here — add them above.
  // ===========================================================================

  group('ANALYSIS PATH: SpacingCalculator models', () {
    test('square-root model approximates the Gould table', () {
      const calculator = SpacingCalculator(
        model: SpacingModel.squareRoot,
        spacingRatio: 1.0,
      );

      calculator.validateAgainstGould().forEach((duration, errorPercent) {
        expect(
          errorPercent,
          lessThan(10.0),
          reason:
              'Duration $duration has error of '
              '${errorPercent.toStringAsFixed(2)}%',
        );
      });
    });

    test('longer notes get more space in every monotonic model', () {
      for (final model in const [
        SpacingModel.squareRoot,
        SpacingModel.logarithmic,
        SpacingModel.linear,
      ]) {
        final calculator = SpacingCalculator(model: model, spacingRatio: 1.0);
        expect(
          calculator.calculateSpace(0.5, 0.125),
          greaterThan(calculator.calculateSpace(0.25, 0.125)),
          reason: '$model is not monotonic',
        );
      }
    });
  });

  group('ANALYSIS PATH: dual-algorithm experiment', () {
    late IntelligentSpacingEngine engine;

    setUp(() {
      engine = IntelligentSpacingEngine(preferences: SpacingPreferences.normal);
      engine.initializeOpticalCompensator(kStaffSpace);
    });

    test('textual spacing keeps a minimum gap between symbols', () {
      final textual = engine.computeTextualSpacing(
        symbols: const [
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
        ],
        minGap: 0.25,
        staffSpace: kStaffSpace,
      );

      final gap =
          textual[1].xPosition - (textual[0].xPosition + textual[0].width);
      expect(gap, greaterThanOrEqualTo(0.25 * kStaffSpace));
    });

    test('adaptive combination reaches the target width', () {
      final symbols = List.generate(
        3,
        (i) => MusicalSymbolInfo(
          index: i,
          musicalTime: i * 0.25,
          duration: 0.25,
          glyphWidth: 1.18,
        ),
      );

      final combined = engine.combineSpacings(
        textual: engine.computeTextualSpacing(
          symbols: symbols,
          minGap: 0.25,
          staffSpace: kStaffSpace,
        ),
        durational: engine.computeDurationalSpacing(
          symbols: symbols,
          shortestDuration: 0.125,
          staffSpace: kStaffSpace,
        ),
        targetWidth: 500.0,
      );

      expect(combined.last.xPosition + combined.last.width, closeTo(500.0, 1e-6));
    });
  });
}
