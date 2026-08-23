// test/invariants/w5_stale_model_reads_guard_test.dart
//
// The three stale reads of `Note.beam` / `Chord.beam` that ADR-005 left behind,
// pinned so they cannot come back.
//
// `test/invariants/adr005_guard_test.dart` is the STRUCTURAL guard: it fails
// the build on a read that is not on its allow-list. This file is the
// BEHAVIOURAL half - it pins what each of the three sites now answers, so a
// future "simplification" that routes one of them back through the model shows
// up as a wrong answer and not just as a lint.
//
// Each site was found by the 2.7.2 final audit, and each had the same shape:
// code that was correct while `LayoutEngine` stamped its decision onto the
// model, and that read `null` for every automatically beamed note the day it
// stopped.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/layout/tuplet_grid.dart';

import '../support/ink_probe.dart';

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

  Note eighth(String step, int octave) => Note(
        pitch: Pitch(step: step, octave: octave),
        duration: Duration(DurationType.eighth),
      );

  Chord eighthChord(List<String> steps, int octave) => Chord(
        notes: [for (final s in steps) eighth(s, octave)],
        duration: Duration(DurationType.eighth),
      );

  LayoutEngine engineOf(Staff staff, {double width = 900}) => LayoutEngine(
        staff,
        availableWidth: width,
        staffSpace: 12,
        metadata: metadata,
      );

  // ------------------------------------------------------------ (a) core --
  group('TupletBracket.shouldShow takes the beam decision, it does not guess',
      () {
    test('a fully beamed triplet hides its bracket ONLY when told the truth',
        () {
      final notes = [eighth('C', 5), eighth('D', 5), eighth('E', 5)];
      final tuplet =
          Tuplet(actualNotes: 3, normalNotes: 2, elements: [...notes]);
      final staff = Staff()
        ..measures.add(Measure()
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 2, denominator: 4),
            tuplet,
          ]));
      final engine = engineOf(staff)..layout();

      // ADR-005: laying the score out leaves the model alone.
      expect(
        notes.map((n) => n.beam).toList(),
        [null, null, null],
        reason: 'the engine must not stamp its decision onto the model',
      );
      // ...and publishes the decision as a value instead.
      //
      // NOTE the oracle composed here. `LayoutEngine.beamOf` consults `beams`
      // (ordinary groups) and the author's hint, but NOT `tupletBeams`, so it
      // answers `null` for a note inside a tuplet even though the engine did
      // decide. Measured on this very fixture: `engine.beamOf(notes[0])` is
      // `null` while `engine.tupletBeams[notes[0]]` is `BeamType.start`. That
      // is a gap in `beamOf` itself, not in this test - see the note filed
      // against `layout_engine.dart` - and until it is closed every caller of
      // `beamOf` that can see a tuplet has to compose the two maps by hand.
      BeamType? beamOf(Note note) =>
          engine.tupletBeams[note] ?? engine.beamOf(note);
      expect(
        notes.map(beamOf).toList(),
        [BeamType.start, BeamType.inner, BeamType.end],
      );

      const bracket = TupletBracket();

      // Asked WITHOUT the layout's answer, `shouldShow` can only see the
      // author's hint (there is none) and returns the conservative answer.
      expect(bracket.shouldShow(tuplet.elements), isTrue);

      // Asked WITH it, Behind Bars p.201 applies: a fully beamed tuplet shows
      // the numeral alone. Before the fix this returned `true` here too,
      // because `note.beam` was null on all three notes - a bracket drawn
      // across a fully beamed triplet.
      expect(
        bracket.shouldShow(tuplet.elements, beamOf: beamOf),
        isFalse,
      );
    });

    test('a hand-authored beam still hides the bracket with no engine at all',
        () {
      // `BeamingMode.manual` is the case ADR-005 keeps `Note.beam` writable
      // for, so the no-oracle fallback must honour it.
      final notes = [eighth('C', 5), eighth('D', 5), eighth('E', 5)]
        ..[0].beam = BeamType.start
        ..[1].beam = BeamType.inner
        ..[2].beam = BeamType.end;
      const bracket = TupletBracket();
      expect(bracket.shouldShow(notes), isFalse);
    });

    test('a rest in the group always shows the bracket', () {
      final elements = <MusicalElement>[
        eighth('C', 5),
        Rest(duration: Duration(DurationType.eighth)),
        eighth('E', 5),
      ];
      const bracket = TupletBracket();
      expect(bracket.shouldShow(elements), isTrue);
      expect(
        bracket.shouldShow(elements, beamOf: (_) => BeamType.inner),
        isTrue,
        reason: 'a rest is not a note; the group is not "fully beamed"',
      );
    });
  });

  // ----------------------------------------------------- (b) interaction --
  group('ScoreHitTester reports the ENGINE\'s beam, not the author\'s hint',
      () {
    test('an automatically beamed eighth gets no flag overhang in its box',
        () {
      Staff staffOf({required bool autoBeaming}) => Staff()
        ..measures.add(Measure(autoBeaming: autoBeaming)
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            eighth('C', 5),
            eighth('D', 5),
            eighth('E', 5),
            eighth('F', 5),
          ]));

      final beamedStaff = staffOf(autoBeaming: true);
      final looseStaff = staffOf(autoBeaming: false);

      final beamedEngine = engineOf(beamedStaff);
      final looseEngine = engineOf(looseStaff);
      final beamedElements = beamedEngine.layout();
      final looseElements = looseEngine.layout();

      final beamedNote = beamedStaff.measures.first.elements
          .whereType<Note>()
          .first;
      final looseNote =
          looseStaff.measures.first.elements.whereType<Note>().first;

      // Neither model was written to; the two staves differ only in what the
      // ENGINE decided. That is the whole point: before the fix, both notes
      // reported `beam == null` and the two boxes came out identical.
      expect(beamedNote.beam, isNull);
      expect(looseNote.beam, isNull);
      expect(beamedEngine.beamOf(beamedNote), BeamType.start);
      expect(looseEngine.beamOf(looseNote), isNull);

      Rect boxOf(
        LayoutEngine engine,
        List<PositionedElement> elements,
        Note note,
      ) {
        final tester = ScoreHitTester(
          elements: elements,
          staffSpace: 12,
          engine: engine,
        );
        final positioned = elements.firstWhere((e) => identical(e.element, note));
        return tester.boundsOf(positioned);
      }

      final beamedBox = boxOf(beamedEngine, beamedElements, beamedNote);
      final looseBox = boxOf(looseEngine, looseElements, looseNote);

      expect(
        beamedBox.width,
        lessThan(looseBox.width),
        reason: 'a beamed eighth has no flag, so its selection box must not '
            'reserve the flag glyph\'s overhang. Reading `note.beam` instead '
            'of `engine.beamOf(note)` made these two identical.',
      );
    });
  });

  // ---------------------------------------------------------- (c) layout --
  group('a Chord joins an AUTOMATIC beam inside a tuplet (M-38)', () {
    test('the plan beams three eighth chords like three eighth notes', () {
      final plan = TupletBeamPlan.of([
        eighthChord(['C', 'E', 'G'], 4),
        eighthChord(['D', 'F', 'A'], 4),
        eighthChord(['E', 'G', 'B'], 4),
      ]);
      // Measured before the fix: `[null, null, null]` and `beamCount` 0,
      // because `_carriesBeam` required a hand-authored `Chord.beam`.
      expect(plan.beams, [BeamType.start, BeamType.inner, BeamType.end]);
      expect(plan.beamCount, 1);
    });

    test('one beam is drawn across the chords, and no chord shows a flag',
        () async {
      final staff = Staff()
        ..measures.add(Measure()
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 2, denominator: 4),
            Tuplet(actualNotes: 3, normalNotes: 2, elements: [
              eighthChord(['C', 'E', 'G'], 4),
              eighthChord(['D', 'F', 'A'], 4),
              eighthChord(['E', 'G', 'B'], 4),
            ]),
          ]));

      final ink = await rasterise(staff, metadata, width: 400, staffSpace: 12);

      // Restricted to the tuplet's own columns so the clef and the meter
      // cannot be mistaken for notation of the tuplet.
      const left = 100;
      const right = 200;
      List<({int start, int end})> runsIn(int y) => [
            for (final run in ink.runsInRow(y))
              if (run.start >= left && run.end <= right) run,
          ];

      // The beam is the only thing over a tuplet that is wide and horizontal.
      // It is also SLOPED, so a single scan row cuts a chord of it rather than
      // its full length; only the middle rows carry the whole span. Find the
      // band, then measure its widest row.
      var beamTop = -1;
      var beamBottom = -1;
      var widest = 0;
      for (var y = 0; y < ink.height; y++) {
        var rowWidest = 0;
        for (final run in runsIn(y)) {
          final length = run.end - run.start + 1;
          if (length > rowWidest) rowWidest = length;
        }
        if (rowWidest > widest) widest = rowWidest;
        if (rowWidest >= 20) {
          if (beamTop < 0) beamTop = y;
          beamBottom = y;
        } else if (beamTop >= 0) {
          break;
        }
      }

      // Measured before the fix: NO run in these columns exceeded 15 px (the
      // widest was a notehead), because there was no beam at all - the three
      // chords printed three separate flags. After it the beam spans the three
      // stems, x = 129..175 at staffSpace 12, i.e. 47 px on its widest row and
      // eight rows of sloped band for a 6 px body.
      expect(
        beamTop,
        greaterThanOrEqualTo(0),
        reason: 'no wide horizontal run was found over the tuplet: the three '
            'chords are not beamed together',
      );
      expect(
        widest,
        greaterThanOrEqualTo(40),
        reason: 'the beam must span all three stems; widest run measured '
            '$widest px, and a notehead alone is about 14',
      );

      // Below the beam there must be nothing but the three bare stems, for a
      // good stretch. A flag would put 3 to 9 px of curl beside one of them,
      // which is exactly what this raster carried before the fix (three flags,
      // no beam).
      var probeRow = -1;
      for (var y = beamBottom + 1; y < beamBottom + 14; y++) {
        final runs = runsIn(y);
        if (runs.length == 3 && runs.every((r) => r.end - r.start + 1 <= 2)) {
          probeRow = y;
          break;
        }
      }
      expect(
        probeRow,
        greaterThanOrEqualTo(0),
        reason: 'expected three bare stems under the beam within 14 rows of '
            'it, found none',
      );
      for (var y = probeRow; y < probeRow + 8; y++) {
        final runs = runsIn(y);
        expect(
          runs.length,
          3,
          reason: 'expected exactly three stems at y=$y, found '
              '${runs.map((r) => '${r.start}-${r.end}').toList()}',
        );
        for (final run in runs) {
          expect(
            run.end - run.start + 1,
            lessThanOrEqualTo(2),
            reason: 'a run wider than a stem below the beam means a flag was '
                'drawn under it: ${run.start}-${run.end} at y=$y',
          );
        }
      }
    });
  });
}
