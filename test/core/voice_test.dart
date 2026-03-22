// test/core/voice_test.dart
// Comprehensive tests for Voice and polyphonic notation

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Voice - Construction', () {
    test('Creates voice with number', () {
      final voice = Voice(number: 1);

      expect(voice.number, equals(1));
      expect(voice.name, isNull);
    });

    test('Creates voice with number and name', () {
      final voice = Voice(number: 1, name: 'Soprano');

      expect(voice.number, equals(1));
      expect(voice.name, equals('Soprano'));
    });

    test('Creates voice 1 with factory', () {
      final voice = Voice.voice1();

      expect(voice.number, equals(1));
    });

    test('Creates voice 2 with factory', () {
      final voice = Voice.voice2();

      expect(voice.number, equals(2));
    });

    test('Creates voice 1 with custom name', () {
      final voice = Voice.voice1(name: 'Upper Voice');

      expect(voice.number, equals(1));
      expect(voice.name, equals('Upper Voice'));
    });

    test('Creates voice 2 with custom name', () {
      final voice = Voice.voice2(name: 'Lower Voice');

      expect(voice.number, equals(2));
      expect(voice.name, equals('Lower Voice'));
    });
  });

  group('Voice - Stem Direction', () {
    test('Voice 1 has stems up', () {
      final voice = Voice.voice1();
      final direction = voice.getStemDirection();

      expect(direction, equals(StemDirection.up));
    });

    test('Voice 2 has stems down', () {
      final voice = Voice.voice2();
      final direction = voice.getStemDirection();

      expect(direction, equals(StemDirection.down));
    });

    test('Voice 3 has stems up', () {
      final voice = Voice(number: 3);
      final direction = voice.getStemDirection();

      expect(direction, equals(StemDirection.up));
    });

    test('Voice 4 has stems down', () {
      final voice = Voice(number: 4);
      final direction = voice.getStemDirection();

      expect(direction, equals(StemDirection.down));
    });

    test('Odd-numbered voices have stems up', () {
      for (int i = 1; i <= 9; i += 2) {
        final voice = Voice(number: i);
        expect(voice.getStemDirection(), equals(StemDirection.up),
          reason: 'Voice $i should have stems up');
      }
    });

    test('Even-numbered voices have stems down', () {
      for (int i = 2; i <= 10; i += 2) {
        final voice = Voice(number: i);
        expect(voice.getStemDirection(), equals(StemDirection.down),
          reason: 'Voice $i should have stems down');
      }
    });
  });

  group('Voice - Horizontal Offset', () {
    const staffSpace = 10.0;

    test('Voice 1 has no horizontal offset', () {
      final voice = Voice.voice1();
      final offset = voice.getHorizontalOffset(staffSpace);

      expect(offset, equals(0.0));
    });

    test('Voice 2 has 0.6 staff spaces offset', () {
      final voice = Voice.voice2();
      final offset = voice.getHorizontalOffset(staffSpace);

      expect(offset, equals(6.0)); // 0.6 * 10.0
    });

    test('Voice 3 has 1.2 staff spaces offset', () {
      final voice = Voice(number: 3);
      final offset = voice.getHorizontalOffset(staffSpace);

      expect(offset, equals(12.0)); // 1.2 * 10.0
    });

    test('Voice 4 has 1.8 staff spaces offset', () {
      final voice = Voice(number: 4);
      final offset = voice.getHorizontalOffset(staffSpace);

      expect(offset, equals(18.0)); // 1.8 * 10.0
    });

    test('Offset increases by 0.6 staff spaces per voice', () {
      const staffSpace = 10.0;
      for (int i = 1; i <= 5; i++) {
        final voice = Voice(number: i);
        final offset = voice.getHorizontalOffset(staffSpace);
        final expectedOffset = (i - 1) * 0.6 * staffSpace;

        expect(offset, equals(expectedOffset),
          reason: 'Voice $i should have offset ${expectedOffset}px');
      }
    });
  });

  group('Voice - Element Management', () {
    test('Voice starts with empty elements', () {
      final voice = Voice.voice1();

      expect(voice.elements, isEmpty);
    });

    test('Add note to voice', () {
      final voice = Voice.voice1();
      final note = Note(
        pitch: Pitch(step: 'C', octave: 4),
        duration: Duration(DurationType.quarter),
      );

      voice.add(note);

      expect(voice.elements, hasLength(1));
      expect(voice.elements.first, equals(note));
    });

    test('Add multiple notes to voice', () {
      final voice = Voice.voice1();
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      for (final note in notes) {
        voice.add(note);
      }

      expect(voice.elements, hasLength(3));
    });

    test('Add chord to voice', () {
      final voice = Voice.voice1();
      final chord = Chord(
        notes: [
          Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
          Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        ],
        duration: Duration(DurationType.quarter),
      );

      voice.add(chord);

      expect(voice.elements, hasLength(1));
      expect(voice.elements.first, equals(chord));
    });

    test('Add rest to voice', () {
      final voice = Voice.voice1();
      final rest = Rest(duration: Duration(DurationType.quarter));

      voice.add(rest);

      expect(voice.elements, hasLength(1));
      expect(voice.elements.first, equals(rest));
    });

    test('Notes getter returns only notes', () {
      final voice = Voice.voice1();
      final note = Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter));
      final rest = Rest(duration: Duration(DurationType.quarter));
      final chord = Chord(
        notes: [Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter))],
        duration: Duration(DurationType.quarter),
      );

      voice.add(note);
      voice.add(rest);
      voice.add(chord);

      expect(voice.notes, hasLength(1));
      expect(voice.notes.first, equals(note));
    });
  });

  group('MultiVoiceMeasure - Construction', () {
    test('Creates empty multi-voice measure', () {
      final measure = MultiVoiceMeasure();

      expect(measure.voices, isEmpty);
      expect(measure.voiceCount, equals(0));
      expect(measure.isPolyphonic, isFalse);
    });

    test('Add voice to measure', () {
      final measure = MultiVoiceMeasure();
      final voice = Voice.voice1();
      voice.add(Note(
        pitch: Pitch(step: 'C', octave: 4),
        duration: Duration(DurationType.quarter),
      ));

      measure.addVoice(voice);

      expect(measure.voiceCount, equals(1));
      expect(measure.voices, contains(voice));
    });

    test('Two voices factory creates polyphonic measure', () {
      final voice1Elements = [
        Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)),
      ];
      final voice2Elements = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final measure = MultiVoiceMeasure.twoVoices(
        voice1Elements: voice1Elements,
        voice2Elements: voice2Elements,
      );

      expect(measure.voiceCount, equals(2));
      expect(measure.isPolyphonic, isTrue);
    });

    test('Three voices factory', () {
      final elements1 = [Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter))];
      final elements2 = [Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter))];
      final elements3 = [Note(pitch: Pitch(step: 'G', octave: 3), duration: Duration(DurationType.quarter))];

      final measure = MultiVoiceMeasure.threeVoices(
        voice1Elements: elements1,
        voice2Elements: elements2,
        voice3Elements: elements3,
      );

      expect(measure.voiceCount, equals(3));
      expect(measure.isPolyphonic, isTrue);
    });
  });

  group('MultiVoiceMeasure - Polyphonic Detection', () {
    test('Single voice is not polyphonic', () {
      final measure = MultiVoiceMeasure();
      final voice = Voice.voice1();
      voice.add(Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)));

      measure.addVoice(voice);

      expect(measure.isPolyphonic, isFalse);
    });

    test('Two voices is polyphonic', () {
      final measure = MultiVoiceMeasure();
      final voice1 = Voice.voice1();
      final voice2 = Voice.voice2();

      voice1.add(Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)));
      voice2.add(Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)));

      measure.addVoice(voice1);
      measure.addVoice(voice2);

      expect(measure.isPolyphonic, isTrue);
    });

    test('Three or more voices is polyphonic', () {
      final measure = MultiVoiceMeasure();
      for (int i = 1; i <= 3; i++) {
        final voice = Voice(number: i);
        voice.add(Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)));
        measure.addVoice(voice);
      }

      expect(measure.isPolyphonic, isTrue);
    });
  });

  group('MultiVoiceMeasure - Voice Access', () {
    test('Get voice by number', () {
      final measure = MultiVoiceMeasure();
      final voice1 = Voice.voice1();
      final voice2 = Voice.voice2();

      measure.addVoice(voice1);
      measure.addVoice(voice2);

      expect(measure.getVoice(1), equals(voice1));
      expect(measure.getVoice(2), equals(voice2));
    });

    test('Get non-existent voice returns null', () {
      final measure = MultiVoiceMeasure();

      expect(measure.getVoice(99), isNull);
    });

    test('sortedVoices returns voices in order', () {
      final measure = MultiVoiceMeasure();
      final voice3 = Voice(number: 3);
      final voice1 = Voice(number: 1);
      final voice2 = Voice(number: 2);

      // Add out of order
      measure.addVoice(voice3);
      measure.addVoice(voice1);
      measure.addVoice(voice2);

      final sorted = measure.sortedVoices;

      expect(sorted[0].number, equals(1));
      expect(sorted[1].number, equals(2));
      expect(sorted[2].number, equals(3));
    });
  });

  group('Voice - Musical Scenarios', () {
    test('Bach two-voice counterpoint', () {
      final measure = MultiVoiceMeasure();

      final upperVoice = Voice.voice1(name: 'Upper');
      upperVoice.add(Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)));
      upperVoice.add(Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.quarter)));
      upperVoice.add(Note(pitch: Pitch(step: 'B', octave: 4), duration: Duration(DurationType.quarter)));
      upperVoice.add(Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)));

      final lowerVoice = Voice.voice2(name: 'Lower');
      lowerVoice.add(Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)));
      lowerVoice.add(Note(pitch: Pitch(step: 'B', octave: 3), duration: Duration(DurationType.quarter)));
      lowerVoice.add(Note(pitch: Pitch(step: 'A', octave: 3), duration: Duration(DurationType.quarter)));
      lowerVoice.add(Note(pitch: Pitch(step: 'G', octave: 3), duration: Duration(DurationType.quarter)));

      measure.addVoice(upperVoice);
      measure.addVoice(lowerVoice);

      expect(measure.isPolyphonic, isTrue);
      expect(upperVoice.getStemDirection(), equals(StemDirection.up));
      expect(lowerVoice.getStemDirection(), equals(StemDirection.down));
      expect(lowerVoice.getHorizontalOffset(10.0), equals(6.0));
    });

    test('Piano texture with melody and chords', () {
      final measure = MultiVoiceMeasure();

      final melody = Voice.voice1(name: 'Melody');
      melody.add(Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.quarter)));
      melody.add(Note(pitch: Pitch(step: 'D', octave: 5), duration: Duration(DurationType.quarter)));

      final chords = Voice.voice2(name: 'Chords');
      chords.add(Chord(
        notes: [
          Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.half)),
          Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.half)),
          Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.half)),
        ],
        duration: Duration(DurationType.half),
      ));

      measure.addVoice(melody);
      measure.addVoice(chords);

      expect(measure.isPolyphonic, isTrue);
      expect(melody.notes, hasLength(2));
      expect(chords.elements, hasLength(1));
    });

    test('Guitar fingerstyle pattern', () {
      final measure = MultiVoiceMeasure();

      final treble = Voice.voice1(name: 'Melody');
      for (int i = 0; i < 4; i++) {
        treble.add(Note(
          pitch: Pitch(step: 'E', octave: 4),
          duration: Duration(DurationType.eighth),
        ));
      }

      final bass = Voice.voice2(name: 'Bass');
      bass.add(Note(pitch: Pitch(step: 'C', octave: 3), duration: Duration(DurationType.half)));

      measure.addVoice(treble);
      measure.addVoice(bass);

      expect(measure.isPolyphonic, isTrue);
      expect(treble.notes, hasLength(4));
      expect(bass.notes, hasLength(1));
    });
  });

  group('StemDirection Enum', () {
    test('StemDirection has all values', () {
      expect(StemDirection.up, isNotNull);
      expect(StemDirection.down, isNotNull);
      expect(StemDirection.auto, isNotNull);
    });

    test('StemDirection values are distinct', () {
      expect(StemDirection.up, isNot(equals(StemDirection.down)));
      expect(StemDirection.up, isNot(equals(StemDirection.auto)));
      expect(StemDirection.down, isNot(equals(StemDirection.auto)));
    });
  });
}
