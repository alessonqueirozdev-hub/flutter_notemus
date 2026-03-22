// lib/src/rendering/renderers/symbols/text_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para textos musicais.
class TextRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;

  TextRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
  });

  void render(Canvas canvas, MusicText text, Offset basePosition) {
    double yOffset = 0;
    switch (text.placement) {
      case TextPlacement.above:
        yOffset = -coordinates.staffSpace * 2.5;
        break;
      case TextPlacement.below:
        yOffset = coordinates.staffSpace * 2.5;
        break;
      case TextPlacement.inside:
        yOffset = 0;
        break;
    }

    final textStyle = text.type == TextType.tempo
        ? (theme.tempoTextStyle ?? const TextStyle())
        : (theme.textStyle ?? const TextStyle());

    final textPainter = TextPainter(
      text: TextSpan(text: text.text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        basePosition.dx - textPainter.width / 2,
        coordinates.staffBaseline.dy + yOffset - textPainter.height / 2,
      ),
    );
  }
}
