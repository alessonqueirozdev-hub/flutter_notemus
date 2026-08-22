import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../theme/music_score_theme.dart';
import '../smufl_positioning_engine.dart';
import '../staff_position_calculator.dart';
import 'base_glyph_renderer.dart';
import 'chord_renderer.dart';
import 'note_renderer.dart';
import 'rest_renderer.dart';

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

  void render(
    Canvas canvas,
    Tuplet tuplet,
    Offset basePosition,
    Clef currentClef,
  ) {
    double currentX = basePosition.dx;
    final spacing = coordinates.staffSpace * 2.5;
    // The layout engine mirrors this same grid in `_registerTupletGeometry`, so
    // beams, accidental decisions and the public position API all agree on
    // where a tuplet's inner notes are. Keep the two in step: if you change the
    // grid here, change `LayoutEngine.tupletInnerSpacing` too.

    final allPositions = <Offset>[];
    final noteOnlyPositions = <Offset>[];
    final notes = <Note>[];

    final processedElements = _applyAutomaticBeams(tuplet.elements);
    final processedNotes = processedElements.whereType<Note>().toList();
    final noteHeadWidth = coordinates.staffSpace * 1.2;
    final slotCenterOffset = calculateTupletSlotCenterOffset(processedElements);
    double? spanStartX;
    double? spanEndX;

    for (final element in processedElements) {
      if (element is Note) {
        final staffPosition = StaffPositionCalculator.calculate(
          element.pitch,
          currentClef,
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
        );

        final position = Offset(currentX, noteY);
        allPositions.add(Offset(currentX + slotCenterOffset, noteY));
        noteOnlyPositions.add(position);
        notes.add(element);
        spanStartX ??= currentX;
        spanEndX = currentX + noteHeadWidth;
        currentX += spacing;
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
        currentX += spacing;
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
          );
        } else if (top != null) {
          noteRenderer.render(
            canvas,
            top,
            Offset(currentX, basePosition.dy),
            currentClef,
          );
        }
        if (top != null) {
          final staffPosition =
              StaffPositionCalculator.calculate(top.pitch, currentClef);
          final noteY = StaffPositionCalculator.toPixelY(
            staffPosition,
            coordinates.staffSpace,
            coordinates.staffBaseline.dy,
          );
          allPositions.add(Offset(currentX + slotCenterOffset, noteY));
        }
        spanStartX ??= currentX;
        spanEndX = currentX + noteHeadWidth;
        currentX += spacing;
      } else if (element is Tuplet) {
        // Nested tuplet (e.g. a triplet inside a quintuplet). It used to be
        // skipped entirely; now it is drawn recursively and its own bracket and
        // ratio number are placed by this same routine one level down.
        render(canvas, element, Offset(currentX, basePosition.dy), currentClef);
        final innerWidth = element.elements.length * spacing;
        allPositions.add(
          Offset(currentX + innerWidth / 2, basePosition.dy),
        );
        spanStartX ??= currentX;
        spanEndX = currentX + innerWidth;
        currentX += innerWidth;
      }
    }

    final hasBeams =
        noteOnlyPositions.length >= 2 &&
        processedNotes.isNotEmpty &&
        processedNotes.first.beam != null;
    final beamCount = hasBeams
        ? _resolveBeamCount(processedNotes.first.duration.type)
        : 0;

    if (hasBeams) {
      _drawSimpleBeams(canvas, noteOnlyPositions, notes);
    }

    if (tuplet.showBracket &&
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
    final beamThickness = coordinates.staffSpace * 0.5;
    final beamGap = coordinates.staffSpace * 0.25;
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

    final paint = Paint()
      ..color = theme.tupletColor ?? theme.stemColor
      ..strokeWidth = coordinates.staffSpace * 0.12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final totalWidth = endX - startX;
    final centerX = (startX + endX) / 2;
    final minSegmentLength = coordinates.staffSpace * 0.5;
    final requestedGap = math.max(
      coordinates.staffSpace * 1.9,
      numberText.length * coordinates.staffSpace * 1.25,
    );
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
    final stemUp = _stemUp(referenceNotes);
    final line = _bracketLine(
      referenceNotes,
      startX,
      endX,
      beamCount: beamCount,
    );
    // Number sits at the sloped bracket's midpoint.
    final bracketY = (line.startY + line.endY) / 2;
    final centerX = (startX + endX) / 2;

    final numberOffset = stemUp
        ? -coordinates.staffSpace * 0.95
        : coordinates.staffSpace * 0.95;
    final numberY = bracketY + numberOffset;

    final numberSize = coordinates.staffSpace * 2.2;

    // SMuFL tuplet glyphs: each digit is tuplet0..tuplet9 and ':' is
    // tupletColon. Compose the display string ('3', '7', '5:4', '11:8', …) as a
    // run of glyphs so multi-digit numbers and ratios render (not just one int).
    String glyphFor(String ch) => ch == ':' ? 'tupletColon' : 'tuplet$ch';
    // Advance width is in staff spaces at the standard 4-SS em; scale to the
    // (smaller) tuplet font size.
    final advScale = numberSize / 4.0;
    double advanceOf(String glyph) =>
        (metadata.getGlyphAdvanceWidth(glyph) ?? 0.55) * advScale;

    final chars = numberText.split('');
    final advances = [for (final c in chars) advanceOf(glyphFor(c))];
    final totalWidth = advances.fold<double>(0.0, (a, b) => a + b);

    // White mask behind the number (height from a representative digit).
    final sampleBounds = metadata.getGlyphBoundingBox('tuplet${chars.first}');
    if (sampleBounds != null) {
      final maskRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, numberY),
          width: totalWidth + (coordinates.staffSpace * 0.5),
          height:
              sampleBounds.heightInPixels(coordinates.staffSpace) +
              (coordinates.staffSpace * 0.55),
        ),
        Radius.circular(coordinates.staffSpace * 0.35),
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
        drawGlyphWithBBox(
          canvas,
          glyphName: glyphFor(chars[i]),
          position: Offset(x + advances[i] / 2, numberY),
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

  void _drawSimpleBeams(
    Canvas canvas,
    List<Offset> notePositions,
    List<Note> notes,
  ) {
    if (notePositions.length < 2 || notes.length < 2) {
      return;
    }

    final beamThickness = coordinates.staffSpace * 0.5;
    final beamGap = coordinates.staffSpace * 0.25;
    final beamSpacing = beamThickness + beamGap;
    final stemUp = _stemUp(notePositions);

    final paint = Paint()
      ..color = theme.beamColor ?? theme.stemColor
      ..style = PaintingStyle.fill;

    final stemXs = List.generate(notePositions.length, (index) {
      final noteheadGlyph = notes[index].duration.type.glyphName;
      return positioningEngine.calculateStemX(
        noteX: notePositions[index].dx,
        noteheadGlyphName: noteheadGlyph,
        stemUp: stemUp,
        staffSpace: coordinates.staffSpace,
      );
    });

    final beamCount = _resolveBeamCount(notes.first.duration.type);
    final staffPositions = notePositions
        .map((position) => coordinates.getStaffPosition(position.dy))
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
        notePositions.map((position) => position.dy).reduce((a, b) => a + b) /
        notePositions.length;
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

    for (int level = 0; level < beamCount; level++) {
      final yOffset = stemUp ? (level * beamSpacing) : -(level * beamSpacing);
      final startX = firstStemX;
      final endX = lastStemX;
      final startY = getBeamY(startX) + yOffset;
      final endY = getBeamY(endX) + yOffset;

      final thicknessDirection = stemUp ? beamThickness : -beamThickness;
      final path = Path()
        ..moveTo(startX, startY)
        ..lineTo(endX, endY)
        ..lineTo(endX, endY + thicknessDirection)
        ..lineTo(startX, startY + thicknessDirection)
        ..close();

      canvas.drawPath(path, paint);
    }

    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth =
          metadata.getEngravingDefault('stemThickness') *
          coordinates.staffSpace;

    for (int index = 0; index < notePositions.length; index++) {
      final noteheadGlyph = notes[index].duration.type.glyphName;
      final stemX = stemXs[index];
      final stemStartY = positioningEngine.calculateStemStartY(
        noteY: notePositions[index].dy,
        noteheadGlyphName: noteheadGlyph,
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

  int _resolveBeamCount(DurationType durationType) {
    return switch (durationType) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      _ => 1,
    };
  }

  /// Assigns beam membership to the notes of a tuplet **in place**.
  ///
  /// This used to rebuild every note. Besides breaking identity (so the note a
  /// caller holds is not the note that gets drawn, and no identity-keyed layout
  /// data matches), the copy constructor omitted `syllables`, `isGraceNote`,
  /// `alternatePitch`, `tabFret`, `tabString`, `accidentalParenthesis`,
  /// `slurs`, `crossStaffMove`, `tremoloStrokes` and `xmlId` — so lyrics, tab
  /// numbers, courtesy accidentals and cross-staff routing simply vanished for
  /// any note inside a tuplet.
  List<MusicalElement> _applyAutomaticBeams(List<MusicalElement> elements) {
    final notes = elements.whereType<Note>().toList();
    if (notes.length != elements.length || notes.length < 2) {
      return elements;
    }

    final beamable = notes.every((note) {
      return note.duration.type == DurationType.eighth ||
          note.duration.type == DurationType.sixteenth ||
          note.duration.type == DurationType.thirtySecond ||
          note.duration.type == DurationType.sixtyFourth;
    });

    if (!beamable) {
      return elements;
    }

    final last = notes.length - 1;
    for (int index = 0; index < notes.length; index++) {
      notes[index].beam = switch (index) {
        0 => BeamType.start,
        _ when index == last => BeamType.end,
        _ => BeamType.inner,
      };
    }

    return elements;
  }
}
