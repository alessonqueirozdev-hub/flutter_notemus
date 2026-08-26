import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// What happens when the music is longer than the page.
///
/// Three things that only appear at length, and all three of which were
/// broken at some point in this package's history in ways a four-bar example
/// could never have shown: system wrapping, horizontal scroll, and pagination
/// on export.
class LongScoreExportExample extends StatelessWidget {
  const LongScoreExportExample({super.key});

  static const _accent = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Long Scores, Wrapping and Export',
      subtitle:
          'Multi-system wrapping, the clef and key restated at every system '
          'start, and what the PDF and PNG exporters do with music that does '
          'not fit on one page.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'The opening block is a convention, not a coincidence',
          description:
              'ADR-004: every system opens with the clef, key signature and — '
              'on the first system only — the meter in force at that point. '
              'Restating them is not decoration; without it a reader landing '
              'mid-page has no way to know what key they are in. The bug this '
              'guards against was specific and nasty: a clef change written '
              'INSIDE a voice was invisible to the restatement logic, so '
              'systems 3 through 9 opened with a treble clef while the bass '
              'clef was actually in force, and every pitch on them read wrong.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Twenty-four bars, wrapped',
          description:
              'The engine breaks the line when the next bar will not fit, and '
              'opens the new system with the clef and key in force. Count the '
              'clefs: one per system, and every one of them is the right clef.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _longPhrase(24),
            accentColor: _accent,
            minHeight: 420,
            staffSpace: 11,
          ),
        ),
        ExampleSectionCard(
          title: 'A mid-phrase clef change, restated correctly',
          description:
              'The clef changes to bass in bar 5 and back to treble in bar 17. '
              'Every system after each change opens with the clef that is '
              'genuinely in force — including the systems that contain no clef '
              'change of their own.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _clefChanges(),
            accentColor: _accent,
            minHeight: 420,
            staffSpace: 11,
          ),
        ),
        ExampleSectionCard(
          title: 'How it measures up',
          description:
              'Run against the score above: how many systems, where the breaks '
              'fall, and which clef each system opens with.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _systemReport()),
        ),
        const ExampleSectionCard(
          title: 'Exporting a long score',
          description:
              'PdfExporter paginates by SYSTEM. A 40-bar two-staff piano score '
              'wraps into 14 systems and comes out as 3 pages of 5 / 5 / 4 — '
              'that is 14 of 14. Before 2.7.0 the grand-staff path put every '
              'system into one image on one page and 60.2% of the music was '
              'simply cut off, with nothing in warnings to say so.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: "import 'package:flutter_notemus/flutter_notemus.dart';\n"
                '\n'
                'final exporter = PdfExporter(metadata: metadata);\n'
                'final bytes = await exporter.exportGroup(\n'
                '  group,\n'
                '  staffSpace: 12,\n'
                '  pageWidth: 1200,\n'
                ');\n'
                '\n'
                '// Always read this: an empty list is part of the contract.\n'
                'if (exporter.warnings.isNotEmpty) {\n'
                '  debugPrint(exporter.warnings.join(String.fromCharCode(10)));\n'
                '}',
          ),
        ),
        const ExampleSectionCard(
          title: 'A single bar can still be wider than the viewport',
          description:
              'Not a defect — a stated limit. The engine compresses an '
              'over-full bar down to LayoutEngine.minimumSpacingScale (0.35) '
              'and no further, because past that the noteheads collide. '
              'Measured on 40 whole notes in one 4/4 bar at 900 px: 43 elements '
              'on one system reaching x = 2 073 px, 2.30x the line. No music is '
              'lost — MusicScore and GrandStaff both scroll horizontally — and '
              'the engine now names the bar and the factor in warnings instead '
              'of overflowing silently. See the Diagnostics page.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: 'final engine = LayoutEngine(staff,\n'
                '    availableWidth: 900, staffSpace: 12);\n'
                'final elements = engine.layout();\n'
                '\n'
                'engine.overflowsAvailableWidth(elements)  // true\n'
                'engine.warnings                           // names the bar',
          ),
        ),
      ],
    );
  }

  static Note _n(String step, int octave,
          {DurationType d = DurationType.eighth}) =>
      Note(
        pitch: Pitch(step: step, octave: octave),
        duration: MusicDuration(d),
      );

  static const _scale = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  static Measure _bar(int index, {Clef? clef, int octave = 5}) {
    final measure = Measure();
    if (clef != null) measure.elements.add(clef);
    if (index == 0) {
      measure.elements.add(TimeSignature(numerator: 4, denominator: 4));
    }
    for (var i = 0; i < 8; i++) {
      measure.elements.add(_n(_scale[(index + i) % 7], octave));
    }
    return measure;
  }

  static Staff _longPhrase(int bars) {
    final staff = Staff();
    for (var i = 0; i < bars; i++) {
      staff.measures.add(_bar(
        i,
        clef: i == 0 ? Clef(clefType: ClefType.treble) : null,
      ));
    }
    return staff;
  }

  static Staff _clefChanges() {
    final staff = Staff();
    for (var i = 0; i < 24; i++) {
      Clef? clef;
      var octave = 5;
      if (i == 0) {
        clef = Clef(clefType: ClefType.treble);
      } else if (i == 4) {
        clef = Clef(clefType: ClefType.bass);
      } else if (i == 16) {
        clef = Clef(clefType: ClefType.treble);
      }
      if (i >= 4 && i < 16) octave = 3;
      staff.measures.add(_bar(i, clef: clef, octave: octave));
    }
    return staff;
  }

  /// Lays the clef-change score out and reports, per system, where it starts
  /// and which clef it opens with.
  static String _systemReport() {
    final engine = LayoutEngine(_clefChanges(),
        availableWidth: 900, staffSpace: 11, metadata: SmuflMetadata());
    final elements = engine.layout();

    final systems = <int, List<PositionedElement>>{};
    for (final element in elements) {
      systems.putIfAbsent(element.system, () => []).add(element);
    }

    final lines = <String>[
      'systems   ${systems.length}',
      'elements  ${elements.length}',
      '',
      'system   opens with        first bar',
      '──────────────────────────────────────',
    ];
    final ordered = systems.keys.toList()..sort();
    for (final index in ordered) {
      final onSystem = systems[index]!;
      final clef = onSystem
          .map((e) => e.element)
          .whereType<Clef>()
          .firstOrNull;
      final firstBar = onSystem
          .map((e) => e.measureIndex)
          .where((m) => m >= 0)
          .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
      lines.add('${index.toString().padLeft(4)}     '
          '${(clef?.clefType.name ?? '(none)').padRight(17)}'
          '${firstBar == null ? '?' : firstBar + 1}');
    }
    return lines.join('\n');
  }
}
