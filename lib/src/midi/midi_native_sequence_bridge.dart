import 'dart:collection';

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

    final tempo = _extractInitialTempo(sequence) ?? fallbackTempoBpm;
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

    for (final note in notes) {
      await backend.scheduleNote(
        midiNote: note.midiNote,
        startTick: note.startTick,
        durationTicks: note.durationTicks,
        velocity: note.velocity,
        channel: note.channel,
        isTied: note.isTied,
      );
    }

    await backend.processTies();

    if (includeMetronome) {
      await backend.scheduleMetronome(
        totalTicks: sequence.totalTicks,
        countInBeats: countInBeats,
      );
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
