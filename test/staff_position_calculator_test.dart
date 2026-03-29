// test/staff_position_calculateTestor_test.dart
// VALIDATION TESTS: SMuFL Coordinate System
//
// These tests validate the critical coordinate system fix
// documented in CORRECOES_CRITICAS_AppliesDAS.md

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('StaffPositionCalculator - Treble Clef', () {
    final trebleClef = Clef(clefType: ClefType.treble);

    test('G4 should be on the 2nd line (staffPosition = -2)', () {
      final pitch = Pitch(step: 'G', octave: 4);
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);

      expect(
        position,
        equals(-2),
        reason:
            'G4 is the reference note of the treble clef and must be on the 2nd line',
      );
    });

    test(
      'C5 should be within the staff in treble clef (staffPosition = 1)',
      () {
        final pitch = Pitch(step: 'C', octave: 5);
        final position = StaffPositionCalculator.calculate(pitch, trebleClef);

        expect(
          position,
          equals(1),
          reason: 'C5 is in the third space in treble clef',
        );
      },
    );

    test('E4 should be on the 1st line (staffPosition = -4)', () {
      final pitch = Pitch(step: 'E', octave: 4);
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);

      expect(
        position,
        equals(-4),
        reason: 'E4 is the lowest note within the staff in treble clef',
      );
    });

    test('F5 should be on the 5th line (staffPosition = 4)', () {
      final pitch = Pitch(step: 'F', octave: 5);
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);

      expect(
        position,
        equals(4),
        reason: 'F5 is the highest note within the staff in treble clef',
      );
    });

    test(
      'Ascending scale C4-C5 should have monotonically increasing positions',
      () {
        final scale = [
          Pitch(step: 'C', octave: 4),
          Pitch(step: 'D', octave: 4),
          Pitch(step: 'E', octave: 4),
          Pitch(step: 'F', octave: 4),
          Pitch(step: 'G', octave: 4),
          Pitch(step: 'A', octave: 4),
          Pitch(step: 'B', octave: 4),
          Pitch(step: 'C', octave: 5),
        ];

        final positions = scale
            .map((p) => StaffPositionCalculator.calculate(p, trebleClef))
            .toList();

        for (int i = 1; i < positions.length; i++) {
          expect(
            positions[i],
            greaterThan(positions[i - 1]),
            reason:
                'Note ${scale[i].step}${scale[i].octave} must be above '
                '${scale[i - 1].step}${scale[i - 1].octave}',
          );
        }
      },
    );

    test(
      'Notes on lower ledger lines should have staffPosition < -4',
      () {
        final pitch = Pitch(step: 'C', octave: 4); // C below the staff
        final position = StaffPositionCalculator.calculate(pitch, trebleClef);

        expect(
          position,
          lessThan(-4),
          reason:
              'C4 is below the staff and requires ledger lines',
        );
      },
    );

    test(
      'Notes on upper ledger lines should have staffPosition > 4',
      () {
        final pitch = Pitch(step: 'A', octave: 5); // A above the staff
        final position = StaffPositionCalculator.calculate(pitch, trebleClef);

        expect(
          position,
          greaterThan(4),
          reason:
              'A5 is above the staff and requires ledger lines',
        );
      },
    );
  });

  group('StaffPositionCalculator - Bass Clef', () {
    final bassClef = Clef(clefType: ClefType.bass);

    test('F3 should be on the 4th line (staffPosition = 2)', () {
      final pitch = Pitch(step: 'F', octave: 3);
      final position = StaffPositionCalculator.calculate(pitch, bassClef);

      expect(
        position,
        equals(2),
        reason:
            'F3 is the reference note of the bass clef and must be on the 4th line',
      );
    });

    test('G2 should be on the 1st line (staffPosition = -4)', () {
      final pitch = Pitch(step: 'G', octave: 2);
      final position = StaffPositionCalculator.calculate(pitch, bassClef);

      expect(
        position,
        equals(-4),
        reason: 'G2 is the lowest note within the staff in bass clef',
      );
    });

    test('A3 should be on the 5th line (staffPosition = 4)', () {
      final pitch = Pitch(step: 'A', octave: 3);
      final position = StaffPositionCalculator.calculate(pitch, bassClef);

      expect(
        position,
        equals(4),
        reason: 'A3 is the highest note within the staff in bass clef',
      );
    });

    test('Ascending scale G2-G3 should have increasing positions', () {
      final scale = [
        Pitch(step: 'G', octave: 2),
        Pitch(step: 'A', octave: 2),
        Pitch(step: 'B', octave: 2),
        Pitch(step: 'C', octave: 3),
        Pitch(step: 'D', octave: 3),
        Pitch(step: 'E', octave: 3),
        Pitch(step: 'F', octave: 3),
        Pitch(step: 'G', octave: 3),
      ];

      final positions = scale
          .map((p) => StaffPositionCalculator.calculate(p, bassClef))
          .toList();

      for (int i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
    });
  });

  group('StaffPositionCalculator - C Clefs', () {
    test('C4 on alto clef should be at center (staffPosition = 0)', () {
      final altoClef = Clef(clefType: ClefType.alto);
      final pitch = Pitch(step: 'C', octave: 4);
      final position = StaffPositionCalculator.calculate(pitch, altoClef);

      expect(
        position,
        equals(0),
        reason:
            'C4 is the reference note of the alto clef, on the center line',
      );
    });

    test(
      'C4 on tenor clef should be on the 4th line (staffPosition = 2)',
      () {
        final tenorClef = Clef(clefType: ClefType.tenor);
        final pitch = Pitch(step: 'C', octave: 4);
        final position = StaffPositionCalculator.calculate(pitch, tenorClef);

        expect(
          position,
          equals(2),
          reason: 'C4 is the reference note of the tenor clef, on the 4th line',
        );
      },
    );
  });

  group('StaffPositionCalculator - Ledger Lines', () {
    test(
      'needsLedgerLines should return false for notes within the staff',
      () {
        expect(StaffPositionCalculator.needsLedgerLines(0), isFalse);
        expect(StaffPositionCalculator.needsLedgerLines(2), isFalse);
        expect(StaffPositionCalculator.needsLedgerLines(-2), isFalse);
        expect(StaffPositionCalculator.needsLedgerLines(4), isFalse);
        expect(StaffPositionCalculator.needsLedgerLines(-4), isFalse);
      },
    );

    test(
      'needsLedgerLines should return true for notes outside the staff',
      () {
        expect(StaffPositionCalculator.needsLedgerLines(5), isTrue);
        expect(StaffPositionCalculator.needsLedgerLines(6), isTrue);
        expect(StaffPositionCalculator.needsLedgerLines(-5), isTrue);
        expect(StaffPositionCalculator.needsLedgerLines(-6), isTrue);
      },
    );

    test('getLedgerLinePositions should correctly calculate lines above', () {
      final lines = StaffPositionCalculator.getLedgerLinePositions(8);
      expect(lines, equals([6, 8]));
    });

    test('getLedgerLinePositions should correctly calculate lines below', () {
      final lines = StaffPositionCalculator.getLedgerLinePositions(-8);
      expect(lines, equals([-6, -8]));
    });

    test(
      'getLedgerLinePositions should include the note line if even',
      () {
        final lines = StaffPositionCalculator.getLedgerLinePositions(6);
        expect(lines.contains(6), isTrue);
      },
    );

    test(
      'getLedgerLinePositions should return empty for notes within the staff',
      () {
        final lines = StaffPositionCalculator.getLedgerLinePositions(2);
        expect(lines, isEmpty);
      },
    );
  });

  group('StaffPositionCalculator - Pixel Conversion', () {
    test('toPixelY should calculate correct Y for positive staffPosition', () {
      final staffSpace = 10.0;
      final staffBaseline = 100.0;

      // staffPosition = 2 (1 staff space above center)
      final y = StaffPositionCalculator.toPixelY(2, staffSpace, staffBaseline);

      expect(
        y,
        equals(90.0),
        reason: 'Positive staffPosition should result in smaller Y (above)',
      );
    });

    test('toPixelY should calculate correct Y for negative staffPosition', () {
      final staffSpace = 10.0;
      final staffBaseline = 100.0;

      // staffPosition = -2 (1 staff space below center)
      final y = StaffPositionCalculator.toPixelY(-2, staffSpace, staffBaseline);

      expect(
        y,
        equals(110.0),
        reason: 'Negative staffPosition should result in larger Y (below)',
      );
    });

    test('toPixelY should return baseline for staffPosition = 0', () {
      final staffSpace = 10.0;
      final staffBaseline = 100.0;

      final y = StaffPositionCalculator.toPixelY(0, staffSpace, staffBaseline);

      expect(
        y,
        equals(100.0),
        reason: 'staffPosition zero should be exactly at the baseline',
      );
    });
  });

  group('StaffPositionCalculator - Pitch Extension', () {
    test('staffPosition extension should work', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final pitch = Pitch(step: 'G', octave: 4);

      final position = pitch.staffPosition(trebleClef);

      expect(position, equals(-2));
    });

    test('needsLedgerLines extension should work', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final pitch = Pitch(step: 'C', octave: 5);

      final needs = pitch.needsLedgerLines(trebleClef);

      expect(needs, isFalse);
    });

    test('getLedgerLinePositions extension should work', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final pitch = Pitch(step: 'C', octave: 5);

      final lines = pitch.getLedgerLinePositions(trebleClef);

      expect(lines, isEmpty);
    });
  });

  group('StaffPositionCalculator - October Fix Validation', () {
    // CRITICAL TEST: Validates that the emergency fix of 01/10/2025
    // (documented in CORRECOES_CRITICAS_AppliesDAS.md) is correct

    test(
      'VALIDATION: Formula must not invert positions (addition, not subtraction)',
      () {
        final trebleClef = Clef(clefType: ClefType.treble);

        // If the formula were using subtraction (original bug),
        // higher notes would have SMALLER staffPosition
        final c4 = Pitch(step: 'C', octave: 4).staffPosition(trebleClef);
        final c5 = Pitch(step: 'C', octave: 5).staffPosition(trebleClef);

        expect(
          c5,
          greaterThan(c4),
          reason:
              'CRITICAL: C5 MUST be above C4. '
              'If this test fails, the coordinate system is inverted!',
        );
      },
    );

    test(
      'VALIDATION: Stem direction must be consistent with staffPosition',
      () {
        final trebleClef = Clef(clefType: ClefType.treble);

        // In treble clef, notes below center have stem up
        // negative staffPosition = below center = stem up
        final e4Pos = Pitch(step: 'E', octave: 4).staffPosition(trebleClef);
        expect(
          e4Pos,
          lessThan(0),
          reason:
              'E4 must be below center (staffPosition < 0) = stem up',
        );

        // B4 occupies the center line in treble clef
        final b4Pos = Pitch(step: 'B', octave: 4).staffPosition(trebleClef);
        expect(
          b4Pos,
          equals(0),
          reason: 'B4 must be on the center line (staffPosition = 0)',
        );
      },
    );
  });
}
