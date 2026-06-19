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

  group('MusicXML multi-voice export', () {
    test('two voices export with <backup> and round-trip', () {
      final measure = MultiVoiceMeasure()
        ..addVoice(Voice(number: 1, elements: [
          Note(
              pitch: const Pitch(step: 'G', octave: 5),
              duration: const Duration(DurationType.half)),
          Note(
              pitch: const Pitch(step: 'A', octave: 5),
              duration: const Duration(DurationType.half)),
        ]))
        ..addVoice(Voice(number: 2, elements: [
          Note(
              pitch: const Pitch(step: 'C', octave: 4),
              duration: const Duration(DurationType.whole)),
        ]));
      final xml = MusicXMLParser.staffToMusicXML(Staff(measures: [measure]));
      expect(xml.contains('<backup>'), isTrue);
      expect(xml.contains('<voice>1</voice>'), isTrue);
      expect(xml.contains('<voice>2</voice>'), isTrue);

      final reimported = MusicXMLParser.parseMusicXML(xml);
      final m = reimported.measures.first;
      expect(m is MultiVoiceMeasure, isTrue);
      expect((m as MultiVoiceMeasure).voiceCount, 2);
      // Voice 1 has the two half notes; voice 2 the whole note.
      expect(m.getVoice(1)!.elements.whereType<Note>().length, 2);
      expect(m.getVoice(2)!.elements.whereType<Note>().length, 1);
    });
  });

  group('MusicXML barline export', () {
    test('final and repeat barlines are emitted and round-trip', () {
      final staff = Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.whole)))
          ..add(Barline(type: BarlineType.repeatBackward)),
      ]);
      final xml = MusicXMLParser.staffToMusicXML(staff);
      expect(xml.contains('<barline'), isTrue);
      expect(xml.contains('<repeat'), isTrue);
      expect(xml.contains('backward'), isTrue);

      final barlines = MusicXMLParser.parseMusicXML(xml)
          .measures
          .expand((m) => m.elements)
          .whereType<Barline>()
          .toList();
      expect(barlines.any((b) => b.type == BarlineType.repeatBackward), isTrue);
    });

    test('a plain single barline is not emitted', () {
      final staff = Staff(measures: [
        Measure()
          ..add(Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.whole)))
          ..add(Barline(type: BarlineType.single)),
      ]);
      expect(MusicXMLParser.staffToMusicXML(staff).contains('<barline'),
          isFalse);
    });
  });

  group('MusicXML ornament + grace export', () {
    test('trill ornament and grace note are emitted and round-trip', () {
      final staff = Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.eighth),
              isGraceNote: true))
          ..add(Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter),
              ornaments: [Ornament(type: OrnamentType.trill)])),
      ]);
      final xml = MusicXMLParser.staffToMusicXML(staff);
      expect(xml.contains('<grace'), isTrue);
      expect(xml.contains('<ornaments>'), isTrue);
      expect(xml.contains('<trill-mark'), isTrue);

      final notes = notesOf(MusicXMLParser.parseMusicXML(xml));
      expect(notes.any((n) => n.isGraceNote), isTrue);
      expect(
          notes.any((n) =>
              n.ornaments.any((o) => o.type == OrnamentType.trill)),
          isTrue);
    });
  });

  group('MusicXML cautionary accidental round-trip', () {
    test('parentheses/brackets survive export -> import', () {
      final staff = Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(Note(
              pitch: const Pitch(step: 'C', octave: 5, alter: 1.0),
              duration: const Duration(DurationType.quarter),
              accidentalParenthesis: AccidentalParenthesis.parentheses))
          ..add(Note(
              pitch: const Pitch(step: 'A', octave: 4, alter: -1.0),
              duration: const Duration(DurationType.quarter),
              accidentalParenthesis: AccidentalParenthesis.brackets)),
      ]);
      final xml = MusicXMLParser.staffToMusicXML(staff);
      expect(xml.contains('cautionary="yes"'), isTrue);
      expect(xml.contains('bracket="yes"'), isTrue);

      final notes = notesOf(MusicXMLParser.parseMusicXML(xml));
      expect(notes[0].accidentalParenthesis, AccidentalParenthesis.parentheses);
      expect(notes[1].accidentalParenthesis, AccidentalParenthesis.brackets);
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
