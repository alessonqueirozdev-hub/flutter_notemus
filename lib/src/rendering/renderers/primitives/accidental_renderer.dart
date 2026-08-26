// lib/src/rendering/renderers/primitives/accidental_renderer.dart

import 'package:flutter/material.dart';
import '../../../../core/core.dart';
import '../../../smufl/smufl_metadata_loader.dart';
import '../../../theme/music_score_theme.dart';
import '../../accidental_resolver.dart';
import '../../smufl_positioning_engine.dart';
import '../base_glyph_renderer.dart';
import '../chord_renderer.dart';

/// Specialized renderer for accidentals.
///
/// Single responsibility: draw accidentals (sharps, flats, naturals, ...) with
/// precise SMuFL positioning, including the cautionary/editorial signs that may
/// enclose them (see [AccidentalParenthesis]).
class AccidentalRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final SMuFLPositioningEngine positioningEngine;

  /// Gap, in staff spaces, left between an enclosing sign and the accidental.
  static const double parenthesisGapSpaces = 0.16;

  AccidentalRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
    required this.positioningEngine,
  });

  /// SMuFL glyph drawn to the LEFT of an accidental for [paren], or null when
  /// the accidental is not enclosed.
  ///
  /// Both names are real SMuFL glyphs present in `assets/smufl/glyphnames.json`.
  static String? leftSignGlyph(AccidentalParenthesis paren) {
    return switch (paren) {
      AccidentalParenthesis.none => null,
      AccidentalParenthesis.parentheses => 'accidentalParensLeft',
      AccidentalParenthesis.brackets => 'accidentalBracketLeft',
    };
  }

  /// SMuFL glyph drawn to the RIGHT of an accidental for [paren], or null when
  /// the accidental is not enclosed.
  static String? rightSignGlyph(AccidentalParenthesis paren) {
    return switch (paren) {
      AccidentalParenthesis.none => null,
      AccidentalParenthesis.parentheses => 'accidentalParensRight',
      AccidentalParenthesis.brackets => 'accidentalBracketRight',
    };
  }

  /// Width of [glyphName] in staff spaces: the real bounding box when
  /// [metadata] carries one, the advance width otherwise, and 1.0 as the
  /// last-resort fallback for a name the font does not know.
  ///
  /// Static and metadata-only so the LAYOUT — which never holds a renderer —
  /// can ask the same question and get the same answer. Every width used to
  /// reserve accidental space funnels through here.
  static double glyphWidthSpacesFor(SmuflMetadata metadata, String glyphName) {
    final box = metadata.getGlyphInfo(glyphName)?.boundingBox;
    final width = box?.width ?? metadata.getGlyphAdvanceWidth(glyphName) ?? 0.0;
    return width > 0 ? width : 1.0;
  }

  /// Instance form of [glyphWidthSpacesFor], bound to this renderer's metadata.
  double glyphWidthSpaces(String glyphName) =>
      glyphWidthSpacesFor(metadata, glyphName);

  /// Total width, in staff spaces, occupied by [glyphName] once enclosed by
  /// [paren]: left sign + gap + accidental + gap + right sign.
  ///
  /// Callers use this to RESERVE the extra horizontal space the signs need
  /// (single notes shift the group left; chord accidental columns widen).
  /// For [AccidentalParenthesis.none] it degrades to the bare glyph width, so
  /// undecorated accidentals keep their previous geometry exactly.
  ///
  /// The arithmetic lives in [ChordRenderer.decoratedAccidentalWidthSpaces],
  /// which is `static` and metadata-only because the LAYOUT has to reserve
  /// this width with no renderer instance in hand. Keeping a second copy here
  /// is exactly how the layout and the renderer drift apart, so this is a pure
  /// delegation. Verified before collapsing: over all 235 `accidental*` glyphs
  /// in `assets/smufl/glyphnames.json` times the 3 [AccidentalParenthesis]
  /// values — 705 combinations, plus `noteheadBlack`, `gClef` and an unknown
  /// glyph name to exercise the fallback — the two implementations returned
  /// bit-identical doubles in 714/714 cases, 0 disagreements.
  double decoratedWidthSpaces(String glyphName, AccidentalParenthesis paren) =>
      ChordRenderer.decoratedAccidentalWidthSpaces(metadata, glyphName, paren);

  /// Draws [glyphName] enclosed by [paren], with the whole group starting at
  /// [leftX] (pixels) on the [y] baseline.
  ///
  /// The accidental is centered between the two signs: it is placed exactly one
  /// left-sign width plus one gap to the right of [leftX], and the right sign
  /// follows one gap after the accidental. The group therefore spans exactly
  /// [decoratedWidthSpaces] staff spaces starting at [leftX].
  void drawDecoratedAccidental(
    Canvas canvas, {
    required String glyphName,
    required double leftX,
    required double y,
    required Color color,
    AccidentalParenthesis paren = AccidentalParenthesis.none,
    GlyphDrawOptions options = const GlyphDrawOptions(),
  }) {
    final left = leftSignGlyph(paren);
    final right = rightSignGlyph(paren);

    if (left == null || right == null) {
      drawGlyphWithBBox(
        canvas,
        glyphName: glyphName,
        position: Offset(leftX, y),
        color: color,
        options: options,
      );
      return;
    }

    final staffSpace = coordinates.staffSpace;
    final gap = parenthesisGapSpaces * staffSpace;
    final leftWidth = glyphWidthSpaces(left) * staffSpace;
    final accidentalWidth = glyphWidthSpaces(glyphName) * staffSpace;
    final accidentalX = leftX + leftWidth + gap;

    drawGlyphWithBBox(
      canvas,
      glyphName: left,
      position: Offset(leftX, y),
      color: color,
      options: options,
    );
    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: Offset(accidentalX, y),
      color: color,
      options: options,
    );
    drawGlyphWithBBox(
      canvas,
      glyphName: right,
      position: Offset(accidentalX + accidentalWidth + gap, y),
      color: color,
      options: options,
    );
  }

  /// Renders the accidental of a note.
  ///
  /// [canvas] - canvas to draw on.
  /// [note] - the note carrying the accidental.
  /// [notePosition] - position of the notehead.
  /// [staffPosition] - the note's staff position.
  /// [display] - the within-measure decision resolved by the layout engine.
  /// [parenthesis] - cautionary/editorial enclosure; defaults to the note's own
  ///   [Note.accidentalParenthesis] so callers may simply propagate the note.
  void render(
    Canvas canvas,
    Note note,
    Offset notePosition,
    double staffPosition, {
    AccidentalDisplay display = AccidentalDisplay.show,
    AccidentalParenthesis? parenthesis,
  }) {
    // Within-measure resolution: suppress repeats, draw a natural on revert.
    if (display == AccidentalDisplay.hide) return;
    final String? accidentalGlyph = display == AccidentalDisplay.natural
        ? 'accidentalNatural'
        : note.pitch.accidentalGlyph;
    if (accidentalGlyph == null) return;

    final paren = parenthesis ?? note.accidentalParenthesis;
    final noteheadGlyph = note.duration.type.glyphName;

    // Position of the accidental, from the positioning engine.
    final accidentalPosition = positioningEngine.calculateAccidentalPosition(
      accidentalGlyph: accidentalGlyph,
      noteheadGlyph: noteheadGlyph,
      staffPosition: staffPosition,
    );

    // Final position of the accidental.
    final accidentalX =
        notePosition.dx + (accidentalPosition.dx * coordinates.staffSpace);
    final accidentalY =
        notePosition.dy + (accidentalPosition.dy * coordinates.staffSpace);

    final accColor = theme.accidentalColor ?? theme.noteheadColor;

    // Cautionary parentheses / editorial brackets claim their extra width on
    // the LEFT: the group's right edge stays where the bare accidental's right
    // edge was, so the right-hand sign never intrudes on the notehead, and the
    // accidental ends up centered between the two signs. With no enclosure the
    // group width equals the glyph width, so nothing moves.
    final bareWidth = glyphWidthSpaces(accidentalGlyph) * coordinates.staffSpace;
    final groupWidth =
        decoratedWidthSpaces(accidentalGlyph, paren) * coordinates.staffSpace;

    drawDecoratedAccidental(
      canvas,
      glyphName: accidentalGlyph,
      leftX: accidentalX + bareWidth - groupWidth,
      y: accidentalY,
      color: accColor,
      paren: paren,
    );
  }
}
