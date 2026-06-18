// Closes H2 (lyrics were silently dropped on import). Verifies that
// MusicXML <lyric> and MEI <verse>/<syl> are parsed into Note.syllables.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  List<Note> notesOf(Staff staff) =>
      staff.measures.expand((m) => m.elements).whereType<Note>().toList();

  group('MusicXML <lyric> import (I1)', () {
    test('parses syllable text and syllabic type', () {
      const xml =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Music</part-name></score-part></part-list><part id="P1">'
          '<measure number="1">'
          '<note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>'
          '<voice>1</voice><type>quarter</type>'
          '<lyric number="1"><syllabic>begin</syllabic><text>Twin</text></lyric></note>'
          '<note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>'
          '<voice>1</voice><type>quarter</type>'
          '<lyric number="1"><syllabic>end</syllabic><text>kle</text></lyric></note>'
          '</measure></part></score-partwise>';

      final notes = notesOf(MusicXMLParser.parseMusicXML(xml));
      expect(notes.length, 2);
      expect(notes[0].syllables, isNotNull);
      expect(notes[0].syllables!.single.text, 'Twin');
      expect(notes[0].syllables!.single.type, SyllableType.initial);
      expect(notes[1].syllables!.single.text, 'kle');
      expect(notes[1].syllables!.single.type, SyllableType.terminal);
    });

    test('multiple verses produce one syllable per verse, ordered by number',
        () {
      const xml =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Music</part-name></score-part></part-list><part id="P1">'
          '<measure number="1">'
          '<note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration>'
          '<voice>1</voice><type>quarter</type>'
          '<lyric number="2"><text>two</text></lyric>'
          '<lyric number="1"><text>one</text></lyric></note>'
          '</measure></part></score-partwise>';

      final note = notesOf(MusicXMLParser.parseMusicXML(xml)).single;
      expect(note.syllables!.map((s) => s.text).toList(), ['one', 'two']);
    });

    test('note without lyric has null syllables', () {
      const xml =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Music</part-name></score-part></part-list><part id="P1">'
          '<measure number="1"><note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>1</duration><voice>1</voice><type>quarter</type></note>'
          '</measure></part></score-partwise>';
      expect(notesOf(MusicXMLParser.parseMusicXML(xml)).single.syllables, isNull);
    });
  });

  group('MEI <verse>/<syl> import (I3)', () {
    test('parses syllable text and word position', () {
      const mei =
          '<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv>'
          '<score><section><measure n="1"><staff n="1"><layer n="1">'
          '<note pname="c" oct="5" dur="4"><verse n="1"><syl wordpos="i">Twin</syl></verse></note>'
          '<note pname="c" oct="5" dur="4"><verse n="1"><syl wordpos="t">kle</syl></verse></note>'
          '</layer></staff></measure></section></score></mdiv></body></music></mei>';

      final notes = notesOf(MEIParser.parseMEI(mei));
      expect(notes.length, 2);
      expect(notes[0].syllables!.single.text, 'Twin');
      expect(notes[0].syllables!.single.type, SyllableType.initial);
      expect(notes[1].syllables!.single.text, 'kle');
      expect(notes[1].syllables!.single.type, SyllableType.terminal);
    });

    test('multiple verses ordered by @n', () {
      const mei =
          '<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv>'
          '<score><section><measure n="1"><staff n="1"><layer n="1">'
          '<note pname="c" oct="5" dur="4">'
          '<verse n="2"><syl>two</syl></verse>'
          '<verse n="1"><syl>one</syl></verse></note>'
          '</layer></staff></measure></section></score></mdiv></body></music></mei>';

      final note = notesOf(MEIParser.parseMEI(mei)).single;
      expect(note.syllables!.map((s) => s.text).toList(), ['one', 'two']);
    });
  });

  group('MusicXML lyric export round-trip', () {
    test('syllable text + syllabic type survive export and re-import', () {
      final staff = Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(Note(
            pitch: const Pitch(step: 'C', octave: 5),
            duration: const Duration(DurationType.quarter),
            syllables: const [
              Syllable(text: 'Glo', type: SyllableType.initial),
            ],
          ))
          ..add(Note(
            pitch: const Pitch(step: 'D', octave: 5),
            duration: const Duration(DurationType.quarter),
            syllables: const [
              Syllable(text: 'ri', type: SyllableType.middle),
            ],
          ))
          ..add(Note(
            pitch: const Pitch(step: 'E', octave: 5),
            duration: const Duration(DurationType.quarter),
            syllables: const [
              Syllable(text: 'a', type: SyllableType.terminal),
            ],
          )),
      ]);

      final xml = MusicXMLParser.staffToMusicXML(staff);
      expect(xml.contains('<lyric'), isTrue);

      final notes = notesOf(MusicXMLParser.parseMusicXML(xml));
      expect(notes[0].syllables!.single.text, 'Glo');
      expect(notes[0].syllables!.single.type, SyllableType.initial);
      expect(notes[1].syllables!.single.text, 'ri');
      expect(notes[1].syllables!.single.type, SyllableType.middle);
      expect(notes[2].syllables!.single.text, 'a');
      expect(notes[2].syllables!.single.type, SyllableType.terminal);
    });
  });
}
