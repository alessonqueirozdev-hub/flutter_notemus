// lib/src/rendering/renderers/primitives/ledger_line_renderer.dart

import 'package:flutter/material.dart';
import '../../../theme/music_score_theme.dart';
import '../../staff_position_calculator.dart';
import '../base_glyph_renderer.dart';

/// Rendersdor especializado APENAS for linhas suplementares (ledger lines).
///
/// Responsabilidade única: desenhar linhas suplementares for notes
/// fora of the staff.
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

  /// Renders linhas suplementares for a note.
  ///
  /// [canvas] - Canvas where desenhar
  /// [notePosition] - X position of the note (borda ESQUERDA of the glifo)
  /// [staffPosition] - Position of the note na staff
  /// [noteheadGlyph] - Glifo of the cabeça of the note (for Calculatestesr width)
  void render(
    Canvas canvas,
    double notePosition,
    int staffPosition,
    String noteheadGlyph,
  ) {
    if (!theme.showLedgerLines) return;

    // Checksr se a note precisa de linhas suplementares
    if (!StaffPositionCalculator.needsLedgerLines(staffPosition)) return;

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness;

    // Fix: CRÍTICA: Calculate centro horizontal CORRETO of the note
    // notePosition é a borda ESQUERDA of the glifo (according to drawGlyphWithBBox)
    // Precisamos add a distância até o centro
    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;

    // Centro relativo ao início of the glyph (in staff spaces)
    final centerOffsetSS = bbox != null
        ? (bbox.bBoxSwX + bbox.bBoxNeX) / 2
        : 1.18 / 2; // Fallback: noteheadBlack tem largura ~1.18
    
    // Fix: Convert for pixels CORRETAMENTE
    final centerOffsetPixels = centerOffsetSS * coordinates.staffSpace;
    
    // X position of the centro of the note
    final noteCenterX = notePosition + centerOffsetPixels;

    // Calculatestesr width of the linha baseada no glifo real + extensão SMuFL
    final noteWidth =
        bbox?.widthInPixels(coordinates.staffSpace) ??
        (coordinates.staffSpace * 1.18);

    // Fix: SMuFL: Use legerLineExtension of the metadata (0.4 staff spaces)
    final extension = coordinates.staffSpace * 0.4;
    final totalWidth = noteWidth + (2 * extension);

    // Get positions das linhas suplementares
    final ledgerPositions = StaffPositionCalculator.getLedgerLinePositions(
      staffPosition,
    );

    // Desenhar each linha suplementar CENTRALIZADA na notehead
    for (final pos in ledgerPositions) {
      final y = StaffPositionCalculator.toPixelY(
        pos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      // Fix: Use noteCenterX como reference for centralização
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
