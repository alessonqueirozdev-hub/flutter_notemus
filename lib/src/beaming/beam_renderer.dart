// lib/src/beaming/beam_renderer.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/beaming/beam_segment.dart';
import 'package:flutter_notemus/src/beaming/beam_types.dart';
import 'package:flutter_notemus/src/theme/music_score_theme.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

/// Renderiza beams (ligaduras de colcheia) geometricamente
class BeamRenderer {
  final MusicScoreTheme theme;
  final double staffSpace;
  final double noteheadWidth;
  final SMuFLPositioningEngine positioningEngine;

  // Métricas SMuFL
  late final double beamThickness;
  late final double beamGap;
  late final double stemThickness;

  BeamRenderer({
    required this.theme,
    required this.staffSpace,
    required this.noteheadWidth,
    required this.positioningEngine,
  }) {
    // SMuFL specifications
    beamThickness = 0.5 * staffSpace;
    beamGap = 0.25 * staffSpace;
    stemThickness = 0.12 * staffSpace;
  }

  /// Renderiza um beam group completo (apenas hastes e beams)
  /// Noteheads são renderizados pelo NoteRenderer
  void renderAdvancedBeamGroup(
    Canvas canvas,
    AdvancedBeamGroup group, {
    Map<dynamic, double>? noteXPositions,
    Map<dynamic, double>? noteYPositions,
  }) {
    final paint = Paint()
      ..color = theme.beamColor ?? theme.stemColor
      ..style = PaintingStyle.fill;

    // 1. Renderizar hastes
    _renderStems(canvas, group, paint, noteXPositions, noteYPositions);

    // 2. Renderizar todos os segmentos de beam
    for (final segment in group.beamSegments) {
      _renderBeamSegment(canvas, group, segment, paint, noteXPositions);
    }
  }

