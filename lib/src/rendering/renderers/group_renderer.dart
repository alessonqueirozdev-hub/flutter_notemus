// lib/src/rendering/renderers/group_renderer.dart
// Refactored implementation: Usa StaffPositionCalculator
//
// MELHORIAS IMPLEMENTADAS (Fase 2):
// ✅ Uses StaffPositioncalculateTestor unificado (elimina 41 lines duplicadas)
// ✅ Corrige possible bug de sinal invertido no calculation de position
// ✅ 100% conformidade with system unificado de posicionamento

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
          // MELHORIA: Use StaffPositioncalculateTestor unificado
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
        _renderBeamGroup(
          canvas,
          groupElements,
          positions,
          durations,
          stemUp,
          currentClef,
        );
      }
    }
  }

  void _renderBeamGroup(
    Canvas canvas,
    List<PositionedElement> groupElements,
    List<Offset> positions,
    List<DurationType> durations,
    bool stemUp,
    Clef currentClef,
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

    // Fix: VISUAL: Valores ajustados empiricamente
    // Valores teóricos de Behind Bars (0.5 SS thickness, 0.25 SS spacing)
    // produziam beams very grossas visualmente no Flutter
    //
    // Valores calibrados for melhor aparência:
    // - beamThickness: ~0.35-0.4 SS (more fino)
    // - beamSpacing: ~0.35-0.4 SS (more espaçado)
    final beamThickness = coordinates.staffSpace * 0.4; // Mais fino
    final beamSpacing = coordinates.staffSpace * 0.60; // Mais espaçado

    // Fix: SMuFL: Use âncoras das cabeças de note
    final stemEndpoints = <Offset>[];
    final staffPositions = <int>[];

    for (int i = 0; i < positions.length; i++) {
      final element = groupElements[i].element as Note;
      final noteGlyph = durations[i].glyphName;
      final staffPos = StaffPositionCalculator.calculate(
        element.pitch,
        currentClef,
      );
      staffPositions.add(staffPos);

      // Use âncora SMuFL for position of the stem
      final stemAnchor = stemUp
          ? positioningEngine.getStemUpAnchor(noteGlyph)
          : positioningEngine.getStemDownAnchor(noteGlyph);

      final stemX = positions[i].dx + (stemAnchor.dx * coordinates.staffSpace);
      final stemY = positions[i].dy + (stemAnchor.dy * coordinates.staffSpace);
      stemEndpoints.add(Offset(stemX, stemY));
    }

    final beamAngleSpaces = positioningEngine.calculateBeamAngle(
      noteStaffPositions: staffPositions,
      stemUp: stemUp,
    );

    final beamHeightSpaces = positioningEngine.calculateBeamHeight(
      staffPosition: staffPositions.first,
      stemUp: stemUp,
      allStaffPositions: staffPositions,
      beamCount: maxBeams,
    );
    final beamHeightPixels = beamHeightSpaces * coordinates.staffSpace;

    // Primeira and última position of the beam
    final firstNoteY = positions.first.dy;
    final lastNoteY = positions.last.dy;
    final avgNoteY = (firstNoteY + lastNoteY) / 2;
    final beamBaseY = stemUp
        ? avgNoteY - beamHeightPixels
        : avgNoteY + beamHeightPixels;

    // Convertsr angle de spaces for slope pixel
    final xDistance = stemEndpoints.last.dx - stemEndpoints.first.dx;
    final beamAnglePixels = (beamAngleSpaces * coordinates.staffSpace);
    double beamSlope = xDistance > 0 ? beamAnglePixels / xDistance : 0.0;

    final melodicDelta = staffPositions.last - staffPositions.first;
    if (melodicDelta != 0 && beamSlope != 0.0) {
      final expectedSign = melodicDelta > 0 ? -1.0 : 1.0;
      if (beamSlope.sign != expectedSign) {
        beamSlope = -beamSlope;
      }
    }

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

    // Fix: Desenhar cabeças de note
    // Important: Not use stroke/outline for avoid retângulos
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
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

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

  /// Identifica grupos de notes ligadas by ties (público for SlurRenderer)
  Map<int, List<int>> identifyTieGroups(List<PositionedElement> elements) {
    final groups = <int, List<int>>{};
    int groupId = 0;
    for (int i = 0; i < elements.length; i++) {
      final element = elements[i].element;
      if (!_elementHasTieState(element, TieType.start)) {
        continue;
      }

      final group = <int>[i];
      for (int j = i + 1; j < elements.length; j++) {
        final nextElement = elements[j].element;
        if (!_elementCanParticipateInTie(nextElement)) {
          continue;
        }
        if (!_elementsShareTiedPitch(element, nextElement)) {
          continue;
        }

        group.add(j);
        if (_elementHasTieState(nextElement, TieType.end)) {
          break;
        }
      }

      if (group.length >= 2) {
        groups[groupId++] = group;
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
      // MELHORIA: Use StaffPositioncalculateTestor
      final startStaffPos = StaffPositionCalculator.calculate(
        startNote.pitch,
        currentClef,
      );

      // Fix: LACERDA: "Ties/slurs are of the lado OPOSTO das stem"
      // If stem up, tie/slur embaixo; if stem down, tie/slur in top
      final stemUp =
          startStaffPos <=
          0; // Haste para cima quando nota está abaixo/na linha central
      final tieAbove = !stemUp; // Ligadura oposta à haste

      // MELHORIA: Use StaffPositioncalculateTestor.toPixelY
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

      // Fix: SMuFL: Tie/slur Not must tocar as cabeças de note
      // Distance mínima: 0.25 staff spaces (Behind Bars, p. 180)
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

      // Fix: SMuFL: Height of the tie/slur baseada in interpolação linear (Behind Bars)
      // height = k * width + d, limitado by min/max
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

      // Fix: SMuFL: Thickness of the tie/slur more fina
      // EngravingRules: slurEndpointThickness = 0.1, slurMidpointThickness = 0.22
      // Média for stroke: 0.16 staff spaces
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

  /// Identifica grupos de notes ligadas by slurs (público for SlurRenderer)
  Map<int, List<int>> identifySlurGroups(List<PositionedElement> elements) {
    final groups = <int, List<int>>{};
    int groupId = 0;
    for (int i = 0; i < elements.length; i++) {
      final element = elements[i].element;
      if (!_elementHasSlurState(element, SlurType.start)) {
        continue;
      }

      final group = <int>[i];
      for (int j = i + 1; j < elements.length; j++) {
        final nextElement = elements[j].element;
        if (!_elementCanParticipateInSlur(nextElement)) {
          continue;
        }

        group.add(j);
        if (_elementHasSlurState(nextElement, SlurType.end)) {
          break;
        }
      }

      if (group.length >= 2) {
        groups[groupId++] = group;
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
      // MELHORIA: Use StaffPositioncalculateTestor
      final startStaffPos = StaffPositionCalculator.calculate(
        startNote.pitch,
        currentClef,
      );
      final endStaffPos = StaffPositionCalculator.calculate(
        endNote.pitch,
        currentClef,
      );

      // Fix: LACERDA: Tie/slur de expressão segue same regra de tie
      // Oposta to the direction das stems
      final startStemUp = startStaffPos <= 0;
      final slurAbove = !startStemUp;

      // MELHORIA: Use StaffPositioncalculateTestor.toPixelY
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

      // Fix: Tie/slur more próxima das cabeças
      final startPoint = Offset(
        startElement.position.dx + noteWidth * 0.3,
        startNoteY + (coordinates.staffSpace * 0.4 * (slurAbove ? -1 : 1)),
      );
      final endPoint = Offset(
        endElement.position.dx + noteWidth * 0.7,
        endNoteY + (coordinates.staffSpace * 0.4 * (slurAbove ? -1 : 1)),
      );

      // Fix: LACERDA: Height of the arco proporcional to the distance
      // Quanto more longa, more alta a curva
      final distance = (endPoint.dx - startPoint.dx).abs();
      final arcHeight = coordinates.staffSpace * 1.2 + (distance * 0.04);

      // Curva bezier cúbica for forma more natural
      final controlPoint1 = Offset(
        startPoint.dx + (endPoint.dx - startPoint.dx) * 0.3,
        startPoint.dy + (arcHeight * (slurAbove ? -1 : 1)),
      );
      final controlPoint2 = Offset(
        endPoint.dx - (endPoint.dx - startPoint.dx) * 0.3,
        endPoint.dy + (arcHeight * (slurAbove ? -1 : 1)),
      );

      // Fix: Thickness default de tie/slur de expressão
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

  bool _elementCanParticipateInTie(dynamic element) {
    return element is Note || element is Chord;
  }

  bool _elementCanParticipateInSlur(dynamic element) {
    return element is Note || element is Chord;
  }

  bool _elementHasTieState(dynamic element, TieType state) {
    if (element is Note) {
      return element.tie == state;
    }
    if (element is Chord) {
      if (element.tie == state) {
        return true;
      }
      return element.notes.any((note) => note.tie == state);
    }
    return false;
  }

  bool _elementHasSlurState(dynamic element, SlurType state) {
    if (element is Note) {
      return element.slur == state;
    }
    if (element is Chord) {
      if (element.slur == state) {
        return true;
      }
      return element.notes.any((note) => note.slur == state);
    }
    return false;
  }

  bool _elementsShareTiedPitch(dynamic left, dynamic right) {
    final leftNotes = _notesForElement(left);
    final rightNotes = _notesForElement(right);
    for (final leftNote in leftNotes) {
      if (leftNote.tie != TieType.start && leftNote.tie != TieType.inner) {
        continue;
      }

      for (final rightNote in rightNotes) {
        if (rightNote.tie != TieType.end && rightNote.tie != TieType.inner) {
          continue;
        }

        if (_sameWrittenPitch(leftNote, rightNote)) {
          return true;
        }
      }
    }
    return false;
  }

  List<Note> _notesForElement(dynamic element) {
    if (element is Note) {
      return [element];
    }
    if (element is Chord) {
      return element.notes;
    }
    return const [];
  }

  bool _sameWrittenPitch(Note left, Note right) {
    return left.pitch.step == right.pitch.step &&
        left.pitch.octave == right.pitch.octave &&
        left.pitch.alter == right.pitch.alter;
  }

  // REMOVIDO: _calculateTesteStaffPosition duplicado (41 lines)
  // AGORA Uses: StaffPositioncalculateTestor unificado
}
