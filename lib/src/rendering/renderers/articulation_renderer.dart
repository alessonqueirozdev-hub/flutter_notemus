// lib/src/rendering/renderers/articulation_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../theme/music_score_theme.dart';
import 'base_glyph_renderer.dart';

class ArticulationRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;

  ArticulationRenderer({
    required super.coordinates,
    required super.metadata,
    required this.theme,
    required super.glyphSize,
    super.collisionDetector, // CORREÇÃO: Passar collision detector para BaseGlyphRenderer
  });

  void render(
    Canvas canvas,
    List<ArticulationType> articulations,
    Offset notePos,
    int staffPosition,
  ) {
    if (articulations.isEmpty) return;

    final stemUp = staffPosition < 0;
    final articulationAbove = !stemUp;
    final yOffset = articulationAbove
        ? -coordinates.staffSpace * 1.5
        : coordinates.staffSpace * 1.2;

    for (final articulation in articulations) {
      final glyphName = _getArticulationGlyph(articulation, articulationAbove);
      if (glyphName != null) {
        final target = Offset(notePos.dx, notePos.dy + yOffset);
        // Alinhar pelo opticalCenter quando disponível; sem subtrações indevidas
        drawGlyphAlignedToAnchor(
          canvas,
          glyphName: glyphName,
          anchorName: 'opticalCenter',
          target: target,
          color: theme.articulationColor,
          options: GlyphDrawOptions.articulationDefault.copyWith(
            size: glyphSize * 0.8,
          ),
        );
      }
    }
  }

  String? _getArticulationGlyph(ArticulationType type, bool above) {
    return switch (type) {
      ArticulationType.staccato => 'augmentationDot',
      ArticulationType.staccatissimo =>
        above ? 'articStaccatissimoAbove' : 'articStaccatissimoBelow',
      ArticulationType.accent =>
        above ? 'articAccentAbove' : 'articAccentBelow',
      ArticulationType.strongAccent || ArticulationType.marcato =>
        above ? 'articMarcatoAbove' : 'articMarcatoBelow',
      ArticulationType.tenuto =>
        above ? 'articTenutoAbove' : 'articTenutoBelow',
      ArticulationType.upBow => 'stringsUpBow',
      ArticulationType.downBow => 'stringsDownBow',
      ArticulationType.harmonics => 'stringsHarmonic',
      ArticulationType.pizzicato => 'pluckedPizzicato',
      _ => null,
    };
  }
}