  /// Renderiza as hastes do grupo
  void _renderStems(
    Canvas canvas,
    AdvancedBeamGroup group,
    Paint paint,
    Map<dynamic, double>? noteXPositions,
    Map<dynamic, double>? noteYPositions,
  ) {
    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = stemThickness
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < group.notes.length; i++) {
      final note = group.notes[i];

      // ✅ Obter posição REAL da nota (não interpolar!)
      final noteX = noteXPositions?[note] ?? group.leftX;
      final noteY = noteYPositions?[note] ?? _estimateNoteY(note, group);

      // ✅ USAR EXATAMENTE A MESMA LÓGICA DO GroupRenderer! (beams simples que JÁ FUNCIONAM)
      // Obter glyph da cabeça de nota
      final noteheadGlyph = note.duration.type.glyphName;

      // Obter âncora SMuFL (IDÊNTICO ao StemRenderer linha 59-61)
      final stemAnchor = group.stemDirection == StemDirection.up
          ? positioningEngine.getStemUpAnchor(noteheadGlyph)
          : positioningEngine.getStemDownAnchor(noteheadGlyph);

      // ✅ CRÍTICO: Aplicar ajustes visuais empíricos (IDÊNTICO ao StemRenderer!)
      const stemUpXOffset = 0.7;
      const stemDownXOffset = -0.8;
      final xOffset = group.stemDirection == StemDirection.up
          ? stemUpXOffset
          : stemDownXOffset;

      // Converter para pixels (IDÊNTICO ao StemRenderer linhas 66-72!)
      final stemX = noteX + (stemAnchor.dx * staffSpace - xOffset);

      // Calcular posição Y do fim da haste (onde encontra o beam)
      final beamY = group.interpolateBeamY(stemX);

      // Desenhar haste (IDÊNTICO ao GroupRenderer linha 294-298)
      canvas.drawLine(
        Offset(stemX, noteY), // Inicia no noteY (posição da cabeça)
        Offset(stemX, beamY), // Termina no beam
        stemPaint,
      );
    }
  }

  /// Renderiza um segmento de beam
  void _renderBeamSegment(
    Canvas canvas,
    AdvancedBeamGroup group,
    BeamSegment segment,
    Paint paint,
    Map<dynamic, double>? noteXPositions,
  ) {
    // Calcular offset vertical para este nível de beam
    final levelOffset = _calculateLevelOffset(
      segment.level,
      group.stemDirection,
    );

    if (segment.isFractional) {
      _renderFractionalBeam(
        canvas,
        group,
        segment,
        paint,
        levelOffset,
        noteXPositions,
      );
    } else {
      _renderFullBeam(
        canvas,
        group,
        segment,
        paint,
        levelOffset,
        noteXPositions,
      );
    }
  }

  /// Calcula offset Y para um nível de beam
  double _calculateLevelOffset(int level, StemDirection stemDirection) {
    final offset = (level - 1) * (beamThickness + beamGap);

    // Inverter direção para hastes para baixo
    return stemDirection == StemDirection.down ? -offset : offset;
  }

  /// Renderiza beam completo
  void _renderFullBeam(
    Canvas canvas,
    AdvancedBeamGroup group,
    BeamSegment segment,
    Paint paint,
    double levelOffset,
    Map<dynamic, double>? noteXPositions,
  ) {
    // ✅ Usar posições REAIS das notas (igual às hastes!)
    final startNote = group.notes[segment.startNoteIndex];
    final endNote = group.notes[segment.endNoteIndex];

    final startNoteX = noteXPositions?[startNote] ?? group.leftX;
    final endNoteX = noteXPositions?[endNote] ?? group.rightX;

    // Obter âncoras SMuFL para calcular posição X da haste
    final startGlyph = startNote.duration.type.glyphName;
    final endGlyph = endNote.duration.type.glyphName;

    final startAnchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(startGlyph)
        : positioningEngine.getStemDownAnchor(startGlyph);

    final endAnchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(endGlyph)
        : positioningEngine.getStemDownAnchor(endGlyph);

    // Aplicar offsets empíricos
    const stemUpXOffset = 0.7;
    const stemDownXOffset = -0.8;
    final xOffset = group.stemDirection == StemDirection.up
        ? stemUpXOffset
        : stemDownXOffset;

    // Calcular X das hastes (IDÊNTICO ao _renderStems!)
    final leftX = startNoteX + (startAnchor.dx * staffSpace - xOffset);
    final rightX = endNoteX + (endAnchor.dx * staffSpace - xOffset);

    // Calcular posições Y ao longo da inclinação do beam
    final leftY = group.interpolateBeamY(leftX) + levelOffset;
    final rightY = group.interpolateBeamY(rightX) + levelOffset;

    // Desenhar retângulo do beam
    final beamPath = Path();

    if (group.stemDirection == StemDirection.up) {
      // Hastes para cima: beam fica embaixo
      beamPath.moveTo(leftX, leftY);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(rightX, rightY + beamThickness);
      beamPath.lineTo(leftX, leftY + beamThickness);
    } else {
      // Hastes para baixo: beam fica em cima
      beamPath.moveTo(leftX, leftY - beamThickness);
      beamPath.lineTo(rightX, rightY - beamThickness);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(leftX, leftY);
    }

    beamPath.close();
    canvas.drawPath(beamPath, paint);
  }

  /// Renderiza fractional beam (broken beam/stub)
  void _renderFractionalBeam(
    Canvas canvas,
    AdvancedBeamGroup group,
    BeamSegment segment,
    Paint paint,
    double levelOffset,
    Map<dynamic, double>? noteXPositions,
  ) {
    final noteIndex = segment.startNoteIndex;
    final note = group.notes[noteIndex];

    // ✅ Usar posição REAL da nota
    final noteX = noteXPositions?[note] ?? group.leftX;

    // Obter âncora SMuFL
    final glyph = note.duration.type.glyphName;
    final anchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(glyph)
        : positioningEngine.getStemDownAnchor(glyph);

    // Aplicar offsets empíricos
    const stemUpXOffset = 0.7;
    const stemDownXOffset = -0.8;
    final xOffset = group.stemDirection == StemDirection.up
        ? stemUpXOffset
        : stemDownXOffset;

    // Calcular X da haste (IDÊNTICO ao _renderStems!)
    final centerX = noteX + (anchor.dx * staffSpace - xOffset);

    // Comprimento do fractional beam
    final length = segment.fractionalLength ?? noteheadWidth;

    double leftX, rightX;
    if (segment.fractionalSide == FractionalBeamSide.right) {
      leftX = centerX;
      rightX = centerX + length;
    } else {
      leftX = centerX - length;
      rightX = centerX;
    }

    // Interpolar Y para seguir inclinação
    final leftY = group.interpolateBeamY(leftX) + levelOffset;
    final rightY = group.interpolateBeamY(rightX) + levelOffset;

    // Desenhar retângulo do fractional beam
    final beamPath = Path();

    if (group.stemDirection == StemDirection.up) {
      beamPath.moveTo(leftX, leftY);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(rightX, rightY + beamThickness);
      beamPath.lineTo(leftX, leftY + beamThickness);
    } else {
      beamPath.moveTo(leftX, leftY - beamThickness);
      beamPath.lineTo(rightX, rightY - beamThickness);
      beamPath.lineTo(rightX, rightY);
      beamPath.lineTo(leftX, leftY);
    }

    beamPath.close();
    canvas.drawPath(beamPath, paint);
  }

  /// Fallback para estimar Y quando noteYPositions está vazio (raro)
  double _estimateNoteY(dynamic note, AdvancedBeamGroup group) {
    // ✅ JÁ INTEGRADO: BeamRenderer recebe noteYPositions do LayoutEngine
    // Este método é apenas fallback para casos extremos
    return staffSpace * 3.0; // Linha central aproximada
  }

  /// Calcula altura total necessária para múltiplos beams
  double calculateTotalBeamHeight(int beamCount) {
    if (beamCount == 0) return 0;
    return beamThickness + ((beamCount - 1) * (beamThickness + beamGap));
  }
}
