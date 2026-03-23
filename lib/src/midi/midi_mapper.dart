import '../../core/barline.dart';
import '../../core/chord.dart';
import '../../core/duration.dart' as music;
import '../../core/dynamic.dart';
import '../../core/measure.dart';
import '../../core/musical_element.dart';
import '../../core/note.dart';
import '../../core/repeat.dart';
import '../../core/rest.dart';
import '../../core/score.dart';
import '../../core/staff.dart';
import '../../core/tempo.dart';
import '../../core/text.dart';
import '../../core/time_signature.dart';
import '../../core/tuplet.dart';
import '../../core/voice.dart';
import '../../core/volta_bracket.dart';
import 'midi_models.dart';

class MidiMapper {
  static MidiSequence fromStaff(
    Staff staff, {
    MidiGenerationOptions options = const MidiGenerationOptions(),
    String trackName = 'Staff 1',
  }) {
    final instrument =
        options.instrumentsByStaff[0] ?? options.defaultInstrument;
    final result = _buildTrackFromStaff(
      staff: staff,
      options: options,
      instrument: instrument,
      trackName: trackName,
    );

    final tracks = <MidiTrack>[
      MidiTrack(name: 'Conductor', channel: 0, events: result.metaEvents),
      result.track,
    ];

    if (options.includeMetronome && result.playedMeasures.isNotEmpty) {
      tracks.add(
        _buildMetronomeTrack(
          playedMeasures: result.playedMeasures,
          options: options,
        ),
      );
    }

    return MidiSequence(
      ticksPerQuarter: options.ticksPerQuarter,
      tracks: tracks,
      warnings: result.warnings,
    );
  }

  static MidiSequence fromScore(
    Score score, {
    MidiGenerationOptions options = const MidiGenerationOptions(),
  }) {
    final staves = score.allStaves;
    final warnings = <String>[];

    if (staves.isEmpty) {
      return MidiSequence(
        ticksPerQuarter: options.ticksPerQuarter,
        tracks: const <MidiTrack>[],
        warnings: const <String>[
          'Score without staves; no MIDI track generated.',
        ],
      );
    }

    final results = <_TrackBuildResult>[];
    for (int staffIndex = 0; staffIndex < staves.length; staffIndex++) {
      final configured = options.instrumentsByStaff[staffIndex];
      final instrument =
          configured ?? _defaultInstrumentForStaff(staffIndex, options);

      final trackResult = _buildTrackFromStaff(
        staff: staves[staffIndex],
        options: options,
        instrument: instrument,
        trackName: 'Staff ${staffIndex + 1}',
      );
      results.add(trackResult);
      warnings.addAll(trackResult.warnings);
    }

    final conductorEvents = <MidiEvent>[
      MidiEvent.tempo(tick: 0, bpm: options.defaultBpm),
      for (final result in results) ...result.metaEvents,
    ];
    _dedupeMetaEvents(conductorEvents, defaultBpm: options.defaultBpm);

    final tracks = <MidiTrack>[
      MidiTrack(
        name: 'Conductor',
        channel: 0,
        events: _sortedEvents(conductorEvents),
      ),
      for (final result in results) result.track,
    ];

    if (options.includeMetronome && results.isNotEmpty) {
      tracks.add(
        _buildMetronomeTrack(
          playedMeasures: results.first.playedMeasures,
          options: options,
        ),
      );
    }

    return MidiSequence(
      ticksPerQuarter: options.ticksPerQuarter,
      tracks: tracks,
      warnings: warnings,
    );
  }
}

