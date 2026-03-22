// lib/src/rendering/renderers/ornament_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
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
    int staffPosition,
  ) {
    if (note.ornaments.isEmpty) return;

    for (final ornament in note.ornaments) {
      if (_isLineOrnament(ornament.type)) continue;

      if (ornament.type == OrnamentType.arpeggio) {
        _renderArpeggio(canvas, notePos, notePos.dy, notePos.dy);
        continue;
      }

      final glyphName = _getOrnamentGlyph(ornament.type);
      if (glyphName == null) continue;

      bool ornamentAbove = _isOrnamentAbove(note, ornament);

      final ornamentY = _calculateOrnamentY(
        notePos.dy,
        ornamentAbove,
        staffPosition,
      );
      final ornamentX = _getOrnamentHorizontalPosition(note, notePos.dx);

      // ✅ FIXED: Use correct size for grace notes (60% per SMuFL standard)
      final isGraceNote = _isGraceNoteOrnament(ornament.type);
      final ornamentSize = isGraceNote ? glyphSize * 0.6 : glyphSize * 0.85;

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

  void renderForChord(
    Canvas canvas,
    Chord chord,
    Offset chordPos,
    int highestPos,
    int lowestPos,
  ) {
    if (chord.ornaments.isEmpty) return;
    final highestY =
        coordinates.staffBaseline.dy -
        (highestPos * coordinates.staffSpace * 0.5);
    final lowestY =
        coordinates.staffBaseline.dy -
        (lowestPos * coordinates.staffSpace * 0.5);

    for (final ornament in chord.ornaments) {
      if (ornament.type == OrnamentType.arpeggio) {
        _renderArpeggio(canvas, chordPos, lowestY, highestY);
        continue;
      }

      final glyphName = _getOrnamentGlyph(ornament.type);
      if (glyphName == null) continue;

      final ornamentY = _calculateOrnamentY(highestY, true, highestPos);

      // ✅ FIXED: Use correct size for grace notes (60% per SMuFL standard)
      final isGraceNote = _isGraceNoteOrnament(ornament.type);
      final ornamentSize = isGraceNote ? glyphSize * 0.6 : glyphSize * 0.9;

      drawGlyphAlignedToAnchor(
        canvas,
        glyphName: glyphName,
        anchorName: 'opticalCenter',
        target: Offset(chordPos.dx, ornamentY),
        color: theme.ornamentColor ?? theme.noteheadColor,
        options: GlyphDrawOptions.ornamentDefault.copyWith(
          size: ornamentSize,
        ),
      );
    }
  }

  bool _isOrnamentAbove(Note note, Ornament ornament) {
    // This logic is faithful to the original corrected staff_renderer
    if (ornament.type == OrnamentType.fermata) return true;
    if (ornament.type == OrnamentType.fermataBelow) return false;

    if (note.voice == null) {
      return ornament.above;
    } else {
      return (note.voice != 2);
    }
  }

  bool _isLineOrnament(OrnamentType type) {
    return type == OrnamentType.glissando || type == OrnamentType.portamento;
  }

  void _renderArpeggio(
    Canvas canvas,
    Offset chordPos,
    double bottomY,
    double topY,
  ) {
    final arpeggioX = chordPos.dx - (coordinates.staffSpace * 1.2);
    final arpeggioHeight = (bottomY - topY).abs() + coordinates.staffSpace;
    final startY = topY - (coordinates.staffSpace * 0.5);
    final paint = Paint()
      ..color = theme.ornamentColor ?? theme.noteheadColor
      ..strokeWidth = staffLineThickness * 0.8
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(arpeggioX - coordinates.staffSpace * 0.2, startY);
    final segments = (arpeggioHeight / (coordinates.staffSpace * 0.5))
        .clamp(3, 8)
        .toInt();
    for (var i = 0; i <= segments; i++) {
      final y = startY + (i / segments) * arpeggioHeight;
      final x =
          arpeggioX + (i % 2 == 0 ? -1 : 1) * coordinates.staffSpace * 0.2;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  double _calculateOrnamentY(
    double noteY,
    bool ornamentAbove,
    int staffPosition,
  ) {
    final stemUp = staffPosition < 0;
    final stemHeight = coordinates.staffSpace * 3.5;

    if (ornamentAbove) {
      // CORREÇÃO DINÂMICA: Ornamentos devem ter posicionamento inteligente
      // 
      // REGRA 1: Notas no pentagrama → ornamento acima do pentagrama (linha 5)
      // REGRA 2: Notas muito altas (>6) → ornamento acima da nota com clearance mínimo
      // REGRA 3: Se tem haste para cima, considerar ponta da haste
      
      final line5Y = coordinates.getStaffLineY(5);
      
      // Para notas muito altas (linhas suplementares superiores)
      if (staffPosition > 6) {
        // Ornamento acima da nota, não acima do pentagrama
        // Clearance mínimo: 0.75 staff spaces (ornamentToNoteDistance)
        return noteY - (coordinates.staffSpace * 0.75);
      }
      
      // Para notas dentro ou próximas do pentagrama
      final minOrnamentY = line5Y - (coordinates.staffSpace * 1.2);

      // Se tem haste para cima, verificar se precisa elevar mais
      if (stemUp) {
        final stemTipY = noteY - stemHeight;
        // Clearance da haste: 0.6 staff spaces
        final ornamentYFromStem = stemTipY - (coordinates.staffSpace * 0.6);
        // Usar o mais alto (menor Y)
        return ornamentYFromStem < minOrnamentY ? ornamentYFromStem : minOrnamentY;
      }
      
      return minOrnamentY;
    } else {
      // CORREÇÃO DINÂMICA: Ornamentos abaixo com mesma lógica
      final line1Y = coordinates.getStaffLineY(1);
      
      // Para notas muito baixas (linhas suplementares inferiores)
      if (staffPosition < -6) {
        return noteY + (coordinates.staffSpace * 0.75);
      }
      
      final maxOrnamentY = line1Y + (coordinates.staffSpace * 1.2);

      // Se tem haste para baixo
      if (!stemUp) {
        final stemTipY = noteY + stemHeight;
        final ornamentYFromStem = stemTipY + (coordinates.staffSpace * 0.6);
        return ornamentYFromStem > maxOrnamentY ? ornamentYFromStem : maxOrnamentY;
      }
      
      return maxOrnamentY;
    }
  }

  double _getOrnamentHorizontalPosition(Note note, double noteX) {
    double baseX = noteX;
    if (note.pitch.accidentalType != null) {
      baseX += coordinates.staffSpace * 0.8;
    }
    return baseX;
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
      OrnamentType.appoggiaturaUp: 'graceNoteAppoggiaturaStemUp',  // ✅ FIXED: no slash for appoggiatura
      OrnamentType.appoggiaturaDown: 'graceNoteAppoggiaturaStemDown',  // ✅ FIXED: no slash for appoggiatura
      OrnamentType.acciaccatura: 'graceNoteAcciaccaturaStemUp',  // ✓ Correct: with slash for acciaccatura
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
