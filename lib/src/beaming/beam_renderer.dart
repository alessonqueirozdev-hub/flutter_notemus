import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/beaming/beam_segment.dart';
import 'package:flutter_notemus/src/beaming/beam_types.dart';
import 'package:flutter_notemus/src/theme/music_score_theme.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

/// Renders beams (eighth-note beams) geometrically.
class BeamRenderer {
  final MusicScoreTheme theme;
  final double staffSpace;
  final double noteheadWidth;
  final SMuFLPositioningEngine positioningEngine;

  late final double beamThickness;
  late final double beamGap;
  late final double stemThickness;

  BeamRenderer({
    required this.theme,
    required this.staffSpace,
    required this.noteheadWidth,
    required this.positioningEngine,
  }) {
    // Match the calibrated legacy beam visuals that already look stable in
    // the public examples. The theoretical SMuFL defaults looked too heavy
    // on Flutter canvases for short, slanted advanced groups.
    beamThickness = 0.4 * staffSpace;
    beamGap = 0.60 * staffSpace;
    stemThickness = 0.12 * staffSpace;
  }

  void renderAdvancedBeamGroup(
    Canvas canvas,
    AdvancedBeamGroup group, {
    Map<dynamic, double>? noteXPositions,
    Map<dynamic, double>? noteYPositions,
  }) {
    final paint = Paint()
      ..color = theme.beamColor ?? theme.stemColor
      ..style = PaintingStyle.fill;

    // 1. Render stems
    _renderStems(canvas, group, paint, noteXPositions, noteYPositions);

    // 2. Render all beam segments
    for (final segment in group.beamSegments) {
      _renderBeamSegment(canvas, group, segment, paint, noteXPositions);
    }
  }

  /// Returns the horizontal X offset applied to the stem anchor, in pixels.
  ///
  /// Positive for stem-up (SE anchor), negative for stem-down (NW anchor).
  double _stemXOffset(StemDirection direction) =>
      direction == StemDirection.up ? 0.7 : -0.8;

  void _renderStems(
    Canvas canvas,
    AdvancedBeamGroup group,
    Paint paint,
    Map<dynamic, double>? noteXPositions,
    Map<dynamic, double>? noteYPositions,
  ) {
    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = stemThickness
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    final xOffset = _stemXOffset(group.stemDirection);

    for (int i = 0; i < group.notes.length; i++) {
      final note = group.notes[i];

      final noteX = noteXPositions?[note] ?? group.leftX;
      final noteY = noteYPositions?[note] ?? _estimateNoteY(note, group);

      final noteheadGlyph = note.duration.type.glyphName;

      final stemAnchor = group.stemDirection == StemDirection.up
          ? positioningEngine.getStemUpAnchor(noteheadGlyph)
          : positioningEngine.getStemDownAnchor(noteheadGlyph);

      final stemX = noteX + (stemAnchor.dx * staffSpace - xOffset);
      final beamY = group.interpolateBeamY(stemX);

      canvas.drawLine(Offset(stemX, noteY), Offset(stemX, beamY), stemPaint);
    }
  }

  void _renderBeamSegment(
    Canvas canvas,
    AdvancedBeamGroup group,
    BeamSegment segment,
    Paint paint,
    Map<dynamic, double>? noteXPositions,
  ) {
    final levelOffset = _calculateLevelOffset(
      segment.level,
      group.stemDirection,
    );

    if (segment.isFractional) {
      _renderFractionalBeam(
        canvas,
        group,
        segment,
        paint,
        levelOffset,
        noteXPositions,
      );
    } else {
      _renderFullBeam(
        canvas,
        group,
        segment,
        paint,
        levelOffset,
        noteXPositions,
      );
    }
  }

  double _calculateLevelOffset(int level, StemDirection stemDirection) {
    final offset = (level - 1) * (beamThickness + beamGap);
    return stemDirection == StemDirection.down ? -offset : offset;
  }

  void _renderFullBeam(
    Canvas canvas,
    AdvancedBeamGroup group,
    BeamSegment segment,
    Paint paint,
    double levelOffset,
    Map<dynamic, double>? noteXPositions,
  ) {
    final startNote = group.notes[segment.startNoteIndex];
    final endNote = group.notes[segment.endNoteIndex];
    final startNoteX = noteXPositions?[startNote] ?? group.leftX;
    final endNoteX = noteXPositions?[endNote] ?? group.rightX;

    final startGlyph = startNote.duration.type.glyphName;
    final endGlyph = endNote.duration.type.glyphName;

    final startAnchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(startGlyph)
        : positioningEngine.getStemDownAnchor(startGlyph);

    final endAnchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(endGlyph)
        : positioningEngine.getStemDownAnchor(endGlyph);

    final xOffset = _stemXOffset(group.stemDirection);

    final leftX = startNoteX + (startAnchor.dx * staffSpace - xOffset);
    final rightX = endNoteX + (endAnchor.dx * staffSpace - xOffset);

    final leftY = group.interpolateBeamY(leftX) + levelOffset;
    final rightY = group.interpolateBeamY(rightX) + levelOffset;

    final beamPath = Path();

    if (group.stemDirection == StemDirection.up) {
      beamPath.moveTo(leftX, leftY);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(rightX, rightY + beamThickness);
      beamPath.lineTo(leftX, leftY + beamThickness);
    } else {
      beamPath.moveTo(leftX, leftY - beamThickness);
      beamPath.lineTo(rightX, rightY - beamThickness);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(leftX, leftY);
    }

    beamPath.close();
    canvas.drawPath(beamPath, paint);
  }

  void _renderFractionalBeam(
    Canvas canvas,
    AdvancedBeamGroup group,
    BeamSegment segment,
    Paint paint,
    double levelOffset,
    Map<dynamic, double>? noteXPositions,
  ) {
    final noteIndex = segment.startNoteIndex;
    final note = group.notes[noteIndex];

    final noteX = noteXPositions?[note] ?? group.leftX;

    final glyph = note.duration.type.glyphName;
    final anchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(glyph)
        : positioningEngine.getStemDownAnchor(glyph);

    final xOffset = _stemXOffset(group.stemDirection);

    final centerX = noteX + (anchor.dx * staffSpace - xOffset);

    final length = segment.fractionalLength ?? noteheadWidth;

    double leftX, rightX;
    if (segment.fractionalSide == FractionalBeamSide.right) {
      leftX = centerX;
      rightX = centerX + length;
    } else {
      leftX = centerX - length;
      rightX = centerX;
    }

    final leftY = group.interpolateBeamY(leftX) + levelOffset;
    final rightY = group.interpolateBeamY(rightX) + levelOffset;

    final beamPath = Path();

    if (group.stemDirection == StemDirection.up) {
      beamPath.moveTo(leftX, leftY);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(rightX, rightY + beamThickness);
      beamPath.lineTo(leftX, leftY + beamThickness);
    } else {
      beamPath.moveTo(leftX, leftY - beamThickness);
      beamPath.lineTo(rightX, rightY - beamThickness);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(leftX, leftY);
    }

    beamPath.close();
    canvas.drawPath(beamPath, paint);
  }

  double _estimateNoteY(dynamic note, AdvancedBeamGroup group) {
    return staffSpace * 3.0;
  }

  double calculateTotalBeamHeight(int beamCount) {
    if (beamCount == 0) return 0;
    return beamThickness + ((beamCount - 1) * (beamThickness + beamGap));
  }
}
