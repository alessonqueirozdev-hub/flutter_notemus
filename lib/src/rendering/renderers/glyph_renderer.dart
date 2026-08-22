// lib/src/rendering/renderers/glyph_renderer.dart

import 'package:flutter/material.dart';
import '../../smufl/smufl_metadata_loader.dart';

/// Central renderer for SMuFL glyphs and text.
///
/// Removes the code duplicated across the individual renderers. The music font
/// is always taken from [metadata] (`SmuflMetadata.font`), never named here.
class GlyphRenderer {
  final SmuflMetadata metadata;

  GlyphRenderer({required this.metadata});

  /// Draws a SMuFL glyph with optional centring.
  void drawGlyph(
    Canvas canvas, {
    required String glyphName,
    required Offset position,
    required double size,
    required Color color,
    bool centerVertically = false,
    bool centerHorizontally = false,
  }) {
    final character = metadata.getCodepoint(glyphName);
    if (character.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          // Font independence: never hardcode a family — see
          // BaseGlyphRenderer's "Font independence" note.
          fontFamily: metadata.font.fontFamily,
          package: metadata.font.fontPackage,
          fontSize: size,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final yOffset = centerVertically ? -textPainter.height * 0.5 : 0;
    final xOffset = centerHorizontally ? -textPainter.width * 0.5 : 0;

    textPainter.paint(
      canvas,
      Offset(position.dx + xOffset, position.dy + yOffset),
    );
  }

  /// Draws text with a caller-supplied style.
  void drawText(
    Canvas canvas, {
    required String text,
    required Offset position,
    required TextStyle style,
    TextAlign align = TextAlign.center,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }
}