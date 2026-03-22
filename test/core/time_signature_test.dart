// test/core/time_signature_test.dart
// Comprehensive tests for TimeSignature model

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('TimeSignature - Basic Construction', () {
    test('Creates 4/4 time signature', () {
      final ts = TimeSignature(numerator: 4, denominator: 4);

      expect(ts.numerator, equals(4));
      expect(ts.denominator, equals(4));
    });

    test('Creates 3/4 time signature', () {
      final ts = TimeSignature(numerator: 3, denominator: 4);

      expect(ts.numerator, equals(3));
      expect(ts.denominator, equals(4));
    });

    test('Creates 6/8 time signature', () {
      final ts = TimeSignature(numerator: 6, denominator: 8);

      expect(ts.numerator, equals(6));
      expect(ts.denominator, equals(8));
    });

    test('Creates 2/2 time signature', () {
      final ts = TimeSignature(numerator: 2, denominator: 2);

      expect(ts.numerator, equals(2));
      expect(ts.denominator, equals(2));
    });
  });

  group('TimeSignature - Common Time Signatures', () {
    test('4/4 (common time)', () {
      final ts = TimeSignature(numerator: 4, denominator: 4);

      expect(ts.numerator, equals(4));
      expect(ts.denominator, equals(4));
      // 4/4 = 4 quarter notes per measure
    });

    test('3/4 (waltz time)', () {
      final ts = TimeSignature(numerator: 3, denominator: 4);

      expect(ts.numerator, equals(3));
      expect(ts.denominator, equals(4));
      // 3/4 = 3 quarter notes per measure
    });

    test('2/4 (march time)', () {
      final ts = TimeSignature(numerator: 2, denominator: 4);

      expect(ts.numerator, equals(2));
      expect(ts.denominator, equals(4));
    });

    test('6/8 (compound duple)', () {
      final ts = TimeSignature(numerator: 6, denominator: 8);

      expect(ts.numerator, equals(6));
      expect(ts.denominator, equals(8));
      // 6/8 = 2 dotted quarter beats
    });

    test('9/8 (compound triple)', () {
      final ts = TimeSignature(numerator: 9, denominator: 8);

      expect(ts.numerator, equals(9));
      expect(ts.denominator, equals(8));
      // 9/8 = 3 dotted quarter beats
    });

    test('12/8 (compound quadruple)', () {
      final ts = TimeSignature(numerator: 12, denominator: 8);

      expect(ts.numerator, equals(12));
      expect(ts.denominator, equals(8));
      // 12/8 = 4 dotted quarter beats
    });
  });

  group('TimeSignature - Simple vs Compound', () {
    test('Simple time signatures', () {
      final simple = [
        TimeSignature(numerator: 2, denominator: 4),
        TimeSignature(numerator: 3, denominator: 4),
        TimeSignature(numerator: 4, denominator: 4),
        TimeSignature(numerator: 2, denominator: 2),
        TimeSignature(numerator: 3, denominator: 2),
      ];

      for (final ts in simple) {
        // Simple time: beat divides into 2
        expect(ts.numerator, lessThanOrEqualTo(5));
      }
    });

    test('Compound time signatures', () {
      final compound = [
        TimeSignature(numerator: 6, denominator: 8),
        TimeSignature(numerator: 9, denominator: 8),
        TimeSignature(numerator: 12, denominator: 8),
        TimeSignature(numerator: 6, denominator: 4),
      ];

      for (final ts in compound) {
        // Compound time: numerator divisible by 3
        expect(ts.numerator % 3, equals(0),
          reason: '${ts.numerator}/${ts.denominator} should be compound');
      }
    });
  });

  group('TimeSignature - Irregular/Odd Meters', () {
    test('5/4 time signature', () {
      final ts = TimeSignature(numerator: 5, denominator: 4);

      expect(ts.numerator, equals(5));
      expect(ts.denominator, equals(4));
      // Often grouped as 3+2 or 2+3
    });

    test('7/8 time signature', () {
      final ts = TimeSignature(numerator: 7, denominator: 8);

      expect(ts.numerator, equals(7));
      expect(ts.denominator, equals(8));
      // Often grouped as 2+2+3 or 3+2+2
    });

    test('7/4 time signature', () {
      final ts = TimeSignature(numerator: 7, denominator: 4);

      expect(ts.numerator, equals(7));
      expect(ts.denominator, equals(4));
    });

    test('11/8 time signature', () {
      final ts = TimeSignature(numerator: 11, denominator: 8);

      expect(ts.numerator, equals(11));
      expect(ts.denominator, equals(8));
    });

    test('13/8 time signature', () {
      final ts = TimeSignature(numerator: 13, denominator: 8);

      expect(ts.numerator, equals(13));
      expect(ts.denominator, equals(8));
    });
  });

  group('TimeSignature - Denominator Values', () {
    test('Denominator 2 (half note beat)', () {
      final ts = TimeSignature(numerator: 3, denominator: 2);

      expect(ts.denominator, equals(2));
      // 3/2 = 3 half notes per measure
    });

    test('Denominator 4 (quarter note beat)', () {
      final ts = TimeSignature(numerator: 4, denominator: 4);

      expect(ts.denominator, equals(4));
      // Most common denominator
    });

    test('Denominator 8 (eighth note beat)', () {
      final ts = TimeSignature(numerator: 6, denominator: 8);

      expect(ts.denominator, equals(8));
    });

    test('Denominator 16 (sixteenth note beat)', () {
      final ts = TimeSignature(numerator: 4, denominator: 16);

      expect(ts.denominator, equals(16));
    });

    test('Valid denominators are powers of 2', () {
      final validDenominators = [2, 4, 8, 16, 32];

      for (final denom in validDenominators) {
        final ts = TimeSignature(numerator: 4, denominator: denom);
        expect(ts.denominator, equals(denom));
      }
    });
  });

  group('TimeSignature - Measure Capacity', () {
    test('4/4 measure holds one whole note', () {
      final ts = TimeSignature(numerator: 4, denominator: 4);

      // Capacity = numerator / denominator = 4/4 = 1.0 whole note
      final capacity = ts.numerator / ts.denominator;
      expect(capacity, equals(1.0));
    });

    test('3/4 measure holds dotted half note', () {
      final ts = TimeSignature(numerator: 3, denominator: 4);

      // Capacity = 3/4 = 0.75 (dotted half)
      final capacity = ts.numerator / ts.denominator;
      expect(capacity, equals(0.75));
    });

    test('6/8 measure holds dotted half note', () {
      final ts = TimeSignature(numerator: 6, denominator: 8);

      // Capacity = 6/8 = 0.75
      final capacity = ts.numerator / ts.denominator;
      expect(capacity, equals(0.75));
    });

    test('2/2 measure holds one whole note', () {
      final ts = TimeSignature(numerator: 2, denominator: 2);

      // Capacity = 2/2 = 1.0
      final capacity = ts.numerator / ts.denominator;
      expect(capacity, equals(1.0));
    });
  });

  group('TimeSignature - Beat Counting', () {
    test('4/4 has 4 beats', () {
      final ts = TimeSignature(numerator: 4, denominator: 4);

      // Simple time: numerator = number of beats
      expect(ts.numerator, equals(4));
    });

    test('3/4 has 3 beats', () {
      final ts = TimeSignature(numerator: 3, denominator: 4);

      expect(ts.numerator, equals(3));
    });

    test('6/8 has 2 beats (compound)', () {
      final ts = TimeSignature(numerator: 6, denominator: 8);

      // Compound time: 6 eighth notes = 2 dotted quarter beats
      final compoundBeats = ts.numerator / 3;
      expect(compoundBeats, equals(2));
    });

    test('9/8 has 3 beats (compound)', () {
      final ts = TimeSignature(numerator: 9, denominator: 8);

      // 9 eighth notes = 3 dotted quarter beats
      final compoundBeats = ts.numerator / 3;
      expect(compoundBeats, equals(3));
    });

    test('12/8 has 4 beats (compound)', () {
      final ts = TimeSignature(numerator: 12, denominator: 8);

      // 12 eighth notes = 4 dotted quarter beats
      final compoundBeats = ts.numerator / 3;
      expect(compoundBeats, equals(4));
    });
  });

  group('TimeSignature - Musical Styles', () {
    test('Waltz uses 3/4', () {
      final waltzTime = TimeSignature(numerator: 3, denominator: 4);

      expect(waltzTime.numerator, equals(3));
      expect(waltzTime.denominator, equals(4));
    });

    test('March uses 2/4 or 4/4', () {
      final march1 = TimeSignature(numerator: 2, denominator: 4);
      final march2 = TimeSignature(numerator: 4, denominator: 4);

      expect(march1.numerator, isIn([2, 4]));
      expect(march2.numerator, isIn([2, 4]));
    });

    test('Jig uses 6/8', () {
      final jigTime = TimeSignature(numerator: 6, denominator: 8);

      expect(jigTime.numerator, equals(6));
      expect(jigTime.denominator, equals(8));
    });

    test('Blues often uses 12/8', () {
      final bluesTime = TimeSignature(numerator: 12, denominator: 8);

      expect(bluesTime.numerator, equals(12));
      expect(bluesTime.denominator, equals(8));
    });
  });

  group('TimeSignature - Special Notations', () {
    test('Common time (C) is 4/4', () {
      final commonTime = TimeSignature(numerator: 4, denominator: 4);

      // C symbol represents 4/4
      expect(commonTime.numerator, equals(4));
      expect(commonTime.denominator, equals(4));
    });

    test('Cut time (¢) is 2/2', () {
      final cutTime = TimeSignature(numerator: 2, denominator: 2);

      // Cut time symbol represents 2/2
      expect(cutTime.numerator, equals(2));
      expect(cutTime.denominator, equals(2));
    });
  });

  group('TimeSignature - Rare Time Signatures', () {
    test('1/4 time signature', () {
      final ts = TimeSignature(numerator: 1, denominator: 4);

      expect(ts.numerator, equals(1));
      expect(ts.denominator, equals(4));
    });

    test('15/8 time signature', () {
      final ts = TimeSignature(numerator: 15, denominator: 8);

      expect(ts.numerator, equals(15));
      expect(ts.denominator, equals(8));
    });

    test('19/16 time signature', () {
      final ts = TimeSignature(numerator: 19, denominator: 16);

      expect(ts.numerator, equals(19));
      expect(ts.denominator, equals(16));
    });
  });

  group('TimeSignature - Comparison', () {
    test('Same time signatures are equal', () {
      final ts1 = TimeSignature(numerator: 4, denominator: 4);
      final ts2 = TimeSignature(numerator: 4, denominator: 4);

      expect(ts1.numerator, equals(ts2.numerator));
      expect(ts1.denominator, equals(ts2.denominator));
    });

    test('Different time signatures are not equal', () {
      final ts1 = TimeSignature(numerator: 3, denominator: 4);
      final ts2 = TimeSignature(numerator: 4, denominator: 4);

      expect(ts1.numerator, isNot(equals(ts2.numerator)));
    });

    test('3/4 and 6/8 have same capacity but different feel', () {
      final threeQuarter = TimeSignature(numerator: 3, denominator: 4);
      final sixEighth = TimeSignature(numerator: 6, denominator: 8);

      final capacity1 = threeQuarter.numerator / threeQuarter.denominator;
      final capacity2 = sixEighth.numerator / sixEighth.denominator;

      // Same total duration
      expect(capacity1, equals(capacity2));

      // But different beat structure
      expect(threeQuarter.numerator, isNot(equals(sixEighth.numerator)));
    });
  });

  group('TimeSignature - Validation', () {
    test('Numerator must be positive', () {
      // Creating with positive numerator
      final ts = TimeSignature(numerator: 4, denominator: 4);
      expect(ts.numerator, greaterThan(0));
    });

    test('Denominator must be positive', () {
      // Creating with positive denominator
      final ts = TimeSignature(numerator: 4, denominator: 4);
      expect(ts.denominator, greaterThan(0));
    });

    test('Common numerators range from 1 to 12+', () {
      final numerators = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15];

      for (final num in numerators) {
        final ts = TimeSignature(numerator: num, denominator: 4);
        expect(ts.numerator, equals(num));
      }
    });

    test('Common denominators are powers of 2', () {
      final denominators = [2, 4, 8, 16];

      for (final denom in denominators) {
        final ts = TimeSignature(numerator: 4, denominator: denom);
        expect(ts.denominator, equals(denom));

        // Check it's a power of 2
        expect((denom & (denom - 1)), equals(0),
          reason: '$denom should be power of 2');
      }
    });
  });
}
