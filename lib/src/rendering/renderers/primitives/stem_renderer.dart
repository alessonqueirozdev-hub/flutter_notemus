// lib/src/rendering/renderers/primitives/stem_renderer.dart

import 'package:flutter/material.dart';
import '../../../theme/music_score_theme.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para hastes (stems) de notas.
///
/// Responsabilidade única: desenhar hastes de notas usando
/// âncoras SMuFL para posicionamento preciso.
class StemRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final double stemThickness;
  final SMuFLPositioningEngine positioningEngine;

  /// Ajuste visual empírico em X para haste PARA CIMA (stemUp = true)
  /// Valor determinado através de análise visual comparativa.
  /// TODO: Investigar se deve ser proporcional ao staffSpace
  static const double stemUpXOffset = 0.7; // pixels

  /// Ajuste visual empírico em X para haste PARA BAIXO (stemUp = false)
  /// Valor determinado através de análise visual comparativa.
  /// TODO: Investigar se deve ser proporcional ao staffSpace
  static const double stemDownXOffset = -0.8; // pixels (ajustar se necessário)

  StemRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
    required this.stemThickness,
    required this.positioningEngine,
  });

  /// Renderiza haste de uma nota.
  ///
  /// Retorna o Offset do final da haste (onde a bandeirola deve ser desenhada).
  ///
  /// [canvas] - Canvas onde desenhar
  /// [notePosition] - Posição da cabeça da nota (em pixels)
  /// [noteheadGlyph] - Glifo SMuFL da cabeça da nota
  /// [staffPosition] - Posição da nota na pauta (linha/espaço)
  /// [stemUp] - Se a haste vai para cima (true) ou para baixo (false)
  /// [beamCount] - Número de barras (0 para notas sem barra)
  /// [isBeamed] - Se a nota está agrupada com outras (afeta comprimento da haste)
  Offset render(
    Canvas canvas,
    Offset notePosition,
    String noteheadGlyph,
    int staffPosition,
    bool stemUp,
    int beamCount, {
    bool isBeamed = false,
  }) {
    // 1️⃣ Obter âncora SMuFL da cabeça de nota
    // Nota: getStemUpAnchor/getStemDownAnchor sempre retornam um valor
    // (têm fallback para noteheadBlack padrão se glifo não encontrado)
    final stemAnchor = stemUp
        ? positioningEngine.getStemUpAnchor(noteheadGlyph)
        : positioningEngine.getStemDownAnchor(noteheadGlyph);

    // 2️⃣ Converter âncora de staff spaces → pixels com ajuste visual
    // CORREÇÃO CRÍTICA: SMuFL usa Y+ para cima, Flutter usa Y+ para baixo
    final xOffset = stemUp ? stemUpXOffset : stemDownXOffset;
    final stemAnchorPixels = Offset(
      stemAnchor.dx * coordinates.staffSpace - xOffset, // Ajuste por direção
      -stemAnchor.dy * coordinates.staffSpace, // Y: INVERTER eixo!
    );

    // 3️⃣ Posição inicial da haste (pixels)
    final stemX = notePosition.dx + stemAnchorPixels.dx;
    final stemStartY = notePosition.dy + stemAnchorPixels.dy;

    // 4️⃣ Calcular comprimento da haste (staff spaces → pixels)
    final stemLength =
        positioningEngine.calculateStemLength(
          staffPosition: staffPosition,
          stemUp: stemUp,
          beamCount: beamCount,
          isBeamed: isBeamed, // ✅ Agora usa parâmetro!
        ) *
        coordinates.staffSpace; // Conversão para pixels

    // 5️⃣ Posição final da haste (pixels)
    // Se stemUp=true: sobe (Y diminui), senão: desce (Y aumenta)
    final stemEndY = stemUp ? stemStartY - stemLength : stemStartY + stemLength;

    // 6️⃣ Desenhar haste (linha vertical)
    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth =
          stemThickness // Já vem em pixels do staff_renderer
      ..strokeCap = StrokeCap.butt; // Ponta quadrada (padrão SMuFL)

    canvas.drawLine(
      Offset(stemX, stemStartY), // Início (na âncora)
      Offset(stemX, stemEndY), // Fim (comprimento calculado)
      stemPaint,
    );

    // 7️⃣ Retornar ponto final da haste (para bandeirolas/ligaduras)
    return Offset(stemX, stemEndY);
  }
}
