// test/midi/playback_plan_test.dart
//
// PlaybackPlan: the transport a player UI needs (position at a time, notes
// sounding, when a bar starts), read off the MidiSequence that makes the
// sound. Cases adapted from @zamvar's fork (`codex/note-tap`,
// `test/playback/playback_plan_test.dart`).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;
import 'package:flutter_notemus/flutter_notemus.dart' as n show Duration;

Note _note(String step, DurationType type, {int octave = 4}) => Note(
      pitch: Pitch(step: step, octave: octave),
      duration: n.Duration(type),
    );

void main() {
  test('tempo changes convert ticks to wall-clock time and back', () {
    final c = _note('C', DurationType.quarter);
    final d = _note('D', DurationType.quarter);
    final measure = Measure()
      ..add(TempoMark(beatUnit: DurationType.quarter, bpm: 60))
      ..add(c)
      ..add(TempoMark(beatUnit: DurationType.quarter, bpm: 120))
      ..add(d);
    final plan = PlaybackPlan.fromStaff(Staff(measures: [measure]));

    expect(plan.tempoChanges.map((t) => (t.tick, t.bpm)), [(0, 60), (960, 120)]);
    expect(plan.timeAtTick(960).inMilliseconds, 1000);
    expect(plan.timeAtTick(1920).inMilliseconds, 1500);
    expect(plan.tickAt(const Duration(milliseconds: 1250)), 1440);

    // The C sounds through the first second, the D after it.
    expect(plan.notesAt(const Duration(milliseconds: 500)).map((s) => s.note),
        [same(c)]);
    expect(plan.notesAt(const Duration(milliseconds: 1250)).map((s) => s.note),
        [same(d)]);
  });

  test('positions and seeking follow the repeat-expanded order', () {
    final first = Measure()
      ..add(TimeSignature(numerator: 4, denominator: 4))
      ..add(Barline(type: BarlineType.repeatForward))
      ..add(_note('C', DurationType.whole));
    final second = Measure()
      ..add(_note('D', DurationType.whole))
      ..add(Barline(type: BarlineType.repeatBackward));
    final plan = PlaybackPlan.fromStaff(Staff(measures: [first, second]));

    expect(plan.measures.map((m) => (m.measureIndex, m.repeatPass)),
        [(0, 1), (1, 1), (0, 2), (1, 2)]);
    expect(plan.duration, const Duration(seconds: 8)); // 4 whole notes at 120
    expect(plan.timeOfMeasure(0), Duration.zero);
    expect(plan.timeOfMeasure(0, repeatPass: 2), const Duration(seconds: 4));
    expect(plan.timeOfMeasure(5), isNull);

    final position = plan.positionAt(const Duration(milliseconds: 4500))!;
    expect(position.measureIndex, 0);
    expect(position.repeatPass, 2);
    expect(position.occurrenceIndex, 2);
    // Half a second at 120 bpm is one quarter: a quarter of the bar.
    expect(position.offsetInMeasure, closeTo(0.25, 1e-9));
    expect(position.progress, closeTo(4.5 / 8, 1e-9));
  });

  test('a span links each played note back to the caller\'s object', () {
    final a = _note('A', DurationType.half);
    final chord = Chord(
      notes: [_note('C', DurationType.half, octave: 5), _note('E', DurationType.half, octave: 5)],
      duration: const n.Duration(DurationType.half),
    );
    final staff = Staff(measures: [
      Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(a)
        ..add(chord),
    ]);
    final spans = MidiMapper.fromStaff(staff).noteSpans;
    expect(spans.map((s) => s.note), [same(a), ...chord.notes.map(same)]);
    expect(spans.map((s) => (s.startTick, s.endTick)),
        [(0, 1920), (1920, 3840), (1920, 3840)]);
    expect(spans.map((s) => s.measureIndex), everyElement(0));
  });

  test('voices split into tracks still give one span per note', () {
    final measure = MultiVoiceMeasure()
      ..add(TimeSignature(numerator: 4, denominator: 4));
    measure.addVoice(Voice(number: 1, elements: [_note('E', DurationType.whole, octave: 5)]));
    measure.addVoice(Voice(number: 2, elements: [_note('C', DurationType.whole)]));
    final staff = Staff(measures: [measure]);
    for (final split in [false, true]) {
      final spans = MidiMapper.fromStaff(staff,
              options: MidiGenerationOptions(separateTracksPerVoice: split))
          .noteSpans;
      expect(spans.map((s) => s.voiceNumber).toList()..sort(), [1, 2],
          reason: 'separateTracksPerVoice: $split');
    }
  });

  test('notesAt leaves out what the options silence', () {
    final top = _note('E', DurationType.whole, octave: 5);
    final bottom = _note('C', DurationType.whole);
    final measure = MultiVoiceMeasure()
      ..add(TimeSignature(numerator: 4, denominator: 4));
    measure.addVoice(Voice(number: 1, elements: [top]));
    measure.addVoice(Voice(number: 2, elements: [bottom]));
    final plan = PlaybackPlan.fromStaff(Staff(measures: [measure]),
        options: const MidiGenerationOptions(mutedVoices: {2}));
    const t = Duration(milliseconds: 100);
    expect(plan.notesAt(t).map((s) => s.note), [same(top)]);
    expect(plan.notesAt(t, includeSilent: true).map((s) => s.note).toSet(),
        {top, bottom});
    expect(
        plan.notesAt(t, includeSilent: true)
            .firstWhere((s) => identical(s.note, bottom))
            .audible,
        isFalse);
  });

  test('a note of a plain Measure reports the voice it declares', () {
    final declared = Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const n.Duration(DurationType.half),
      voice: 3,
    );
    final chord = Chord(
      notes: [_note('C', DurationType.half, octave: 5)],
      duration: const n.Duration(DurationType.half),
      voice: 2,
    );
    final spans = MidiMapper.fromStaff(Staff(measures: [
      Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(declared)
        ..add(chord),
    ])).noteSpans;
    expect(spans.map((s) => s.voiceNumber), [3, 2]);
  });

  test('a tuplet plays within its written span', () {
    final triplet = Tuplet.triplet(elements: [
      for (final s in ['C', 'D', 'E']) _note(s, DurationType.eighth),
    ]);
    final after = _note('F', DurationType.quarter);
    final staff = Staff(measures: [
      Measure()
        ..add(TimeSignature(numerator: 2, denominator: 4))
        ..add(triplet)
        ..add(after),
    ]);
    final spans = MidiMapper.fromStaff(staff).noteSpans;
    expect(spans.map((s) => s.startTick), [0, 320, 640, 960]);
  });

  test('a pickup is as long as its content on the transport too', () {
    final staff = Staff(measures: [
      Measure(isImplicit: true)
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(_note('G', DurationType.quarter)),
      Measure()..add(_note('C', DurationType.whole, octave: 5)),
    ]);
    final plan = PlaybackPlan.fromStaff(staff);
    expect(plan.measures.map((m) => (m.startTick, m.endTick)),
        [(0, 960), (960, 4800)]);
    expect(plan.positionAt(const Duration(milliseconds: 600))!.measureIndex, 1);
  });

  test('positions clamp to the piece, and an empty staff has none', () {
    final plan = PlaybackPlan.fromStaff(Staff(measures: [
      Measure()
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(_note('C', DurationType.whole)),
    ]));
    expect(plan.positionAt(const Duration(seconds: -1))!.tick, 0);
    expect(plan.positionAt(const Duration(minutes: 5))!.progress, 1.0);
    expect(PlaybackPlan.fromStaff(Staff()).positionAt(Duration.zero), isNull);
  });
}