_TrackBuildResult _buildTrackFromStaff({
  required Staff staff,
  required MidiGenerationOptions options,
  required MidiInstrumentAssignment instrument,
  required String trackName,
}) {
  final warnings = <String>[];
  final playOrder = _buildPlaybackOrder(staff.measures, options, warnings);
  final playedMeasures = _buildPlayedMeasureTimeline(
    staff.measures,
    playOrder,
    options.ticksPerQuarter,
  );

  final builder = _TrackEventBuilder(
    channel: instrument.channel,
    options: options,
    baseVelocity: instrument.velocity,
  );

  builder.events.add(
    MidiEvent.programChange(
      tick: 0,
      channel: instrument.channel,
      program: instrument.program.clamp(0, 127),
    ),
  );
  builder.metaEvents.add(MidiEvent.tempo(tick: 0, bpm: options.defaultBpm));

  for (final played in playedMeasures) {
    final measure = staff.measures[played.measureIndex];
    builder.processMeasure(
      measure: measure,
      measureStartTick: played.startTick,
      measureEndTick: played.endTick,
      repeatPass: played.repeatPass,
    );
  }

  final trackEndTick = playedMeasures.isEmpty ? 0 : playedMeasures.last.endTick;
  builder.closeOpenTies(trackEndTick);
  _dedupeMetaEvents(builder.metaEvents, defaultBpm: options.defaultBpm);

  return _TrackBuildResult(
    track: MidiTrack(
      name: trackName,
      channel: instrument.channel,
      events: _sortedEvents(builder.events),
    ),
    metaEvents: _sortedEvents(builder.metaEvents),
    warnings: <String>[...warnings, ...builder.warnings],
    playedMeasures: playedMeasures,
  );
}

class _TrackEventBuilder {
  _TrackEventBuilder({
    required this.channel,
    required this.options,
    required this.baseVelocity,
  });

  final int channel;
  final int baseVelocity;
  final MidiGenerationOptions options;

  final List<MidiEvent> events = <MidiEvent>[];
  final List<MidiEvent> metaEvents = <MidiEvent>[];
  final List<String> warnings = <String>[];

  final Map<int, int> _voiceVelocity = <int, int>{};
  final Map<_TieKey, _TieState> _openTies = <_TieKey, _TieState>{};

  void processMeasure({
    required Measure measure,
    required int measureStartTick,
    required int measureEndTick,
    required int repeatPass,
  }) {
    if (measure is MultiVoiceMeasure) {
      for (final element in measure.elements) {
        _consumeElement(
          element: element,
          tick: measureStartTick,
          voiceNumber: 1,
          tupletMultiplier: 1.0,
        );
      }

      for (final voice in measure.sortedVoices) {
        int localTick = measureStartTick;
        _voiceVelocity.putIfAbsent(voice.number, () => baseVelocity);
        for (final element in voice.elements) {
          final consumed = _consumeElement(
            element: element,
            tick: localTick,
            voiceNumber: voice.number,
            tupletMultiplier: 1.0,
          );
          localTick += consumed;
        }

        if (localTick > measureEndTick) {
          warnings.add(
            'Voice ${voice.number} overflowed measure by '
            '${localTick - measureEndTick} ticks.',
          );
        }
      }
      return;
    }

    int localTick = measureStartTick;
    for (final element in measure.elements) {
      final consumed = _consumeElement(
        element: element,
        tick: localTick,
        voiceNumber: 1,
        tupletMultiplier: 1.0,
      );
      localTick += consumed;
    }

    if (localTick > measureEndTick) {
      warnings.add(
        'Measure overflowed by ${localTick - measureEndTick} ticks.',
      );
    }

    if (_measureHasRepeatStart(measure)) {
      metaEvents.add(
        MidiEvent.marker(
          tick: measureStartTick,
          text: 'repeat-start (pass $repeatPass)',
        ),
      );
    }
    if (_measureHasRepeatEnd(measure)) {
      metaEvents.add(
        MidiEvent.marker(
          tick: measureEndTick,
          text: 'repeat-end (pass $repeatPass)',
        ),
      );
    }
  }

