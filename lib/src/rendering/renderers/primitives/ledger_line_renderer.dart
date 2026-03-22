// lib/src/rendering/renderers/primitives/ledger_line_renderer.dart

import 'package:flutter/material.dart';
import '../../../theme/music_score_theme.dart';
import '../../staff_position_calculator.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para linhas suplementares (ledger lines).
///
/// Responsabilidade única: desenhar linhas suplementares para notas
/// fora do pentagrama.
class LedgerLineRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final double staffLineThickness;

  LedgerLineRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
    required this.staffLineThickness,
  });

  /// Renderiza linhas suplementares para uma nota.
  ///
  /// [canvas] - Canvas onde desenhar
  /// [notePosition] - Posição X da nota (borda ESQUERDA do glifo)
  /// [staffPosition] - Posição da nota na pauta
  /// [noteheadGlyph] - Glifo da cabeça da nota (para calcular largura)
  void render(
    Canvas canvas,
    double notePosition,
    int staffPosition,
    String noteheadGlyph,
  ) {
    if (!theme.showLedgerLines) return;

    // Verificar se a nota precisa de linhas suplementares
    if (!StaffPositionCalculator.needsLedgerLines(staffPosition)) return;

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness;

    // CORREÇÃO CRÍTICA: Calcular centro horizontal CORRETO da nota
    // notePosition é a borda ESQUERDA do glifo (conforme drawGlyphWithBBox)
    // Precisamos adicionar a distância até o centro
    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;

    // Centro relativo ao início do glyph (em staff spaces)
    final centerOffsetSS = bbox != null
        ? (bbox.bBoxSwX + bbox.bBoxNeX) / 2
        : 1.18 / 2; // Fallback: noteheadBlack tem largura ~1.18
    
    // CORREÇÃO: Converter para pixels CORRETAMENTE
    final centerOffsetPixels = centerOffsetSS * coordinates.staffSpace;
    
    // Posição X do centro da nota
    final noteCenterX = notePosition + centerOffsetPixels;

    // Calcular largura da linha baseada no glifo real + extensão SMuFL
    final noteWidth =
        bbox?.widthInPixels(coordinates.staffSpace) ??
        (coordinates.staffSpace * 1.18);

    // CORREÇÃO SMuFL: Usar legerLineExtension do metadata (0.4 staff spaces)
    final extension = coordinates.staffSpace * 0.4;
    final totalWidth = noteWidth + (2 * extension);

    // Obter posições das linhas suplementares
    final ledgerPositions = StaffPositionCalculator.getLedgerLinePositions(
      staffPosition,
    );

    // Desenhar cada linha suplementar CENTRALIZADA na cabeça de nota
    for (final pos in ledgerPositions) {
      final y = StaffPositionCalculator.toPixelY(
        pos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      // CORREÇÃO: Usar noteCenterX como referência para centralização
      final lineStartX = noteCenterX - (totalWidth / 2);
      final lineEndX = noteCenterX + (totalWidth / 2);

      canvas.drawLine(
        Offset(lineStartX, y),
        Offset(lineEndX, y),
        paint,
      );
    }
  }
}
