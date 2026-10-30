// test/core/implicit_measure_test.dart
//
// A pickup bar (anacrusis) and other bars "excluded from the count" are
// marked implicit in every interchange format: MusicXML
// `<measure implicit="yes">`, MEI `<measure metcon="false">`. The model had
// no field for it, so an imported pickup lost that fact and:
//
// - played as a FULL bar: a one-quarter pickup in 4/4 was followed by three
//   beats of silence before bar 1, because MIDI sized every bar from its meter;
// - was numbered 1, so the first full bar printed as 2;
// - was exported as an ordinary bar, so a round trip dropped the flag.
//
// `Measure.isImplicit` carries it now. Ported from @zamvar's fork
// (`codex/note-tap`, "implicit MusicXML pickup uses its exact source
// duration"), reworked onto the 2.8 engine.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

const _pickupXml = '''
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Voice</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="0" implicit="yes">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><type>quarter</type>
      </note>
    </measure>
    <measure number="1">
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>16</duration><voice>1</voice><type>whole</type>
      </note>
    </measure>
    <measure number="2">
      <note>
        <pitch><step>E</step><octave>4</octave></pitch>
        <duration>16</duration><voice>1</voice><type>whole</type>
      </note>
    </measure>
  </part>
</score-partwise>
''';

List<int> _noteOnTicks(MidiSequence sequence) => sequence.tracks
    .firstWhere((t) => t.name == 'Staff 1')
    .events
    .where((e) => e.type == MidiEventType.noteOn)
    .map((e) => e.tick)
    .toList();

