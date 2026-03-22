// Substitua o conteúdo inteiro em: lib/src/rendering/slur_calculator.dart

import 'dart:ui';
import 'dart:math' as math;
import '../../core/core.dart'; // 🆕 Tipos do core
import '../layout/layout_engine.dart';

// ################### INÍCIO DA CORREÇÃO ###################
//
// Esta versão do SlurCalculator implementa uma detecção de obstáculos
// muito mais robusta, baseada em Bounding Boxes, para evitar colisões
// com notas, hastes, acidentes e outros elementos.
//
// ##########################################################

/// Representa a caixa delimitadora de um elemento musical para detecção de colisão.
class ElementBoundingBox {
  final Rect rect;
  final MusicalElement element;

  ElementBoundingBox(this.rect, this.element);
}

/// Calcula curvas de slurs com detecção de obstáculos aprimorada.
class SlurCalculator {
  final double staffSpace;
  final List<PositionedElement> allElements;
  final List<ElementBoundingBox> _obstaclesCache = [];

  SlurCalculator({required this.staffSpace, required this.allElements}) {
    _buildObstaclesCache();
  }

  /// Pré-calcula as caixas delimitadoras de todos os elementos.
  void _buildObstaclesCache() {
    for (final positionedElement in allElements) {
      final box = _createElementBoundingBox(positionedElement);
      if (box != null) {
        _obstaclesCache.add(box);
      }
    }
  }

  /// Calcula a curva de um slur considerando obstáculos.
  SlurCurve calculateSlurCurve({
    required Offset startPoint,
    required Offset endPoint,
    required bool above,
    required List<int> noteIndices,
  }) {
    final distance = (endPoint.dx - startPoint.dx).abs();
    final baseHeight = _calculateBaseHeight(distance);

    final obstacles = _findObstacles(startPoint, endPoint, noteIndices);

    final adjustedHeight = _adjustHeightForObstacles(
      startPoint,
      endPoint,
      baseHeight,
      obstacles,
      above,
    );

    final controlPoints = _calculateControlPoints(
      startPoint,
      endPoint,
      adjustedHeight,
      above,
    );

    return SlurCurve(
      startPoint: startPoint,
      endPoint: endPoint,
      controlPoint1: controlPoints[0],
      controlPoint2: controlPoints[1],
      height: adjustedHeight,
      above: above,
    );
  }

  double _calculateBaseHeight(double distance) {
    final ratio = 0.15;
    final calculatedHeight = distance * ratio;
    final minHeight = staffSpace * 1.0;
    final maxHeight = staffSpace * 4.0;
    return calculatedHeight.clamp(minHeight, maxHeight);
  }

  /// Encontra obstáculos entre os pontos de início e fim do slur.
  List<ElementBoundingBox> _findObstacles(
    Offset start,
    Offset end,
    List<int> noteIndices,
  ) {
    final relevantObstacles = <ElementBoundingBox>[];
    final minX = math.min(start.dx, end.dx) + staffSpace * 0.5;
    final maxX = math.max(start.dx, end.dx) - staffSpace * 0.5;

    final slurElements = noteIndices.map((i) => allElements[i].element).toSet();

    for (final obstacleBox in _obstaclesCache) {
      // Ignora as notas que fazem parte do próprio slur.
      if (slurElements.contains(obstacleBox.element)) continue;

      // Verifica se o obstáculo está na faixa horizontal do slur.
      if (obstacleBox.rect.left < maxX && obstacleBox.rect.right > minX) {
        relevantObstacles.add(obstacleBox);
      }
    }
    return relevantObstacles;
  }

