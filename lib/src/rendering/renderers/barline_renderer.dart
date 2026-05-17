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
    final topY =
        coordinates.getStaffLineY(1) +
        (barlineYOffset * coordinates.staffSpace);
    final x = position.dx + (barlineXOffset * coordinates.staffSpace);
    final barlineHeight = coordinates.staffSpace * barlineHeightMultiplier;

    // repeatBoth (:||:) prefers the combined SMuFL glyph, but many fonts /
    // metadata tables omit it. Fall back to composing the end-repeat
    // (repeatRight) immediately followed by the start-repeat (repeatLeft) so
    // the barline always renders consistently.
    if (barline.type == BarlineType.repeatBoth &&
        !_isGlyphAvailable('repeatLeftRight')) {
      _renderRepeatBothComposite(canvas, x, topY, barlineHeight);
      return;
    }

    glyphRenderer.drawGlyph(
      canvas,
      glyphName: _getGlyphName(barline.type),
      position: Offset(x, topY),
      size: barlineHeight,
      color: theme.barlineColor,
      centerVertically: false,
    );
  }

  /// Whether [glyphName] is present in the loaded SMuFL metadata and maps to a
  /// real codepoint (both checks matter: a name can exist without a usable
  /// codepoint depending on the font tables).
  bool _isGlyphAvailable(String glyphName) {
    return metadata.hasGlyph(glyphName) &&
        metadata.getCodepoint(glyphName).isNotEmpty;
  }

  /// Draws repeatBoth as `repeatRight` + `repeatLeft` when the combined glyph
  /// is unavailable. The horizontal gap uses the end-repeat advance width plus
  /// the SMuFL `barlineSeparation` default so the two halves don't collide and
  /// alignment-sensitive hooks (volta/octave) stay anchored to the left edge.
  void _renderRepeatBothComposite(
    Canvas canvas,
    double x,
    double topY,
    double barlineHeight,
  ) {
    glyphRenderer.drawGlyph(
      canvas,
      glyphName: 'repeatRight',
      position: Offset(x, topY),
      size: barlineHeight,
      color: theme.barlineColor,
      centerVertically: false,
    );

    // Advance widths in SMuFL metadata are in staff spaces; at this font size
    // (barlineHeightMultiplier staff spaces == 1 em) 1 SS == staffSpace px.
    final double endRepeatWidth =
        metadata.getGlyphAdvanceWidth('repeatRight') ?? 1.0;
    final double separation = _engravingDefault('barlineSeparation', 0.4);
    final double secondX =
        x + ((endRepeatWidth + separation) * coordinates.staffSpace);

    glyphRenderer.drawGlyph(
      canvas,
      glyphName: 'repeatLeft',
      position: Offset(secondX, topY),
      size: barlineHeight,
      color: theme.barlineColor,
      centerVertically: false,
    );
  }

  double _engravingDefault(String key, double fallback) {
    final value = metadata.getEngravingDefaultValue(key);
    return (value != null && value > 0) ? value : fallback;
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
