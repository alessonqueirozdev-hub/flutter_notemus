// test/core/pitch_test.dart
// Comprehensive tests for Pitch model

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Pitch - Basic Construction', () {
    test('Creates pitch with step and octave', () {
      final pitch = Pitch(step: 'C', octave: 4);

      expect(pitch.step, equals('C'));
      expect(pitch.octave, equals(4));
      expect(pitch.accidentalType, isNull);
    });

    test('Creates pitch with accidental', () {
      final pitch = Pitch(
        step: 'F',
        octave: 5,
        accidentalType: AccidentalType.sharp,
      );

      expect(pitch.step, equals('F'));
      expect(pitch.octave, equals(5));
      expect(pitch.accidentalType, equals(AccidentalType.sharp));
    });

    test('Creates pitch with all accidental types', () {
      final sharp = Pitch(step: 'C', octave: 4, accidentalType: AccidentalType.sharp);
      final flat = Pitch(step: 'D', octave: 4, accidentalType: AccidentalType.flat);
      final natural = Pitch(step: 'E', octave: 4, accidentalType: AccidentalType.natural);
      final doubleSharp = Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.doubleSharp);
      final doubleFlat = Pitch(step: 'G', octave: 4, accidentalType: AccidentalType.doubleFlat);

      expect(sharp.accidentalType, equals(AccidentalType.sharp));
      expect(flat.accidentalType, equals(AccidentalType.flat));
      expect(natural.accidentalType, equals(AccidentalType.natural));
      expect(doubleSharp.accidentalType, equals(AccidentalType.doubleSharp));
      expect(doubleFlat.accidentalType, equals(AccidentalType.doubleFlat));
    });
  });

  group('Pitch - MIDI Number Calculation', () {
    test('Middle C (C4) is MIDI 60', () {
      final pitch = Pitch(step: 'C', octave: 4);
      expect(pitch.midiNumber, equals(60));
    });

    test('A4 (concert pitch) is MIDI 69', () {
      final pitch = Pitch(step: 'A', octave: 4);
      expect(pitch.midiNumber, equals(69));
    });

    test('C0 is MIDI 12', () {
      final pitch = Pitch(step: 'C', octave: 0);
      expect(pitch.midiNumber, equals(12));
    });

    test('C8 is MIDI 108', () {
      final pitch = Pitch(step: 'C', octave: 8);
      expect(pitch.midiNumber, equals(108));
    });

    test('Sharps increase MIDI number by 1', () {
      final c4 = Pitch(step: 'C', octave: 4);
      final cSharp4 = Pitch(step: 'C', octave: 4, accidentalType: AccidentalType.sharp);

      expect(cSharp4.midiNumber, equals(c4.midiNumber + 1));
    });

    test('Flats decrease MIDI number by 1', () {
      final d4 = Pitch(step: 'D', octave: 4);
      final dFlat4 = Pitch(step: 'D', octave: 4, accidentalType: AccidentalType.flat);

      expect(dFlat4.midiNumber, equals(d4.midiNumber - 1));
    });

    test('Double sharps increase MIDI number by 2', () {
      final c4 = Pitch(step: 'C', octave: 4);
      final cDoubleSharp4 = Pitch(step: 'C', octave: 4, accidentalType: AccidentalType.doubleSharp);

      expect(cDoubleSharp4.midiNumber, equals(c4.midiNumber + 2));
    });

    test('Double flats decrease MIDI number by 2', () {
      final d4 = Pitch(step: 'D', octave: 4);
      final dDoubleFlat4 = Pitch(step: 'D', octave: 4, accidentalType: AccidentalType.doubleFlat);

      expect(dDoubleFlat4.midiNumber, equals(d4.midiNumber - 2));
    });

    test('Chromatic scale has ascending MIDI numbers', () {
      final scale = [
        Pitch(step: 'C', octave: 4),
        Pitch(step: 'C', octave: 4, accidentalType: AccidentalType.sharp),
        Pitch(step: 'D', octave: 4),
        Pitch(step: 'D', octave: 4, accidentalType: AccidentalType.sharp),
        Pitch(step: 'E', octave: 4),
        Pitch(step: 'F', octave: 4),
        Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.sharp),
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'G', octave: 4, accidentalType: AccidentalType.sharp),
        Pitch(step: 'A', octave: 4),
        Pitch(step: 'A', octave: 4, accidentalType: AccidentalType.sharp),
        Pitch(step: 'B', octave: 4),
        Pitch(step: 'C', octave: 5),
      ];

      for (int i = 1; i < scale.length; i++) {
        expect(scale[i].midiNumber, equals(scale[i - 1].midiNumber + 1),
          reason: '${scale[i].step}${scale[i].octave} should be 1 semitone above ${scale[i-1].step}${scale[i-1].octave}');
      }
    });
  });

  group('Pitch - Enharmonic Equivalents', () {
    test('C# and Db have same MIDI number', () {
      final cSharp = Pitch(step: 'C', octave: 4, accidentalType: AccidentalType.sharp);
      final dFlat = Pitch(step: 'D', octave: 4, accidentalType: AccidentalType.flat);

      expect(cSharp.midiNumber, equals(dFlat.midiNumber));
    });

    test('F# and Gb have same MIDI number', () {
      final fSharp = Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.sharp);
      final gFlat = Pitch(step: 'G', octave: 4, accidentalType: AccidentalType.flat);

      expect(fSharp.midiNumber, equals(gFlat.midiNumber));
    });

    test('E# and F natural have same MIDI number', () {
      final eSharp = Pitch(step: 'E', octave: 4, accidentalType: AccidentalType.sharp);
      final fNatural = Pitch(step: 'F', octave: 4);

      expect(eSharp.midiNumber, equals(fNatural.midiNumber));
    });

    test('Cb and B natural have same MIDI number', () {
      final cFlat = Pitch(step: 'C', octave: 4, accidentalType: AccidentalType.flat);
      final bNatural = Pitch(step: 'B', octave: 3);

      expect(cFlat.midiNumber, equals(bNatural.midiNumber));
    });
  });

  group('Pitch - SMuFL Accidental Glyphs', () {
    test('Sharp returns correct glyph', () {
      final pitch = Pitch(step: 'C', octave: 4, accidentalType: AccidentalType.sharp);
      expect(pitch.accidentalGlyph, equals('accidentalSharp'));
    });

    test('Flat returns correct glyph', () {
      final pitch = Pitch(step: 'D', octave: 4, accidentalType: AccidentalType.flat);
      expect(pitch.accidentalGlyph, equals('accidentalFlat'));
    });

    test('Natural returns correct glyph', () {
      final pitch = Pitch(step: 'E', octave: 4, accidentalType: AccidentalType.natural);
      expect(pitch.accidentalGlyph, equals('accidentalNatural'));
    });

    test('Double sharp returns correct glyph', () {
      final pitch = Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.doubleSharp);
      expect(pitch.accidentalGlyph, equals('accidentalDoubleSharp'));
    });

    test('Double flat returns correct glyph', () {
      final pitch = Pitch(step: 'G', octave: 4, accidentalType: AccidentalType.doubleFlat);
      expect(pitch.accidentalGlyph, equals('accidentalDoubleFlat'));
    });

    test('No accidental returns null', () {
      final pitch = Pitch(step: 'A', octave: 4);
      expect(pitch.accidentalGlyph, isNull);
    });
  });

  group('Pitch - Validation', () {
    test('All valid steps (A-G) are accepted', () {
      for (final step in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
        final pitch = Pitch(step: step, octave: 4);
        expect(pitch.step, equals(step));
      }
    });

    test('Valid octave range (0-8)', () {
      for (int octave = 0; octave <= 8; octave++) {
        final pitch = Pitch(step: 'C', octave: octave);
        expect(pitch.octave, equals(octave));
      }
    });
  });

  group('Pitch - Musical Theory', () {
    test('Octave changes correctly from B to C', () {
      final b3 = Pitch(step: 'B', octave: 3);
      final c4 = Pitch(step: 'C', octave: 4);

      // C4 is one semitone above B3
      expect(c4.midiNumber, equals(b3.midiNumber + 1));
    });

    test('Major third (C-E) is 4 semitones', () {
      final c4 = Pitch(step: 'C', octave: 4);
      final e4 = Pitch(step: 'E', octave: 4);

      expect(e4.midiNumber - c4.midiNumber, equals(4));
    });

    test('Perfect fifth (C-G) is 7 semitones', () {
      final c4 = Pitch(step: 'C', octave: 4);
      final g4 = Pitch(step: 'G', octave: 4);

      expect(g4.midiNumber - c4.midiNumber, equals(7));
    });

    test('Octave interval is 12 semitones', () {
      final c4 = Pitch(step: 'C', octave: 4);
      final c5 = Pitch(step: 'C', octave: 5);

      expect(c5.midiNumber - c4.midiNumber, equals(12));
    });
  });

  group('Pitch - Staff Position Integration', () {
    test('staffPosition extension works with treble clef', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final g4 = Pitch(step: 'G', octave: 4);

      final position = g4.staffPosition(trebleClef);
      expect(position, equals(-2), reason: 'G4 is on second line of treble clef');
    });

    test('needsLedgerLines extension works', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final c4 = Pitch(step: 'C', octave: 4); // Below staff
      final e4 = Pitch(step: 'E', octave: 4); // On staff

      expect(c4.needsLedgerLines(trebleClef), isTrue);
      expect(e4.needsLedgerLines(trebleClef), isFalse);
    });
  });

  group('Pitch - Edge Cases', () {
    test('Lowest MIDI note (C-1 adjusted) behaves correctly', () {
      final c0 = Pitch(step: 'C', octave: 0);
      expect(c0.midiNumber, greaterThanOrEqualTo(0));
    });

    test('Highest MIDI note (G9 or C8) behaves correctly', () {
      final c8 = Pitch(step: 'C', octave: 8);
      expect(c8.midiNumber, lessThanOrEqualTo(127));
    });

    test('Natural accidental cancels previous accidental', () {
      // In musical notation, natural cancels sharp or flat
      final fSharp = Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.sharp);
      final fNatural = Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.natural);
      final fPlain = Pitch(step: 'F', octave: 4);

      // Natural and no accidental should have same MIDI number
      expect(fNatural.midiNumber, equals(fPlain.midiNumber));
      expect(fSharp.midiNumber, equals(fNatural.midiNumber + 1));
    });
  });
}
