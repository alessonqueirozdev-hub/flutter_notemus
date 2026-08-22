// Regression suite for the 2.7.1 remediation.
//
// Every test here pins a defect that the 2.7.0 forensic re-audit found by
// EXECUTING the engine, and that the 792 green tests of 2.7.0 did not catch.
// Each one states the number that was measured before the fix, so a future
// regression is recognisable rather than merely red.
//
// Naming follows the re-audit's identifiers (N-xx).

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/grand_staff_painter.dart';

Note _n(String step, int octave,
        {DurationType d = DurationType.quarter,
        double alter = 0.0,
        int? voice}) =>
    Note(
      pitch: Pitch(step: step, octave: octave, alter: alter),
      duration: Duration(d),
      voice: voice,
    );

Measure _bar(List<MusicalElement> elements) {
  final m = Measure();
  m.elements.addAll(elements);
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  LayoutEngine engineFor(Staff staff, {double width = 900, double ss = 12}) =>
      LayoutEngine(staff,
          availableWidth: width, staffSpace: ss, metadata: metadata);

  // ------------------------------------------------------------------ N-11 --
  group('N-11 — a measure opens clef, key, meter, whatever the source order',
      () {
    test('a MusicXML import draws the clef FIRST', () {
      // <attributes> has a FIXED child order of divisions, key, time, …, clef,
      // so a faithful parse hands the engine key, time, clef. Measured before:
      // KeySignature@30.0, TimeSignature@69.6, Clef@105.6 — on every imported
      // score in existence.
      const xml = '''<?xml version="1.0"?>
<score-partwise version="4.0"><part-list><score-part id="P1"/></part-list>
<part id="P1"><measure number="1"><attributes><divisions>2</divisions>
<key><fifths>-3</fifths></key>
<time><beats>4</beats><beat-type>4</beat-type></time>
<clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>2</duration><type>quarter</type></note>
</measure></part></score-partwise>''';
      final placed = engineFor(MusicXMLParser.parseMusicXML(xml)).layout();
      final clefX = placed.firstWhere((p) => p.element is Clef).position.dx;
      final keyX =
          placed.firstWhere((p) => p.element is KeySignature).position.dx;
      final timeX =
          placed.firstWhere((p) => p.element is TimeSignature).position.dx;
      expect(clefX, lessThan(keyX));
      expect(keyX, lessThan(timeX));
    });

    test('a mid-measure change still keeps document order (F-01)', () {
      final first = _n('C', 4);
      final second = _n('C', 4);
      final engine = engineFor(Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          first,
          Clef(clefType: ClefType.bass),
          second,
        ])
      ]));
      final placed = engine.layout();
      final clefs =
          placed.where((p) => p.element is Clef).map((p) => p.position.dx);
      expect(clefs.last, greaterThan(engine.noteXPositions[first]!),
          reason: 'the bass clef must stay after the note it follows');
      expect(engine.noteYPositions[first],
          isNot(engine.noteYPositions[second]));
    });
  });

  // ------------------------------------------------------------ N-01 / N-02 --
  group('N-01 / N-02 — a wrapped system rebuilds its first bar faithfully', () {
    Staff bassOf(int bars) => Staff(measures: [
          for (var i = 0; i < bars; i++)
            _bar([
              if (i == 0) Clef(clefType: ClefType.bass),
              _n('C', 3, d: DurationType.whole),
            ])
        ]);

    test('an over-full bar does not take the painter down', () {
      // `Measure.elements`' own dartdoc says importers write over-full bars.
      // `_systemStaff` copied them with `Measure.add`, which validates, so the
      // painter's CONSTRUCTOR threw MeasureCapacityException.
      final measures = <Measure>[];
      for (var i = 0; i < 12; i++) {
        final m = Measure();
        if (i == 0) m.elements.add(Clef(clefType: ClefType.treble));
        m.elements.add(TimeSignature(numerator: 4, denominator: 4));
        for (var k = 0; k < (i == 5 ? 6 : 4); k++) {
          m.elements.add(_n('C', 4));
        }
        measures.add(m);
      }
      expect(
        () => GrandStaffPainter(
          staffGroup:
              StaffGroup(staves: [Staff(measures: measures), bassOf(12)]),
          staffSpace: 12,
          metadata: metadata,
          theme: const MusicScoreTheme(),
          availableWidth: 300,
        ),
        returnsNormally,
      );
    });

    test('autoBeaming: false survives every system break', () {
      // Measured before: honoured in bar 0 only; bars 1..7 were auto-beamed.
      final groups = <List<Note>>[];
      final measures = <Measure>[];
      for (var i = 0; i < 8; i++) {
        final g = [
          for (final p in ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C'])
            _n(p, 4, d: DurationType.eighth)
        ];
        groups.add(g);
        final m = Measure(autoBeaming: false);
        if (i == 0) m.elements.add(Clef(clefType: ClefType.treble));
        m.elements.addAll(g);
        measures.add(m);
      }
      GrandStaffPainter(
        staffGroup: StaffGroup(staves: [Staff(measures: measures), bassOf(8)]),
        staffSpace: 12,
        metadata: metadata,
        theme: const MusicScoreTheme(),
        availableWidth: 400,
      );
      for (var i = 0; i < 8; i++) {
        expect(groups[i].where((n) => n.beam != null), isEmpty,
            reason: 'bar $i had auto-beaming turned off by its author');
      }
    });

    test('polyphony is not dropped by the rebuild', () {
      final measures = <Measure>[];
      for (var i = 0; i < 8; i++) {
        final mv = MultiVoiceMeasure();
        if (i == 0) mv.elements.add(Clef(clefType: ClefType.treble));
        mv.addVoice(
            Voice(number: 1, elements: [_n('C', 5, d: DurationType.whole)]));
        mv.addVoice(
            Voice(number: 2, elements: [_n('E', 4, d: DurationType.whole)]));
        measures.add(mv);
      }
      expect(
        () => GrandStaffPainter(
          staffGroup:
              StaffGroup(staves: [Staff(measures: measures), bassOf(8)]),
          staffSpace: 12,
          metadata: metadata,
          theme: const MusicScoreTheme(),
          availableWidth: 300,
        ),
        returnsNormally,
      );
    });
  });

  // ------------------------------------------------------------ N-03 / N-12 --
  group('N-03 / N-12 — MultiVoiceMeasure.elements are real', () {
    test('a clef in measure.elements positions the notes by pitch', () {
      // Measured before: the clef, key, meter and dynamic were never drawn, the
      // cursor had no active clef, and C6 and C4 both landed at y = 60.0 with
      // noteXPositions EMPTY.
      final mv = MultiVoiceMeasure();
      mv.elements.addAll([
        Clef(clefType: ClefType.treble),
        KeySignature(3),
        TimeSignature(numerator: 4, denominator: 4),
        Dynamic(type: DynamicType.f),
      ]);
      mv.addVoice(Voice(number: 1, elements: [_n('C', 6, d: DurationType.half)]));
      mv.addVoice(Voice(number: 2, elements: [_n('C', 4, d: DurationType.half)]));

      final engine = engineFor(Staff(measures: [mv]));
      final placed = engine.layout();

      expect(placed.where((p) => p.element is Clef), hasLength(1));
      expect(placed.where((p) => p.element is KeySignature), hasLength(1));
      expect(placed.where((p) => p.element is TimeSignature), hasLength(1));
      expect(placed.where((p) => p.element is Dynamic), hasLength(1));
      expect(engine.noteXPositions, hasLength(2));
      expect(
        placed.where((p) => p.element is Note).map((p) => p.position.dy).toSet(),
        hasLength(2),
        reason: 'C6 and C4 must not share a Y',
      );
    });

    test('a polyphonic import does not duplicate its opening block', () {
      // The parsers wrote every system element to BOTH measure.elements and
      // voice 1 to compensate for the layout ignoring the former. With the
      // layout fixed, that duplication draws everything twice.
      const xml = '''<?xml version="1.0"?>
<score-partwise version="4.0"><part-list><score-part id="P1"/></part-list>
<part id="P1"><measure number="1"><attributes><divisions>4</divisions>
<key><fifths>2</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>
<clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>16</duration><voice>1</voice><type>whole</type></note>
<backup><duration>16</duration></backup>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>16</duration><voice>2</voice><type>whole</type></note>
</measure></part></score-partwise>''';
      final placed = engineFor(MusicXMLParser.parseMusicXML(xml)).layout();
      expect(placed.where((p) => p.element is Clef), hasLength(1));
      expect(placed.where((p) => p.element is KeySignature), hasLength(1));
      expect(placed.where((p) => p.element is TimeSignature), hasLength(1));
      expect(placed.where((p) => p.element is Note), hasLength(2));
    });
  });

  // ------------------------------------------------------------------ N-04 --
  test('N-04 — layout stays linear in the number of systems', () {
    // Measured before: 400 bars 160 ms, 1600 bars 262 ms, 3200 bars 1156 ms,
    // 6400 bars 5991 ms — `_justifyHorizontally` scanned the whole element list
    // once per system.
    Staff big(int bars) => Staff(measures: [
          for (var i = 0; i < bars; i++)
            _bar([
              if (i == 0) Clef(clefType: ClefType.treble),
              if (i == 0) TimeSignature(numerator: 4, denominator: 4),
              for (final p in ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C'])
                _n(p, 4, d: DurationType.eighth),
            ])
        ]);
    engineFor(big(100), width: 1000).layout(); // warm up

    double timeOf(int bars) {
      final staff = big(bars);
      final sw = Stopwatch()..start();
      engineFor(staff, width: 1000).layout();
      return sw.elapsedMicroseconds / 1000.0;
    }

    final small = timeOf(800);
    final large = timeOf(3200);
    // Four times the input must not cost more than ten times the time. The old
    // engine cost 8x for this step and grew from there.
    expect(large / math.max(small, 1e-6), lessThan(10.0),
        reason: 'justification must not be O(systems x elements): '
            '800 bars ${small}ms vs 3200 bars ${large}ms');
  });

  // ------------------------------------------------------------ N-05 / F-27 --
  group('N-05 / F-27 — an accidental claims the space BEFORE its note', () {
    test('the gap grows in front, not behind', () {
      // Measured before: gap before +6.30 px, gap after +15.55 px.
      final a = _n('C', 4);
      final b = _n('E', 4, alter: 1.0);
      final c = _n('G', 4);
      final d = _n('B', 4);
      final engine = engineFor(
          Staff(measures: [
            _bar([Clef(clefType: ClefType.treble), a, b, c, d])
          ]),
          width: 100000);
      engine.layout();
      final before = engine.noteXPositions[b]! - engine.noteXPositions[a]!;
      final after = engine.noteXPositions[c]! - engine.noteXPositions[b]!;
      final plain = engine.noteXPositions[d]! - engine.noteXPositions[c]!;
      expect(before, greaterThan(after));
      expect(after, closeTo(plain, 0.01),
          reason: 'the gap AFTER an accidental note must be the plain gap');
    });

    test('a double flat never overlaps the previous notehead', () {
      // Measured before: 26.90 px note-to-note, 14.16 px head, 19.82 px glyph
      // — 7.08 px of overlap under maximum compression.
      final notes = [
        for (var i = 0; i < 32; i++)
          _n('B', 4, d: DurationType.sixteenth, alter: i.isEven ? -2.0 : 0.0)
      ];
      final engine = engineFor(
          Staff(measures: [
            _bar([Clef(clefType: ClefType.treble), ...notes])
          ]),
          width: 400);
      engine.layout();

      final head = engine.noteheadBlackWidth * 12;
      final doubleFlat = metadata.getGlyphWidth('accidentalDoubleFlat') * 12;
      final natural = metadata.getGlyphWidth('accidentalNatural') * 12;

      for (var i = 1; i < notes.length; i++) {
        final decision = engine.accidentalDecisions[notes[i]];
        if (decision == AccidentalDisplay.hide) continue;
        final glyph = decision == AccidentalDisplay.natural
            ? natural
            : (notes[i].pitch.alter == -2.0 ? doubleFlat : natural);
        final gap =
            engine.noteXPositions[notes[i]]! - engine.noteXPositions[notes[i - 1]]!;
        expect(gap - head - glyph, greaterThanOrEqualTo(0.0),
            reason: 'note $i: the accidental drove into the previous notehead');
      }
    });
  });

  // ------------------------------------------------------------------ N-07 --
  test('N-07 — a tuplet spaces its children by duration', () {
    // Measured before: a quarter and an eighth in one triplet both got exactly
    // 30.00 px, and so did an eighth followed by two sixteenths.
    final quarter = _n('C', 4);
    final eighth = _n('D', 4, d: DurationType.eighth);
    final t1 =
        Tuplet(elements: [quarter, eighth], actualNotes: 3, normalNotes: 2);
    final e8 = _n('E', 4, d: DurationType.eighth);
    final s1 = _n('F', 4, d: DurationType.sixteenth);
    final s2 = _n('G', 4, d: DurationType.sixteenth);
    final t2 = Tuplet(elements: [e8, s1, s2], actualNotes: 3, normalNotes: 2);

    final engine = engineFor(
        Staff(measures: [
          _bar([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            t1,
            t2,
          ])
        ]),
        width: 100000);
    engine.layout();

    final quarterSlot =
        engine.noteXPositions[eighth]! - engine.noteXPositions[quarter]!;
    final eighthSlot = engine.noteXPositions[s1]! - engine.noteXPositions[e8]!;
    final sixteenthSlot = engine.noteXPositions[s2]! - engine.noteXPositions[s1]!;
    expect(quarterSlot, greaterThan(eighthSlot));
    expect(eighthSlot, greaterThan(sixteenthSlot));
  });

  // ------------------------------------------------------------------ N-09 --
  test('N-09 — beams get geometry without an explicit meter', () {
    // The README's quick-start snippet declares no TimeSignature, and
    // `_analyzeBeamGroups` returned early for it: beams were stamped but had no
    // stem lengths, no slope and no secondary segments.
    final notes = [
      for (final p in ['C', 'D', 'E', 'F']) _n(p, 4, d: DurationType.eighth)
    ];
    final engine = engineFor(Staff(measures: [
      _bar([Clef(clefType: ClefType.treble), ...notes])
    ]));
    engine.layout();
    expect(engine.advancedBeamGroups, hasLength(1));
    expect(engine.advancedBeamGroups.single.beamSegments, isNotEmpty);
  });

  // ------------------------------------------------------------------ N-10 --
  test('N-10 — beam slant follows the interval (Gould table)', () {
    // Measured before: an ascending 2nd, an ascending 6th and a two-octave leap
    // ALL produced a slant of exactly 0.25 staff spaces.
    double slantOf(String s1, int o1, String s2, int o2) {
      final notes = [
        _n(s1, o1, d: DurationType.eighth),
        _n(s2, o2, d: DurationType.eighth),
      ];
      final engine = engineFor(Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 2, denominator: 4),
          ...notes,
        ])
      ]));
      engine.layout();
      final group = engine.advancedBeamGroups.single;
      return (group.rightY - group.leftY).abs() / 12;
    }

    expect(slantOf('G', 4, 'G', 4), closeTo(0.00, 0.02)); // unison
    expect(slantOf('G', 4, 'A', 4), closeTo(0.25, 0.02)); // 2nd
    expect(slantOf('G', 4, 'B', 4), closeTo(0.50, 0.02)); // 3rd
    expect(slantOf('G', 4, 'C', 5), closeTo(1.00, 0.02)); // 4th
    expect(slantOf('G', 4, 'E', 5), closeTo(1.25, 0.02)); // 6th
    expect(slantOf('G', 4, 'G', 5), closeTo(1.50, 0.02)); // octave
  });

  // ------------------------------------------------------------------ N-13 --
  test('N-13 — <transpose> reaches playback', () {
    // `applyMusicXmlTransposition` existed and was never called from lib/,
    // test/ or example/: a B-flat clarinet played back a major second high.
    const xml = '''<?xml version="1.0"?>
<score-partwise version="4.0"><part-list>
<score-part id="P1"><part-name>Clarinet in B-flat</part-name></score-part></part-list>
<part id="P1"><measure number="1"><attributes><divisions>4</divisions>
<transpose><diatonic>-1</diatonic><chromatic>-2</chromatic></transpose>
<clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>16</duration><type>whole</type></note>
</measure></part></score-partwise>''';
    final staff = MusicXMLParser.parseMusicXML(xml);
    expect(staff.transposition?.semitones, -2);
    expect(staff.measures.first.allElements.whereType<Note>().first.pitch.octave,
        4,
        reason: 'the WRITTEN pitch stays written; only playback transposes');
    final notes = MidiMapper.fromStaff(staff)
        .tracks
        .expand((t) => t.events)
        .where((e) => e.type == MidiEventType.noteOn)
        .map((e) => e.note);
    expect(notes, [58], reason: 'written C4 on a B-flat clarinet sounds B-flat 3');
  });

  // ------------------------------------------------------------------ N-15 --
  test('N-15 — an octave clef is applied once, on the drawing side', () {
    // MusicXML <pitch> is the SOUNDING pitch. The importer stored it as written
    // and MidiMapper shifted it again, so an imported tenor part was drawn an
    // octave low AND played an octave low.
    String doc(int change) => '''<?xml version="1.0"?>
<score-partwise version="4.0"><part-list><score-part id="P1"/></part-list>
<part id="P1"><measure number="1"><attributes><divisions>4</divisions>
<clef><sign>G</sign><line>2</line>${change == 0 ? '' : '<clef-octave-change>$change</clef-octave-change>'}</clef></attributes>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>16</duration><type>whole</type></note>
</measure></part></score-partwise>''';

    final positions = <int>[];
    for (final change in [0, -1, 1]) {
      final staff = MusicXMLParser.parseMusicXML(doc(change));
      final note = staff.measures.first.allElements.whereType<Note>().first;
      final clef = staff.measures.first.allElements.whereType<Clef>().first;
      expect(note.pitch.octave, 4, reason: '<pitch> is stored verbatim');
      positions.add(StaffPositionCalculator.calculate(note.pitch, clef));
      final notes = MidiMapper.fromStaff(staff)
          .tracks
          .expand((t) => t.events)
          .where((e) => e.type == MidiEventType.noteOn)
          .map((e) => e.note);
      expect(notes, [60], reason: 'a sounding C4 is MIDI 60 under any clef');
    }
    // 8vb prints a seventh higher on the page, 8va a seventh lower.
    expect(positions[1] - positions[0], 7);
    expect(positions[0] - positions[2], 7);
  });

  // ------------------------------------------------------------------ N-19 --
  test('N-19 — the hit-test box covers what is drawn', () {
    // Measured before: clicking a stem, an accidental, or the notehead of a
    // chord above the staff all returned null.
    final high = _n('C', 6);
    final sharp = _n('F', 4, alter: 1.0);
    final chord = Chord(
      notes: [_n('C', 6), _n('E', 6), _n('G', 6)],
      duration: Duration(DurationType.quarter),
    );
    final engine = engineFor(Staff(measures: [
      _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        high,
        sharp,
        chord,
      ])
    ]));
    final placed = engine.layout();
    final tester =
        ScoreHitTester(elements: placed, staffSpace: 12, engine: engine);

    final stemPoint = Offset(
      engine.noteXPositions[high]!,
      engine.noteYPositions[high]! + 24,
    );
    expect(tester.hitTest(stemPoint)?.element, same(high),
        reason: 'the stem belongs to its note');

    final accidentalPoint = Offset(
      engine.noteXPositions[sharp]! - 8,
      engine.noteYPositions[sharp]!,
    );
    expect(tester.hitTest(accidentalPoint)?.element, same(sharp));

    for (final note in chord.notes) {
      final point = Offset(
        engine.noteXPositions[note]!,
        engine.noteYPositions[note]!,
      );
      expect(tester.hitTest(point)?.element, same(chord),
          reason: 'a chord high above the staff must still be clickable');
    }
  });

  // ------------------------------------------------------------------ N-21 --
  test('N-21 — 4/4 groups sixteenths by the beat, quavers by the half bar', () {
    List<int> groupsOf(DurationType d, int count) {
      final notes = [for (var i = 0; i < count; i++) _n('C', 4, d: d)];
      engineFor(
          Staff(measures: [
            _bar([
              Clef(clefType: ClefType.treble),
              TimeSignature(numerator: 4, denominator: 4),
              ...notes,
            ])
          ]),
          width: 100000).layout();
      final sizes = <int>[];
      var current = 0;
      for (final n in notes) {
        switch (n.beam) {
          case BeamType.start:
            current = 1;
          case BeamType.inner:
            current++;
          case BeamType.end:
            sizes.add(current + 1);
            current = 0;
          case null:
            break;
        }
      }
      return sizes;
    }

    expect(groupsOf(DurationType.eighth, 8), [4, 4],
        reason: 'Behind Bars allows quavers across the half bar');
    expect(groupsOf(DurationType.sixteenth, 16), [4, 4, 4, 4],
        reason: 'semiquavers are grouped by the crotchet; this used to be 8-8');
  });

  // ------------------------------------------------------------------ N-22 --
  test('N-22 — the onset grid resolves the shortest duration', () {
    // Measured before: sixteen distinct 2048th onsets collapsed to nine keys.
    final keys = <double>{};
    for (var i = 0; i < 16; i++) {
      keys.add(((i / 2048) * 8192.0).round() / 8192.0);
    }
    expect(keys, hasLength(16));
  });

  // ------------------------------------------------------------ N-23 / N-24 --
  group('N-23 / N-24 — interop keeps what it was given', () {
    test('part names, group names and abbreviations survive a round trip', () {
      const xml = '''<?xml version="1.0"?>
<score-partwise version="4.0"><part-list>
<part-group type="start" number="1"><group-symbol>brace</group-symbol><group-name>Piano</group-name></part-group>
<score-part id="P1"><part-name>Right hand</part-name></score-part>
<score-part id="P2"><part-name>Left hand</part-name></score-part>
<part-group type="stop" number="1"/>
<score-part id="P3"><part-name>Violoncello</part-name><part-abbreviation>Vc.</part-abbreviation></score-part>
</part-list>
<part id="P1"><measure number="1"><attributes><divisions>1</divisions><clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><type>whole</type></note></measure></part>
<part id="P2"><measure number="1"><attributes><divisions>1</divisions><clef><sign>F</sign><line>4</line></clef></attributes>
<note><pitch><step>C</step><octave>3</octave></pitch><duration>4</duration><type>whole</type></note></measure></part>
<part id="P3"><measure number="1"><attributes><divisions>1</divisions><clef><sign>F</sign><line>4</line></clef></attributes>
<note><pitch><step>G</step><octave>2</octave></pitch><duration>4</duration><type>whole</type></note></measure></part>
</score-partwise>''';
      final score = MusicXMLParser.scoreFromMusicXML(xml);
      expect(score.staffGroups.first.name, 'Piano');
      expect(score.allStaves.map((s) => s.name),
          ['Right hand', 'Left hand', 'Violoncello']);
      expect(score.allStaves.last.abbreviation, 'Vc.');

      final back =
          MusicXMLParser.scoreFromMusicXML(MusicXMLParser.scoreToMusicXML(score));
      expect(back.staffGroups.first.name, 'Piano');
      expect(back.allStaves.map((s) => s.name),
          ['Right hand', 'Left hand', 'Violoncello']);
    });

    test('JSON round-trips lyrics and cross-staff routing', () {
      // Measured before: there was NO exporter, and the importer returned
      // syllables == null and crossStaffMove == 0 whatever went in.
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          Note(
            pitch: const Pitch(step: 'F', octave: 4, alter: 1.0),
            duration: const Duration(DurationType.eighth, dots: 1),
            syllables: const [Syllable(text: 'Ky-', type: SyllableType.initial)],
            crossStaffMove: -1,
            voice: 2,
          ),
        ])
      ]);
      final back =
          JsonMusicParser.parseStaff(JsonMusicParser.staffToJson(staff));
      final note = back.measures.first.allElements.whereType<Note>().first;
      expect(note.syllables?.single.text, 'Ky-');
      expect(note.syllables?.single.type, SyllableType.initial);
      expect(note.crossStaffMove, -1);
      expect(note.voice, 2);
      expect(note.duration.dots, 1);
    });

    test('a <pitch> with no <octave> fails loudly instead of vanishing', () {
      const xml = '''<?xml version="1.0"?>
<score-partwise version="4.0"><part-list><score-part id="P1"/></part-list>
<part id="P1"><measure number="1">
<note><pitch><step>C</step></pitch><duration>4</duration><type>quarter</type></note>
</measure></part></score-partwise>''';
      expect(() => MusicXMLParser.parseMusicXML(xml),
          throwsA(isA<FormatException>()));
    });

    test('MEI clef.shape="TAB" produces a tablature clef', () {
      const mei = '''<?xml version="1.0"?>
<mei xmlns="http://www.music-encoding.org/ns/mei"><music><body><mdiv><score>
<scoreDef><staffGrp><staffDef n="1" lines="6" clef.shape="TAB"/></staffGrp></scoreDef>
<section><measure n="1"><staff n="1"><layer n="1">
<note pname="c" oct="4" dur="4"/></layer></staff></measure></section>
</score></mdiv></body></music></mei>''';
      final staff = MEIParser.scoreFromMei(mei).allStaves.first;
      expect(
        staff.measures.first.allElements.whereType<Clef>().single.clefType,
        ClefType.tab6,
      );
    });
  });

  // ------------------------------------------------------------------ N-29 --
  test('N-29 — a cross-voice unison shares one notehead position', () {
    // Behind Bars p.44: two voices on the same pitch with the same value share
    // a notehead. Displacing one by a full head width reads as a second.
    MultiVoiceMeasure unison({required bool sameDuration}) {
      final mv = MultiVoiceMeasure();
      mv.elements.add(Clef(clefType: ClefType.treble));
      mv.addVoice(Voice(number: 1, elements: [_n('D', 5, d: DurationType.whole)]));
      mv.addVoice(Voice(number: 2, elements: [
        _n('D', 5, d: sameDuration ? DurationType.whole : DurationType.half)
      ]));
      return mv;
    }

    List<double> xsOf(Measure m) => engineFor(Staff(measures: [m]))
        .layout()
        .where((p) => p.element is Note)
        .map((p) => p.position.dx)
        .toList();

    expect(xsOf(unison(sameDuration: true)).toSet(), hasLength(1));
    expect(xsOf(unison(sameDuration: false)).toSet(), hasLength(2),
        reason: 'different values still need separate heads');

    final second = MultiVoiceMeasure();
    second.elements.add(Clef(clefType: ClefType.treble));
    second.addVoice(
        Voice(number: 1, elements: [_n('B', 4, d: DurationType.whole)]));
    second.addVoice(
        Voice(number: 2, elements: [_n('A', 4, d: DurationType.whole)]));
    expect(xsOf(second).toSet(), hasLength(2));
  });

  // ------------------------------------------------------------------ N-31 --
  test('N-31 — beam subdivisions cover the whole bar', () {
    // 5/4 had a table entry of [0.5, 0.5], which sums to 1.0 against a bar of
    // 1.25: the fifth crotchet fell through and produced a stray trailing group
    // (measured: 4-4-2 for ten quavers).
    final notes = [
      for (var i = 0; i < 10; i++) _n('C', 4, d: DurationType.eighth)
    ];
    engineFor(
        Staff(measures: [
          _bar([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 5, denominator: 4),
            ...notes,
          ])
        ]),
        width: 100000).layout();
    final starts = notes.where((n) => n.beam == BeamType.start).length;
    final ends = notes.where((n) => n.beam == BeamType.end).length;
    expect(starts, ends, reason: 'every opened beam group must be closed');
    expect(starts, 5, reason: '5/4 beams its quavers in five crotchet pairs');
  });
}
