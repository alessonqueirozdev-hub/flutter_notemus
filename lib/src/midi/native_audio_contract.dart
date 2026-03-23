/// Contract for a low-latency native MIDI backend.
///
/// This package already generates complete MIDI mapping in Dart. The native
/// backend is optional and can be used to provide sample-accurate scheduling,
/// SoundFont synthesis, and metronome playback with lower latency.
abstract class MidiNativeAudioBackend {
  /// Initializes native audio resources.
  ///
  /// Implementations may use platform-specific engines (e.g. Oboe/AAudio on
  /// Android, CoreAudio on Apple platforms, WASAPI on Windows).
  Future<bool> initialize({
    required String primarySoundFontPath,
    String? metronomeSoundFontPath,
    int sampleRate = 48000,
  });

  /// Starts native playback.
  Future<void> start();

  /// Stops playback and keeps resources allocated.
  Future<void> stop();

  /// Releases all native resources.
  Future<void> dispose();

  /// Schedules a note event in PPQ ticks.
  Future<void> scheduleNote({
    required int midiNote,
    required int startTick,
    required int durationTicks,
    required int velocity,
    int channel = 0,
    bool isTied = false,
  });

  /// Schedules metronome events for the current sequence.
  Future<void> scheduleMetronome({
    required int totalTicks,
    int countInBeats = 0,
  });

  /// Sets current sequencer tempo.
  Future<void> setTempo(int bpm);

  /// Sets ticks-per-quarter resolution used by scheduled PPQ events.
  Future<void> setTicksPerQuarter(int ticksPerQuarter);

  /// Sets current sequencer time signature.
  Future<void> setTimeSignature({
    required int numerator,
    required int denominator,
  });

  /// Clears currently scheduled sequence events on native side.
  Future<void> clearScheduledEvents();

  /// Triggers tie processing in the native sequencer.
  ///
  /// Backends that do not support tie processing can implement as no-op.
  Future<void> processTies();

  /// Indicates whether native backend is initialized and ready.
  Future<bool> isReady();
}
