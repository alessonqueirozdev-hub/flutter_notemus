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
