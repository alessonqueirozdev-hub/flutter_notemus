import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Every colour role the engraver honours, on one page, switchable live.
///
/// Theming is the most-asked-about part of this package that had no gallery
/// page, and it is also where its limits are clearest: `MusicScoreTheme` is a
/// SCORE-level object. There is no per-note colour — a request tracked as
/// issue #23 — so "highlight the note being played" is not expressible here
/// yet, and this page says so rather than implying otherwise.
class ThemingExample extends StatefulWidget {
  const ThemingExample({super.key});

  @override
  State<ThemingExample> createState() => _ThemingExampleState();
}

class _ThemingExampleState extends State<ThemingExample> {
  static const _accent = Color(0xFF0891B2);

  int _preset = 0;

  static const _presets = <_ThemePreset>[
    _ThemePreset(
      name: 'Default',
      note: 'Everything unset. Black ink on the host background.',
      theme: MusicScoreTheme(),
    ),
    _ThemePreset(
      name: 'Blueprint',
      note: 'One hue for structure, a warmer one for everything the performer '
          'reads as an instruction.',
      theme: MusicScoreTheme(
        staffLineColor: Color(0xFF94A3B8),
        barlineColor: Color(0xFF94A3B8),
        noteheadColor: Color(0xFF0F172A),
        stemColor: Color(0xFF0F172A),
        beamColor: Color(0xFF0F172A),
        clefColor: Color(0xFF0369A1),
        keySignatureColor: Color(0xFF0369A1),
        timeSignatureColor: Color(0xFF0369A1),
        accidentalColor: Color(0xFFB45309),
        articulationColor: Color(0xFFB45309),
        dynamicColor: Color(0xFFB91C1C),
        slurColor: Color(0xFF047857),
        tieColor: Color(0xFF047857),
        tupletColor: Color(0xFF7C3AED),
        restColor: Color(0xFF475569),
      ),
    ),
    _ThemePreset(
      name: 'Low contrast',
      note: 'Every role muted at once — useful for a background reference '
          'score behind an editing overlay.',
      theme: MusicScoreTheme(
        staffLineColor: Color(0xFFCBD5E1),
        barlineColor: Color(0xFFCBD5E1),
        noteheadColor: Color(0xFF64748B),
        stemColor: Color(0xFF64748B),
        beamColor: Color(0xFF64748B),
        clefColor: Color(0xFF94A3B8),
        keySignatureColor: Color(0xFF94A3B8),
        timeSignatureColor: Color(0xFF94A3B8),
        restColor: Color(0xFF94A3B8),
        accidentalColor: Color(0xFF94A3B8),
      ),
    ),
    _ThemePreset(
      name: 'Proof-reading',
      note: 'Structure stays quiet so the things that get mis-engraved — '
          'accidentals, dynamics, tuplet numbers — carry the only strong '
          'colours on the page.',
      theme: MusicScoreTheme(
        staffLineColor: Color(0xFFE2E8F0),
        barlineColor: Color(0xFFCBD5E1),
        noteheadColor: Color(0xFF1E293B),
        stemColor: Color(0xFF334155),
        beamColor: Color(0xFF334155),
        clefColor: Color(0xFF64748B),
        keySignatureColor: Color(0xFF64748B),
        timeSignatureColor: Color(0xFF64748B),
        restColor: Color(0xFF64748B),
        accidentalColor: Color(0xFFDC2626),
        dynamicColor: Color(0xFF16A34A),
        tupletColor: Color(0xFFEA580C),
        octaveColor: Color(0xFF9333EA),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final preset = _presets[_preset];

    return ExampleShowcasePage(
      title: 'Theming',
      subtitle:
          'MusicScoreTheme gives every engraving role its own colour. Switch '
          'presets and watch which parts of the page move.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'Roles, not widgets',
          description:
              'The theme is keyed by what a mark MEANS — notehead, stem, beam, '
              'accidental, dynamic, slur, tuplet, octave line — rather than by '
              'which renderer draws it. That is what lets you mute structure '
              'and keep instructions loud without touching the model. Roles '
              'left null inherit a sensible default rather than disappearing.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Pick a preset',
          description: preset.note,
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _preset,
                onValueChanged: (value) {
                  if (value != null) setState(() => _preset = value);
                },
                children: {
                  for (var i = 0; i < _presets.length; i++)
                    i: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Text(_presets[i].name,
                          style: const TextStyle(fontSize: 13)),
                    ),
                },
              ),
              const SizedBox(height: 16),
              ScorePreviewFrame(
                staff: _sampler(),
                accentColor: _accent,
                minHeight: 250,
                staffSpace: 16,
                theme: preset.theme,
              ),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'The same score, all four at once',
          description:
              'Side by side, because a colour scheme is judged against its '
              'alternatives rather than on its own.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in _presets) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, top: 4),
                  child: Text(
                    p.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                ScorePreviewFrame(
                  staff: _sampler(),
                  accentColor: _accent,
                  minHeight: 190,
                  staffSpace: 13,
                  theme: p.theme,
                ),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
        const ExampleSectionCard(
          title: 'Text faces are a separate hatch',
          description:
              'This package ships two fonts and both are music fonts — no text '
              'face at all. On a host that provides none of Academico, Century '
              'Schoolbook, Edwin or serif, every string renders as a .notdef '
              'box, and the generic serif family does NOT rescue it (measured: '
              'a headless binary with a face registered as serif produced a '
              'byte-identical PNG). MusicTextFont.use is the supported answer '
              'and reaches every string the package draws. Shipping a face is '
              'tracked as issue #28.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: "import 'package:flutter_notemus/flutter_notemus.dart';\n"
                '\n'
                '// Once, at startup — before anything is rendered.\n'
                "MusicTextFont.use('Academico');\n"
                '\n'
                '// Or per score, through the theme:\n'
                'MusicScoreTheme(textFontFamily: \'Academico\');',
          ),
        ),
        const ExampleSectionCard(
          title: 'What theming cannot do yet',
          description:
              'MusicScoreTheme is score-level. There is no per-note colour, so '
              'colouring one note to show a playhead is not expressible — that '
              'is issue #23, and the wider per-element styling layer is issue '
              '#16. Both are open, not wontfix. Painting a highlight in an '
              'overlay above the score, positioned with ScoreHitTester.boundsOf, '
              'is the workaround that exists today.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: 'final tester = ScoreHitTester(\n'
                '  elements: engine.layout(),\n'
                '  staffSpace: 12,\n'
                '  metadata: metadata,\n'
                ');\n'
                'final box = tester.boundsOf(note); // paint your highlight here',
          ),
        ),
      ],
    );
  }

  /// One bar carrying as many distinct theme roles as will fit legibly:
  /// clef, key, meter, notehead, stem, beam, accidental, rest, tuplet,
  /// dynamic, slur and tie.
  static Staff _sampler() {
    Note n(String step, int octave,
            {DurationType d = DurationType.eighth,
            double alter = 0.0,
            SlurType? slur,
            TieType? tie}) =>
        Note(
          pitch: Pitch(step: step, octave: octave, alter: alter),
          duration: MusicDuration(d),
          slur: slur,
          tie: tie,
        );

    final bar1 = Measure()
      ..elements.addAll([
        Clef(clefType: ClefType.treble),
        KeySignature(2),
        TimeSignature(numerator: 4, denominator: 4),
        Dynamic(type: DynamicType.mf),
        n('D', 5, slur: SlurType.start),
        n('E', 5, alter: 1.0),
        n('F', 5, alter: 1.0),
        n('G', 5, slur: SlurType.end),
        Rest(duration: const MusicDuration(DurationType.quarter)),
        n('A', 5, d: DurationType.quarter, tie: TieType.start),
      ]);

    final bar2 = Measure()
      ..elements.addAll([
        n('A', 5, d: DurationType.quarter, tie: TieType.end),
        Tuplet(actualNotes: 3, normalNotes: 2, elements: [
          n('B', 5),
          n('A', 5),
          n('G', 5),
        ]),
        n('F', 5, d: DurationType.quarter, alter: 1.0),
      ]);

    return Staff()..measures.addAll([bar1, bar2]);
  }
}

class _ThemePreset {
  final String name;
  final String note;
  final MusicScoreTheme theme;

  const _ThemePreset({
    required this.name,
    required this.note,
    required this.theme,
  });
}