  void closeOpenTies(int sequenceEndTick) {
    for (final entry in _openTies.entries) {
      final tieEnd = entry.value.endTick > sequenceEndTick
          ? entry.value.endTick
          : sequenceEndTick;
      events.add(
        MidiEvent.noteOff(tick: tieEnd, channel: channel, note: entry.key.note),
      );
    }
    _openTies.clear();
  }

  int _consumeElement({
    required MusicalElement element,
    required int tick,
    required int voiceNumber,
    required double tupletMultiplier,
  }) {
    if (element is Note) {
      return _emitNote(
        note: element,
        startTick: tick,
        voiceNumber: voiceNumber,
        tupletMultiplier: tupletMultiplier,
      );
    }

    if (element is Chord) {
      return _emitChord(
        chord: element,
        startTick: tick,
        voiceNumber: voiceNumber,
        tupletMultiplier: tupletMultiplier,
      );
    }

    if (element is Rest) {
      return _durationToTicks(
        duration: element.duration,
        tupletMultiplier: tupletMultiplier,
        isGraceNote: false,
        options: options,
      );
    }

    if (element is Tuplet) {
      final tupletRatio = element.ratio.modifier;
      int localTick = tick;
      for (final tupletElement in element.elements) {
        final consumed = _consumeElement(
          element: tupletElement,
          tick: localTick,
          voiceNumber: voiceNumber,
          tupletMultiplier: tupletMultiplier * tupletRatio,
        );
        localTick += consumed;
      }
      return localTick - tick;
    }

    if (element is TempoMark) {
      if (element.bpm != null) {
        metaEvents.add(MidiEvent.tempo(tick: tick, bpm: element.bpm!));
      }
      if (element.text != null && element.text!.trim().isNotEmpty) {
        metaEvents.add(
          MidiEvent.marker(tick: tick, text: element.text!.trim()),
        );
      }
      return 0;
    }

    if (element is TimeSignature) {
      metaEvents.add(
        MidiEvent.timeSignature(
          tick: tick,
          numerator: element.numerator,
          denominator: element.denominator,
        ),
      );
      return 0;
    }

    if (element is Dynamic) {
      _voiceVelocity[voiceNumber] = velocityFromDynamic(element.type);
      return 0;
    }

    if (element is RepeatMark) {
      final label = element.label ?? element.type.name;
      metaEvents.add(MidiEvent.marker(tick: tick, text: label));
      return 0;
    }

    if (element is VoltaBracket) {
      metaEvents.add(
        MidiEvent.marker(tick: tick, text: 'volta ${element.displayLabel}'),
      );
      return 0;
    }

    if (element is MusicText &&
        (element.type == TextType.instruction ||
            element.type == TextType.tempo)) {
      metaEvents.add(MidiEvent.marker(tick: tick, text: element.text));
      return 0;
    }

    return 0;
  }

  int _emitNote({
    required Note note,
    required int startTick,
    required int voiceNumber,
    required double tupletMultiplier,
  }) {
    if (note.isGraceNote && !options.playGraceNotes) {
      return 0;
    }

    final durationTicks = _durationToTicks(
      duration: note.duration,
      tupletMultiplier: tupletMultiplier,
      isGraceNote: note.isGraceNote,
      options: options,
    );
    final midiNote = note.pitch.midiNumber.clamp(0, 127);
    final velocity = note.dynamicElement != null
        ? velocityFromDynamic(note.dynamicElement!.type)
        : (_voiceVelocity[voiceNumber] ?? baseVelocity);

    _emitTiedNote(
      midiNote: midiNote,
      startTick: startTick,
      durationTicks: durationTicks,
      velocity: velocity,
      tieType: note.tie,
      voiceNumber: voiceNumber,
    );

    return durationTicks;
  }

