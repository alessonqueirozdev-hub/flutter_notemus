import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../theme/music_score_theme.dart';
import '../smufl_positioning_engine.dart';
import '../staff_position_calculator.dart';
import 'base_glyph_renderer.dart';
import 'note_renderer.dart';
import 'rest_renderer.dart';

/// Specialized renderer for tuplets and other irregular rhythmic groups.
class TupletRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final NoteRenderer noteRenderer;
  final RestRenderer restRenderer;
  final SMuFLPositioningEngine positioningEngine;

  TupletRenderer({
    required super.coordinates,
    required super.metadata,
    required this.theme,
    required super.glyphSize,
    required this.noteRenderer,
    required this.restRenderer,
    required this.positioningEngine,
  });

  void render(
    Canvas canvas,
    Tuplet tuplet,
    Offset basePosition,
    Clef currentClef,
  ) {
    double currentX = basePosition.dx;
    final spacing = coordinates.staffSpace * 2.5;

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
        number: tuplet.actualNotes,
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
        number: tuplet.actualNotes,
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

  double _calculateBracketY(
    List<Offset> notePositions, {
    required int beamCount,
  }) {
    final stemUp = _stemUp(notePositions);

    final extremeY = stemUp
        ? notePositions.map((position) => position.dy).reduce(math.min)
        : notePositions.map((position) => position.dy).reduce(math.max);

    final stemLength = coordinates.staffSpace * 3.5;
    final beamThickness = coordinates.staffSpace * 0.5;
    final beamGap = coordinates.staffSpace * 0.25;
    final beamStackDepth = beamCount <= 0
        ? 0.0
        : beamThickness + ((beamCount - 1) * (beamThickness + beamGap));
    final clearance = coordinates.staffSpace * (beamCount > 0 ? 0.95 : 0.75);

    if (stemUp) {
      final beamTopY = extremeY - stemLength - beamStackDepth;
      final unclamped = beamTopY - clearance;
      final minY = coordinates.getStaffLineY(5) - coordinates.staffSpace * 2.6;
      return unclamped < minY ? minY : unclamped;
    }

    final beamBottomY = extremeY + stemLength + beamStackDepth;
    final unclamped = beamBottomY + clearance;
    final maxY = coordinates.getStaffLineY(1) + coordinates.staffSpace * 2.6;
    return unclamped > maxY ? maxY : unclamped;
  }

  void _drawTupletBracket(
    Canvas canvas, {
    required double startX,
    required double endX,
    required List<Offset> anchorPositions,
    required List<Offset> notePositions,
    required int number,
    required int beamCount,
  }) {
    if (anchorPositions.length < 2) {
      return;
    }

    final referenceNotes = notePositions.isNotEmpty
        ? notePositions
        : anchorPositions;
    final stemUp = _stemUp(referenceNotes);
    final bracketY = _calculateBracketY(referenceNotes, beamCount: beamCount);

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
      number.toString().length * coordinates.staffSpace * 1.25,
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

    canvas.drawLine(Offset(startX, bracketY), Offset(leftEnd, bracketY), paint);
    canvas.drawLine(
      Offset(rightStart, bracketY),
      Offset(endX, bracketY),
      paint,
    );

    final hookDirection = stemUp ? hookLength : -hookLength;
    canvas.drawLine(
      Offset(startX, bracketY),
      Offset(startX, bracketY + hookDirection),
      paint,
    );
    canvas.drawLine(
      Offset(endX, bracketY),
      Offset(endX, bracketY + hookDirection),
      paint,
    );
  }

  void _drawTupletNumber(
    Canvas canvas, {
    required double startX,
    required double endX,
    required List<Offset> anchorPositions,
    required List<Offset> notePositions,
    required int number,
    required int beamCount,
  }) {
    if (anchorPositions.isEmpty) {
      return;
    }

    final referenceNotes = notePositions.isNotEmpty
        ? notePositions
        : anchorPositions;
    final stemUp = _stemUp(referenceNotes);
    final bracketY = _calculateBracketY(referenceNotes, beamCount: beamCount);
    final centerX = (startX + endX) / 2;

    final numberOffset = stemUp
        ? -coordinates.staffSpace * 0.95
        : coordinates.staffSpace * 0.95;
    final numberY = bracketY + numberOffset;

    final glyphName = 'tuplet$number';
    final numberSize = coordinates.staffSpace * 2.2;
    final glyphBounds = metadata.getGlyphBoundingBox(glyphName);

    if (glyphBounds != null) {
      final maskRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, numberY),
          width:
              glyphBounds.widthInPixels(coordinates.staffSpace) +
              (coordinates.staffSpace * 0.7),
          height:
              glyphBounds.heightInPixels(coordinates.staffSpace) +
              (coordinates.staffSpace * 0.55),
        ),
        Radius.circular(coordinates.staffSpace * 0.35),
      );
      canvas.drawRRect(maskRect, Paint()..color = const Color(0xFFFFFFFF));
    }

    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: Offset(centerX, numberY),
      color: theme.tupletColor ?? theme.stemColor,
      options: GlyphDrawOptions(
        size: numberSize,
        centerVertically: true,
        centerHorizontally: true,
        trackBounds: false,
      ),
    );
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

    final beamedNotes = <Note>[];
    for (int index = 0; index < notes.length; index++) {
      final beamType = switch (index) {
        0 => BeamType.start,
        _ when index == notes.length - 1 => BeamType.end,
        _ => BeamType.inner,
      };

      beamedNotes.add(
        Note(
          pitch: notes[index].pitch,
          duration: notes[index].duration,
          beam: beamType,
          articulations: notes[index].articulations,
          tie: notes[index].tie,
          slur: notes[index].slur,
          ornaments: notes[index].ornaments,
          dynamicElement: notes[index].dynamicElement,
          techniques: notes[index].techniques,
          voice: notes[index].voice,
        ),
      );
    }

    return beamedNotes.cast<MusicalElement>();
  }
}
