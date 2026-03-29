import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  group('LayoutEngine', () {
    test('keeps chords as chord elements while tracking note geometry', () {
      final chord = Chord(
        notes: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.half),
          ),
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.half),
          ),
          Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.half),
          ),
        ],
        duration: const Duration(DurationType.half, dots: 1),
        ornaments: [Ornament(type: OrnamentType.arpeggio)],
        dynamic: Dynamic(type: DynamicType.f),
      );

      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(chord);
      final staff = Staff(measures: [measure]);
      final engine = LayoutEngine(
        staff,
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      final result = engine.layoutWithSignature();

      expect(
        result.elements.where((positioned) => positioned.element is Chord),
        hasLength(1),
      );
      expect(
        result.elements.where((positioned) => positioned.element is Note),
        isEmpty,
      );

      for (final note in chord.notes) {
        expect(engine.noteXPositions[note], isNotNull);
        expect(engine.noteYPositions[note], isNotNull);
      }
    });

    test('keeps legacy beam rendering for groups without time signature', () {
      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.eighth),
            beam: BeamType.start,
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.eighth),
            beam: BeamType.inner,
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.eighth),
            beam: BeamType.end,
          ),
        );
      final staff = Staff(measures: [measure]);
      final engine = LayoutEngine(
        staff,
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      engine.layoutWithSignature();

      expect(engine.advancedBeamGroups, isEmpty);
    });

    test('creates advanced beam groups when time signature is present', () {
      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'F', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
        );
      final staff = Staff(measures: [measure]);
      final engine = LayoutEngine(
        staff,
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      engine.layoutWithSignature();

      expect(engine.advancedBeamGroups, hasLength(1));
      expect(engine.advancedBeamGroups.single.notes, hasLength(4));
    });

    test(
      'automatically beams an isolated pair of eighth notes inside a beat',
      () {
        final measure = Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(
            Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'F', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'G', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'F', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          );
        final engine = LayoutEngine(
          Staff(measures: [measure]),
          availableWidth: 640,
          staffSpace: 12,
          metadata: metadata,
        );

        engine.layoutWithSignature();

        expect(engine.advancedBeamGroups, hasLength(1));
        final beamGroup = engine.advancedBeamGroups.single;
        expect(beamGroup.notes, hasLength(2));
        expect(
          beamGroup.notes.map((note) => note.pitch.step),
          orderedEquals(const ['F', 'G']),
        );
        expect(
          (beamGroup.rightY - beamGroup.leftY).abs(),
          lessThanOrEqualTo(3.0),
        );
      },
    );

    test('does not beam across non-beamable notes inside the measure', () {
      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'A', octave: 4),
            duration: const Duration(DurationType.eighth),
            ornaments: [Ornament(type: OrnamentType.appoggiaturaDown)],
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'B', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.sixteenth),
            ornaments: [Ornament(type: OrnamentType.acciaccatura)],
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'F', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );
      final engine = LayoutEngine(
        Staff(measures: [measure]),
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      engine.layoutWithSignature();

      expect(engine.advancedBeamGroups, isEmpty);
    });

    test('does not beam across rests inside the measure', () {
      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
        )
        ..add(Rest(duration: const Duration(DurationType.eighth)))
        ..add(
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );
      final engine = LayoutEngine(
        Staff(measures: [measure]),
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      engine.layoutWithSignature();

      expect(engine.advancedBeamGroups, isEmpty);
    });

    test('does not stretch single-measure systems across the full width', () {
      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );
      final staff = Staff(measures: [measure]);
      final engine = LayoutEngine(
        staff,
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      final result = engine.layoutWithSignature();
      final clef = result.elements.firstWhere(
        (positioned) => positioned.element is Clef,
      );
      final timeSignature = result.elements.firstWhere(
        (positioned) => positioned.element is TimeSignature,
      );
      final note = result.elements.firstWhere(
        (positioned) => positioned.element is Note,
      );

      expect(timeSignature.position.dx - clef.position.dx, lessThan(80));
      expect(note.position.dx - timeSignature.position.dx, lessThan(90));
    });

    test(
      'keeps wide multi-measure passages on one system when width allows',
      () {
        final measures = List<Measure>.generate(6, (index) {
          final measure = Measure();
          if (index == 0) {
            measure
              ..add(Clef(clefType: ClefType.treble))
              ..add(TimeSignature(numerator: 4, denominator: 4));
          }
          measure
            ..add(
              Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.quarter),
              ),
            )
            ..add(
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            )
            ..add(
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            )
            ..add(
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            );
          return measure;
        });

        final engine = LayoutEngine(
          Staff(measures: measures),
          availableWidth: 2200,
          staffSpace: 12,
          metadata: metadata,
        );

        final result = engine.layoutWithSignature();
        final systems = result.elements
            .map((positioned) => positioned.system)
            .toSet();

        expect(systems, hasLength(1));
        expect(systems.single, 0);
      },
    );

    test(
      'adds a closing barline before a system break when the next measure starts with a repeat barline',
      () {
        final measure1 = Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(
            Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'B', octave: 4),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'A', octave: 4),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'G', octave: 4),
              duration: const Duration(DurationType.quarter),
            ),
          );

        final measure2 = Measure()
          ..add(Barline(type: BarlineType.repeatForward))
          ..add(
            Note(
              pitch: const Pitch(step: 'A', octave: 4),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'B', octave: 4),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          );

        final engine = LayoutEngine(
          Staff(measures: [measure1, measure2]),
          availableWidth: 210,
          staffSpace: 12,
          metadata: metadata,
        );

        final result = engine.layoutWithSignature();
        final system0Barlines = result.elements
            .where((positioned) => positioned.system == 0)
            .where((positioned) => positioned.element is Barline)
            .map((positioned) => positioned.element as Barline)
            .toList();
        final system1Barlines = result.elements
            .where((positioned) => positioned.system == 1)
            .where((positioned) => positioned.element is Barline)
            .map((positioned) => positioned.element as Barline)
            .toList();

        expect(system0Barlines, isNotEmpty);
        expect(system0Barlines.last.type, BarlineType.single);
        expect(system1Barlines, isNotEmpty);
        expect(system1Barlines.first.type, BarlineType.repeatForward);
      },
    );

    test(
      'keeps simultaneous lower-voice attacks aligned with the upper voice',
      () {
        final voice1 = Voice.voice1()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(
            Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          );

        final voice2 = Voice.voice2()
          ..add(
            Note(
              pitch: const Pitch(step: 'C', octave: 4),
              duration: const Duration(DurationType.half),
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'G', octave: 3),
              duration: const Duration(DurationType.half),
            ),
          );

        final measure = MultiVoiceMeasure()
          ..addVoice(voice1)
          ..addVoice(voice2);
        final staff = Staff(measures: [measure]);
        final engine = LayoutEngine(
          staff,
          availableWidth: 640,
          staffSpace: 12,
          metadata: metadata,
        );

        final result = engine.layoutWithSignature();
        final upperNotes = result.elements
            .where(
              (positioned) =>
                  positioned.element is Note && positioned.voiceNumber == 1,
            )
            .toList();
        final lowerNotes = result.elements
            .where(
              (positioned) =>
                  positioned.element is Note && positioned.voiceNumber == 2,
            )
            .toList();

        expect(upperNotes, hasLength(4));
        expect(lowerNotes, hasLength(2));
        expect(
          lowerNotes[0].position.dx,
          closeTo(upperNotes[0].position.dx, 0.001),
        );
        expect(
          lowerNotes[1].position.dx,
          closeTo(upperNotes[2].position.dx, 0.001),
        );
      },
    );

    test(
      'assigns horizontal width to multiple tempo marks in the same measure',
      () {
        final measure = Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(
            TempoMark(
              beatUnit: DurationType.quarter,
              bpm: 120,
              text: 'Allegro',
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'C', octave: 4),
              duration: const Duration(DurationType.quarter),
            ),
          )
          ..add(
            TempoMark(
              beatUnit: DurationType.eighth,
              bpm: 144,
              text: 'Piu mosso',
            ),
          )
          ..add(
            Note(
              pitch: const Pitch(step: 'D', octave: 4),
              duration: const Duration(DurationType.quarter),
            ),
          );
        final staff = Staff(measures: [measure]);
        final engine = LayoutEngine(
          staff,
          availableWidth: 640,
          staffSpace: 12,
          metadata: metadata,
        );

        final result = engine.layoutWithSignature();
        final tempoMarks = result.elements
            .where((positioned) => positioned.element is TempoMark)
            .toList();
        final notes = result.elements
            .where((positioned) => positioned.element is Note)
            .toList();

        expect(tempoMarks, hasLength(2));
        expect(notes, hasLength(2));
        expect(
          tempoMarks[1].position.dx,
          greaterThan(tempoMarks[0].position.dx),
        );
        expect(
          notes[0].position.dx,
          greaterThanOrEqualTo(tempoMarks[0].position.dx),
        );
        expect(
          tempoMarks[1].position.dx,
          greaterThanOrEqualTo(notes[0].position.dx),
        );
        expect(
          notes[1].position.dx,
          greaterThanOrEqualTo(tempoMarks[1].position.dx),
        );
      },
    );

    test('assigns horizontal width to instructional music text', () {
      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(
          MusicText(
            text: 'con fuoco',
            type: TextType.instruction,
            placement: TextPlacement.above,
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'F', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          MusicText(
            text: 'legato',
            type: TextType.instruction,
            placement: TextPlacement.above,
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );
      final staff = Staff(measures: [measure]);
      final engine = LayoutEngine(
        staff,
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      final result = engine.layoutWithSignature();
      final texts = result.elements
          .where((positioned) => positioned.element is MusicText)
          .toList();
      final notes = result.elements
          .where((positioned) => positioned.element is Note)
          .toList();

      expect(texts, hasLength(2));
      expect(notes, hasLength(2));
      expect(notes[0].position.dx, greaterThanOrEqualTo(texts[0].position.dx));
      expect(texts[1].position.dx, greaterThanOrEqualTo(notes[0].position.dx));
      expect(notes[1].position.dx, greaterThanOrEqualTo(texts[1].position.dx));
    });

    test('assigns horizontal width to textual repeat instructions', () {
      final measure = Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(RepeatMark(type: RepeatType.dalSegnoAlCoda))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(RepeatMark(type: RepeatType.fine))
        ..add(
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );
      final staff = Staff(measures: [measure]);
      final engine = LayoutEngine(
        staff,
        availableWidth: 640,
        staffSpace: 12,
        metadata: metadata,
      );

      final result = engine.layoutWithSignature();
      final repeatMarks = result.elements
          .where((positioned) => positioned.element is RepeatMark)
          .toList();
      final notes = result.elements
          .where((positioned) => positioned.element is Note)
          .toList();

      expect(repeatMarks, hasLength(2));
      expect(notes, hasLength(2));
      expect(
        notes[0].position.dx,
        greaterThanOrEqualTo(repeatMarks[0].position.dx),
      );
      expect(
        repeatMarks[1].position.dx,
        greaterThanOrEqualTo(notes[0].position.dx),
      );
      expect(
        notes[1].position.dx,
        greaterThanOrEqualTo(repeatMarks[1].position.dx),
      );
    });
  });
}
