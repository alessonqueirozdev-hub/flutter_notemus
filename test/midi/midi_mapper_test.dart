import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MidiMapper', () {
    test('maps quarter notes to PPQ ticks', () {
      final measure = Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'F', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );

      final sequence = MidiMapper.fromStaff(Staff(measures: [measure]));
      final staffTrack = sequence.tracks.firstWhere(
        (track) => track.name == 'Staff 1',
      );
      final noteOns = staffTrack.events
          .where((event) => event.type == MidiEventType.noteOn)
          .toList();
      final noteOffs = staffTrack.events
          .where((event) => event.type == MidiEventType.noteOff)
          .toList();

      expect(noteOns.length, 4);
      expect(noteOffs.length, 4);
      expect(noteOns.first.tick, 0);
      expect(noteOffs.first.tick, 960);
      expect(noteOffs.last.tick, 3840);
      expect(sequence.totalTicks, 3840);
    });

    test('applies tuplet ratio to durations', () {
      final triplet = Tuplet.triplet(
        elements: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.eighth),
          ),
        ],
      );

      final measure = Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(triplet);

      final sequence = MidiMapper.fromStaff(Staff(measures: [measure]));
      final staffTrack = sequence.tracks.firstWhere(
        (track) => track.name == 'Staff 1',
      );
      final noteOffs = staffTrack.events
          .where((event) => event.type == MidiEventType.noteOff)
          .map((event) => event.tick)
          .toList();

      expect(noteOffs, [320, 640, 960]);
    });

    test('expands repeats and respects volta endings', () {
      final measure1 = Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(Barline(type: BarlineType.repeatForward))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.whole),
          ),
        );

      final measure2 = Measure()
        ..add(VoltaBracket(number: 1, length: 0.0))
        ..add(
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.whole),
          ),
        )
        ..add(Barline(type: BarlineType.repeatBackward));

      final measure3 = Measure()
        ..add(VoltaBracket(number: 2, length: 0.0))
        ..add(
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.whole),
          ),
        );

      final sequence = MidiMapper.fromStaff(
        Staff(measures: [measure1, measure2, measure3]),
      );
      final staffTrack = sequence.tracks.firstWhere(
        (track) => track.name == 'Staff 1',
      );
      final notes = staffTrack.events
          .where((event) => event.type == MidiEventType.noteOn)
          .map((event) => event.note)
          .toList();

      expect(notes, [60, 62, 60, 64]);
    });

    test('generates metronome track from played timeline', () {
      final measure1 = Measure()
        ..add(TimeSignature(numerator: 3, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );

      final measure2 = Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'F', octave: 4),
            duration: const Duration(DurationType.quarter),
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
            pitch: const Pitch(step: 'A', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        )
        ..add(
          Note(
            pitch: const Pitch(step: 'B', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        );

      final sequence = MidiMapper.fromStaff(
        Staff(measures: [measure1, measure2]),
        options: const MidiGenerationOptions(includeMetronome: true),
      );

      final metronomeTrack = sequence.tracks.firstWhere(
        (track) => track.name == 'Metronome',
      );
      final noteOns = metronomeTrack.events
          .where((event) => event.type == MidiEventType.noteOn)
          .toList();

      expect(noteOns.length, 7);
      expect(noteOns.where((event) => event.note == 76).length, 2);
      expect(noteOns.where((event) => event.note == 77).length, 5);
    });

    test('staccato shortens the sounding duration but not the advance', () {
      final measure = Measure()
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.quarter),
          articulations: const [ArticulationType.staccato],
        ))
        ..add(Note(
          pitch: const Pitch(step: 'D', octave: 4),
          duration: const Duration(DurationType.quarter),
        ));
      final track = MidiMapper.fromStaff(Staff(measures: [measure]))
          .tracks
          .firstWhere((t) => t.name == 'Staff 1');
      final ons =
          track.events.where((e) => e.type == MidiEventType.noteOn).toList();
      final offs =
          track.events.where((e) => e.type == MidiEventType.noteOff).toList();
      // ppq 960: staccato quarter sounds ~480 ticks (gate 0.5)...
      expect(offs.first.tick - ons.first.tick, 480);
      // ...but the next note still starts a full quarter later.
      expect(ons[1].tick, 960);
    });

    test('accent raises note velocity', () {
      Measure m(List<ArticulationType> arts) => Measure()
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.quarter),
          articulations: arts,
        ));
      int vel(List<ArticulationType> arts) => MidiMapper.fromStaff(
              Staff(measures: [m(arts)]))
          .tracks
          .firstWhere((t) => t.name == 'Staff 1')
          .events
          .firstWhere((e) => e.type == MidiEventType.noteOn)
          .velocity!;
      expect(vel(const [ArticulationType.accent]),
          greaterThan(vel(const [])));
      expect(vel(const [ArticulationType.marcato]),
          greaterThan(vel(const [ArticulationType.accent])));
    });

    test('a trill expands into rapid alternating sub-notes', () {
      final measure = Measure()
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.quarter),
          ornaments: [Ornament(type: OrnamentType.trill)],
        ));
      final track = MidiMapper.fromStaff(Staff(measures: [measure]))
          .tracks
          .firstWhere((t) => t.name == 'Staff 1');
      final ons =
          track.events.where((e) => e.type == MidiEventType.noteOn).toList();
      // Many alternations, between C5 (72) and the upper neighbour (74).
      expect(ons.length, greaterThan(3));
      expect(ons.map((e) => e.note).toSet(), {72, 74});
    });

    test('a mordent plays main-upper-main', () {
      final measure = Measure()
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.quarter),
          ornaments: [Ornament(type: OrnamentType.mordent)],
        ));
      final ons = MidiMapper.fromStaff(Staff(measures: [measure]))
          .tracks
          .firstWhere((t) => t.name == 'Staff 1')
          .events
          .where((e) => e.type == MidiEventType.noteOn)
          .map((e) => e.note)
          .toList();
      expect(ons, [72, 74, 72]);
    });

    test('grace note steals time: it sounds before the beat and does not '
        'delay the main note', () {
      final measure = Measure()
        ..add(Note(
            pitch: const Pitch(step: 'C', octave: 5),
            duration: const Duration(DurationType.eighth),
            isGraceNote: true))
        ..add(Note(
            pitch: const Pitch(step: 'D', octave: 5),
            duration: const Duration(DurationType.quarter)));
      final track = MidiMapper.fromStaff(Staff(measures: [measure]))
          .tracks
          .firstWhere((t) => t.name == 'Staff 1');
      final ons =
          track.events.where((e) => e.type == MidiEventType.noteOn).toList();
      // Grace at tick 0, main note still at tick 0 (not pushed later)...
      final main = ons.firstWhere((e) => e.note == 74); // D5
      expect(main.tick, 0);
      // ...and the measure length is the single quarter (960), no overflow.
      expect(track.events
          .where((e) => e.type == MidiEventType.noteOff)
          .map((e) => e.tick)
          .reduce((a, b) => a > b ? a : b), 960);
    });

    test('half-note metronome mark scales to per-quarter MIDI tempo', () {
      final measure = Measure()
        ..add(TempoMark(beatUnit: DurationType.half, bpm: 80))
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.quarter),
        ));
      final seq = MidiMapper.fromStaff(Staff(measures: [measure]));
      final tempo = seq.tracks
          .expand((t) => t.events)
          .firstWhere((e) => e.type == MidiEventType.tempo && e.tick > 0,
              orElse: () => seq.tracks
                  .expand((t) => t.events)
                  .lastWhere((e) => e.type == MidiEventType.tempo));
      // half = 80 -> quarter = 160.
      expect(tempo.bpm, 160);
    });

    test('a hairpin dynamic does not reset the running velocity', () {
      final measure = Measure()
        ..add(Dynamic(type: DynamicType.f)) // forte
        ..add(Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter)))
        ..add(Dynamic(type: DynamicType.crescendo, isHairpin: true))
        ..add(Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const Duration(DurationType.quarter)));
      final track = MidiMapper.fromStaff(Staff(measures: [measure]))
          .tracks
          .firstWhere((t) => t.name == 'Staff 1');
      final ons =
          track.events.where((e) => e.type == MidiEventType.noteOn).toList();
      // Both notes keep the forte velocity; the hairpin doesn't reset to mf.
      expect(ons[0].velocity, ons[1].velocity);
      expect(ons[1].velocity, velocityFromDynamic(DynamicType.f));
    });

    test('tied notes are never shortened by articulation', () {
      final measure = Measure()
        ..add(Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.quarter),
          articulations: const [ArticulationType.staccato],
          tie: TieType.start,
        ));
      final track = MidiMapper.fromStaff(Staff(measures: [measure]))
          .tracks
          .firstWhere((t) => t.name == 'Staff 1');
      final on = track.events.firstWhere((e) => e.type == MidiEventType.noteOn);
      // tie keeps it open to the end of the sequence (full duration), not gated.
      expect(track.events.any((e) => e.type == MidiEventType.noteOff), isTrue);
      expect(on.tick, 0);
    });
  });

  group('MidiFileWriter', () {
    test('writes valid MIDI header and track chunk', () {
      final measure = Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.whole),
          ),
        );

      final sequence = MidiMapper.fromStaff(Staff(measures: [measure]));
      final bytes = MidiFileWriter.write(sequence);

      expect(ascii.decode(bytes.sublist(0, 4)), 'MThd');
      expect(_containsPattern(bytes, ascii.encode('MTrk')), isTrue);
    });
  });
}

bool _containsPattern(Uint8List bytes, List<int> pattern) {
  if (pattern.isEmpty || bytes.length < pattern.length) {
    return false;
  }

  for (int i = 0; i <= bytes.length - pattern.length; i++) {
    bool match = true;
    for (int j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      return true;
    }
  }
  return false;
}
