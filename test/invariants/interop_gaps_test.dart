// Import gaps the 2.6.0 audit listed as NOT IMPLEMENTED.
//
// Each test here was written against the *claim* that a gap was closed, not
// against the implementation — the point is to check the claim, and to probe a
// neighbouring case the fix might have missed.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

String _partwise(String body, {String attributes = ''}) =>
    '<score-partwise version="4.0">'
    '<part-list><score-part id="P1"><part-name>P</part-name></score-part>'
    '</part-list>'
    '<part id="P1"><measure number="1">'
    '<attributes><divisions>4</divisions>'
    '<time><beats>4</beats><beat-type>4</beat-type></time>'
    '<clef><sign>G</sign><line>2</line></clef>'
    '$attributes</attributes>'
    '$body'
    '</measure></part></score-partwise>';

String _mei(String scoreDef, String layer) =>
    '<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv>'
    '<score>$scoreDef'
    '<section><measure n="1"><staff n="1"><layer n="1">$layer'
    '</layer></staff></measure></section>'
    '</score></mdiv></body></music></mei>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicXML — percussion and unpitched notes', () {
    test('an unpitched note is not discarded', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<note><unpitched>'
        '<display-step>E</display-step><display-octave>5</display-octave>'
        '</unpitched><duration>4</duration><type>quarter</type></note>',
      ));
      final notes = staff.measures.first.elements.whereType<Note>().toList();
      expect(notes, hasLength(1),
          reason: '`_musicXmlPitch` used to return null for <unpitched>, and '
              'the note was dropped without a word.');
      expect(notes.first.pitch.step, 'E');
      expect(notes.first.pitch.octave, 5);
    });

    test('an unpitched note without display info still survives', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<note><unpitched/><duration>4</duration><type>quarter</type></note>',
      ));
      expect(staff.measures.first.elements.whereType<Note>(), hasLength(1),
          reason: 'a drum part that omits display-step must not vanish.');
    });
  });

  group('MusicXML — staff lines', () {
    test('a one-line percussion staff is imported', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<note><unpitched><display-step>E</display-step>'
        '<display-octave>4</display-octave></unpitched>'
        '<duration>4</duration><type>quarter</type></note>',
        attributes: '<staff-details><staff-lines>1</staff-lines>'
            '</staff-details>',
      ));
      expect(staff.lineCount, 1);
    });

    test('a six-line tab staff is imported', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<note><pitch><step>E</step><octave>4</octave></pitch>'
        '<duration>4</duration><type>quarter</type></note>',
        attributes: '<staff-details><staff-lines>6</staff-lines>'
            '</staff-details>',
      ));
      expect(staff.lineCount, 6);
    });

    test('a normal staff still defaults to five lines', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>4</duration><type>quarter</type></note>',
      ));
      expect(staff.lineCount, 5);
    });
  });

  group('MusicXML — tempo from <sound>', () {
    test('<sound tempo> becomes a TempoMark when there is no metronome', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<direction placement="above"><sound tempo="144"/></direction>'
        '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>4</duration><type>quarter</type></note>',
      ));
      final tempos =
          staff.measures.first.elements.whereType<TempoMark>().toList();
      expect(tempos, hasLength(1));
      expect(tempos.first.bpm, 144);
    });

    test('an explicit metronome is not duplicated by <sound>', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<direction><direction-type><metronome>'
        '<beat-unit>quarter</beat-unit><per-minute>90</per-minute>'
        '</metronome></direction-type><sound tempo="90"/></direction>'
        '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>4</duration><type>quarter</type></note>',
      ));
      expect(staff.measures.first.elements.whereType<TempoMark>(),
          hasLength(1),
          reason: 'reading both would print the tempo twice.');
    });
  });

  group('MEI — key mode, additive meter, tablature, header', () {
    test('@mode reaches the key signature', () {
      final staff = MEIParser.parseMEI(_mei(
        '<scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" '
        'clef.line="2" key.sig="1s" key.mode="minor" meter.count="4" '
        'meter.unit="4"/></staffGrp></scoreDef>',
        '<note pname="e" oct="4" dur="4"/>',
      ));
      final key =
          staff.measures.first.elements.whereType<KeySignature>().firstOrNull;
      expect(key, isNotNull);
      expect(key!.count, 1);
      expect(key.mode, KeyMode.minor,
          reason: 'KeyMode existed in the model and nothing ever filled it.');
    });

    test('an additive meter survives import', () {
      final staff = MEIParser.parseMEI(_mei(
        '<scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" '
        'clef.line="2" meter.count="3+2+2" meter.unit="8"/></staffGrp>'
        '</scoreDef>',
        '<note pname="c" oct="5" dur="8"/>',
      ));
      final ts = staff.measures.first.elements
          .whereType<TimeSignature>()
          .firstOrNull;
      expect(ts, isNotNull);
      expect(ts!.isAdditive, isTrue);
      expect(ts.additiveGroups?.map((g) => g.numerator).toList(), [3, 2, 2]);
      expect(ts.denominator, 8);
    });

    test('@tab.fret and @tab.string reach the note', () {
      final staff = MEIParser.parseMEI(_mei(
        '<scoreDef><staffGrp><staffDef n="1" lines="6" clef.shape="G" '
        'clef.line="2" meter.count="4" meter.unit="4"/></staffGrp></scoreDef>',
        '<note pname="e" oct="4" dur="4" tab.fret="3" tab.string="2"/>',
      ));
      final note = staff.measures.first.elements.whereType<Note>().first;
      expect(note.tabFret, 3);
      expect(note.tabString, 2);
      expect(note.isTabNote, isTrue);
    });

    test('staffDef @lines reaches the staff', () {
      final staff = MEIParser.parseMEI(_mei(
        '<scoreDef><staffGrp><staffDef n="1" lines="6" clef.shape="G" '
        'clef.line="2" meter.count="4" meter.unit="4"/></staffGrp></scoreDef>',
        '<note pname="e" oct="4" dur="4"/>',
      ));
      expect(staff.lineCount, 6);
    });

    test('<meiHead> is imported through scoreFromMei', () {
      const doc = '<mei xmlns="http://www.music-encoding.org/ns/mei">'
          '<meiHead><fileDesc><titleStmt>'
          '<title>Missa Papae Marcelli</title>'
          '</titleStmt></fileDesc></meiHead>'
          '<music><body><mdiv><score>'
          '<scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" '
          'clef.line="2" meter.count="4" meter.unit="4"/></staffGrp>'
          '</scoreDef>'
          '<section><measure n="1"><staff n="1"><layer n="1">'
          '<note pname="c" oct="4" dur="4"/>'
          '</layer></staff></measure></section>'
          '</score></mdiv></body></music></mei>';

      final score = MEIParser.scoreFromMei(doc);
      expect(score.meiHeader, isNotNull,
          reason: 'MeiHeader was model-only: the classes existed and nothing '
              'ever parsed a <meiHead> into them.');
      expect(score.title, 'Missa Papae Marcelli');
      expect(score.staffGroups, isNotEmpty);
    });

    test('a document without <meiHead> still imports', () {
      final score = MEIParser.scoreFromMei(_mei(
        '<scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" '
        'clef.line="2" meter.count="4" meter.unit="4"/></staffGrp></scoreDef>',
        '<note pname="c" oct="4" dur="4"/>',
      ));
      expect(score.staffGroups, isNotEmpty);
    });
  });

  group('regression guard — the earlier fixes still hold', () {
    test('divisions still drive an untyped note', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(
        '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>16</duration></note>',
      ));
      expect(
        staff.measures.first.elements.whereType<Note>().first.duration.type,
        DurationType.whole,
      );
    });

    test('an invalid step is still rejected', () {
      expect(
        () => MusicXMLParser.parseMusicXML(_partwise(
          '<note><pitch><step>H</step><octave>4</octave></pitch>'
          '<type>quarter</type></note>',
        )),
        throwsA(isA<FormatException>()),
      );
    });

    test('MEI still reads every section', () {
      const doc = '<mei xmlns="http://www.music-encoding.org/ns/mei">'
          '<music><body><mdiv><score>'
          '<scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" '
          'clef.line="2" meter.count="4" meter.unit="4"/></staffGrp>'
          '</scoreDef>'
          '<section n="1"><measure n="1"><staff n="1"><layer n="1">'
          '<note pname="c" oct="4" dur="4"/></layer></staff></measure>'
          '</section>'
          '<section n="2"><measure n="2"><staff n="1"><layer n="1">'
          '<note pname="g" oct="4" dur="4"/></layer></staff></measure>'
          '</section>'
          '</score></mdiv></body></music></mei>';
      expect(MEIParser.parseMEI(doc).measures.length, 2);
    });
  });
}
