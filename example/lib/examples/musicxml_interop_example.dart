import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// MusicXML in, MusicXML out — with the round trip shown, not asserted.
///
/// This is the interop case the gallery had no page for at all, which is odd
/// given it is the format most notation software actually speaks. It renders
/// a real MusicXML document, exports the parsed model straight back out, and
/// prints both so you can see for yourself what survived.
class MusicXmlInteropExample extends StatelessWidget {
  const MusicXmlInteropExample({super.key});

  static const _accent = Color(0xFF047857);

  @override
  Widget build(BuildContext context) {
    final staff = MusicXMLParser.parseMusicXML(_source);
    final exported = MusicXMLParser.staffToMusicXML(staff);
    final reparsed = MusicXMLParser.parseMusicXML(exported);

    final warnings = <String>[];
    MusicXMLParser.parseMusicXML(_malformed, warnings: warnings);

    return ExampleShowcasePage(
      title: 'MusicXML Import and Export',
      subtitle:
          'A document goes in, a Staff comes out, and the Staff goes back to '
          'XML. Both directions are on this page, including what the parser '
          'refuses to accept in silence.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'What a round trip has to preserve',
          description:
              'Pitch and rhythm are the easy half. The half that used to be '
              'lost here was structure: a tuplet came back as loose notes '
              'because the exporter wrote <time-modification> without '
              '<notations><tuplet>, so a 4/4 bar of a triplet plus a quarter '
              'measured 0.625 instead of 0.5. Both tags are written now, and '
              'the importer opens a group from the ratio even when the bracket '
              'tag is missing.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Imported from MusicXML',
          description:
              'Parsed with MusicXMLParser.parseMusicXML. The triplet, the '
              'accidental, the slur and the dynamic all come from the document '
              'below — nothing on this line was built in Dart.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: staff,
            accentColor: _accent,
            minHeight: 220,
            staffSpace: 15,
          ),
        ),
        ExampleSectionCard(
          title: 'Exported, then imported again',
          description:
              'The staff above was written back out with staffToMusicXML and '
              'read in a second time. If the round trip lost anything, these '
              'two lines would differ — compare them directly.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: reparsed,
            accentColor: _accent,
            minHeight: 220,
            staffSpace: 15,
          ),
        ),
        ExampleSectionCard(
          title: 'The source document',
          description:
              'Trimmed to the part that matters. A full MusicXML file carries '
              'a <part-list>, identification and layout blocks as well.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _source.trim()),
        ),
        ExampleSectionCard(
          title: 'What the exporter produced',
          description:
              'Note <time-modification> AND <notations><tuplet> on the triplet: '
              'the second is what makes the group survive a re-import.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: exported.trim()),
        ),
        ExampleSectionCard(
          title: 'Malformed input is reported, not absorbed',
          description:
              'parseMusicXML takes an optional warnings list, so a partial '
              'import stops being indistinguishable from a complete one. The '
              'document fed here declares <divisions>0</divisions>. Coverage is '
              'not total — four kinds of defect are still silent, and that is '
              'tracked as issue #29 rather than glossed over.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: warnings.isEmpty
                ? '(no warnings)'
                : warnings.map((w) => '• $w').join('\n'),
          ),
        ),
      ],
    );
  }
}

/// A bar of a 3:2 triplet plus a quarter, with an accidental, a slur and a
/// dynamic — chosen because each one exercises a different part of the parser.
const String _source = '''
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>12</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <direction placement="below">
        <direction-type><dynamics><mf/></dynamics></direction-type>
      </direction>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>8</duration><voice>1</voice><type>quarter</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
        <notations>
          <tuplet type="start" number="1"/>
          <slur type="start" number="1"/>
        </notations>
      </note>
      <note>
        <pitch><step>E</step><alter>-1</alter><octave>5</octave></pitch>
        <duration>8</duration><voice>1</voice><type>quarter</type>
        <accidental>flat</accidental>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
      </note>
      <note>
        <pitch><step>G</step><octave>5</octave></pitch>
        <duration>8</duration><voice>1</voice><type>quarter</type>
        <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
        <notations>
          <tuplet type="stop" number="1"/>
          <slur type="stop" number="1"/>
        </notations>
      </note>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>12</duration><voice>1</voice><type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

/// `<divisions>0</divisions>` makes every duration in the part undefined.
const String _malformed = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Bad</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>0</divisions></attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';
