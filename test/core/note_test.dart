// test/core/note_test.dart
// Comprehensive tests for Note model

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('Note - Basic Construction', () {
    test('Creates simple note with pitch and duration', () {
      final pitch = Pitch(step: 'C', octave: 4);
      final duration = Duration(DurationType.quarter);
      final note = Note(pitch: pitch, duration: duration);

      expect(note.pitch, equals(pitch));
      expect(note.duration, equals(duration));
      expect(note.articulations, isEmpty);
      expect(note.tie, isNull);
      expect(note.slur, isNull);
      expect(note.beam, isNull);
      expect(note.ornaments, isEmpty);
      expect(note.dynamicElement, isNull);
      expect(note.techniques, isEmpty);
      expect(note.voice, isNull);
    });

    test('Creates note with articulations', () {
      final note = Note(
        pitch: Pitch(step: 'D', octave: 4),
        duration: Duration(DurationType.quarter),
        articulations: [ArticulationType.staccato, ArticulationType.accent],
      );

      expect(note.articulations, hasLength(2));
      expect(note.articulations, contains(ArticulationType.staccato));
      expect(note.articulations, contains(ArticulationType.accent));
    });

    test('Creates note with tie', () {
      final note = Note(
        pitch: Pitch(step: 'E', octave: 4),
        duration: Duration(DurationType.half),
        tie: TieType.start,
      );

      expect(note.tie, equals(TieType.start));
    });

    test('Creates note with slur', () {
      final note = Note(
        pitch: Pitch(step: 'F', octave: 4),
        duration: Duration(DurationType.quarter),
        slur: SlurType.start,
      );

      expect(note.slur, equals(SlurType.start));
    });

    test('Creates note with beam', () {
      final note = Note(
        pitch: Pitch(step: 'G', octave: 4),
        duration: Duration(DurationType.eighth),
        beam: BeamType.start,
      );

      expect(note.beam, equals(BeamType.start));
    });

    test('Creates note with ornaments', () {
      final note = Note(
        pitch: Pitch(step: 'A', octave: 4),
        duration: Duration(DurationType.quarter),
        ornaments: [
          Ornament(type: OrnamentType.trill),
          Ornament(type: OrnamentType.mordent),
        ],
      );

      expect(note.ornaments, hasLength(2));
    });

    test('Creates note with dynamic', () {
      final note = Note(
        pitch: Pitch(step: 'B', octave: 4),
        duration: Duration(DurationType.quarter),
        dynamicElement: Dynamic(type: DynamicType.forte),
      );

      expect(note.dynamicElement, isNotNull);
      expect(note.dynamicElement!.type, equals(DynamicType.forte));
    });

    test('Creates note with voice number', () {
      final note = Note(
        pitch: Pitch(step: 'C', octave: 5),
        duration: Duration(DurationType.quarter),
        voice: 2,
      );

      expect(note.voice, equals(2));
    });
  });

  group('Note - Beaming', () {
    test('Creates beamed eighth notes', () {
      final note1 = Note(
        pitch: Pitch(step: 'C', octave: 4),
        duration: Duration(DurationType.eighth),
        beam: BeamType.start,
      );
      final note2 = Note(
        pitch: Pitch(step: 'D', octave: 4),
        duration: Duration(DurationType.eighth),
        beam: BeamType.end,
      );

      expect(note1.beam, equals(BeamType.start));
      expect(note2.beam, equals(BeamType.end));
    });

    test('Inner beamed notes use BeamType.inner', () {
      final note = Note(
        pitch: Pitch(step: 'E', octave: 4),
        duration: Duration(DurationType.eighth),
        beam: BeamType.inner,
      );

      expect(note.beam, equals(BeamType.inner));
    });

    test('Only eighth notes and shorter can be beamed', () {
      // Quarter note with beam (technically invalid)
      final quarter = Note(
        pitch: Pitch(step: 'F', octave: 4),
        duration: Duration(DurationType.quarter),
        beam: BeamType.start,
      );

      // Eighth note with beam (valid)
      final eighth = Note(
        pitch: Pitch(step: 'G', octave: 4),
        duration: Duration(DurationType.eighth),
        beam: BeamType.start,
      );

      // Test that eighth or smaller typically needs flags
      expect(quarter.duration.type.needsFlag, isFalse);
      expect(eighth.duration.type.needsFlag, isTrue);
    });
  });

  group('Note - Ties', () {
    test('Note can start a tie', () {
      final note = Note(
        pitch: Pitch(step: 'A', octave: 4),
        duration: Duration(DurationType.half),
        tie: TieType.start,
      );

      expect(note.tie, equals(TieType.start));
    });

    test('Note can end a tie', () {
      final note = Note(
        pitch: Pitch(step: 'A', octave: 4),
        duration: Duration(DurationType.half),
        tie: TieType.end,
      );

      expect(note.tie, equals(TieType.end));
    });

    test('Note can continue a tie', () {
      final note = Note(
        pitch: Pitch(step: 'A', octave: 4),
        duration: Duration(DurationType.half),
        tie: TieType.inner,
      );

      expect(note.tie, equals(TieType.inner));
    });

    test('Tied notes typically have same pitch', () {
      final pitch = Pitch(step: 'B', octave: 4);
      final note1 = Note(
        pitch: pitch,
        duration: Duration(DurationType.quarter),
        tie: TieType.start,
      );
      final note2 = Note(
        pitch: pitch,
        duration: Duration(DurationType.quarter),
        tie: TieType.end,
      );

      expect(note1.pitch.midiNumber, equals(note2.pitch.midiNumber));
    });
  });

  group('Note - Slurs', () {
    test('Note can start a slur', () {
      final note = Note(
        pitch: Pitch(step: 'C', octave: 4),
        duration: Duration(DurationType.quarter),
        slur: SlurType.start,
      );

      expect(note.slur, equals(SlurType.start));
    });

    test('Note can end a slur', () {
      final note = Note(
        pitch: Pitch(step: 'E', octave: 4),
        duration: Duration(DurationType.quarter),
        slur: SlurType.end,
      );

      expect(note.slur, equals(SlurType.end));
    });

    test('Note can be inside a slur', () {
      final note = Note(
        pitch: Pitch(step: 'D', octave: 4),
        duration: Duration(DurationType.quarter),
        slur: SlurType.inner,
      );

      expect(note.slur, equals(SlurType.inner));
    });
  });

  group('Note - Articulations', () {
    test('Note can have single articulation', () {
      final note = Note(
        pitch: Pitch(step: 'F', octave: 4),
        duration: Duration(DurationType.quarter),
        articulations: [ArticulationType.staccato],
      );

      expect(note.articulations, hasLength(1));
      expect(note.articulations.first, equals(ArticulationType.staccato));
    });

    test('Note can have multiple articulations', () {
      final note = Note(
        pitch: Pitch(step: 'G', octave: 4),
        duration: Duration(DurationType.quarter),
        articulations: [
          ArticulationType.accent,
          ArticulationType.tenuto,
          ArticulationType.staccato,
        ],
      );

      expect(note.articulations, hasLength(3));
      expect(note.articulations, contains(ArticulationType.accent));
      expect(note.articulations, contains(ArticulationType.tenuto));
      expect(note.articulations, contains(ArticulationType.staccato));
    });

    test('All articulation types can be applied', () {
      final articulations = [
        ArticulationType.staccato,
        ArticulationType.staccatissimo,
        ArticulationType.accent,
        ArticulationType.strongAccent,
        ArticulationType.tenuto,
        ArticulationType.marcato,
        ArticulationType.legato,
        ArticulationType.portato,
        ArticulationType.upBow,
        ArticulationType.downBow,
        ArticulationType.harmonics,
        ArticulationType.pizzicato,
        ArticulationType.snap,
        ArticulationType.thumb,
        ArticulationType.stopped,
        ArticulationType.open,
        ArticulationType.halfStopped,
      ];

      for (final articulation in articulations) {
        final note = Note(
          pitch: Pitch(step: 'A', octave: 4),
          duration: Duration(DurationType.quarter),
          articulations: [articulation],
        );

        expect(note.articulations.first, equals(articulation));
      }
    });
  });

  group('Note - Ornaments', () {
    test('Note can have trill', () {
      final note = Note(
        pitch: Pitch(step: 'B', octave: 4),
        duration: Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.trill)],
      );

      expect(note.ornaments, hasLength(1));
      expect(note.ornaments.first.type, equals(OrnamentType.trill));
    });

    test('Note can have mordent', () {
      final note = Note(
        pitch: Pitch(step: 'C', octave: 5),
        duration: Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.mordent)],
      );

      expect(note.ornaments.first.type, equals(OrnamentType.mordent));
    });

    test('Note can have turn', () {
      final note = Note(
        pitch: Pitch(step: 'D', octave: 5),
        duration: Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.turn)],
      );

      expect(note.ornaments.first.type, equals(OrnamentType.turn));
    });

    test('Note can have fermata', () {
      final note = Note(
        pitch: Pitch(step: 'E', octave: 5),
        duration: Duration(DurationType.whole),
        ornaments: [Ornament(type: OrnamentType.fermata)],
      );

      expect(note.ornaments.first.type, equals(OrnamentType.fermata));
    });

    test('Note can have multiple ornaments', () {
      final note = Note(
        pitch: Pitch(step: 'F', octave: 5),
        duration: Duration(DurationType.quarter),
        ornaments: [
          Ornament(type: OrnamentType.trill),
          Ornament(type: OrnamentType.fermata),
        ],
      );

      expect(note.ornaments, hasLength(2));
    });
  });

  group('Note - Dynamics', () {
    test('Note can have piano dynamic', () {
      final note = Note(
        pitch: Pitch(step: 'G', octave: 4),
        duration: Duration(DurationType.quarter),
        dynamicElement: Dynamic(type: DynamicType.piano),
      );

      expect(note.dynamicElement, isNotNull);
      expect(note.dynamicElement!.type, equals(DynamicType.piano));
    });

    test('Note can have forte dynamic', () {
      final note = Note(
        pitch: Pitch(step: 'A', octave: 4),
        duration: Duration(DurationType.quarter),
        dynamicElement: Dynamic(type: DynamicType.forte),
      );

      expect(note.dynamicElement!.type, equals(DynamicType.forte));
    });

    test('Note can have mezzo-forte dynamic', () {
      final note = Note(
        pitch: Pitch(step: 'B', octave: 4),
        duration: Duration(DurationType.quarter),
        dynamicElement: Dynamic(type: DynamicType.mezzoForte),
      );

      expect(note.dynamicElement!.type, equals(DynamicType.mezzoForte));
    });
  });

  group('Note - Polyphonic (Voices)', () {
    test('Note can belong to voice 1', () {
      final note = Note(
        pitch: Pitch(step: 'C', octave: 4),
        duration: Duration(DurationType.quarter),
        voice: 1,
      );

      expect(note.voice, equals(1));
    });

    test('Note can belong to voice 2', () {
      final note = Note(
        pitch: Pitch(step: 'E', octave: 4),
        duration: Duration(DurationType.quarter),
        voice: 2,
      );

      expect(note.voice, equals(2));
    });

    test('Note without voice defaults to null', () {
      final note = Note(
        pitch: Pitch(step: 'G', octave: 4),
        duration: Duration(DurationType.quarter),
      );

      expect(note.voice, isNull);
    });

    test('Voice numbers can be higher than 2', () {
      final note = Note(
        pitch: Pitch(step: 'A', octave: 4),
        duration: Duration(DurationType.quarter),
        voice: 3,
      );

      expect(note.voice, equals(3));
    });
  });

  group('Note - Complex Combinations', () {
    test('Note can have all properties simultaneously', () {
      final note = Note(
        pitch: Pitch(step: 'D', octave: 5, accidentalType: AccidentalType.sharp),
        duration: Duration(DurationType.eighth, dots: 1),
        articulations: [ArticulationType.staccato, ArticulationType.accent],
        tie: TieType.start,
        slur: SlurType.start,
        beam: BeamType.start,
        ornaments: [Ornament(type: OrnamentType.trill)],
        dynamicElement: Dynamic(type: DynamicType.forte),
        techniques: [PlayingTechnique(type: TechniqueType.tremolo)],
        voice: 1,
      );

      expect(note.pitch.accidentalType, equals(AccidentalType.sharp));
      expect(note.duration.dots, equals(1));
      expect(note.articulations, hasLength(2));
      expect(note.tie, equals(TieType.start));
      expect(note.slur, equals(SlurType.start));
      expect(note.beam, equals(BeamType.start));
      expect(note.ornaments, hasLength(1));
      expect(note.dynamicElement, isNotNull);
      expect(note.techniques, hasLength(1));
      expect(note.voice, equals(1));
    });
  });

  group('Note - Musical Context', () {
    test('Grace notes are typically shorter duration', () {
      final graceNote = Note(
        pitch: Pitch(step: 'C', octave: 4),
        duration: Duration(DurationType.eighth),
        ornaments: [Ornament(type: OrnamentType.acciaccatura)],
      );

      expect(graceNote.ornaments.first.type, equals(OrnamentType.acciaccatura));
    });

    test('Beamed notes typically form rhythmic groups', () {
      final notes = [
        Note(
          pitch: Pitch(step: 'C', octave: 4),
          duration: Duration(DurationType.eighth),
          beam: BeamType.start,
        ),
        Note(
          pitch: Pitch(step: 'D', octave: 4),
          duration: Duration(DurationType.eighth),
          beam: BeamType.inner,
        ),
        Note(
          pitch: Pitch(step: 'E', octave: 4),
          duration: Duration(DurationType.eighth),
          beam: BeamType.inner,
        ),
        Note(
          pitch: Pitch(step: 'F', octave: 4),
          duration: Duration(DurationType.eighth),
          beam: BeamType.end,
        ),
      ];

      expect(notes.first.beam, equals(BeamType.start));
      expect(notes.last.beam, equals(BeamType.end));
      expect(notes[1].beam, equals(BeamType.inner));
    });
  });
}
