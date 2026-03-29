// lib/src/rendering/renderers/primitives/stem_renderer.dart

import 'package:flutter/material.dart';
import '../../../theme/music_score_theme.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';

/// Rendersdor especializado APENAS for stems (stems) de notes.
///
/// Responsabilidade única: desenhar stems de notes using
/// âncoras SMuFL for posicionamento preciso.
class StemRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final double stemThickness;
  final SMuFLPositioningEngine positioningEngine;

  static const double stemUpXOffset = 0.7;
  static const double stemDownXOffset = -0.8;

  StemRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
    required this.stemThickness,
    required this.positioningEngine,
  });

  /// Renders stem de a note.
  ///
  /// Returns o Offset of the final of the stem (where a bandeirola deve ser desenhada).
  Offset render(
    Canvas canvas,
    Offset notePosition,
    String noteheadGlyph,
    int staffPosition,
    bool stemUp,
    int beamCount, {
    bool isBeamed = false,
  }) {
    final stemAnchor = stemUp
        ? positioningEngine.getStemUpAnchor(noteheadGlyph)
        : positioningEngine.getStemDownAnchor(noteheadGlyph);

    final xOffset = stemUp ? stemUpXOffset : stemDownXOffset;
    final stemAnchorPixels = Offset(
      stemAnchor.dx * coordinates.staffSpace - xOffset,
      -stemAnchor.dy * coordinates.staffSpace,
    );
    final stemX = notePosition.dx + stemAnchorPixels.dx;
    final stemStartY = notePosition.dy + stemAnchorPixels.dy;

    final stemLength =
        positioningEngine.calculateStemLength(
          staffPosition: staffPosition,
          stemUp: stemUp,
          beamCount: beamCount,
          isBeamed: isBeamed,
        ) *
        coordinates.staffSpace;

    final stemEndY = stemUp ? stemStartY - stemLength : stemStartY + stemLength;

    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = stemThickness
      ..strokeCap = StrokeCap.butt;

    canvas.drawLine(
      Offset(stemX, stemStartY),
      Offset(stemX, stemEndY),
      stemPaint,
    );

    return Offset(stemX, stemEndY);
  }
}
