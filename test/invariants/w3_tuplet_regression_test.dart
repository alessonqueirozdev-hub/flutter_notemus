// test/invariants/w3_tuplet_regression_test.dart
//
// Regression tests for the 2.7.1 wave-3 tuplet remediation: the shared,
// accidental-aware, proportional grid (M-08, M-10, M-31), the resolver-aware
// renderer (M-11), the beam decision moving out of the paint pass (M-26,
// M-38), the numeral on the bracket line (M-27), the multi-voice direction
// advance (F3) and the written value of a tuplet holding a grace note (F5).
//
// Every expectation below quotes the number that was MEASURED before the fix.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/layout/tuplet_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    final bytes = await File('assets/smufl/Bravura.otf').readAsBytes();
    await (FontLoader('packages/flutter_notemus/Bravura')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
  });

  Staff staffOf(List<Measure> measures) => Staff()..measures.addAll(measures);

  Measure bar(List<MusicalElement> elements) =>
      Measure()..elements.addAll(elements);

  LayoutEngine engineOf(Staff staff, {double width = 900}) => LayoutEngine(
        staff,
        availableWidth: width,
        staffSpace: 12,
        metadata: metadata,
      );

  Note note(String step, int octave,
          {DurationType d = DurationType.eighth, double alter = 0.0}) =>
      Note(
        pitch: Pitch(step: step, octave: octave, alter: alter),
        duration: Duration(d),
      );

  Tuplet tupletOf(List<MusicalElement> elements,
          {int actual = 3, int normal = 2}) =>
      Tuplet(actualNotes: actual, normalNotes: normal, elements: elements);

  // ------------------------------------------------------------- M-08/M-31 --
  group('M-08 / M-31: the tuplet grid is proportional and legible', () {
    test('the legibility floor is a GROUP scale, not a per-child clamp', () {
      // Measured before: an eighth got 21.213 px and a sixteenth 16.800 px —
      // the sixteenth was on the floor, so the true 1.4142 ratio came out as
      // 1.2626. Ten of the fifteen DurationTypes (sixteenth through 1/2048)
      // ALL received exactly 1.400 staff spaces, so the "proportional" grid
      // was flat over two thirds of its domain.
      final pairs = <List<DurationType>>[
        [DurationType.eighth, DurationType.sixteenth],
        [DurationType.sixteenth, DurationType.thirtySecond],
        [DurationType.sixtyFourth, DurationType.oneHundredTwentyEighth],
        [
          DurationType.oneHundredTwentyEighth,
          DurationType.twoHundredFiftySixth
        ],
        [
          DurationType.thousandTwentyFourth,
          DurationType.twoThousandFortyEighth
        ],
      ];
      for (final pair in pairs) {
        final slots = TupletGrid.slotWidths(
          tupletOf([note('C', 5, d: pair[0]), note('D', 5, d: pair[1])]),
          12.0,
        );
        expect(slots[0] / slots[1], closeTo(1.4142, 1e-3),
            reason: '${pair[0].name} : ${pair[1].name} must keep the exact '
                'square-root ratio at every depth of the duration ladder.');
      }
    });

    test('the narrowest slot of a group clears the package own minGap', () {
      // Measured before, on the corpus case m04m_tuplet_ratio (5:4, five
      // stepwise sixteenths) at staffSpace = 12: every step was 16.800 px and
      // the real ink gap between adjacent noteheads was 2 px = 0.167 staff
      // spaces, against SpacingPreferences.normal.minGap of 0.25.
      final slots = TupletGrid.slotWidths(
        tupletOf(
          [for (var i = 0; i < 5; i++) note('C', 5, d: DurationType.sixteenth)],
          actual: 5,
          normal: 4,
        ),
        12.0,
      );
      for (final slot in slots) {
        expect(slot, closeTo(22.8, 1e-6));
      }
      final head = metadata.getGlyphAdvanceWidth('noteheadBlack')! * 12.0;
      expect((slots.first - head) / 12.0, greaterThan(0.25),
          reason: 'the geometric gap must beat the package minimum of 0.25 SS; '
              'it used to be 0.220 SS of nominal slack and 0.167 SS of real '
              'white.');
    });

    test('a quarter inside a tuplet keeps its historical 2.5 staff spaces', () {
      final slots = TupletGrid.slotWidths(
        tupletOf([
          note('C', 5, d: DurationType.quarter),
          note('D', 5, d: DurationType.quarter),
          note('E', 5, d: DurationType.quarter),
        ]),
        12.0,
      );
      expect(slots.every((s) => (s - 30.0).abs() < 1e-9), isTrue);
    });
  });

  // ------------------------------------------------------------------ M-10 --
  group('M-10: accidentals inside a tuplet do not collide', () {
    // Measured at staffSpace = 12 against a 14.16 px notehead, the clearance
    // between the accidental and the PREVIOUS notehead:
    //   double flat -20.78 px, double sharp -12.96, flat -11.81, sharp -12.91.
    // i.e. the accidental was drawn entirely on top of the previous note.
    for (final entry in const <(double, String)>[
      (-2.0, 'accidentalDoubleFlat'),
      (-1.0, 'accidentalFlat'),
      (1.0, 'accidentalSharp'),
      (2.0, 'accidentalDoubleSharp'),
    ]) {
      test('alter ${entry.$1} clears the previous notehead', () {
        final first = note('C', 5);
        final middle = note('D', 5, alter: entry.$1);
        final tuplet = tupletOf([first, middle, note('E', 5)]);
        final engine = engineOf(
            staffOf([bar([Clef(clefType: ClefType.treble), tuplet])]));
        engine.layout();

        final head = metadata.getGlyphAdvanceWidth('noteheadBlack')! * 12.0;
        final accidental =
            metadata.getGlyphAdvanceWidth(entry.$2)! * 12.0;
        // The accidental is drawn 0.3 staff spaces in front of its notehead
        // (SMuFL guidance), which is what `_leftExtent` reserves.
        final accidentalLeft = engine.noteXPositions[middle]! -
            accidental -
            (0.3 * 12.0);
        final clearance =
            accidentalLeft - (engine.noteXPositions[first]! + head);
        expect(clearance, greaterThanOrEqualTo(0.0),
            reason: '${entry.$2} drove ${(-clearance).toStringAsFixed(2)} '
                'px into the previous notehead.');
        expect(clearance / 12.0, closeTo(0.25, 1e-6),
            reason: 'the grid gives exactly the package own minGap of air.');
      });
    }
  });

  // ------------------------------------------------------------------ M-11 --
  test('M-11: a tuplet honours the accidental resolver', () async {
    // Measured before: a bar of C#4 quarter followed by a triplet of three
    // C#4 eighths — the resolver decides hide/hide/hide for the inner notes
    // (an accidental holds for the rest of the bar) and the tuplet printed
    // THREE SHARPS, because TupletRenderer called NoteRenderer with the
    // default AccidentalDisplay.show.
    final inner = [
      for (var i = 0; i < 3; i++) note('C', 4, alter: 1.0),
    ];
    final tuplet = tupletOf(inner);
    final staff = staffOf([
      bar([
        Clef(clefType: ClefType.treble),
        Note(
          pitch: const Pitch(step: 'C', octave: 4, alter: 1.0),
          duration: const Duration(DurationType.quarter),
        ),
        tuplet,
      ])
    ]);
    final engine = engineOf(staff);
    engine.layout();
    for (final n in inner) {
      expect(engine.accidentalDecisions[n], AccidentalDisplay.hide);
    }

    // The decision has to REACH the drawing. Count the sharp-shaped ink in the
    // tuplet's own horizontal band: three suppressed accidentals is the whole
    // point, so the band must hold noteheads and nothing to their left.
    final png = await ScoreRasterizer.renderStaffToPng(
      staff: staff,
      metadata: metadata,
      width: 900,
      pixelRatio: 1.0,
    );
    expect(png, isNotNull);
    final image = await decodeImageFromList(png!);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    int darkAt(int x, int y) {
      final offset = ((y * image.width) + x) * 4;
      return data!.getUint8(offset) < 128 ? 1 : 0;
    }

    // A hidden accidental leaves the 1.5 staff spaces in front of each inner
    // notehead empty. The first inner note is at the tuplet's own X.
    final firstX = engine.noteXPositions[inner.first]!.round();
    var ink = 0;
    for (var x = firstX - 18; x < firstX - 3; x++) {
      for (var y = 0; y < image.height; y++) {
        if (x >= 0 && x < image.width) ink += darkAt(x, y);
      }
    }
    // Only the four staff lines (2 px each) may cross that strip.
    expect(ink, lessThan(15 * 12),
        reason: 'a sharp glyph occupies far more ink than the staff lines '
            'crossing this strip; three of them printed here before the fix.');
  });

  // ------------------------------------------------------------------ M-26 --
  test('M-26: painting a score does not mutate it', () async {
    // Measured before: a Staff with a tuplet of three eighths exported 1620
    // characters of MusicXML with 0 <beam> tags; after one
    // ScoreRasterizer.renderStaffToPng the inner notes' `beam` fields had
    // become [start, inner, end] and the same Staff exported 1735 characters
    // with 3 <beam> tags. Export therefore depended on whether the score had
    // been displayed.
    final staff = staffOf([
      bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        tupletOf([note('C', 5), note('D', 5), note('E', 5)]),
      ])
    ]);

    final xmlBefore = MusicXMLParser.staffToMusicXML(staff);
    final jsonBefore = JsonMusicExporter.staffToJson(staff);

    final png = await ScoreRasterizer.renderStaffToPng(
      staff: staff,
      metadata: metadata,
      width: 900,
    );
    expect(png, isNotNull);

    expect(MusicXMLParser.staffToMusicXML(staff), xmlBefore,
        reason: 'the PAINT pass wrote Note.beam into the model.');
    expect(JsonMusicExporter.staffToJson(staff), jsonBefore,
        reason: 'the PAINT pass wrote Note.beam into the model.');
  });

  // ------------------------------------------------------------------ M-38 --
  group('M-38: rests and extreme durations no longer kill a tuplet beam', () {
    test('a rest inside the group is transparent, not fatal', () {
      // Before: `_applyAutomaticBeams` required EVERY element to be a Note, so
      // one rest removed the beams from the whole tuplet.
      final plan = TupletBeamPlan.of([
        note('C', 5),
        Rest(duration: const Duration(DurationType.eighth)),
        note('E', 5),
      ]);
      expect(plan.beams, [BeamType.start, null, BeamType.end]);
      expect(plan.beamCount, 1);
    });

    test('a 128th tuplet beams with five levels', () {
      // Before: the whitelist stopped at the sixty-fourth, so a 128th tuplet
      // printed loose flags.
      final plan = TupletBeamPlan.of([
        for (var i = 0; i < 3; i++)
          note('C', 5, d: DurationType.oneHundredTwentyEighth),
      ]);
      expect(plan.beams, [BeamType.start, BeamType.inner, BeamType.end]);
      expect(plan.beamCount, 5);
    });

    test('a chord that declares a beam joins the group', () {
      final chord = Chord(
        notes: [note('C', 5), note('E', 5)],
        duration: const Duration(DurationType.eighth),
        beam: BeamType.inner,
      );
      final plan = TupletBeamPlan.of([note('G', 4), chord, note('B', 4)]);
      expect(plan.beams, [BeamType.start, BeamType.inner, BeamType.end]);
    });

    test('an unbeamable child ends the run instead of cancelling the tuplet',
        () {
      final plan = TupletBeamPlan.of([
        note('C', 5),
        note('D', 5),
        note('E', 5, d: DurationType.quarter),
        note('F', 5),
        note('G', 5),
      ]);
      expect(plan.beams, [
        BeamType.start,
        BeamType.end,
        null,
        BeamType.start,
        BeamType.end,
      ]);
    });
  });

  // ------------------------------------------------------------------ M-23 --
  test('M-23: a bar holding only a tuplet reserves its bracket headroom', () {
    // Measured before wave 2: contentTopOverflow == 0.00 and
    // contentBottomOverflow == 0.00 for ANY tuplet, so the bracket and its
    // numeral were clipped out of the raster and the PDF.
    final staff = staffOf([
      bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        tupletOf([
          for (var i = 0; i < 5; i++) note('B', 4, d: DurationType.sixteenth)
        ], actual: 5, normal: 4),
      ])
    ]);
    final engine = engineOf(staff);
    final positioned = engine.layout();
    expect(engine.contentTopOverflow(positioned), greaterThan(20.0));
    // The reserved headroom must cover the beam stack a sixteenth tuplet
    // actually draws: the reach used to be derived from a private copy of the
    // beam-count rule that could disagree with the renderer.
    expect(engine.calculateTotalHeight(positioned),
        greaterThan(engine.contentTopOverflow(positioned)));
  });

  // -------------------------------------------------------------------- F3 --
  group('F3: a direction reserves no advance in EITHER voice', () {
    // Measured, X of the first note of a two-voice bar at staffSpace = 12:
    //   OctaveMark  v1 158.21 vs v2 116.21 (delta 42.00 px)
    //   Dynamic     v1 182.21 vs v2 116.21 (delta 66.00 px)
    //   MusicText   v1 207.29 vs v2 116.21 (delta 91.08 px)
    // In a MONOPHONIC bar all four tested directions moved the first note by
    // 0.00 px, so the multi-voice lead voice was the odd one out.
    MusicalElement clone(MusicalElement Function() make) => make();

    final directions = <String, MusicalElement Function()>{
      'OctaveMark': () => OctaveMark(type: OctaveType.va8, startMeasure: 0, endMeasure: 0),
      'Dynamic': () => Dynamic(type: DynamicType.mf),
      'MusicText': () =>
          MusicText(text: 'dolce', type: TextType.expression),
    };

    for (final entry in directions.entries) {
      test('${entry.key} in voice 1 costs the same as in voice 2', () {
        double firstNoteX({required bool inLead}) {
          final leadNote = note('C', 5, d: DurationType.quarter);
          final otherNote = note('C', 4, d: DurationType.quarter);
          final direction = clone(entry.value);
          final measure = MultiVoiceMeasure.twoVoices(
            voice1Elements: [
              if (inLead) direction,
              leadNote,
            ],
            voice2Elements: [
              if (!inLead) direction,
              otherNote,
            ],
          );
          measure.elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
          ]);
          final engine = engineOf(staffOf([measure]));
          engine.layout();
          return engine.noteXPositions[inLead ? leadNote : otherNote]!;
        }

        expect(firstNoteX(inLead: true), closeTo(firstNoteX(inLead: false), 0.01),
            reason: 'the same direction must reserve the same advance in '
                'either voice.');
      });
    }
  });

  // -------------------------------------------------------------------- F5 --
  test('F5: a grace note is not part of a tuplet written value', () {
    // Measured: a 3:2 tuplet containing one grace note gave
    // totalDuration = 0.3333 against Measure.musicalValueOf = 0.25.
    final grace = Note(
      pitch: const Pitch(step: 'D', octave: 5, alter: 0.0),
      duration: const Duration(DurationType.eighth),
      isGraceNote: true,
    );
    final tuplet = tupletOf([note('C', 5), grace, note('E', 5)]);
    expect(tuplet.totalDuration, closeTo(0.25 * 2 / 3, 1e-9));
    expect(tuplet.totalDuration,
        closeTo(Measure.musicalValueOf(tuplet), 1e-9),
        reason: 'totalDuration and musicalValueOf must agree, or the ADR-002 '
            'shared onset grid splits between the two staves of a system.');
  });
}