Staff _handBuiltPickup() => Staff(measures: [
      Measure(isImplicit: true)
        ..add(Clef(clefType: ClefType.treble))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const MusicDuration(DurationType.quarter))),
      Measure()
        ..add(Note(
            pitch: const Pitch(step: 'D', octave: 4),
            duration: const MusicDuration(DurationType.whole))),
      Measure()
        ..add(Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const MusicDuration(DurationType.whole))),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicXML import', () {
    test('reads implicit="yes" and the source measure numbers', () {
      final staff = MusicXMLParser.parseMusicXML(_pickupXml);
      expect(staff.measures.map((m) => m.isImplicit), [true, false, false]);
      expect(staff.measures.map((m) => m.number), [0, 1, 2]);
    });

    test('a non-numeric measure number is left to the engine', () {
      final staff = MusicXMLParser.parseMusicXML(
          _pickupXml.replaceFirst('number="1"', 'number="X1"'));
      expect(staff.measures[1].number, isNull);
    });
  });

  group('MIDI', () {
    test('an imported pickup lasts as long as its content', () {
      final staff = MusicXMLParser.parseMusicXML(_pickupXml);
      // 960 ticks per quarter: the pickup is one quarter, so bar 1 starts at
      // 960, not at 3840 after three beats of silence.
      expect(_noteOnTicks(MidiMapper.fromStaff(staff)), [0, 960, 4800]);
    });

    test('a hand-built implicit bar does the same', () {
      expect(_noteOnTicks(MidiMapper.fromStaff(_handBuiltPickup())),
          [0, 960, 4800]);
    });

    test('an ordinary short bar still occupies its full meter', () {
      final staff = _handBuiltPickup();
      final plain = Staff(measures: [
        Measure()..elements.addAll(staff.measures.first.elements),
        ...staff.measures.skip(1),
      ]);
      expect(_noteOnTicks(MidiMapper.fromStaff(plain)), [0, 3840, 7680]);
    });

    // MIDI used to skip `Space` outright: it advanced no time while playing
    // and added none to an implicit bar's length.
    test('a <forward> gap delays the note after it', () {
      final staff = MusicXMLParser.parseMusicXML(_pickupXml.replaceFirst(
          RegExp(r'<note>\s*<pitch><step>D</step>'),
          '<forward><duration>8</duration></forward>'
              '<note><pitch><step>D</step>'));
      // Bar 1's D now enters on beat 3 (a half note of forward at 960/qtr).
      expect(_noteOnTicks(MidiMapper.fromStaff(staff))[1], 960 + 1920);
    });

    test('a <forward> gap counts toward an implicit bar', () {
      final staff = MusicXMLParser.parseMusicXML(_pickupXml.replaceFirst(
          RegExp(r'<note>\s*<pitch><step>C</step>'),
          '<forward><duration>4</duration></forward>'
              '<note><pitch><step>C</step>'));
      // Pickup = one quarter of forward + one quarter: C at 960, bar 1 at
      // 1920, bar 2 at 1920 + 3840.
      expect(_noteOnTicks(MidiMapper.fromStaff(staff)), [960, 1920, 5760]);
    });

    test('a grace note does not lengthen an implicit bar', () {
      final staff = _handBuiltPickup();
      staff.measures.first.elements.insert(
          2,
          Note(
              pitch: const Pitch(step: 'B', octave: 3),
              duration: const MusicDuration(DurationType.eighth),
              isGraceNote: true));
      final ticks = _noteOnTicks(MidiMapper.fromStaff(staff));
      expect(ticks.sublist(ticks.length - 2), [960, 4800]);
    });
  });

  group('measure numbers', () {
    late SmuflMetadata metadata;
    setUpAll(() async {
      metadata = SmuflMetadata();
      await metadata.load();
    });

    test('an implicit bar is not counted', () {
      final engine = LayoutEngine(_handBuiltPickup(),
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      engine.layout();
      expect(engine.measureNumbers, {0: 0, 1: 1, 2: 2});
    });

    test('an implicit bar mid-piece shares the previous number', () {
      final staff = _handBuiltPickup();
      staff.measures.add(Measure(isImplicit: true)
        ..add(Note(
            pitch: const Pitch(step: 'F', octave: 4),
            duration: const MusicDuration(DurationType.half))));
      staff.measures.add(Measure()
        ..add(Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const MusicDuration(DurationType.whole))));
      final engine = LayoutEngine(staff,
          availableWidth: 2000, staffSpace: 12, metadata: metadata);
      expect(engine.measureNumbers, {0: 0, 1: 1, 2: 2, 3: 2, 4: 3});
    });

    test('a pickup imported from MusicXML lays out without errors', () {
      final staff = MusicXMLParser.parseMusicXML(_pickupXml);
      final engine = LayoutEngine(staff,
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      engine.layout();
      expect(engine.measureNumbers, {0: 0, 1: 1, 2: 2});
    });
  });

  group('round trips', () {
    test('MusicXML export writes implicit="yes" and reads it back', () {
      final xml = MusicXMLParser.staffToMusicXML(_handBuiltPickup());
      expect(xml, contains('implicit="yes"'));
      final back = MusicXMLParser.parseMusicXML(xml);
      expect(back.measures.map((m) => m.isImplicit), [true, false, false]);
    });

    test('JSON export writes "implicit" and reads it back', () {
      final json = JsonMusicExporter.staffToJson(_handBuiltPickup());
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(json, contains('"implicit": true'));
      final back = JsonMusicParser.parseStaff(jsonEncode(decoded));
      expect(back.measures.map((m) => m.isImplicit), [true, false, false]);
    });

    test('JSON export writes "irregular" and reads it back', () {
      final staff = _handBuiltPickup();
      staff.measures[1].isIrregular = true;
      final json = JsonMusicExporter.staffToJson(staff);
      expect(json, contains('"irregular": true'));
      final back = JsonMusicParser.parseStaff(json);
      expect(back.measures.map((m) => m.isIrregular), [false, true, false]);
    });

    test('MEI metcon="false" imports as implicit', () {
      const mei = '''
<mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0">
  <music><body><mdiv><score>
    <scoreDef meter.count="4" meter.unit="4">
      <staffGrp><staffDef n="1" lines="5" clef.shape="G" clef.line="2"/></staffGrp>
    </scoreDef>
    <section>
      <measure n="0" metcon="false"><staff n="1"><layer n="1">
        <note pname="c" oct="4" dur="4"/>
      </layer></staff></measure>
      <measure n="1"><staff n="1"><layer n="1">
        <note pname="d" oct="4" dur="1"/>
      </layer></staff></measure>
    </section>
  </score></mdiv></body></music>
</mei>
''';
      final staff = MEIParser.parseMEI(mei);
      expect(staff.measures.map((m) => m.isImplicit), [true, false]);
    });

    // `@metcon="false"` only says the content does not fill the meter. A
    // mid-piece irregular bar still counts; marking it implicit made the
    // next auto-numbered bar repeat its number.
    test('MEI metcon="false" mid-piece is an irregular bar that still counts',
        () {
      const mei = '''
<mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0">
  <music><body><mdiv><score>
    <scoreDef meter.count="4" meter.unit="4">
      <staffGrp><staffDef n="1" lines="5" clef.shape="G" clef.line="2"/></staffGrp>
    </scoreDef>
    <section>
      <measure><staff n="1"><layer n="1">
        <note pname="c" oct="4" dur="1"/>
      </layer></staff></measure>
      <measure metcon="false"><staff n="1"><layer n="1">
        <note pname="d" oct="4" dur="2"/>
      </layer></staff></measure>
      <measure><staff n="1"><layer n="1">
        <note pname="e" oct="4" dur="1"/>
      </layer></staff></measure>
    </section>
  </score></mdiv></body></music>
</mei>
''';
      final staff = MEIParser.parseMEI(mei);
      expect(staff.measures.map((m) => m.isImplicit), [false, false, false]);
      expect(staff.measures.map((m) => m.isIrregular), [false, true, false]);
      expect(LayoutEngine.displayMeasureNumbers(staff.measures),
          {0: 1, 1: 2, 2: 3});
      // ...and it still lasts only its half note: bar 3 enters at
      // 3840 + 1920, not after two beats of silence at 7680.
      expect(_noteOnTicks(MidiMapper.fromStaff(staff)), [0, 3840, 5760]);
    });
  });

  group('trailing <forward>', () {
    // A forward is only materialised as Space when a later note of its voice
    // needs the gap, so one ENDING an implicit bar left no trace and the next
    // bar started early by the gap.
    test('a pickup ending in a forward lasts until the forward ends', () {
      final staff = MusicXMLParser.parseMusicXML(_pickupXml.replaceFirst(
          RegExp(r'<type>quarter</type>\s*</note>'),
          '<type>quarter</type></note>'
              '<forward><duration>4</duration><voice>1</voice></forward>'));
      // C (one quarter) + one quarter of forward: bar 1 at 1920.
      expect(_noteOnTicks(MidiMapper.fromStaff(staff)), [0, 1920, 5760]);
    });

    test('a forward-only voice does not become a second voice', () {
      final staff = MusicXMLParser.parseMusicXML(_pickupXml.replaceFirst(
          RegExp(r'<type>quarter</type>\s*</note>'),
          '<type>quarter</type></note>'
              '<backup><duration>4</duration></backup>'
              '<forward><duration>4</duration><voice>2</voice></forward>'));
      expect(staff.measures.first, isNot(isA<MultiVoiceMeasure>()));
    });
  });
}
