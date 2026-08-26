import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// What the engine says when it cannot do what you asked.
///
/// Most of this package's history is a story about silent failure: bars that
/// overflowed without a word, imports that dropped notes and returned an empty
/// staff, exports that lost 60% of the music onto a page nobody counted. The
/// fixes are elsewhere in this gallery. This page is about the OTHER half —
/// the engine having something to say, and saying it.
class DiagnosticsExample extends StatelessWidget {
  const DiagnosticsExample({super.key});

  static const _accent = Color(0xFFC2410C);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Diagnostics and Warnings',
      subtitle:
          'Every reporting channel in the package, each one triggered live on '
          'this page by input that actually provokes it.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'Why a warning list beats an exception',
          description:
              'A notation file is usually partly readable. Throwing on the '
              'first defect loses the other 95%; ignoring it hands back a score '
              'that looks complete and is not. So the rule here is: a defect '
              'that makes the surrounding music unreadable REJECTS with a '
              'FormatException, and one that loses a detail WARNS and carries '
              'on. What you must never get is silence, and getting there is '
              'still in progress — see the last card.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'A bar that cannot fit is named, not silently overflowed',
          description:
              'Forty semibreves written into one 4/4 bar at 900 px. The engine '
              'compresses to its 0.35 floor and no further, because past that '
              'the noteheads collide — so the bar genuinely does not fit. It '
              'used to just run off the line. It now names the measure, its '
              'index, the width it reached and the factor, in '
              'LayoutEngine.warnings.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _overflowWarning()),
        ),
        ExampleSectionCard(
          title: 'A malformed import reports what it could not read',
          description:
              'Four documents, four different defects. Two are warned about and '
              'two are rejected outright — and the split is not arbitrary: a '
              'zero <divisions> makes every duration in the part meaningless '
              'but the pitches survive, while a <pitch> with no <octave> has no '
              'defensible reading at all.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _parserOutcomes()),
        ),
        ExampleSectionCard(
          title: 'MIDI generation reports what it could not sound',
          description:
              'MidiSequence carries its own warnings list, because the things '
              'that defeat playback are not the things that defeat engraving. A '
              'repeat structure with no resolvable ending, an unmapped '
              'instrument, a tempo the format cannot express — all of them draw '
              'perfectly and none of them sound right.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _midiWarnings()),
        ),
        ExampleSectionCard(
          title: 'A measure refuses more than it can hold',
          description:
              'Measure.add validates against the meter in force and throws '
              'MeasureCapacityException rather than accepting a bar that cannot '
              'be engraved. Worth knowing: this used to depend on whether the '
              'score had been laid out — layout() wrote the derived meter back '
              'into the model, so the same call accepted a note before layout '
              'and threw after it. That is ADR-005, and the derived meter is a '
              'value now.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _capacityOutcome()),
        ),
        const ExampleSectionCard(
          title: 'Where this is still not honest enough',
          description:
              'Four kinds of malformed MusicXML remain SILENT: an unknown '
              '<clef><sign>, an unknown <type>, a non-numeric <alter> and a '
              'missing <part-list>. Each one changes what the score means '
              'without saying so — an unknown clef sign silently keeps the '
              'previous clef, so every pitch after it is engraved on the wrong '
              'line. It is issue #29, kept open with the measurements in it, '
              'rather than rounded up to "the parser reports problems".',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: 'document                     outcome\n'
                '─────────────────────────────────────────\n'
                '<divisions>0</divisions>      warned\n'
                'non-positive <duration>       warned\n'
                '<pitch> with no <octave>      rejected\n'
                'unknown <step>                rejected\n'
                'not a score at all            rejected\n'
                'unknown <clef><sign>          SILENT\n'
                'unknown <type>                SILENT\n'
                'non-numeric <alter>           SILENT\n'
                'missing <part-list>           SILENT',
          ),
        ),
      ],
    );
  }

  static String _overflowWarning() {
    final staff = Staff(measures: [
      Measure()
        ..elements.addAll([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          for (var i = 0; i < 40; i++)
            Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const MusicDuration(DurationType.whole),
            ),
        ])
    ]);
    final engine = LayoutEngine(staff,
        availableWidth: 900, staffSpace: 12, metadata: SmuflMetadata());
    final elements = engine.layout();
    final lines = <String>[
      'elements on one system   ${elements.length}',
      'overflows the width      ${engine.overflowsAvailableWidth(elements)}',
      '',
    ];
    lines.addAll(engine.warnings.map((w) => _wrap(w)));
    if (engine.warnings.isEmpty) lines.add('(no warnings)');
    return lines.join('\n');
  }

  static String _parserOutcomes() {
    final cases = <String, String>{
      '<divisions>0</divisions>': _xml('<attributes><divisions>0</divisions>'
          '</attributes>'
          '<note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>4</duration><type>quarter</type></note>'),
      'negative <duration>': _xml('<attributes><divisions>4</divisions>'
          '</attributes>'
          '<note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>-4</duration><type>quarter</type></note>'),
      '<pitch> with no <octave>': _xml('<attributes><divisions>4</divisions>'
          '</attributes>'
          '<note><pitch><step>C</step></pitch>'
          '<duration>4</duration><type>quarter</type></note>'),
      'unknown <step>': _xml('<attributes><divisions>4</divisions></attributes>'
          '<note><pitch><step>H</step><octave>4</octave></pitch>'
          '<duration>4</duration><type>quarter</type></note>'),
    };

    final lines = <String>[];
    cases.forEach((label, source) {
      final warnings = <String>[];
      String outcome;
      try {
        MusicXMLParser.parseMusicXML(source, warnings: warnings);
        outcome = warnings.isEmpty
            ? 'SILENT — imported with no complaint'
            : warnings.map((w) => 'warned: ${_wrap(w, indent: 10)}').join('\n');
      } on FormatException catch (e) {
        outcome = 'rejected: ${_wrap(e.message, indent: 10)}';
      }
      lines.add(label);
      lines.add('  $outcome');
      lines.add('');
    });
    return lines.join('\n').trimRight();
  }

  static String _midiWarnings() {
    final staff = Staff(measures: [
      Measure()
        ..elements.addAll([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          Barline(type: BarlineType.repeatBackward),
          Note(
            pitch: const Pitch(step: 'C', octave: 5),
            duration: const MusicDuration(DurationType.whole),
          ),
        ])
    ]);
    final sequence = MidiMapper.fromStaff(staff);
    if (sequence.warnings.isEmpty) {
      return 'tracks   ${sequence.tracks.length}\n'
          'warnings (none for this input — the mapper handled everything it '
          'was given)';
    }
    return 'tracks   ${sequence.tracks.length}\n\n'
        '${sequence.warnings.map((w) => '• ${_wrap(w)}').join('\n')}';
  }

  static String _capacityOutcome() {
    final measure = Measure()
      ..elements.addAll([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        for (var i = 0; i < 4; i++)
          Note(
            pitch: const Pitch(step: 'C', octave: 5),
            duration: const MusicDuration(DurationType.quarter),
          ),
      ]);
    try {
      measure.add(Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const MusicDuration(DurationType.quarter),
      ));
      return 'No exception. The fifth quarter was accepted into a full 4/4 bar '
          '— this is the old behaviour and should not happen.';
    } on MeasureCapacityException catch (e) {
      return 'MeasureCapacityException\n\n${_wrap(e.toString())}';
    }
  }

  static String _xml(String body) => '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>P</part-name></score-part></part-list>
  <part id="P1"><measure number="1">$body</measure></part>
</score-partwise>
''';

  /// Hard-wraps a diagnostic so a long sentence stays readable in a code block
  /// that scrolls horizontally.
  static String _wrap(String text, {int indent = 0, int width = 66}) {
    final pad = ' ' * indent;
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = StringBuffer();
    for (final word in words) {
      if (current.isEmpty) {
        current.write(word);
      } else if (current.length + 1 + word.length <= width) {
        current.write(' $word');
      } else {
        lines.add(current.toString());
        current = StringBuffer(word);
      }
    }
    if (current.isNotEmpty) lines.add(current.toString());
    if (lines.isEmpty) return text;
    return [lines.first, ...lines.skip(1).map((l) => '$pad$l')].join('\n');
  }
}