  int _emitChord({
    required Chord chord,
    required int startTick,
    required int voiceNumber,
    required double tupletMultiplier,
  }) {
    final durationTicks = _durationToTicks(
      duration: chord.duration,
      tupletMultiplier: tupletMultiplier,
      isGraceNote: false,
      options: options,
    );

    final dynamicVelocity = chord.dynamic != null
        ? velocityFromDynamic(chord.dynamic!.type)
        : (_voiceVelocity[voiceNumber] ?? baseVelocity);

    for (final chordNote in chord.notes) {
      final midiNote = chordNote.pitch.midiNumber.clamp(0, 127);
      final noteVelocity = chordNote.dynamicElement != null
          ? velocityFromDynamic(chordNote.dynamicElement!.type)
          : dynamicVelocity;

      _emitTiedNote(
        midiNote: midiNote,
        startTick: startTick,
        durationTicks: durationTicks,
        velocity: noteVelocity,
        tieType: chordNote.tie ?? chord.tie,
        voiceNumber: voiceNumber,
      );
    }

    return durationTicks;
  }

  void _emitTiedNote({
    required int midiNote,
    required int startTick,
    required int durationTicks,
    required int velocity,
    required TieType? tieType,
    required int voiceNumber,
  }) {
    final key = _TieKey(voiceNumber: voiceNumber, note: midiNote);
    final endTick = startTick + durationTicks;

    switch (tieType) {
      case TieType.start:
        if (!_openTies.containsKey(key)) {
          events.add(
            MidiEvent.noteOn(
              tick: startTick,
              channel: channel,
              note: midiNote,
              velocity: velocity.clamp(1, 127),
            ),
          );
        }
        _openTies[key] = _TieState(endTick: endTick);
        return;

      case TieType.inner:
        if (_openTies.containsKey(key)) {
          _openTies[key] = _TieState(endTick: endTick);
        } else {
          events.add(
            MidiEvent.noteOn(
              tick: startTick,
              channel: channel,
              note: midiNote,
              velocity: velocity.clamp(1, 127),
            ),
          );
          _openTies[key] = _TieState(endTick: endTick);
        }
        return;

      case TieType.end:
        final existing = _openTies.remove(key);
        if (existing == null) {
          events.add(
            MidiEvent.noteOn(
              tick: startTick,
              channel: channel,
              note: midiNote,
              velocity: velocity.clamp(1, 127),
            ),
          );
          events.add(
            MidiEvent.noteOff(tick: endTick, channel: channel, note: midiNote),
          );
        } else {
          final tieOffTick = endTick > existing.endTick
              ? endTick
              : existing.endTick;
          events.add(
            MidiEvent.noteOff(
              tick: tieOffTick,
              channel: channel,
              note: midiNote,
            ),
          );
        }
        return;

      case null:
        final existing = _openTies.remove(key);
        if (existing != null) {
          events.add(
            MidiEvent.noteOff(
              tick: startTick,
              channel: channel,
              note: midiNote,
            ),
          );
        }
        events.add(
          MidiEvent.noteOn(
            tick: startTick,
            channel: channel,
            note: midiNote,
            velocity: velocity.clamp(1, 127),
          ),
        );
        events.add(
          MidiEvent.noteOff(tick: endTick, channel: channel, note: midiNote),
        );
        return;
    }
  }
}

class _TrackBuildResult {
  final MidiTrack track;
  final List<MidiEvent> metaEvents;
  final List<String> warnings;
  final List<_PlayedMeasureTiming> playedMeasures;

  const _TrackBuildResult({
    required this.track,
    required this.metaEvents,
    required this.warnings,
    required this.playedMeasures,
  });
}

class _RepeatSection {
  final int startMeasure;
  final int endMeasure;
  final int times;

  const _RepeatSection({
    required this.startMeasure,
    required this.endMeasure,
    required this.times,
  });
}

class _PlaybackMeasureRef {
  final int measureIndex;
  final int repeatPass;

  const _PlaybackMeasureRef({
    required this.measureIndex,
    required this.repeatPass,
  });
}

class _PlayedMeasureTiming {
  final int measureIndex;
  final int repeatPass;
  final int startTick;
  final int endTick;
  final TimeSignature? timeSignature;

