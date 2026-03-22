// test/core/clef_test.dart
// Comprehensive tests for Clef model

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Clef - Basic Construction', () {
    test('Creates treble clef', () {
      final clef = Clef(clefType: ClefType.treble);

      expect(clef.clefType, equals(ClefType.treble));
      expect(clef.actualClefType, equals(ClefType.treble));
    });

    test('Creates bass clef', () {
      final clef = Clef(clefType: ClefType.bass);

      expect(clef.clefType, equals(ClefType.bass));
      expect(clef.actualClefType, equals(ClefType.bass));
    });

    test('Creates alto clef', () {
      final clef = Clef(clefType: ClefType.alto);

      expect(clef.clefType, equals(ClefType.alto));
      expect(clef.actualClefType, equals(ClefType.alto));
    });

    test('Creates tenor clef', () {
      final clef = Clef(clefType: ClefType.tenor);

      expect(clef.clefType, equals(ClefType.tenor));
      expect(clef.actualClefType, equals(ClefType.tenor));
    });
  });

  group('Clef - Octave Transposition', () {
    test('Treble 8va clef transposes up octave', () {
      final clef = Clef(clefType: ClefType.treble8va);

      expect(clef.clefType, equals(ClefType.treble8va));
      expect(clef.actualClefType, equals(ClefType.treble));
    });

    test('Treble 8vb clef transposes down octave', () {
      final clef = Clef(clefType: ClefType.treble8vb);

      expect(clef.clefType, equals(ClefType.treble8vb));
      expect(clef.actualClefType, equals(ClefType.treble));
    });

    test('Treble 15ma clef transposes up two octaves', () {
      final clef = Clef(clefType: ClefType.treble15ma);

      expect(clef.clefType, equals(ClefType.treble15ma));
      expect(clef.actualClefType, equals(ClefType.treble));
    });

    test('Treble 15mb clef transposes down two octaves', () {
      final clef = Clef(clefType: ClefType.treble15mb);

      expect(clef.clefType, equals(ClefType.treble15mb));
      expect(clef.actualClefType, equals(ClefType.treble));
    });

    test('Bass 8va clef transposes up octave', () {
      final clef = Clef(clefType: ClefType.bass8va);

      expect(clef.clefType, equals(ClefType.bass8va));
      expect(clef.actualClefType, equals(ClefType.bass));
    });

    test('Bass 8vb clef transposes down octave', () {
      final clef = Clef(clefType: ClefType.bass8vb);

      expect(clef.clefType, equals(ClefType.bass8vb));
      expect(clef.actualClefType, equals(ClefType.bass));
    });
  });

  group('Clef - All Clef Types', () {
    test('All clef types are valid', () {
      final types = [
        ClefType.treble,
        ClefType.bass,
        ClefType.alto,
        ClefType.tenor,
        ClefType.treble8va,
        ClefType.treble8vb,
        ClefType.treble15ma,
        ClefType.treble15mb,
        ClefType.bass8va,
        ClefType.bass8vb,
        ClefType.bass15ma,
        ClefType.bass15mb,
        ClefType.bassThirdLine,
      ];

      for (final type in types) {
        final clef = Clef(clefType: type);
        expect(clef.clefType, equals(type));
      }
    });
  });

  group('Clef - Staff Position Calculation', () {
    test('G4 on treble clef is on 2nd line', () {
      final clef = Clef(clefType: ClefType.treble);
      final pitch = Pitch(step: 'G', octave: 4);

      final position = StaffPositionCalculator.calculate(pitch, clef);

      expect(position, equals(-2));
    });

    test('F3 on bass clef is on 4th line', () {
      final clef = Clef(clefType: ClefType.bass);
      final pitch = Pitch(step: 'F', octave: 3);

      final position = StaffPositionCalculator.calculate(pitch, clef);

      expect(position, equals(2));
    });

    test('C4 (middle C) on alto clef is on middle line', () {
      final clef = Clef(clefType: ClefType.alto);
      final pitch = Pitch(step: 'C', octave: 4);

      final position = StaffPositionCalculator.calculate(pitch, clef);

      expect(position, equals(0));
    });

    test('C4 on tenor clef is on 4th line', () {
      final clef = Clef(clefType: ClefType.tenor);
      final pitch = Pitch(step: 'C', octave: 4);

      final position = StaffPositionCalculator.calculate(pitch, clef);

      expect(position, equals(2));
    });
  });

  group('Clef - Musical Instruments', () {
    test('Treble clef for violin, flute, trumpet', () {
      // Most common clef for high instruments
      final clef = Clef(clefType: ClefType.treble);

      expect(clef.clefType, equals(ClefType.treble));
    });

    test('Bass clef for cello, bass, trombone', () {
      // Most common clef for low instruments
      final clef = Clef(clefType: ClefType.bass);

      expect(clef.clefType, equals(ClefType.bass));
    });

    test('Alto clef for viola', () {
      // Standard clef for viola
      final clef = Clef(clefType: ClefType.alto);

      expect(clef.clefType, equals(ClefType.alto));
    });

    test('Tenor clef for cello (upper register)', () {
      // Used for cello when playing high
      final clef = Clef(clefType: ClefType.tenor);

      expect(clef.clefType, equals(ClefType.tenor));
    });

    test('Treble 8vb for tenor voice', () {
      // Tenor voice notation
      final clef = Clef(clefType: ClefType.treble8vb);

      expect(clef.clefType, equals(ClefType.treble8vb));
    });
  });

  group('Clef - Pitch Reading', () {
    test('Same pitch has different positions in different clefs', () {
      final pitch = Pitch(step: 'C', octave: 4);
      final trebleClef = Clef(clefType: ClefType.treble);
      final bassClef = Clef(clefType: ClefType.bass);
      final altoClef = Clef(clefType: ClefType.alto);

      final treblePos = StaffPositionCalculator.calculate(pitch, trebleClef);
      final bassPos = StaffPositionCalculator.calculate(pitch, bassClef);
      final altoPos = StaffPositionCalculator.calculate(pitch, altoClef);

      // C4 appears in different positions on different clefs
      expect(treblePos, isNot(equals(bassPos)));
      expect(bassPos, isNot(equals(altoPos)));
      expect(treblePos, isNot(equals(altoPos)));
    });

    test('Ascending scale has ascending positions in any clef', () {
      final clefs = [
        Clef(clefType: ClefType.treble),
        Clef(clefType: ClefType.bass),
        Clef(clefType: ClefType.alto),
      ];

      final scale = [
        Pitch(step: 'C', octave: 4),
        Pitch(step: 'D', octave: 4),
        Pitch(step: 'E', octave: 4),
        Pitch(step: 'F', octave: 4),
        Pitch(step: 'G', octave: 4),
      ];

      for (final clef in clefs) {
        final positions = scale.map((p) => StaffPositionCalculator.calculate(p, clef)).toList();

        for (int i = 1; i < positions.length; i++) {
          expect(positions[i], greaterThan(positions[i - 1]),
            reason: 'Ascending pitches should have ascending positions in ${clef.clefType}');
        }
      }
    });
  });

  group('Clef - Grand Staff', () {
    test('Piano uses treble and bass clefs', () {
      final treble = Clef(clefType: ClefType.treble);
      final bass = Clef(clefType: ClefType.bass);

      // Right hand (treble) and left hand (bass)
      expect(treble.clefType, equals(ClefType.treble));
      expect(bass.clefType, equals(ClefType.bass));
    });

    test('Middle C is leger line in both treble and bass', () {
      final treble = Clef(clefType: ClefType.treble);
      final bass = Clef(clefType: ClefType.bass);
      final middleC = Pitch(step: 'C', octave: 4);

      final treblePos = StaffPositionCalculator.calculate(middleC, treble);
      final bassPos = StaffPositionCalculator.calculate(middleC, bass);

      // Middle C requires leger lines in both clefs
      expect(StaffPositionCalculator.needsLedgerLines(treblePos), isTrue);
      expect(StaffPositionCalculator.needsLedgerLines(bassPos), isTrue);
    });
  });

  group('Clef - Clef Changes', () {
    test('Clef can change mid-staff', () {
      final initialClef = Clef(clefType: ClefType.treble);
      final newClef = Clef(clefType: ClefType.bass);

      expect(initialClef.clefType, equals(ClefType.treble));
      expect(newClef.clefType, equals(ClefType.bass));
      expect(initialClef.clefType, isNot(equals(newClef.clefType)));
    });

    test('Clef changes preserve pitch meaning', () {
      // Same pitch, different visual positions
      final pitch = Pitch(step: 'G', octave: 4);
      final treble = Clef(clefType: ClefType.treble);
      final bass = Clef(clefType: ClefType.bass);

      final treblePos = StaffPositionCalculator.calculate(pitch, treble);
      final bassPos = StaffPositionCalculator.calculate(pitch, bass);

      // G4 on treble is on staff, on bass is above staff
      expect(treblePos, lessThanOrEqualTo(4)); // Within staff
      expect(bassPos, greaterThan(4)); // Above staff
    });
  });

  group('Clef - Special Cases', () {
    test('Bass third line clef', () {
      final clef = Clef(clefType: ClefType.bassThirdLine);

      expect(clef.clefType, equals(ClefType.bassThirdLine));
    });

    test('Actual clef type strips transposition', () {
      final transposed = [
        Clef(clefType: ClefType.treble8va),
        Clef(clefType: ClefType.treble8vb),
        Clef(clefType: ClefType.treble15ma),
        Clef(clefType: ClefType.treble15mb),
      ];

      for (final clef in transposed) {
        expect(clef.actualClefType, equals(ClefType.treble),
          reason: '${clef.clefType} should have actualClefType = treble');
      }
    });
  });

  group('Clef - Reading Ranges', () {
    test('Treble clef comfortable range', () {
      final clef = Clef(clefType: ClefType.treble);

      // E4 (1st line) to F5 (5th line) are within staff
      final e4 = Pitch(step: 'E', octave: 4);
      final f5 = Pitch(step: 'F', octave: 5);

      final e4Pos = StaffPositionCalculator.calculate(e4, clef);
      final f5Pos = StaffPositionCalculator.calculate(f5, clef);

      expect(e4Pos, equals(-4)); // 1st line
      expect(f5Pos, equals(4));  // 5th line
    });

    test('Bass clef comfortable range', () {
      final clef = Clef(clefType: ClefType.bass);

      // G2 (1st line) to A3 (5th line) are within staff
      final g2 = Pitch(step: 'G', octave: 2);
      final a3 = Pitch(step: 'A', octave: 3);

      final g2Pos = StaffPositionCalculator.calculate(g2, clef);
      final a3Pos = StaffPositionCalculator.calculate(a3, clef);

      expect(g2Pos, equals(-4)); // 1st line
      expect(a3Pos, equals(4));  // 5th line
    });
  });

  group('Clef - Historical and Modern Usage', () {
    test('C clefs (alto, tenor) for middle ranges', () {
      final alto = Clef(clefType: ClefType.alto);
      final tenor = Clef(clefType: ClefType.tenor);

      // Both are C clefs, placing middle C on different lines
      final middleC = Pitch(step: 'C', octave: 4);

      final altoPos = StaffPositionCalculator.calculate(middleC, alto);
      final tenorPos = StaffPositionCalculator.calculate(middleC, tenor);

      expect(altoPos, equals(0));  // Middle line (3rd line)
      expect(tenorPos, equals(2)); // 4th line
    });
  });
}
