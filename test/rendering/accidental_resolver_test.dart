// Within-measure accidental persistence (Behind Bars rule).

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Note note(String step, int octave, double alter) =>
      Note(pitch: Pitch(step: step, octave: octave, alter: alter),
          duration: const Duration(DurationType.quarter));

  Measure measureOf(List<MusicalElement> els) {
    final m = Measure();
    for (final e in els) {
      m.add(e);
    }
    return m;
  }

  group('AccidentalResolver', () {
    test('shows an accidental once per measure, hides repeats', () {
      final cs1 = note('C', 5, 1.0);
      final cs2 = note('C', 5, 1.0);
      final r = AccidentalResolver.resolve([
        measureOf([cs1, cs2]),
      ]);
      expect(r[cs1], AccidentalDisplay.show);
      expect(r[cs2], AccidentalDisplay.hide);
    });

    test('emits a natural when a pitch reverts mid-measure', () {
      final cs = note('C', 5, 1.0);
      final cn = note('C', 5, 0.0);
      final cn2 = note('C', 5, 0.0);
      final r = AccidentalResolver.resolve([
        measureOf([cs, cn, cn2]),
      ]);
      expect(r[cs], AccidentalDisplay.show);
      expect(r[cn], AccidentalDisplay.natural);
      expect(r[cn2], AccidentalDisplay.hide);
    });

    test('resets at the barline', () {
      final cs1 = note('C', 5, 1.0);
      final cs2 = note('C', 5, 1.0);
      final r = AccidentalResolver.resolve([
        measureOf([cs1]),
        measureOf([cs2]),
      ]);
      expect(r[cs1], AccidentalDisplay.show);
      expect(r[cs2], AccidentalDisplay.show); // new measure
    });

    test('a plain natural note in C major shows nothing', () {
      final c = note('C', 5, 0.0);
      final r = AccidentalResolver.resolve([
        measureOf([c]),
      ]);
      expect(r[c], AccidentalDisplay.hide);
    });

    test('key signature: key-sharp note hides, reverting note gets natural', () {
      // G major (1 sharp = F#).
      final fSharp = note('F', 5, 1.0); // matches key -> no accidental
      final fNat = note('F', 5, 0.0); // contradicts key -> natural
      final r = AccidentalResolver.resolve([
        measureOf([KeySignature(1), fSharp, fNat]),
      ]);
      expect(r[fSharp], AccidentalDisplay.hide);
      expect(r[fNat], AccidentalDisplay.natural);
    });

    test('octave-specific: same letter different octave is independent', () {
      final f5 = note('F', 5, 1.0);
      final f4 = note('F', 4, 1.0);
      final r = AccidentalResolver.resolve([
        measureOf([f5, f4]),
      ]);
      expect(r[f5], AccidentalDisplay.show);
      expect(r[f4], AccidentalDisplay.show); // different octave
    });

    test('chord notes participate in measure state', () {
      final chordCs = Note(
          pitch: const Pitch(step: 'C', octave: 5, alter: 1.0),
          duration: const Duration(DurationType.quarter));
      final laterCs = note('C', 5, 1.0);
      final chord = Chord(
        notes: [
          chordCs,
          Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.quarter)),
        ],
        duration: const Duration(DurationType.quarter),
      );
      final r = AccidentalResolver.resolve([
        measureOf([chord, laterCs]),
      ]);
      expect(r[chordCs], AccidentalDisplay.show);
      expect(r[laterCs], AccidentalDisplay.hide); // chord set the state
    });
  });
}
