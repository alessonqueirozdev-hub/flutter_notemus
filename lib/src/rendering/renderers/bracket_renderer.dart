// lib/src/rendering/renderers/bracket_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/staff_group.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../staff_coordinate_system.dart';
import '../../theme/music_score_theme.dart';

/// Renderer for staff group brackets and braces
///
/// Handles rendering of:
/// - Curly braces { for keyboard instruments (piano, organ, harp)
/// - Square brackets [ for vocal groups and orchestral sections
/// - Vertical lines | for multiple instances of same instrument
///
/// References:
/// - "Behind Bars" by Elaine Gould - Chapter on Score Layout
/// - SMuFL specification for brace glyphs
class BracketRenderer {
  final StaffCoordinateSystem coordinates;
  final MusicScoreTheme theme;

  /// SMuFL metadata used to render the `brace` glyph. When null (or the glyph
  /// is unavailable), brace rendering degrades to a custom-path fallback.
  final SmuflMetadata? metadata;

  BracketRenderer({
    required this.coordinates,
    required this.theme,
    this.metadata,
  });

  /// Render bracket/brace for a staff group
  ///
  /// [canvas] - Canvas to draw on
  /// [staffGroup] - The staff group to render bracket for
  /// [topStaffY] - Y coordinate of top staff in group
  /// [bottomStaffY] - Y coordinate of bottom staff in group
  /// [leftX] - X coordinate for bracket/brace (left edge of system)
  void render(
    Canvas canvas,
    StaffGroup staffGroup,
    double topStaffY,
    double bottomStaffY,
    double leftX,
  ) {
    // No rendering needed for no bracket
    if (staffGroup.bracket == BracketType.none) {
      return;
    }

    // Get Configurestion for bracket type
    final config = _getConfigForType(staffGroup.bracket);

    // calculateTeste bracket position
    final bracketX = leftX - (config.horizontalOffset * coordinates.staffSpace);
    final bracketHeight = bottomStaffY - topStaffY;

    switch (staffGroup.bracket) {
      case BracketType.brace:
        _renderBrace(canvas, bracketX, topStaffY, bracketHeight);
        break;
      case BracketType.bracket:
        _renderBracket(canvas, bracketX, topStaffY, bracketHeight, config);
        break;
      case BracketType.line:
        _renderLine(canvas, bracketX, topStaffY, bracketHeight, config);
        break;
      case BracketType.none:
        break; // Already handled above
    }
  }

