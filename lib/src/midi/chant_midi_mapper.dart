// Gregorian chant -> MIDI mapping (playback / .mid export).
//
// Chant is monophonic, free-rhythm, and has NO absolute pitch. By the time the
// elements reach this mapper their note letters have already been resolved to
// real diatonic pitches relative to the clef (see GabcParser), so the mapper
// simply: resolves each component to its [Pitch.midiNumber], honours accidental
// signs (flat/natural/sharp, local until the next divisio) plus an optional
// clef-flat soft-B (key-signature-like), approximates the free rhythm as an
// equal pulse with mora-dot lengthening, and inserts breath rests at
// divisiones. Absolute register is a configurable [ChantPlaybackOptions.transpose].
// The result is a standard [MidiSequence] — the existing MIDI file writer and
// native audio backend play/export it unchanged.

import '../../core/musical_element.dart';
import '../../core/neume.dart';
import '../../core/pitch.dart';
import 'midi_models.dart';

/// Tuning knobs for chant playback. Durations are in quarter notes; defaults
/// give a flowing, neutral interpretation (each punctum one pulse, a mora dot
/// doubling it). Stylistic nuances (episema agogic, liquescent lightening, ictus
/// accent) are neutral by default and opt-in.
class ChantPlaybackOptions {
  /// MIDI time resolution (ticks per quarter note). Valid SMF range 1..32767.
  final int ticksPerQuarter;

  /// Tempo in beats (quarter notes) per minute.
  final int bpm;

  /// Voice instrument (channel/program/velocity). Default program 52 = "Choir
  /// Aahs". Reuses the shared [MidiInstrumentAssignment] value object.
  final MidiInstrumentAssignment instrument;

  /// Semitones added to every note. Chant has no fixed pitch, so this only
  /// chooses a comfortable register.
  final int transpose;

  /// Duration of a single punctum (the basic pulse), in quarter notes.
  final double baseNoteQuarters;

  /// Quarter notes added per mora (augmentum) dot. With the default equal to
  /// [baseNoteQuarters], one dot doubles the note.
  final double moraExtraQuarters;

  /// Duration multiplier for a note carrying a horizontal episema (agogic
  /// broadening). 1.0 = neutral.
  final double episemaScale;

  /// Duration multiplier for a liquescent (deminutus) note. 1.0 = neutral;
  /// values < 1 lighten/shorten the melted note.
  final double liquescentScale;

  /// Velocity added to a note carrying an ictus (rhythmic touch-point).
  final int ictusVelocityBoost;

  /// Breath-rest durations at each divisio, in quarter notes.
  final double divisioMinimaQuarters;
  final double divisioMinorQuarters;
  final double divisioMaiorQuarters;
  final double divisioFinalisQuarters;

  /// Whether inline accidentals persist only until the next divisio (chant
  /// rule). The clef-flat soft-B is unaffected — it persists like a key sig.
  final bool accidentalResetsAtDivisio;

  const ChantPlaybackOptions({
    this.ticksPerQuarter = 960,
    this.bpm = 130,
    this.instrument = const MidiInstrumentAssignment(
      channel: 0,
      program: 52,
      velocity: 90,
    ),
    this.transpose = 0,
    this.baseNoteQuarters = 1.0,
    this.moraExtraQuarters = 1.0,
    this.episemaScale = 1.0,
    this.liquescentScale = 1.0,
    this.ictusVelocityBoost = 0,
    this.divisioMinimaQuarters = 0.5,
    this.divisioMinorQuarters = 1.0,
    this.divisioMaiorQuarters = 2.0,
    this.divisioFinalisQuarters = 2.0,
    this.accidentalResetsAtDivisio = true,
  });

