import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../layout/tuplet_grid.dart';
import '../accidental_resolver.dart' show AccidentalDisplay;
import '../../theme/music_score_theme.dart';
import '../smufl_positioning_engine.dart';
import '../staff_position_calculator.dart';
import 'base_glyph_renderer.dart';
import 'chord_renderer.dart';
import 'note_renderer.dart';
import 'rest_renderer.dart';

/// One child of a tuplet as the drawing pass sees it: where it was placed, and
/// which beam level it carries.
typedef _Participant = ({int index, Offset position, MusicalElement element});

/// Specialized renderer for tuplets and other irregular rhythmic groups.
class TupletRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final NoteRenderer noteRenderer;
  final RestRenderer restRenderer;
  final SMuFLPositioningEngine positioningEngine;

  /// Used to draw a [Chord] that lives inside a tuplet. Optional so existing
  /// callers keep compiling; when absent, the chord degrades to its top note
  /// rather than disappearing.
  final ChordRenderer? chordRenderer;

  TupletRenderer({
    required super.coordinates,
    required super.metadata,
    required this.theme,
    required super.glyphSize,
    required this.noteRenderer,
    required this.restRenderer,
    required this.positioningEngine,
    this.chordRenderer,
  });

  /// [extraOctaveShift] carries the 8va/8vb bracket span the tuplet sits in, so
  /// the inner notes are printed at the SAME staff positions the layout engine
  /// registered for them in `_registerTupletNotes` — without it the tuplet's own
  /// beam and bracket would be drawn an octave away from the noteheads under a
  /// bracket, which is how the six octave-mark types all measured identical
  /// before this parameter existed.
  ///
  /// [accidentalDecisions] is the resolver's answer for every note on the
  /// staff, threaded in from `StaffRenderer`. Without it this renderer drew
  /// every inner note with the default [AccidentalDisplay.show], and finding
  /// M-11 is exactly that: a bar of `C#4` quarter followed by a triplet of
  /// three `C#4` eighths made the resolver decide `hide, hide, hide` for the
  /// three inner notes — an accidental holds for the rest of the bar — and the
  /// tuplet printed THREE SHARPS anyway, while the identical figure written
  /// outside a tuplet was drawn correctly.
  ///
  /// [leftExtent] is `LayoutEngine.elementLeftExtent`, handed over so the grid
  /// this renderer walks is the accidental-aware grid the layout reserved space
  /// for. Passing it is not optional in production: omit it and the drawing
  /// falls back to the geometry-only grid while the layout used the wider one,
  /// which is the divergence the shared [TupletGrid] exists to prevent.
  ///
  /// [contextSmallestLeafSpaces] is `LayoutEngine.tupletContextFloor[tuplet]`
  /// — the denominator of the grid's legibility scale, measured by the LAYOUT
  /// over the whole bar and read here. It is not optional in production for the
  /// same reason [leftExtent] is not: this renderer is handed ONE tuplet and
  /// cannot see its neighbours, so left to itself it would derive the per-GROUP
  /// scale that findings M-08 / M-31 are about and draw a narrower grid than
  /// the layout reserved. Measured on a bar holding a 3:2 triplet of eighths
  /// beside a 3:2 triplet of sixteenths at `staffSpace = 12`: with the context
  /// the eighth slot is 2.6870 SS, without it 1.9000 SS — a 9.4 px error per
  /// note, accumulating across the group.
  ///
  /// [beamTypes] is `LayoutEngine.tupletBeams` — the beam decision, taken by
  /// the LAYOUT and read here. This renderer used to take it itself, during
  /// paint, by writing [Note.beam] into the caller's model (M-26). When the
  /// map is absent (a renderer driven without a layout engine) the same pure
  /// [TupletBeamPlan] is evaluated locally, so the two paths cannot disagree
  /// and neither of them writes to the model.
  void render(
    Canvas canvas,
    Tuplet tuplet,
    Offset basePosition,
    Clef currentClef, {
    int extraOctaveShift = 0,
    Map<Note, AccidentalDisplay> accidentalDecisions = const {},
    Map<Note, BeamType>? beamTypes,
    TupletLeftExtent? leftExtent,
    double? contextSmallestLeafSpaces,
  }) {
    double currentX = basePosition.dx;
    // Slot widths come from [TupletGrid], the SAME source `LayoutEngine` reads
    // when it registers the inner notes' geometry — so beams, accidental
    // decisions, hit-testing and the drawing cannot drift apart.
    //
    // The grid used to be a flat `staffSpace * 2.5` per child, duplicated here
    // and in the engine. A quarter and an eighth inside one triplet received
    // exactly the same 30.00 px.
    final slots = TupletGrid.slotWidths(
      tuplet,
      coordinates.staffSpace,
      leftExtent: leftExtent,
      noteheadAdvanceSpaces: metadata.getGlyphAdvanceWidth('noteheadBlack') ??
          TupletGrid.defaultNoteheadAdvanceSpaces,
      contextSmallestLeafSpaces: contextSmallestLeafSpaces,
    );

    final elements = tuplet.elements;
    final plan = TupletBeamPlan.of(elements);
    BeamType? beamOf(int index, MusicalElement element) {
      if (element is Note && beamTypes != null) return beamTypes[element];
      return index < plan.beams.length ? plan.beams[index] : null;
    }

    // The beam this pass actually DREW, per note. It is what the bracket rule
    // is asked about below, rather than [beamTypes] or [plan] directly, so the
    // bracket and the beam can never contradict each other: a group drawn with
    // a beam loses its bracket, a group drawn without one keeps it, whichever
    // of the two sources supplied the answer. Identity-keyed — `Note` does not
    // override `==`, and two notes of the same pitch and duration inside one
    // tuplet must stay distinct entries.
    final drawnBeams = <Note, BeamType>{};

    final allPositions = <Offset>[];
    final noteOnlyPositions = <Offset>[];
    final participants = <_Participant>[];
    // Chord origin X per element index, for the beam pass: a chord's stem does
    // NOT start at its origin (see `ChordRenderer.chordStemAnchor`), so the
    // beam pass has to re-derive the anchor and needs the origin to do it.
    final chordOrigins = <int, double>{};

    final noteHeadWidth = coordinates.staffSpace * 1.2;
    final slotCenterOffset = calculateTupletSlotCenterOffset(elements);
    double? spanStartX;
    double? spanEndX;

    for (var index = 0; index < elements.length; index++) {
      final element = elements[index];
      final beam = beamOf(index, element);
      if (element is Note && beam != null) drawnBeams[element] = beam;
      if (element is Note) {
        final staffPosition = StaffPositionCalculator.calculate(
          element.pitch,
          currentClef,
          extraOctaveShift: extraOctaveShift,
        );
        final noteY = StaffPositionCalculator.toPixelY(
          staffPosition,
          coordinates.staffSpace,
          coordinates.staffBaseline.dy,
        );

        noteRenderer.render(
          canvas,
          element,
          Offset(currentX, basePosition.dy),
          currentClef,
          // A beamed note's stem and flag belong to this renderer's beam pass.
          // `NoteRenderer` skips them when `Note.beam != null`, which is what
          // the old in-place mutation bought; now that nothing is mutated, the
          // suppression has to be asked for explicitly or every beamed tuplet
          // note would print a loose flag under its own beam.
          renderOnlyNotehead: beam != null,
          accidentalDisplay:
              accidentalDecisions[element] ?? AccidentalDisplay.show,
          extraOctaveShift: extraOctaveShift,
        );

        final position = Offset(currentX, noteY);
        allPositions.add(Offset(currentX + slotCenterOffset, noteY));
        noteOnlyPositions.add(position);
        if (beam != null) {
          participants.add((index: index, position: position, element: element));
        }
        spanStartX ??= currentX;
        spanEndX = currentX + noteHeadWidth;
      } else if (element is Rest) {
        final restAnchorX = resolveTupletElementAnchorX(
          element: element,
          slotX: currentX,
          slotCenterOffset: slotCenterOffset,
        );
        restRenderer.render(
          canvas,
          element,
          Offset(restAnchorX, basePosition.dy),
        );
        allPositions.add(Offset(restAnchorX, basePosition.dy));
        spanStartX ??= restAnchorX - (noteHeadWidth * 0.5);
        spanEndX = restAnchorX + (noteHeadWidth * 0.5);
      } else if (element is Chord) {
        // A chord inside a tuplet used to fall through every branch and simply
        // NOT BE DRAWN — silent loss of music, not just of a symbol.
        final top = element.notes.isEmpty
            ? null
            : element.notes.reduce(
                (a, b) => a.pitch.midiNumber > b.pitch.midiNumber ? a : b,
              );
        if (chordRenderer != null) {
          chordRenderer!.render(
            canvas,
            element,
            Offset(currentX, basePosition.dy),
            currentClef,
            accidentalDecisions: accidentalDecisions,
            extraOctaveShift: extraOctaveShift,
            // A beamed chord's stem belongs to THIS renderer's beam pass, for
            // the same reason a beamed note's does: only the beam pass knows
            // where the beam line is, and the chord's own
            // `calculateChordStemLength` aims at a length, not at a line.
            // Before this, a `Chord` carrying `Chord.beam` drew a full-length
            // stem of its own that stopped wherever that length landed, and the
            // beam was then drawn somewhere else entirely.
            suppressStem: beam != null,
          );
        } else if (top != null) {
          noteRenderer.render(
            canvas,
            top,
            Offset(currentX, basePosition.dy),
            currentClef,
            accidentalDisplay:
                accidentalDecisions[top] ?? AccidentalDisplay.show,
            extraOctaveShift: extraOctaveShift,
          );
        }
        if (top != null) {
          final staffPosition = StaffPositionCalculator.calculate(
            top.pitch,
            currentClef,
            extraOctaveShift: extraOctaveShift,
          );
          final noteY = StaffPositionCalculator.toPixelY(
            staffPosition,
            coordinates.staffSpace,
            coordinates.staffBaseline.dy,
          );
          allPositions.add(Offset(currentX + slotCenterOffset, noteY));
          if (beam != null) {
            participants.add((
              index: index,
              position: Offset(currentX, noteY),
              element: element,
            ));
            chordOrigins[index] = currentX;
          }
        }
        spanStartX ??= currentX;
        spanEndX = currentX + noteHeadWidth;
      } else if (element is Tuplet) {
        // Nested tuplet (e.g. a triplet inside a quintuplet). It used to be
        // skipped entirely; now it is drawn recursively and its own bracket and
        // ratio number are placed by this same routine one level down.
        render(
          canvas,
          element,
          Offset(currentX, basePosition.dy),
          currentClef,
          extraOctaveShift: extraOctaveShift,
          accidentalDecisions: accidentalDecisions,
          beamTypes: beamTypes,
          leftExtent: leftExtent,
        );
        final innerWidth = slots[index];
        allPositions.add(
          Offset(currentX + innerWidth / 2, basePosition.dy),
        );
        spanStartX ??= currentX;
        spanEndX = currentX + innerWidth;
      }
      currentX += slots[index];
    }

    final beamCount = participants.isEmpty ? 0 : plan.beamCount;
    if (participants.length >= 2) {
      _drawBeamRuns(
        canvas,
        participants,
        chordOrigins: chordOrigins,
        currentClef: currentClef,
        accidentalDecisions: accidentalDecisions,
        extraOctaveShift: extraOctaveShift,
      );
    }

    // Behind Bars p.201, asked at last. This used to read the DEPRECATED
    // `tuplet.showBracket`, which defaults to `true`, so the bracket was drawn
    // unconditionally: `Tuplet.shouldShowBracket` had zero callers anywhere in
    // `lib/`, `example/` or `test/`, and neither did the `bracketConfig` the
    // public API tells authors to configure — measured, `TupletBracket(show:
    // false)` rasterised to the same 1960 dark pixels as the default. Routing
    // through the rule removes 128 px of ink from a fully beamed triplet (1960
    // -> 1832) and leaves the numeral, and leaves the bracket in place on a
    // triplet holding a rest or written in unbeamable values.
    //
    // `drawnBeams` rather than `beamTypes`: the rule must be answered by what
    // this pass drew, not by what it was handed. When the renderer runs without
    // a layout engine `beamTypes` is null and the beams come from the local
    // [TupletBeamPlan]; passing `beamTypes` there would report "no beams" over
    // a group this very method beamed, and print a bracket across it.
    if (tuplet.shouldShowBracket(beamOf: (note) => drawnBeams[note]) &&
        allPositions.length >= 2 &&
        spanStartX != null &&
        spanEndX != null) {
      _drawTupletBracket(
        canvas,
        startX: spanStartX,
        endX: spanEndX,
        anchorPositions: allPositions,
        notePositions: noteOnlyPositions,
        numberText: tuplet.numberText,
        beamCount: beamCount,
      );
    }

    if (tuplet.showNumber &&
        allPositions.isNotEmpty &&
        spanStartX != null &&
        spanEndX != null) {
      _drawTupletNumber(
        canvas,
        startX: spanStartX,
        endX: spanEndX,
        anchorPositions: allPositions,
        notePositions: noteOnlyPositions,
        numberText: tuplet.numberText,
        beamCount: beamCount,
      );
    }
  }

  @visibleForTesting
  double calculateTupletSlotCenterOffset(List<MusicalElement> elements) {
    final referenceNote = elements.whereType<Note>().firstOrNull;
    if (referenceNote == null) {
      return coordinates.staffSpace * 0.6;
    }

    final glyphName = referenceNote.duration.type.glyphName;
    final glyphBounds = metadata.getGlyphBoundingBox(glyphName);
    if (glyphBounds == null) {
      return coordinates.staffSpace * 0.6;
    }

    return glyphBounds.centerX * coordinates.staffSpace;
  }

  @visibleForTesting
  double resolveTupletElementAnchorX({
    required MusicalElement element,
    required double slotX,
    required double slotCenterOffset,
  }) {
    if (element is Rest) {
      return slotX + slotCenterOffset;
    }
    return slotX;
  }

  bool _stemUp(List<Offset> notePositions) {
    final staffCenterY = coordinates.staffBaseline.dy;
    final averageY =
        notePositions.map((position) => position.dy).reduce((a, b) => a + b) /
        notePositions.length;
    return averageY >= staffCenterY;
  }

  /// Bracket line endpoints (at [startX]/[endX]) sloped to parallel the note
  /// trend (Gould p.205-207), clamped to TupletBracket.maxSlope, while clearing
  /// every note by the same offset the flat bracket would use.
  ({double startY, double endY}) _bracketLine(
    List<Offset> notePositions,
    double startX,
    double endX, {
    required int beamCount,
  }) {
    final stemUp = _stemUp(notePositions);
    final stemLength = coordinates.staffSpace * 3.5;
    final beamThickness = _beamThicknessPx;
    final beamGap = _beamGapPx;
    final beamStackDepth = beamCount <= 0
        ? 0.0
        : beamThickness + ((beamCount - 1) * (beamThickness + beamGap));
    final clearance = coordinates.staffSpace * (beamCount > 0 ? 0.95 : 0.75);
    final off = stemLength + beamStackDepth + clearance;

    final firstX = notePositions.first.dx;
    final lastX = notePositions.last.dx;
    final span = endX - startX;
    double slope = (lastX - firstX).abs() < 1e-6
        ? 0.0
        : (notePositions.last.dy - notePositions.first.dy) / (lastX - firstX);
    // Clamp the total rise across the bracket to maxSlope.
    final maxRise = TupletBracket.maxSlope * coordinates.staffSpace;
    if (span.abs() > 1e-6 && (slope * span).abs() > maxRise) {
      slope = (slope.isNegative ? -1 : 1) * (maxRise / span.abs());
    }

    // Fit the intercept so the sloped line clears every note by `off`.
    double? yStart;
    for (final p in notePositions) {
      final target = stemUp ? p.dy - off : p.dy + off;
      final candidate = target - slope * (p.dx - startX);
      if (yStart == null) {
        yStart = candidate;
      } else if (stemUp) {
        if (candidate < yStart) yStart = candidate; // highest (smallest Y)
      } else {
        if (candidate > yStart) yStart = candidate; // lowest (largest Y)
      }
    }
    yStart ??= stemUp ? -off : off;
    return (startY: yStart, endY: yStart + slope * span);
  }

  /// Font size the ratio numeral is drawn at.
  double get _numberSize => coordinates.staffSpace * 2.2;

  /// Staff space the numeral's own metrics are expressed in.
  ///
  /// A SMuFL glyph's bounding box and advance width are given in staff spaces
  /// at the standard 4-staff-space em, so a glyph drawn at [_numberSize] has an
  /// EFFECTIVE staff space of `_numberSize / 4` — 6.6 px where the staff's own
  /// is 12.0. Mixing the two is the second half of finding M-27: the numeral
  /// was centred with `drawGlyphWithBBox`'s built-in `centerHorizontally`,
  /// which scales the bbox by `coordinates.staffSpace`, so the digit was pushed
  /// `bbox.centerX * (12.0 - 6.6)` = about 0.28 staff spaces left of the gap it
  /// was supposed to sit in.
  double get _numberSpace => _numberSize / 4.0;

  /// Total advance of the numeral text at [_numberSize], in pixels.
  double _numberTextWidth(String numberText) {
    var total = 0.0;
    for (final ch in numberText.split('')) {
      final glyph = ch == ':' ? 'tupletColon' : 'tuplet$ch';
      total += (metadata.getGlyphAdvanceWidth(glyph) ?? 0.55) * _numberSpace;
    }
    return total;
  }

  void _drawTupletBracket(
    Canvas canvas, {
    required double startX,
    required double endX,
    required List<Offset> anchorPositions,
    required List<Offset> notePositions,
    required String numberText,
    required int beamCount,
  }) {
    if (anchorPositions.length < 2) {
      return;
    }

    final referenceNotes = notePositions.isNotEmpty
        ? notePositions
        : anchorPositions;
    final stemUp = _stemUp(referenceNotes);
    final line = _bracketLine(
      referenceNotes,
      startX,
      endX,
      beamCount: beamCount,
    );
    final span = endX - startX;
    double yAt(double x) => span.abs() < 1e-6
        ? line.startY
        : line.startY + (line.endY - line.startY) * ((x - startX) / span);

    // Bracket thickness comes from `engravingDefaults.tupletBracketThickness`
    // (Bravura: 0.16 staff spaces), NOT from the stem.
    //
    // It used to be `coordinates.staffSpace * 0.12`, which is the value of
    // `stemThickness` — the wrong entry of the wrong table, and it was a
    // literal, so it did not even follow the font's stem. Measured on a raster
    // at `staffSpace = 48`: the horizontal bracket line was 6 opaque rows,
    // i.e. 6/48 = 0.1250 staff spaces, against the 0.16 the font declares —
    // the bracket printed 22% thinner than the metadata asks for. SMuFL gives
    // brackets their own entry precisely because they are NOT stem-weight;
    // Gould (Behind Bars p.201) draws the tuplet bracket at the weight of a
    // thin barline, which is exactly Bravura's 0.16.
    final paint = Paint()
      ..color = theme.tupletColor ?? theme.stemColor
      ..strokeWidth =
          metadata.getEngravingDefault('tupletBracketThickness', 0.16) *
          coordinates.staffSpace
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final totalWidth = endX - startX;
    final centerX = (startX + endX) / 2;
    final minSegmentLength = coordinates.staffSpace * 0.5;
    // The interruption is now sized from the numeral's REAL advance width,
    // because the numeral is drawn INSIDE it (Gould, Behind Bars p.201) rather
    // than floating a staff space away from the line. It used to be
    // `max(1.9 SS, length * 1.25 SS)`, a proxy for a text width that nothing
    // measured; measured at 8x zoom the gap it opened was 1.906 SS (flat
    // bracket) / 1.927 SS (sloped) and contained ZERO ink — 0 dark pixels out
    // of 2340 sampled along the line — while the numeral sat 96.50 device px
    // (1.0052 SS) off the line, and its opaque mask erased 61 px (0.64 SS) of
    // the top staff line on the way past.
    final requestedGap = _numberTextWidth(numberText) * 1.1;
    final numberGap = math.min(totalWidth * 0.5, requestedGap);
    double leftEnd = centerX - (numberGap * 0.5);
    double rightStart = centerX + (numberGap * 0.5);

    if (leftEnd - startX < minSegmentLength) {
      leftEnd = startX + minSegmentLength;
    }
    if (endX - rightStart < minSegmentLength) {
      rightStart = endX - minSegmentLength;
    }

    final hookLength = coordinates.staffSpace * 0.5;

    canvas.drawLine(
      Offset(startX, yAt(startX)),
      Offset(leftEnd, yAt(leftEnd)),
      paint,
    );
    canvas.drawLine(
      Offset(rightStart, yAt(rightStart)),
      Offset(endX, yAt(endX)),
      paint,
    );

    final hookDirection = stemUp ? hookLength : -hookLength;
    canvas.drawLine(
      Offset(startX, yAt(startX)),
      Offset(startX, yAt(startX) + hookDirection),
      paint,
    );
    canvas.drawLine(
      Offset(endX, yAt(endX)),
      Offset(endX, yAt(endX) + hookDirection),
      paint,
    );
  }

  void _drawTupletNumber(
    Canvas canvas, {
    required double startX,
    required double endX,
    required List<Offset> anchorPositions,
    required List<Offset> notePositions,
    required String numberText,
    required int beamCount,
  }) {
    if (anchorPositions.isEmpty || numberText.isEmpty) {
      return;
    }

    final referenceNotes = notePositions.isNotEmpty
        ? notePositions
        : anchorPositions;
    final line = _bracketLine(
      referenceNotes,
      startX,
      endX,
      beamCount: beamCount,
    );
    final centerX = (startX + endX) / 2;
    // The numeral is CENTRED ON THE BRACKET LINE, inside the interruption
    // `_drawTupletBracket` opens for it (Gould, Behind Bars p.201). It used to
    // be offset a further 0.95 staff spaces past the line, so the gap in the
    // bracket held nothing and the numeral floated beside it. For a linear
    // line this midpoint is exactly `yAt(centerX)` of the same line the
    // bracket is drawn along.
    final numberY = (line.startY + line.endY) / 2;

    final numberSize = _numberSize;

    // SMuFL tuplet glyphs: each digit is tuplet0..tuplet9 and ':' is
    // tupletColon. Compose the display string ('3', '7', '5:4', '11:8', …) as a
    // run of glyphs so multi-digit numbers and ratios render (not just one int).
    String glyphFor(String ch) => ch == ':' ? 'tupletColon' : 'tuplet$ch';
    // Advance width is in staff spaces at the standard 4-SS em; scale to the
    // (smaller) tuplet font size.
    double advanceOf(String glyph) =>
        (metadata.getGlyphAdvanceWidth(glyph) ?? 0.55) * _numberSpace;

    final chars = numberText.split('');
    final advances = [for (final c in chars) advanceOf(glyphFor(c))];
    final totalWidth = advances.fold<double>(0.0, (a, b) => a + b);

    // White mask behind the number: it is what actually interrupts the bracket
    // line and the staff lines under it, now that the digit sits ON the line.
    // Its height is a representative digit's bounding box AT THE NUMERAL'S OWN
    // effective staff space — measuring it against the staff's 12.0 px made the
    // mask 1.8x too tall, which is how it came to erase 0.64 SS of the top
    // staff line while the numeral was still off to the side.
    final sampleBounds = metadata.getGlyphBoundingBox('tuplet${chars.first}');
    if (sampleBounds != null) {
      final maskRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, numberY),
          width: totalWidth + (coordinates.staffSpace * 0.3),
          height: sampleBounds.heightInPixels(_numberSpace) +
              (coordinates.staffSpace * 0.2),
        ),
        Radius.circular(coordinates.staffSpace * 0.2),
      );
      canvas.drawRRect(maskRect, Paint()..color = const Color(0xFFFFFFFF));
    }

    final numberColor = theme.tupletColor ?? theme.stemColor;
    var x = centerX - (totalWidth / 2);
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == ':') {
        // Draw the ratio colon as two dots: the bundled Bravura may not cover
        // the tupletColon glyph (U+E88A), so render it font-independently.
        final cx = x + advances[i] / 2;
        final r = numberSize * 0.055;
        final dy = numberSize * 0.16;
        final dotPaint = Paint()..color = numberColor;
        canvas.drawCircle(Offset(cx, numberY - dy), r, dotPaint);
        canvas.drawCircle(Offset(cx, numberY + dy), r, dotPaint);
      } else {
        // HORIZONTAL centring is corrected here; vertical is not.
        //
        // `drawGlyphWithBBox` centres by subtracting
        // `bbox.center * coordinates.staffSpace`, which is only right for a
        // glyph drawn at the staff's own size. This one is drawn at
        // [_numberSize], whose effective staff space is [_numberSpace] (6.6 px
        // where the staff's is 12.0), so the built-in horizontal centring
        // over-shoots by `bbox.centerX * (staffSpace - _numberSpace)` and that
        // difference is added back. Measured on the corpus `5:4` at
        // `staffSpace = 12`: the digit's ink used to sit left of the
        // interruption's centre; with this term its ink box is x 165..172,
        // centre 168.5, against a bracket interruption of x 163..174, centre
        // 168.5 — dead centre.
        //
        // The VERTICAL axis needs no such term, and adding one measurably made
        // it worse: `centerVertically` combined with the painter's own
        // top-origin behaviour already lands the digit's ink at rows 19..27,
        // centre 23.0, against a bracket line at rows 23..24, centre 23.5 —
        // 0.5 px (0.042 staff spaces) off. Applying the same over-shoot
        // correction vertically pushed the centre to row 27, 3.5 px BELOW the
        // line.
        final bounds = metadata.getGlyphBoundingBox(glyphFor(chars[i]));
        final dx = bounds == null
            ? 0.0
            : bounds.centerX * (coordinates.staffSpace - _numberSpace);
        drawGlyphWithBBox(
          canvas,
          glyphName: glyphFor(chars[i]),
          position: Offset(x + advances[i] / 2 + dx, numberY),
          color: numberColor,
          options: GlyphDrawOptions(
            size: numberSize,
            centerVertically: true,
            centerHorizontally: true,
            trackBounds: false,
          ),
        );
      }
      x += advances[i];
    }
  }

  /// Splits [participants] into the maximal runs the beam plan produced and
  /// draws each one.
  ///
  /// A tuplet can hold more than one beamed run — `[8th, 8th, quarter, 8th,
  /// 8th]` is two groups of two — which the old code could not express at all:
  /// it required every child to be a beamable `Note` and gave up on the whole
  /// tuplet otherwise.
  void _drawBeamRuns(
    Canvas canvas,
    List<_Participant> participants, {
    required Map<int, double> chordOrigins,
    required Clef currentClef,
    required Map<Note, AccidentalDisplay> accidentalDecisions,
    required int extraOctaveShift,
  }) {
    var runStart = 0;
    for (var i = 1; i <= participants.length; i++) {
      final breaks = i == participants.length ||
          participants[i].index != participants[i - 1].index + 1;
      if (!breaks) continue;
      if (i - runStart >= 2) {
        _drawSimpleBeams(
          canvas,
          participants.sublist(runStart, i),
          chordOrigins: chordOrigins,
          currentClef: currentClef,
          accidentalDecisions: accidentalDecisions,
          extraOctaveShift: extraOctaveShift,
        );
      }
      runStart = i;
    }
  }

  void _drawSimpleBeams(
    Canvas canvas,
    List<_Participant> run, {
    Map<int, double> chordOrigins = const <int, double>{},
    Clef? currentClef,
    Map<Note, AccidentalDisplay> accidentalDecisions = const {},
    int extraOctaveShift = 0,
  }) {
    if (run.length < 2) {
      return;
    }

    final notePositions = [for (final p in run) p.position];
    final beamThickness = _beamThicknessPx;
    final beamGap = _beamGapPx;
    final beamSpacing = beamThickness + beamGap;
    final stemUp = _stemUp(notePositions);

    final paint = Paint()
      ..color = theme.beamColor ?? theme.stemColor
      ..style = PaintingStyle.fill;

    String glyphOf(MusicalElement element) => element is Note
        ? element.duration.type.glyphName
        : (element as Chord).duration.type.glyphName;

    // A chord's stem does not start at the chord's origin, nor at the
    // top note's X: it hangs off the EXTREME notehead on the beam's side, which
    // may itself be cluster-displaced. `ChordRenderer.chordStemAnchor` is the
    // only thing that knows where that is; asking it here is what lets a chord
    // sit in an automatic beam at all.
    final chordAnchors = <int, ({double x, double nearY, double farY})>{};
    if (chordRenderer != null && currentClef != null) {
      for (var index = 0; index < run.length; index++) {
        final element = run[index].element;
        final origin = chordOrigins[run[index].index];
        if (element is! Chord || origin == null) continue;
        final anchor = chordRenderer!.chordStemAnchor(
          chord: element,
          basePosition: Offset(origin, coordinates.staffBaseline.dy),
          currentClef: currentClef,
          stemUp: stemUp,
          accidentalDecisions: accidentalDecisions,
          extraOctaveShift: extraOctaveShift,
        );
        if (anchor != null) chordAnchors[index] = anchor;
      }
    }

    final stemXs = List.generate(run.length, (index) {
      final anchor = chordAnchors[index];
      if (anchor != null) return anchor.x;
      return positioningEngine.calculateStemX(
        noteX: notePositions[index].dx,
        noteheadGlyphName: glyphOf(run[index].element),
        stemUp: stemUp,
        staffSpace: coordinates.staffSpace,
      );
    });

    // Y the beam has to clear, per member. For a `Note` that is its notehead;
    // for a `Chord` it is the notehead FURTHEST from the beam — the bottom one
    // under a stem-down beam, the top one over a stem-up beam.
    //
    // `participants` records a chord by its TOP note, because that is the only
    // note the slot loop resolves. Measured with that value on a stem-down
    // `[C4-E4-G4]-D5-E5` eighth triplet at `staffSpace = 24`: the beam was
    // placed from y = 312 (the chord's G4) and landed at y = 348, which is
    // TWELVE PIXELS ABOVE the C4 notehead at y = 360 — the beam was drawn
    // through the middle of the chord it belonged to. Reading the far extreme
    // from `ChordRenderer.chordStemAnchor` moves it below the whole chord.
    final beamAnchorYs = List<double>.generate(
      run.length,
      (index) => chordAnchors[index]?.farY ?? notePositions[index].dy,
    );

    // Beam HEIGHT still uses the deepest level in the group, so the beam stack
    // clears the noteheads; which levels actually get drawn is decided per note
    // further down.
    final levels = <int>[
      for (final p in run) beamCountFor(_durationTypeOf(p.element)),
    ];
    final beamCount = levels.reduce((a, b) => a > b ? a : b);
    final staffPositions = beamAnchorYs
        .map((y) => coordinates.getStaffPosition(y))
        .toList();
    final beamHeightSpaces = positioningEngine.calculateBeamHeight(
      staffPosition: staffPositions.first,
      stemUp: stemUp,
      allStaffPositions: staffPositions,
      beamCount: beamCount,
    );
    final beamAngleSpaces = positioningEngine.calculateBeamAngle(
      noteStaffPositions: staffPositions,
      stemUp: stemUp,
    );

    final firstStemX = stemXs.first;
    final lastStemX = stemXs.last;
    final averageNoteY =
        beamAnchorYs.reduce((a, b) => a + b) / beamAnchorYs.length;
    final beamBaseY = stemUp
        ? averageNoteY - (beamHeightSpaces * coordinates.staffSpace)
        : averageNoteY + (beamHeightSpaces * coordinates.staffSpace);
    final xDistance = lastStemX - firstStemX;
    double beamSlope = xDistance == 0
        ? 0.0
        : (beamAngleSpaces * coordinates.staffSpace) / xDistance;

    final melodicDelta = staffPositions.last - staffPositions.first;
    if (melodicDelta != 0 && beamSlope != 0.0) {
      final expectedSign = melodicDelta > 0 ? -1.0 : 1.0;
      if (beamSlope.sign != expectedSign) {
        beamSlope = -beamSlope;
      }
    }

    double getBeamY(double x) {
      return beamBaseY + (beamSlope * (x - firstStemX));
    }

    // Beam levels are decided PER NOTE, not by the first note of the group.
    //
    // `beamCount` used to be `_resolveBeamCount(notes.first.duration.type)` and
    // was applied to the whole span, so an eighth followed by two sixteenths
    // drew ONE beam and the secondary beam of the sixteenths simply vanished —
    // while the same figure outside a tuplet, which goes through `BeamAnalyzer`,
    // got it right. Level 1 spans the whole group; each higher level is drawn
    // only across the runs of adjacent notes that actually need it, with a
    // fractional stub for a run of one (Behind Bars p.30).
    final maxLevel = beamCount;

    void drawBeamRun(int level, double startX, double endX) {
      final yOffset = stemUp ? (level * beamSpacing) : -(level * beamSpacing);
      final startY = getBeamY(startX) + yOffset;
      final endY = getBeamY(endX) + yOffset;
      final thicknessDirection = stemUp ? beamThickness : -beamThickness;
      canvas.drawPath(
        Path()
          ..moveTo(startX, startY)
          ..lineTo(endX, endY)
          ..lineTo(endX, endY + thicknessDirection)
          ..lineTo(startX, startY + thicknessDirection)
          ..close(),
        paint,
      );
    }

    // Primary beam: the whole group.
    drawBeamRun(0, firstStemX, lastStemX);

    final stubLength = coordinates.staffSpace * 1.0;
    for (int level = 1; level < maxLevel; level++) {
      var runStart = -1;
      for (var i = 0; i <= levels.length; i++) {
        final inRun = i < levels.length && levels[i] > level;
        if (inRun && runStart < 0) {
          runStart = i;
        } else if (!inRun && runStart >= 0) {
          final last = i - 1;
          if (last > runStart) {
            drawBeamRun(level, stemXs[runStart], stemXs[last]);
          } else {
            // A lone shorter note carries a fractional beam pointing INTO the
            // group (towards the neighbour it belongs to rhythmically).
            final x = stemXs[runStart];
            final pointsRight = runStart == 0;
            drawBeamRun(
              level,
              pointsRight ? x : x - stubLength,
              pointsRight ? x + stubLength : x,
            );
          }
          runStart = -1;
        }
      }
    }

    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth =
          metadata.getEngravingDefault('stemThickness') *
          coordinates.staffSpace;

    for (int index = 0; index < run.length; index++) {
      final element = run[index].element;
      final chordAnchor = chordAnchors[index];
      // A `Chord` used to be skipped here — it drew its own stem, at its own
      // computed LENGTH, which is not the beam LINE, so the beam and the stem
      // met only by accident. It is now drawn like every other member of the
      // run, from the anchor `ChordRenderer.chordStemAnchor` reports (the
      // renderer was asked to suppress its own stem for exactly this reason).
      if (element is! Note && chordAnchor == null) continue;
      final stemX = stemXs[index];
      final stemStartY = chordAnchor?.nearY ??
          positioningEngine.calculateStemStartY(
            noteY: notePositions[index].dy,
            noteheadGlyphName: glyphOf(element),
            stemUp: stemUp,
            staffSpace: coordinates.staffSpace,
          );
      final beamY = getBeamY(stemX);

      canvas.drawLine(
        Offset(stemX, stemStartY),
        Offset(stemX, beamY),
        stemPaint,
      );
    }
  }

  static DurationType _durationTypeOf(MusicalElement element) =>
      element is Note
          ? element.duration.type
          : (element as Chord).duration.type;

  /// Number of beams a single duration needs.
  ///
  /// Delegates to [TupletBeamPlan.beamCountFor], which is the version the
  /// LAYOUT also uses to reserve the bracket's headroom — the two used to be
  /// separate switch statements with different domains, and the layout's
  /// stopped at the sixty-fourth.
  static int beamCountFor(DurationType durationType) =>
      TupletBeamPlan.beamCountFor(durationType);

  /// Beam body thickness in PIXELS, read from `engravingDefaults.beamThickness`
  /// of the loaded font (Bravura: 0.5 staff spaces).
  ///
  /// This renderer draws its own beams instead of delegating to `BeamRenderer`
  /// (a tuplet's beam is laid out on the tuplet's own slot grid, not on a
  /// `BeamGroup`), and it used to carry its own `staffSpace * 0.5` literal in
  /// two places. The literal happens to equal Bravura's value, so nothing moved
  /// when it was replaced — measured, both paths return 6.000 px at
  /// `staffSpace = 12` and 24.000 px at `staffSpace = 48`, byte-identical
  /// rasters. It is routed through the metadata anyway because a SECOND SOURCE
  /// OF TRUTH for a font-supplied number is the defect, not the pixel: point a
  /// `SmuflMetadata` at a font whose `beamThickness` is not 0.5 and the tuplet
  /// beams would silently keep Bravura's, while `BeamRenderer` (which reads the
  /// metadata since 2.7.1) followed the font.
  double get _beamThicknessPx =>
      metadata.getEngravingDefault('beamThickness', 0.5) *
      coordinates.staffSpace;

  /// Vertical air between two stacked beams in PIXELS, from
  /// `engravingDefaults.beamSpacing` (Bravura: 0.25 staff spaces).
  ///
  /// Same story as [_beamThicknessPx]: the old `staffSpace * 0.25` literal was
  /// numerically right for Bravura and structurally wrong for every other font.
  double get _beamGapPx =>
      metadata.getEngravingDefault('beamSpacing', 0.25) *
      coordinates.staffSpace;
}
