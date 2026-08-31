import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Type a score and watch it render.
///
/// Every other page in this gallery shows a fixed example. This one hands the
/// engine over: edit the JSON, MusicXML or MEI on the left and the staff below
/// re-parses and re-renders on every keystroke.
///
/// It is also the page that tells the truth when something goes wrong. A parser
/// that rejects a document raises a `FormatException`, one that only half-reads
/// it fills a `warnings` list, and both appear here instead of an empty panel —
/// which is exactly the failure mode that made a blank page impossible to
/// report usefully.
class LiveEditorExample extends StatefulWidget {
  const LiveEditorExample({super.key});

  @override
  State<LiveEditorExample> createState() => _LiveEditorExampleState();
}

enum _Format { json, musicXml, mei }

class _LiveEditorExampleState extends State<LiveEditorExample> {
  static const _accent = Color(0xFF7C3AED);

  _Format _format = _Format.json;
  late final Map<_Format, TextEditingController> _controllers = {
    _Format.json: TextEditingController(text: _seedJson),
    _Format.musicXml: TextEditingController(text: _seedMusicXml),
    _Format.mei: TextEditingController(text: _seedMei),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController get _controller => _controllers[_format]!;

  /// Parses the current source. Never throws: a rejection is a result too.
  _ParseOutcome _parse() {
    final source = _controller.text;
    final warnings = <String>[];
    try {
      final staff = switch (_format) {
        _Format.json => JsonMusicParser.parseStaff(source, warnings: warnings),
        _Format.musicXml =>
          MusicXMLParser.parseMusicXML(source, warnings: warnings),
        _Format.mei => MEIParser.parseMEI(source, warnings: warnings),
      };
      return _ParseOutcome(staff: staff, warnings: warnings);
    } on FormatException catch (e) {
      return _ParseOutcome(warnings: warnings, error: e.message);
    } catch (e) {
      // Anything else is a defect in the parser rather than in the document,
      // and saying so is more useful than showing nothing.
      return _ParseOutcome(
        warnings: warnings,
        error: '${e.runtimeType}: $e',
        isUnexpected: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _parse();

    return ExampleShowcasePage(
      title: 'Live Editor',
      subtitle:
          'Edit the source and the staff re-renders as you type. JSON, '
          'MusicXML and MEI, through the same parsers the rest of the package '
          'uses.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'The point is to break it',
          description:
              'Delete an <octave>, put a letter where a number goes, feed it an '
              'empty document. A parser that refuses raises a FormatException '
              'and one that half-reads fills a warnings list, and both show up '
              'below rather than as an empty panel. Four kinds of malformed '
              'MusicXML are still absorbed in SILENCE — an unknown clef sign, '
              'an unknown note type, a non-numeric alter and a missing '
              'part-list — and this is the fastest way to see that for '
              'yourself. It is issue #29.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Source',
          description:
              'Switching format keeps what you typed in the other two, so you '
              'can compare the same music expressed three ways.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoSlidingSegmentedControl<_Format>(
                groupValue: _format,
                onValueChanged: (value) {
                  if (value != null) setState(() => _format = value);
                },
                children: const {
                  _Format.json: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text('JSON', style: TextStyle(fontSize: 13)),
                  ),
                  _Format.musicXml: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text('MusicXML', style: TextStyle(fontSize: 13)),
                  ),
                  _Format.mei: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text('MEI', style: TextStyle(fontSize: 13)),
                  ),
                },
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                padding: const EdgeInsets.all(12),
                child: CupertinoTextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  maxLines: 16,
                  minLines: 8,
                  decoration: const BoxDecoration(),
                  padding: EdgeInsets.zero,
                  cursorColor: const Color(0xFF93C5FD),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New'],
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    onPressed: () => setState(() {
                      _controller.text = _seedFor(_format);
                    }),
                    child: const Text('Reset', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  if (outcome.staff != null)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      onPressed: () => setState(() {
                        // Round-trips through the writer for the two formats
                        // that have one. MEI is import-only (issue #31), so it
                        // is not offered there.
                        final staff = outcome.staff!;
                        _controller.text = _format == _Format.json
                            ? JsonMusicParser.staffToJson(staff)
                            : MusicXMLParser.staffToMusicXML(staff);
                      }),
                      child: Text(
                        _format == _Format.mei
                            ? 'No MEI writer (#31)'
                            : 'Round-trip through the writer',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'What the parser made of it',
          description: outcome.error != null
              ? 'The document was refused. Nothing is drawn, and the reason is '
                  'below.'
              : 'Re-parsed and re-rendered on the last keystroke.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (outcome.staff != null)
                ScorePreviewFrame(
                  staff: outcome.staff!,
                  accentColor: _accent,
                  minHeight: 240,
                  staffSpace: 15,
                ),
              if (outcome.error != null) _ErrorPanel(outcome: outcome),
              const SizedBox(height: 12),
              ShowcaseCodeBlock(text: _report(outcome)),
            ],
          ),
        ),
      ],
    );
  }

  String _report(_ParseOutcome outcome) {
    final lines = <String>[];
    if (outcome.staff != null) {
      final staff = outcome.staff!;
      final elements =
          staff.measures.fold<int>(0, (a, m) => a + m.elements.length);
      final notes = staff.measures
          .expand((m) => m.elements)
          .whereType<Note>()
          .length;
      lines.add('measures  ${staff.measures.length}');
      lines.add('elements  $elements');
      lines.add('notes     $notes');
      if (staff.name != null) lines.add('name      ${staff.name}');
      if (staff.transposition != null) {
        final t = staff.transposition!;
        lines.add('transpose diatonic ${t.diatonic}, '
            'chromatic ${t.chromatic}, octave ${t.octaveChange}');
      }
    }
    lines.add('');
    if (outcome.warnings.isEmpty) {
      lines.add('warnings  (none)');
    } else {
      lines.add('warnings  ${outcome.warnings.length}');
      for (final w in outcome.warnings) {
        lines.add('  • $w');
      }
    }
    return lines.join('\n');
  }

  static String _seedFor(_Format format) => switch (format) {
        _Format.json => _seedJson,
        _Format.musicXml => _seedMusicXml,
        _Format.mei => _seedMei,
      };
}

