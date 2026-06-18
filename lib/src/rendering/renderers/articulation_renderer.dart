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

    // Stack multiple articulations outward from the notehead (Behind Bars):
    // dot/tenuto closest, accent/marcato outside, bowing/mutes outermost.
    final ordered = [...articulations]
      ..sort((a, b) => _stackRank(a).compareTo(_stackRank(b)));

    double nextClearSS = 0.0;
    var first = true;
    for (final articulation in ordered) {
      final glyphName = _getArticulationGlyph(articulation, articulationAbove);
      if (glyphName == null) continue;

      // A8 FIX: Behind Bars standard: 0.5 SS clearance from notehead to optical
      // centre of the FIRST articulation; each further mark stacks beyond it.
      if (first) {
        nextClearSS = _getArticulationClearanceSS(articulation);
        first = false;
      }
      final clearanceSS = nextClearSS;
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

      final glyphHeight =
          metadata.getGlyphInfo(glyphName)?.boundingBox?.height ?? 0.8;
      nextClearSS += glyphHeight + 0.3;
    }
  }

  /// Stacking order from the notehead outward (lower = closer).
  static int _stackRank(ArticulationType type) => switch (type) {
        ArticulationType.staccato || ArticulationType.staccatissimo => 0,
        ArticulationType.tenuto || ArticulationType.portato => 1,
        ArticulationType.accent => 2,
        ArticulationType.strongAccent || ArticulationType.marcato => 3,
        _ => 4,
      };

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
      ArticulationType.portato =>
        above ? 'articTenutoStaccatoAbove' : 'articTenutoStaccatoBelow',
      ArticulationType.snap =>
        above ? 'pluckedSnapPizzicatoAbove' : 'pluckedSnapPizzicatoBelow',
      ArticulationType.thumb => 'stringsThumbPosition',
      ArticulationType.stopped => 'brassMuteClosed',
      ArticulationType.open => 'brassMuteOpen',
      ArticulationType.halfStopped => 'brassMuteHalfClosed',
      // legato is rendered as a slur, not an articulation glyph.
      ArticulationType.legato => null,
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
