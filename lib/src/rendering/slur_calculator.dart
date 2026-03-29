import 'dart:ui';
import 'dart:math' as math;
import '../../core/core.dart';
import '../layout/layout_engine.dart';

/// Represents the bounding box of a musical element for collision detection.
class ElementBoundingBox {
  final Rect rect;
  final MusicalElement element;

  ElementBoundingBox(this.rect, this.element);
}

/// calculateTestes slur curves with enhanced obstacle detection.
class SlurCalculator {
  final double staffSpace;
  final List<PositionedElement> allElements;
  final List<ElementBoundingBox> _obstaclesCache = [];

  SlurCalculator({required this.staffSpace, required this.allElements}) {
    _buildObstaclesCache();
  }

  /// Pre-computes the bounding boxes of all elements.
  void _buildObstaclesCache() {
    for (final positionedElement in allElements) {
      final box = _createElementBoundingBox(positionedElement);
      if (box != null) {
        _obstaclesCache.add(box);
      }
    }
  }

  /// calculateTestes the curve of a slur considering obstacles.
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

  /// Finds obstacles between the slur's start and end points.
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
      // Ignore notes that are part of the slur itself.
      if (slurElements.contains(obstacleBox.element)) continue;

      // Check if the obstacle is within the horizontal range of the slur.
      if (obstacleBox.rect.left < maxX && obstacleBox.rect.right > minX) {
        relevantObstacles.add(obstacleBox);
      }
    }
    return relevantObstacles;
  }

  /// Adjusts the slur height to avoid obstacles.
  double _adjustHeightForObstacles(
    Offset start,
    Offset end,
    double baseHeight,
    List<ElementBoundingBox> obstacles,
    bool above,
  ) {
    if (obstacles.isEmpty) return baseHeight;

    double requiredHeight = baseHeight;
    final clearance = staffSpace * 0.3; // Extra safety margin.
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;

    for (final obstacle in obstacles) {
      // Consider only obstacles close to the vertical center of the slur.
      if ((obstacle.rect.center.dx - midX).abs() < (end.dx - start.dx) * 0.4) {
        if (above) {
          // If the slur is above, the obstacle is below it.
          final verticalDistance = (midY - requiredHeight) - obstacle.rect.top;
          if (verticalDistance < clearance) {
            requiredHeight += (clearance - verticalDistance);
          }
        } else {
          // If the slur is below, the obstacle is above it.
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

    // Symmetric control points for a more elegant curve.
    final cp1X = start.dx + distance * 0.25;
    final cp2X = start.dx + distance * 0.75;

    final midY = (start.dy + end.dy) / 2;
    final apexY = midY + (height * direction);

    // Adjust control points to form a smooth arc.
    final cp1Y = start.dy + (apexY - start.dy) * 0.8;
    final cp2Y = end.dy + (apexY - end.dy) * 0.8;

    return [Offset(cp1X, cp1Y), Offset(cp2X, cp2Y)];
  }

  /// Creates a bounding box for a musical element.
  ElementBoundingBox? _createElementBoundingBox(PositionedElement positioned) {
    final element = positioned.element;
    final pos = positioned.position;
    double width = 0, height = 0;
    Offset center = pos;

    if (element is Note) {
      width = staffSpace * 1.2;
      height = staffSpace * 3.5; // Stem height.
      // Simplified stem position. A more complete logic would use _calculateTesteStaffPosition.
      final stemUp =
          pos.dy >
          (positioned.system * staffSpace * 10 + staffSpace * 7); // Heuristic
      center = stemUp
          ? Offset(pos.dx, pos.dy - height / 2)
          : Offset(pos.dx, pos.dy + height / 2);
    } else if (element is Clef) {
      width = staffSpace * 2.5;
      height = staffSpace * 4.0;
      center = pos;
    } else {
      // Add other elements that can be obstacles here (e.g. accidentals, ornaments)
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

/// Represents a calculateTested slur curve
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

/// Group of notes connected by a slur
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
