import 'package:flutter/painting.dart';

import '../../../core/core.dart';
import '../../theme/music_score_theme.dart';
import 'base_glyph_renderer.dart';

/// Renderiza barlines com alinhamento por bounding box SMuFL.
/// Isso elimina gaps visuais e descolamento entre barra final/repetiÃ§Ã£o e pauta.
class BarlineRenderer extends BaseGlyphRenderer {
  static const double barlineYOffset = 0.0;
  static const double barlineXOffset = 0.0;

  final MusicScoreTheme theme;

  BarlineRenderer({
    required super.coordinates,
    required super.metadata,
    required this.theme,
    required super.glyphSize,
  });

  void render(Canvas canvas, Barline barline, Offset position) {
    final glyphName = _getGlyphName(barline.type);

    final topY =
        coordinates.getStaffLineY(5) + (barlineYOffset * coordinates.staffSpace);
    final x = position.dx + (barlineXOffset * coordinates.staffSpace);

    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: Offset(x, topY),
      color: theme.barlineColor,
      options: const GlyphDrawOptions(
        alignLeft: true,
        alignTop: true,
        trackBounds: false,
      ),
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
