// Robustness / fuzz suite.
//
// The 2.6.0 forensic audit found ZERO fuzzing and proved the consequence:
// `<step>H</step>` reached the model untouched and blew up later as
// `_TypeError: Null check operator used on a null value`, while
// `<octave>999999</octave>` was accepted silently and produced MIDI note
// 12000000. Boundary validation was added; this file is the guard that keeps it.
//
// What is asserted is a CONTRACT, not a behaviour:
//
//   1. a parser may only fail with a DOMAIN exception — never a TypeError,
//      never a null-check crash, never a hang;
//   2. if it returns a Staff, every Note in it is inside the legal ranges;
//   3. if it returns a Staff, the layout engine must survive it and produce
//      finite coordinates;
//   4. if it returns a Staff, the MIDI mapper must survive it and emit ticks
//      >= 0 with notes in 0..127.
//
// Generation is deterministic (fixed seed) so a failure is reproducible.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

// ---------------------------------------------------------------- corpus ----

const String validMusicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Music</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <key><fifths>2</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><type>quarter</type><voice>1</voice></note>
      <note><pitch><step>D</step><alter>1</alter><octave>5</octave></pitch><duration>4</duration><type>quarter</type><voice>1</voice></note>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>2</duration><type>eighth</type><beam number="1">begin</beam></note>
      <note><pitch><step>F</step><octave>5</octave></pitch><duration>2</duration><type>eighth</type><beam number="1">end</beam></note>
      <note><rest/><duration>4</duration><type>quarter</type></note>
    </measure>
    <measure number="2">
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>16</duration><type>whole</type></note>
      <barline location="right"><bar-style>light-heavy</bar-style></barline>
    </measure>
  </part>
</score-partwise>''';

const String validMei = '''<?xml version="1.0" encoding="UTF-8"?>
<mei xmlns="http://www.music-encoding.org/ns/mei">
  <meiHead><fileDesc><titleStmt><title>Fuzz</title></titleStmt></fileDesc></meiHead>
  <music><body><mdiv><score>
    <scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" clef.line="2" meter.count="4" meter.unit="4"/></staffGrp></scoreDef>
    <section n="1">
      <measure n="1"><staff n="1"><layer n="1">
        <note xml:id="n1" pname="c" oct="5" dur="4"/>
        <note xml:id="n2" pname="d" oct="5" dur="4"/>
        <beam><note pname="e" oct="5" dur="8"/><note pname="f" oct="5" dur="8"/></beam>
        <rest dur="4"/>
      </layer></staff></measure>
    </section>
  </score></mdiv></body></music>
