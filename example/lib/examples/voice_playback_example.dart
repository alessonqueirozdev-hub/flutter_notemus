// example/lib/examples/voice_playback_example.dart
//
// Per-voice MIDI generation: `MidiGenerationOptions.separateTracksPerVoice`,
// `mutedVoices` and `soloVoices`.
//
// With `separateTracksPerVoice` every (staff, voice) pair becomes its own
// `MidiTrack` on its own channel, named `'<staff> - Voice N'`, so a DAW — or
// this page — can solo and mute an individual line. Muting never changes the
// timing of the other voices: a silenced voice still consumes its musical
// time, only its note events are dropped.

import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Catalog entry: voice-aware MIDI tracks with mute and solo.
class VoicePlaybackExample extends StatelessWidget {
  const VoicePlaybackExample({super.key});

  static const _accent = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return const ExampleShowcasePage(
      title: 'Per-Voice Playback',
      subtitle:
          'One three-voice bar, rendered to MIDI with separate tracks per '
          'voice, plus mute and solo — and the generated events listed track '
          'by track.',
      accentColor: _accent,
      children: [
        ShowcaseInfoBanner(
          title: 'Solo beats mute',
          description:
              'MidiGenerationOptions.isVoiceAudible() resolves the two sets: a '
              'non-empty soloVoices wins over mutedVoices, and an empty solo '
              'set means "no solo active". The same precedence applies to '
              'mutedStaves / soloStaves on a full Score.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Three voices, one staff',
          description:
              'Voice 1 moves in quarter notes, voice 2 in half notes and '
              'voice 3 holds a whole note. Toggle the options below and watch '
              'the generated tracks change.',
          accentColor: _accent,
          child: _VoicePlaybackPanel(),
        ),
      ],
    );
  }
}

class _VoicePlaybackPanel extends StatefulWidget {
  const _VoicePlaybackPanel();

  @override
  State<_VoicePlaybackPanel> createState() => _VoicePlaybackPanelState();
}

class _VoicePlaybackPanelState extends State<_VoicePlaybackPanel> {
  static const Color _accent = VoicePlaybackExample._accent;
  static const List<int> _voices = <int>[1, 2, 3];

  late final Staff _staff = _buildStaff();

  bool _separateTracks = true;
  final Set<int> _muted = <int>{};
  final Set<int> _solo = <int>{};

  MidiGenerationOptions get _options => MidiGenerationOptions(
        defaultBpm: 96,
        separateTracksPerVoice: _separateTracks,
        mutedVoices: Set<int>.unmodifiable(_muted),
        soloVoices: _solo.isEmpty ? null : Set<int>.unmodifiable(_solo),
      );

  // --- Model ----------------------------------------------------------------

  static Note _note(String step, int octave, DurationType type, int voice) {
    return Note(
      pitch: Pitch(step: step, octave: octave),
      duration: Duration(type),
      voice: voice,
    );
  }

