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

  /// Thickness of a single beam, in pixels.
  ///
  /// Read from `engravingDefaults.beamThickness` of the loaded SMuFL font, via
  /// [SMuFLPositioningEngine.beamThickness] (which already applies the Bravura
  /// fallback of 0.5 staff spaces when the font ships no value).
  ///
  /// This used to be a hardcoded `0.4 * staffSpace`, justified by the comment
  /// "the theoretical SMuFL defaults looked too heavy on Flutter canvases".
  /// Measured at staffSpace = 40 px on a two-level (sixteenth-note) group, by
  /// counting dark pixel runs down a column in the middle of the beam:
  ///
  /// ```text
  ///                       band      gap     total 2-beam stack
  ///   hardcoded (0.40/0.60)  16 px   24 px   56 px = 1.40 SS
  ///   metadata  (0.50/0.25)  20 px   10 px   50 px = 1.25 SS
  /// ```
  ///
  /// So the old numbers were not in fact "lighter": each individual band was
  /// 4 px thinner, but the gap was 14 px wider, and the STACK — which is what
  /// the eye reads as beam weight, and what the stems have to span — was 6 px
  /// (10.7%) TALLER than the conformant one. At three beam levels the gap
  /// dominates outright: 2.40 SS hardcoded against 2.00 SS from the metadata,
  /// 16.7% taller. There is therefore no measurement supporting a corrective
  /// scale factor on top of the metadata, and none is applied.
  late final double beamThickness;

  /// Vertical gap between two adjacent beams, in pixels.
  ///
  /// Read from `engravingDefaults.beamSpacing` (Bravura: 0.25 staff spaces).
  /// Named `beamGap` rather than `beamSpacing` for source compatibility; see
  /// [beamThickness] for the measurement that motivated dropping the old
  /// hardcoded `0.60 * staffSpace`.
  late final double beamGap;

  /// Stem thickness, in pixels, from `engravingDefaults.stemThickness`.
  ///
  /// Bravura's value is 0.12, identical to the literal this replaced, so the
  /// rendered output is unchanged; the point is that a font whose stems are
  /// not 0.12 staff spaces now reaches the beam drawer instead of being
  /// silently overridden.
  late final double stemThickness;

  BeamRenderer({
    required this.theme,
    required this.staffSpace,
    required this.noteheadWidth,
    required this.positioningEngine,
  }) {
    // Single source of truth: the positioning engine already loads these three
    // keys from `engravingDefaults` (with the Bravura numbers as fallbacks) and
    // is the same object the rest of the engraving math consults, so the beam
    // drawer can no longer contradict the metadata it is handed.
    beamThickness = positioningEngine.beamThickness * staffSpace;
    beamGap = positioningEngine.beamSpacing * staffSpace;
    stemThickness = positioningEngine.stemThickness * staffSpace;
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
  ///
  /// KNOWN DEVIATION, deliberately left alone by the M-15 metadata pass: these
  /// two numbers are RAW PIXELS, not staff spaces, so unlike every other length
  /// in this class they do not scale with [staffSpace]. They exist to pull the
  /// drawn stem back inside the notehead by roughly half a stem width, which at
  /// the package's common staffSpace of 10 px is `0.12 * 10 / 2 = 0.6 px` —
  /// close enough to 0.7/0.8 to make that their evident origin. Expressing them
  /// as `stemThickness / 2` would be the metadata-correct form, but it moves
  /// every beamed note horizontally at every other staff size, so it is a
  /// separate, separately-measured change and not part of the beam-weight fix.
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

  /// Last-resort notehead Y for a note the caller supplied no position for.
  ///
  /// `3.0 * staffSpace` is the middle staff line under this package's staff
  /// origin, i.e. a POSITION, not a thickness — it is deliberately NOT routed
  /// through `engravingDefaults`, which defines no such key.
  double _estimateNoteY(dynamic note, AdvancedBeamGroup group) {
    return staffSpace * 3.0;
  }

  /// Total vertical extent of a [beamCount]-level beam stack, in pixels.
  ///
  /// Metadata-derived since M-15: at staffSpace = 40 px with Bravura this is
  /// 20 / 50 / 80 px for 1 / 2 / 3 beams, against 16 / 56 / 96 px from the old
  /// hardcoded 0.4 + 0.6 pair — the conformant stack is shorter from two beams
  /// upward, which is the measurement that decided against a scale factor.
  double calculateTotalBeamHeight(int beamCount) {
    if (beamCount == 0) return 0;
    return beamThickness + ((beamCount - 1) * (beamThickness + beamGap));
  }
}
