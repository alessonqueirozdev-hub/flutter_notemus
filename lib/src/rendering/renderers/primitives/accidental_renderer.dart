// lib/src/rendering/renderers/primitives/accidental_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';

/// Renderizador especializado APENAS para acidentes (accidentals).
///
/// Responsabilidade única: desenhar acidentes (sustenidos, bemóis, etc.)
/// usando posicionamento SMuFL preciso.
class AccidentalRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final SMuFLPositioningEngine positioningEngine;

  AccidentalRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
    required this.positioningEngine,
  });

  /// Renderiza acidente de uma nota.
  ///
  /// [canvas] - Canvas onde desenhar
  /// [note] - Nota com acidente
  /// [notePosition] - Posição da cabeça da nota
  /// [staffPosition] - Posição da nota na pauta
  void render(
    Canvas canvas,
    Note note,
    Offset notePosition,
    double staffPosition,
  ) {
    if (note.pitch.accidentalGlyph == null) return;

    final accidentalGlyph = note.pitch.accidentalGlyph!;
    final noteheadGlyph = note.duration.type.glyphName;

    // Calcular posição do acidente usando positioning engine
    final accidentalPosition = positioningEngine.calculateAccidentalPosition(
      accidentalGlyph: accidentalGlyph,
      noteheadGlyph: noteheadGlyph,
      staffPosition: staffPosition,
    );

    // Posição final do acidente
    final accidentalX =
        notePosition.dx + (accidentalPosition.dx * coordinates.staffSpace);
    final accidentalY =
        notePosition.dy + (accidentalPosition.dy * coordinates.staffSpace);

    // Desenhar acidente
    drawGlyphWithBBox(
      canvas,
      glyphName: accidentalGlyph,
      position: Offset(accidentalX, accidentalY),
      color: theme.accidentalColor ?? theme.noteheadColor,
      options: const GlyphDrawOptions(),
    );
  }
}