  const _PlayedMeasureTiming({
    required this.measureIndex,
    required this.repeatPass,
    required this.startTick,
    required this.endTick,
    required this.timeSignature,
  });
}

class _TieKey {
  final int voiceNumber;
  final int note;

  const _TieKey({required this.voiceNumber, required this.note});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _TieKey &&
        other.voiceNumber == voiceNumber &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(voiceNumber, note);
}

class _TieState {
  final int endTick;

  const _TieState({required this.endTick});
}

List<_PlaybackMeasureRef> _buildPlaybackOrder(
  List<Measure> measures,
  MidiGenerationOptions options,
  List<String> warnings,
) {
  if (measures.isEmpty) return const <_PlaybackMeasureRef>[];

  final sections = _detectRepeatSections(measures, options);
  final byStart = <int, _RepeatSection>{
    for (final section in sections) section.startMeasure: section,
  };

  final order = <_PlaybackMeasureRef>[];
  int cursor = 0;

  while (cursor < measures.length) {
    final section = byStart[cursor];
    if (section == null) {
      order.add(_PlaybackMeasureRef(measureIndex: cursor, repeatPass: 1));
      cursor++;
      continue;
    }

    final times = section.times <= 0 ? 1 : section.times;
    if (times > options.maxRepeatCycles) {
      warnings.add(
        'Repeat section at measure ${section.startMeasure + 1} capped at '
        '${options.maxRepeatCycles} cycles.',
      );
    }

    final effectiveTimes = times.clamp(1, options.maxRepeatCycles);
    for (int pass = 1; pass <= effectiveTimes; pass++) {
      for (int i = section.startMeasure; i <= section.endMeasure; i++) {
        if (_shouldPlayMeasureOnPass(measures[i], pass)) {
          order.add(_PlaybackMeasureRef(measureIndex: i, repeatPass: pass));
        }
      }
    }

    cursor = section.endMeasure + 1;
  }

  return order;
}

List<_RepeatSection> _detectRepeatSections(
  List<Measure> measures,
  MidiGenerationOptions options,
) {
  final sections = <_RepeatSection>[];
  int currentStart = 0;

  for (int i = 0; i < measures.length; i++) {
    final measure = measures[i];
    if (_measureHasRepeatStart(measure)) {
      currentStart = i;
    }

    if (_measureHasRepeatEnd(measure)) {
      final explicitTimes = _repeatTimes(measure);
      final times = explicitTimes ?? options.repeatDefaultTimes;
      sections.add(
        _RepeatSection(
          startMeasure: currentStart,
          endMeasure: i,
          times: times <= 0 ? 1 : times,
        ),
      );
      currentStart = i + 1;
    }
  }

  return sections;
}

bool _measureHasRepeatStart(Measure measure) {
  return measure.elements.any((element) {
    if (element is Barline) {
      return element.type == BarlineType.repeatForward ||
          element.type == BarlineType.repeatBoth;
    }
    if (element is RepeatMark) {
      return element.type == RepeatType.start;
    }
    return false;
  });
}

bool _measureHasRepeatEnd(Measure measure) {
  return measure.elements.any((element) {
    if (element is Barline) {
      return element.type == BarlineType.repeatBackward ||
          element.type == BarlineType.repeatBoth;
    }
    if (element is RepeatMark) {
      return element.type == RepeatType.end;
    }
    return false;
  });
}

int? _repeatTimes(Measure measure) {
  for (final element in measure.elements) {
    if (element is RepeatMark &&
        element.type == RepeatType.end &&
        element.times != null) {
      return element.times;
    }
  }
  return null;
}

bool _shouldPlayMeasureOnPass(Measure measure, int pass) {
  final voltaPasses = _extractVoltaPasses(measure);
  if (voltaPasses.isEmpty) return true;
  return voltaPasses.contains(pass);
}