  /// Render instrument name for staff group
  ///
  /// Displayed to the left of the bracket/brace
  void renderInstrumentName(
    Canvas canvas,
    StaffGroup staffGroup,
    double centerY,
    double leftX, {
    bool useAbbreviation = false,
  }) {
    final name = useAbbreviation && staffGroup.abbreviation != null
        ? staffGroup.abbreviation!
        : staffGroup.name;

    if (name == null || name.isEmpty) return;

    // Position name to the left of bracket
    final nameX = leftX - (2.5 * coordinates.staffSpace);

    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: theme.textStyle?.copyWith(
              fontSize: coordinates.staffSpace * 1.2,
              fontWeight: FontWeight.w500,
            ) ??
            TextStyle(
              fontSize: coordinates.staffSpace * 1.2,
              fontWeight: FontWeight.w500,
              color: theme.textColor,
            ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Center vertically on the group
    final textY = centerY - (textPainter.height / 2);

    textPainter.paint(canvas, Offset(nameX - textPainter.width, textY));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PRIVATE RENDERING METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Render curly brace `{` spanning a staff group.
  ///
  /// Prefers the SMuFL `brace` glyph (U+E000), which is designed to be
  /// stretched vertically to span any number of staves. Falls back to a
  /// custom cubic path when SMuFL metadata or the glyph is unavailable.
  void _renderBrace(
    Canvas canvas,
    double x,
    double topY,
    double height,
  ) {
    if (_renderBraceGlyph(canvas, x, topY, height)) {
      return;
    }
    _renderBraceFallbackPath(canvas, x, topY, height);
  }

  /// Draws the SMuFL `brace` glyph stretched vertically to [height].
  ///
  /// The glyph is anchored at its right edge against [x] (so the brace tips
  /// face the staves) and non-uniformly scaled on Y to span the group while
  /// keeping its designed horizontal thickness. Returns false when the glyph
  /// cannot be drawn so the caller can fall back.
  bool _renderBraceGlyph(
    Canvas canvas,
    double x,
    double topY,
    double height,
  ) {
    final md = metadata;
    if (md == null || !md.hasGlyph('brace')) return false;

    final character = md.getCodepoint('brace');
    if (character.isEmpty) return false;

    final bbox = md.getGlyphBoundingBox('brace');
    if (bbox == null || bbox.height <= 0) return false;

    // SMuFL fonts use 1 em == 4 staff spaces; rendering at that font size makes
    // metadata staff-space metrics map to staffSpace px directly.
    final double fontSize = coordinates.staffSpace * 4.0;
    final double naturalHeightPx = bbox.heightInPixels(coordinates.staffSpace);
    final double naturalWidthPx = bbox.widthInPixels(coordinates.staffSpace);
    if (naturalHeightPx <= 0) return false;

    final double scaleY = height / naturalHeightPx;

    final painter = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: fontSize,
          color: theme.barlineColor,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    // Place the glyph's right edge at x, top at topY, then stretch on Y only.
    canvas.translate(x - naturalWidthPx, topY);
    canvas.scale(1.0, scaleY);
    // Compensate the glyph's own top bearing so it starts exactly at topY.
    final double topBearingPx = bbox.bBoxNeY * coordinates.staffSpace;
    painter.paint(canvas, Offset(0, -topBearingPx - painter.height * 0.5));
    canvas.restore();
    return true;
  }

  /// Custom cubic-path brace used when the SMuFL glyph is unavailable.
  void _renderBraceFallbackPath(
    Canvas canvas,
    double x,
    double topY,
    double height,
  ) {
    final paint = Paint()
      ..color = theme.barlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = coordinates.staffSpace * 0.16
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Brace is drawn as a symmetric curve
    final centerY = topY + (height / 2);
    final controlPointOffset = coordinates.staffSpace * 0.8;

    // Top half of brace (outward curve)
    path.moveTo(x, topY);
    path.cubicTo(
      x - controlPointOffset,
      topY + (height * 0.15),
      x - controlPointOffset,
      centerY - (height * 0.1),
      x,
      centerY,
    );

    // Bottom half of brace (outward curve)
    final bottomY = topY + height;
    path.cubicTo(
      x - controlPointOffset,
      centerY + (height * 0.1),
      x - controlPointOffset,
      bottomY - (height * 0.15),
      x,
      bottomY,
    );

    canvas.drawPath(path, paint);
  }

  /// Render square bracket [ with tips
  ///
  /// Standard orchestral/choral bracket with horizontal tips
  /// at top and bottom.
  void _renderBracket(
    Canvas canvas,
    double x,
    double topY,
    double height,
    BracketRenderConfig config,
  ) {
    final paint = Paint()
      ..color = theme.barlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = coordinates.staffSpace * config.thickness
      ..strokeCap = StrokeCap.square;

    final bottomY = topY + height;
    final tipWidth = config.tipWidth * coordinates.staffSpace;

    // Vertical line
    canvas.drawLine(
      Offset(x, topY),
      Offset(x, bottomY),
      paint,
    );

    // Top tip (horizontal line pointing right)
    canvas.drawLine(
      Offset(x, topY),
      Offset(x + tipWidth, topY),
      paint,
    );

    // Bottom tip (horizontal line pointing right)
    canvas.drawLine(
      Offset(x, bottomY),
      Offset(x + tipWidth, bottomY),
      paint,
    );
  }

  /// Render simple vertical line |
  ///
  /// Used for multiple instances of the same instrument
  /// (and.g., Violin I & II)
  void _renderLine(
    Canvas canvas,
    double x,
    double topY,
    double height,
    BracketRenderConfig config,
  ) {
    final paint = Paint()
      ..color = theme.barlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = coordinates.staffSpace * config.thickness
      ..strokeCap = StrokeCap.butt;

    final bottomY = topY + height;

    canvas.drawLine(
      Offset(x, topY),
      Offset(x, bottomY),
      paint,
    );
  }

  /// Get rendering Configurestion for bracket type
  BracketRenderConfig _getConfigForType(BracketType type) {
    switch (type) {
      case BracketType.brace:
        return BracketRenderConfig.brace();
      case BracketType.bracket:
        return BracketRenderConfig.bracket();
      case BracketType.line:
        return BracketRenderConfig.line();
      case BracketType.none:
        return const BracketRenderConfig();
    }
  }
}

/// Renderer for connected barlines across staff groups
///
/// Draws vertical barlines that span multiple staves in a group
class ConnectedBarlineRenderer {
  final StaffCoordinateSystem coordinates;
  final MusicScoreTheme theme;

  ConnectedBarlineRenderer({
    required this.coordinates,
    required this.theme,
  });

  /// Render connected barline spanning multiple staves
  ///
  /// [canvas] - Canvas to draw on
  /// [x] - X coordinate of barline
  /// [topStaffY] - Y coordinate of top staff
  /// [bottomStaffY] - Y coordinate of bottom staff
  /// [thickness] - Optional custom thickness (default: 0.16 SS)
  void render(
    Canvas canvas,
    double x,
    double topStaffY,
    double bottomStaffY, {
    double? thickness,
  }) {
    final paint = Paint()
      ..color = theme.barlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          thickness ?? (coordinates.staffSpace * 0.16) // SMuFL standard
      ..strokeCap = StrokeCap.butt;

    // Draw vertical line from top staff to bottom staff
    // Add 2 SS extension to cover full height of staves (5 lines each)
    final topExtension = coordinates.staffSpace * 2.0; // Reach top line
    final bottomExtension = coordinates.staffSpace * 2.0; // Reach bottom line

    canvas.drawLine(
      Offset(x, topStaffY - topExtension),
      Offset(x, bottomStaffY + bottomExtension),
      paint,
    );
  }
}