  ChantPlaybackOptions copyWith({
    int? ticksPerQuarter,
    int? bpm,
    MidiInstrumentAssignment? instrument,
    int? transpose,
    double? baseNoteQuarters,
    double? moraExtraQuarters,
    double? episemaScale,
    double? liquescentScale,
    int? ictusVelocityBoost,
    double? divisioMinimaQuarters,
    double? divisioMinorQuarters,
    double? divisioMaiorQuarters,
    double? divisioFinalisQuarters,
    bool? accidentalResetsAtDivisio,
  }) {
    return ChantPlaybackOptions(
      ticksPerQuarter: ticksPerQuarter ?? this.ticksPerQuarter,
      bpm: bpm ?? this.bpm,
      instrument: instrument ?? this.instrument,
      transpose: transpose ?? this.transpose,
      baseNoteQuarters: baseNoteQuarters ?? this.baseNoteQuarters,
      moraExtraQuarters: moraExtraQuarters ?? this.moraExtraQuarters,
      episemaScale: episemaScale ?? this.episemaScale,
      liquescentScale: liquescentScale ?? this.liquescentScale,
      ictusVelocityBoost: ictusVelocityBoost ?? this.ictusVelocityBoost,
      divisioMinimaQuarters:
          divisioMinimaQuarters ?? this.divisioMinimaQuarters,
      divisioMinorQuarters: divisioMinorQuarters ?? this.divisioMinorQuarters,
      divisioMaiorQuarters: divisioMaiorQuarters ?? this.divisioMaiorQuarters,
      divisioFinalisQuarters:
          divisioFinalisQuarters ?? this.divisioFinalisQuarters,
      accidentalResetsAtDivisio:
          accidentalResetsAtDivisio ?? this.accidentalResetsAtDivisio,
    );
  }
}

/// Timing of one sounded chant note, for playback highlighting / seeking in an
/// editor: which [component] of which [neume] sounds when, and at what pitch.
class ChantNoteTiming {
  final Neume neume;
  final NeumeComponent component;
  final int startTick;
  final int endTick;
  final int midiNote;

  const ChantNoteTiming({
    required this.neume,
    required this.component,
    required this.startTick,
    required this.endTick,
    required this.midiNote,
  });
}

/// Result of building chant playback: the [sequence] to play/export plus a
/// per-note [notes] timeline keyed back to the source elements.
class ChantPlayback {
  final MidiSequence sequence;
  final List<ChantNoteTiming> notes;

  const ChantPlayback({required this.sequence, required this.notes});
}

/// Converts a chant element stream (the same `List<MusicalElement>` rendered by
/// `ChantScore` / produced by `GabcParser`) into a [MidiSequence].
class ChantMidiMapper {
  /// Builds a [MidiSequence] from a flat list of [Neume]/[NeumeDivision].
  ///
  /// Set [softB] for a clef-flat (every si/B is flat until a natural cancels it,
  /// persisting across divisiones like a key signature).
  static MidiSequence fromChant(
    List<MusicalElement> elements, {
    ChantPlaybackOptions options = const ChantPlaybackOptions(),
    bool softB = false,
    String trackName = 'Chant',
  }) =>
      build(elements, options: options, softB: softB, trackName: trackName)
          .sequence;