</mei>''';

const String validJson = '''
{"measures":[{"elements":[
  {"type":"clef","clefType":"treble"},
  {"type":"timeSignature","numerator":4,"denominator":4},
  {"pitch":{"step":"C","octave":5},"duration":{"type":"quarter"}},
  {"pitch":{"step":"D","octave":5},"duration":{"type":"quarter"}},
  {"pitch":{"step":"E","octave":5},"duration":{"type":"half"}}
]}]}''';

// ------------------------------------------------------------- mutations ----

/// A named, deterministic corruption of a document.
typedef Mutation = ({String name, String Function(String, math.Random) apply});

final List<Mutation> mutations = <Mutation>[
  (
    name: 'truncate',
    apply: (s, r) => s.substring(0, math.max(1, (s.length * r.nextDouble()).floor())),
  ),
  (
    name: 'drop a random element',
    apply: (s, r) {
      final open = RegExp(r'<([a-zA-Z][\w:.-]*)').allMatches(s).toList();
      if (open.isEmpty) return s;
      final m = open[r.nextInt(open.length)];
      return s.replaceFirst(m.group(0)!, '<zzz');
    },
  ),
  (name: 'octave -> negative', apply: (s, r) => s.replaceFirst(RegExp(r'oct="\d+"'), 'oct="-9"').replaceFirst(RegExp(r'<octave>\d+</octave>'), '<octave>-9</octave>')),
  (name: 'octave -> huge', apply: (s, r) => s.replaceFirst(RegExp(r'oct="\d+"'), 'oct="999999"').replaceFirst(RegExp(r'<octave>\d+</octave>'), '<octave>999999</octave>')),
  (name: 'octave -> text', apply: (s, r) => s.replaceFirst(RegExp(r'oct="\d+"'), 'oct="abc"').replaceFirst(RegExp(r'<octave>\d+</octave>'), '<octave>abc</octave>')),
  (name: 'octave -> empty', apply: (s, r) => s.replaceFirst(RegExp(r'<octave>\d+</octave>'), '<octave></octave>')),
  (name: 'step -> H', apply: (s, r) => s.replaceFirst('<step>C</step>', '<step>H</step>').replaceFirst('pname="c"', 'pname="h"')),
  (name: 'step -> lowercase', apply: (s, r) => s.replaceFirst('<step>C</step>', '<step>c</step>')),
  (name: 'step -> empty', apply: (s, r) => s.replaceFirst('<step>C</step>', '<step></step>').replaceFirst('pname="c"', 'pname=""')),
  (name: 'step -> symbol', apply: (s, r) => s.replaceFirst('<step>C</step>', '<step>@</step>').replaceFirst('pname="c"', 'pname="@"')),
  (name: 'duration -> negative', apply: (s, r) => s.replaceFirst(RegExp(r'<duration>\d+</duration>'), '<duration>-5</duration>')),
  (name: 'duration -> zero', apply: (s, r) => s.replaceFirst(RegExp(r'<duration>\d+</duration>'), '<duration>0</duration>')),
  (name: 'duration -> 1e9', apply: (s, r) => s.replaceFirst(RegExp(r'<duration>\d+</duration>'), '<duration>1000000000</duration>')),
  (name: 'divisions -> zero', apply: (s, r) => s.replaceFirst(RegExp(r'<divisions>\d+</divisions>'), '<divisions>0</divisions>')),
  (name: 'dur -> bogus', apply: (s, r) => s.replaceFirst('dur="4"', 'dur="bogus"').replaceFirst('<type>quarter</type>', '<type>bogus</type>')),
  (name: 'duplicate xml:id', apply: (s, r) => s.replaceAll('xml:id="n2"', 'xml:id="n1"')),
  (name: 'beam without end', apply: (s, r) => s.replaceFirst('<beam number="1">end</beam>', '<beam number="1">begin</beam>')),
  (name: 'drop the clef', apply: (s, r) => s.replaceFirst(RegExp(r'<clef>.*?</clef>', dotAll: true), '').replaceFirst(RegExp(r'clef\.shape="G" clef\.line="2"'), '')),
  (
    name: 'malformed nested tuplets',
    apply: (s, r) => s.replaceFirst(
      '<rest dur="4"/>',
      '<tuplet num="3" numbase="2"><tuplet num="5" numbase="4">'
      '<note pname="c" oct="5" dur="16"/></tuplet>',
    ),
  ),
  (name: 'time signature -> zero', apply: (s, r) => s.replaceFirst('<beats>4</beats>', '<beats>0</beats>').replaceFirst('meter.count="4"', 'meter.count="0"')),
  (name: 'fifths -> absurd', apply: (s, r) => s.replaceFirst('<fifths>2</fifths>', '<fifths>99</fifths>')),
  (name: 'unclosed tag', apply: (s, r) => s.replaceFirst('</measure>', '')),
  (name: 'stray ampersand', apply: (s, r) => s.replaceFirst('<part-name>Music</part-name>', '<part-name>M & M</part-name>')),
];

// --------------------------------------------------------------- contract ---

/// Exceptions a parser is ALLOWED to throw. Anything else — above all a
/// `TypeError` from a null-check — is a bug, not a rejection.
bool isDomainFailure(Object e) =>
    e is FormatException || e is ArgumentError || e is StateError;

String describe(Object e) => '${e.runtimeType}: $e';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  /// Runs the whole downstream pipeline over whatever the parser returned.
  void assertUsable(Staff staff, String label) {
    for (final measure in staff.measures) {
      for (final element in measure.allElements) {
        if (element is! Note) continue;
        expect(Pitch.isValidStep(element.pitch.step), isTrue,
            reason: '$label produced step "${element.pitch.step}"');
        expect(element.pitch.octave, inInclusiveRange(-1, 10),
            reason: '$label produced octave ${element.pitch.octave}');
      }
    }

    final engine = LayoutEngine(staff,
        availableWidth: 800, staffSpace: 12, metadata: metadata);
    final positioned = engine.layout();
    for (final p in positioned) {
      expect(p.position.dx.isFinite, isTrue, reason: '$label: non-finite x');
      expect(p.position.dy.isFinite, isTrue, reason: '$label: non-finite y');
      expect(p.onset.isFinite, isTrue, reason: '$label: non-finite onset');
    }

    final sequence = MidiMapper.fromStaff(staff);
    for (final track in sequence.tracks) {
      for (final event in track.events) {
        expect(event.tick, greaterThanOrEqualTo(0),
            reason: '$label: negative tick');
        final note = event.note;
        if (note != null) {
          expect(note, inInclusiveRange(0, 127),
              reason: '$label: MIDI note out of range');
        }
      }
    }
  }

  /// One fuzz case: parse, then either accept a domain failure or verify the
  /// result is fully usable. Never a crash, never a hang.
  void fuzzCase(String label, Staff Function() parse) {
    Staff? staff;
    try {
      staff = parse();
    } catch (e) {
      expect(isDomainFailure(e), isTrue,
          reason: '$label must fail with a domain exception, got ${describe(e)}');
      return;
    }
    assertUsable(staff, label);
  }

  group('MusicXML', () {
    for (final mutation in mutations) {
      test('survives: ${mutation.name}', () {
        final rnd = math.Random(1337);
        for (var i = 0; i < 3; i++) {
          final doc = mutation.apply(validMusicXml, rnd);
          fuzzCase('MusicXML/${mutation.name}#$i',
              () => MusicXMLParser.parseMusicXML(doc));
        }
      });
    }

    test('survives byte-level truncation', () {
      for (var cut = 1; cut < validMusicXml.length; cut += 37) {
        fuzzCase('truncate@$cut',
            () => MusicXMLParser.parseMusicXML(validMusicXml.substring(0, cut)));
      }
    });
  });

  group('MEI', () {
    for (final mutation in mutations) {
      test('survives: ${mutation.name}', () {
        final rnd = math.Random(4242);
        for (var i = 0; i < 3; i++) {
          final doc = mutation.apply(validMei, rnd);
          fuzzCase('MEI/${mutation.name}#$i', () => MEIParser.parseMEI(doc));
        }
      });
    }

    test('survives byte-level truncation', () {
      for (var cut = 1; cut < validMei.length; cut += 29) {
        fuzzCase('truncate@$cut',
            () => MEIParser.parseMEI(validMei.substring(0, cut)));
      }
    });
  });

  group('JSON', () {
    final jsonMutations = <String>[
      '',
      '{}',
      '[]',
      'null',
      'not json at all',
      '{"measures": null}',
      '{"measures": []}',
      '{"measures": [{"elements": null}]}',
      '{"measures": [{"elements": [{"pitch": {"step": "Q", "octave": "abc"}}]}]}',
      '{"measures": [{"elements": [{"pitch": {"step": "C", "octave": 1000000}, "duration": {"type": "quarter"}}]}]}',
      '{"measures": [{"elements": [{"pitch": {"step": "C", "octave": -50}, "duration": {"type": "quarter"}}]}]}',
      '{"measures": [{"elements": [{"pitch": {"step": "C", "octave": 4}, "duration": {"type": "zzz"}}]}]}',
      '{"measures": [{"elements": [{"unknownKind": 1}]}], "extraTopLevel": true}',
      '{"measures": [{"elements": [{"type": "tuplet", "actualNotes": 0, "normalNotes": 0, "elements": []}]}]}',
    ];

    for (var i = 0; i < jsonMutations.length; i++) {
      test('survives case $i', () {
        fuzzCase('JSON#$i', () => JsonMusicParser.parseStaff(jsonMutations[i]));
      });
    }
  });

  group('XML denial of service', () {
    test('deeply nested entities do not explode', () {
      final sb = StringBuffer()
        ..writeln('<?xml version="1.0"?>')
        ..writeln('<!DOCTYPE score [')
        ..writeln('<!ENTITY e0 "aaaaaaaaaa">');
      for (var i = 1; i <= 6; i++) {
        sb.writeln('<!ENTITY e$i "${List.filled(10, '&e${i - 1};').join()}">');
      }
      sb
        ..writeln(']>')
        ..writeln('<score-partwise version="4.0">'
            '<part-list><score-part id="P1"><part-name>&e6;</part-name>'
            '</score-part></part-list>'
            '<part id="P1"><measure number="1"/></part></score-partwise>');

      final sw = Stopwatch()..start();
      try {
        MusicXMLParser.extractMetadata(sb.toString());
      } catch (e) {
        expect(isDomainFailure(e) || e is Exception, isTrue);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'a billion-laughs document must not become a hang.');
    });

    test('an external entity reference resolves to nothing', () {
      const xxe = '<?xml version="1.0"?>'
          '<!DOCTYPE score [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>'
          '<score-partwise version="4.0">'
          '<part-list><score-part id="P1"><part-name>&xxe;</part-name>'
          '</score-part></part-list>'
          '<part id="P1"><measure number="1"/></part></score-partwise>';
      try {
        final meta = MusicXMLParser.extractMetadata(xxe);
        final title = '${meta['title']}';
        expect(title.contains('root:'), isFalse,
            reason: 'the parser must never inline an external file.');
      } catch (e) {
        expect(isDomainFailure(e) || e is Exception, isTrue);
      }
    });
  });

  group('round-trip under fuzzing', () {
    test('valid documents keep their notes through export and re-import', () {
      final sources = <String, Staff Function()>{
        'musicxml': () => MusicXMLParser.parseMusicXML(validMusicXml),
        'mei': () => MEIParser.parseMEI(validMei),
        'json': () => JsonMusicParser.parseStaff(validJson),
      };

      sources.forEach((label, parse) {
        final original = parse();
        final xml = MusicXMLParser.staffToMusicXML(original);
        final back = MusicXMLParser.parseMusicXML(xml);

        List<String> pitchesOf(Staff s) => [
              for (final m in s.measures)
                for (final e in m.allElements)
                  if (e is Note) '${e.pitch.step}${e.pitch.octave}'
                      '${e.pitch.effectiveAlter}',
            ];

        expect(pitchesOf(back), pitchesOf(original),
            reason: '$label lost or altered pitches on round-trip.');
      });
    });

    test('a mutated-but-accepted document still round-trips', () {
      final rnd = math.Random(99);
      for (final mutation in mutations) {
        final doc = mutation.apply(validMusicXml, rnd);
        Staff? staff;
        try {
          staff = MusicXMLParser.parseMusicXML(doc);
        } catch (_) {
          continue; // rejected: nothing to round-trip
        }
        try {
          final back =
              MusicXMLParser.parseMusicXML(MusicXMLParser.staffToMusicXML(staff));
          assertUsable(back, 'round-trip/${mutation.name}');
        } catch (e) {
          expect(isDomainFailure(e), isTrue,
              reason: 'round-trip of "${mutation.name}" threw ${describe(e)}');
        }
      }
    });
  });
}
