// §30 of the audit — "playback by part / staff / voice / selection".
//
// The audit found: per STAFF was already possible (one track per staff), per
// VOICE was not (measured: both voices of a MultiVoiceMeasure emitted on the
// same track and the same channel, so nothing could be soloed or muted), and
// per REGION did not exist at all.
//
// These tests pin the contract for all three.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Note _n(String step, int octave, [DurationType d = DurationType.quarter]) =>
    Note(pitch: Pitch(step: step, octave: octave), duration: Duration(d));

MultiVoiceMeasure _twoVoiceBar() {
  final m = MultiVoiceMeasure();
  m.elements.add(Clef(clefType: ClefType.treble));
  m.elements.add(TimeSignature(numerator: 4, denominator: 4));
  m.addVoice(Voice(number: 1, elements: [
    _n('C', 5, DurationType.half),
    _n('D', 5, DurationType.half),
  ]));
  m.addVoice(Voice(number: 2, elements: [
    _n('C', 4, DurationType.whole),
  ]));
  return m;
}

Iterable<MidiTrack> _music(MidiSequence s) =>
    s.tracks.where((t) => t.name != 'Conductor');

Set<int> _pitches(Iterable<MidiTrack> tracks) => {
      for (final t in tracks)
        for (final e in t.events)
          if (e.type == MidiEventType.noteOn) e.note!,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voices sound simultaneously by default (unchanged behaviour)', () {
    final seq = MidiMapper.fromStaff(Staff(measures: [_twoVoiceBar()]));
    final track = _music(seq).first;
    final onsets = {
      for (final e in track.events)
        if (e.type == MidiEventType.noteOn) '${e.note}@${e.tick}',
    };
    expect(onsets, containsAll(<String>['72@0', '60@0', '74@1920']),
        reason: 'C5 and C4 start together; D5 enters at the half bar.');
  });

  test('separateTracksPerVoice puts each voice on its own track', () {
    final seq = MidiMapper.fromStaff(
      Staff(measures: [_twoVoiceBar()]),
      options: const MidiGenerationOptions(separateTracksPerVoice: true),
    );
    final tracks = _music(seq).toList();
    expect(tracks.length, greaterThanOrEqualTo(2),
        reason: 'both voices used to share one track and one channel, so '
            'nothing could be soloed or muted.');
    expect(tracks.map((t) => t.name).toSet(), hasLength(tracks.length));
  });

  test('muting a voice removes exactly that voice', () {
    final all = _pitches(_music(MidiMapper.fromStaff(
      Staff(measures: [_twoVoiceBar()]),
      options: const MidiGenerationOptions(separateTracksPerVoice: true),
    )));
    expect(all, containsAll(<int>[72, 74, 60]));

    final muted = _pitches(_music(MidiMapper.fromStaff(
      Staff(measures: [_twoVoiceBar()]),
      options: const MidiGenerationOptions(
        separateTracksPerVoice: true,
        mutedVoices: {2},
      ),
    )));
    expect(muted, isNot(contains(60)), reason: 'voice 2 was muted');
    expect(muted, containsAll(<int>[72, 74]), reason: 'voice 1 survives');
  });

  test('solo wins over mute', () {
    final soloed = _pitches(_music(MidiMapper.fromStaff(
      Staff(measures: [_twoVoiceBar()]),
      options: const MidiGenerationOptions(
        separateTracksPerVoice: true,
        mutedVoices: {2},
        soloVoices: {2},
      ),
    )));
    expect(soloed, contains(60));
    expect(soloed, isNot(contains(72)));
  });

  test('per-staff selection still works on a Score', () {
    Staff line(String step, int octave, ClefType clef) => Staff(measures: [
          Measure()
            ..elements.add(Clef(clefType: clef))
            ..elements.add(TimeSignature(numerator: 4, denominator: 4))
            ..elements.add(_n(step, octave, DurationType.whole)),
        ]);

    final score = Score(staffGroups: [
      StaffGroup(
        staves: [line('C', 5, ClefType.treble), line('C', 3, ClefType.bass)],
        bracket: BracketType.brace,
      ),
    ]);

    final all = _pitches(_music(MidiMapper.fromScore(score)));
    expect(all, containsAll(<int>[72, 48]));

    final topOnly = _pitches(_music(MidiMapper.fromScore(
      score,
      options: const MidiGenerationOptions(soloStaves: {0}),
    )));
    expect(topOnly, contains(72));
    expect(topOnly, isNot(contains(48)));
  });

  test('a marquee selection yields a playable onset range', () {
    // The hit tester is what turns a drag into a time range; this is the
    // handshake between selection and playback that §30 asked for.
    final staff = Staff(measures: [
      Measure()
        ..elements.add(Clef(clefType: ClefType.treble))
        ..elements.add(TimeSignature(numerator: 4, denominator: 4))
        ..elements.add(_n('C', 5))
        ..elements.add(_n('D', 5))
        ..elements.add(_n('E', 5))
        ..elements.add(_n('F', 5)),
    ]);
    final metadata = SmuflMetadata();
    return metadata.load().then((_) {
      final engine = LayoutEngine(staff,
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      final elements = engine.layout();
      final tester =
          ScoreHitTester(elements: elements, staffSpace: 12, engine: engine);

      final selected = tester.selectTimeRange(0.25, 0.75);
      final notes = selected.where((h) => h.element is Note).toList();
      expect(notes, hasLength(2));
      expect(notes.map((h) => (h.element as Note).pitch.step), ['D', 'E']);

      // And the full sequence still covers the whole bar.
      final seq = MidiMapper.fromStaff(staff);
      final lastOff = _music(seq)
          .expand((t) => t.events)
          .where((e) => e.type == MidiEventType.noteOff)
          .map((e) => e.tick)
          .reduce(math.max);
      expect(lastOff, seq.ticksPerQuarter * 4);
    });
  });
}
