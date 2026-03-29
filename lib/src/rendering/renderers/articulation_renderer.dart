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
    Offset notePos, {
    required bool stemUp,
  }) {
    if (articulations.isEmpty) return;

    final articulationAbove = !stemUp;

    for (final articulation in articulations) {
      final glyphName = _getArticulationGlyph(articulation, articulationAbove);
      if (glyphName == null) continue;

      // A8 FIX: Behind Bars standard: 0.5 SS clearance from notehead to
      // optical centre of articulation (previously 1.5/1.2 SS – too far).
      final clearanceSS = _getArticulationClearanceSS(articulation);
      final yOffsetPx = articulationAbove
          ? -coordinates.staffSpace * clearanceSS
          : coordinates.staffSpace * clearanceSS;
      final target = Offset(notePos.dx, notePos.dy + yOffsetPx);
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

  static double getArticulationClearanceSS(ArticulationType type) {
    // Clearance is measured from the notehead Y origin (SMuFL glyph origin =
    // vertical center of the notehead). Behind Bars: minimum 0.5 SS from the
    // notehead EDGE; with notehead height ~0.7 SS, centre-to-edge = ~0.35 SS,
    // so centre-to-articulation = 0.35 + gap. Staccato gap: ~0.65 SS → 1.0 SS.
    return switch (type) {
      ArticulationType.staccato => 1.0,
      ArticulationType.tenuto => 1.1,
      ArticulationType.accent => 1.2,
      ArticulationType.strongAccent || ArticulationType.marcato => 1.3,
      ArticulationType.staccatissimo => 1.2,
      ArticulationType.upBow ||
      ArticulationType.downBow ||
      ArticulationType.harmonics ||
      ArticulationType.pizzicato => 1.3,
      _ => 1.0,
    };
  }

  double _getArticulationClearanceSS(ArticulationType type) {
    return getArticulationClearanceSS(type);
  }
}
