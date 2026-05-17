// lib/src/rendering/renderers/primitives/stem_renderer.dart

import 'package:flutter/material.dart';
import '../../../theme/music_score_theme.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';

/// Renderer especializado Only for stems (stems) de notes.
///
/// Responsabilidade única: desenhar stems de notes using
/// âncoras SMuFL for posicionamento preciso.
class StemRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final double stemThickness;
  final SMuFLPositioningEngine positioningEngine;

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
  /// Returns o Offset of the final of the stem (where a bandeirola must be desenhada).
  Offset render(
    Canvas canvas,
    Offset notePosition,
    String noteheadGlyph,
    int staffPosition,
    bool stemUp,
    int beamCount, {
    bool isBeamed = false,
  }) {
    // Attachment offset comes from the SMuFL stem anchor of the notehead plus
    // a half-stem-thickness inset (stemThickness is a SMuFL engraving default),
    // all expressed in staff spaces and scaled by staffSpace. This replaces the
    // former raw-pixel nudge constants so stems stay proportional at any
    // staffSpace, and keeps single notes consistent with ChordRenderer (which
    // already uses this positioning engine path).
    final attachment = positioningEngine.calculateStemAttachmentOffset(
      noteheadGlyphName: noteheadGlyph,
      stemUp: stemUp,
      staffSpace: coordinates.staffSpace,
    );
    final stemX = notePosition.dx + attachment.dx;
    final stemStartY = notePosition.dy + attachment.dy;

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
