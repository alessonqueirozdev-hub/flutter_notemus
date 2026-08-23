// Engraving and model INVARIANTS.
//
// Every test here encodes a property that must hold for ANY score, not a
// golden snapshot of one. They exist because the 2.6.0 forensic audit found
// that 594 green tests coexisted with silently dropped notes, inverted
// rhythmic spacing, a mid-measure clef that moved every note in its bar by a
// twelfth, and grand-staff hands that did not line up.
//
// Naming follows the audit's identifiers (L1..L10 invariants, F-xx findings)
// so a future audit can map a failure straight back to the defect it guards.

import 'dart:math' as math;

// Hide the music `Duration` so `const Duration(milliseconds: …)` inside the
// Flutter framework still resolves, and alias the framework import.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Note _n(String step, int octave,
        {DurationType d = DurationType.quarter,
        int dots = 0,
        int? voice,
        List<Syllable>? syllables,
        double alter = 0.0}) =>
    Note(
      pitch: Pitch(step: step, octave: octave, alter: alter),
      duration: Duration(d, dots: dots),
      voice: voice,
      syllables: syllables,
    );

Measure _bar(List<MusicalElement> elements) {
  final m = Measure();
  for (final e in elements) {
    m.elements.add(e);
  }
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
      LayoutEngine(staff, availableWidth: width, staffSpace: ss,
          metadata: metadata);

  // ---------------------------------------------------------------- L1 -----
  //
  // The original defect (F-05) had two halves: a bar wider than the line was
  // neither squeezed NOR reachable — the canvas was pinned to the viewport
  // width and the horizontal scroll view wrapped a child of exactly that width,
  // so ~67% of a dense bar was clipped away with no way to scroll to it.
  //
  // The contract now is: squeeze as far as legibility allows, and whatever is
  // still too wide must be REACHABLE (the canvas grows and really scrolls).
  group('L1 — dense music is compressed, and never unreachable', () {
    double naturalSpan(Measure m) {
      final positioned = LayoutEngine(Staff(measures: [m]),
              availableWidth: 100000, staffSpace: 12, metadata: metadata)
          .layout();
      return positioned.map((p) => p.position.dx).reduce(math.max);
    }

    Measure denseBar() => _bar([
          Clef(clefType: ClefType.treble),
          for (var i = 0; i < 32; i++)
            _n('C', 4, d: DurationType.sixteenth),
        ]);

    test('a bar that does not fit is squeezed towards the line', () {
      const width = 400.0;
      final natural = naturalSpan(denseBar());
      final squeezed = engineFor(Staff(measures: [denseBar()]), width: width)
          .layout()
          .map((p) => p.position.dx)
          .reduce(math.max);

      expect(squeezed, lessThan(natural * 0.85),
          reason: 'F-05: the engine used to apply no compression at all.');
      // It cannot go below the collision floor, and that is correct: past that
      // point the music would be illegible. L8 guards the floor itself.
      expect(squeezed, greaterThan(width * 0.5));
    });

    test('overflow is reported so the canvas can grow', () {
      const width = 400.0;
      final engine = engineFor(Staff(measures: [denseBar()]), width: width);
      final positioned = engine.layout();
      final maxX = positioned.map((p) => p.position.dx).reduce(math.max);

      expect(engine.contentWidth(positioned), greaterThanOrEqualTo(maxX),
          reason: 'the widget sizes its canvas from this number; if it under-'
              'reports, music is clipped and unreachable.');
      expect(engine.overflowsAvailableWidth(positioned), isTrue);
    });

    testWidgets('MusicScore makes the overflow scrollable', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: MusicScore(
              staff: Staff(measures: [denseBar()]),
              staffSpace: 12,
              enableResponsiveLayout: false,
              preventVerticalOverflow: false,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((c) => c.painter is MusicScorePainter)
          .toList();
      expect(painters, isNotEmpty, reason: 'the score should have painted');

      final painter = painters.first.painter as MusicScorePainter;
      final maxX = painter.positionedElements
          .map((p) => p.position.dx)
          .reduce(math.max);
      final size = painters.first.size;
      expect(size.width, greaterThanOrEqualTo(maxX),
          reason: 'F-05b: the canvas was pinned to the viewport width, so the '
              'horizontal SingleChildScrollView never had anything to scroll.');
    });

    test('normal music is not compressed at all', () {
      final measures = <Measure>[
        for (var b = 0; b < 4; b++)
          _bar([
            if (b == 0) Clef(clefType: ClefType.treble),
            for (var i = 0; i < 4; i++) _n('CDEFGAB'[i % 7], 4),
          ]),
      ];
      final engine = engineFor(Staff(measures: measures), width: 900);
      final positioned = engine.layout();
      expect(engine.overflowsAvailableWidth(positioned), isFalse);
    });
  });

  // ---------------------------------------------------------------- L2 -----
  group('L2 — every note in the model reaches the layout', () {
    test('a reused Note instance is not swallowed', () {
      final shared = _n('C', 4);
      final m = _bar([Clef(clefType: ClefType.treble), shared, shared, shared]);
      final positioned = engineFor(Staff(measures: [m]))
          .layout()
          .where((p) => p.element is Note)
          .length;
      expect(positioned, 3,
          reason: 'F-08: the identity Set used to drop every repeat of the '
              'same instance, silently deleting music.');
    });

    test('note count is preserved across a whole staff', () {
      final measures = <Measure>[
        for (var b = 0; b < 5; b++)
          _bar([
            if (b == 0) Clef(clefType: ClefType.treble),
            for (var i = 0; i < 8; i++)
              _n('CDEFGAB'[i % 7], 4, d: DurationType.eighth),
          ]),
      ];
      final staff = Staff(measures: measures);
      final modelCount = staff.measures
          .expand((m) => m.elements)
          .whereType<Note>()
          .length;
      final laidOut = engineFor(staff)
          .layout()
          .where((p) => p.element is Note)
          .length;
      expect(laidOut, modelCount);
    });
  });

  // ---------------------------------------------------------------- L3 -----
  group('L3 — layout geometry is keyed on the caller own objects', () {
    test('beamed notes keep their identity', () {
      final notes = [
        for (var i = 0; i < 4; i++) _n('C', 5, d: DurationType.eighth),
      ];
      final m = _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 2, denominator: 4),
        ...notes,
      ]);
      final engine = engineFor(Staff(measures: [m]));
      engine.layout();
      for (final note in notes) {
        expect(engine.noteXPositions[note], isNotNull,
            reason: 'F-02: the engine used to replace beamed notes with clones, '
                'so the public position map never matched the user objects.');
        expect(engine.noteYPositions[note], isNotNull);
      }
    });

    test('tuplet inner notes get geometry too', () {
      final inner = [
        _n('C', 5, d: DurationType.eighth),
        _n('D', 5, d: DurationType.eighth),
        _n('E', 5, d: DurationType.eighth),
      ];
      final m = _bar([
        Clef(clefType: ClefType.treble),
        Tuplet(elements: inner, actualNotes: 3, normalNotes: 2),
      ]);
      final engine = engineFor(Staff(measures: [m]));
      engine.layout();
      for (final note in inner) {
        expect(engine.noteXPositions[note], isNotNull,
            reason: 'F-25: tuplet contents used to be invisible to the layout.');
      }
    });
  });

  // ---------------------------------------------------------------- L4 -----
  group('L4 — the layout signature is deterministic', () {
    test('laying the same staff out twice yields the same signature', () {
      final measures = <Measure>[
        for (var b = 0; b < 6; b++)
          _bar([
            if (b == 0) Clef(clefType: ClefType.treble),
            for (var i = 0; i < 4; i++)
              _n('CDEFGAB'[(b + i) % 7], 4, d: DurationType.eighth),
          ]),
      ];
      final staff = Staff(measures: measures);
      final signatures = [
        for (var i = 0; i < 3; i++)
          engineFor(staff).layoutWithSignature().signature,
      ];
      expect(signatures.toSet(), hasLength(1),
          reason: 'F-02b: identity hashes of freshly cloned notes made three '
              'runs produce three different signatures, so shouldRepaint was '
              'always true and viewport culling saved nothing.');
    });

    test('positions themselves are reproducible', () {
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          for (var i = 0; i < 6; i++) _n('G', 4, d: DurationType.eighth),
        ])
      ]);
      List<String> run() => engineFor(staff)
          .layout()
          .map((p) =>
              '${p.element.runtimeType}@${p.position.dx.toStringAsFixed(4)}')
          .toList();
      expect(run(), run());
    });
  });

  // ---------------------------------------------------------------- L5 -----
  group('L5 — every stem in a beam group clears the minimum length', () {
    test('a wide interval does not produce a stub stem', () {
      // E4 + F5 is the case the audit measured at 1.75 staff spaces.
      final m = _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 2, denominator: 4),
        _n('E', 4, d: DurationType.eighth),
        _n('F', 5, d: DurationType.eighth),
      ]);
      final engine = engineFor(Staff(measures: [m]));
      engine.layout();
      expect(engine.advancedBeamGroups, isNotEmpty);
      for (final group in engine.advancedBeamGroups) {
        for (final note in group.notes) {
          final noteY = engine.noteYPositions[note];
          final noteX = engine.noteXPositions[note];
          expect(noteY, isNotNull);
          expect(noteX, isNotNull);
          final beamY = group.interpolateBeamY(noteX!);
          final stemSpaces = (noteY! - beamY).abs() / 12.0;
          expect(stemSpaces, greaterThanOrEqualTo(2.4),
              reason: 'F-14: the beam was placed from the average of the FIRST '
                  'and LAST note only, so inner/outer stems collapsed.');
        }
      }
    });

    test('a run of leaps keeps every stem legal', () {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        _n('E', 4, d: DurationType.eighth),
        _n('E', 5, d: DurationType.eighth),
        _n('F', 4, d: DurationType.eighth),
        _n('D', 5, d: DurationType.eighth),
        _n('G', 4, d: DurationType.eighth),
        _n('C', 5, d: DurationType.eighth),
        _n('A', 4, d: DurationType.eighth),
        _n('B', 4, d: DurationType.eighth),
      ]);
      final engine = engineFor(Staff(measures: [m]), width: 1400);
      engine.layout();
      for (final group in engine.advancedBeamGroups) {
        for (final note in group.notes) {
          final noteY = engine.noteYPositions[note]!;
          final noteX = engine.noteXPositions[note]!;
          final stemSpaces =
              (noteY - group.interpolateBeamY(noteX)).abs() / 12.0;
          expect(stemSpaces, greaterThanOrEqualTo(2.4));
        }
      }
    });
  });

  // ---------------------------------------------------------------- L6 -----
  group('L6 — horizontal space grows monotonically with duration', () {
    double spanOf(DurationType d) {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        for (var i = 0; i < 4; i++) _n('C', 4, d: d),
      ]);
      final positioned = engineFor(Staff(measures: [m]), width: 100000)
          .layout()
          .where((p) => p.element is Note)
          .toList();
      return positioned.last.position.dx - positioned.first.position.dx;
    }

    test('all fifteen duration types are ordered', () {
      const ordered = <DurationType>[
        DurationType.twoThousandFortyEighth,
        DurationType.thousandTwentyFourth,
        DurationType.fiveHundredTwelfth,
        DurationType.twoHundredFiftySixth,
        DurationType.oneHundredTwentyEighth,
        DurationType.sixtyFourth,
        DurationType.thirtySecond,
        DurationType.sixteenth,
        DurationType.eighth,
        DurationType.quarter,
        DurationType.half,
        DurationType.whole,
        DurationType.breve,
        DurationType.long,
        DurationType.maxima,
      ];
      double previous = -1;
      for (final d in ordered) {
        final span = spanOf(d);
        expect(span, greaterThanOrEqualTo(previous),
            reason: 'F-11: the factor table only covered whole..64th and fell '
                'back to 1.0, so a breve was narrower than a whole note and a '
                '128th took 2.3x the space of a 64th. Offender: ${d.name}.');
        previous = span;
      }
    });

    test('a dotted note takes more room than its plain form', () {
      expect(
        spanOf(DurationType.quarter),
        lessThan(_spanDotted(engineFor, DurationType.quarter)),
      );
    });
  });

  // ---------------------------------------------------------------- L7 -----
  group('L7 — simultaneous events share an X across staves', () {
    test('four quarters against two halves line up on every beat', () {
      final treble = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          _n('C', 5), _n('D', 5), _n('E', 5), _n('F', 5),
        ])
      ]);
      final bass = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.bass),
          TimeSignature(numerator: 4, denominator: 4),
          _n('C', 3, d: DurationType.half),
          _n('G', 3, d: DurationType.half),
        ])
      ]);

      final tre = engineFor(treble, width: 600).layout();
      final bas = engineFor(bass, width: 600).layout();

      // Onsets are the shared time coordinate the aligner works on.
      double? onsetOf(List<PositionedElement> els, int noteIndex) {
        final notes = els.where((p) => p.element is Note).toList();
        return noteIndex < notes.length ? notes[noteIndex].onset : null;
      }

      expect(onsetOf(tre, 0), 0.0);
      expect(onsetOf(tre, 2), 0.5, reason: 'beat 3 of a 4/4 bar');
      expect(onsetOf(bas, 1), 0.5,
          reason: 'F-04: without a shared time coordinate the aligner had '
              'nothing to match on and beat 3 drifted 38 px apart.');
    });

    test('every positioned element carries a finite onset', () {
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 3, denominator: 4),
          _n('C', 4), _n('D', 4), _n('E', 4),
        ]),
        _bar([_n('F', 4), _n('G', 4), _n('A', 4)]),
      ]);
      final positioned = engineFor(staff).layout();
      for (final p in positioned) {
        expect(p.onset.isFinite, isTrue);
        expect(p.onset, greaterThanOrEqualTo(0));
      }
      final secondBarNotes = positioned
          .where((p) => p.element is Note && p.measureIndex == 1)
          .toList();
      expect(secondBarNotes.first.onset, closeTo(0.75, 1e-9),
          reason: 'measure 2 of a 3/4 piece starts at three quarters.');
    });
  });

  // ---------------------------------------------------------------- L8 -----
  group('L8 — noteheads do not overlap', () {
    test('consecutive notes never come closer than a notehead', () {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        for (var i = 0; i < 24; i++)
          _n('CDEFGAB'[i % 7], 4, d: DurationType.thirtySecond),
      ]);
      final positioned = engineFor(Staff(measures: [m]), width: 380)
          .layout()
          .where((p) => p.element is Note)
          .toList();
      final headWidth = metadata.getGlyphWidth('noteheadBlack') * 12.0;
      for (var i = 1; i < positioned.length; i++) {
        final gap = positioned[i].position.dx - positioned[i - 1].position.dx;
        expect(gap, greaterThanOrEqualTo(headWidth * 0.85),
            reason: 'compression must stop before the heads collide');
      }
    });
  });

  // ---------------------------------------------------------------- L9 -----
  group('L9 — round trips do not silently lose data', () {
    test('MusicXML keeps pitch, duration, articulation, tie and lyrics', () {
      final original = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          KeySignature(2),
          TimeSignature(numerator: 6, denominator: 8),
          Note(
            pitch: const Pitch(step: 'F', octave: 4, alter: 1.0),
            duration: const Duration(DurationType.eighth, dots: 1),
            articulations: const [
              ArticulationType.staccato,
              ArticulationType.accent
            ],
            tie: TieType.start,
            slur: SlurType.start,
            syllables: [Syllable(text: 'Ky', type: SyllableType.initial)],
          ),
          Rest(duration: const Duration(DurationType.quarter)),
        ])
      ]);

      final xml = MusicXMLParser.staffToMusicXML(original);
      final back = MusicXMLParser.parseMusicXML(xml);

      final a = original.measures.first.elements.whereType<Note>().first;
      final b = back.measures.first.elements.whereType<Note>().first;

      expect(b.pitch.step, a.pitch.step);
      expect(b.pitch.octave, a.pitch.octave);
      expect(b.pitch.effectiveAlter, a.pitch.effectiveAlter);
      expect(b.duration.type, a.duration.type);
      expect(b.duration.dots, a.duration.dots);
      expect(b.articulations, containsAll(a.articulations));
      expect(b.tie, a.tie);
      expect(b.slur, a.slur);
      expect(b.syllables?.first.text, 'Ky');
      expect(
        back.measures.first.elements.whereType<TimeSignature>().first.numerator,
        6,
      );
      expect(
        back.measures.first.elements.whereType<KeySignature>().first.count,
        2,
      );
    });
  });

  // --------------------------------------------------------------- L10 -----
  group('L10 — the MIDI timeline preserves musical duration', () {
    test('a 4/4 bar of quarters lasts exactly one bar', () {
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          _n('C', 4), _n('D', 4), _n('E', 4), _n('F', 4),
        ])
      ]);
      final seq = MidiMapper.fromStaff(staff);
      final track = seq.tracks.firstWhere((t) => t.name != 'Conductor');
      final lastOff = track.events
          .where((e) => e.type == MidiEventType.noteOff)
          .map((e) => e.tick)
          .reduce(math.max);
      expect(lastOff, seq.ticksPerQuarter * 4);
    });

    test('a triplet of eighths still fills one quarter', () {
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          Tuplet(
            elements: [
              _n('C', 4, d: DurationType.eighth),
              _n('D', 4, d: DurationType.eighth),
              _n('E', 4, d: DurationType.eighth),
            ],
            actualNotes: 3,
            normalNotes: 2,
          ),
        ])
      ]);
      final seq = MidiMapper.fromStaff(staff);
      final track = seq.tracks.firstWhere((t) => t.name != 'Conductor');
      final offs = track.events
          .where((e) => e.type == MidiEventType.noteOff)
          .map((e) => e.tick)
          .toList()
        ..sort();
      expect(offs.last, seq.ticksPerQuarter);
      expect(offs.first, seq.ticksPerQuarter ~/ 3);
    });
  });

  // ------------------------------------------------- targeted regressions ---
  group('F-01 — a mid-measure clef change', () {
    test('stays where it was written and only affects later notes', () {
      final first = _n('C', 4);
      final second = _n('C', 4);
      final m = _bar([
        Clef(clefType: ClefType.treble),
        first,
        Clef(clefType: ClefType.bass),
        second,
      ]);
      final engine = engineFor(Staff(measures: [m]));
      final positioned = engine.layout();

      final clefs =
          positioned.where((p) => p.element is Clef).toList();
      final notes = positioned.where((p) => p.element is Note).toList();
      expect(clefs, hasLength(2));
      expect(notes, hasLength(2));

      expect(clefs[1].position.dx, greaterThan(notes.first.position.dx),
          reason: 'the change belongs after the first note, not at the barline');

      final yTreble = engine.noteYPositions[first]!;
      final yBass = engine.noteYPositions[second]!;
      expect(yTreble, isNot(closeTo(yBass, 0.5)),
          reason: 'C4 in treble and C4 in bass are twelve staff positions '
              'apart; both used to be drawn at the bass position.');
      expect(
        StaffPositionCalculator.calculate(
            first.pitch, Clef(clefType: ClefType.treble)),
        -6,
      );
    });
  });

  group('F-03 — compound meters beam in threes', () {
    List<String?> beamsFor(int num, int den, int count, DurationType d) {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: num, denominator: den),
        for (var i = 0; i < count; i++) _n('C', 5, d: d),
      ]);
      final engine = engineFor(Staff(measures: [m]), width: 2000);
      final placed = engine.layout();
      // `LayoutEngine.beamOf`, not `note.beam`: under ADR-001 the layout no
      // longer stamps its decision onto the model, and `beamOf` falls back to
      // the author's own hint — so this reads the same answer under either
      // contract and the assertions below are untouched.
      return placed
          .where((p) => p.element is Note)
          .map((p) => engine.beamOf(p.element as Note)?.name)
          .toList();
    }

    test('3/8 makes one group of three', () {
      expect(beamsFor(3, 8, 3, DurationType.eighth),
          ['start', 'inner', 'end']);
    });

    test('6/8 makes two groups of three', () {
      expect(beamsFor(6, 8, 6, DurationType.eighth),
          ['start', 'inner', 'end', 'start', 'inner', 'end']);
    });

    test('9/8 makes three groups of three', () {
      expect(beamsFor(9, 8, 9, DurationType.eighth), [
        'start', 'inner', 'end',
        'start', 'inner', 'end',
        'start', 'inner', 'end',
      ]);
    });

    test('12/8 makes four groups of three', () {
      final beams = beamsFor(12, 8, 12, DurationType.eighth);
      expect(beams.where((b) => b == null), isEmpty,
          reason: 'the last note used to be orphaned with a flag');
      expect(beams.where((b) => b == 'start').length, 4);
    });

    test('6/8 in sixteenths makes two groups of six', () {
      final beams = beamsFor(6, 8, 12, DurationType.sixteenth);
      expect(beams.where((b) => b == null), isEmpty);
      expect(beams.where((b) => b == 'start').length, 2);
    });

    test('simple meters are unchanged', () {
      expect(beamsFor(3, 4, 6, DurationType.eighth),
          ['start', 'end', 'start', 'end', 'start', 'end']);
    });
  });

  group('F-02 / F-16 — accidental resolution', () {
    List<String> decisionsFor(DurationType d) {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        for (var i = 0; i < 4; i++) _n('F', 4, d: d, alter: 1.0),
      ]);
      final engine = engineFor(Staff(measures: [m]), width: 1200);
      engine.layout();
      return engine
          .layout()
          .where((p) => p.element is Note)
          .map((p) =>
              engine.accidentalDecisions[p.element]?.name ?? 'MISSING')
          .toList();
    }

    test('the rule applies to unbeamed notes', () {
      expect(decisionsFor(DurationType.quarter),
          ['show', 'hide', 'hide', 'hide']);
    });

    test('the rule also applies to BEAMED notes', () {
      expect(decisionsFor(DurationType.eighth),
          ['show', 'hide', 'hide', 'hide'],
          reason: 'F-02: cloning beamed notes broke the identity-keyed map, so '
              'four sharps were printed instead of one.');
    });

    test('a cautionary accidental is never hidden', () {
      final plain = _n('F', 4, alter: 1.0);
      final cautionary = Note(
        pitch: const Pitch(step: 'F', octave: 4, alter: 1.0),
        duration: const Duration(DurationType.quarter),
        accidentalParenthesis: AccidentalParenthesis.parentheses,
      );
      final m = _bar([Clef(clefType: ClefType.treble), plain, cautionary]);
      final engine = engineFor(Staff(measures: [m]));
      engine.layout();
      expect(engine.accidentalDecisions[cautionary], AccidentalDisplay.show,
          reason: 'F-16: the resolver ignored accidentalParenthesis and threw '
              'the courtesy accidental away.');
    });
  });

  group('F-15 — lyrics claim horizontal space', () {
    double spacingWith(String? syllable) {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        for (var i = 0; i < 3; i++)
          _n('C', 4,
              syllables: syllable == null
                  ? null
                  : [Syllable(text: syllable, type: SyllableType.single)]),
      ]);
      final notes = engineFor(Staff(measures: [m]), width: 100000)
          .layout()
          .where((p) => p.element is Note)
          .toList();
      return notes[1].position.dx - notes[0].position.dx;
    }

    test('a long syllable widens the gap', () {
      final bare = spacingWith(null);
      final short = spacingWith('a');
      final long = spacingWith('Extraordinarily');
      expect(short, greaterThanOrEqualTo(bare));
      expect(long, greaterThan(short * 1.5),
          reason: 'F-15: syllable width was ignored entirely, so a 15-letter '
              'word produced exactly the spacing of no lyric at all.');
    });
  });

  group('F-09 — Measure capacity is voice aware', () {
    test('two full voices fit in one bar', () {
      final m = Measure();
      m.add(TimeSignature(numerator: 4, denominator: 4));
      expect(() {
        for (var i = 0; i < 4; i++) {
          m.add(_n('C', 5, voice: 1));
        }
        for (var i = 0; i < 4; i++) {
          m.add(_n('C', 4, voice: 2));
        }
      }, returnsNormally,
          reason: 'F-09: the capacity check summed every voice together and '
              'rejected legitimate polyphony written through the public API.');
    });

    test('a single voice still cannot overflow', () {
      final m = Measure();
      m.add(TimeSignature(numerator: 4, denominator: 4));
      for (var i = 0; i < 4; i++) {
        m.add(_n('C', 5, voice: 1));
      }
      expect(() => m.add(_n('D', 5, voice: 1)),
          throwsA(isA<MeasureCapacityException>()));
    });
  });

  group('F-10 — invalid input fails loudly, never silently', () {
    test('an unknown step is rejected by the MusicXML parser', () {
      const xml = '<score-partwise version="4.0">'
          '<part-list><score-part id="P1"/></part-list>'
          '<part id="P1"><measure number="1">'
          '<note><pitch><step>H</step><octave>4</octave></pitch>'
          '<type>quarter</type></note>'
          '</measure></part></score-partwise>';
      expect(() => MusicXMLParser.parseMusicXML(xml),
          throwsA(isA<FormatException>()),
          reason: 'it used to reach the model and crash later with '
              '"Null check operator used on a null value".');
    });

    test('an absurd octave is rejected too', () {
      const xml = '<score-partwise version="4.0">'
          '<part-list><score-part id="P1"/></part-list>'
          '<part id="P1"><measure number="1">'
          '<note><pitch><step>C</step><octave>999999</octave></pitch>'
          '<type>quarter</type></note>'
          '</measure></part></score-partwise>';
      expect(() => MusicXMLParser.parseMusicXML(xml),
          throwsA(isA<FormatException>()));
    });
  });

  group('F-19 / F-20 / F-21 — pitch arithmetic', () {
    test('intervals no longer double count the alteration', () {
      const c4 = Pitch(step: 'C', octave: 4);
      expect(PitchUtils.intervalInSemitones(c4, const Pitch(step: 'C', octave: 4, alter: 1)), 1.0);
      expect(PitchUtils.intervalInSemitones(c4, const Pitch(step: 'E', octave: 4, alter: -1)), 3.0);
      expect(PitchUtils.intervalInSemitones(c4, const Pitch(step: 'E', octave: 4)), 4.0);
      expect(PitchUtils.intervalInSemitones(c4, const Pitch(step: 'C', octave: 5)), 12.0);
    });

    test('negative octaves parse correctly', () {
      final p = Pitch.fromString('C-1');
      expect(p.octave, -1);
      expect(p.midiNumber, 0);
    });

    test('equal pitches compare equal however they were spelled', () {
      const a = Pitch(step: 'F', octave: 4, alter: 1.0);
      final b = Pitch.withAccidental(
          step: 'F', octave: 4, accidentalType: AccidentalType.sharp);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('durations have value equality', () {
      expect(Duration(DurationType.quarter, dots: 1),
          Duration(DurationType.quarter, dots: 1));
      expect(Duration(DurationType.quarter, dots: 1).hashCode,
          Duration(DurationType.quarter, dots: 1).hashCode);
      expect(const Duration(DurationType.quarter),
          isNot(Duration(DurationType.quarter, dots: 1)));
    });
  });

  group('F-06 / F-07 — MusicXML timing', () {
    test('divisions drive the duration when <type> is absent', () {
      const xml = '<score-partwise version="4.0">'
          '<part-list><score-part id="P1"/></part-list>'
          '<part id="P1"><measure number="1">'
          '<attributes><divisions>4</divisions>'
          '<time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>'
          '<note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>16</duration></note>'
          '</measure></part></score-partwise>';
      final staff = MusicXMLParser.parseMusicXML(xml);
      final note = staff.measures.first.elements.whereType<Note>().first;
      expect(note.duration.type, DurationType.whole,
          reason: 'F-06: <duration>/<divisions> was ignored and every '
              'untyped note became a quarter.');
    });

    test('backup separates simultaneous voices', () {
      const xml = '<score-partwise version="4.0">'
          '<part-list><score-part id="P1"/></part-list>'
          '<part id="P1"><measure number="1">'
          '<attributes><divisions>4</divisions>'
          '<time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>'
          '<note><pitch><step>C</step><octave>5</octave></pitch>'
          '<duration>8</duration><type>half</type></note>'
          '<note><pitch><step>D</step><octave>5</octave></pitch>'
          '<duration>8</duration><type>half</type></note>'
          '<backup><duration>16</duration></backup>'
          '<note><pitch><step>C</step><octave>4</octave></pitch>'
          '<duration>16</duration><type>whole</type></note>'
          '</measure></part></score-partwise>';
      final staff = MusicXMLParser.parseMusicXML(xml);
      final measure = staff.measures.first;
      expect(measure, isA<MultiVoiceMeasure>(),
          reason: 'F-07: <backup> was a no-op, so the two voices were laid '
              'end to end and the bar carried twice its value.');
    });
  });

  group('F-17 — MEI reads every section', () {
    test('two sections yield two measures', () {
      const mei = '<mei xmlns="http://www.music-encoding.org/ns/mei">'
          '<music><body><mdiv><score>'
          '<scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" '
          'clef.line="2" meter.count="4" meter.unit="4"/></staffGrp></scoreDef>'
          '<section n="1"><measure n="1"><staff n="1"><layer n="1">'
          '<note pname="c" oct="4" dur="4"/></layer></staff></measure></section>'
          '<section n="2"><measure n="2"><staff n="1"><layer n="1">'
          '<note pname="g" oct="4" dur="4"/></layer></staff></measure></section>'
          '</score></mdiv></body></music></mei>';
      final staff = MEIParser.parseMEI(mei);
      expect(staff.measures.length, 2,
          reason: 'F-17: only the first <section> was parsed, so the rest of '
              'the piece disappeared without a warning.');
    });
  });

  group('L11 — nothing is drawn above the top of the canvas', () {
    test('high ledger-line notes fit', () {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        _n('C', 4),
        _n('C', 8),
        _n('C', 9),
      ]);
      final engine = engineFor(Staff(measures: [m]));
      final positioned = engine.layout();
      final height = engine.calculateTotalHeight(positioned);
      final inset = engine.contentTopOverflow(positioned);

      final highest =
          positioned.map((p) => p.position.dy).reduce(math.min);
      expect(highest + inset, greaterThan(0),
          reason: 'the audit measured C9 at y = -114 on a canvas 192 px tall: '
              'the note was simply cut off the top with no scroll and no '
              'warning.');
      expect(height, greaterThan(inset));
    });

    test('low ledger-line notes fit', () {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        _n('C', 0),
        _n('C', 1),
      ]);
      final engine = engineFor(Staff(measures: [m]));
      final positioned = engine.layout();
      final lowest = positioned.map((p) => p.position.dy).reduce(math.max);
      final height = engine.calculateTotalHeight(positioned) +
          engine.contentTopOverflow(positioned);
      expect(lowest, lessThan(height));
    });

    test('a boxed rehearsal mark reserves its own headroom', () {
      final plain = _bar([Clef(clefType: ClefType.treble), _n('C', 5)]);
      final withMark = _bar([
        Clef(clefType: ClefType.treble),
        MusicText(
          text: 'A',
          type: TextType.rehearsal,
          placement: TextPlacement.above,
        ),
        _n('C', 5),
      ]);

      final plainEngine = engineFor(Staff(measures: [plain]));
      final markEngine = engineFor(Staff(measures: [withMark]));
      final plainInset =
          plainEngine.contentTopOverflow(plainEngine.layout());
      final markInset = markEngine.contentTopOverflow(markEngine.layout());

      expect(markInset, greaterThan(plainInset),
          reason: 'the box used to be drawn entirely above the canvas edge.');
    });

    test('ordinary music needs no extra headroom', () {
      final m = _bar([
        Clef(clefType: ClefType.treble),
        for (var i = 0; i < 4; i++) _n('CDEFGAB'[i % 7], 4),
      ]);
      final engine = engineFor(Staff(measures: [m]));
      expect(engine.contentTopOverflow(engine.layout()), 0.0,
          reason: 'the inset must not inflate every score.');
    });
  });

  group('F-25b — tuplet contents are first-class', () {
    test('a chord inside a tuplet gets geometry', () {
      final chord = Chord(
        notes: [_n('C', 5, d: DurationType.eighth), _n('E', 5, d: DurationType.eighth)],
        duration: const Duration(DurationType.eighth),
      );
      final tuplet = Tuplet(
        elements: [
          _n('G', 4, d: DurationType.eighth),
          chord,
          _n('B', 4, d: DurationType.eighth),
        ],
        actualNotes: 3,
        normalNotes: 2,
      );
      final engine = engineFor(Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), tuplet])
      ]));
      engine.layout();
      for (final note in chord.notes) {
        expect(engine.noteXPositions[note], isNotNull,
            reason: 'a chord inside a tuplet used to fall through every render '
                'branch and simply not be drawn.');
      }
    });

    test('a nested tuplet gets geometry and widens its parent', () {
      final innerNotes = [
        _n('C', 5, d: DurationType.sixteenth),
        _n('D', 5, d: DurationType.sixteenth),
        _n('E', 5, d: DurationType.sixteenth),
      ];
      final inner = Tuplet(
          elements: innerNotes, actualNotes: 3, normalNotes: 2, isNested: true);
      final outer = Tuplet(
        elements: [
          _n('G', 4, d: DurationType.eighth),
          inner,
          _n('B', 4, d: DurationType.eighth),
        ],
        actualNotes: 3,
        normalNotes: 2,
      );
      final flat = Tuplet(
        elements: [
          _n('G', 4, d: DurationType.eighth),
          _n('A', 4, d: DurationType.eighth),
          _n('B', 4, d: DurationType.eighth),
        ],
        actualNotes: 3,
        normalNotes: 2,
      );

      final nestedEngine = engineFor(Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), outer])
      ]));
      nestedEngine.layout();
      for (final note in innerNotes) {
        expect(nestedEngine.noteXPositions[note], isNotNull);
      }
      expect(nestedEngine.elementWidth(outer),
          greaterThan(nestedEngine.elementWidth(flat)),
          reason: 'a nested tuplet contributes its own content width, not one '
              'slot; otherwise it overlaps whatever follows.');
    });

    test('totalDuration sums the real content, not the first note x N', () {
      // A 3:2 triplet of eighth + quarter + eighth is legal and common.
      final mixed = Tuplet(
        elements: [
          _n('C', 5, d: DurationType.eighth),
          _n('D', 5),
          _n('E', 5, d: DurationType.eighth),
        ],
        actualNotes: 3,
        normalNotes: 2,
      );
      // written = 1/8 + 1/4 + 1/8 = 0.5 ; x 2/3 = 1/3
      expect(mixed.totalDuration, closeTo(0.5 * 2 / 3, 1e-9),
          reason: 'it used to read only the FIRST note and multiply by '
              'actualNotes, so a mixed-duration tuplet was measured wrong and '
              'every onset after it shifted.');

      // Rests only: used to collapse to 0.0 because whereType<Note>() was empty.
      final rests = Tuplet(
        elements: [
          Rest(duration: const Duration(DurationType.eighth)),
          Rest(duration: const Duration(DurationType.eighth)),
          Rest(duration: const Duration(DurationType.eighth)),
        ],
        actualNotes: 3,
        normalNotes: 2,
      );
      expect(rests.totalDuration, closeTo(0.375 * 2 / 3, 1e-9));

      // Chords only: same trap.
      final chords = Tuplet(
        elements: [
          for (var i = 0; i < 3; i++)
            Chord(
              notes: [_n('C', 5, d: DurationType.eighth), _n('E', 5, d: DurationType.eighth)],
              duration: const Duration(DurationType.eighth),
            ),
        ],
        actualNotes: 3,
        normalNotes: 2,
      );
      expect(chords.totalDuration, closeTo(0.375 * 2 / 3, 1e-9),
          reason: 'a chord sounds once, not once per note.');
    });

    test('a mixed-duration tuplet does not shift the following onsets', () {
      final after = _n('G', 4);
      final m = _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        Tuplet(
          elements: [
            _n('C', 5, d: DurationType.eighth),
            _n('D', 5),
            _n('E', 5, d: DurationType.eighth),
          ],
          actualNotes: 3,
          normalNotes: 2,
        ),
        after,
      ]);
      final positioned = engineFor(Staff(measures: [m]), width: 1200).layout();
      final onset = positioned
          .firstWhere((p) => identical(p.element, after))
          .onset;
      expect(onset, closeTo(0.5 * 2 / 3, 1e-9));
    });

    test('a note inside a tuplet keeps its lyrics and identity', () {
      final sung = _n('C', 5,
          d: DurationType.eighth,
          syllables: [Syllable(text: 'Ky', type: SyllableType.initial)]);
      final tuplet = Tuplet(
        elements: [
          sung,
          _n('D', 5, d: DurationType.eighth),
          _n('E', 5, d: DurationType.eighth),
        ],
        actualNotes: 3,
        normalNotes: 2,
      );
      final engine = engineFor(Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), tuplet])
      ]));
      engine.layout();
      // The renderer used to rebuild tuplet notes with a copy constructor that
      // omitted syllables, tab data, grace status and cautionary accidentals.
      expect(identical(tuplet.elements.first, sung), isTrue);
      expect(sung.syllables?.first.text, 'Ky');
      expect(engine.noteXPositions[sung], isNotNull);
    });
  });

  group('F-22 — very long scores still render', () {
    test('past a thousand systems the painter keeps drawing', () {
      final measures = <Measure>[
        for (var b = 0; b < 1200; b++)
          _bar([
            if (b == 0) Clef(clefType: ClefType.treble),
            _n('C', 4, d: DurationType.whole),
          ]),
      ];
      final positioned = engineFor(Staff(measures: measures), width: 220)
          .layout();
      final maxSystem = positioned.map((p) => p.system).reduce(math.max);
      expect(maxSystem, greaterThan(999));
      // The painter must be able to address them all.
      final painterVisible = maxSystem.clamp(0, maxSystem);
      expect(painterVisible, maxSystem);
    });
  });
}

double _spanDotted(
  LayoutEngine Function(Staff, {double width, double ss}) engineFor,
  DurationType d,
) {
  final m = Measure();
  m.elements.add(Clef(clefType: ClefType.treble));
  for (var i = 0; i < 4; i++) {
    m.elements.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: Duration(d, dots: 1),
    ));
  }
  final notes = engineFor(Staff(measures: [m]), width: 100000)
      .layout()
      .where((p) => p.element is Note)
      .toList();
  return notes.last.position.dx - notes.first.position.dx;
}