  /// Ajusta a altura do slur para desviar dos obstáculos.
  double _adjustHeightForObstacles(
    Offset start,
    Offset end,
    double baseHeight,
    List<ElementBoundingBox> obstacles,
    bool above,
  ) {
    if (obstacles.isEmpty) return baseHeight;

    double requiredHeight = baseHeight;
    final clearance = staffSpace * 0.3; // Espaço extra de segurança.
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;

    for (final obstacle in obstacles) {
      // Considera apenas obstáculos próximos ao centro vertical do slur.
      if ((obstacle.rect.center.dx - midX).abs() < (end.dx - start.dx) * 0.4) {
        if (above) {
          // Se o slur é acima, o obstáculo está abaixo dele.
          final verticalDistance = (midY - requiredHeight) - obstacle.rect.top;
          if (verticalDistance < clearance) {
            requiredHeight += (clearance - verticalDistance);
          }
        } else {
          // Se o slur é abaixo, o obstáculo está acima dele.
          final verticalDistance =
              obstacle.rect.bottom - (midY + requiredHeight);
          if (verticalDistance < clearance) {
            requiredHeight += (clearance - verticalDistance);
          }
        }
      }
    }
    return requiredHeight.clamp(baseHeight, staffSpace * 5.0);
  }

  List<Offset> _calculateControlPoints(
    Offset start,
    Offset end,
    double height,
    bool above,
  ) {
    final distance = end.dx - start.dx;
    final direction = above ? -1.0 : 1.0;

    // Pontos de controle simétricos para uma curva mais elegante.
    final cp1X = start.dx + distance * 0.25;
    final cp2X = start.dx + distance * 0.75;

    final midY = (start.dy + end.dy) / 2;
    final apexY = midY + (height * direction);

    // Ajusta os pontos de controle para formar um arco suave.
    final cp1Y = start.dy + (apexY - start.dy) * 0.8;
    final cp2Y = end.dy + (apexY - end.dy) * 0.8;

    return [Offset(cp1X, cp1Y), Offset(cp2X, cp2Y)];
  }

  /// Cria uma caixa delimitadora para um elemento musical.
  ElementBoundingBox? _createElementBoundingBox(PositionedElement positioned) {
    final element = positioned.element;
    final pos = positioned.position;
    double width = 0, height = 0;
    Offset center = pos;

    if (element is Note) {
      width = staffSpace * 1.2;
      height = staffSpace * 3.5; // Altura da haste.
      // Simplificação da posição da haste. Uma lógica mais completa usaria _calculateStaffPosition.
      final stemUp =
          pos.dy >
          (positioned.system * staffSpace * 10 + staffSpace * 7); // Heurística
      center = stemUp
          ? Offset(pos.dx, pos.dy - height / 2)
          : Offset(pos.dx, pos.dy + height / 2);
    } else if (element is Clef) {
      width = staffSpace * 2.5;
      height = staffSpace * 4.0;
      center = pos;
    } else {
      // Adicione outros elementos que podem ser obstáculos aqui (ex: acidentes, ornamentos)
      return null;
    }

    return ElementBoundingBox(
      Rect.fromCenter(center: center, width: width, height: height),
      element,
    );
  }

  List<SlurCurve> calculateMultipleSlurs(List<SlurGroup> slurGroups) {
    final curves = <SlurCurve>[];
    for (final group in slurGroups) {
      final curve = calculateSlurCurve(
        startPoint: group.startPoint,
        endPoint: group.endPoint,
        above: group.above,
        noteIndices: group.noteIndices,
      );
      curves.add(curve);
    }
    return curves;
  }
}

/// Representa uma curva de slur calculada
class SlurCurve {
  final Offset startPoint;
  final Offset endPoint;
  final Offset controlPoint1;
  final Offset controlPoint2;
  final double height;
  final bool above;

  SlurCurve({
    required this.startPoint,
    required this.endPoint,
    required this.controlPoint1,
    required this.controlPoint2,
    required this.height,
    required this.above,
  });
}

/// Grupo de notas ligadas por um slur
class SlurGroup {
  final Offset startPoint;
  final Offset endPoint;
  final bool above;
  final List<int> noteIndices;

  SlurGroup({
    required this.startPoint,
    required this.endPoint,
    required this.above,
    required this.noteIndices,
  });
}
