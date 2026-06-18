// Chant -> MIDI playback mapping.

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChantMidiMapper', () {
    NeumeComponent nc(String step, int octave,
            {int morae = 0,
            bool episema = false,
            bool ictus = false,
            bool liq = false}) =>
        NeumeComponent(
          pitchName: step,
          octave: octave,
          morae: morae,
          episema: episema,
          ictus: ictus,
          isLiquescent: liq,
        );

    MidiTrack chantTrack(MidiSequence seq) =>
        seq.tracks.firstWhere((t) => t.name == 'Chant');

    List<MidiEvent> noteOns(MidiSequence seq) => chantTrack(seq)
        .events
        .where((e) => e.type == MidiEventType.noteOn)
        .toList();

    test('resolves natural diatonic pitches and pairs note on/off', () {
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.punctum, components: [nc('C', 4)]),
        Neume(type: NeumeType.punctum, components: [nc('D', 4)]),
        Neume(type: NeumeType.pes, components: [nc('E', 4), nc('G', 4)]),
      ]);

      final ons = noteOns(seq);
      // 2 single notes + 2 from the pes = 4 sounding notes.
      expect(ons.length, 4);
      // C4 = 60, D4 = 62, E4 = 64, G4 = 67.
      expect(ons.map((e) => e.note).toList(), [60, 62, 64, 67]);

      final offs = chantTrack(seq)
          .events
          .where((e) => e.type == MidiEventType.noteOff)
          .toList();
      expect(offs.length, ons.length);
    });

    test('monophonic notes are sequential (no overlap)', () {
      const opts = ChantPlaybackOptions(ticksPerQuarter: 960);
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.punctum, components: [nc('C', 4)]),
        Neume(type: NeumeType.punctum, components: [nc('D', 4)]),
      ], options: opts);

      final track = chantTrack(seq);
      final on0 = track.events.firstWhere((e) => e.type == MidiEventType.noteOn);
      final off0 =
          track.events.firstWhere((e) => e.type == MidiEventType.noteOff);
      final on1 = track.events.lastWhere((e) => e.type == MidiEventType.noteOn);
      // Base note = 1 quarter = 960 ticks; second note starts where first ends.
      expect(on0.tick, 0);
      expect(off0.tick, 960);
      expect(on1.tick, 960);
    });

    test('mora dot doubles the note duration', () {
      const opts = ChantPlaybackOptions(ticksPerQuarter: 960);
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.punctum, components: [nc('C', 4, morae: 1)]),
      ], options: opts);
      final track = chantTrack(seq);
      final on = track.events.firstWhere((e) => e.type == MidiEventType.noteOn);
      final off =
          track.events.firstWhere((e) => e.type == MidiEventType.noteOff);
      // base (960) + 1 mora (960) = 1920.
      expect(off.tick - on.tick, 1920);
    });

    test('flat sign lowers following same-position notes by a semitone', () {
      final seq = ChantMidiMapper.fromChant([
        // flat sign at B4 (standalone, no notehead)
        Neume(type: NeumeType.custom, components: [
          NeumeComponent(
              pitchName: 'B', octave: 4, accidental: NeumeAccidental.flat),
        ]),
        Neume(type: NeumeType.punctum, components: [nc('B', 4)]),
        Neume(type: NeumeType.punctum, components: [nc('B', 3)]), // other octave
      ]);
      final ons = noteOns(seq);
      // B4 natural = 71 -> flat = 70; B3 (different position) stays 59.
      expect(ons.length, 2);
      expect(ons[0].note, 70);
      expect(ons[1].note, 59);
    });

    test('accidental resets at a divisio', () {
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.custom, components: [
          NeumeComponent(
              pitchName: 'B', octave: 4, accidental: NeumeAccidental.flat),
        ]),
        Neume(type: NeumeType.punctum, components: [nc('B', 4)]), // flatted -> 70
        NeumeDivision(type: NeumeDivisionType.maior),
        Neume(type: NeumeType.punctum, components: [nc('B', 4)]), // natural -> 71
      ]);
      final ons = noteOns(seq);
      expect(ons[0].note, 70);
      expect(ons[1].note, 71);
    });

    test('divisio inserts a breath rest (gap between notes)', () {
      const opts = ChantPlaybackOptions(
          ticksPerQuarter: 960, divisioMaiorQuarters: 2.0);
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.punctum, components: [nc('C', 4)]),
        NeumeDivision(type: NeumeDivisionType.maior),
        Neume(type: NeumeType.punctum, components: [nc('D', 4)]),
      ], options: opts);
      final ons = noteOns(seq);
      // first note 0..960, then 2q (1920) rest, second note at 2880.
      expect(ons[0].tick, 0);
      expect(ons[1].tick, 960 + 1920);
    });

    test('transpose shifts every note', () {
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.punctum, components: [nc('C', 4)]),
      ], options: const ChantPlaybackOptions(transpose: 12));
      expect(noteOns(seq).single.note, 72); // C4+octave
    });

    test('emits a program change and a tempo conductor track', () {
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.punctum, components: [nc('C', 4)]),
      ], options: const ChantPlaybackOptions(
        instrument: MidiInstrumentAssignment(
            channel: 0, program: 19, velocity: 90),
        bpm: 100,
      ));
      final track = chantTrack(seq);
      final pc = track.events
          .firstWhere((e) => e.type == MidiEventType.programChange);
      expect(pc.program, 19);
      final conductor = seq.tracks.firstWhere((t) => t.name == 'Conductor');
      final tempo =
          conductor.events.firstWhere((e) => e.type == MidiEventType.tempo);
      expect(tempo.bpm, 100);
    });

    test('pitch is resolved RELATIVE to the clef (mode depends on clef)', () {
      // Same letters g,h under c4 vs c3 must give different pitches and a
      // different g->h interval (clef shifts where the semitones land).
      List<int> notesFor(String clef) {
        final seq = gabcToMidiSequence('($clef) a(g)b(h)');
        return noteOns(seq).map((e) => e.note!).toList();
      }

      final c4 = notesFor('c4'); // g=G3(55), h=A3(57) -> whole tone
      final c3 = notesFor('c3'); // g=B3(59), h=C4(60) -> semitone
      expect(c4, [55, 57]);
      expect(c3, [59, 60]);
      expect(c4[1] - c4[0], 2); // tone under c4
      expect(c3[1] - c3[0], 1); // semitone under c3
    });

    test('do-clef line resolves to C, fa-clef line to F', () {
      // c4: line 4 = do = C; the note on that line (slot j) sounds C.
      final doSeq = gabcToMidiSequence('(c4) a(j)');
      expect(noteOns(doSeq).single.note, 60); // C4
      // f3: line 3 = fa = F; the note on that line (slot h) sounds F.
      final faSeq = gabcToMidiSequence('(f3) a(h)');
      expect(noteOns(faSeq).single.note! % 12, 5); // F pitch-class
    });

    test('clef-flat (cb) flats every si until cancelled', () {
      // Under cb4, slot i = B3 (natural 59) sounds as B-flat (58).
      final flat = gabcToMidiSequence('(cb4) a(i)');
      expect(noteOns(flat).single.note, 58);
      // Without the clef-flat it is natural.
      final natural = gabcToMidiSequence('(c4) a(i)');
      expect(noteOns(natural).single.note, 59);
    });

    test('build() returns a per-note timeline keyed to components', () {
      final pb = ChantMidiMapper.build([
        Neume(type: NeumeType.pes, components: [nc('C', 4), nc('D', 4)]),
        NeumeDivision(type: NeumeDivisionType.maior),
        Neume(type: NeumeType.punctum, components: [nc('E', 4)]),
      ]);
      expect(pb.notes.length, 3);
      expect(pb.notes[0].midiNote, 60);
      expect(pb.notes[1].midiNote, 62);
      expect(pb.notes[2].midiNote, 64);
      // Timeline ticks are monotonic and the divisio gap separates note 2 & 3.
      expect(pb.notes[1].endTick, lessThanOrEqualTo(pb.notes[2].startTick));
    });

    test('two-phase pass: accidental fused into a multi-note neume governs '
        'only the matching position, not sounded as a note', () {
      // A neume with [flat-sign-on-B, note B, note C]: the flat sign is not a
      // note; B sounds flat, C unaffected.
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.custom, components: [
          NeumeComponent(
              pitchName: 'B', octave: 4, accidental: NeumeAccidental.flat),
          nc('B', 4),
          nc('C', 5),
        ]),
      ]);
      final ons = noteOns(seq);
      expect(ons.length, 2); // only B and C sound
      expect(ons[0].note, 70); // B4 flat
      expect(ons[1].note, 72); // C5
    });

    test('MidiFileWriter rejects an out-of-range ticksPerQuarter', () {
      final seq = ChantMidiMapper.fromChant([
        Neume(type: NeumeType.punctum, components: [nc('C', 4)]),
      ], options: const ChantPlaybackOptions(ticksPerQuarter: 70000));
      expect(() => MidiFileWriter.write(seq), throwsArgumentError);
    });

    test('gabcToMidiSequence convenience parses and maps in one call', () {
      const gabc = '(c4) Ký(h)ri(hg)e(g) (::)';
      final seq = gabcToMidiSequence(gabc);
      expect(noteOns(seq).length, 4); // h, h, g, g
    });

    test('parses GABC end-to-end and writes a valid .mid header', () {
      const gabc = '''
name: Kyrie;
%%
(c4) Ký(h)ri(h)e(g.) *(,) e(hi)lé(hg)i(g)son.(g) (::)
''';
      final parsed = GabcParser.parse(gabc);
      final seq = ChantMidiMapper.fromChant(parsed.elements);
      expect(noteOns(seq).length, greaterThan(5));

      final bytes = MidiFileWriter.write(seq);
      // 'MThd' magic header.
      expect(bytes.sublist(0, 4), [0x4D, 0x54, 0x68, 0x64]);
      expect(bytes.length, greaterThan(20));
    });

    test('empty chant yields a warning and no notes', () {
      final seq = ChantMidiMapper.fromChant([]);
      expect(noteOns(seq), isEmpty);
      expect(seq.warnings, isNotEmpty);
    });
  });
}
