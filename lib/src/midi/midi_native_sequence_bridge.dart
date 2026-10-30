import 'dart:collection';

import '../playback/playback_plan.dart';
import 'midi_models.dart';
import 'native_audio_contract.dart';

class ScheduledMidiNote {
  final int midiNote;
  final int startTick;
  final int durationTicks;
  final int velocity;
  final int channel;
  final bool isTied;

  const ScheduledMidiNote({
    required this.midiNote,
    required this.startTick,
    required this.durationTicks,
    required this.velocity,
    required this.channel,
    this.isTied = false,
  });
}

class MidiNativeSequenceBridge {
  final MidiNativeAudioBackend backend;

  const MidiNativeSequenceBridge(this.backend);

  Future<void> uploadSequence(
    MidiSequence sequence, {
    bool includeMetronome = true,
    int countInBeats = 0,
    int fallbackTempoBpm = 120,
    int fallbackNumerator = 4,
    int fallbackDenominator = 4,
    bool includeMetronomeTrackNotes = false,
  }) async {
    await backend.clearScheduledEvents();
    await backend.setTicksPerQuarter(sequence.ticksPerQuarter);

    // The opening tempo is the LAST tempo event at the earliest tick, as a MIDI
    // player applies them — PlaybackPlan's reading. Taking the first one sent
    // the mapper's default 120 even when the score's own mark at tick 0 says
    // otherwise.
    final plan = PlaybackPlan.fromSequence(sequence);
    final tempo = _extractInitialTempo(sequence) == null
        ? fallbackTempoBpm
        : plan.tempoChanges.first.bpm;
    await backend.setTempo(tempo);

    final timeSignature = _extractInitialTimeSignature(sequence);
    await backend.setTimeSignature(
      numerator: timeSignature?.numerator ?? fallbackNumerator,
      denominator: timeSignature?.denominator ?? fallbackDenominator,
    );

    final notes = extractScheduledNotes(
      sequence,
      includeMetronomeTrack: includeMetronomeTrackNotes,
    );

    // The backend contract takes ONE tempo and converts every scheduled tick
    // with it, so a tempo change after tick 0 was silently ignored: a score
    // that slows to half speed half-way through played at its opening tempo
    // throughout, and drifted from `PlaybackPlan.positionAt`. Each tick is
    // re-expressed instead as the tick, at the opening tempo, of the moment
    // it really sounds — the same time `PlaybackPlan.timeAtTick` gives.
    final warp = _tempoWarp(plan, sequence.ticksPerQuarter, tempo);

    for (final note in notes) {
      final start = warp(note.startTick);
      final end = warp(note.startTick + note.durationTicks);
      await backend.scheduleNote(
        midiNote: note.midiNote,
        startTick: start,
        durationTicks: end > start ? end - start : 1,
        velocity: note.velocity,
        channel: note.channel,
        isTied: note.isTied,
      );
    }

    await backend.processTies();

    if (includeMetronome) {
      if (plan.tempoChanges.length < 2) {
        await backend.scheduleMetronome(
          totalTicks: sequence.totalTicks,
          countInBeats: countInBeats,
        );
      } else {
        // The backend lays its clicks on a grid at the ONE tempo it was given,
        // so after a tempo change they drifted off the (warped) notes: at
        // 60 -> 120 bpm the notes moved to half-second beats while the clicks
        // stayed a second apart. Schedule the clicks as notes instead, one per
        // beat of every played bar, warped like everything else. The count-in
        // comes before tick 0, at the opening tempo, so the backend still
        // provides it.
        if (countInBeats > 0) {
          await backend.scheduleMetronome(
            totalTicks: 0,
            countInBeats: countInBeats,
          );
        }
        // A sequence that already carries its metronome track, uploaded with
        // includeMetronomeTrackNotes, has its clicks among the notes above.
        final clicksUploaded = includeMetronomeTrackNotes &&
            sequence.tracks.any((t) => t.name.toLowerCase() == 'metronome');
        for (final click in clicksUploaded
            ? const <({int tick, bool accent})>[]
            : _metronomeClicks(sequence)) {
          final start = warp(click.tick);
          final end = warp(click.tick + _clickOptions.metronomeClickDurationTicks);
          await backend.scheduleNote(
            midiNote: click.accent
                ? _clickOptions.metronomeAccentNote
                : _clickOptions.metronomeRegularNote,
            startTick: start,
            durationTicks: end > start ? end - start : 1,
            velocity: click.accent
                ? _clickOptions.metronomeAccentVelocity
                : _clickOptions.metronomeRegularVelocity,
            channel: _clickOptions.metronomeChannel,
          );
        }
      }
    }
  }

  Future<void> uploadAndStart(
    MidiSequence sequence, {
    bool includeMetronome = true,
    int countInBeats = 0,
  }) async {
    await uploadSequence(
      sequence,
      includeMetronome: includeMetronome,
      countInBeats: countInBeats,
    );
    await backend.start();
  }
}

/// The click sounds the mapper's metronome uses by default.
const _clickOptions = MidiGenerationOptions();