  /// Two bars, three voices each.
  ///
  /// The clef and the meter are written twice on purpose: `MultiVoiceMeasure`
  /// renders only what its voices carry, while `Measure.timeSignature` (used by
  /// the MIDI timeline) reads the measure's own element list. Keeping both in
  /// sync is what makes the bar render *and* play back correctly.
  static Staff _buildStaff() {
    final staff = Staff();

    for (var bar = 0; bar < 2; bar++) {
      final measure = MultiVoiceMeasure();
      if (bar == 0) {
        measure.add(Clef(clefType: ClefType.treble));
        measure.add(TimeSignature(numerator: 4, denominator: 4));
      }

      final voice1 = Voice.voice1(name: 'Melody');
      if (bar == 0) {
        voice1.add(Clef(clefType: ClefType.treble));
        voice1.add(TimeSignature(numerator: 4, denominator: 4));
      }
      final melody = bar == 0
          ? const <String>['E', 'F', 'G', 'A']
          : const <String>['G', 'F', 'E', 'D'];
      for (final step in melody) {
        voice1.add(_note(step, 5, DurationType.quarter, 1));
      }

      final voice2 = Voice.voice2(name: 'Counter-melody');
      final counter = bar == 0
          ? const <String>['C', 'B']
          : const <String>['B', 'A'];
      for (var i = 0; i < counter.length; i++) {
        voice2.add(_note(counter[i], counter[i] == 'C' ? 5 : 4,
            DurationType.half, 2));
      }

      final voice3 = Voice(
        number: 3,
        name: 'Pedal',
        forcedStemDirection: StemDirection.down,
      );
      voice3.add(_note(bar == 0 ? 'C' : 'G', 4, DurationType.whole, 3));

      measure.addVoice(voice1);
      measure.addVoice(voice2);
      measure.addVoice(voice3);
      staff.add(measure);
    }

    return staff;
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final sequence = MidiMapper.fromStaff(
      _staff,
      options: options,
      trackName: 'Piano',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScoreFrame(staff: _staff),
        const SizedBox(height: 18),
        _buildOptionsCard(context, options),
        const SizedBox(height: 18),
        _buildSequenceCard(context, sequence),
      ],
    );
  }

  Widget _buildOptionsCard(BuildContext context, MidiGenerationOptions o) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'separateTracksPerVoice',
                  style: textTheme.textStyle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              CupertinoSwitch(
                value: _separateTracks,
                activeTrackColor: _accent,
                onChanged: (value) =>
                    setState(() => _separateTracks = value),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _separateTracks
                ? 'Each voice gets its own track and channel.'
                : 'All voices share one track on one channel (the historical '
                    'behaviour).',
            style: textTheme.textStyle.copyWith(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const _GroupLabel('mutedVoices'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final voice in _voices)
                _Toggle(
                  label: 'Mute voice $voice',
                  selected: _muted.contains(voice),
                  accent: const Color(0xFFB91C1C),
                  onPressed: () => setState(() {
                    if (!_muted.remove(voice)) _muted.add(voice);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _GroupLabel('soloVoices'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final voice in _voices)
                _Toggle(
                  label: 'Solo voice $voice',
                  selected: _solo.contains(voice),
                  accent: _accent,
                  onPressed: () => setState(() {
                    if (!_solo.remove(voice)) _solo.add(voice);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _GroupLabel('Resolved audibility'),
          const SizedBox(height: 4),
          for (final voice in _voices)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'isVoiceAudible($voice) = ${o.isVoiceAudible(voice)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: o.isVoiceAudible(voice)
                      ? const Color(0xFF15803D)
                      : const Color(0xFFB91C1C),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSequenceCard(BuildContext context, MidiSequence sequence) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7DDE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sequence.tracks.length} track(s) · '
            '${sequence.ticksPerQuarter} ticks per quarter · '
            '${sequence.totalTicks} ticks total',
            style: textTheme.textStyle.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (sequence.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final warning in sequence.warnings)
              Text(
                '⚠ $warning',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB45309),
                ),
              ),
          ],
          const SizedBox(height: 12),
          for (final track in sequence.tracks) _buildTrack(track),
        ],
      ),
    );
  }

  Widget _buildTrack(MidiTrack track) {
    final noteOns = track.events
        .where((event) => event.type == MidiEventType.noteOn)
        .toList();
    final shown = noteOns.take(10).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  track.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                'ch ${track.channel} · ${noteOns.length} note(s)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          if (noteOns.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Silent — the voice is muted or another voice is soloed.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            for (final event in shown)
              Text(
                'tick ${event.tick.toString().padLeft(5)}  ·  '
                '${_noteName(event.note)}  ·  vel ${event.velocity}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            if (noteOns.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '… ${noteOns.length - shown.length} more',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _noteName(int? midiNumber) {
    if (midiNumber == null) return '—';
    return '${PitchUtils.fromMidiNumber(midiNumber)} ($midiNumber)';
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onPressed;

  const _Toggle({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      color: selected
          ? accent.withValues(alpha: 0.85)
          : accent.withValues(alpha: 0.10),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: selected ? const Color(0xFFFFFFFF) : accent,
        ),
      ),
    );
  }
}

class _ScoreFrame extends StatelessWidget {
  final Staff staff;

  const _ScoreFrame({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7DDE5)),
        color: const Color(0xFFFFFFFF),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: SizedBox(
        width: double.infinity,
        height: 190,
        child: MusicScore(
          staff: staff,
          staffSpace: 14,
          theme: const MusicScoreTheme(
            staffLineColor: Color(0xFF1F2937),
            noteheadColor: Color(0xFF111827),
            stemColor: Color(0xFF111827),
            clefColor: Color(0xFF111827),
            barlineColor: Color(0xFF111827),
            showMeasureNumbers: true,
          ),
        ),
      ),
    );
  }
}
