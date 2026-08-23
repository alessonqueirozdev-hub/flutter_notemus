// The hit-test box must come from the geometry the RENDERER draws.
//
// M-14 of the forensic audit: `ScoreHitTester` estimated the stem with a flat
// 3.5 staff spaces while the renderer calls
// `SMuFLPositioningEngine.calculateStemLength`, which extends the stem until it
// reaches the middle line (Behind Bars p.47) and starts it at the notehead's
// SMuFL stem anchor. MEASURED at staffSpace 12, treble, quarter notes, before
// the fix — the drawn tip fell OUTSIDE the box at every staff position tested:
//
// ```text
// staffPos  drawn stem   tip y     old box       tip outside by
//   -20     10.000 SS    57.98   138.00..188.40      80.02 px
//   -12      6.000 SS    57.98    90.00..140.40      32.02 px
//    -6      3.500 SS    51.98    54.00..104.40       2.02 px
//    +6      3.500 SS    68.02    15.60.. 66.00       2.02 px
//   +12      6.000 SS    62.02   -20.40.. 30.00      32.02 px
//   +20     10.000 SS    62.02   -68.40..-18.00      80.02 px
// ```
//
// and for chords, once wave 2 removed the 6.0 SS clamp from
// `calculateChordStemLength`, by a flat 1.30 px at every span (0, 4, 8, 14, 20
// and 28 half-positions all measured the same 1.30, because the miss is the
// chord renderer's own attachment + overlap offset).
//
// These tests re-measure the same points against the same renderer functions,
// so they fail the moment the two models drift apart again.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const staffSpace = 12.0;

  late SmuflMetadata metadata;
  late SMuFLPositioningEngine positioning;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    positioning = SMuFLPositioningEngine(metadataLoader: metadata);
  });

  /// The pitch whose treble staff position is [target] (B4 is position 0).
  Pitch pitchAt(int target) {
    const steps = 'CDEFGAB';
    final n = 34 + target; // B4 == octave 4 * 7 + index of 'B' == 34
    return Pitch(step: steps[n % 7], octave: n ~/ 7);
  }

  ({LayoutEngine engine, List<PositionedElement> elements}) layOut(
    List<MusicalElement> content,
  ) {
    final measure = Measure();
    measure.elements.addAll([Clef(clefType: ClefType.treble), ...content]);
    final engine = LayoutEngine(
      Staff(measures: [measure]),
      availableWidth: 900,
      staffSpace: staffSpace,
      metadata: metadata,
    );
    return (engine: engine, elements: engine.layout());
  }

  group('the box reaches the stem tip the renderer draws', () {
    for (final staffPosition in [-20, -12, -6, 6, 12, 20]) {
      test('single quarter note at staff position $staffPosition', () {
        final note = Note(
          pitch: pitchAt(staffPosition),
          duration: const Duration(DurationType.quarter),
        );
        final laid = layOut([note]);
        final engine = laid.engine;
        final tester = ScoreHitTester(
          elements: laid.elements,
          staffSpace: staffSpace,
          engine: engine,
        );

        final resolved = engine.noteStaffPositions[note];
        expect(resolved, staffPosition,
            reason: 'the fixture must actually sit where the test says');
        final noteY = engine.noteYPositions[note]!;
        final noteX = engine.noteXPositions[note]!;
        final stemUp = staffPosition < 0;

        // Exactly what `StemRenderer.render` computes.
        final attachment = positioning.calculateStemAttachmentOffset(
          noteheadGlyphName: 'noteheadBlack',
          stemUp: stemUp,
          staffSpace: staffSpace,
        );
        final stemLengthPx = positioning.calculateStemLength(
              staffPosition: staffPosition,
              stemUp: stemUp,
              beamCount: 0,
            ) *
            staffSpace;
        final stemStartY = noteY + attachment.dy;
        final tipY =
            stemUp ? stemStartY - stemLengthPx : stemStartY + stemLengthPx;
        final stemX = noteX + attachment.dx;

        final box = tester.boundsOf(
          laid.elements.firstWhere((e) => identical(e.element, note)),
        );

        // Residual gap, positive when the tip is still outside the box.
        final gap = stemUp ? box.top - tipY : tipY - box.bottom;
        expect(gap, lessThanOrEqualTo(0.0),
            reason: 'tip $tipY is outside $box by $gap px');

        expect(tester.hitTest(Offset(stemX, tipY))?.element, same(note),
            reason: 'a click on the very tip of the stem must select the note');
        expect(
          tester
              .hitTest(Offset(stemX, stemUp ? tipY + 1 : tipY - 1))
              ?.element,
          same(note),
          reason: 'one pixel inside the tip must select the note',
        );
        expect(
          tester.hitTest(Offset(stemX, (stemStartY + tipY) / 2))?.element,
          same(note),
          reason: 'the midpoint of the stem must select the note',
        );
      });
    }
  });

  group('the chord box reaches the chord stem tip', () {
    for (final span in [0, 4, 8, 14, 20, 28]) {
      test('chord spanning $span half-positions', () {
        const bottom = -6;
        final notes = <Note>[
          Note(
            pitch: pitchAt(bottom),
            duration: const Duration(DurationType.quarter),
          ),
          if (span != 0)
            Note(
              pitch: pitchAt(bottom + span),
              duration: const Duration(DurationType.quarter),
            ),
        ];
        final chord = Chord(
          notes: notes,
          duration: const Duration(DurationType.quarter),
        );
        final laid = layOut([chord]);
        final engine = laid.engine;
        final tester = ScoreHitTester(
          elements: laid.elements,
          staffSpace: staffSpace,
          engine: engine,
        );

        final positions = [
          for (final n in notes) engine.noteStaffPositions[n]!,
        ]..sort((a, b) => b.compareTo(a)); // highest first, as ChordRenderer

        // `ChordRenderer.resolveStemDirection`: the note furthest from the
        // middle line decides.
        final extreme =
            positions.reduce((a, b) => a.abs() >= b.abs() ? a : b);
        final stemUp = extreme < 0;
        // `stemNoteIndex = stemUp ? positions.length - 1 : 0` over that list.
        final stemPosition = stemUp ? positions.last : positions.first;
        final stemNote = notes
            .firstWhere((n) => engine.noteStaffPositions[n] == stemPosition);
        final stemNoteY = engine.noteYPositions[stemNote]!;
        final baseX = engine.noteXPositions[chord] ??
            engine.noteXPositions[stemNote]!;

        final stemLengthPx = positioning.calculateChordStemLength(
              noteStaffPositions: positions,
              stemUp: stemUp,
              beamCount: 0,
            ) *
            staffSpace;
        final stemStartY = positioning.calculateStemStartY(
          noteY: stemNoteY,
          noteheadGlyphName: 'noteheadBlack',
          stemUp: stemUp,
          staffSpace: staffSpace,
        );
        final tipY =
            stemUp ? stemStartY - stemLengthPx : stemStartY + stemLengthPx;
        final stemX = baseX +
            positioning
                .calculateStemAttachmentOffset(
                  noteheadGlyphName: 'noteheadBlack',
                  stemUp: stemUp,
                  staffSpace: staffSpace,
                )
                .dx;

        final box = tester.boundsOf(
          laid.elements.firstWhere((e) => identical(e.element, chord)),
        );
        final gap = stemUp ? box.top - tipY : tipY - box.bottom;
        expect(gap, lessThanOrEqualTo(0.0),
            reason: 'chord tip $tipY is outside $box by $gap px');
        expect(tester.hitTest(Offset(stemX, tipY))?.element, same(chord),
            reason: 'a click on the chord stem tip must select the chord');
      });
    }
  });

  // N-19 of the audit claimed that clicking a flag or a ledger line selected
  // nothing. Nobody had ever measured it; both claims turned out to be true.
  test('a click on the flag of a lone eighth note selects it', () {
    final note = Note(
      pitch: pitchAt(-6), // C4, stem up
      duration: const Duration(DurationType.eighth),
    );
    final laid = layOut([note]);
    final engine = laid.engine;
    final tester = ScoreHitTester(
      elements: laid.elements,
      staffSpace: staffSpace,
      engine: engine,
    );

    final noteX = engine.noteXPositions[note]!;
    final noteY = engine.noteYPositions[note]!;
    final attachment = positioning.calculateStemAttachmentOffset(
      noteheadGlyphName: 'noteheadBlack',
      stemUp: true,
      staffSpace: staffSpace,
    );
    final tipY = noteY +
        attachment.dy -
        positioning.calculateStemLength(
              staffPosition: -6,
              stemUp: true,
              beamCount: 1,
            ) *
            staffSpace;

    // Where `FlagRenderer.render` puts `flag8thUp`.
    final anchor = positioning.getFlagAnchor('flag8thUp');
    final flagX = noteX +
        attachment.dx -
        anchor.dx * staffSpace -
        (positioning.stemThickness / 2) * staffSpace;
    final flagBox = metadata.getGlyphInfo('flag8thUp')!.boundingBox!;
    final flagLeft = flagX + flagBox.bBoxSwX * staffSpace;
    final flagRight = flagX + flagBox.bBoxNeX * staffSpace;
    final flagTop = tipY - flagBox.bBoxNeY * staffSpace;
    final flagBottom = tipY - flagBox.bBoxSwY * staffSpace;

    // MEASURED before the fix: the flag occupied x 95.32..107.99 while the box
    // stopped at x 99.20, so the outer 8.79 px of the glyph picked nothing.
    for (final point in [
      Offset((flagLeft + flagRight) / 2, (flagTop + flagBottom) / 2),
      Offset(flagRight, (flagTop + flagBottom) / 2),
      Offset((flagLeft + flagRight) / 2, flagTop + 1),
      Offset((flagLeft + flagRight) / 2, flagBottom - 1),
    ]) {
      expect(tester.hitTest(point)?.element, same(note),
          reason: 'a click on the flag at $point must select the note');
    }
  });

  for (final spec in [
    (name: 'C6', pitch: const Pitch(step: 'C', octave: 6)),
    (name: 'A3', pitch: const Pitch(step: 'A', octave: 3)),
  ]) {
    test('a click on a ledger line of ${spec.name} selects the note', () {
      final note = Note(
        pitch: spec.pitch,
        duration: const Duration(DurationType.quarter),
      );
      final laid = layOut([note]);
      final engine = laid.engine;
      final tester = ScoreHitTester(
        elements: laid.elements,
        staffSpace: staffSpace,
        engine: engine,
      );

      final staffPosition = engine.noteStaffPositions[note]!;
      expect(StaffPositionCalculator.needsLedgerLines(staffPosition), isTrue);

      // Where `LedgerLineRenderer.render` draws them.
      final noteX = engine.noteXPositions[note]!;
      final head = metadata.getGlyphInfo('noteheadBlack')!.boundingBox!;
      final centreX =
          noteX + ((head.bBoxSwX + head.bBoxNeX) / 2) * staffSpace;
      final extension =
          metadata.getEngravingDefault('legerLineExtension', 0.4) * staffSpace;
      final half =
          ((head.bBoxNeX - head.bBoxSwX) * staffSpace) / 2 + extension;

      // MEASURED before the fix: the ledger lines ran 23.76 px wide against a
      // 18.90 px box, so 2.43 px of line at each end picked nothing.
      for (final position
          in StaffPositionCalculator.getLedgerLinePositions(staffPosition)) {
        final y = StaffPositionCalculator.toPixelY(
          position,
          staffSpace,
          laid.elements
              .firstWhere((e) => identical(e.element, note))
              .staffBaselineY,
        );
        for (final x in [centreX - half, centreX, centreX + half]) {
          expect(tester.hitTest(Offset(x, y))?.element, same(note),
              reason: 'ledger line at staff position $position, x $x');
        }
      }
    });
  }
}
