// MEI import: scoreDef/staffDef defaults and <beam>/<tuplet> containers.

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Note> notesOf(Staff s) =>
      s.measures.expand((m) => m.elements).whereType<Note>().toList();

  const ns = 'xmlns="http://www.music-encoding.org/ns/mei"';
  String mei(String body) =>
      '<mei $ns><music><body><mdiv><score>$body</score></mdiv></body></music></mei>';

  group('MEI scoreDef/staffDef', () {
    test('provides clef, key and meter to the first measure', () {
      final doc = mei(
        '<scoreDef><staffGrp><staffDef n="1" clef.shape="G" clef.line="2" '
        'key.sig="1s" meter.count="3" meter.unit="4"/></staffGrp></scoreDef>'
        '<section><measure n="1"><staff n="1"><layer n="1">'
        '<note pname="c" oct="5" dur="4"/>'
        '</layer></staff></measure></section>',
      );
      final first = MEIParser.parseMEI(doc).measures.first;
      expect(first.elements.whereType<Clef>().first.actualClefType,
          ClefType.treble);
      expect(first.elements.whereType<KeySignature>().first.count, 1);
      final ts = first.elements.whereType<TimeSignature>().first;
      expect(ts.numerator, 3);
      expect(ts.denominator, 4);
    });

    test('bass clef on a baritone staffDef line maps correctly', () {
      final doc = mei(
        '<scoreDef><staffGrp><staffDef n="1" clef.shape="F" clef.line="3"/>'
        '</staffGrp></scoreDef>'
        '<section><measure n="1"><staff n="1"><layer n="1">'
        '<note pname="c" oct="4" dur="4"/>'
        '</layer></staff></measure></section>',
      );
      final clef = MEIParser.parseMEI(doc)
          .measures
          .first
          .elements
          .whereType<Clef>()
          .first;
      expect(clef.actualClefType, ClefType.bassThirdLine);
    });
  });

  group('MEI container elements', () {
    test('<beam> preserves its notes with positional beam types', () {
      final doc = mei(
        '<section><measure n="1"><staff n="1"><layer n="1"><beam>'
        '<note pname="c" oct="5" dur="8"/>'
        '<note pname="d" oct="5" dur="8"/>'
        '<note pname="e" oct="5" dur="8"/>'
        '</beam></layer></staff></measure></section>',
      );
      final notes = notesOf(MEIParser.parseMEI(doc));
      expect(notes.length, 3); // previously all dropped
      expect(notes[0].beam, BeamType.start);
      expect(notes[1].beam, BeamType.inner);
      expect(notes[2].beam, BeamType.end);
    });

    test('<tuplet> container wraps its notes in a Tuplet', () {
      final doc = mei(
        '<section><measure n="1"><staff n="1"><layer n="1">'
        '<tuplet num="3" numbase="2">'
        '<note pname="c" oct="5" dur="8"/>'
        '<note pname="d" oct="5" dur="8"/>'
        '<note pname="e" oct="5" dur="8"/>'
        '</tuplet></layer></staff></measure></section>',
      );
      final tuplets = MEIParser.parseMEI(doc)
          .measures
          .first
          .elements
          .whereType<Tuplet>()
          .toList();
      expect(tuplets.length, 1);
      expect(tuplets.first.elements.length, 3);
      expect(tuplets.first.actualNotes, 3);
      expect(tuplets.first.normalNotes, 2);
    });
  });
}
