// test/core/key_signature_spelling_test.dart
//
// The trap this guards against caught this package's own flagship example.
//
// `Pitch.alter` is the SOUNDING alteration (ADR-003) and defaults to 0.0, so
// `Pitch(step: 'F', octave: 5)` is an F NATURAL whatever the key signature
// says. `complete_music_piece.dart` is in D major and built every note that
// way, so the engraver printed a natural in front of nearly every F and C —
// correctly, because that is what the model asked for. A reviewer reported it
// as an engraving bug; measured, the resolver was right the whole time and the
// score was wrong.
//
// `KeySignature.alterFor` / `KeySignature.pitch` exist so that spelling a note
// in its own key is the short way to write it rather than the thing you have to
// remember.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  test('a D-major phrase spelled in key prints no accidental at all', () {
    final key = KeySignature(2);
    Staff build({required bool inKey}) => Staff(measures: [
          Measure()
            ..elements.addAll([
              Clef(clefType: ClefType.treble),
              KeySignature(2),
              TimeSignature(numerator: 4, denominator: 4),
              for (final s in ['F', 'G', 'A', 'C'])
                Note(
                  pitch: inKey
                      ? key.pitch(s, 5)
                      : Pitch(step: s, octave: 5),
                  duration: const MusicDuration(DurationType.quarter),
                ),
            ])
        ]);

    for (final inKey in [false, true]) {
      final engine = LayoutEngine(build(inKey: inKey),
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      final elements = engine.layout();
      final printed = <String>[];
      for (final e in elements) {
        final el = e.element;
        if (el is Note) {
          final d = engine.accidentalDecisions[el];
          if (d != null && d != AccidentalDisplay.hide) {
            printed.add('${el.pitch.step}=$d');
          }
        }
      }
      // ignore: avoid_print
      print('inKey=$inKey  accidentals printed: '
          '${printed.isEmpty ? "(none)" : printed.join(", ")}');
    }
    expect(key.alterFor('F'), 1.0);
    expect(key.alterFor('C'), 1.0);
    expect(key.alterFor('G'), 0.0);
    expect(KeySignature(-2).alterFor('B'), -1.0);
    expect(KeySignature(-2).alterFor('E'), -1.0);
    expect(KeySignature(0).alterFor('F'), 0.0);
  });
}
