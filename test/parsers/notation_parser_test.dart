import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('NotationParser', () {
    test('detects JSON, MusicXML, and MEI', () {
      expect(
        NotationParser.detectFormat('{"measures": []}'),
        NotationFormat.json,
      );
      expect(
        NotationParser.detectFormat(
          '<score-partwise version="4.0"></score-partwise>',
        ),
        NotationFormat.musicXml,
      );
      expect(
        NotationParser.detectFormat(
          '<mei xmlns="http://www.music-encoding.org/ns/mei"></mei>',
        ),
        NotationFormat.mei,
      );
    });

    test('parses JSON with renderable element coverage', () {
      const json = '''
      {
        "measures": [
          {
            "elements": [
              {"type": "clef", "clefType": "treble"},
              {"type": "keySignature", "count": 2},
              {"type": "timeSignature", "numerator": 4, "denominator": 4},
              {"type": "tempo", "beatUnit": "quarter", "bpm": 96, "text": "Allegro"},
              {"type": "dynamic", "dynamicType": "mf"},
              {"type": "text", "text": "dolce", "textType": "expression"},
              {"type": "octaveMark", "octaveType": "8va", "startMeasure": 0, "endMeasure": 0, "length": 0},
              {"type": "voltaBracket", "number": 1, "length": 0, "hasOpenEnd": true},
              {"type": "repeatMark", "repeatType": "segno"},
              {
                "type": "tuplet",
                "actualNotes": 3,
                "normalNotes": 2,
                "elements": [
                  {"type": "note", "pitch": {"step": "C", "octave": 5}, "duration": {"type": "eighth"}},
                  {"type": "note", "pitch": {"step": "D", "octave": 5}, "duration": {"type": "eighth"}},
                  {"type": "note", "pitch": {"step": "E", "octave": 5}, "duration": {"type": "eighth"}}
                ]
              },
              {
                "type": "chord",
                "duration": {"type": "half"},
                "notes": [
                  {"pitch": {"step": "C", "octave": 4}},
                  {"pitch": {"step": "E", "octave": 4}},
                  {"pitch": {"step": "G", "octave": 4}}
                ]
              },
              {"type": "rest", "duration": {"type": "quarter"}, "ornaments": ["fermata"]},
              {"type": "breath", "breathType": "comma"},
              {"type": "caesura"},
              {"type": "barline", "barlineType": "final_"}
            ]
          }
        ]
      }
      ''';

      final staff = JsonMusicParser.parseStaff(json);
      final elements = staff.measures.first.elements;

      expect(elements.whereType<Clef>().single.actualClefType, ClefType.treble);
      expect(elements.whereType<KeySignature>().single.count, 2);
      expect(elements.whereType<TimeSignature>().single.numerator, 4);
      expect(elements.whereType<TempoMark>().single.bpm, 96);
      expect(elements.whereType<Dynamic>().single.type, DynamicType.mf);
      expect(elements.whereType<MusicText>().single.text, 'dolce');
      expect(elements.whereType<OctaveMark>().single.type, OctaveType.va8);
      expect(elements.whereType<VoltaBracket>().single.hasOpenEnd, isTrue);
      expect(elements.whereType<RepeatMark>().single.type, RepeatType.segno);
      expect(elements.whereType<Tuplet>().single.elements, hasLength(3));
      expect(elements.whereType<Chord>().single.notes, hasLength(3));
      expect(
        elements.whereType<Rest>().single.ornaments.single.type,
        OrnamentType.fermata,
      );
      expect(elements.whereType<Breath>().single.type, BreathType.comma);
      expect(elements.whereType<Caesura>().single.type, BreathType.caesura);
      expect(elements.whereType<Barline>().single.type, BarlineType.final_);
    });

    test('parses MusicXML including multi-voice measures', () {
      const musicXml = '''
      <score-partwise version="4.0">
        <part-list>
          <score-part id="P1"><part-name>Music</part-name></score-part>
        </part-list>
        <part id="P1">
          <measure number="1">
            <attributes>
              <divisions>1</divisions>
              <key><fifths>1</fifths></key>
              <time><beats>4</beats><beat-type>4</beat-type></time>
              <clef><sign>G</sign><line>2</line></clef>
            </attributes>
            <direction>
              <direction-type>
                <metronome><beat-unit>quarter</beat-unit><per-minute>88</per-minute></metronome>
              </direction-type>
            </direction>
            <direction>
              <direction-type><dynamics><mf/></dynamics></direction-type>
            </direction>
            <direction>
              <direction-type><words>espressivo</words></direction-type>
            </direction>
            <direction>
              <direction-type><octave-shift type="up" size="8"/></direction-type>
            </direction>
            <note>
              <pitch><step>C</step><octave>5</octave></pitch>
              <duration>1</duration>
              <voice>1</voice>
              <type>quarter</type>
              <dot/>
              <tie type="start"/>
              <notations>
                <slur type="start"/>
                <articulations>
                  <staccato/>
                  <breath-mark/>
                </articulations>
              </notations>
            </note>
            <note>
              <chord/>
              <pitch><step>E</step><octave>5</octave></pitch>
              <duration>1</duration>
              <voice>1</voice>
              <type>quarter</type>
            </note>
            <note>
              <rest/>
              <duration>2</duration>
              <voice>1</voice>
              <type>half</type>
            </note>
            <barline location="right">
              <bar-style>light-heavy</bar-style>
              <repeat direction="backward"/>
              <ending number="1" type="start">1.</ending>
            </barline>
          </measure>
          <measure number="2">
            <attributes>
              <time><beats>4</beats><beat-type>4</beat-type></time>
            </attributes>
            <note>
              <pitch><step>G</step><octave>5</octave></pitch>
              <duration>1</duration>
              <voice>1</voice>
              <type>quarter</type>
            </note>
            <note>
              <pitch><step>A</step><octave>5</octave></pitch>
              <duration>1</duration>
              <voice>1</voice>
              <type>quarter</type>
            </note>
            <backup><duration>2</duration></backup>
            <note>
              <pitch><step>C</step><octave>4</octave></pitch>
              <duration>2</duration>
              <voice>2</voice>
              <type>half</type>
            </note>
          </measure>
        </part>
      </score-partwise>
      ''';

      final staff = MusicXMLParser.parseMusicXML(musicXml);

      expect(staff.measures, hasLength(2));
      final measureOne = staff.measures.first.elements;
      expect(
        measureOne.whereType<Clef>().single.actualClefType,
        ClefType.treble,
      );
      expect(measureOne.whereType<KeySignature>().single.count, 1);
      expect(measureOne.whereType<TempoMark>().single.bpm, 88);
      expect(measureOne.whereType<Dynamic>().single.type, DynamicType.mf);
      expect(measureOne.whereType<MusicText>().single.text, 'espressivo');
      expect(measureOne.whereType<OctaveMark>().single.type, OctaveType.va8);
      expect(measureOne.whereType<Chord>().single.notes, hasLength(2));
      expect(
        measureOne.whereType<Rest>().single.duration.type,
        DurationType.half,
      );
      expect(measureOne.whereType<Breath>().single.type, BreathType.comma);
      expect(measureOne.whereType<VoltaBracket>().single.number, 1);
      expect(
        measureOne.whereType<Barline>().single.type,
        BarlineType.repeatBackward,
      );

      final secondMeasure = staff.measures[1];
      expect(secondMeasure, isA<MultiVoiceMeasure>());
      final multiVoice = secondMeasure as MultiVoiceMeasure;
      expect(multiVoice.voiceCount, 2);
      expect(multiVoice.voice1!.elements.whereType<Note>(), hasLength(2));
      expect(multiVoice.voice2!.elements.whereType<Note>().single.voice, 2);
    });

    test('parses score-timewise MusicXML with repeat marks', () {
      const musicXml = '''
      <score-timewise version="4.0">
        <part-list>
          <score-part id="P1"><part-name>Music</part-name></score-part>
        </part-list>
        <measure number="1">
          <part id="P1">
            <direction>
              <direction-type><segno/></direction-type>
            </direction>
            <note>
              <pitch><step>C</step><octave>4</octave></pitch>
              <duration>1</duration>
              <voice>1</voice>
              <type>quarter</type>
            </note>
            <barline location="left">
              <repeat direction="forward"/>
            </barline>
          </part>
        </measure>
      </score-timewise>
      ''';

      final staff = NotationParser.parseStaff(musicXml);
      final elements = staff.measures.single.elements;

      expect(elements.whereType<RepeatMark>().single.type, RepeatType.segno);
      expect(
        elements.whereType<Barline>().single.type,
        BarlineType.repeatForward,
      );
      expect(elements.whereType<Note>().single.pitch.step, 'C');
    });

    test('parses MEI layers into voices', () {
      const mei = '''
      <mei xmlns="http://www.music-encoding.org/ns/mei">
        <music>
          <body>
            <mdiv>
              <score>
                <section>
                  <measure n="1">
                    <staff n="1">
                      <clef shape="G" line="2"/>
                      <keySig sig="2s"/>
                      <meterSig count="4" unit="4"/>
                      <tempo unit="4" mm="104">Allegro</tempo>
                      <dynam>mf</dynam>
                      <dir>cantabile</dir>
                      <octave dis="8" dis.place="above"/>
                      <layer n="1">
                        <note pname="c" oct="5" dur="4" dots="1" artic="staccato" tie="i"/>
                        <chord dur="2">
                          <note pname="e" oct="5"/>
                          <note pname="g" oct="5"/>
                        </chord>
                        <breath/>
                      </layer>
                      <layer n="2">
                        <rest dur="2"/>
                        <note pname="c" oct="4" dur="2"/>
                      </layer>
                    </staff>
                  </measure>
                </section>
              </score>
            </mdiv>
          </body>
        </music>
      </mei>
      ''';

      final staff = MEIParser.parseMEI(mei);
      final measure = staff.measures.single as MultiVoiceMeasure;

      expect(measure.voiceCount, 2);
      expect(
        measure.voice1!.elements.whereType<Clef>().single.actualClefType,
        ClefType.treble,
      );
      expect(
        measure.voice1!.elements.whereType<KeySignature>().single.count,
        2,
      );
      expect(
        measure.voice1!.elements.whereType<TimeSignature>().single.denominator,
        4,
      );
      expect(measure.voice1!.elements.whereType<TempoMark>().single.bpm, 104);
      expect(
        measure.voice1!.elements.whereType<Dynamic>().single.type,
        DynamicType.mf,
      );
      expect(
        measure.voice1!.elements.whereType<MusicText>().single.text,
        'cantabile',
      );
      expect(
        measure.voice1!.elements.whereType<OctaveMark>().single.type,
        OctaveType.va8,
      );
      expect(
        measure.voice1!.elements.whereType<Chord>().single.notes,
        hasLength(2),
      );
      expect(
        measure.voice1!.elements.whereType<Breath>().single.type,
        BreathType.comma,
      );
      expect(
        measure.voice2!.elements.whereType<Rest>().single.duration.type,
        DurationType.half,
      );
      expect(measure.voice2!.elements.whereType<Note>().single.voice, 2);
    });

    test('parses MEI repeat marks and barline renditions', () {
      const mei = '''
      <mei xmlns="http://www.music-encoding.org/ns/mei">
        <music>
          <body>
            <mdiv>
              <score>
                <section>
                  <measure n="1" right="rptend">
                    <staff n="1">
                      <repeatMark func="segno"/>
                      <barLine form="dashed"/>
                      <layer n="1">
                        <note pname="c" oct="4" dur="4"/>
                      </layer>
                    </staff>
                  </measure>
                </section>
              </score>
            </mdiv>
          </body>
        </music>
      </mei>
      ''';

      final staff = MEIParser.parseMEI(mei);
      final elements = staff.measures.single.elements;

      expect(elements.whereType<RepeatMark>().single.type, RepeatType.segno);
      expect(
        elements.whereType<Barline>().map((barline) => barline.type),
        containsAll(<BarlineType>[
          BarlineType.dashed,
          BarlineType.repeatBackward,
        ]),
      );
    });

    test('MusicScore factories normalize all supported formats', () {
      final fromJson = MusicScore.fromJson(
        json:
            '{"measures":[{"elements":[{"type":"note","pitch":{"step":"C","octave":4},"duration":{"type":"quarter"}}]}]}',
      );
      final fromMusicXml = MusicScore.fromMusicXml(
        musicXml:
            '<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list><part id="P1"><measure number="1"><note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type></note></measure></part></score-partwise>',
      );
      final fromMei = MusicScore.fromMei(
        mei:
            '<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv><score><section><measure n="1"><staff n="1"><layer n="1"><note pname="c" oct="4" dur="4"/></layer></staff></measure></section></score></mdiv></body></music></mei>',
      );

      expect(fromJson.staff.measures, hasLength(1));
      expect(fromMusicXml.staff.measures, hasLength(1));
      expect(fromMei.staff.measures, hasLength(1));
    });
  });
}
