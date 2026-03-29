// lib/src/rendering/renderers/primitives/flag_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';

/// Renderer especializado Only for bandeirolas (flags) de notes.
///
/// Responsabilidade única: desenhar bandeirolas using
/// âncoras SMuFL for posicionamento preciso.
class FlagRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final SMuFLPositioningEngine positioningEngine;
  static const double flagUpXOffset = 0.7;
  static const double flagUpYOffset = 0;
  static const double flagDownXOffset = 0.7;
  static const double flagDownYOffset = 0.5;

  FlagRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
    required this.positioningEngine,
  });

  /// Renders bandeirola de a note.
  ///
  /// [canvas] - Canvas where desenhar
  /// [stemEnd] - Position of the final of the stem
  /// [duration] - Duração of the note
  /// [stemUp] - If a stem vai for top
  void render(
    Canvas canvas,
    Offset stemEnd,
    DurationType duration,
    bool stemUp,
  ) {
    final flagGlyph = _getFlagGlyph(duration, stemUp);
    if (flagGlyph == null) return;

    // Get âncora of the bandeirola
    final flagAnchor = positioningEngine.getFlagAnchor(flagGlyph);

    final flagAnchorPixels = Offset(
      flagAnchor.dx * coordinates.staffSpace,
      -flagAnchor.dy * coordinates.staffSpace,
    );

    final xOffset = stemUp ? flagUpXOffset : flagDownXOffset;
    final yOffset = stemUp ? flagUpYOffset : flagDownYOffset;

    final flagX = stemEnd.dx - flagAnchorPixels.dx - xOffset;
    final flagY = stemEnd.dy - flagAnchorPixels.dy - yOffset;

    // Desenhar bandeirola
    drawGlyphWithBBox(
      canvas,
      glyphName: flagGlyph,
      position: Offset(flagX, flagY),
      color: theme.stemColor,
      options: const GlyphDrawOptions(), // Sem centralização
    );
  }

  /// Returns o glifo SMuFL correct for a bandeirola.
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