  /// Like [fromChant] but also returns the per-note [ChantPlayback.notes]
  /// timeline (for playback cursor / highlighting in an editor).
  static ChantPlayback build(
    List<MusicalElement> elements, {
    ChantPlaybackOptions options = const ChantPlaybackOptions(),
    bool softB = false,
    String trackName = 'Chant',
  }) {
    final tpq = options.ticksPerQuarter;
    int q2t(double quarters) {
      final t = (quarters * tpq).round();
      return t < 0 ? 0 : t;
    }

    final warnings = <String>[];
    final timings = <ChantNoteTiming>[];
    final events = <MidiEvent>[
      MidiEvent.programChange(
        tick: 0,
        channel: options.instrument.channel,
        program: options.instrument.program.clamp(0, 127),
      ),
    ];

    // Active inline accidental per staff position (step+octave) -> semitones.
    final alter = <String, int>{};
    String keyOf(String step, int octave) => '$step$octave';

    var cursor = 0;
    var sounded = 0;
    var unpitched = 0;
    var clamped = 0;

    int effectiveAlter(NeumeComponent c) {
      final k = keyOf(c.pitchName!, c.octave!);
      if (alter.containsKey(k)) return alter[k]!;
      if (softB && c.pitchName == 'B') return -1; // clef-flat soft si
      return 0;
    }

    double noteQuarters(NeumeComponent c) {
      var q = options.baseNoteQuarters + c.morae * options.moraExtraQuarters;
      if (c.episema) q *= options.episemaScale;
      if (c.isLiquescent) q *= options.liquescentScale;
      return q;
    }

    for (final el in elements) {
      if (el is NeumeDivision) {
        if (options.accidentalResetsAtDivisio) alter.clear();
        cursor += q2t(_divisioQuarters(el.type, options));
        continue;
      }
      if (el is! Neume) continue;

      // Phase 1: register every accidental sign in this neume (a component with
      // an accidental is a sign, not a sounding note — even if fused).
      for (final c in el.components) {
        if (c.accidental != NeumeAccidental.none &&
            c.pitchName != null &&
            c.octave != null) {
          alter[keyOf(c.pitchName!, c.octave!)] =
              _accidentalSemitones(c.accidental);
        }
      }

      // Phase 2: sound the note components (skip accidental signs).
      for (final c in el.components) {
        if (c.accidental != NeumeAccidental.none) continue;

        if (c.pitchName == null || c.octave == null) {
          unpitched++;
          cursor += q2t(noteQuarters(c)); // keep the intended pulse
          continue;
        }

        final durTicks = q2t(noteQuarters(c)).clamp(1, 1 << 30);
        final natural =
            Pitch(step: c.pitchName!, octave: c.octave!).midiNumber;
        final raw = natural + effectiveAlter(c) + options.transpose;
        final midi = raw.clamp(0, 127);
        if (raw != midi) clamped++;

        var vel = options.instrument.velocity;
        if (c.ictus) vel = vel + options.ictusVelocityBoost;
        vel = vel.clamp(1, 127);

        events.add(MidiEvent.noteOn(
          tick: cursor,
          channel: options.instrument.channel,
          note: midi,
          velocity: vel,
        ));
        events.add(MidiEvent.noteOff(
          tick: cursor + durTicks,
          channel: options.instrument.channel,
          note: midi,
        ));
        timings.add(ChantNoteTiming(
          neume: el,
          component: c,
          startTick: cursor,
          endTick: cursor + durTicks,
          midiNote: midi,
        ));
        cursor += durTicks;
        sounded++;
      }
    }

    if (sounded == 0) warnings.add('Chant produced no sounding notes.');
    if (unpitched > 0) {
      warnings.add(
          '$unpitched neume component(s) had no resolvable pitch; inserted '
          'silent pulse(s).');
    }
    if (clamped > 0) {
      warnings.add(
          '$clamped note(s) clamped into the MIDI 0..127 range by transpose='
          '${options.transpose}; adjust transpose to avoid folding pitches.');
    }

    final sequence = MidiSequence(
      ticksPerQuarter: tpq,
      tracks: <MidiTrack>[
        MidiTrack(
          name: 'Conductor',
          channel: 0,
          events: <MidiEvent>[MidiEvent.tempo(tick: 0, bpm: options.bpm)],
        ),
        MidiTrack(
          name: trackName,
          channel: options.instrument.channel,
          events: events,
        ),
      ],
      warnings: warnings,
    );
    return ChantPlayback(sequence: sequence, notes: timings);
  }

  static int _accidentalSemitones(NeumeAccidental a) => switch (a) {
        NeumeAccidental.flat => -1,
        NeumeAccidental.sharp => 1,
        NeumeAccidental.natural => 0,
        NeumeAccidental.none => 0,
      };

  static double _divisioQuarters(
          NeumeDivisionType t, ChantPlaybackOptions o) =>
      switch (t) {
        NeumeDivisionType.minima => o.divisioMinimaQuarters,
        NeumeDivisionType.minor => o.divisioMinorQuarters,
        NeumeDivisionType.maior => o.divisioMaiorQuarters,
        NeumeDivisionType.finalis => o.divisioFinalisQuarters,
      };
}
