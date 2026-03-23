import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelMidiNativeAudioBackend', () {
    const channel = MethodChannel('flutter_notemus/native_audio');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'nativeInitialize' ||
                call.method == 'nativeIsReady') {
              return true;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('invokes expected native methods and payloads', () async {
      final backend = MethodChannelMidiNativeAudioBackend(channel: channel);

      final initialized = await backend.initialize(
        primarySoundFontPath: 'sf/gm.sf2',
        metronomeSoundFontPath: 'sf/metronome.sf2',
        sampleRate: 48000,
      );
      expect(initialized, isTrue);

      await backend.setTicksPerQuarter(960);
      await backend.setTempo(132);
      await backend.setTimeSignature(numerator: 6, denominator: 8);
      await backend.clearScheduledEvents();
      await backend.scheduleNote(
        midiNote: 64,
        startTick: 960,
        durationTicks: 480,
        velocity: 100,
        channel: 1,
        isTied: true,
      );
      await backend.scheduleMetronome(totalTicks: 3840, countInBeats: 2);
      await backend.processTies();
      await backend.start();
      await backend.stop();

      final ready = await backend.isReady();
      expect(ready, isTrue);

      await backend.dispose();

      expect(calls.map((call) => call.method), [
        'nativeInitialize',
        'nativeSequencerSetTicksPerQuarter',
        'nativeSequencerSetTempo',
        'nativeSequencerSetTimeSignature',
        'nativeSequencerClear',
        'nativeSequencerAddNote',
        'nativeSequencerAddMetronome',
        'nativeSequencerProcessTies',
        'nativeSequencerStart',
        'nativeSequencerStop',
        'nativeIsReady',
        'nativeRelease',
      ]);

      final initArgs = calls.first.arguments as Map<Object?, Object?>;
      expect(initArgs['primarySoundFontPath'], 'sf/gm.sf2');
      expect(initArgs['metronomeSoundFontPath'], 'sf/metronome.sf2');
      expect(initArgs['sampleRate'], 48000);
    });
  });

  group('MidiNativeSequenceBridge', () {
    test('uploads sequence metadata, notes and metronome', () async {
      final staff = Staff(
        measures: [
          Measure()
            ..add(TimeSignature(numerator: 4, denominator: 4))
            ..add(TempoMark(beatUnit: DurationType.quarter, bpm: 120))
            ..add(
              Note(
                pitch: const Pitch(step: 'C', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            )
            ..add(
              Note(
                pitch: const Pitch(step: 'D', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            )
            ..add(
              Note(
                pitch: const Pitch(step: 'E', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            )
            ..add(
              Note(
                pitch: const Pitch(step: 'F', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            ),
        ],
      );

      final sequence = MidiMapper.fromStaff(staff);
      final backend = _FakeNativeBackend();
      final bridge = MidiNativeSequenceBridge(backend);

      await bridge.uploadSequence(
        sequence,
        includeMetronome: true,
        countInBeats: 1,
      );

      expect(backend.cleared, isTrue);
      expect(backend.ticksPerQuarter, 960);
      expect(backend.tempo, 120);
      expect(backend.timeSignatureNumerator, 4);
      expect(backend.timeSignatureDenominator, 4);
      expect(backend.scheduledNotes.length, 4);
      expect(backend.processTiesCalled, isTrue);
      expect(backend.metronomeTotalTicks, sequence.totalTicks);
      expect(backend.metronomeCountIn, 1);
    });

    test(
      'extractScheduledNotes ignores conductor/metronome tracks by default',
      () {
        final sequence = MidiSequence(
          ticksPerQuarter: 960,
          tracks: [
            MidiTrack(
              name: 'Conductor',
              channel: 0,
              events: const [MidiEvent.tempo(tick: 0, bpm: 120)],
            ),
            MidiTrack(
              name: 'Staff 1',
              channel: 0,
              events: const [
                MidiEvent.noteOn(tick: 0, channel: 0, note: 60, velocity: 90),
                MidiEvent.noteOff(tick: 960, channel: 0, note: 60),
              ],
            ),
            MidiTrack(
              name: 'Metronome',
              channel: 9,
              events: const [
                MidiEvent.noteOn(tick: 0, channel: 9, note: 76, velocity: 120),
                MidiEvent.noteOff(tick: 100, channel: 9, note: 76),
              ],
            ),
          ],
        );

        final notes = extractScheduledNotes(sequence);

        expect(notes.length, 1);
        expect(notes.first.midiNote, 60);
        expect(notes.first.durationTicks, 960);
      },
    );
  });
}

class _FakeNativeBackend implements MidiNativeAudioBackend {
  bool initialized = false;
  bool playing = false;
  bool disposed = false;
  bool cleared = false;
  bool processTiesCalled = false;
  int? ticksPerQuarter;
  int? tempo;
  int? timeSignatureNumerator;
  int? timeSignatureDenominator;
  int? metronomeTotalTicks;
  int? metronomeCountIn;
  final List<ScheduledMidiNote> scheduledNotes = <ScheduledMidiNote>[];

  @override
  Future<void> clearScheduledEvents() async {
    cleared = true;
    scheduledNotes.clear();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<bool> initialize({
    required String primarySoundFontPath,
    String? metronomeSoundFontPath,
    int sampleRate = 48000,
  }) async {
    initialized = true;
    return true;
  }

  @override
  Future<bool> isReady() async {
    return initialized && !disposed;
  }

  @override
  Future<void> processTies() async {
    processTiesCalled = true;
  }

  @override
  Future<void> scheduleMetronome({
    required int totalTicks,
    int countInBeats = 0,
  }) async {
    metronomeTotalTicks = totalTicks;
    metronomeCountIn = countInBeats;
  }

  @override
  Future<void> scheduleNote({
    required int midiNote,
    required int startTick,
    required int durationTicks,
    required int velocity,
    int channel = 0,
    bool isTied = false,
  }) async {
    scheduledNotes.add(
      ScheduledMidiNote(
        midiNote: midiNote,
        startTick: startTick,
        durationTicks: durationTicks,
        velocity: velocity,
        channel: channel,
        isTied: isTied,
      ),
    );
  }

  @override
  Future<void> setTempo(int bpm) async {
    tempo = bpm;
  }

  @override
  Future<void> setTicksPerQuarter(int ticksPerQuarter) async {
    this.ticksPerQuarter = ticksPerQuarter;
  }

  @override
  Future<void> setTimeSignature({
    required int numerator,
    required int denominator,
  }) async {
    timeSignatureNumerator = numerator;
    timeSignatureDenominator = denominator;
  }

  @override
  Future<void> start() async {
    playing = true;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }
}
