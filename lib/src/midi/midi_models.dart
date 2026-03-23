import '../../core/dynamic.dart';

enum MidiEventType {
  noteOn,
  noteOff,
  tempo,
  programChange,
  controlChange,
  timeSignature,
  marker,
}

class MidiEvent {
  final int tick;
  final MidiEventType type;
  final int channel;
  final int? note;
  final int? velocity;
  final int? program;
  final int? controller;
  final int? value;
  final int? bpm;
  final int? numerator;
  final int? denominator;
  final String? markerText;

  const MidiEvent._({
    required this.tick,
    required this.type,
    this.channel = 0,
    this.note,
    this.velocity,
    this.program,
    this.controller,
    this.value,
    this.bpm,
    this.numerator,
    this.denominator,
    this.markerText,
  });

  const MidiEvent.noteOn({
    required int tick,
    required int channel,
    required int note,
    required int velocity,
  }) : this._(
         tick: tick,
         type: MidiEventType.noteOn,
         channel: channel,
         note: note,
         velocity: velocity,
       );

  const MidiEvent.noteOff({
    required int tick,
    required int channel,
    required int note,
    int velocity = 0,
  }) : this._(
         tick: tick,
         type: MidiEventType.noteOff,
         channel: channel,
         note: note,
         velocity: velocity,
       );

  const MidiEvent.tempo({required int tick, required int bpm})
    : this._(tick: tick, type: MidiEventType.tempo, bpm: bpm);

  const MidiEvent.programChange({
    required int tick,
    required int channel,
    required int program,
  }) : this._(
         tick: tick,
         type: MidiEventType.programChange,
         channel: channel,
         program: program,
       );

  const MidiEvent.controlChange({
    required int tick,
    required int channel,
    required int controller,
    required int value,
  }) : this._(
         tick: tick,
         type: MidiEventType.controlChange,
         channel: channel,
         controller: controller,
         value: value,
       );

  const MidiEvent.timeSignature({
    required int tick,
    required int numerator,
    required int denominator,
  }) : this._(
         tick: tick,
         type: MidiEventType.timeSignature,
         numerator: numerator,
         denominator: denominator,
       );

  const MidiEvent.marker({required int tick, required String text})
    : this._(tick: tick, type: MidiEventType.marker, markerText: text);
}

class MidiTrack {
  final String name;
  final int channel;
  final List<MidiEvent> events;

  const MidiTrack({
    required this.name,
    required this.channel,
    required this.events,
  });

  MidiTrack copyWith({String? name, int? channel, List<MidiEvent>? events}) {
    return MidiTrack(
      name: name ?? this.name,
      channel: channel ?? this.channel,
      events: events ?? this.events,
    );
  }
}

class MidiSequence {
  final int ticksPerQuarter;
  final List<MidiTrack> tracks;
  final List<String> warnings;

  const MidiSequence({
    required this.ticksPerQuarter,
    required this.tracks,
    this.warnings = const <String>[],
  });

  int get totalTicks {
    int maxTick = 0;
    for (final track in tracks) {
      for (final event in track.events) {
        if (event.tick > maxTick) {
          maxTick = event.tick;
        }
      }
    }
    return maxTick;
  }
}

class MidiInstrumentAssignment {
  final int channel;
  final int program;
  final int velocity;

  const MidiInstrumentAssignment({
    required this.channel,
    required this.program,
    this.velocity = 96,
  });
}

class MidiGenerationOptions {
  final int ticksPerQuarter;
  final int defaultBpm;
  final int repeatDefaultTimes;
  final int maxRepeatCycles;
  final bool includeMetronome;
  final int metronomeChannel;
  final int metronomeAccentNote;
  final int metronomeRegularNote;
  final int metronomeAccentVelocity;
  final int metronomeRegularVelocity;
  final int metronomeClickDurationTicks;
  final bool playGraceNotes;
  final double graceDurationScale;
  final MidiInstrumentAssignment defaultInstrument;
  final Map<int, MidiInstrumentAssignment> instrumentsByStaff;

