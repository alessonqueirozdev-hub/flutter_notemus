// test/core/duration_test.dart
// Comprehensive tests for Duration model

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Duration - Basic Construction', () {
    test('Creates duration with type', () {
      final duration = Duration(DurationType.quarter);

      expect(duration.type, equals(DurationType.quarter));
      expect(duration.dots, equals(0));
    });

    test('Creates duration with dots', () {
      final duration = Duration(DurationType.quarter, dots: 1);

      expect(duration.type, equals(DurationType.quarter));
      expect(duration.dots, equals(1));
    });

    test('Creates duration with multiple dots', () {
      final duration = Duration(DurationType.half, dots: 2);

      expect(duration.type, equals(DurationType.half));
      expect(duration.dots, equals(2));
    });
  });

  group('Duration - Type Values', () {
    test('Whole note has value 1.0', () {
      final duration = Duration(DurationType.whole);
      expect(duration.type.value, equals(1.0));
    });

    test('Half note has value 0.5', () {
      final duration = Duration(DurationType.half);
      expect(duration.type.value, equals(0.5));
    });

    test('Quarter note has value 0.25', () {
      final duration = Duration(DurationType.quarter);
      expect(duration.type.value, equals(0.25));
    });

    test('Eighth note has value 0.125', () {
      final duration = Duration(DurationType.eighth);
      expect(duration.type.value, equals(0.125));
    });

    test('Sixteenth note has value 0.0625', () {
      final duration = Duration(DurationType.sixteenth);
      expect(duration.type.value, equals(0.0625));
    });

    test('Thirty-second note has value 0.03125', () {
      final duration = Duration(DurationType.thirtySecond);
      expect(duration.type.value, equals(0.03125));
    });

    test('Sixty-fourth note has value 0.015625', () {
      final duration = Duration(DurationType.sixtyFourth);
      expect(duration.type.value, equals(0.015625));
    });
  });

  group('Duration - Dotted Values', () {
    test('Dotted quarter (1 dot) equals 3/8', () {
      // Quarter = 0.25, dotted = 0.25 + 0.125 = 0.375
      final duration = Duration(DurationType.quarter, dots: 1);
      final expectedValue = 0.25 * 1.5; // 0.375

      expect(duration.absoluteValue, equals(expectedValue));
    });

    test('Double-dotted half (2 dots) calculated correctly', () {
      // Half = 0.5, double-dotted = 0.5 + 0.25 + 0.125 = 0.875
      final duration = Duration(DurationType.half, dots: 2);
      final expectedValue = 0.5 * 1.75; // 0.875

      expect(duration.absoluteValue, equals(expectedValue));
    });

    test('Dotted eighth equals quarter minus sixteenth', () {
      final dottedEighth = Duration(DurationType.eighth, dots: 1);
      // 0.125 * 1.5 = 0.1875
      expect(dottedEighth.absoluteValue, equals(0.1875));
    });

    test('Single dot adds 50% of original value', () {
      for (final type in DurationType.values) {
        final plain = Duration(type);
        final dotted = Duration(type, dots: 1);

        expect(dotted.absoluteValue, equals(plain.absoluteValue * 1.5),
          reason: 'Dotted ${type.name} should be 1.5x plain value');
      }
    });

    test('Double dot adds 75% of original value', () {
      for (final type in DurationType.values) {
        final plain = Duration(type);
        final doubleDotted = Duration(type, dots: 2);

        expect(doubleDotted.absoluteValue, equals(plain.absoluteValue * 1.75),
          reason: 'Double-dotted ${type.name} should be 1.75x plain value');
      }
    });
  });

  group('Duration - SMuFL Glyph Names', () {
    test('Whole note returns noteheadWhole', () {
      final duration = Duration(DurationType.whole);
      expect(duration.type.glyphName, equals('noteheadWhole'));
    });

    test('Half note returns noteheadHalf', () {
      final duration = Duration(DurationType.half);
      expect(duration.type.glyphName, equals('noteheadHalf'));
    });

    test('Quarter and shorter notes return noteheadBlack', () {
      final quarter = Duration(DurationType.quarter);
      final eighth = Duration(DurationType.eighth);
      final sixteenth = Duration(DurationType.sixteenth);

      expect(quarter.type.glyphName, equals('noteheadBlack'));
      expect(eighth.type.glyphName, equals('noteheadBlack'));
      expect(sixteenth.type.glyphName, equals('noteheadBlack'));
    });
  });

  group('Duration - Rest Glyph Names', () {
    test('Whole rest returns restWhole', () {
      final duration = Duration(DurationType.whole);
      expect(duration.type.restGlyphName, equals('restWhole'));
    });

    test('Half rest returns restHalf', () {
      final duration = Duration(DurationType.half);
      expect(duration.type.restGlyphName, equals('restHalf'));
    });

    test('Quarter rest returns restQuarter', () {
      final duration = Duration(DurationType.quarter);
      expect(duration.type.restGlyphName, equals('restQuarter'));
    });

    test('Eighth rest returns rest8th', () {
      final duration = Duration(DurationType.eighth);
      expect(duration.type.restGlyphName, equals('rest8th'));
    });

    test('Sixteenth rest returns rest16th', () {
      final duration = Duration(DurationType.sixteenth);
      expect(duration.type.restGlyphName, equals('rest16th'));
    });

    test('Thirty-second rest returns rest32nd', () {
      final duration = Duration(DurationType.thirtySecond);
      expect(duration.type.restGlyphName, equals('rest32nd'));
    });

    test('Sixty-fourth rest returns rest64th', () {
      final duration = Duration(DurationType.sixtyFourth);
      expect(duration.type.restGlyphName, equals('rest64th'));
    });
  });

  group('Duration - Needs Stem', () {
    test('Whole note does not need stem', () {
      final duration = Duration(DurationType.whole);
      expect(duration.type.needsStem, isFalse);
    });

    test('Half note and shorter need stem', () {
      final types = [
        DurationType.half,
        DurationType.quarter,
        DurationType.eighth,
        DurationType.sixteenth,
        DurationType.thirtySecond,
        DurationType.sixtyFourth,
      ];

      for (final type in types) {
        final duration = Duration(type);
        expect(duration.type.needsStem, isTrue,
          reason: '${type.name} should need a stem');
      }
    });
  });

  group('Duration - Needs Flag', () {
    test('Whole, half, quarter do not need flags', () {
      final types = [
        DurationType.whole,
        DurationType.half,
        DurationType.quarter,
      ];

      for (final type in types) {
        final duration = Duration(type);
        expect(duration.type.needsFlag, isFalse,
          reason: '${type.name} should not need a flag');
      }
    });

    test('Eighth and shorter need flags', () {
      final types = [
        DurationType.eighth,
        DurationType.sixteenth,
        DurationType.thirtySecond,
        DurationType.sixtyFourth,
      ];

      for (final type in types) {
        final duration = Duration(type);
        expect(duration.type.needsFlag, isTrue,
          reason: '${type.name} should need a flag');
      }
    });
  });

  group('Duration - Is Filled', () {
    test('Whole and half notes are not filled', () {
      final whole = Duration(DurationType.whole);
      final half = Duration(DurationType.half);

      expect(whole.type.isFilled, isFalse);
      expect(half.type.isFilled, isFalse);
    });

    test('Quarter and shorter notes are filled', () {
      final types = [
        DurationType.quarter,
        DurationType.eighth,
        DurationType.sixteenth,
        DurationType.thirtySecond,
        DurationType.sixtyFourth,
      ];

      for (final type in types) {
        final duration = Duration(type);
        expect(duration.type.isFilled, isTrue,
          reason: '${type.name} should be filled');
      }
    });
  });

  group('Duration - Musical Theory', () {
    test('Two half notes equal one whole note', () {
      final whole = Duration(DurationType.whole);
      final half = Duration(DurationType.half);

      expect(half.absoluteValue * 2, equals(whole.absoluteValue));
    });

    test('Four quarter notes equal one whole note', () {
      final whole = Duration(DurationType.whole);
      final quarter = Duration(DurationType.quarter);

      expect(quarter.absoluteValue * 4, equals(whole.absoluteValue));
    });

    test('Eight eighth notes equal one whole note', () {
      final whole = Duration(DurationType.whole);
      final eighth = Duration(DurationType.eighth);

      expect(eighth.absoluteValue * 8, equals(whole.absoluteValue));
    });

    test('Dotted quarter plus eighth equals half note', () {
      final dottedQuarter = Duration(DurationType.quarter, dots: 1);
      final eighth = Duration(DurationType.eighth);
      final half = Duration(DurationType.half);

      final sum = dottedQuarter.absoluteValue + eighth.absoluteValue;
      expect(sum, equals(half.absoluteValue));
    });

    test('Three eighth notes fit in dotted quarter', () {
      final dottedQuarter = Duration(DurationType.quarter, dots: 1);
      final eighth = Duration(DurationType.eighth);

      expect(dottedQuarter.absoluteValue, equals(eighth.absoluteValue * 3));
    });
  });

  group('Duration - Measure Validation', () {
    test('Four quarter notes fill 4/4 measure', () {
      final quarter = Duration(DurationType.quarter);
      final measureCapacity = 1.0; // 4/4 = 4 quarters = 1.0 whole note

      final totalDuration = quarter.absoluteValue * 4;
      expect(totalDuration, equals(measureCapacity));
    });

    test('Three quarter notes fill 3/4 measure', () {
      final quarter = Duration(DurationType.quarter);
      final measureCapacity = 0.75; // 3/4 measure

      final totalDuration = quarter.absoluteValue * 3;
      expect(totalDuration, equals(measureCapacity));
    });

    test('Six eighth notes fill 3/4 measure', () {
      final eighth = Duration(DurationType.eighth);
      final measureCapacity = 0.75; // 3/4 measure

      final totalDuration = eighth.absoluteValue * 6;
      expect(totalDuration, equals(measureCapacity));
    });
  });

  group('Duration - Relative Durations', () {
    test('Each duration is half the previous', () {
      final types = [
        DurationType.whole,
        DurationType.half,
        DurationType.quarter,
        DurationType.eighth,
        DurationType.sixteenth,
        DurationType.thirtySecond,
        DurationType.sixtyFourth,
      ];

      for (int i = 1; i < types.length; i++) {
        final longer = Duration(types[i - 1]);
        final shorter = Duration(types[i]);

        expect(shorter.absoluteValue, equals(longer.absoluteValue / 2),
          reason: '${types[i].name} should be half of ${types[i-1].name}');
      }
    });
  });

  group('Duration - Edge Cases', () {
    test('Zero dots is valid', () {
      final duration = Duration(DurationType.quarter, dots: 0);
      expect(duration.dots, equals(0));
      expect(duration.absoluteValue, equals(0.25));
    });

    test('Maximum reasonable dots (3) behaves correctly', () {
      // Triple-dotted note: 1 + 0.5 + 0.25 + 0.125 = 1.875
      final duration = Duration(DurationType.whole, dots: 3);
      final expectedValue = 1.0 * (1 + 0.5 + 0.25 + 0.125); // 1.875

      expect(duration.absoluteValue, equals(expectedValue));
    });

    test('Smallest practical duration (sixty-fourth) is precise', () {
      final duration = Duration(DurationType.sixtyFourth);
      expect(duration.absoluteValue, equals(1.0 / 64.0));
    });
  });
}
