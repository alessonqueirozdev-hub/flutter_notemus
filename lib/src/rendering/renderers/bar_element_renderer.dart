// lib/src/rendering/renderers/bar_element_renderer.dart

import 'package:flutter/material.dart';

import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../layout/collision_detector.dart'; // CORREÇÃO: Import collision detector
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';

class BarElementRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final CollisionDetector? collisionDetector; // CORREÇÃO: Adicionar collision detector

  BarElementRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    this.collisionDetector, // CORREÇÃO: Parâmetro opcional
  });

  void renderClef(Canvas canvas, Clef clef, Offset basePosition) {
    final glyphName = clef.glyphName;
    double yOffset = 0;

    switch (clef.actualClefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        yOffset = coordinates.getStaffLineY(2) - coordinates.staffBaseline.dy;
        break;
      case ClefType.bass:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        yOffset = coordinates.getStaffLineY(4) - coordinates.staffBaseline.dy;
        break;
      case ClefType.alto:
        yOffset = 0;
        break;
      case ClefType.tenor:
        yOffset = coordinates.getStaffLineY(4) - coordinates.staffBaseline.dy;
        break;
      default:
        yOffset = 0;
    }

    _drawGlyph(
      canvas,
      glyphName: glyphName,
      position: Offset(basePosition.dx, coordinates.staffBaseline.dy + yOffset),
      size: glyphSize,
      color: theme.clefColor,
      centerVertically: true,
    );

    // Fix: Not desenhar indicação de oitava manual
    // Os glyphs SMuFL as 'gClef8va' already contain o "8" embutido
  }

  void renderKeySignature(
    Canvas canvas,
    KeySignature ks,
    Clef currentClef,
    Offset basePosition,
  ) {
    double currentX = basePosition.dx;
    const spacing = 0.8;

    // Draw natural cancellation signs for the previous key signature
    if (ks.previousCount != null && ks.previousCount != 0) {
      final prevCount = ks.previousCount!;
      final prevPositions = _getKeySignaturePositionsCorrected(
        currentClef.actualClefType,
        prevCount > 0,
      );
      final naturalsCount = prevCount.abs();

      for (int i = 0; i < naturalsCount && i < prevPositions.length; i++) {
        final staffPos = prevPositions[i];
        final y =
            coordinates.staffBaseline.dy -
            (staffPos * coordinates.staffSpace * 0.5);

        _drawGlyph(
          canvas,
          glyphName: 'accidentalNatural',
          position: Offset(currentX, y),
          size: glyphSize * 0.9,
          color: theme.keySignatureColor,
          centerVertically: true,
        );

        currentX += spacing * coordinates.staffSpace;
      }

      // Small gap after naturals before the new key
      currentX += 0.5 * coordinates.staffSpace;
    }

    // Draw the new key signature accidentals (skip if C major / count == 0)
    if (ks.count == 0) return;

    final glyphName = ks.count > 0 ? 'accidentalSharp' : 'accidentalFlat';
    final count = ks.count.abs();
    final positions = _getKeySignaturePositionsCorrected(
      currentClef.actualClefType,
      ks.count > 0,
    );

    for (int i = 0; i < count && i < positions.length; i++) {
      final staffPos = positions[i];
      final y =
          coordinates.staffBaseline.dy -
          (staffPos * coordinates.staffSpace * 0.5);

      _drawGlyph(
        canvas,
        glyphName: glyphName,
        position: Offset(currentX, y),
        size: glyphSize * 0.9,
        color: theme.keySignatureColor,
        centerVertically: true,
      );

      currentX += spacing * coordinates.staffSpace;
    }
  }

  List<int> _getKeySignaturePositionsCorrected(
    ClefType clefType,
    bool isSharp,
  ) {
    switch (clefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        if (isSharp) return [4, 1, 5, 2, -1, 3, 0];
        return [0, 3, -1, 2, -2, 1, -3];
      case ClefType.bass:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        if (isSharp) return [2, -1, 3, 0, -3, 1, -2];
        return [-2, 1, -3, 0, -4, -1, -5];
      case ClefType.alto:
        if (isSharp) return [3, 0, 4, 1, -2, 2, -1];
        return [-1, 2, -2, 1, -3, 0, -4];
      case ClefType.tenor:
        if (isSharp) return [1, -2, 2, -1, -4, 0, -3];
        return [0, -3, -1, -4, -2, -5, -3];
      default:
        if (isSharp) return [4, 1, 5, 2, -1, 3, 0];
        return [0, 3, -1, 2, -2, 1, -3];
    }
  }

  void renderTimeSignature(
    Canvas canvas,
    TimeSignature ts,
    Offset basePosition,
  ) {
    if (ts.numerator == 4 &&
        ts.denominator == 4 &&
        metadata.hasGlyph('timeSigCommon')) {
      _drawGlyph(
        canvas,
        glyphName: 'timeSigCommon',
        position: Offset(basePosition.dx, coordinates.staffBaseline.dy),
        size: glyphSize,
        color: theme.timeSignatureColor,
        centerVertically: true,
      );
      return;
    }
    if (ts.numerator == 2 &&
        ts.denominator == 2 &&
        metadata.hasGlyph('timeSigCutCommon')) {
      _drawGlyph(
        canvas,
        glyphName: 'timeSigCutCommon',
        position: Offset(basePosition.dx, coordinates.staffBaseline.dy),
        size: glyphSize,
        color: theme.timeSignatureColor,
        centerVertically: true,
      );
      return;
    }

    _drawGlyph(
      canvas,
      glyphName: 'timeSig${ts.numerator}',
      position: Offset(basePosition.dx, coordinates.getStaffLineY(4)),
      size: glyphSize,
      color: theme.timeSignatureColor,
      centerVertically: true,
    );
    _drawGlyph(
      canvas,
      glyphName: 'timeSig${ts.denominator}',
      position: Offset(basePosition.dx, coordinates.getStaffLineY(2)),
      size: glyphSize,
      color: theme.timeSignatureColor,
      centerVertically: true,
    );
  }

  void _drawGlyph(
    Canvas canvas, {
    required String glyphName,
    required Offset position,
    required double size,
    required Color color,
    bool centerVertically = false,
    bool centerHorizontally = false,
    // A2 FIX: when true, position.y is treated as the SMuFL y=0 baseline
    // (and.g. G-line for gClef, F-line for fClef) and the glyph is anchored
    // to the font's alphabetic baseline rather than the layout-box centre.
    bool useBaseline = false,
  }) {
    final character = metadata.getCodepoint(glyphName);
    if (character.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontFamily: 'Bravura',
          package: 'flutter_notemus',
          fontSize: size,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    double yOffset;
    if (useBaseline) {
      // Shift so the font's alphabetic baseline lands exactly at position.dy.
      final ascent = textPainter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      yOffset = -ascent;
    } else if (centerVertically) {
      yOffset = -textPainter.height * 0.5;
    } else {
      yOffset = 0;
    }
    double xOffset = centerHorizontally ? -textPainter.width * 0.5 : 0;
    textPainter.paint(
      canvas,
      Offset(position.dx + xOffset, position.dy + yOffset),
    );
  }
}
