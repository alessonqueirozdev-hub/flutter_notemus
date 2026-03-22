// lib/src/rendering/renderers/primitives/dot_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para pontos de aumento.
///
/// Responsabilidade única: desenhar pontos de aumento seguindo
/// a especificação SMuFL.
///
/// Regras SMuFL:
/// - Notas em LINHAS (staffPosition PAR): ponto na mesma linha
/// - Notas em ESPAÇOS (staffPosition ÍMPAR): ponto no espaço acima
class DotRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;

  DotRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
  });

  /// Renderiza pontos de aumento para uma nota.
  ///
  /// [canvas] - Canvas onde desenhar
  /// [note] - Nota com pontos de aumento
  /// [notePosition] - Posição da cabeça da nota (centro)
  /// [staffPosition] - Posição da nota na pauta (em meios de staff space)
  void render(
    Canvas canvas,
    Note note,
    Offset notePosition,
    int staffPosition,
  ) {
    if (note.duration.dots == 0) return;

    // CORREÇÃO SMuFL: Posicionamento horizontal conforme Behind Bars
    // Behind Bars (p.14): "aproximadamente 1 staff space da nota"
    // notePosition já é o CENTRO da nota
    // Largura típica de noteheadBlack = 1.18 staff spaces
    // Centro da nota + metade da largura (~0.59) + clearance (~0.4) ≈ 1.0 SS
    final dotStartX = notePosition.dx + (coordinates.staffSpace * 1.3);

    // CORREÇÃO CRÍTICA: Posição Y deve alinhar EXATAMENTE ao centro da cabeça
    final dotY = _calculateDotY(notePosition.dy, staffPosition);

    // Desenhar cada ponto (múltiplos pontos ficam horizontalmente espaçados)
    for (int i = 0; i < note.duration.dots; i++) {
      // Espaçamento entre pontos: 0.5 staff spaces (Behind Bars)
      final dotX = dotStartX + (i * coordinates.staffSpace * 0.5);
      _drawDot(canvas, Offset(dotX, dotY));
    }
  }

  /// Calcula a posição Y do ponto seguindo especificação SMuFL.
  ///
  /// **REGRA FUNDAMENTAL:** Pontos SEMPRE nos espaços, NUNCA nas linhas!
  ///
  /// [noteY] - Posição Y REAL da nota (em pixels)
  /// [staffPosition] - Posição da nota no pentagrama
  double _calculateDotY(double noteY, int staffPosition) {
    // ESPECIFICAÇÃO SMuFL (Behind Bars, p.14):
    // - Notas em LINHAS (staffPosition PAR): ponto fica NO ESPAÇO adjacente
    // - Notas em ESPAÇOS (staffPosition ÍMPAR): ponto fica no mesmo espaço
    //
    // IMPORTANTE: staffPosition é em "meios de staff space"
    // - PAR (0, 2, 4, -2, -4...): nota está em uma LINHA
    // - ÍMPAR (1, 3, 5, -1, -3...): nota está em um ESPAÇO
    //
    // ⚠️ VALORES EMPÍRICOS - Compensam a baseline correction aplicada nas noteheads
    // A baseline correction move as noteheads para cima em ~2.5 staff spaces.
    // Estes valores compensam esse offset para posicionar os pontos corretamente.

    if (staffPosition.isEven) {
      // Nota em LINHA: ponto vai para o ESPAÇO mais próximo do centro
      if (staffPosition > 0) {
        // Nota acima do centro → ponto vai para BAIXO
        // Valor empírico que compensa baseline correction
        return noteY + (coordinates.staffSpace * -2.5);
      } else {
        // Nota no centro ou abaixo → ponto vai para CIMA
        // Valor empírico que compensa baseline correction
        return noteY - (coordinates.staffSpace * 2.5);
      }
    } else {
      // Nota em ESPAÇO: ponto fica no MESMO espaço
      // Valor empírico que compensa baseline correction
      return noteY - (coordinates.staffSpace * 2.0);
    }
  }

  /// Desenha um único ponto de aumento.
  void _drawDot(Canvas canvas, Offset position) {
    drawGlyphWithBBox(
      canvas,
      glyphName: 'augmentationDot',
      position: position,
      color: theme.noteheadColor,
      options: const GlyphDrawOptions(
        centerHorizontally: true,
        centerVertically:
            true, // Centralizar verticalmente na posição calculada
        disableBaselineCorrection:
            true, // CRÍTICO: Não aplicar correção de baseline nos pontos!
        size: null,
        scale: 1.0, // Tamanho padrão SMuFL
        trackBounds: false, // Pontos não precisam de collision detection
      ),
    );
  }
}
