// Regression coverage for issue #12:
// Chord elements must surface Note.syllables. ChordRenderer.lyricNoteFor picks
// the note that carries the chord's single lyric line.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/chord_renderer.dart';

void main() {
  group('ChordRenderer.lyricNoteFor (issue #12)', () {
    test('returns the first note that carries syllables', () {
      final lyricNote = Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
        syllables: const [Syllable(text: 'la', type: SyllableType.single)],
      );
      final chord = Chord(
        notes: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
          lyricNote,
          Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.quarter),
            syllables: const [Syllable(text: 'da', type: SyllableType.single)],
          ),
        ],
        duration: const Duration(DurationType.quarter),
      );

      final picked = ChordRenderer.lyricNoteFor(chord);
      expect(picked, same(lyricNote));
      expect(picked!.syllables!.single.text, 'la');
    });

    test('returns null when no chord note has syllables', () {
      final chord = Chord(
        notes: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        ],
        duration: const Duration(DurationType.quarter),
      );

      expect(ChordRenderer.lyricNoteFor(chord), isNull);
    });

    test('ignores notes whose syllable list is empty', () {
      final chord = Chord(
        notes: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
            syllables: const [],
          ),
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter),
            syllables: const [
              Syllable(text: 'sol', type: SyllableType.single),
            ],
          ),
        ],
        duration: const Duration(DurationType.quarter),
      );

      final picked = ChordRenderer.lyricNoteFor(chord);
      expect(picked, isNotNull);
      expect(picked!.syllables!.single.text, 'sol');
    });
  });
}
