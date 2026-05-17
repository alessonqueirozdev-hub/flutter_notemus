// Coverage for the Jianpu pitch mapper (issue #24, GB/T 46845-2025 §6.2):
// movable-do numerals, octave dots, diatonic accidental spelling.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('JianpuPitchMapper — C major (1=C)', () {
    final mapper = JianpuPitchMapper(0);

    test('diatonic scale C4..B4 maps to 1..7 with no octave dots', () {
      final expected = {
        'C': '1',
        'D': '2',
        'E': '3',
        'F': '4',
        'G': '5',
        'A': '6',
        'B': '7',
      };
      expected.forEach((step, numeral) {
        final j = mapper.map(Pitch(step: step, octave: 4));
        expect(j.numeral, numeral, reason: '${step}4');
        expect(j.accidental, '');
        expect(j.octaveDots, 0, reason: '${step}4 should be central octave');
      });
    });

    test('octave register produces dots above/below', () {
      expect(mapper.map(const Pitch(step: 'C', octave: 5)).octaveDots, 1);
      expect(mapper.map(const Pitch(step: 'C', octave: 3)).octaveDots, -1);
      expect(mapper.map(const Pitch(step: 'C', octave: 6)).octaveDots, 2);
    });

    test('chromatic F# is spelled ♯4 (raised 4th degree)', () {
      final j = mapper.map(const Pitch(step: 'F', octave: 4, alter: 1.0));
      expect(j.numeral, '4');
      expect(j.accidental, '♯');
    });
  });

  group('JianpuPitchMapper.fromKeySignature', () {
    test('D major (2 sharps): tonic D maps to 1, name "D"', () {
      final mapper = JianpuPitchMapper.fromKeySignature(KeySignature(2));
      expect(mapper.tonicName, 'D');
      final j = mapper.map(const Pitch(step: 'D', octave: 4));
      expect(j.numeral, '1');
      expect(j.accidental, '');
      expect(j.octaveDots, 0);
      // The 5th of D (A4) is degree 5.
      expect(mapper.map(const Pitch(step: 'A', octave: 4)).numeral, '5');
    });

    test('Eb major (3 flats): tonic Eb maps to 1, name "Eb"', () {
      final mapper = JianpuPitchMapper.fromKeySignature(KeySignature(-3));
      expect(mapper.tonicName, 'Eb');
      final j = mapper.map(const Pitch(step: 'E', octave: 4, alter: -1.0));
      expect(j.numeral, '1');
      expect(j.accidental, '');
      expect(j.octaveDots, 0);
    });

    test('G major: a natural F cancels the key sharp → ♮7', () {
      final mapper = JianpuPitchMapper.fromKeySignature(KeySignature(1));
      expect(mapper.tonicName, 'G');
      // F# is diatonic in G (leading tone, degree 7, no accidental).
      final fSharp =
          mapper.map(const Pitch(step: 'F', octave: 4, alter: 1.0));
      expect(fSharp.numeral, '7');
      expect(fSharp.accidental, '');
      // F natural lowers the leading tone → natural sign on degree 7.
      final fNatural = mapper.map(const Pitch(step: 'F', octave: 4));
      expect(fNatural.numeral, '7');
      expect(fNatural.accidental, '♮');
    });
  });
}
