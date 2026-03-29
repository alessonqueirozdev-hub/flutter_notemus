// lib/src/rendering/renderers/primitives/ledger_line_renderer.dart

import 'package:flutter/material.dart';
import '../../../theme/music_score_theme.dart';
import '../../staff_position_calculator.dart';
import '../base_glyph_renderer.dart';

/// Renderer especializado Only for ledger lines (ledger lines).
///
/// Responsabilidade única: desenhar ledger lines for notes
/// outside of the staff.
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

  /// Renders ledger lines for a note.
  ///
  /// [canvas] - Canvas where desenhar
  /// [notePosition] - X position of the note (borda Left of the glifo)
  /// [staffPosition] - Position of the note na staff
  /// [noteheadGlyph] - Glifo of the cabeça of the note (for Calculate width)
  void render(
    Canvas canvas,
    double notePosition,
    int staffPosition,
    String noteheadGlyph,
  ) {
    if (!theme.showLedgerLines) return;

    // Check if a note needs de ledger lines
    if (!StaffPositionCalculator.needsLedgerLines(staffPosition)) return;

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness;

    // Fix: CRÍTICA: Calculate centre horizontal Correct of the note
    // notePosition is a borda Left of the glifo (according to drawGlyphWithBBox)
    // Precisamos add a distance until o centre
    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;

    // Centre relativo to the start of the glyph (in staff spaces)
    final centerOffsetSS = bbox != null
        ? (bbox.bBoxSwX + bbox.bBoxNeX) / 2
        : 1.18 / 2; // Fallback: noteheadBlack tem largura ~1.18
    
    // Fix: Convert for pixels CORRETAMENTE
    final centerOffsetPixels = centerOffsetSS * coordinates.staffSpace;
    
    // X position of the centre of the note
    final noteCenterX = notePosition + centerOffsetPixels;

    // Calculate width of the line baseada no glifo real + extension SMuFL
    final noteWidth =
        bbox?.widthInPixels(coordinates.staffSpace) ??
        (coordinates.staffSpace * 1.18);

    // Fix: SMuFL: Use legerLineExtension of the metadata (0.4 staff spaces)
    final extension = coordinates.staffSpace * 0.4;
    final totalWidth = noteWidth + (2 * extension);

    // Get positions das ledger lines
    final ledgerPositions = StaffPositionCalculator.getLedgerLinePositions(
      staffPosition,
    );

    // Desenhar each ledger line Centred na notehead
    for (final pos in ledgerPositions) {
      final y = StaffPositionCalculator.toPixelY(
        pos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      // Fix: Use noteCenterX as reference for centralização
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