Set<int> _extractVoltaPasses(Measure measure) {
  final result = <int>{};
  for (final element in measure.elements) {
    if (element is! VoltaBracket) continue;

    result.add(element.number);
    final label = element.label;
    if (label == null || label.trim().isEmpty) continue;

    final numbers = RegExp(r'\d+')
        .allMatches(label)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();
    if (numbers.isEmpty) continue;

    if (label.contains('-') && numbers.length >= 2) {
      final minNumber = numbers.reduce((a, b) => a < b ? a : b);
      final maxNumber = numbers.reduce((a, b) => a > b ? a : b);
      for (int value = minNumber; value <= maxNumber; value++) {
        result.add(value);
      }
    } else {
      result.addAll(numbers);
    }
  }
  return result;
}

List<_PlayedMeasureTiming> _buildPlayedMeasureTimeline(
  List<Measure> measures,
  List<_PlaybackMeasureRef> playOrder,
  int ticksPerQuarter,
) {
  final timeline = <_PlayedMeasureTiming>[];
  TimeSignature? currentTimeSignature;
  int cursor = 0;

  for (final reference in playOrder) {
    final measure = measures[reference.measureIndex];
    final measureTimeSignature = measure.timeSignature;
    if (measureTimeSignature != null) {
      currentTimeSignature = measureTimeSignature;
    }

    final activeTimeSignature = measureTimeSignature ?? currentTimeSignature;
    final measureTicks = _measureLengthTicks(
      measure: measure,
      timeSignature: activeTimeSignature,
      ticksPerQuarter: ticksPerQuarter,
    );

    timeline.add(
      _PlayedMeasureTiming(
        measureIndex: reference.measureIndex,
        repeatPass: reference.repeatPass,
        startTick: cursor,
        endTick: cursor + measureTicks,
        timeSignature: activeTimeSignature,
      ),
    );
    cursor += measureTicks;
  }

  return timeline;
}

int _measureLengthTicks({
  required Measure measure,
  required TimeSignature? timeSignature,
  required int ticksPerQuarter,
}) {
  if (timeSignature != null) {
    final beatsInQuarter =
        timeSignature.numerator * (4.0 / timeSignature.denominator);
    final ticks = (beatsInQuarter * ticksPerQuarter).round();
    return ticks <= 0 ? ticksPerQuarter : ticks;
  }

  final quarters = _measureLengthInQuarterNotes(measure);
  final ticks = (quarters * ticksPerQuarter).round();
  return ticks <= 0 ? ticksPerQuarter * 4 : ticks;
}

double _measureLengthInQuarterNotes(Measure measure) {
  if (measure is MultiVoiceMeasure) {
    double maxLength = 0.0;
    for (final voice in measure.sortedVoices) {
      final duration = _elementsLengthInQuarterNotes(voice.elements, 1.0);
      if (duration > maxLength) {
        maxLength = duration;
      }
    }
    return maxLength;
  }
  return _elementsLengthInQuarterNotes(measure.elements, 1.0);
}

double _elementsLengthInQuarterNotes(
  List<MusicalElement> elements,
  double tupletMultiplier,
) {
  double total = 0.0;
  for (final element in elements) {
    if (element is Note) {
      total += element.duration.realValue * 4.0 * tupletMultiplier;
      continue;
    }
    if (element is Rest) {
      total += element.duration.realValue * 4.0 * tupletMultiplier;
      continue;
    }
    if (element is Chord) {
      total += element.duration.realValue * 4.0 * tupletMultiplier;
      continue;
    }
    if (element is Tuplet) {
      total += _elementsLengthInQuarterNotes(
        element.elements,
        tupletMultiplier * element.ratio.modifier,
      );
    }
  }
  return total;
}

int _durationToTicks({
  required music.Duration duration,
  required double tupletMultiplier,
  required bool isGraceNote,
  required MidiGenerationOptions options,
}) {
  double quarterNotes = duration.realValue * 4.0 * tupletMultiplier;
  if (isGraceNote) {
    quarterNotes *= options.graceDurationScale;
  }
  final ticks = (quarterNotes * options.ticksPerQuarter).round();
  return ticks <= 0 ? 1 : ticks;
}

