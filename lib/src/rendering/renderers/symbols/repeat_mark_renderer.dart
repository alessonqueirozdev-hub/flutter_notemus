// lib/src/rendering/renderers/symbols/repeat_mark_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para marcas de repetição (segno, coda, etc).
///
/// Responsabilidade única: desenhar símbolos de navegação musical.
class RepeatMarkRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;

  RepeatMarkRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
  });

  /// Renderiza marca de repetição.
  void render(Canvas canvas, RepeatMark repeatMark, Offset basePosition) {
    final glyphName = _getRepeatMarkGlyph(repeatMark.type);
    if (glyphName == null) return;

    // Posição tipográfica: acima da pauta
    final signY = coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.5);

    // Usar opticalCenter anchor se disponível
    final glyphInfo = metadata.getGlyphInfo(glyphName);
    double verticalAdjust = 0;
    if (glyphInfo != null && glyphInfo.hasAnchors) {
      final opticalCenter = glyphInfo.anchors?.getAnchor('opticalCenter');
      if (opticalCenter != null) {
        verticalAdjust = opticalCenter.dy * coordinates.staffSpace;
      }
    }

    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: Offset(basePosition.dx, signY - verticalAdjust),
      color: theme.repeatColor ?? theme.noteheadColor,
      options: GlyphDrawOptions(
        centerHorizontally: true,
        centerVertically: glyphInfo == null,
        scale: 0.65, // CORREÇÃO: Reduzido de 1.1 para 0.65 (60-70% do tamanho)
      ),
    );
  }

  String? _getRepeatMarkGlyph(RepeatType type) {
    const repeatGlyphs = {
      RepeatType.segno: 'segno',
      RepeatType.coda: 'coda',
      RepeatType.segnoSquare: 'segnoSerpent1',
      RepeatType.codaSquare: 'codaSquare',
    };
    return repeatGlyphs[type];
  }
}
