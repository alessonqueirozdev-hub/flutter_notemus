// lib/src/rendering/renderers/ornament_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // ðŸ†• Tipos do core
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
    super.collisionDetector, // CORREÃ‡ÃƒO: Passar collision detector para BaseGlyphRenderer
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
        _renderArpeggio(
          canvas,
          notePos,
          notePos.dy + verticalHalfExtent,
          notePos.dy - verticalHalfExtent,
        );
        continue;
      }

      final glyphName = _getOrnamentGlyph(ornament.type);
      if (glyphName == null) continue;

      final isGraceNote = _isGraceNoteOrnament(ornament.type);
      final ornamentSize = isGraceNote ? glyphSize * 0.6 : glyphSize * 0.85;

      if (isGraceNote) {
        // Grace notes: positioned BEFORE the main note (left X offset)
        // and at the same vertical level as the main note (correct pitch reference)
        final graceGlyphName = resolveGraceGlyphName(note) ?? glyphName;
        // Evita sobreposiÃ§Ã£o com acidentes da nota principal.
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
      } else {
        final stemUp = _resolveStemUp(note, staffPosition, voiceNumber);
        final ornamentAbove = _isOrnamentAbove(note, ornament, voiceNumber);
        final ornamentY = _calculateOrnamentY(
          notePos.dy,
          ornamentAbove,
          staffPosition,
          stemUp: stemUp,
        );
        final ornamentX = _getOrnamentHorizontalPosition(
          note,
          notePos.dx,
          ornamentAbove: ornamentAbove,
          stemUp: stemUp,
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
    double? leftmostNoteCenterX,
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
        final arpeggioAnchorX = leftmostNoteCenterX ?? chordPos.dx;
        final verticalHalfExtent = _noteheadVerticalHalfExtent();
        _renderArpeggio(
          canvas,
          Offset(arpeggioAnchorX, chordPos.dy),
          lowestY + verticalHalfExtent,
          highestY - verticalHalfExtent,
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
        final graceOrigin = graceGlyphOriginForChord(
          chord,
          chordPos,
          highestY,
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
    double topY,
  ) {
    const glyphName = 'wiggleArpeggiatoUp';

    // wiggleArpeggiatoUp e um tile HORIZONTAL no Bravura (~1.3 SS x 0.476 SS).
    // Para arpejo vertical, rotacionamos -90 graus em torno do centro de cada tile.
    // Apos rotacao: largura original (tileW) → extensao vertical; altura (tileH) → extensao horizontal.
    final bBox = metadata.getGlyphBoundingBox(glyphName);
    if (bBox == null || bBox.width <= 0) return;

    final tileW =
        bBox.width *
        coordinates.staffSpace; // extensao horizontal original (~1.3 SS)
    final tileH =
        bBox.height *
        coordinates.staffSpace; // extensao vertical original (~0.476 SS)

    final ornamentColor = theme.ornamentColor ?? theme.noteheadColor;

    final noteheadBox = metadata.getGlyphInfo('noteheadBlack')?.boundingBox;
    final noteheadLeftFromCenter = noteheadBox != null
        ? (noteheadBox.centerX - noteheadBox.bBoxSwX) * coordinates.staffSpace
        : coordinates.staffSpace * 0.6;

    // Apos rotacao -90: tileH vira a largura visual do arpejo na tela
    final gap = coordinates.staffSpace * 0.38;
    final arpeggioX = chordPos.dx - noteheadLeftFromCenter - tileH - gap;

    final arpeggioTopY =
        math.min(topY, bottomY) - (coordinates.staffSpace * 0.35);
    final arpeggioBottomY =
        math.max(topY, bottomY) + (coordinates.staffSpace * 0.35);

    // Apos rotacao: tileW vira a extensao vertical de cada tile na tela
    final tileVertical = tileW;
    final step = tileVertical * 0.85; // leve sobreposicao para linha continua
    final firstCenterY = arpeggioTopY + tileVertical * 0.5;
    final lastCenterY = arpeggioBottomY - tileVertical * 0.5;

    // Centro X visual: metade da largura visual apos rotacao
    final tileCenterX = arpeggioX + tileH * 0.5;

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
          alignLeft: false,
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
      // Regra: altura padrÃ£o fixa acima da pauta (consistÃªncia visual).
      // SÃ³ acompanha a cabeÃ§a da nota quando hÃ¡ muitas linhas suplementares.
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
          'graceNoteAppoggiaturaStemUp', // âœ… FIXED: no slash for appoggiatura
      OrnamentType.appoggiaturaDown:
          'graceNoteAppoggiaturaStemDown', // âœ… FIXED: no slash for appoggiatura
      OrnamentType.acciaccatura:
          'graceNoteAcciaccaturaStemUp', // âœ“ Correct: with slash for acciaccatura
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
}
