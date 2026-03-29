// lib/src/rendering/renderers/primitives/accidental_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';

/// Renderer especializado Only for accidentals (accidentals).
///
/// Responsabilidade única: desenhar accidentals (sharps, bemóis, etc.)
/// using posicionamento SMuFL preciso.
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

  /// Renders accidental de a note.
  ///
  /// [canvas] - Canvas where desenhar
  /// [note] - Note with accidental
  /// [notePosition] - Position of the cabeça of the note
  /// [staffPosition] - Position of the note na staff
  void render(
    Canvas canvas,
    Note note,
    Offset notePosition,
    double staffPosition,
  ) {
    if (note.pitch.accidentalGlyph == null) return;

    final accidentalGlyph = note.pitch.accidentalGlyph!;
    final noteheadGlyph = note.duration.type.glyphName;

    // Calculate position of the accidental using positioning engine
    final accidentalPosition = positioningEngine.calculateAccidentalPosition(
      accidentalGlyph: accidentalGlyph,
      noteheadGlyph: noteheadGlyph,
      staffPosition: staffPosition,
    );

    // Position final of the accidental
    final accidentalX =
        notePosition.dx + (accidentalPosition.dx * coordinates.staffSpace);
    final accidentalY =
        notePosition.dy + (accidentalPosition.dy * coordinates.staffSpace);

    // Desenhar accidental
    drawGlyphWithBBox(
      canvas,
      glyphName: accidentalGlyph,
      position: Offset(accidentalX, accidentalY),
      color: theme.accidentalColor ?? theme.noteheadColor,
      options: const GlyphDrawOptions(),
    );
  }
}
