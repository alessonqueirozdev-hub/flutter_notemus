// lib/src/rendering/renderers/group_renderer.dart
// VERSÃO REFATORADA: Usa StaffPositionCalculator
//
// MELHORIAS IMPLEMENTADAS (Fase 2):
// ✅ Usa StaffPositionCalculator unificado (elimina 41 linhas duplicadas)
// ✅ Corrige possível bug de sinal invertido no cálculo de posição
// ✅ 100% conformidade com sistema unificado de posicionamento

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../layout/collision_detector.dart'; // CORREÇÃO: Import collision detector
import '../../layout/layout_engine.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../smufl_positioning_engine.dart';
import '../staff_coordinate_system.dart';
import '../staff_position_calculator.dart';

class GroupRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final double staffLineThickness;
  final double stemThickness;
  final CollisionDetector?
  collisionDetector; // CORREÇÃO: Adicionar collision detector
  late final SMuFLPositioningEngine positioningEngine;

  GroupRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    required this.staffLineThickness,
    required this.stemThickness,
    this.collisionDetector, // CORREÇÃO: Parâmetro opcional
  }) {
    // Initialize with already loaded metadata
    positioningEngine = SMuFLPositioningEngine(metadataLoader: metadata);
  }

  Map<int, List<int>> _identifyBeamGroups(List<PositionedElement> elements) {
    final groups = <int, List<int>>{};
    int groupId = 0;
    for (int i = 0; i < elements.length; i++) {
      final element = elements[i].element;
      if (element is Note && element.beam == BeamType.start) {
        final group = <int>[i];
        for (int j = i + 1; j < elements.length; j++) {
          final nextElement = elements[j].element;
          if (nextElement is Note) {
            group.add(j);
            if (nextElement.beam == BeamType.end) break;
          } else {
            break;
          }
        }
        if (group.length >= 2) {
          groups[groupId++] = group;
        }
      }
    }
    return groups;
  }

  void renderBeams(
    Canvas canvas,
    List<PositionedElement> elements,
    Clef currentClef,
  ) {
    final beamGroups = _identifyBeamGroups(elements);
    for (final group in beamGroups.values) {
      if (group.length < 2) continue;

      final positions = <Offset>[];
      final staffPositions = <int>[];
      final durations = <DurationType>[];
      final groupElements = <PositionedElement>[];

      for (final index in group) {
        final element = elements[index];
        groupElements.add(element);
        if (element.element is Note) {
          final note = element.element as Note;
          // MELHORIA: Usar StaffPositionCalculator unificado
          final staffPos = StaffPositionCalculator.calculate(
            note.pitch,
            currentClef,
          );
          final noteY = StaffPositionCalculator.toPixelY(
            staffPos,
            coordinates.staffSpace,
            coordinates.staffBaseline.dy,
          );
          positions.add(Offset(element.position.dx, noteY));
          staffPositions.add(staffPos);
          durations.add(note.duration.type);
        }
      }
      if (staffPositions.isNotEmpty) {
        final avgPos =
            staffPositions.reduce((a, b) => a + b) / staffPositions.length;
        final stemUp = avgPos <= 0;
        _renderBeamGroup(canvas, groupElements, positions, durations, stemUp);
      }
    }
  }

  void _renderBeamGroup(
    Canvas canvas,
    List<PositionedElement> groupElements,
    List<Offset> positions,
    List<DurationType> durations,
    bool stemUp,
  ) {
    if (positions.length < 2) return;

    int maxBeams = 0;
    final beamCounts = durations.map((duration) {
      final beams = switch (duration) {
        DurationType.eighth => 1,
        DurationType.sixteenth => 2,
        DurationType.thirtySecond => 3,
        DurationType.sixtyFourth => 4,
        _ => 0,
      };
      if (beams > maxBeams) maxBeams = beams;
      return beams;
    }).toList();


    // CORREÇÃO VISUAL: Valores ajustados empiricamente
    // Valores teóricos de Behind Bars (0.5 SS thickness, 0.25 SS spacing)
    // produziam beams muito grossas visualmente no Flutter
    //
    // Valores calibrados para melhor aparência:
    // - beamThickness: ~0.35-0.4 SS (mais fino)
    // - beamSpacing: ~0.35-0.4 SS (mais espaçado)
    final beamThickness = coordinates.staffSpace * 0.4; // Mais fino
    final beamSpacing = coordinates.staffSpace * 0.60; // Mais espaçado

    // CORREÇÃO SMuFL: Usar âncoras das cabeças de nota
    final stemEndpoints = <Offset>[];
    final staffPositions = <int>[];

    for (int i = 0; i < positions.length; i++) {
      final element = groupElements[i].element as Note;
      final noteGlyph = durations[i].glyphName;
      // MELHORIA: Usar StaffPositionCalculator
      final staffPos = StaffPositionCalculator.calculate(
        element.pitch,
        Clef(clefType: ClefType.treble),
      );

      staffPositions.add(staffPos);

      // Usar âncora SMuFL para posição da haste
      final stemAnchor = stemUp
          ? positioningEngine.getStemUpAnchor(noteGlyph)
          : positioningEngine.getStemDownAnchor(noteGlyph);

      final stemX = positions[i].dx + (stemAnchor.dx * coordinates.staffSpace);
      final stemY = positions[i].dy + (stemAnchor.dy * coordinates.staffSpace);
      stemEndpoints.add(Offset(stemX, stemY));
    }

    // CORREÇÃO SMuFL: Calcular ângulo do feixe usando positioning engine
    // Baseado em Ted Ross e Behind Bars
    final beamAngleSpaces = positioningEngine.calculateBeamAngle(
      noteStaffPositions: staffPositions,
      stemUp: stemUp,
    );

    // Calcular altura do feixe usando positioning engine
    // CORREÇÃO: Passar maxBeams para garantir comprimento mínimo de haste
    final beamHeightSpaces = positioningEngine.calculateBeamHeight(
      staffPosition: staffPositions.first,
      stemUp: stemUp,
      allStaffPositions: staffPositions,
      beamCount: maxBeams, // ← CRÍTICO: Garantir espaço para todas as beams!
    );
    final beamHeightPixels = beamHeightSpaces * coordinates.staffSpace;

    // Primeira e última posição do feixe
    final firstNoteY = positions.first.dy;
    final lastNoteY = positions.last.dy;
    final avgNoteY = (firstNoteY + lastNoteY) / 2;

    final beamBaseY = stemUp
        ? avgNoteY - beamHeightPixels
        : avgNoteY + beamHeightPixels;

    // Converter ângulo de spaces para slope pixel
    final xDistance = stemEndpoints.last.dx - stemEndpoints.first.dx;
    final beamAnglePixels = (beamAngleSpaces * coordinates.staffSpace);
    final beamSlope = xDistance > 0 ? beamAnglePixels / xDistance : 0.0;

    final firstStem = Offset(stemEndpoints.first.dx, beamBaseY);

    double getBeamY(double x) {
      return firstStem.dy + (beamSlope * (x - firstStem.dx));
    }

    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = stemThickness;
    final beamPaint = Paint()
      ..color = theme.beamColor ?? theme.stemColor
      ..style = PaintingStyle.fill;

    // Draw beams
    for (int beamLevel = 0; beamLevel < maxBeams; beamLevel++) {
      Path? currentPath;
      int pathStartIndex = -1;
      for (int i = 0; i < groupElements.length; i++) {
        if (beamCounts[i] > beamLevel) {
          if (currentPath == null) {
            currentPath = Path();
            pathStartIndex = i;
          }
        }
        bool shouldEndPath = false;
        if (i == groupElements.length - 1) {
          shouldEndPath = currentPath != null;
        } else {
          if (beamCounts[i] > beamLevel && beamCounts[i + 1] <= beamLevel) {
            shouldEndPath = true;
          }
        }
        if (shouldEndPath && currentPath != null && pathStartIndex >= 0) {
          int endIndex = i;
          if (beamCounts[i] <= beamLevel && i > pathStartIndex) {
            endIndex = i - 1;
          }
          if (pathStartIndex <= endIndex) {
            final yOffset = stemUp
                ? beamLevel * beamSpacing
                : -beamLevel * beamSpacing;
            final startX = stemEndpoints[pathStartIndex].dx;
            final endX = stemEndpoints[endIndex].dx;
            final startY = getBeamY(startX) + yOffset;
            final endY = getBeamY(endX) + yOffset;
            final beamDirection = stemUp ? 1.0 : -1.0;
            currentPath.moveTo(startX, startY);
            currentPath.lineTo(endX, endY);
            currentPath.lineTo(endX, endY + beamThickness * beamDirection);
            currentPath.lineTo(startX, startY + beamThickness * beamDirection);
            currentPath.close();
            canvas.drawPath(currentPath, beamPaint);
          }
          currentPath = null;
          pathStartIndex = -1;
        }
      }
    }

    // CORREÇÃO: Desenhar cabeças de nota
    // IMPORTANTE: Não usar stroke/outline para evitar retângulos
    for (int i = 0; i < positions.length; i++) {
      final noteGlyph = durations[i].glyphName;
      final notePosition = positions[i];
      
      final character = metadata.getCodepoint(noteGlyph);
      if (character.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: character,
            style: TextStyle(
              fontFamily: 'Bravura',
              fontSize: glyphSize,
              color: theme.noteheadColor,
              height: 1.0,
              // CRÍTICO: Sem decoração, sem stroke!
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Aplicar baseline correction igual ao noteheadDefault
        final baselineCorrection = -textPainter.height * 0.5;
        textPainter.paint(
          canvas,
          Offset(notePosition.dx, notePosition.dy + baselineCorrection),
        );
      }
    }
    
    // Draw stems
    for (int i = 0; i < positions.length; i++) {
      final stemX = stemEndpoints[i].dx;
      final beamY = getBeamY(stemX);
      canvas.drawLine(
        Offset(stemX, positions[i].dy),
        Offset(stemX, beamY),
        stemPaint,
      );
    }
  }

  /// Identifica grupos de notas ligadas por ties (público para SlurRenderer)
  Map<int, List<int>> identifyTieGroups(List<PositionedElement> elements) {
    final groups = <int, List<int>>{};
    int groupId = 0;
    for (int i = 0; i < elements.length; i++) {
      final element = elements[i].element;
      if (element is Note && element.tie == TieType.start) {
        final group = <int>[i];
        for (int j = i + 1; j < elements.length; j++) {
          final nextElement = elements[j].element;
          if (nextElement is Note &&
              nextElement.pitch.step == (element).pitch.step &&
              nextElement.pitch.octave == element.pitch.octave) {
            group.add(j);
            if (nextElement.tie == TieType.end) break;
          }
        }
        if (group.length >= 2) {
          groups[groupId++] = group;
        }
      }
    }
    return groups;
  }

  void renderTies(
    Canvas canvas,
    List<PositionedElement> elements,
    Clef currentClef,
  ) {
    final tieGroups = identifyTieGroups(elements);
    for (final group in tieGroups.values) {
      final startElement = elements[group.first];
      final endElement = elements[group.last];
      if (startElement.element is! Note || endElement.element is! Note) {
        continue;
      }

      final startNote = startElement.element as Note;
      // MELHORIA: Usar StaffPositionCalculator
      final startStaffPos = StaffPositionCalculator.calculate(
        startNote.pitch,
        currentClef,
      );

      // CORREÇÃO LACERDA: "Ligaduras ficam do lado OPOSTO das hastes"
      // Se haste para cima, ligadura embaixo; se haste para baixo, ligadura em cima
      final stemUp =
          startStaffPos <=
          0; // Haste para cima quando nota está abaixo/na linha central
      final tieAbove = !stemUp; // Ligadura oposta à haste

      // MELHORIA: Usar StaffPositionCalculator.toPixelY
      final startNoteY = StaffPositionCalculator.toPixelY(
        startStaffPos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );
      final endStaffPos = StaffPositionCalculator.calculate(
        (endElement.element as Note).pitch,
        currentClef,
      );
      final endNoteY = StaffPositionCalculator.toPixelY(
        endStaffPos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );
      final noteWidth = coordinates.staffSpace * 1.18;

      // CORREÇÃO SMuFL: Ligadura NÃO deve tocar as cabeças de nota
      // Distância mínima: 0.25 staff spaces (Behind Bars, p. 180)
      final clearance = coordinates.staffSpace * 0.25;

      final startPoint = Offset(
        startElement.position.dx + noteWidth * 0.75, // Mais à direita
        startNoteY +
            (tieAbove
                ? -(clearance + coordinates.staffSpace * 0.15)
                : (clearance + coordinates.staffSpace * 0.15)),
      );
      final endPoint = Offset(
        endElement.position.dx + noteWidth * 0.25, // Mais à esquerda
        endNoteY +
            (tieAbove
                ? -(clearance + coordinates.staffSpace * 0.15)
                : (clearance + coordinates.staffSpace * 0.15)),
      );

      // CORREÇÃO SMuFL: Altura da ligadura baseada em interpolação linear (Behind Bars)
      // height = k * width + d, limitado por min/max
      final distance = (endPoint.dx - startPoint.dx).abs();
      final distanceInSpaces = distance / coordinates.staffSpace;

      // Fórmula de interpolação (EngravingRules)
      // k = 0.0288, d = 0.136
      final heightSpaces = (0.0288 * distanceInSpaces + 0.136).clamp(0.28, 1.2);
      final curvatureHeight = heightSpaces * coordinates.staffSpace;

      final controlPoint = Offset(
        (startPoint.dx + endPoint.dx) / 2,
        ((startPoint.dy + endPoint.dy) / 2) +
            (curvatureHeight * (tieAbove ? -1 : 1)),
      );

      // CORREÇÃO SMuFL: Espessura da ligadura mais fina
      // EngravingRules: slurEndpointThickness = 0.1, slurMidpointThickness = 0.22
      // Média para stroke: 0.16 staff spaces
      final tiePaint = Paint()
        ..color = theme.tieColor ?? theme.noteheadColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = coordinates.staffSpace * 0.16
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      path.moveTo(startPoint.dx, startPoint.dy);
      path.quadraticBezierTo(
        controlPoint.dx,
        controlPoint.dy,
        endPoint.dx,
        endPoint.dy,
      );
      canvas.drawPath(path, tiePaint);
    }
  }

  /// Identifica grupos de notas ligadas por slurs (público para SlurRenderer)
  Map<int, List<int>> identifySlurGroups(List<PositionedElement> elements) {
    final groups = <int, List<int>>{};
    int groupId = 0;
    for (int i = 0; i < elements.length; i++) {
      final element = elements[i].element;
      if (element is Note && element.slur == SlurType.start) {
        final group = <int>[i];
        for (int j = i + 1; j < elements.length; j++) {
          final nextElement = elements[j].element;
          if (nextElement is Note) {
            group.add(j);
            if (nextElement.slur == SlurType.end) break;
          }
        }
        if (group.length >= 2) {
          groups[groupId++] = group;
        }
      }
    }
    return groups;
  }

  void renderSlurs(
    Canvas canvas,
    List<PositionedElement> elements,
    Clef currentClef,
  ) {
    final slurGroups = identifySlurGroups(elements);
    for (final group in slurGroups.values) {
      if (group.length < 2) continue;

      final startElement = elements[group.first];
      final endElement = elements[group.last];
      if (startElement.element is! Note || endElement.element is! Note) {
        continue;
      }
      final startNote = startElement.element as Note;
      final endNote = endElement.element as Note;
      // MELHORIA: Usar StaffPositionCalculator
      final startStaffPos = StaffPositionCalculator.calculate(
        startNote.pitch,
        currentClef,
      );
      final endStaffPos = StaffPositionCalculator.calculate(
        endNote.pitch,
        currentClef,
      );

      // CORREÇÃO LACERDA: Ligadura de expressão segue mesma regra de tie
      // Oposta à direção das hastes
      final startStemUp = startStaffPos <= 0;
      final slurAbove = !startStemUp;

      // MELHORIA: Usar StaffPositionCalculator.toPixelY
      final startNoteY = StaffPositionCalculator.toPixelY(
        startStaffPos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );
      final endNoteY = StaffPositionCalculator.toPixelY(
        endStaffPos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      final noteWidth = coordinates.staffSpace * 1.18;

      // CORREÇÃO: Ligadura mais próxima das cabeças
      final startPoint = Offset(
        startElement.position.dx + noteWidth * 0.3,
        startNoteY + (coordinates.staffSpace * 0.4 * (slurAbove ? -1 : 1)),
      );
      final endPoint = Offset(
        endElement.position.dx + noteWidth * 0.7,
        endNoteY + (coordinates.staffSpace * 0.4 * (slurAbove ? -1 : 1)),
      );

      // CORREÇÃO LACERDA: Altura do arco proporcional à distância
      // Quanto mais longa, mais alta a curva
      final distance = (endPoint.dx - startPoint.dx).abs();
      final arcHeight = coordinates.staffSpace * 1.2 + (distance * 0.04);

      // Curva bezier cúbica para forma mais natural
      final controlPoint1 = Offset(
        startPoint.dx + (endPoint.dx - startPoint.dx) * 0.3,
        startPoint.dy + (arcHeight * (slurAbove ? -1 : 1)),
      );
      final controlPoint2 = Offset(
        endPoint.dx - (endPoint.dx - startPoint.dx) * 0.3,
        endPoint.dy + (arcHeight * (slurAbove ? -1 : 1)),
      );

      // CORREÇÃO: Espessura padrão de ligadura de expressão
      final slurPaint = Paint()
        ..color = theme.slurColor ?? theme.noteheadColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = coordinates.staffSpace * 0.12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      path.moveTo(startPoint.dx, startPoint.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        endPoint.dx,
        endPoint.dy,
      );
      canvas.drawPath(path, slurPaint);
    }
  }

  // REMOVIDO: _calculateStaffPosition duplicado (41 linhas)
  // AGORA USA: StaffPositionCalculator unificado
}
