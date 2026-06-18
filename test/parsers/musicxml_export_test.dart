// MusicXML export: real durations (<divisions>) and tuplet round-trip.

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Note> notesOf(Staff s) =>
      s.measures.expand((m) => m.elements).whereType<Note>().toList();

  group('MusicXML export durations', () {
    test('emits <divisions> and duration proportional to note value', () {
      final staff = Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter)))
          ..add(Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.eighth)))
          ..add(Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.half))),
      ]);
      final xml = MusicXMLParser.staffToMusicXML(staff);
      expect(xml.contains('<divisions>480</divisions>'), isTrue);
      // quarter = 480, eighth = 240, half = 960 (not all "1").
      expect(xml.contains('<duration>480</duration>'), isTrue);
      expect(xml.contains('<duration>240</duration>'), isTrue);
      expect(xml.contains('<duration>960</duration>'), isTrue);
    });
  });

  group('MusicXML clef export', () {
    String clefXml(ClefType ct) => MusicXMLParser.staffToMusicXML(Staff(
        measures: [Measure()..add(Clef(clefType: ct))]));

    test('alto C-clef exports on line 3 (not 2)', () {
      final xml = clefXml(ClefType.alto);
      expect(xml.contains('<sign>C</sign>'), isTrue);
      expect(xml.contains('<line>3</line>'), isTrue);
    });

    test('bass clef exports on line 4', () {
      expect(clefXml(ClefType.bass).contains('<line>4</line>'), isTrue);
    });

    test('octave clef emits clef-octave-change', () {
      final xml = clefXml(ClefType.treble8vb);
      expect(xml.contains('<clef-octave-change>-1</clef-octave-change>'),
          isTrue);
    });
  });

  group('MusicXML tuplet round-trip', () {
    test('a triplet survives export -> import', () {
      final staff = Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(Tuplet.triplet(elements: [
            Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.eighth)),
            Note(
                pitch: const Pitch(step: 'D', octave: 5),
                duration: const Duration(DurationType.eighth)),
            Note(
                pitch: const Pitch(step: 'E', octave: 5),
                duration: const Duration(DurationType.eighth)),
          ])),
      ]);
      final xml = MusicXMLParser.staffToMusicXML(staff);
      // time-modification present (3:2), and the notes are emitted.
      expect(xml.contains('<time-modification>'), isTrue);
      expect(xml.contains('<actual-notes>3</actual-notes>'), isTrue);

      final reimported = MusicXMLParser.parseMusicXML(xml);
      // The three triplet notes survived (previously the Tuplet was dropped).
      expect(notesOf(reimported).length, 3);
    });
  });
}