MidiTrack _buildMetronomeTrack({
  required List<_PlayedMeasureTiming> playedMeasures,
  required MidiGenerationOptions options,
}) {
  final events = <MidiEvent>[];

  for (final played in playedMeasures) {
    final numerator = played.timeSignature?.numerator ?? 4;
    final beatsInMeasure = numerator <= 0 ? 1 : numerator;
    final measureTicks = played.endTick - played.startTick;
    final beatTicks = measureTicks / beatsInMeasure;

    for (int beat = 0; beat < beatsInMeasure; beat++) {
      final startTick = played.startTick + (beat * beatTicks).round();
      final note = beat == 0
          ? options.metronomeAccentNote
          : options.metronomeRegularNote;
      final velocity = beat == 0
          ? options.metronomeAccentVelocity
          : options.metronomeRegularVelocity;
      final endTick = startTick + options.metronomeClickDurationTicks;

      events.add(
        MidiEvent.noteOn(
          tick: startTick,
          channel: options.metronomeChannel,
          note: note.clamp(0, 127),
          velocity: velocity.clamp(1, 127),
        ),
      );
      events.add(
        MidiEvent.noteOff(
          tick: endTick,
          channel: options.metronomeChannel,
          note: note.clamp(0, 127),
        ),
      );
    }
  }

  return MidiTrack(
    name: 'Metronome',
    channel: options.metronomeChannel,
    events: _sortedEvents(events),
  );
}

MidiInstrumentAssignment _defaultInstrumentForStaff(
  int staffIndex,
  MidiGenerationOptions options,
) {
  int channel = (options.defaultInstrument.channel + staffIndex) % 16;
  if (channel == options.metronomeChannel) {
    channel = (channel + 1) % 16;
  }
  return MidiInstrumentAssignment(
    channel: channel,
    program: options.defaultInstrument.program,
    velocity: options.defaultInstrument.velocity,
  );
}

void _dedupeMetaEvents(List<MidiEvent> events, {required int defaultBpm}) {
  if (events.isEmpty) {
    events.add(MidiEvent.tempo(tick: 0, bpm: defaultBpm));
    return;
  }

  final deduped = <String, MidiEvent>{};
  for (final event in events) {
    final key = switch (event.type) {
      MidiEventType.tempo => 'tempo:${event.tick}:${event.bpm}',
      MidiEventType.timeSignature =>
        'timesig:${event.tick}:${event.numerator}:${event.denominator}',
      MidiEventType.marker => 'marker:${event.tick}:${event.markerText}',
      _ => 'meta:${event.type}:${event.tick}',
    };
    deduped[key] = event;
  }

  events
    ..clear()
    ..addAll(deduped.values);

  final hasTempoAtZero = events.any(
    (event) => event.type == MidiEventType.tempo && event.tick == 0,
  );
  if (!hasTempoAtZero) {
    events.add(MidiEvent.tempo(tick: 0, bpm: defaultBpm));
  }
}

List<MidiEvent> _sortedEvents(List<MidiEvent> events) {
  final sorted = List<MidiEvent>.from(events);
  sorted.sort((a, b) {
    final tickComparison = a.tick.compareTo(b.tick);
    if (tickComparison != 0) return tickComparison;
    return _eventPriority(a.type).compareTo(_eventPriority(b.type));
  });
  return sorted;
}

int _eventPriority(MidiEventType type) {
  return switch (type) {
    MidiEventType.tempo => 0,
    MidiEventType.timeSignature => 1,
    MidiEventType.marker => 2,
    MidiEventType.programChange => 3,
    MidiEventType.controlChange => 4,
    MidiEventType.noteOff => 5,
    MidiEventType.noteOn => 6,
  };
}
