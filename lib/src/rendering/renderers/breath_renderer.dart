// lib/src/rendering/renderers/breath_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';
import 'glyph_renderer.dart';

class BreathRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final GlyphRenderer glyphRenderer;

  BreathRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    required this.glyphRenderer,
  });

  void render(Canvas canvas, Breath breath, Offset position) {
    final glyphName = _getGlyphName(breath.type);
    
    // Posicionar acima da pauta (como na imagem de referência)
    final yOffset = -coordinates.staffSpace * 2.5;
    final renderPosition = Offset(position.dx, position.dy + yOffset);
    
    glyphRenderer.drawGlyph(
      canvas,
      glyphName: glyphName,
      position: renderPosition,
      size: glyphSize,
      color: theme.articulationColor, // Usar cor de articulação
    );
  }

  String _getGlyphName(BreathType type) {
    switch (type) {
      case BreathType.comma:
        return 'breathMarkComma';
      case BreathType.tick:
        return 'breathMarkTick';
      case BreathType.upbow:
        return 'breathMarkUpbow';
      case BreathType.caesura:
        return 'caesura';
      case BreathType.shortCaesura:
        return 'caesuraShort';
      case BreathType.longCaesura:
        return 'caesuraThick';
      case BreathType.chokeCymbal:
        return 'brassMuteHalfClosed'; // Aproximação
    }
  }
}
