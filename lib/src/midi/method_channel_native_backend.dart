import 'package:flutter/services.dart';

import 'native_audio_contract.dart';

/// Method names used by [MethodChannelMidiNativeAudioBackend].
///
/// Defaults are intentionally aligned with a JNI-style bridge commonly used
/// in Android native audio stacks.
class MidiNativeMethodNames {
  final String initialize;
  final String start;
  final String stop;
  final String dispose;
  final String scheduleNote;
  final String scheduleMetronome;
  final String setTempo;
  final String setTicksPerQuarter;
  final String setTimeSignature;
  final String clearScheduledEvents;
  final String processTies;
  final String isReady;

  const MidiNativeMethodNames({
    this.initialize = 'nativeInitialize',
    this.start = 'nativeSequencerStart',
    this.stop = 'nativeSequencerStop',
    this.dispose = 'nativeRelease',
    this.scheduleNote = 'nativeSequencerAddNote',
    this.scheduleMetronome = 'nativeSequencerAddMetronome',
    this.setTempo = 'nativeSequencerSetTempo',
    this.setTicksPerQuarter = 'nativeSequencerSetTicksPerQuarter',
    this.setTimeSignature = 'nativeSequencerSetTimeSignature',
    this.clearScheduledEvents = 'nativeSequencerClear',
    this.processTies = 'nativeSequencerProcessTies',
    this.isReady = 'nativeIsReady',
  });
}

/// Native backend implementation backed by [MethodChannel].
///
/// This class allows the package to interact with a platform-native low-latency
/// sequencer/synth engine while keeping Dart-side MIDI mapping independent.
class MethodChannelMidiNativeAudioBackend implements MidiNativeAudioBackend {
  final MethodChannel channel;
  final MidiNativeMethodNames methods;

  const MethodChannelMidiNativeAudioBackend({
    this.channel = const MethodChannel('flutter_notemus/native_audio'),
    this.methods = const MidiNativeMethodNames(),
  });

  @override
  Future<bool> initialize({
    required String primarySoundFontPath,
    String? metronomeSoundFontPath,
    int sampleRate = 48000,
  }) async {
    final result = await channel.invokeMethod<bool>(methods.initialize, {
      'primarySoundFontPath': primarySoundFontPath,
      'metronomeSoundFontPath': metronomeSoundFontPath,
      'sampleRate': sampleRate,
    });
    return result ?? false;
  }

  @override
  Future<void> start() {
    return channel.invokeMethod<void>(methods.start);
  }

  @override
  Future<void> stop() {
    return channel.invokeMethod<void>(methods.stop);
  }

  @override
  Future<void> dispose() {
    return channel.invokeMethod<void>(methods.dispose);
  }

  @override
  Future<void> scheduleNote({
    required int midiNote,
    required int startTick,
    required int durationTicks,
    required int velocity,
    int channel = 0,
    bool isTied = false,
  }) {
    return this.channel.invokeMethod<void>(methods.scheduleNote, {
      'midiNote': midiNote,
      'startTick': startTick,
      'durationTicks': durationTicks,
      'velocity': velocity,
      'channel': channel,
      'isTied': isTied,
      'noteIndex': -1,
    });
  }

  @override
  Future<void> scheduleMetronome({
    required int totalTicks,
    int countInBeats = 0,
  }) {
    return channel.invokeMethod<void>(methods.scheduleMetronome, {
      'durationTicks': totalTicks,
      'countIn': countInBeats,
    });
  }

  @override
  Future<void> setTempo(int bpm) {
    return channel.invokeMethod<void>(methods.setTempo, {'bpm': bpm});
  }

  @override
  Future<void> setTicksPerQuarter(int ticksPerQuarter) {
    return channel.invokeMethod<void>(methods.setTicksPerQuarter, {
      'ticksPerQuarter': ticksPerQuarter,
    });
  }

  @override
  Future<void> setTimeSignature({
    required int numerator,
    required int denominator,
  }) {
    return channel.invokeMethod<void>(methods.setTimeSignature, {
      'numerator': numerator,
      'denominator': denominator,
    });
  }

  @override
  Future<void> clearScheduledEvents() {
    return channel.invokeMethod<void>(methods.clearScheduledEvents);
  }

  @override
  Future<void> processTies() {
    return channel.invokeMethod<void>(methods.processTies);
  }

  @override
  Future<bool> isReady() async {
    final result = await channel.invokeMethod<bool>(methods.isReady);
    return result ?? false;
  }
}
