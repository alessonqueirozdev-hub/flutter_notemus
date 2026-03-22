// test/core/chord_test.dart
// Comprehensive tests for Chord model

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Chord - Basic Construction', () {
    test('Creates chord with multiple notes', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
      );

      expect(chord.notes, hasLength(3));
      expect(chord.duration.type, equals(DurationType.quarter));
      expect(chord.articulations, isEmpty);
      expect(chord.tie, isNull);
      expect(chord.slur, isNull);
      expect(chord.beam, isNull);
      expect(chord.ornaments, isEmpty);
      expect(chord.dynamic, isNull);
      expect(chord.voice, isNull);
    });

    test('Creates chord with two notes (dyad)', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.half)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.half)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.half),
      );

      expect(chord.notes, hasLength(2));
    });

    test('Creates chord with four notes', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'B', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
      );

      expect(chord.notes, hasLength(4));
    });

    test('Creates chord with articulations', () {
      final notes = [
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
        articulations: [ArticulationType.staccato, ArticulationType.accent],
      );

      expect(chord.articulations, hasLength(2));
      expect(chord.articulations, contains(ArticulationType.staccato));
      expect(chord.articulations, contains(ArticulationType.accent));
    });

    test('Creates chord with dynamic', () {
      final notes = [
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'B', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
        dynamic: Dynamic(type: DynamicType.forte),
      );

      expect(chord.dynamic, isNotNull);
      expect(chord.dynamic!.type, equals(DynamicType.forte));
    });

    test('Creates chord with voice number', () {
      final notes = [
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
        voice: 2,
      );

      expect(chord.voice, equals(2));
    });
  });

  group('Chord - Common Musical Chords', () {
    test('C major triad', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      // C major = C, E, G (MIDI 60, 64, 67)
      expect(chord.notes[0].pitch.midiNumber, equals(60)); // C4
      expect(chord.notes[1].pitch.midiNumber, equals(64)); // E4
      expect(chord.notes[2].pitch.midiNumber, equals(67)); // G4
    });

    test('D minor triad', () {
      final notes = [
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      // D minor = D, F, A (MIDI 62, 65, 69)
      expect(chord.notes[0].pitch.midiNumber, equals(62)); // D4
      expect(chord.notes[1].pitch.midiNumber, equals(65)); // F4
      expect(chord.notes[2].pitch.midiNumber, equals(69)); // A4
    });

    test('G7 chord (dominant seventh)', () {
      final notes = [
        Note(pitch: Pitch(step: 'G', octave: 3), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'B', octave: 3), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      expect(chord.notes, hasLength(4));
      expect(chord.notes[0].pitch.step, equals('G'));
      expect(chord.notes[1].pitch.step, equals('B'));
      expect(chord.notes[2].pitch.step, equals('D'));
      expect(chord.notes[3].pitch.step, equals('F'));
    });

    test('Power chord (dyad)', () {
      final notes = [
        Note(pitch: Pitch(step: 'A', octave: 3), duration: Duration(DurationType.half)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.half)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.half));

      expect(chord.notes, hasLength(2));
      // Perfect fifth interval = 7 semitones
      final interval = chord.notes[1].pitch.midiNumber - chord.notes[0].pitch.midiNumber;
      expect(interval, equals(7));
    });
  });

  group('Chord - Highest and Lowest Notes', () {
    test('highestNote returns correct note', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      expect(chord.highestNote.pitch.step, equals('C'));
      expect(chord.highestNote.pitch.octave, equals(5));
      expect(chord.highestNote.pitch.midiNumber, equals(72));
    });

    test('lowestNote returns correct note', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 3), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      expect(chord.lowestNote.pitch.step, equals('C'));
      expect(chord.lowestNote.pitch.octave, equals(3));
      expect(chord.lowestNote.pitch.midiNumber, equals(48));
    });

    test('highestNote and lowestNote work with two notes', () {
      final notes = [
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      expect(chord.lowestNote.pitch.step, equals('D'));
      expect(chord.highestNote.pitch.step, equals('A'));
    });

    test('Chord span calculation', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 3), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      final span = chord.highestNote.pitch.midiNumber - chord.lowestNote.pitch.midiNumber;
      expect(span, equals(24)); // 2 octaves = 24 semitones
    });
  });

  group('Chord - With Accidentals', () {
    test('Chord with sharps', () {
      final notes = [
        Note(
          pitch: Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.sharp),
          duration: Duration(DurationType.quarter),
        ),
        Note(
          pitch: Pitch(step: 'A', octave: 4, accidentalType: AccidentalType.sharp),
          duration: Duration(DurationType.quarter),
        ),
        Note(
          pitch: Pitch(step: 'C', octave: 5, accidentalType: AccidentalType.sharp),
          duration: Duration(DurationType.quarter),
        ),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      expect(chord.notes[0].pitch.accidentalType, equals(AccidentalType.sharp));
      expect(chord.notes[1].pitch.accidentalType, equals(AccidentalType.sharp));
      expect(chord.notes[2].pitch.accidentalType, equals(AccidentalType.sharp));
    });

    test('Chord with mixed accidentals', () {
      final notes = [
        Note(
          pitch: Pitch(step: 'E', octave: 4, accidentalType: AccidentalType.flat),
          duration: Duration(DurationType.quarter),
        ),
        Note(
          pitch: Pitch(step: 'G', octave: 4), // Natural
          duration: Duration(DurationType.quarter),
        ),
        Note(
          pitch: Pitch(step: 'B', octave: 4, accidentalType: AccidentalType.flat),
          duration: Duration(DurationType.quarter),
        ),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      expect(chord.notes[0].pitch.accidentalType, equals(AccidentalType.flat));
      expect(chord.notes[1].pitch.accidentalType, isNull);
      expect(chord.notes[2].pitch.accidentalType, equals(AccidentalType.flat));
    });
  });

  group('Chord - Duration and Rhythm', () {
    test('Whole note chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.whole)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.whole)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.whole)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.whole));

      expect(chord.duration.type, equals(DurationType.whole));
      expect(chord.duration.type.value, equals(1.0));
    });

    test('Dotted half note chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.half, dots: 1)),
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.half, dots: 1)),
        Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.half, dots: 1)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.half, dots: 1));

      expect(chord.duration.dots, equals(1));
      expect(chord.duration.absoluteValue, equals(0.75));
    });

    test('Eighth note chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.eighth)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.eighth)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.eighth));

      expect(chord.duration.type, equals(DurationType.eighth));
      expect(chord.duration.type.needsFlag, isTrue);
    });
  });

  group('Chord - Beaming', () {
    test('Beamed chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.eighth)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.eighth)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.eighth)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.eighth),
        beam: BeamType.start,
      );

      expect(chord.beam, equals(BeamType.start));
    });

    test('Multiple beamed chords form group', () {
      final notes1 = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.eighth)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.eighth)),
      ];

      final notes2 = [
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.eighth)),
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.eighth)),
      ];

      final chord1 = Chord(
        notes: notes1,
        duration: Duration(DurationType.eighth),
        beam: BeamType.start,
      );

      final chord2 = Chord(
        notes: notes2,
        duration: Duration(DurationType.eighth),
        beam: BeamType.end,
      );

      expect(chord1.beam, equals(BeamType.start));
      expect(chord2.beam, equals(BeamType.end));
    });
  });

  group('Chord - Ties', () {
    test('Tied chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.half)),
        Note(pitch: Pitch(step: 'B', octave: 4), duration: Duration(DurationType.half)),
        Note(pitch: Pitch(step: 'D', octave: 5), duration: Duration(DurationType.half)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.half),
        tie: TieType.start,
      );

      expect(chord.tie, equals(TieType.start));
    });
  });

  group('Chord - Slurs', () {
    test('Slurred chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
        slur: SlurType.start,
      );

      expect(chord.slur, equals(SlurType.start));
    });
  });

  group('Chord - Ornaments', () {
    test('Chord with arpeggio', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.arpeggio)],
      );

      expect(chord.ornaments, hasLength(1));
      expect(chord.ornaments.first.type, equals(OrnamentType.arpeggio));
    });

    test('Chord with fermata', () {
      final notes = [
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.whole)),
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.whole)),
        Note(pitch: Pitch(step: 'A', octave: 4), duration: Duration(DurationType.whole)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.whole),
        ornaments: [Ornament(type: OrnamentType.fermata)],
      );

      expect(chord.ornaments.first.type, equals(OrnamentType.fermata));
    });
  });

  group('Chord - Polyphonic (Voices)', () {
    test('Chord in voice 1', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 5), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 5), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.quarter),
        voice: 1,
      );

      expect(chord.voice, equals(1));
    });

    test('Chord in voice 2', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 3), duration: Duration(DurationType.half)),
        Note(pitch: Pitch(step: 'G', octave: 3), duration: Duration(DurationType.half)),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.half),
        voice: 2,
      );

      expect(chord.voice, equals(2));
    });
  });

  group('Chord - Complex Scenarios', () {
    test('Dense cluster chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'D', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'E', octave: 4), duration: Duration(DurationType.quarter)),
        Note(pitch: Pitch(step: 'F', octave: 4), duration: Duration(DurationType.quarter)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.quarter));

      // All notes within one major third span
      final span = chord.highestNote.pitch.midiNumber - chord.lowestNote.pitch.midiNumber;
      expect(span, equals(5)); // F4 - C4 = 5 semitones
    });

    test('Wide spread chord', () {
      final notes = [
        Note(pitch: Pitch(step: 'C', octave: 2), duration: Duration(DurationType.whole)),
        Note(pitch: Pitch(step: 'G', octave: 4), duration: Duration(DurationType.whole)),
        Note(pitch: Pitch(step: 'C', octave: 6), duration: Duration(DurationType.whole)),
      ];

      final chord = Chord(notes: notes, duration: Duration(DurationType.whole));

      final span = chord.highestNote.pitch.midiNumber - chord.lowestNote.pitch.midiNumber;
      expect(span, greaterThan(36)); // More than 3 octaves
    });

    test('Chord with all properties', () {
      final notes = [
        Note(
          pitch: Pitch(step: 'F', octave: 4, accidentalType: AccidentalType.sharp),
          duration: Duration(DurationType.eighth),
        ),
        Note(
          pitch: Pitch(step: 'A', octave: 4, accidentalType: AccidentalType.sharp),
          duration: Duration(DurationType.eighth),
        ),
        Note(
          pitch: Pitch(step: 'C', octave: 5, accidentalType: AccidentalType.sharp),
          duration: Duration(DurationType.eighth),
        ),
      ];

      final chord = Chord(
        notes: notes,
        duration: Duration(DurationType.eighth),
        articulations: [ArticulationType.accent],
        tie: TieType.start,
        slur: SlurType.start,
        beam: BeamType.start,
        ornaments: [Ornament(type: OrnamentType.arpeggio)],
        dynamic: Dynamic(type: DynamicType.forte),
        voice: 1,
      );

      expect(chord.notes, hasLength(3));
      expect(chord.articulations, isNotEmpty);
      expect(chord.tie, isNotNull);
      expect(chord.slur, isNotNull);
      expect(chord.beam, isNotNull);
      expect(chord.ornaments, isNotEmpty);
      expect(chord.dynamic, isNotNull);
      expect(chord.voice, equals(1));
    });
  });
}
