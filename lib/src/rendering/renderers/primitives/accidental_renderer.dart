// lib/src/rendering/renderers/primitives/accidental_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../theme/music_score_theme.dart';
import '../../accidental_resolver.dart';
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
    double staffPosition, {
    AccidentalDisplay display = AccidentalDisplay.show,
  }) {
    // Within-measure resolution: suppress repeats, draw a natural on revert.
    if (display == AccidentalDisplay.hide) return;
    final String? accidentalGlyph = display == AccidentalDisplay.natural
        ? 'accidentalNatural'
        : note.pitch.accidentalGlyph;
    if (accidentalGlyph == null) return;

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
    final accColor = theme.accidentalColor ?? theme.noteheadColor;

    drawGlyphWithBBox(
      canvas,
      glyphName: accidentalGlyph,
      position: Offset(accidentalX, accidentalY),
      color: accColor,
      options: const GlyphDrawOptions(),
    );

    // Cautionary/editorial brackets around the accidental.
    if (note.accidentalParenthesis != AccidentalParenthesis.none) {
      final isBracket =
          note.accidentalParenthesis == AccidentalParenthesis.brackets;
      final leftGlyph =
          isBracket ? 'accidentalBracketLeft' : 'accidentalParensLeft';
      final rightGlyph =
          isBracket ? 'accidentalBracketRight' : 'accidentalParensRight';
      final accWidth = metadata.getGlyphAdvanceWidth(accidentalGlyph) ?? 1.0;
      final gap = 0.18 * coordinates.staffSpace;
      drawGlyphWithBBox(
        canvas,
        glyphName: leftGlyph,
        position: Offset(accidentalX - gap, accidentalY),
        color: accColor,
        options: const GlyphDrawOptions(),
      );
      drawGlyphWithBBox(
        canvas,
        glyphName: rightGlyph,
        position: Offset(
          accidentalX + accWidth * coordinates.staffSpace + gap,
          accidentalY,
        ),
        color: accColor,
        options: const GlyphDrawOptions(),
      );
    }
  }
}
