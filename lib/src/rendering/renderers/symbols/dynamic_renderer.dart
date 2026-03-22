// lib/src/rendering/renderers/symbols/dynamic_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para dinâmicas musicais (p, f, mf, crescendo, etc).
///
/// Responsabilidade única: desenhar indicações de dinâmica.
class DynamicRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;

  DynamicRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
  });

  /// Renderiza dinâmica.
  void render(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition, {
    double verticalOffset = 0.0,
  }) {
    if (dynamic.isHairpin) {
      _renderHairpin(
        canvas,
        dynamic,
        basePosition,
        verticalOffset: verticalOffset,
      );
      return;
    }

    final glyphName = _getDynamicGlyph(dynamic.type);
    final dynamicY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;

    if (glyphName != null) {
      drawGlyphWithBBox(
        canvas,
        glyphName: glyphName,
        position: Offset(basePosition.dx, dynamicY),
        color: theme.dynamicColor ?? theme.noteheadColor,
        options: const GlyphDrawOptions(
          centerVertically: true,
          centerHorizontally: true,
        ),
      );
    } else if (dynamic.customText != null) {
      _drawCustomDynamicText(
        canvas,
        dynamic.customText!,
        basePosition.dx,
        dynamicY,
      );
    }
  }

  /// Renderiza hairpin (crescendo/diminuendo).
  void _renderHairpin(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition, {
    double verticalOffset = 0.0,
  }) {
    // CORREÇÃO: Comprimento proporcional ao número de notas abrangidas
    // Se length não especificado, usar comprimento padrão de 4 staff spaces por nota
    // Mas permitir override via dynamic.length
    final defaultLength = coordinates.staffSpace * 6.0; // Aumentado de 4.0 para 6.0
    final length = dynamic.length ?? defaultLength;
    
    final hairpinY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;
    
    // CORREÇÃO: Altura proporcional também (mais expressiva)
    final height = coordinates.staffSpace * 0.9; // Aumentado de 0.75

    final hairpinThickness = metadata.getEngravingDefault('hairpinThickness');
    final paint = Paint()
      ..color = theme.dynamicColor ?? theme.noteheadColor
      ..strokeWidth = hairpinThickness * coordinates.staffSpace
      ..strokeCap = StrokeCap.butt; // CORREÇÃO: Pontas quadradas (não arredondadas)

    if (dynamic.type == DynamicType.crescendo) {
      // Crescendo: abre para direita (<)
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY - height),
        Offset(basePosition.dx + length, hairpinY),
        paint,
      );
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY + height),
        Offset(basePosition.dx + length, hairpinY),
        paint,
      );
    } else if (dynamic.type == DynamicType.diminuendo) {
      // Diminuendo: fecha para direita (>)
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY),
        Offset(basePosition.dx + length, hairpinY - height),
        paint,
      );
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY),
        Offset(basePosition.dx + length, hairpinY + height),
        paint,
      );
    }
  }

  /// Desenha texto de dinâmica customizado.
  void _drawCustomDynamicText(Canvas canvas, String text, double x, double y) {
    final textStyle =
        theme.dynamicTextStyle ??
        TextStyle(
          fontSize: glyphSize * 0.4,
          fontStyle: FontStyle.italic,
          color: theme.dynamicColor ?? theme.noteheadColor,
        );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  String? _getDynamicGlyph(DynamicType type) {
    const dynamicGlyphs = {
      DynamicType.p: 'dynamicPiano',
      DynamicType.mp: 'dynamicMezzoPiano',
      DynamicType.mf: 'dynamicMezzoForte',
      DynamicType.f: 'dynamicForte',
      DynamicType.pp: 'dynamicPP',
      DynamicType.ff: 'dynamicFF',
      DynamicType.ppp: 'dynamicPPP',
      DynamicType.fff: 'dynamicFFF',
      DynamicType.sforzando: 'dynamicSforzando1',
    };
    return dynamicGlyphs[type];
  }
}