class _ParseOutcome {
  final Staff? staff;
  final List<String> warnings;
  final String? error;
  final bool isUnexpected;

  const _ParseOutcome({
    this.staff,
    this.warnings = const [],
    this.error,
    this.isUnexpected = false,
  });
}

class _ErrorPanel extends StatelessWidget {
  final _ParseOutcome outcome;

  const _ErrorPanel({required this.outcome});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outcome.isUnexpected
                ? 'The parser threw something other than a FormatException'
                : 'Refused',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF991B1B),
            ),
          ),
          if (outcome.isUnexpected)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'That is a defect in the parser rather than in your document — '
                'a malformed file should be refused by name, not by crash. '
                'Please report it with the text below.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
              ),
            ),
          const SizedBox(height: 10),
          SelectableText(
            outcome.error ?? '',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New'],
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF450A0A),
            ),
          ),
        ],
      ),
    );
  }
}

const String _seedJson = '''
{
  "measures": [
    {
      "elements": [
        {"type": "clef", "clefType": "treble"},
        {"type": "timesignature", "numerator": 4, "denominator": 4},
        {"type": "note", "pitch": {"step": "C", "octave": 5},
         "duration": {"type": "quarter"}},
        {"type": "note", "pitch": {"step": "D", "octave": 5},
         "duration": {"type": "quarter"}},
        {"type": "note", "pitch": {"step": "E", "octave": 5},
         "duration": {"type": "quarter"}},
        {"type": "note", "pitch": {"step": "G", "octave": 5},
         "duration": {"type": "quarter"}}
      ]
    }
  ]
}
''';

const String _seedMusicXml = '''
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>4</duration><type>quarter</type>
      </note>
      <note>
        <pitch><step>D</step><octave>5</octave></pitch>
        <duration>4</duration><type>quarter</type>
      </note>
      <note>
        <pitch><step>E</step><octave>5</octave></pitch>
        <duration>4</duration><type>quarter</type>
      </note>
      <note>
        <pitch><step>G</step><octave>5</octave></pitch>
        <duration>4</duration><type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

const String _seedMei = '''
<mei xmlns="http://www.music-encoding.org/ns/mei">
 <music>
  <body><mdiv><score>
   <scoreDef><staffGrp>
    <staffDef n="1" lines="5" clef.shape="G" clef.line="2"
              meter.count="4" meter.unit="4"/>
   </staffGrp></scoreDef>
   <section><measure n="1"><staff n="1"><layer n="1">
    <note pname="c" oct="5" dur="4"/>
    <note pname="d" oct="5" dur="4"/>
    <note pname="e" oct="5" dur="4"/>
    <note pname="g" oct="5" dur="4"/>
   </layer></staff></measure></section>
  </score></mdiv></body>
 </music>
</mei>
''';