  const MidiGenerationOptions({
    this.ticksPerQuarter = 960,
    this.defaultBpm = 120,
    this.repeatDefaultTimes = 2,
    this.maxRepeatCycles = 16,
    this.includeMetronome = false,
    this.metronomeChannel = 9,
    this.metronomeAccentNote = 76,
    this.metronomeRegularNote = 77,
    this.metronomeAccentVelocity = 120,
    this.metronomeRegularVelocity = 95,
    this.metronomeClickDurationTicks = 120,
    this.playGraceNotes = true,
    this.graceDurationScale = 0.25,
    this.defaultInstrument = const MidiInstrumentAssignment(
      channel: 0,
      program: 0,
      velocity: 96,
    ),
    this.instrumentsByStaff = const <int, MidiInstrumentAssignment>{},
  });

  MidiGenerationOptions copyWith({
    int? ticksPerQuarter,
    int? defaultBpm,
    int? repeatDefaultTimes,
    int? maxRepeatCycles,
    bool? includeMetronome,
    int? metronomeChannel,
    int? metronomeAccentNote,
    int? metronomeRegularNote,
    int? metronomeAccentVelocity,
    int? metronomeRegularVelocity,
    int? metronomeClickDurationTicks,
    bool? playGraceNotes,
    double? graceDurationScale,
    MidiInstrumentAssignment? defaultInstrument,
    Map<int, MidiInstrumentAssignment>? instrumentsByStaff,
  }) {
    return MidiGenerationOptions(
      ticksPerQuarter: ticksPerQuarter ?? this.ticksPerQuarter,
      defaultBpm: defaultBpm ?? this.defaultBpm,
      repeatDefaultTimes: repeatDefaultTimes ?? this.repeatDefaultTimes,
      maxRepeatCycles: maxRepeatCycles ?? this.maxRepeatCycles,
      includeMetronome: includeMetronome ?? this.includeMetronome,
      metronomeChannel: metronomeChannel ?? this.metronomeChannel,
      metronomeAccentNote: metronomeAccentNote ?? this.metronomeAccentNote,
      metronomeRegularNote: metronomeRegularNote ?? this.metronomeRegularNote,
      metronomeAccentVelocity:
          metronomeAccentVelocity ?? this.metronomeAccentVelocity,
      metronomeRegularVelocity:
          metronomeRegularVelocity ?? this.metronomeRegularVelocity,
      metronomeClickDurationTicks:
          metronomeClickDurationTicks ?? this.metronomeClickDurationTicks,
      playGraceNotes: playGraceNotes ?? this.playGraceNotes,
      graceDurationScale: graceDurationScale ?? this.graceDurationScale,
      defaultInstrument: defaultInstrument ?? this.defaultInstrument,
      instrumentsByStaff: instrumentsByStaff ?? this.instrumentsByStaff,
    );
  }
}

int velocityFromDynamic(DynamicType dynamicType) {
  return switch (dynamicType) {
    DynamicType.pppp => 18,
    DynamicType.ppp => 26,
    DynamicType.pp => 34,
    DynamicType.p => 42,
    DynamicType.mp => 56,
    DynamicType.mf => 74,
    DynamicType.f => 92,
    DynamicType.ff => 108,
    DynamicType.fff => 120,
    DynamicType.ffff => 126,
    DynamicType.pianissimo => 34,
    DynamicType.piano => 42,
    DynamicType.mezzoPiano => 56,
    DynamicType.mezzoForte => 74,
    DynamicType.forte => 92,
    DynamicType.fortissimo => 108,
    DynamicType.fortississimo => 120,
    DynamicType.sforzando => 112,
    DynamicType.sforzandoFF => 124,
    DynamicType.sforzandoPiano => 84,
    DynamicType.sforzandoPianissimo => 70,
    DynamicType.rinforzando => 108,
    DynamicType.fortePiano => 86,
    DynamicType.niente => 8,
    _ => 96,
  };
}
