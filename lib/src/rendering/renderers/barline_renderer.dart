import 'package:flutter/painting.dart';

import '../../../core/core.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';
import 'glyph_renderer.dart';

/// Renders barlines using stable SMuFL glyph placement tuned for this engine.
///
/// We intentionally avoid bbox-top alignment here because text-baseline and
/// SMuFL bbox origins differ for barline glyphs and can vertically detach the
/// final barline from the staff.
class BarlineRenderer {
  static const double barlineHeightMultiplier = 4.0;
  static const double barlineYOffset = -2.0;
  static const double barlineXOffset = 0.0;

  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final GlyphRenderer glyphRenderer;
  final double glyphSize;

  BarlineRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphRenderer,
    required this.glyphSize,
  });

  void render(Canvas canvas, Barline barline, Offset position) {
    final glyphName = _getGlyphName(barline.type);
    final topY =
        coordinates.getStaffLineY(1) +
        (barlineYOffset * coordinates.staffSpace);
    final x = position.dx + (barlineXOffset * coordinates.staffSpace);
    final barlineHeight = coordinates.staffSpace * barlineHeightMultiplier;

    glyphRenderer.drawGlyph(
      canvas,
      glyphName: glyphName,
      position: Offset(x, topY),
      size: barlineHeight,
      color: theme.barlineColor,
      centerVertically: false,
    );
  }

  String _getGlyphName(BarlineType type) {
    switch (type) {
      case BarlineType.single:
        return 'barlineSingle';
      case BarlineType.double:
      case BarlineType.lightLight:
        return 'barlineDouble';
      case BarlineType.final_:
      case BarlineType.lightHeavy:
        return 'barlineFinal';
      case BarlineType.repeatForward:
        return 'repeatLeft';
      case BarlineType.repeatBackward:
        return 'repeatRight';
      case BarlineType.repeatBoth:
        return 'repeatLeftRight';
      case BarlineType.dashed:
        return 'barlineDashed';
      case BarlineType.heavy:
      case BarlineType.heavyHeavy:
      case BarlineType.heavyLight:
        return 'barlineHeavy';
      case BarlineType.tick:
        return 'barlineTick';
      case BarlineType.short_:
        return 'barlineShort';
      case BarlineType.none:
        return 'barlineSingle';
    }
  }
}
