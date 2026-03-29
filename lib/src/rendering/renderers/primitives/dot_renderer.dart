import 'package:flutter/material.dart';

import '../../../../core/core.dart';
import '../../staff_coordinate_system.dart';
import '../../../theme/music_score_theme.dart';
import '../base_glyph_renderer.dart';

/// Rendersdor especializado for pontos de aumento.
class DotRenderer extends BaseGlyphRenderer {
  DotRenderer({
    required super.metadata,
    required this.theme,
    required super.coordinates,
    required super.glyphSize,
  });

  final MusicScoreTheme theme;

  /// Regra tipográfica:
  /// - notes in linha -> ponto no space acima
  /// - notes in space -> ponto no mesmo space
  static int resolveDotStaffPosition(int noteStaffPosition) {
    if (noteStaffPosition.isEven) {
      return noteStaffPosition + 1;
    }
    return noteStaffPosition;
  }

  static double calculateDotY({
    required int dotStaffPosition,
    required StaffCoordinateSystem coordinates,
  }) {
    return coordinates.staffBaseline.dy -
        (dotStaffPosition * coordinates.staffSpace * 0.5);
  }

  void render(
    Canvas canvas,
    Note note,
    Offset notePosition,
    int staffPosition,
  ) {
    if (note.duration.dots == 0) return;

    final dotStaffPosition = resolveDotStaffPosition(staffPosition);
    final dotY = calculateDotY(
      dotStaffPosition: dotStaffPosition,
      coordinates: coordinates,
    );

    final dotStartX = notePosition.dx + (coordinates.staffSpace * 1.0);

    for (int index = 0; index < note.duration.dots; index++) {
      final dotX = dotStartX + (index * coordinates.staffSpace * 0.6);
      drawGlyphWithBBox(
        canvas,
        glyphName: 'augmentationDot',
        position: Offset(dotX, dotY),
        color: theme.noteheadColor,
        options: const GlyphDrawOptions(
          centerHorizontally: true,
          trackBounds: false,
        ),
      );
    }
  }
}
