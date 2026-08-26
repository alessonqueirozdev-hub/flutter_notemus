// test/parsers/parser_remediation_2_7_1_test.dart
//
// Invariants for the 2.7.1 parser-layer remediation.
//
// Each group pins ONE measured defect from the forensic re-audit, with the
// measurement that motivated it quoted in the test name or in a comment, so a
// regression reads as a sentence rather than as a bare number.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Wraps [body] as the single measure of a one-part `score-partwise` document.
String _partwise(String body, {String parts = ''}) => '''<?xml version="1.0"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>$parts
  </part-list>
  <part id="P1"><measure number="1">$body</measure></part>
</score-partwise>''';

/// A `<note>` carrying a 3:2 `<time-modification>` and NO `<notations>`.
String _timeModifiedNote(String step, int duration, String type) =>
    '<note><pitch><step>$step</step><octave>4</octave></pitch>'
    '<duration>$duration</duration><type>$type</type>'
    '<time-modification><actual-notes>3</actual-notes>'
    '<normal-notes>2</normal-notes></time-modification></note>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M-03 <time-modification> opens the tuplet, not <notations><tuplet>',
      () {
    // divisions=6 -> a quarter is 6 ticks, a triplet quarter 4.
    const body = '<attributes><divisions>6</divisions>'
        '<time><beats>4</beats><beat-type>4</beat-type></time></attributes>'
        '${''}';

    String tripletBar() =>
        '$body${_timeModifiedNote('C', 4, 'quarter')}'
        '${_timeModifiedNote('D', 4, 'quarter')}'
        '${_timeModifiedNote('E', 4, 'quarter')}'
        '<note><pitch><step>F</step><octave>4</octave></pitch>'
        '<duration>12</duration><type>half</type></note>';

    test('three triplet quarters + a half measure 1.0, not 1.25', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(tripletBar()));
      final measure = staff.measures.single;

      // Measured before the fix: 1.25 (three FULL quarters + a half).
      expect(measure.currentMusicalValue, closeTo(1.0, 1e-9));
    });

    test('the three notes are grouped into one Tuplet(3:2)', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(tripletBar()));
      final tuplets = staff.measures.single.elements.whereType<Tuplet>();

      expect(tuplets, hasLength(1));
      expect(tuplets.single.actualNotes, 3);
      expect(tuplets.single.normalNotes, 2);
      expect(tuplets.single.elements, hasLength(3));
      // The half note stays outside the group.
      expect(staff.measures.single.elements.whereType<Note>(), hasLength(1));
    });

    test('MIDI emits 640 ticks per triplet quarter, not 960', () {
      final staff = MusicXMLParser.parseMusicXML(_partwise(tripletBar()));
      final sequence = MidiMapper.fromStaff(staff);
      final onsets = <int>[
        for (final track in sequence.tracks)
          for (final event in track.events)
            if (event.type == MidiEventType.noteOn) event.tick,
      ]..sort();

      expect(sequence.ticksPerQuarter, 960);
      // 0, 640, 1280 for the triplet; 1920 for the half that follows.
      expect(onsets, <int>[0, 640, 1280, 1920]);
    });

    test('two adjacent triplets with no <notations> stay two groups', () {
      // divisions=6, eighth = 3 ticks, triplet eighth = 2.
      final bar = '<attributes><divisions>6</divisions>'
          '<time><beats>2</beats><beat-type>4</beat-type></time></attributes>'
          '${_timeModifiedNote('C', 2, 'eighth')}'
          '${_timeModifiedNote('D', 2, 'eighth')}'
          '${_timeModifiedNote('E', 2, 'eighth')}'
          '${_timeModifiedNote('F', 2, 'eighth')}'
          '${_timeModifiedNote('G', 2, 'eighth')}'
          '${_timeModifiedNote('A', 2, 'eighth')}';
      final staff = MusicXMLParser.parseMusicXML(_partwise(bar));
      final tuplets =
          staff.measures.single.elements.whereType<Tuplet>().toList();

      // Grouping "consecutive notes that share the ratio" alone would give ONE
      // six-note triplet; the ratio's own arithmetic closes each group at 3/8.
      expect(tuplets, hasLength(2));
      expect(tuplets[0].elements, hasLength(3));
      expect(tuplets[1].elements, hasLength(3));
      expect(staff.measures.single.currentMusicalValue, closeTo(0.5, 1e-9));
    });

    test('a 1:1 <time-modification> does not open a tuplet', () {
      final bar = '<attributes><divisions>4</divisions></attributes>'
          '<note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>4</duration><type>quarter</type>'
          '<time-modification><actual-notes>2</actual-notes>'
          '<normal-notes>2</normal-notes></time-modification></note>';
      final staff = MusicXMLParser.parseMusicXML(_partwise(bar));

      expect(staff.measures.single.elements.whereType<Tuplet>(), isEmpty);
    });

    test('<notations><tuplet> still supplies bracket/number display', () {
      final bar = '<attributes><divisions>6</divisions></attributes>'
          '<note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>4</duration><type>quarter</type>'
          '<time-modification><actual-notes>3</actual-notes>'
          '<normal-notes>2</normal-notes></time-modification>'
          '<notations><tuplet type="start" number="1" bracket="no"'
          ' show-number="both"/></notations></note>'
          '${_timeModifiedNote('D', 4, 'quarter')}'
          '<note><pitch><step>E</step><octave>4</octave></pitch>'
          '<duration>4</duration><type>quarter</type>'
          '<time-modification><actual-notes>3</actual-notes>'
          '<normal-notes>2</normal-notes></time-modification>'
          '<notations><tuplet type="stop" number="1"/></notations></note>';
      final tuplet =
          MusicXMLParser.parseMusicXML(_partwise(bar))
              .measures
              .single
              .elements
              .whereType<Tuplet>()
              .single;

      expect(tuplet.elements, hasLength(3));
      expect(tuplet.bracketConfig?.show, isFalse);
      expect(tuplet.numberConfig?.showAsRatio, isTrue);
    });
  });

  group('M-02 a tuplet survives a MusicXML round trip', () {
    /// A bar with a tuplet, a dotted chord and a tie pair — the four features
    /// the invariant names.
    ///
    /// The chord's INNER notes deliberately carry a plain eighth while
    /// [Chord.duration] is a dotted quarter. Until 2.7.2 the exporter wrote the
    /// inner note's duration and never looked at [Chord.duration], and this
    /// fixture used to hide that: it gave the inner notes the same dotted
    /// quarter as the chord, so the two agreed by accident and the invariant
    /// below passed while the defect was live. With the values split, the bar
    /// measured 1.0 -> 0.75 before the fix (the chord shed 0.375 - 0.125) and
    /// 1.0 -> 1.0 after it.
    Staff sourceStaff() {
      final staff = Staff(name: 'Piano', abbreviation: 'Pno.');
      final measure = Measure();
      measure.elements.addAll(<MusicalElement>[
        Clef(clefType: ClefType.treble),
        KeySignature(-3),
        TimeSignature(numerator: 4, denominator: 4),
        Tuplet(actualNotes: 3, normalNotes: 2, elements: <MusicalElement>[
          Note(
              pitch: Pitch(step: 'C', octave: 4),
              duration: Duration(DurationType.eighth)),
          Note(
              pitch: Pitch(step: 'D', octave: 4),
              duration: Duration(DurationType.eighth)),
          Note(
              pitch: Pitch(step: 'E', octave: 4),
              duration: Duration(DurationType.eighth)),
        ]),
        Chord(
          notes: <Note>[
            Note(
                pitch: Pitch(step: 'C', octave: 4),
                duration: Duration(DurationType.eighth)),
            Note(
                pitch: Pitch(step: 'E', octave: 4),
                duration: Duration(DurationType.eighth)),
          ],
          duration: Duration(DurationType.quarter, dots: 1),
        ),
        Note(
            pitch: Pitch(step: 'G', octave: 4),
            duration: Duration(DurationType.eighth),
            tie: TieType.start),
        Note(
            pitch: Pitch(step: 'G', octave: 4),
            duration: Duration(DurationType.quarter),
            tie: TieType.end),
      ]);
      staff.add(measure);
      return staff;
    }

    test('the exporter writes <notations><tuplet> start and stop', () {
      final xml = MusicXMLParser.staffToMusicXML(sourceStaff());

      // Measured before the fix: three <time-modification> blocks and ZERO
      // <tuplet> elements.
      expect(RegExp(r'<tuplet\b[^>]*type="start"').allMatches(xml), hasLength(1));
      expect(RegExp(r'<tuplet\b[^>]*type="stop"').allMatches(xml), hasLength(1));
      expect(xml, contains('time-modification'));
    });

    test(
        'INVARIANT parse(staffToMusicXML(s)).currentMusicalValue == '
        's.currentMusicalValue', () {
      final staff = sourceStaff();
      final back =
          MusicXMLParser.parseMusicXML(MusicXMLParser.staffToMusicXML(staff));

      for (var i = 0; i < staff.measures.length; i++) {
        expect(
          back.measures[i].currentMusicalValue,
          closeTo(staff.measures[i].currentMusicalValue, 1e-9),
          reason: 'measure ${i + 1} changed value across the round trip',
        );
      }
      // Measured before the fix: 0.5 -> 0.625 and four loose notes.
      expect(back.measures.single.elements.whereType<Tuplet>(), hasLength(1));
    });

    test(
        'INVARIANT the bar value survives the round trip for every rhythmic '
        'shape the model can build', () {
      // One fixture proves nothing about a shape it does not contain: the
      // dotted-chord defect (F1) sat under the single-bar invariant above for
      // two releases because that bar happened to give the chord's inner notes
      // the chord's own duration. This is the property-style version — one bar
      // per rhythmic shape, each asserted independently so a failure names the
      // shape rather than "the fixture".
      Measure bar(List<MusicalElement> elements) =>
          Measure()..elements.addAll(elements);

      Note n(String step, Duration d, {TieType? tie}) => Note(
          pitch: Pitch(step: step, octave: 4), duration: d, tie: tie);

      final shapes = <String, Measure>{
        'plain quarters': bar(<MusicalElement>[
          TimeSignature(numerator: 4, denominator: 4),
          for (final step in ['C', 'D', 'E', 'F'])
            n(step, Duration(DurationType.quarter)),
        ]),
        'dotted and double-dotted notes': bar(<MusicalElement>[
          TimeSignature(numerator: 4, denominator: 4),
          n('C', Duration(DurationType.half, dots: 1)),
          n('D', Duration(DurationType.quarter, dots: 1)),
          n('E', Duration(DurationType.eighth)),
        ]),
        'rests of every dotting': bar(<MusicalElement>[
          TimeSignature(numerator: 4, denominator: 4),
          Rest(duration: Duration(DurationType.half, dots: 1)),
          Rest(duration: Duration(DurationType.quarter)),
          Rest(duration: Duration(DurationType.eighth)),
          Rest(duration: Duration(DurationType.eighth)),
        ]),
        'a tie pair': bar(<MusicalElement>[
          TimeSignature(numerator: 2, denominator: 4),
          n('G', Duration(DurationType.quarter), tie: TieType.start),
          n('G', Duration(DurationType.quarter), tie: TieType.end),
        ]),
        // F1: Chord.duration is the rhythmic authority and the inner notes
        // disagree with it on purpose. Measured before the fix: 0.375 -> 0.25.
        'a dotted chord over undotted inner notes': bar(<MusicalElement>[
          TimeSignature(numerator: 4, denominator: 4),
          Chord(notes: <Note>[
            n('C', Duration(DurationType.quarter)),
            n('E', Duration(DurationType.quarter)),
          ], duration: Duration(DurationType.quarter, dots: 1)),
          Rest(duration: Duration(DurationType.eighth)),
          n('G', Duration(DurationType.half)),
        ]),
        // Measured before the fix: 0.875 -> 0.5.
        'a double-dotted chord': bar(<MusicalElement>[
          TimeSignature(numerator: 4, denominator: 4),
          Chord(notes: <Note>[
            n('C', Duration(DurationType.half)),
            n('G', Duration(DurationType.half)),
          ], duration: Duration(DurationType.half, dots: 2)),
          n('A', Duration(DurationType.eighth)),
        ]),
        'a triplet': bar(<MusicalElement>[
          TimeSignature(numerator: 2, denominator: 4),
          Tuplet(actualNotes: 3, normalNotes: 2, elements: <MusicalElement>[
            for (final step in ['C', 'D', 'E'])
              n(step, Duration(DurationType.eighth)),
          ]),
          n('F', Duration(DurationType.quarter)),
        ]),
        'a tuplet holding a chord and a rest': bar(<MusicalElement>[
          TimeSignature(numerator: 4, denominator: 4),
          Tuplet(actualNotes: 3, normalNotes: 2, elements: <MusicalElement>[
            Chord(notes: <Note>[
              n('C', Duration(DurationType.sixteenth)),
              n('E', Duration(DurationType.sixteenth)),
            ], duration: Duration(DurationType.quarter)),
            n('D', Duration(DurationType.quarter)),
            Rest(duration: Duration(DurationType.quarter)),
          ]),
          n('B', Duration(DurationType.half)),
        ]),
        // Nested tuplets flatten to the PRODUCT ratio on export (see
        // `_buildTupletXml`): the structure comes back as two sibling groups,
        // but the value is exact. Measured before that recursion existed, the
        // inner group was dropped outright and the bar went 0.5 -> 0.3333.
        'a nested tuplet': bar(<MusicalElement>[
          TimeSignature(numerator: 4, denominator: 4),
          Tuplet(actualNotes: 3, normalNotes: 2, elements: <MusicalElement>[
            n('C', Duration(DurationType.quarter)),
            n('D', Duration(DurationType.quarter)),
            Tuplet(actualNotes: 3, normalNotes: 2, elements: <MusicalElement>[
              for (final step in ['E', 'F', 'G'])
                n(step, Duration(DurationType.eighth)),
            ]),
          ]),
          n('A', Duration(DurationType.half)),
        ]),
      };

      shapes.forEach((name, measure) {
        final staff = Staff(name: 'Piano', abbreviation: 'Pno.')..add(measure);
        final back =
            MusicXMLParser.parseMusicXML(MusicXMLParser.staffToMusicXML(staff));
        expect(
          back.measures.single.currentMusicalValue,
          closeTo(measure.currentMusicalValue, 1e-9),
          reason: '"$name" changed value across the MusicXML round trip',
        );
      });
    });

    test('the exporter writes <dot/> from Chord.duration, not from its notes',
        () {
      // F1, at the XML level. Measured before the fix, this chord exported
      // `<duration>480</duration>` twice, `<type>quarter</type>` twice and ZERO
      // `<dot/>`; the dotted half of the value was simply not in the file.
      final staff = Staff(name: 'Piano', abbreviation: 'Pno.')
        ..add(Measure()
          ..elements.addAll(<MusicalElement>[
            TimeSignature(numerator: 4, denominator: 4),
            Chord(notes: <Note>[
              Note(
                  pitch: Pitch(step: 'C', octave: 4),
                  duration: Duration(DurationType.quarter)),
              Note(
                  pitch: Pitch(step: 'E', octave: 4),
                  duration: Duration(DurationType.quarter)),
            ], duration: Duration(DurationType.quarter, dots: 1)),
          ]));
      final xml = MusicXMLParser.staffToMusicXML(staff);

      // <divisions>480, so a dotted quarter is 720 ticks — one per chord tone.
      expect(
        RegExp(r'<duration>720</duration>').allMatches(xml),
        hasLength(2),
        reason: 'both chord tones must carry Chord.duration in ticks',
      );
      expect(RegExp(r'<duration>480</duration>').allMatches(xml), isEmpty);
      // One <dot/> per tone: MusicXML has no chord-level <dot>.
      expect(RegExp(r'<dot\s*/>').allMatches(xml), hasLength(2));
    });

    test('a rest-only tuplet round-trips as a Tuplet too', () {
      final staff = Staff();
      final measure = Measure();
      measure.elements.addAll(<MusicalElement>[
        TimeSignature(numerator: 2, denominator: 4),
        Tuplet(actualNotes: 3, normalNotes: 2, elements: <MusicalElement>[
          Rest(duration: Duration(DurationType.eighth)),
          Rest(duration: Duration(DurationType.eighth)),
          Rest(duration: Duration(DurationType.eighth)),
        ]),
      ]);
      staff.add(measure);
      final xml = MusicXMLParser.staffToMusicXML(staff);
      final back = MusicXMLParser.parseMusicXML(xml);

      expect(xml, contains('type="start"'));
      expect(back.measures.single.elements.whereType<Tuplet>(), hasLength(1));
      expect(
        back.measures.single.currentMusicalValue,
        closeTo(measure.currentMusicalValue, 1e-9),
      );
    });
  });

  group('M-06 MEI never drops a malformed note in silence', () {
    String mei(String layerBody) => '''<?xml version="1.0"?>
<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv><score>
  <scoreDef><staffGrp>
    <staffDef n="1" lines="5" clef.shape="G" clef.line="2"/>
  </staffGrp></scoreDef>
  <section><measure n="1"><staff n="1"><layer n="1">$layerBody</layer></staff></measure></section>
</score></mdiv></body></music></mei>''';

    test('a CMN <note> with no @oct throws FormatException', () {
      // Measured before the fix: a measure with n=0 notes, no exception and no
      // warning, while the MusicXML equivalent threw.
      expect(
        () => MEIParser.parseMEI(mei('<note pname="c" dur="4"/>')),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('@oct'), contains('MEI <note>')),
        )),
      );
    });

    test('a CMN <note> with no @pname throws FormatException', () {
      expect(
        () => MEIParser.parseMEI(mei('<note oct="4" dur="4"/>')),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('@pname'))),
      );
    });

    test('a tablature-only note is tolerated but warned about', () {
      final warnings = <String>[];
      final staff = MEIParser.parseMEI(
        mei('<note tab.fret="3" tab.string="2" dur="4"/>'),
        warnings: warnings,
      );

      expect(staff.measures.single.elements.whereType<Note>(), isEmpty);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('tab.fret'));
    });

    test('a well-formed note still imports', () {
      final warnings = <String>[];
      final staff = MEIParser.parseMEI(
        mei('<note pname="c" oct="4" dur="4"/>'),
        warnings: warnings,
      );

      expect(staff.measures.single.elements.whereType<Note>(), hasLength(1));
      expect(warnings, isEmpty);
    });
  });

  group('M-29 malformed MusicXML is accepted but reported', () {
    /// Imports [body] and returns the warnings it produced.
    ({Staff staff, List<String> warnings}) importWith(String body) {
      final warnings = <String>[];
      final staff =
          MusicXMLParser.parseMusicXML(_partwise(body), warnings: warnings);
      return (staff: staff, warnings: warnings);
    }

    const quarterNote = '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>4</duration></note>';

    test('a well-formed bar produces no warnings at all', () {
      final result = importWith(
        '<attributes><divisions>4</divisions>'
        '<time><beats>1</beats><beat-type>4</beat-type></time></attributes>'
        '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>4</duration><type>quarter</type></note>',
      );

      expect(result.warnings, isEmpty);
    });

    test('<divisions>0</divisions> still imports but is reported', () {
      final result =
          importWith('<attributes><divisions>0</divisions></attributes>'
              '$quarterNote');

      // Fail-soft is deliberately unchanged: the quarter still becomes a whole
      // note because divisions falls back to 1. Only the silence is fixed.
      expect(result.staff.measures.single.currentMusicalValue, 1.0);
      expect(
        result.warnings.any((w) => w.contains('<divisions>')),
        isTrue,
        reason: 'divisions=0 must be reported',
      );
    });

    test('garbage <divisions> is reported', () {
      final result =
          importWith('<attributes><divisions>abc</divisions></attributes>'
              '$quarterNote');

      expect(result.warnings.any((w) => w.contains('abc')), isTrue);
    });

    test('a part that never declares <divisions> is reported', () {
      final result = importWith(
          '<attributes><key><fifths>0</fifths></key></attributes>$quarterNote');

      expect(
        result.warnings.any((w) => w.contains('never declared <divisions>')),
        isTrue,
      );
    });

    test('<duration> of -16, "abc" and missing are each reported', () {
      const attributes = '<attributes><divisions>4</divisions></attributes>';
      for (final duration in <String>[
        '<duration>-16</duration>',
        '<duration>abc</duration>',
        '',
      ]) {
        final result = importWith(
          '$attributes<note><pitch><step>C</step><octave>4</octave></pitch>'
          '$duration</note>',
        );
        // Unchanged fail-soft result: all three still become a quarter note.
        expect(result.staff.measures.single.currentMusicalValue, 0.25);
        expect(
          result.warnings.any((w) => w.contains('<duration>')),
          isTrue,
          reason: 'duration "$duration" must be reported',
        );
      }
    });

    test('a <backup> reaching before the barline is reported', () {
      // Measured before the fix: byte-for-byte identical to a legal backup
      // (audit case B03 == B04), so the corruption was undetectable.
      final result = importWith(
        '<attributes><divisions>4</divisions>'
        '<time><beats>4</beats><beat-type>4</beat-type></time></attributes>'
        '<backup><duration>9999</duration></backup>'
        '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>16</duration><type>whole</type></note>',
      );

      expect(
        result.warnings.any((w) => w.contains('<backup>')),
        isTrue,
      );
    });

    test('a <forward> longer than the bar is reported', () {
      final result = importWith(
        '<attributes><divisions>4</divisions>'
        '<time><beats>4</beats><beat-type>4</beat-type></time></attributes>'
        '<forward><duration>400</duration></forward>'
        '<note><pitch><step>C</step><octave>4</octave></pitch>'
        '<duration>16</duration><type>whole</type></note>',
      );

      expect(result.warnings.any((w) => w.contains('<forward>')), isTrue);
    });

    test('a <note> with neither <pitch> nor <rest> is reported', () {
      final result = importWith(
        '<attributes><divisions>4</divisions>'
        '<time><beats>4</beats><beat-type>4</beat-type></time></attributes>'
        '<note><duration>16</duration><type>whole</type></note>',
      );

      expect(result.staff.measures.single.elements.whereType<Note>(), isEmpty);
      expect(
        result.warnings.any((w) => w.contains('neither <pitch>')),
        isTrue,
      );
    });

    test('a bar whose model value disagrees with its <duration>s is reported',
        () {
      final result = importWith(
        '<attributes><divisions>4</divisions>'
        '<time><beats>4</beats><beat-type>4</beat-type></time></attributes>'
        '<note><duration>16</duration><type>whole</type></note>',
      );

      expect(
        result.warnings.any((w) => w.contains('add up to')),
        isTrue,
        reason: 'the sum(<duration>)/divisions/4 cross-check must fire',
      );
    });

    test('warnings are append-only across a batch', () {
      final warnings = <String>[];
      MusicXMLParser.parseMusicXML(
        _partwise('<attributes><divisions>0</divisions></attributes>'
            '$quarterNote'),
        warnings: warnings,
      );
      final afterFirst = warnings.length;
      MusicXMLParser.parseMusicXML(
        _partwise('<attributes><divisions>0</divisions></attributes>'
            '$quarterNote'),
        warnings: warnings,
      );

      expect(warnings.length, greaterThan(afterFirst));
    });
  });

  group('M-21/M-20 the JSON round trip', () {
    Staff sourceStaff() {
      final staff = Staff(
        name: 'Violin I',
        abbreviation: 'Vln. I',
        lineCount: 4,
        transposition: const Transposition(diatonic: -1, chromatic: -2),
      );
      final measure = MultiVoiceMeasure.twoVoices(
        voice1Elements: <MusicalElement>[
          Note(
              pitch: Pitch(step: 'C', octave: 5),
              duration: Duration(DurationType.quarter)),
        ],
        voice2Elements: <MusicalElement>[
          Note(
              pitch: Pitch(step: 'E', octave: 3),
              duration: Duration(DurationType.quarter)),
        ],
      );
      measure.elements.addAll(<MusicalElement>[
        Clef(clefType: ClefType.treble),
        KeySignature(-3),
        TimeSignature(numerator: 4, denominator: 4),
      ]);
      staff.add(measure);
      return staff;
    }

    test('M-20 preserves name, abbreviation, lineCount and transposition', () {
      final staff = sourceStaff();
      final back = JsonMusicParser.parseStaff(JsonMusicParser.staffToJson(staff));

      // Measured before the fix: all four came back null / 5.
      expect(back.name, 'Violin I');
      expect(back.abbreviation, 'Vln. I');
      expect(back.lineCount, 4);
      expect(back.transposition, staff.transposition);
    });

    test('M-21 does not duplicate the opening block into voice 1', () {
      final back =
          JsonMusicParser.parseStaff(JsonMusicParser.staffToJson(sourceStaff()))
              .measures
              .single as MultiVoiceMeasure;

      // Measured before the fix: measure.elements = [Clef, Key, Time] AND
      // voice1 = [Clef, Key, Time, Note, ...], so the layout drew two clefs,
      // two key signatures and two time signatures.
      expect(back.elements.whereType<Clef>(), hasLength(1));
      expect(back.elements.whereType<KeySignature>(), hasLength(1));
      expect(back.elements.whereType<TimeSignature>(), hasLength(1));
      for (final voice in back.voices) {
        expect(voice.elements.whereType<Clef>(), isEmpty);
        expect(voice.elements.whereType<KeySignature>(), isEmpty);
        expect(voice.elements.whereType<TimeSignature>(), isEmpty);
      }
    });

    test('the opening block keeps its element count', () {
      final staff = sourceStaff();
      final back =
          JsonMusicParser.parseStaff(JsonMusicParser.staffToJson(staff));

      expect(
        back.measures.single.elements.length,
        staff.measures.single.elements.length,
      );
    });

    test('a single-voice measure is unaffected', () {
      final staff = Staff();
      final measure = Measure();
      measure.elements.addAll(<MusicalElement>[
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        Note(
            pitch: Pitch(step: 'C', octave: 4),
            duration: Duration(DurationType.whole)),
      ]);
      staff.add(measure);
      final back =
          JsonMusicParser.parseStaff(JsonMusicParser.staffToJson(staff));

      expect(back.measures.single.elements, hasLength(3));
      expect(back.measures.single.currentMusicalValue,
          closeTo(measure.currentMusicalValue, 1e-9));
    });
  });

  group('M-25 score-level metadata', () {
    test('scoreToMusicXML emits <group-abbreviation>', () {
      final score = Score(staffGroups: <StaffGroup>[
        StaffGroup(
          staves: <Staff>[Staff(name: 'A'), Staff(name: 'B')],
          bracket: BracketType.bracket,
          name: 'Strings',
          abbreviation: 'Str.',
        ),
      ]);

      final xml = MusicXMLParser.scoreToMusicXML(score);
      expect(xml, contains('<group-abbreviation>Str.</group-abbreviation>'));

      final back = MusicXMLParser.scoreFromMusicXML(xml);
      expect(back.staffGroups.single.abbreviation, 'Str.');
    });

    test('BracketType.none survives instead of becoming a bracket', () {
      final score = Score(staffGroups: <StaffGroup>[
        StaffGroup(
          staves: <Staff>[Staff(name: 'A'), Staff(name: 'B')],
          bracket: BracketType.none,
          name: 'Loose',
        ),
      ]);

      final xml = MusicXMLParser.scoreToMusicXML(score);
      expect(xml, contains('<group-symbol>none</group-symbol>'));

      final back = MusicXMLParser.scoreFromMusicXML(xml).staffGroups.single;
      // Measured before the fix: BracketType.bracket, and connectBarlines
      // flipped false -> true, so a bracket was drawn where none was asked for.
      expect(back.bracket, BracketType.none);
      expect(back.connectBarlines, isFalse);
    });

    test('connectBarlines round-trips independently of the bracket', () {
      final score = Score(staffGroups: <StaffGroup>[
        StaffGroup(
          staves: <Staff>[Staff(name: 'A'), Staff(name: 'B')],
          bracket: BracketType.bracket,
          connectBarlines: false,
        ),
      ]);

      final back = MusicXMLParser.scoreFromMusicXML(
        MusicXMLParser.scoreToMusicXML(score),
      ).staffGroups.single;

      expect(back.bracket, BracketType.bracket);
      expect(back.connectBarlines, isFalse);
    });

    test('score-timewise reads <part-list> for part names', () {
      const xml = '''<?xml version="1.0"?>
<score-timewise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Flute</part-name>
      <part-abbreviation>Fl.</part-abbreviation></score-part>
    <score-part id="P2"><part-name>Oboe</part-name>
      <part-abbreviation>Ob.</part-abbreviation></score-part>
  </part-list>
  <measure number="1">
    <part id="P1"><attributes><divisions>1</divisions></attributes>
      <note><pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><type>whole</type></note></part>
    <part id="P2"><attributes><divisions>1</divisions></attributes>
      <note><pitch><step>E</step><octave>4</octave></pitch>
        <duration>4</duration><type>whole</type></note></part>
  </measure>
</score-timewise>''';

      final staves = MusicXMLParser.scoreFromMusicXML(xml).allStaves.toList();

      // Measured before the fix: both came back name = abbreviation = null.
      expect(staves.map((s) => s.name), <String>['Flute', 'Oboe']);
      expect(staves.map((s) => s.abbreviation), <String>['Fl.', 'Ob.']);
    });

    test('MEI <staffGrp><label>/<labelAbbr> name the group', () {
      const mei = '''<?xml version="1.0"?>
<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv><score>
  <scoreDef><staffGrp symbol="brace">
    <label>Piano</label><labelAbbr>Pno.</labelAbbr>
    <staffDef n="1" lines="5" clef.shape="G" clef.line="2"/>
    <staffDef n="2" lines="5" clef.shape="F" clef.line="4"/>
  </staffGrp></scoreDef>
  <section><measure n="1">
    <staff n="1"><layer n="1"><note pname="c" oct="4" dur="4"/></layer></staff>
    <staff n="2"><layer n="1"><note pname="c" oct="3" dur="4"/></layer></staff>
  </measure></section>
</score></mdiv></body></music></mei>''';

      final group = MEIParser.scoreFromMei(mei).staffGroups.single;

      // Measured before the fix: name = null and abbreviation = null.
      expect(group.name, 'Piano');
      expect(group.abbreviation, 'Pno.');
      expect(group.bracket, BracketType.brace);
    });
  });

  group('M-18/M-19 MEI <staffDef> attributes ADR-003 depends on', () {
    String mei(String staffDefAttributes) => '''<?xml version="1.0"?>
<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv><score>
  <scoreDef><staffGrp>
    <staffDef n="1" lines="5" $staffDefAttributes/>
  </staffGrp></scoreDef>
  <section><measure n="1"><staff n="1"><layer n="1">
    <note pname="c" oct="4" dur="4"/>
  </layer></staff></measure></section>
</score></mdiv></body></music></mei>''';

    test('clef.dis=8 + clef.dis.place=below is a treble-8vb clef', () {
      final staff = MEIParser.parseMEI(
        mei('clef.shape="G" clef.line="2" clef.dis="8" clef.dis.place="below"'),
      );
      final clef = staff.measures.single.elements.whereType<Clef>().single;

      // Measured before the fix: ClefType.treble (octaveShift 0), so the staff
      // printed an octave wrong.
      expect(clef.clefType, ClefType.treble8vb);
    });

    test('clef.dis=8 + clef.dis.place=above is a treble-8va clef', () {
      final staff = MEIParser.parseMEI(
        mei('clef.shape="G" clef.line="2" clef.dis="8" clef.dis.place="above"'),
      );

      expect(
        staff.measures.single.elements.whereType<Clef>().single.clefType,
        ClefType.treble8va,
      );
    });

    test('clef.dis=15 below is a treble-15mb clef', () {
      final staff = MEIParser.parseMEI(
        mei('clef.shape="G" clef.line="2" clef.dis="15"'
            ' clef.dis.place="below"'),
      );

      expect(
        staff.measures.single.elements.whereType<Clef>().single.clefType,
        ClefType.treble15mb,
      );
    });

    test('the attribute form agrees with the <clef> element form', () {
      const meiElementForm = '''<?xml version="1.0"?>
<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv><score>
  <scoreDef><staffGrp><staffDef n="1" lines="5">
    <clef shape="G" line="2" dis="8" dis.place="below"/>
  </staffDef></staffGrp></scoreDef>
  <section><measure n="1"><staff n="1"><layer n="1">
    <note pname="c" oct="4" dur="4"/>
  </layer></staff></measure></section>
</score></mdiv></body></music></mei>''';

      final fromAttributes = MEIParser.parseMEI(
        mei('clef.shape="G" clef.line="2" clef.dis="8" clef.dis.place="below"'),
      ).measures.single.elements.whereType<Clef>().single;
      final fromElement = MEIParser.parseMEI(meiElementForm)
          .measures
          .single
          .elements
          .whereType<Clef>()
          .single;

      expect(fromAttributes.clefType, fromElement.clefType);
    });

    test('trans.semi/trans.diat become Staff.transposition', () {
      final staff = MEIParser.parseMEI(
        mei('clef.shape="G" clef.line="2" trans.semi="-2" trans.diat="-1"'),
      );

      // Measured before the fix: staff.transposition = null, so MIDI played 60
      // where a B-flat instrument must sound 58.
      expect(staff.transposition, isNotNull);
      expect(staff.transposition!.diatonic, -1);
      expect(staff.transposition!.chromatic, -2);
      expect(staff.transposition!.semitones, -2);
    });

    test('a concert-pitch declaration stays null', () {
      final staff = MEIParser.parseMEI(
        mei('clef.shape="G" clef.line="2" trans.semi="0" trans.diat="0"'),
      );

      expect(staff.transposition, isNull);
    });
  });

  group('doubledAbove', () {
    String transposeXml(String doubleElement) => _partwise(
          '<attributes><divisions>1</divisions>'
          '<transpose><diatonic>-1</diatonic><chromatic>-2</chromatic>'
          '$doubleElement</transpose></attributes>'
          '<note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>4</duration><type>whole</type></note>',
        );

    test('<double above="yes"/> sets Transposition.doubledAbove', () {
      final staff =
          MusicXMLParser.parseMusicXML(transposeXml('<double above="yes"/>'));

      // Measured before the fix: doubledAbove false and semitones -14, a
      // 24-semitone error against the +10 the file declares.
      expect(staff.transposition!.doubled, isTrue);
      expect(staff.transposition!.doubledAbove, isTrue);
      expect(staff.transposition!.semitones, 10);
    });

    test('a bare <double/> still means an octave down', () {
      final staff = MusicXMLParser.parseMusicXML(transposeXml('<double/>'));

      expect(staff.transposition!.doubled, isTrue);
      expect(staff.transposition!.doubledAbove, isFalse);
      expect(staff.transposition!.semitones, -14);
    });

    test('above="yes" survives the MusicXML round trip', () {
      final staff = Staff(
        transposition: const Transposition(
          diatonic: -1,
          chromatic: -2,
          doubled: true,
          doubledAbove: true,
        ),
      );
      final measure = Measure();
      measure.elements.add(Note(
          pitch: Pitch(step: 'C', octave: 4),
          duration: Duration(DurationType.whole)));
      staff.add(measure);

      final xml = MusicXMLParser.staffToMusicXML(staff);
      expect(xml, contains('above="yes"'));
      expect(
        MusicXMLParser.parseMusicXML(xml).transposition,
        staff.transposition,
      );
    });

    test('doubledAbove survives the JSON round trip', () {
      final staff = Staff(
        transposition: const Transposition(
          diatonic: -1,
          chromatic: -2,
          doubled: true,
          doubledAbove: true,
        ),
      );

      expect(
        JsonMusicParser.parseStaff(JsonMusicParser.staffToJson(staff))
            .transposition,
        staff.transposition,
      );
    });
  });
}
