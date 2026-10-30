// test/parsers/sole_voice_import_test.dart
//
// A bar whose ONLY voice is not voice 1 imported empty. The single-voice
// branch of both XML importers read `voice(1)` instead of the voice that was
// actually there. MuseScore numbers a piano's lower staff from voice 5, so on
// its 4.7.4 reference export the left hand's whole note in bar 2 disappeared.
// Bar 1 survived only because its clef/key/meter landed in voice 1, which sent
// it down the multi-voice path.
//
// Found by importing @zamvar's MuseScore reference fixture.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

List<String> _notes(Measure m) => [
      for (final e in m.allElements)
        if (e is Note) '${e.pitch.step}${e.pitch.octave}',
    ];

void main() {
  test('MusicXML: a bar whose only voice is 5 keeps its notes', () {
    const xml = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>F</sign><line>4</line></clef></attributes>
      <note><pitch><step>C</step><octave>3</octave></pitch>
        <duration>4</duration><voice>5</voice><type>whole</type></note>
    </measure>
    <measure number="2">
      <note><pitch><step>D</step><octave>3</octave></pitch>
        <duration>4</duration><voice>5</voice><type>whole</type></note>
    </measure>
  </part>
</score-partwise>''';
    final warnings = <String>[];
    final staff = MusicXMLParser.parseMusicXML(xml, warnings: warnings);
    expect(staff.measures.map(_notes), [
      ['C3'],
      ['D3'],
    ]);
    expect(warnings, isEmpty);

    // The notes keep their voice, too. A plain Measure is voice 1 to MIDI, so
    // filing bar 2 there put its D3 out of reach of per-voice solo/mute.
    final bar2 = staff.measures[1];
    expect(bar2, isA<MultiVoiceMeasure>());
    expect((bar2 as MultiVoiceMeasure).sortedVoices.map((v) => v.number), [5]);
    final soloed = MidiMapper.fromStaff(
      staff,
      options: const MidiGenerationOptions(soloVoices: {5}),
    );
    final pitches = [
      for (final track in soloed.tracks)
        for (final e in track.events)
          if (e.type == MidiEventType.noteOn) e.note,
    ];
    expect(pitches, [48, 50]); // C3, D3
  });

  test('MEI: a bar whose only layer is n="3" keeps its notes', () {
    const mei = '''
<mei xmlns="http://www.music-encoding.org/ns/mei" meiversion="5.0">
  <music><body><mdiv><score>
    <scoreDef meter.count="4" meter.unit="4">
      <staffGrp><staffDef n="1" lines="5" clef.shape="F" clef.line="4"/></staffGrp>
    </scoreDef>
    <section>
      <measure n="1"><staff n="1"><layer n="3">
        <note pname="c" oct="3" dur="1"/>
      </layer></staff></measure>
      <measure n="2"><staff n="1"><layer n="3">
        <note pname="d" oct="3" dur="1"/>
      </layer></staff></measure>
    </section>
  </score></mdiv></body></music>
</mei>''';
    final staff = MEIParser.parseMEI(mei);
    // Bar 1 survives either way: the scoreDef's clef and meter land in voice
    // 1 and send it down the multi-voice path. Bar 2 has nothing else.
    expect(staff.measures.map(_notes), [
      ['C3'],
      ['D3'],
    ]);
  });

  test('the MuseScore reference imports every bar, with no warning', () {
    final warnings = <String>[];
    final score = MusicXMLParser.scoreFromBytes(
      File('test/parsers/fixtures/musescore_4_7_4/notemus_reference.mxl')
          .readAsBytesSync(),
      warnings: warnings,
    );
    expect(warnings, isEmpty);
    final lowerStaff = score.allStaves.last;
    expect(lowerStaff.measures[1].allElements.whereType<Note>().map(
          (n) => '${n.pitch.step}${n.pitch.octave}',
        ),
        ['D3']);
  });
}
