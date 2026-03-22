// lib/src/rendering/renderers/primitives/flag_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para bandeirolas (flags) de notas.
///
/// Responsabilidade única: desenhar bandeirolas usando
/// âncoras SMuFL para posicionamento preciso.
class FlagRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final SMuFLPositioningEngine positioningEngine;

  // ========== AJUSTES PARA BANDEIROLA PARA CIMA (stemUp = true) ==========
  /// Ajuste visual empírico em X para bandeirola PARA CIMA
  /// Valor determinado através de análise visual comparativa.
  /// TODO: Investigar se deve ser proporcional ao staffSpace
  static const double flagUpXOffset = 0.7; // pixels

  /// Ajuste visual empírico em Y para bandeirola PARA CIMA
  /// Valor determinado através de análise visual comparativa.
  /// TODO: Investigar se deve ser proporcional ao staffSpace
  static const double flagUpYOffset =
      0; // pixels (negativo porque Y+ é para baixo)

  // ========== AJUSTES PARA BANDEIROLA PARA BAIXO (stemUp = false) ==========
  /// Ajuste visual empírico em X para bandeirola PARA BAIXO
  /// Valor determinado através de análise visual comparativa.
  /// TODO: Investigar se deve ser proporcional ao staffSpace
  static const double flagDownXOffset = 0.7; // pixels (ajustar se necessário)

  /// Ajuste visual empírico em Y para bandeirola PARA BAIXO
  /// Valor determinado através de análise visual comparativa.
  /// TODO: Investigar se deve ser proporcional ao staffSpace
  static const double flagDownYOffset = 0.5; // pixels (ajustar se necessário)

  FlagRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
    required this.positioningEngine,
  });

  /// Renderiza bandeirola de uma nota.
  ///
  /// [canvas] - Canvas onde desenhar
  /// [stemEnd] - Posição do final da haste
  /// [duration] - Duração da nota
  /// [stemUp] - Se a haste vai para cima
  void render(
    Canvas canvas,
    Offset stemEnd,
    DurationType duration,
    bool stemUp,
  ) {
    final flagGlyph = _getFlagGlyph(duration, stemUp);
    if (flagGlyph == null) return;

    // Obter âncora da bandeirola
    final flagAnchor = positioningEngine.getFlagAnchor(flagGlyph);

    // Converter âncora de spaces para pixels
    // CORREÇÃO CRÍTICA: SMuFL usa Y+ para cima, Flutter usa Y+ para baixo
    final flagAnchorPixels = Offset(
      flagAnchor.dx * coordinates.staffSpace,
      -flagAnchor.dy * coordinates.staffSpace, // INVERTER Y!
    );

    // Calcular posição da bandeirola com ajustes visuais (diferentes para cima/baixo)
    final xOffset = stemUp ? flagUpXOffset : flagDownXOffset;
    final yOffset = stemUp ? flagUpYOffset : flagDownYOffset;

    final flagX = stemEnd.dx - flagAnchorPixels.dx - xOffset;
    final flagY =
        stemEnd.dy -
        flagAnchorPixels.dy -
        yOffset; // Nota: yOffset já é negativo

    // Desenhar bandeirola
    drawGlyphWithBBox(
      canvas,
      glyphName: flagGlyph,
      position: Offset(flagX, flagY),
      color: theme.stemColor,
      options: const GlyphDrawOptions(), // Sem centralização
    );
  }

  /// Retorna o glifo SMuFL correto para a bandeirola.
  String? _getFlagGlyph(DurationType duration, bool stemUp) {
    return switch (duration) {
      DurationType.eighth => stemUp ? 'flag8thUp' : 'flag8thDown',
      DurationType.sixteenth => stemUp ? 'flag16thUp' : 'flag16thDown',
      DurationType.thirtySecond => stemUp ? 'flag32ndUp' : 'flag32ndDown',
      DurationType.sixtyFourth => stemUp ? 'flag64thUp' : 'flag64thDown',
      _ => null,
    };
  }
}
