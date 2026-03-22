// test/core/rest_test.dart
// Comprehensive tests for Rest model

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Rest - Basic Construction', () {
    test('Creates rest with duration', () {
      final rest = Rest(duration: Duration(DurationType.quarter));

      expect(rest.duration.type, equals(DurationType.quarter));
    });

    test('Creates rest with dotted duration', () {
      final rest = Rest(duration: Duration(DurationType.half, dots: 1));

      expect(rest.duration.type, equals(DurationType.half));
      expect(rest.duration.dots, equals(1));
    });

    test('Creates rest with double-dotted duration', () {
      final rest = Rest(duration: Duration(DurationType.quarter, dots: 2));

      expect(rest.duration.dots, equals(2));
    });
  });

  group('Rest - Duration Types', () {
    test('Whole rest', () {
      final rest = Rest(duration: Duration(DurationType.whole));

      expect(rest.duration.type, equals(DurationType.whole));
      expect(rest.duration.type.value, equals(1.0));
      expect(rest.duration.type.restGlyphName, equals('restWhole'));
    });

    test('Half rest', () {
      final rest = Rest(duration: Duration(DurationType.half));

      expect(rest.duration.type, equals(DurationType.half));
      expect(rest.duration.type.value, equals(0.5));
      expect(rest.duration.type.restGlyphName, equals('restHalf'));
    });

    test('Quarter rest', () {
      final rest = Rest(duration: Duration(DurationType.quarter));

      expect(rest.duration.type, equals(DurationType.quarter));
      expect(rest.duration.type.value, equals(0.25));
      expect(rest.duration.type.restGlyphName, equals('restQuarter'));
    });

    test('Eighth rest', () {
      final rest = Rest(duration: Duration(DurationType.eighth));

      expect(rest.duration.type, equals(DurationType.eighth));
      expect(rest.duration.type.value, equals(0.125));
      expect(rest.duration.type.restGlyphName, equals('rest8th'));
    });

    test('Sixteenth rest', () {
      final rest = Rest(duration: Duration(DurationType.sixteenth));

      expect(rest.duration.type, equals(DurationType.sixteenth));
      expect(rest.duration.type.value, equals(0.0625));
      expect(rest.duration.type.restGlyphName, equals('rest16th'));
    });

    test('Thirty-second rest', () {
      final rest = Rest(duration: Duration(DurationType.thirtySecond));

      expect(rest.duration.type, equals(DurationType.thirtySecond));
      expect(rest.duration.type.restGlyphName, equals('rest32nd'));
    });

    test('Sixty-fourth rest', () {
      final rest = Rest(duration: Duration(DurationType.sixtyFourth));

      expect(rest.duration.type, equals(DurationType.sixtyFourth));
      expect(rest.duration.type.restGlyphName, equals('rest64th'));
    });
  });

  group('Rest - SMuFL Glyphs', () {
    test('All rest types have valid glyph names', () {
      final types = [
        DurationType.whole,
        DurationType.half,
        DurationType.quarter,
        DurationType.eighth,
        DurationType.sixteenth,
        DurationType.thirtySecond,
        DurationType.sixtyFourth,
      ];

      for (final type in types) {
        final rest = Rest(duration: Duration(type));
        expect(rest.duration.type.restGlyphName, isNotEmpty,
          reason: '${type.name} rest should have valid glyph name');
      }
    });

    test('Whole rest glyph is restWhole', () {
      final rest = Rest(duration: Duration(DurationType.whole));
      expect(rest.duration.type.restGlyphName, equals('restWhole'));
    });

    test('Half rest glyph is restHalf', () {
      final rest = Rest(duration: Duration(DurationType.half));
      expect(rest.duration.type.restGlyphName, equals('restHalf'));
    });
  });

  group('Rest - Dotted Rests', () {
    test('Dotted quarter rest value', () {
      final rest = Rest(duration: Duration(DurationType.quarter, dots: 1));

      // Quarter rest = 0.25, dotted = 0.375
      expect(rest.duration.absoluteValue, equals(0.375));
    });

    test('Dotted half rest value', () {
      final rest = Rest(duration: Duration(DurationType.half, dots: 1));

      // Half rest = 0.5, dotted = 0.75
      expect(rest.duration.absoluteValue, equals(0.75));
    });

    test('Double-dotted whole rest value', () {
      final rest = Rest(duration: Duration(DurationType.whole, dots: 2));

      // Whole rest = 1.0, double-dotted = 1.75
      expect(rest.duration.absoluteValue, equals(1.75));
    });

    test('Dotted eighth rest value', () {
      final rest = Rest(duration: Duration(DurationType.eighth, dots: 1));

      // Eighth rest = 0.125, dotted = 0.1875
      expect(rest.duration.absoluteValue, equals(0.1875));
    });
  });

  group('Rest - Musical Context', () {
    test('Whole measure rest in 4/4', () {
      final rest = Rest(duration: Duration(DurationType.whole));

      // In 4/4 time, whole rest fills the measure
      expect(rest.duration.absoluteValue, equals(1.0));
    });

    test('Half measure rest in 2/4', () {
      final rest = Rest(duration: Duration(DurationType.half));

      // In 2/4 time, half rest fills the measure
      expect(rest.duration.absoluteValue, equals(0.5));
    });

    test('Quarter rest in 4/4 measure', () {
      final rest = Rest(duration: Duration(DurationType.quarter));

      // Four quarter rests fill 4/4 measure
      final totalValue = rest.duration.absoluteValue * 4;
      expect(totalValue, equals(1.0));
    });

    test('Dotted quarter rest in 3/4 measure', () {
      final dottedQuarter = Rest(duration: Duration(DurationType.quarter, dots: 1));
      final eighth = Rest(duration: Duration(DurationType.eighth));

      // Dotted quarter + eighth = half measure in 3/4
      final total = dottedQuarter.duration.absoluteValue + eighth.duration.absoluteValue;
      expect(total, equals(0.5));
    });
  });

  group('Rest - Measure Validation', () {
    test('Four quarter rests equal one whole rest', () {
      final quarterRest = Rest(duration: Duration(DurationType.quarter));
      final wholeRest = Rest(duration: Duration(DurationType.whole));

      expect(quarterRest.duration.absoluteValue * 4, equals(wholeRest.duration.absoluteValue));
    });

    test('Two half rests equal one whole rest', () {
      final halfRest = Rest(duration: Duration(DurationType.half));
      final wholeRest = Rest(duration: Duration(DurationType.whole));

      expect(halfRest.duration.absoluteValue * 2, equals(wholeRest.duration.absoluteValue));
    });

    test('Eight eighth rests equal one whole rest', () {
      final eighthRest = Rest(duration: Duration(DurationType.eighth));
      final wholeRest = Rest(duration: Duration(DurationType.whole));

      expect(eighthRest.duration.absoluteValue * 8, equals(wholeRest.duration.absoluteValue));
    });
  });

  group('Rest - Combinations', () {
    test('Quarter rest + dotted quarter rest + eighth rest = half note', () {
      final quarter = Rest(duration: Duration(DurationType.quarter));
      final dottedQuarter = Rest(duration: Duration(DurationType.quarter, dots: 1));
      final eighth = Rest(duration: Duration(DurationType.eighth));

      final total = quarter.duration.absoluteValue +
                    dottedQuarter.duration.absoluteValue +
                    eighth.duration.absoluteValue;

      // 0.25 + 0.375 + 0.125 = 0.75 (dotted half)
      expect(total, equals(0.75));
    });

    test('Half rest + quarter rest = three quarters', () {
      final half = Rest(duration: Duration(DurationType.half));
      final quarter = Rest(duration: Duration(DurationType.quarter));

      final total = half.duration.absoluteValue + quarter.duration.absoluteValue;

      expect(total, equals(0.75));
    });
  });

  group('Rest - Edge Cases', () {
    test('Multiple rests in sequence', () {
      final rests = [
        Rest(duration: Duration(DurationType.quarter)),
        Rest(duration: Duration(DurationType.quarter)),
        Rest(duration: Duration(DurationType.quarter)),
        Rest(duration: Duration(DurationType.quarter)),
      ];

      final total = rests.fold<double>(
        0.0,
        (sum, rest) => sum + rest.duration.absoluteValue,
      );

      expect(total, equals(1.0));
    });

    test('Very small rest (sixty-fourth)', () {
      final rest = Rest(duration: Duration(DurationType.sixtyFourth));

      expect(rest.duration.absoluteValue, equals(1.0 / 64.0));
    });

    test('Rest with maximum dots', () {
      final rest = Rest(duration: Duration(DurationType.whole, dots: 3));

      // Triple-dotted whole: 1 + 0.5 + 0.25 + 0.125 = 1.875
      expect(rest.duration.absoluteValue, equals(1.875));
    });
  });

  group('Rest - Time Signature Context', () {
    test('Whole rest represents full measure in 4/4', () {
      final rest = Rest(duration: Duration(DurationType.whole));
      final measureCapacity = 1.0; // 4/4

      expect(rest.duration.absoluteValue, equals(measureCapacity));
    });

    test('Whole rest represents full measure in 3/4', () {
      // By convention, whole rest is used for full measure rest
      // even in 3/4 time
      final rest = Rest(duration: Duration(DurationType.whole));

      // Note: In practice, whole rest means "full measure rest"
      // regardless of time signature
      expect(rest.duration.type, equals(DurationType.whole));
    });

    test('Dotted half rest fills 3/4 measure', () {
      final rest = Rest(duration: Duration(DurationType.half, dots: 1));
      final measureCapacity = 0.75; // 3/4

      expect(rest.duration.absoluteValue, equals(measureCapacity));
    });
  });

  group('Rest - Comparison with Notes', () {
    test('Quarter rest has same duration as quarter note', () {
      final rest = Rest(duration: Duration(DurationType.quarter));
      final note = Note(
        pitch: Pitch(step: 'C', octave: 4),
        duration: Duration(DurationType.quarter),
      );

      expect(rest.duration.absoluteValue, equals(note.duration.absoluteValue));
    });

    test('Dotted rest equals dotted note duration', () {
      final rest = Rest(duration: Duration(DurationType.eighth, dots: 1));
      final note = Note(
        pitch: Pitch(step: 'D', octave: 4),
        duration: Duration(DurationType.eighth, dots: 1),
      );

      expect(rest.duration.absoluteValue, equals(note.duration.absoluteValue));
    });

    test('Rest can replace note of same duration', () {
      // Musical principle: rest occupies same time as note
      final originalNote = Note(
        pitch: Pitch(step: 'E', octave: 4),
        duration: Duration(DurationType.quarter),
      );
      final replacementRest = Rest(duration: Duration(DurationType.quarter));

      expect(replacementRest.duration.type, equals(originalNote.duration.type));
      expect(replacementRest.duration.absoluteValue, equals(originalNote.duration.absoluteValue));
    });
  });

  group('Rest - Visual Representation', () {
    test('Whole and half rests have different visual positions', () {
      final wholeRest = Rest(duration: Duration(DurationType.whole));
      final halfRest = Rest(duration: Duration(DurationType.half));

      // Whole rest hangs from line, half rest sits on line
      // This is convention, not explicitly stored in model
      expect(wholeRest.duration.type, isNot(equals(halfRest.duration.type)));
      expect(wholeRest.duration.type.restGlyphName, isNot(equals(halfRest.duration.type.restGlyphName)));
    });

    test('All rest types have distinct glyphs', () {
      final types = [
        DurationType.whole,
        DurationType.half,
        DurationType.quarter,
        DurationType.eighth,
        DurationType.sixteenth,
        DurationType.thirtySecond,
        DurationType.sixtyFourth,
      ];

      final glyphs = types.map((t) => Duration(t).type.restGlyphName).toSet();

      expect(glyphs.length, equals(types.length),
        reason: 'Each rest type should have unique glyph');
    });
  });
}