/// One click per beat of every played bar of [sequence] — the beats the
/// mapper's own metronome track uses (`numerator` clicks across the bar,
/// accent on the downbeat), in source ticks.
List<({int tick, bool accent})> _metronomeClicks(MidiSequence sequence) => [
      for (final bar in sequence.playedMeasures)
        for (var beat = 0; beat < _beatsOf(bar); beat++)
          (
            tick: bar.startTick +
                (beat * bar.durationTicks / _beatsOf(bar)).round(),
            accent: beat == 0,
          ),
    ];

int _beatsOf(MidiPlayedMeasure bar) {
  final n = bar.numerator ?? 4;
  return n <= 0 ? 1 : n;
}

/// Maps a tick of [plan]'s sequence to the tick at [openingBpm] at which it
/// actually sounds, through every tempo change. The identity when the
/// sequence never changes tempo.
int Function(int) _tempoWarp(
    PlaybackPlan plan, int ticksPerQuarter, int openingBpm) {
  if (plan.tempoChanges.length < 2) return (tick) => tick;
  final ticksPerMicro = openingBpm * ticksPerQuarter / 60000000;
  return (tick) => (plan.timeAtTick(tick).inMicroseconds * ticksPerMicro).round();
}

List<ScheduledMidiNote> extractScheduledNotes(
  MidiSequence sequence, {
  bool includeMetronomeTrack = false,
}) {
  final output = <ScheduledMidiNote>[];

  for (final track in sequence.tracks) {
    final lowerName = track.name.toLowerCase();
    if (lowerName == 'conductor') {
      continue;
    }
    if (!includeMetronomeTrack && lowerName == 'metronome') {
      continue;
    }

    final events = List<MidiEvent>.from(track.events)
      ..sort((a, b) {
        final tickCmp = a.tick.compareTo(b.tick);
        if (tickCmp != 0) return tickCmp;
        return _eventPriority(a.type).compareTo(_eventPriority(b.type));
      });

    final active = <_ActiveKey, Queue<_ActiveNote>>{};

    for (final event in events) {
      if (event.type == MidiEventType.noteOn && (event.velocity ?? 0) > 0) {
        final key = _ActiveKey(event.channel, event.note ?? 0);
        final queue = active.putIfAbsent(key, Queue<_ActiveNote>.new);
        queue.add(
          _ActiveNote(startTick: event.tick, velocity: event.velocity ?? 0),
        );
        continue;
      }

      final isNoteOff =
          event.type == MidiEventType.noteOff ||
          (event.type == MidiEventType.noteOn && (event.velocity ?? 0) == 0);
      if (!isNoteOff) {
        continue;
      }

      final key = _ActiveKey(event.channel, event.note ?? 0);
      final queue = active[key];
      if (queue == null || queue.isEmpty) {
        continue;
      }

      final started = queue.removeFirst();
      final duration = event.tick - started.startTick;
      if (duration <= 0) {
        continue;
      }

      output.add(
        ScheduledMidiNote(
          midiNote: key.note.clamp(0, 127),
          startTick: started.startTick,
          durationTicks: duration,
          velocity: started.velocity.clamp(1, 127),
          channel: key.channel.clamp(0, 15),
        ),
      );

      if (queue.isEmpty) {
        active.remove(key);
      }
    }
  }

  output.sort((a, b) {
    final tickCmp = a.startTick.compareTo(b.startTick);
    if (tickCmp != 0) return tickCmp;
    return a.midiNote.compareTo(b.midiNote);
  });
  return output;
}

int? _extractInitialTempo(MidiSequence sequence) {
  int? tick;
  int? bpm;

  for (final track in sequence.tracks) {
    for (final event in track.events) {
      if (event.type != MidiEventType.tempo || event.bpm == null) continue;
      if (tick == null || event.tick < tick) {
        tick = event.tick;
        bpm = event.bpm;
      }
    }
  }

  return bpm;
}

_InitialTimeSignature? _extractInitialTimeSignature(MidiSequence sequence) {
  int? tick;
  _InitialTimeSignature? signature;

  for (final track in sequence.tracks) {
    for (final event in track.events) {
      if (event.type != MidiEventType.timeSignature) continue;
      if (event.numerator == null || event.denominator == null) continue;
      if (tick == null || event.tick < tick) {
        tick = event.tick;
        signature = _InitialTimeSignature(
          numerator: event.numerator!,
          denominator: event.denominator!,
        );
      }
    }
  }

  return signature;
}

class _InitialTimeSignature {
  final int numerator;
  final int denominator;

  const _InitialTimeSignature({
    required this.numerator,
    required this.denominator,
  });
}

class _ActiveNote {
  final int startTick;
  final int velocity;

  const _ActiveNote({required this.startTick, required this.velocity});
}

class _ActiveKey {
  final int channel;
  final int note;

  const _ActiveKey(this.channel, this.note);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ActiveKey &&
        other.channel == channel &&
        other.note == note;
  }

  @override
  int get hashCode => Object.hash(channel, note);
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
