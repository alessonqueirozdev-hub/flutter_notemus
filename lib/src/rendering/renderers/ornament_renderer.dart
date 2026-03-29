// lib/src/rendering/renderers/ornament_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../grace_note_geometry.dart';
import '../../theme/music_score_theme.dart';
import 'base_glyph_renderer.dart';

class OrnamentRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final double staffLineThickness;

  OrnamentRenderer({
    required super.coordinates,
    required super.metadata,
    required this.theme,
    required super.glyphSize,
    required this.staffLineThickness,
    super.collisionDetector, // CORREÇÃO: Passar collision detector para BaseGlyphRenderer
  });

  void renderForNote(
    Canvas canvas,
    Note note,
    Offset notePos,
    int staffPosition, {
    int? voiceNumber,
  }) {
    if (note.ornaments.isEmpty) return;

    for (final ornament in note.ornaments) {
      if (_isLineOrnament(ornament.type)) continue;

      if (ornament.type == OrnamentType.arpeggio) {
        final verticalHalfExtent = _noteheadVerticalHalfExtent();
        final noteStemUp = _resolveStemUp(note, staffPosition, voiceNumber);
        _renderArpeggio(
          canvas,
          notePos,
          notePos.dy + verticalHalfExtent,
          notePos.dy - verticalHalfExtent,
          stemUp: noteStemUp,
        );
        continue;
      }

      final glyphName = _getOrnamentGlyph(ornament.type);
      if (glyphName == null) continue;

      final isGraceNote = _isGraceNoteOrnament(ornament.type);
      final ornamentSize = isGraceNote ? glyphSize * 0.6 : glyphSize * 0.85;
      final noteStemUp = _resolveStemUp(note, staffPosition, voiceNumber);

      if (isGraceNote) {
        // Grace notes: positioned BEFORE the main note (left X offset)
        // and at the same vertical level as the main note (correct pitch reference)
        final graceGlyphName = resolveGraceGlyphName(note) ?? glyphName;
        final graceStemUp = !graceGlyphName.contains('StemDown');
        final graceOrigin = graceGlyphOriginForNote(
          note,
          notePos,
          coordinates.staffSpace,
        );

        drawGlyphWithBBox(
          canvas,
          glyphName: graceGlyphName,
          position: graceOrigin,
          color: theme.ornamentColor ?? theme.noteheadColor,
          options: GlyphDrawOptions.ornamentDefault.copyWith(
            size: ornamentSize,
          ),
        );

        // Fix: Render mini-slur of the grace note à note principal
        _renderGraceSlur(
          canvas,
          graceOrigin: graceOrigin,
          mainNotePos: notePos,
          ornamentSize: ornamentSize,
          placementAbove: !noteStemUp,
          graceStemUp: graceStemUp,
          mainNoteStemUp: noteStemUp,
        );
      } else {
        final ornamentAbove = _isOrnamentAbove(note, ornament, voiceNumber);
        final ornamentY = _calculateOrnamentY(
          notePos.dy,
          ornamentAbove,
          staffPosition,
          stemUp: noteStemUp,
        );
        final ornamentX = _getOrnamentHorizontalPosition(
          note,
          notePos.dx,
          ornamentAbove: ornamentAbove,
          stemUp: noteStemUp,
          voiceNumber: voiceNumber,
        );

        drawGlyphAlignedToAnchor(
          canvas,
          glyphName: glyphName,
          anchorName: 'opticalCenter',
          target: Offset(ornamentX, ornamentY),
          color: theme.ornamentColor ?? theme.noteheadColor,
          options: GlyphDrawOptions.ornamentDefault.copyWith(
            size: ornamentSize,
          ),
        );
      }
    }
  }

  void renderForChord(
    Canvas canvas,
    Chord chord,
    Offset chordPos,
    int highestPos,
    int lowestPos, {
    int? voiceNumber,
    double? leadingNoteCenterX,
    double? arpeggioReferenceCenterX,
    bool stemUp = true,
  }) {
    if (chord.ornaments.isEmpty) return;
    final highestY =
        coordinates.staffBaseline.dy -
        (highestPos * coordinates.staffSpace * 0.5);
    final lowestY =
        coordinates.staffBaseline.dy -
        (lowestPos * coordinates.staffSpace * 0.5);

    for (final ornament in chord.ornaments) {
      if (ornament.type == OrnamentType.arpeggio) {
        final arpeggioAnchorX = arpeggioReferenceCenterX ?? chordPos.dx;
        final verticalHalfExtent = _noteheadVerticalHalfExtent();
        _renderArpeggio(
          canvas,
          Offset(arpeggioAnchorX, chordPos.dy),
          lowestY + verticalHalfExtent,
          highestY - verticalHalfExtent,
          stemUp: stemUp,
        );
        continue;
      }

      final glyphName = _getOrnamentGlyph(ornament.type);
      if (glyphName == null) continue;

      final isGraceNote = _isGraceNoteOrnament(ornament.type);
      final ornamentSize = isGraceNote ? glyphSize * 0.6 : glyphSize * 0.9;

      if (isGraceNote) {
        final graceGlyphName =
            resolveGraceGlyphNameFromOrnaments(chord.ornaments) ?? glyphName;
        final graceStemUp = !graceGlyphName.contains('StemDown');
        final gracePlacementAbove = !stemUp;
        final graceTargetY = gracePlacementAbove ? highestY : lowestY;
        final graceOrigin = graceGlyphOriginForChord(
          chord,
          chordPos,
          graceTargetY,
          coordinates.staffSpace,
        );

        drawGlyphWithBBox(
          canvas,
          glyphName: graceGlyphName,
          position: graceOrigin,
          color: theme.ornamentColor ?? theme.noteheadColor,
          options: GlyphDrawOptions.ornamentDefault.copyWith(
            size: ornamentSize,
          ),
        );

        // Fix: Render mini-slur of the grace note ao chord
        _renderGraceSlur(
          canvas,
          graceOrigin: graceOrigin,
          mainNotePos: Offset(leadingNoteCenterX ?? chordPos.dx, graceTargetY),
          ornamentSize: ornamentSize,
          placementAbove: gracePlacementAbove,
          graceStemUp: graceStemUp,
          mainNoteStemUp: stemUp,
        );
      } else {
        final effectiveVoice = voiceNumber ?? chord.voice;
        final ornamentAbove = _isChordOrnamentAbove(ornament, effectiveVoice);
        final referenceY = ornamentAbove ? highestY : lowestY;
        final referenceStaffPosition = ornamentAbove ? highestPos : lowestPos;
        final stemUp = effectiveVoice?.isOdd ?? true;
        final ornamentY = _calculateOrnamentY(
          referenceY,
          ornamentAbove,
          referenceStaffPosition,
          stemUp: stemUp,
        );
        final ornamentX =
            chordPos.dx +
            ((!ornamentAbove && !stemUp) ? coordinates.staffSpace * 0.45 : 0.0);

        drawGlyphAlignedToAnchor(
          canvas,
          glyphName: glyphName,
          anchorName: 'opticalCenter',
          target: Offset(ornamentX, ornamentY),
          color: theme.ornamentColor ?? theme.noteheadColor,
          options: GlyphDrawOptions.ornamentDefault.copyWith(
            size: ornamentSize,
          ),
        );
      }
    }
  }

  bool _isOrnamentAbove(Note note, Ornament ornament, int? voiceNumber) {
    if (ornament.type == OrnamentType.fermata) return true;
    if (ornament.type == OrnamentType.fermataBelow) return false;

    final effectiveVoice = voiceNumber ?? note.voice;
    if (effectiveVoice == null) {
      return ornament.above;
    }
    return effectiveVoice.isOdd;
  }

  bool _isChordOrnamentAbove(Ornament ornament, int? voiceNumber) {
    if (ornament.type == OrnamentType.fermata) return true;
    if (ornament.type == OrnamentType.fermataBelow) return false;
    if (voiceNumber == null) return true;
    return voiceNumber.isOdd;
  }

  bool _isLineOrnament(OrnamentType type) {
    return type == OrnamentType.glissando ||
        type == OrnamentType.portamento ||
        type == OrnamentType.slide;
  }

  void _renderArpeggio(
    Canvas canvas,
    Offset chordPos,
    double bottomY,
    double topY, {
    bool stemUp = true,
  }) {
    const glyphName = 'wiggleArpeggiatoUp';

    // wiggleArpeggiatoUp e um tile HORIZONTAL no Bravura (~1.3 SS x 0.476 SS).
    // For arpejo vertical, rotacionamos -90 graus in torno of the centro de each tile.
    // Apos rotacao: width original (tileW) → extensao vertical; height (tileH) → extensao horizontal.
    final bBox = metadata.getGlyphBoundingBox(glyphName);
    if (bBox == null || bBox.width <= 0) return;

    final tileW = bBox.width * coordinates.staffSpace;

    final ornamentColor = theme.ornamentColor ?? theme.noteheadColor;

    final noteheadBox = metadata.getGlyphInfo('noteheadBlack')?.boundingBox;
    // Use half the notehead width since chordPos.dx is the notehead CENTER X.
    // This places the arpeggio right edge exactly at the notehead left edge + gap.
    final noteheadHalfWidth = noteheadBox != null
        ? (noteheadBox.width * coordinates.staffSpace * 0.5)
        : coordinates.staffSpace * 0.59;

    // Standard clearance between arpeggio and noteheads (SMuFL/Behind Bars ≈ 0.15 SS).
    final gap = coordinates.staffSpace * 0.03;

    // Per engraving convention (Gould "Behind Bars" p.137):
    // Arpeggios always appear on the side of the noteheads opposite the stem:
    //   stem-UP  → stem on RIGHT  → arpeggio on LEFT  of noteheads
    //   stem-DOWN → stem on LEFT  → arpeggio on RIGHT of noteheads
    final rotatedLeftExtent =
        (bBox.centerY - bBox.bBoxSwY).abs() * coordinates.staffSpace;
    final rotatedRightExtent =
        (bBox.bBoxNeY - bBox.centerY).abs() * coordinates.staffSpace;

    final double tileCenterX;
    if (stemUp) {
      tileCenterX = chordPos.dx - noteheadHalfWidth - gap - rotatedRightExtent;
    } else {
      tileCenterX = chordPos.dx + noteheadHalfWidth + gap + rotatedLeftExtent;
    }

    final arpeggioTopY =
        math.min(topY, bottomY) - (coordinates.staffSpace * 0.18);
    final arpeggioBottomY =
        math.max(topY, bottomY) + (coordinates.staffSpace * 0.18);

    final tileVertical = tileW;
    final step = tileVertical * 0.85;
    final firstCenterY = arpeggioTopY + tileVertical * 0.5;
    final lastCenterY = arpeggioBottomY - tileVertical * 0.5;

    void drawTile(double centerY) {
      canvas.save();
      canvas.translate(tileCenterX, centerY);
      canvas.rotate(
        -math.pi / 2,
      ); // glifo horizontal → vertical (de baixo para cima)
      drawGlyphWithBBox(
        canvas,
        glyphName: glyphName,
        position: Offset.zero,
        color: ornamentColor,
        options: const GlyphDrawOptions(
          centerHorizontally: true,
          centerVertically: true,
          disableBaselineCorrection: true,
          trackBounds: false,
        ),
      );
      canvas.restore();
    }

    if (lastCenterY <= firstCenterY) {
      drawTile((arpeggioTopY + arpeggioBottomY) * 0.5);
      return;
    }

    for (
      double centerY = firstCenterY;
      centerY <= lastCenterY + 0.001;
      centerY += step
    ) {
      drawTile(centerY);
    }
  }

  double _noteheadVerticalHalfExtent() {
    final noteheadBox = metadata.getGlyphBoundingBox('noteheadBlack');
    if (noteheadBox != null && noteheadBox.height > 0) {
      return (noteheadBox.height * coordinates.staffSpace * 0.5) +
          (coordinates.staffSpace * 0.12);
    }
    return coordinates.staffSpace * 0.42;
  }

  double _calculateOrnamentY(
    double noteY,
    bool ornamentAbove,
    int staffPosition, {
    required bool stemUp,
  }) {
    final stemHeight = coordinates.staffSpace * 3.5;

    if (ornamentAbove) {
      // Regra: height default fixa acima of the staff (consistência visual).
      // Só acompanha a cabeça of the note when há muitas linhas suplementares.
      final standardY =
          coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.8);
      if (staffPosition > 6) {
        return noteY - (coordinates.staffSpace * 1.2);
      }

      if (stemUp) {
        final stemTipY = noteY - stemHeight;
        final clearanceFromStem = stemTipY - (coordinates.staffSpace * 0.8);
        return clearanceFromStem < standardY ? clearanceFromStem : standardY;
      }

      return standardY;
    } else {
      final standardY =
          coordinates.getStaffLineY(1) + (coordinates.staffSpace * 1.8);
      if (staffPosition < -6) {
        return noteY + (coordinates.staffSpace * 1.2);
      }

      if (!stemUp) {
        final stemTipY = noteY + stemHeight;
        final clearanceFromStem = stemTipY + (coordinates.staffSpace * 0.8);
        return clearanceFromStem > standardY ? clearanceFromStem : standardY;
      }

      return standardY;
    }
  }

  double _getOrnamentHorizontalPosition(
    Note note,
    double noteX, {
    required bool ornamentAbove,
    required bool stemUp,
    int? voiceNumber,
  }) {
    double baseX = noteX;
    if (note.pitch.accidentalType != null) {
      baseX += coordinates.staffSpace * 0.8;
    }
    final effectiveVoice = voiceNumber ?? note.voice;
    if (effectiveVoice != null &&
        effectiveVoice.isEven &&
        !ornamentAbove &&
        !stemUp) {
      baseX += coordinates.staffSpace * 0.45;
    }
    return baseX;
  }

  bool _resolveStemUp(Note note, int staffPosition, int? voiceNumber) {
    final effectiveVoice = voiceNumber ?? note.voice;
    if (effectiveVoice != null) {
      return effectiveVoice.isOdd;
    }
    return staffPosition <= 0;
  }

  String? _getOrnamentGlyph(OrnamentType type) {
    const ornamentGlyphs = {
      OrnamentType.trill: 'ornamentTrill',
      OrnamentType.trillFlat: 'ornamentTrillFlat',
      OrnamentType.trillNatural: 'ornamentTrillNatural',
      OrnamentType.trillSharp: 'ornamentTrillSharp',
      OrnamentType.shortTrill: 'ornamentShortTrill',
      OrnamentType.trillLigature: 'ornamentPrecompTrillLowerMordent',
      OrnamentType.mordent: 'ornamentMordent',
      OrnamentType.invertedMordent: 'ornamentMordentInverted',
      OrnamentType.mordentUpperPrefix: 'ornamentPrecompMordentUpperPrefix',
      OrnamentType.mordentLowerPrefix: 'ornamentPrecompMordentLowerPrefix',
      OrnamentType.turn: 'ornamentTurn',
      OrnamentType.turnInverted: 'ornamentTurnInverted',
      OrnamentType.invertedTurn: 'ornamentTurnInverted',
      OrnamentType.turnSlash: 'ornamentTurnSlash',
      OrnamentType.appoggiaturaUp:
          'graceNoteAppoggiaturaStemUp', // ✅ FIXED: no slash for appoggiatura
      OrnamentType.appoggiaturaDown:
          'graceNoteAppoggiaturaStemDown', // ✅ FIXED: no slash for appoggiatura
      OrnamentType.acciaccatura:
          'graceNoteAcciaccaturaStemUp', // ✓ Correct: with slash for acciaccatura
      OrnamentType.fermata: 'fermataAbove',
      OrnamentType.fermataBelow: 'fermataBelow',
      OrnamentType.fermataBelowInverted: 'fermataBelowInverted',
      OrnamentType.schleifer: 'ornamentSchleifer',
      OrnamentType.haydn: 'ornamentHaydn',
      OrnamentType.shake: 'ornamentShake3',
      OrnamentType.wavyLine: 'ornamentPrecompSlide',
      OrnamentType.zigZagLineNoRightEnd: 'ornamentZigZagLineNoRightEnd',
      OrnamentType.zigZagLineWithRightEnd: 'ornamentZigZagLineWithRightEnd',
      OrnamentType.zigzagLine: 'ornamentZigZagLineWithRightEnd',
      OrnamentType.scoop: 'brassBendUp',
      OrnamentType.fall: 'brassFallMedium',
      OrnamentType.doit: 'brassDoitMedium',
      OrnamentType.plop: 'brassPlop',
      OrnamentType.bend: 'brassBendUp',
      OrnamentType.grace: 'graceNoteAcciaccaturaStemUp',
    };
    return ornamentGlyphs[type];
  }

  /// Helper function to identify grace note ornaments
  /// Grace notes should be rendered at 60% size per SMuFL standard
  bool _isGraceNoteOrnament(OrnamentType type) {
    return type == OrnamentType.appoggiaturaUp ||
        type == OrnamentType.appoggiaturaDown ||
        type == OrnamentType.acciaccatura ||
        type == OrnamentType.grace;
  }

  /// Renders mini-slur de grace note → note principal with Bézier cúbico
  /// e espessura variable (fina nas pontas, mais grossa no meio), alinhado
  /// with o estilo tipográfico Bravura das slurs normais.
  void _renderGraceSlur(
    Canvas canvas, {
    required Offset graceOrigin,
    required Offset mainNotePos,
    required double ornamentSize,
    required bool placementAbove,
    required bool graceStemUp,
    required bool mainNoteStemUp,
  }) {
    final scaleFactor = ornamentSize / glyphSize;
    final noteheadBox = metadata.getGlyphBoundingBox('noteheadBlack');
    final graceNoteheadWidth =
        (noteheadBox?.width ?? 1.18) * coordinates.staffSpace * scaleFactor;
    final mainNoteheadWidth =
        (noteheadBox?.width ?? 1.18) * coordinates.staffSpace;
    final graceNoteheadHalfHeight =
        ((noteheadBox?.height ?? 0.88) * coordinates.staffSpace * scaleFactor) *
        0.5;
    final mainNoteheadHalfHeight =
        ((noteheadBox?.height ?? 0.88) * coordinates.staffSpace) * 0.5;

    // Short grace slurs should hug the noteheads without touching the stem side.
    final graceClearance = math.max(
      graceNoteheadHalfHeight + coordinates.staffSpace * 0.08,
      coordinates.staffSpace * 0.22,
    );
    final mainClearance = math.max(
      mainNoteheadHalfHeight + coordinates.staffSpace * 0.08,
      coordinates.staffSpace * 0.22,
    );

    final graceCenterX = graceOrigin.dx + (graceNoteheadWidth * 0.5);
    final startX = _resolveStemSafeAnchorX(
      centerX: graceCenterX,
      width: graceNoteheadWidth,
      stemUp: graceStemUp,
      placementAbove: placementAbove,
      isStart: true,
    );
    final startY =
        graceOrigin.dy + (placementAbove ? -graceClearance : graceClearance);
    final endX = _resolveStemSafeAnchorX(
      centerX: mainNotePos.dx,
      width: mainNoteheadWidth,
      stemUp: mainNoteStemUp,
      placementAbove: placementAbove,
      isStart: false,
    );
    final endY =
        mainNotePos.dy + (placementAbove ? -mainClearance : mainClearance);

    // Cubic Bézier: control points angled inward for calligraphic curve.
    final span = endX - startX;
    final arch = coordinates.staffSpace * (placementAbove ? -0.55 : 0.55);
    final cp1 = Offset(startX + span * 0.35, startY + arch);
    final cp2 = Offset(startX + span * 0.65, endY + arch);

    // Variable-thickness fill path (thin at endpoints, thick at midpoint).
    final endThicknessPx = coordinates.staffSpace * 0.06;
    final midThicknessPx = coordinates.staffSpace * 0.14;
    const steps = 30;

    // Evaluate cubic bezier
    Offset evalCubic(double t) {
      final mt = 1 - t;
      return Offset(
        mt * mt * mt * startX +
            3 * mt * mt * t * cp1.dx +
            3 * mt * t * t * cp2.dx +
            t * t * t * endX,
        mt * mt * mt * startY +
            3 * mt * mt * t * cp1.dy +
            3 * mt * t * t * cp2.dy +
            t * t * t * endY,
      );
    }

    Offset evalDerivative(double t) {
      final mt = 1 - t;
      return Offset(
        3 *
            (mt * mt * (cp1.dx - startX) +
                2 * mt * t * (cp2.dx - cp1.dx) +
                t * t * (endX - cp2.dx)),
        3 *
            (mt * mt * (cp1.dy - startY) +
                2 * mt * t * (cp2.dy - cp1.dy) +
                t * t * (endY - cp2.dy)),
      );
    }

    final pathTop = Path();
    final pathBottom = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final pt = evalCubic(t);
      final deriv = evalDerivative(t);
      final angle = math.atan2(deriv.dy, deriv.dx);
      final perp = angle + math.pi / 2;
      final tCentered = 2 * t - 1;
      final halfThick =
          (endThicknessPx +
              (midThicknessPx - endThicknessPx) * (1 - tCentered * tCentered)) /
          2;
      final dx = math.cos(perp) * halfThick;
      final dy = math.sin(perp) * halfThick;
      if (i == 0) {
        pathTop.moveTo(pt.dx + dx, pt.dy + dy);
        pathBottom.moveTo(pt.dx - dx, pt.dy - dy);
      } else {
        pathTop.lineTo(pt.dx + dx, pt.dy + dy);
        pathBottom.lineTo(pt.dx - dx, pt.dy - dy);
      }
    }
    // Close the outline: top path forward, bottom path reversed
    final closedPath = Path()..addPath(pathTop, Offset.zero);
    for (int i = steps; i >= 0; i--) {
      final t = i / steps;
      final pt = evalCubic(t);
      final deriv = evalDerivative(t);
      final angle = math.atan2(deriv.dy, deriv.dx);
      final perp = angle + math.pi / 2;
      final tCentered = 2 * t - 1;
      final halfThick =
          (endThicknessPx +
              (midThicknessPx - endThicknessPx) * (1 - tCentered * tCentered)) /
          2;
      final dx = math.cos(perp) * halfThick;
      final dy = math.sin(perp) * halfThick;
      closedPath.lineTo(pt.dx - dx, pt.dy - dy);
    }
    closedPath.close();

    canvas.drawPath(
      closedPath,
      Paint()
        ..color = theme.ornamentColor ?? theme.noteheadColor
        ..style = PaintingStyle.fill,
    );
  }

  double _resolveStemSafeAnchorX({
    required double centerX,
    required double width,
    required bool stemUp,
    required bool placementAbove,
    required bool isStart,
  }) {
    final stemSafeInset = math.min(width * 0.18, coordinates.staffSpace * 0.22);
    final directionalInset = math.min(
      width * 0.08,
      coordinates.staffSpace * 0.12,
    );

    if (placementAbove && !stemUp) {
      return centerX + (isStart ? stemSafeInset : directionalInset);
    }

    if (!placementAbove && stemUp) {
      return centerX - (isStart ? directionalInset : stemSafeInset);
    }

    final edgeInset = math.min(width * 0.16, coordinates.staffSpace * 0.12);
    final halfWidth = width * 0.5;
    return isStart
        ? centerX + halfWidth - edgeInset
        : centerX - halfWidth + edgeInset;
  }
}
