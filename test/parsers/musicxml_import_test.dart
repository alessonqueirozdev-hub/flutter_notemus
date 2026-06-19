// MusicXML import: directions (crescendo/diminuendo wedges).

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String score(String measureBody) =>
      '<score-partwise version="4.0"><part-list><score-part id="P1">'
      '<part-name>Music</part-name></score-part></part-list><part id="P1">'
      '<measure number="1">$measureBody</measure></part></score-partwise>';

  List<Dynamic> dynamicsOf(Staff s) =>
      s.measures.expand((m) => m.elements).whereType<Dynamic>().toList();

  group('MusicXML cautionary/editorial accidentals', () {
    List<Note> notesOf(Staff s) =>
        s.measures.expand((m) => m.elements).whereType<Note>().toList();

    test('cautionary/parentheses -> parentheses; bracket/editorial -> brackets',
        () {
      final xml = score(
        '<note><pitch><step>C</step><octave>5</octave><alter>1</alter></pitch>'
        '<duration>1</duration><type>quarter</type>'
        '<accidental cautionary="yes">sharp</accidental></note>'
        '<note><pitch><step>A</step><octave>4</octave><alter>-1</alter></pitch>'
        '<duration>1</duration><type>quarter</type>'
        '<accidental bracket="yes">flat</accidental></note>'
        '<note><pitch><step>G</step><octave>4</octave><alter>1</alter></pitch>'
        '<duration>1</duration><type>quarter</type>'
        '<accidental>sharp</accidental></note>',
      );
      final notes = notesOf(MusicXMLParser.parseMusicXML(xml));
      expect(notes[0].accidentalParenthesis, AccidentalParenthesis.parentheses);
      expect(notes[1].accidentalParenthesis, AccidentalParenthesis.brackets);
      expect(notes[2].accidentalParenthesis, AccidentalParenthesis.none);
    });
  });

  group('MusicXML multi-part / multi-staff import', () {
    List<Note> staffNotes(Staff s) =>
        s.measures.expand((m) => m.elements).whereType<Note>().toList();

    test('each <part> becomes its own staff in the Score (SATB/ensemble)', () {
      const xml = '<score-partwise version="4.0"><part-list>'
          '<score-part id="P1"><part-name>Soprano</part-name></score-part>'
          '<score-part id="P2"><part-name>Bass</part-name></score-part>'
          '</part-list>'
          '<part id="P1"><measure number="1">'
          '<note><pitch><step>C</step><octave>5</octave></pitch>'
          '<duration>1</duration><type>quarter</type></note></measure></part>'
          '<part id="P2"><measure number="1">'
          '<note><pitch><step>C</step><octave>3</octave></pitch>'
          '<duration>1</duration><type>quarter</type></note></measure></part>'
          '</score-partwise>';
      final score = MusicXMLParser.scoreFromMusicXML(xml);
      expect(score.allStaves.length, 2);
      expect(staffNotes(score.allStaves[0]).single.pitch.octave, 5);
      expect(staffNotes(score.allStaves[1]).single.pitch.octave, 3);
    });

    test('a 2-staff part (piano) splits by <staff> with per-staff clefs', () {
      const xml = '<score-partwise version="4.0"><part-list>'
          '<score-part id="P1"><part-name>Piano</part-name></score-part>'
          '</part-list><part id="P1"><measure number="1">'
          '<attributes><divisions>1</divisions><staves>2</staves>'
          '<clef number="1"><sign>G</sign><line>2</line></clef>'
          '<clef number="2"><sign>F</sign><line>4</line></clef></attributes>'
          '<note><pitch><step>E</step><octave>5</octave></pitch>'
          '<duration>1</duration><type>quarter</type><staff>1</staff></note>'
          '<note><pitch><step>C</step><octave>3</octave></pitch>'
          '<duration>1</duration><type>quarter</type><staff>2</staff></note>'
          '</measure></part></score-partwise>';
      final score = MusicXMLParser.scoreFromMusicXML(xml);
      expect(score.allStaves.length, 2);
      // Treble staff gets the E5 + a G clef; bass staff the C3 + an F clef.
      final s1 = score.allStaves[0];
      final s2 = score.allStaves[1];
      expect(staffNotes(s1).single.pitch.octave, 5);
      expect(staffNotes(s2).single.pitch.octave, 3);
      Clef clefOf(Staff s) =>
          s.measures.first.elements.whereType<Clef>().first;
      expect(clefOf(s1).actualClefType, ClefType.treble);
      expect(clefOf(s2).actualClefType, ClefType.bass);
    });
  });

  group('MusicXML <wedge> import', () {
    test('crescendo wedge becomes a hairpin Dynamic', () {
      final xml = score(
        '<direction><direction-type><wedge type="crescendo"/></direction-type>'
        '</direction>'
        '<note><pitch><step>C</step><octave>5</octave></pitch>'
        '<duration>1</duration><type>quarter</type></note>'
        '<direction><direction-type><wedge type="stop"/></direction-type>'
        '</direction>',
      );
      final dyns = dynamicsOf(MusicXMLParser.parseMusicXML(xml));
      expect(dyns.length, 1);
      expect(dyns.first.type, DynamicType.crescendo);
      expect(dyns.first.isHairpin, isTrue);
    });

    test('diminuendo wedge becomes a hairpin Dynamic', () {
      final xml = score(
        '<direction><direction-type><wedge type="diminuendo"/></direction-type>'
        '</direction>'
        '<note><pitch><step>C</step><octave>5</octave></pitch>'
        '<duration>1</duration><type>quarter</type></note>',
      );
      final dyns = dynamicsOf(MusicXMLParser.parseMusicXML(xml));
      expect(dyns.length, 1);
      expect(dyns.first.type, DynamicType.diminuendo);
      expect(dyns.first.isHairpin, isTrue);
    });
  });
}
