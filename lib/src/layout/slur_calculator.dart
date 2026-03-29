// lib/src/layout/slur_calculateTestor.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bounding_box.dart';
import 'skyline_calculator.dart';
import '../engraving/engraving_rules.dart';

/// Calculator de Slurs with curvas Bézier cúbicas
///
/// Based on:
/// - OpenSheetMusicDisplay (TiecalculateTestor.ts and SlurcalculateTestor.ts)
/// - Behind Bars (Elaine Gould) - regras de slurs
/// - SMuFL specification - anchors and positioning
///
/// Algoritmo:
/// 1. Ajustar points de start/end with offsets (slurNoteHeadYOffset)
/// 2. Coletar points of the skyline between start and end
/// 3. Rotacionar coordinate system for simplificar calculations
/// 4. Calculate slopes máximas that evitam colisões
/// 5. Limitar angles tangentes (30° a 80° according to Behind Bars)
/// 6. Generatesr points de control Bézier cúbica
/// 7. Rotacionar de volta to the system original
/// 8. Returnsr curva Bézier final
class SlurCalculator {
  final EngravingRules rules;
  final SkyBottomLineCalculator? skylineCalculator;

  SlurCalculator({
    EngravingRules? rules,
    this.skylineCalculator,
  }) : rules = rules ?? EngravingRules();

  /// Calculates a curva Bézier cúbica for a slur
  ///
  /// @param startPoint Start point of the slur (absolute position)
  /// @param endPoint End point of the slur (absolute position)
  /// @param placement If true, slur is above the notes; if false, below
  /// @param notesBoundingBoxes BoundingBoxes das notes between start and end
  /// @param staffSpace Staff space size in pixels
  /// @return CubicBezierCurve with 4 points de control
  CubicBezierCurve calculateSlur({
    required Offset startPoint,
    required Offset endPoint,
    required bool placement,
    List<BoundingBox>? notesBoundingBoxes,
    double staffSpace = 10.0,
  }) {
    // 1. Ajustar points de start/end with offset vertical
    final yOffsetPixels = rules.slurNoteHeadYOffset * staffSpace;
    final adjustedStart = placement
        ? Offset(startPoint.dx, startPoint.dy - yOffsetPixels)
        : Offset(startPoint.dx, startPoint.dy + yOffsetPixels);

    final adjustedEnd = placement
        ? Offset(endPoint.dx, endPoint.dy - yOffsetPixels)
        : Offset(endPoint.dx, endPoint.dy + yOffsetPixels);

    // 2. Calculate length horizontal of the slur
    final horizontalLength = (adjustedEnd.dx - adjustedStart.dx).abs();

    // 3. Calculate height ideal of the slur based no length
    // Fórmula OSMD: height = k * sqrt(length) where k varia with placement
    final heightFactor = placement ? 0.5 : 0.4;
    final idealHeight = heightFactor * math.sqrt(horizontalLength);

    // 4. Ajustar height if houver colisões with skyline
    // C2 FIX: removed redundant `&& notesBoundingBoxes != null` guard —
    // _adjustHeightForCollisions only uses skylinecalculateTestor, so collision
    // avoidance was never activated even though staff_renderer passes a
    // SkyBottomLinecalculateTestor.
    double finalHeight = idealHeight;
    if (skylineCalculator != null) {
      finalHeight = _adjustHeightForCollisions(
        adjustedStart,
        adjustedEnd,
        idealHeight,
        placement,
        staffSpace,
      );
    }

    // 5. Calculate angle de slope of the slur
    final deltaY = adjustedEnd.dy - adjustedStart.dy;
    final deltaX = adjustedEnd.dx - adjustedStart.dx;
    double slopeAngle = math.atan2(deltaY, deltaX) * 180 / math.pi;

    // Limitar angle de slope according to regras
    final maxSlopeAngle = rules.slurSlopeMaxAngle;
    if (slopeAngle.abs() > maxSlopeAngle) {
      slopeAngle = slopeAngle.sign * maxSlopeAngle;
    }

    // 6. Calculate points de control of the curva Bézier cúbica
    final controlPoints = _calculateBezierControlPoints(
      adjustedStart,
      adjustedEnd,
      finalHeight,
      slopeAngle,
      placement,
    );

    return CubicBezierCurve(
      p0: controlPoints[0],
      p1: controlPoints[1],
      p2: controlPoints[2],
      p3: controlPoints[3],
    );
  }

  /// Ajusta height of the slur for avoid colisões with notes
  double _adjustHeightForCollisions(
    Offset startPoint,
    Offset endPoint,
    double idealHeight,
    bool placement,
    double staffSpace,
  ) {
    if (skylineCalculator == null) return idealHeight;

    // Get points of the skyline/bottomline no intervalo of the slur
    final points = placement
        ? skylineCalculator!.getSkyLinePoints(startPoint.dx, endPoint.dx)
        : skylineCalculator!.getBottomLinePoints(startPoint.dx, endPoint.dx);

    if (points.isEmpty) return idealHeight;

    // Encontrar point more extremo (more alto for placement=true, more bottom for false)
    double extremeY = placement ? double.infinity : double.negativeInfinity;
    for (final point in points) {
      if (placement) {
        extremeY = math.min(extremeY, point.y);
      } else {
        extremeY = math.max(extremeY, point.y);
      }
    }

    // Calculate height required for avoid colisão
    final midPointY = (startPoint.dy + endPoint.dy) / 2;
    final clearance = rules.slurClearanceMinimum * staffSpace;

    double requiredHeight;
    if (placement) {
      // Slur above: needs be placed above the skyline
      requiredHeight = (midPointY - extremeY).abs() + clearance;
    } else {
      // Slur below: needs be placed below the bottomline
      requiredHeight = (extremeY - midPointY).abs() + clearance;
    }

    // Returnsr o greater between height ideal and height required
    return math.max(idealHeight, requiredHeight);
  }

  /// Calculates os 4 points de control de a curva Bézier cúbica
  ///
  /// Algoritmo based on OSMD and Behind Bars:
  /// - P0: point initial
  /// - P1: point de control initial (tangent with angle limitado)
  /// - P2: point de control final (tangent with angle limitado)
  /// - P3: point final
  List<Offset> _calculateBezierControlPoints(
    Offset start,
    Offset end,
    double height,
    double slopeAngle,
    bool placement,
  ) {
    // Calculate length horizontal and vertical
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);

    // Calculate angles tangentes nos points initial and final
    // OSMD Uses angles between 30° and 80° according to Behind Bars
    final minTangentAngle = rules.slurTangentMinAngle * math.pi / 180;
    final maxTangentAngle = rules.slurTangentMaxAngle * math.pi / 180;

    // Angle tangent based no length of the slur
    // Slurs curtos: angle more íngreme
    // Slurs longos: angle more smooth
    final tangentAngleFactor = (length / 100.0).clamp(0.0, 1.0);
    final tangentAngle = minTangentAngle +
        (maxTangentAngle - minTangentAngle) * (1.0 - tangentAngleFactor);

    // Calculate length dos vectors de control
    // OSMD Uses aproximadamente 1/3 of the length total
    final controlLength = length * 0.38;

    // P0: point initial
    final p0 = start;

    // P1: point de control initial
    // Direction: angle of the slur + angle tangent
    final startControlAngle = math.atan2(dy, dx) +
        (placement ? -tangentAngle : tangentAngle);
    final p1 = Offset(
      start.dx + controlLength * math.cos(startControlAngle),
      start.dy + controlLength * math.sin(startControlAngle),
    );

    // P2: point de control final
    // Direction: angle of the slur - angle tangent (simétrico)
    final endControlAngle = math.atan2(dy, dx) +
        (placement ? tangentAngle : -tangentAngle);
    final p2 = Offset(
      end.dx - controlLength * math.cos(endControlAngle),
      end.dy - controlLength * math.sin(endControlAngle),
    );

    // P3: point final
    final p3 = end;

    return [p0, p1, p2, p3];
  }

  /// Calculates a tie (tie/slur de prolongation)
  ///
  /// Ties are similares a slurs mas with regras específicas:
  /// - Always connect notes of the same height
  /// - Height baseada in interpolação linear (Behind Bars)
  /// - Forma more simétrica and previsível
  ///
  /// @param startPoint Point initial of the tie
  /// @param endPoint Point final of the tie
  /// @param placement if true, tie above; if false, below
  /// @param staffSpace Staff space size in pixels
  /// @return CubicBezierCurve
  CubicBezierCurve calculateTie({
    required Offset startPoint,
    required Offset endPoint,
    required bool placement,
    double staffSpace = 10.0,
  }) {
    // 1. Calculate length horizontal (in staff spaces)
    final horizontalLengthSS = (endPoint.dx - startPoint.dx) / staffSpace;

    // 2. Calculate height using interpolação linear (Behind Bars)
    // height = k * width + d
    // With limites mínimo and máximo
    final heightSS = rules.calculateTieHeight(horizontalLengthSS);
    final heightPixels = heightSS * staffSpace;

    // 3. For ties, os points are always na same height Y
    // (diferente de slurs that can connect notes diferentes)
    final adjustedStart = startPoint;
    final adjustedEnd = endPoint;

    // 4. Calculate points de control of the Bézier
    // Ties use forma more simétrica that slurs
    final controlPoints = _calculateTieBezierControlPoints(
      adjustedStart,
      adjustedEnd,
      heightPixels,
      placement,
    );

    return CubicBezierCurve(
      p0: controlPoints[0],
      p1: controlPoints[1],
      p2: controlPoints[2],
      p3: controlPoints[3],
    );
  }

  /// Calculates points de control Bézier for ties (more simétrico that slurs)
  List<Offset> _calculateTieBezierControlPoints(
    Offset start,
    Offset end,
    double height,
    bool placement,
  ) {
    final dx = end.dx - start.dx;
    // midX not used, removido for avoid warning

    // For ties, Use angle tangent Smaller (Behind Bars: ties must be achatados)
    final tangentAngle = 25.0 * math.pi / 180; // Reduzido de 45° para 25°

    // Length dos vectors de control: 35% of the length total (reduzido)
    final controlLength = dx * 0.35; // Reduzido de 0.4 para 0.35

    // P0: point initial
    final p0 = start;

    // P1: point de control initial
    final p1 = Offset(
      start.dx + controlLength,
      placement
          ? start.dy - controlLength * math.tan(tangentAngle)
          : start.dy + controlLength * math.tan(tangentAngle),
    );

    // P2: point de control final (simétrico a P1)
    final p2 = Offset(
      end.dx - controlLength,
      placement
          ? end.dy - controlLength * math.tan(tangentAngle)
          : end.dy + controlLength * math.tan(tangentAngle),
    );

    // P3: point final
    final p3 = end;

    return [p0, p1, p2, p3];
  }

  /// Calculates múltiplos points to the longo of the curva Bézier
  ///
  /// Útil for:
  /// - Rendering of the curva
  /// - Detecção de colisões needs
  /// - Currentização de skyline/bottomline
  ///
  /// @param curve Curva Bézier
  /// @param numPoints Number de points a Generatesr (default: 20)
  /// @return List of offsets to the longo of the curva
  List<Offset> sampleBezierCurve(CubicBezierCurve curve, {int numPoints = 20}) {
    final points = <Offset>[];

    for (int i = 0; i <= numPoints; i++) {
      final t = i / numPoints;
      points.add(curve.pointAt(t));
    }

    return points;
  }

  /// Currentiza o skyline/bottomline with a curva de slur/tie
  ///
  /// @param curve Curva Bézier
  /// @param placement if true, currentiza skyline; if false, bottomline
  /// @param thickness Thickness of the line of the slur in pixels
  void updateSkylineWithCurve(
    CubicBezierCurve curve, {
    required bool placement,
    double thickness = 1.5,
  }) {
    if (skylineCalculator == null) return;

    // Amostrar points to the longo of the curva
    final points = sampleBezierCurve(curve, numPoints: 30);

    // Currentizar skyline/bottomline for each point
    for (final point in points) {
      if (placement) {
        // Slur above: currentizar skyline (subtrair thickness)
        skylineCalculator!.updateSkyLine(point.dx, point.dy - thickness / 2);
      } else {
        // Slur below: currentizar bottomline (add thickness)
        skylineCalculator!.updateBottomLine(point.dx, point.dy + thickness / 2);
      }
    }
  }
}

/// Representa a curva Bézier cúbica
///
/// Fórmula: B(t) = (1-t)³·P0 + 3(1-t)²t·P1 + 3(1-t)t²·P2 + t³·P3
/// where t ∈ [0, 1]
class CubicBezierCurve {
  final Offset p0; // Ponto inicial
  final Offset p1; // Primeiro ponto de controle
  final Offset p2; // Segundo ponto de controle
  final Offset p3; // Ponto final

  CubicBezierCurve({
    required this.p0,
    required this.p1,
    required this.p2,
    required this.p3,
  });

  /// Calculates a point na curva in t ∈ [0, 1]
  Offset pointAt(double t) {
    final u = 1.0 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;

    // B(t) = u³·P0 + 3u²t·P1 + 3ut²·P2 + t³·P3
    final x = uuu * p0.dx +
        3 * uu * t * p1.dx +
        3 * u * tt * p2.dx +
        ttt * p3.dx;

    final y = uuu * p0.dy +
        3 * uu * t * p1.dy +
        3 * u * tt * p2.dy +
        ttt * p3.dy;

    return Offset(x, y);
  }

  /// Calculates a derivada (tangent) of the curva in t ∈ [0, 1]
  Offset derivativeAt(double t) {
    final u = 1.0 - t;
    final uu = u * u;
    final tt = t * t;

    // B'(t) = 3u²(P1-P0) + 6ut(P2-P1) + 3t²(P3-P2)
    final dx = 3 * uu * (p1.dx - p0.dx) +
        6 * u * t * (p2.dx - p1.dx) +
        3 * tt * (p3.dx - p2.dx);

    final dy = 3 * uu * (p1.dy - p0.dy) +
        6 * u * t * (p2.dy - p1.dy) +
        3 * tt * (p3.dy - p2.dy);

    return Offset(dx, dy);
  }

  /// Calculates o angle of the tangent in t ∈ [0, 1] (in radianos)
  double tangentAngleAt(double t) {
    final derivative = derivativeAt(t);
    return math.atan2(derivative.dy, derivative.dx);
  }

  /// Calculates o length approximate of the curva
  ///
  /// Uses method de Simpson for integração numérica
  double approximateLength({int segments = 20}) {
    double length = 0.0;
    Offset previousPoint = p0;

    for (int i = 1; i <= segments; i++) {
      final t = i / segments;
      final currentPoint = pointAt(t);
      final dx = currentPoint.dx - previousPoint.dx;
      final dy = currentPoint.dy - previousPoint.dy;
      length += math.sqrt(dx * dx + dy * dy);
      previousPoint = currentPoint;
    }

    return length;
  }

  /// Converts for Path of the Flutter (for Rendering)
  Path toPath() {
    final path = Path();
    path.moveTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    return path;
  }

  /// Calculates bounding box of the curva
  BoundingBox calculateBoundingBox() {
    // Encontrar min/max de x and y to the longo of the curva
    double minX = math.min(p0.dx, p3.dx);
    double maxX = math.max(p0.dx, p3.dx);
    double minY = math.min(p0.dy, p3.dy);
    double maxY = math.max(p0.dy, p3.dy);

    // Amostrar points intermediários
    for (int i = 1; i < 20; i++) {
      final t = i / 20.0;
      final point = pointAt(t);
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    final box = BoundingBox();
    box.relativePosition = PointF2D(minX, minY);
    box.borderLeft = 0;
    box.borderRight = maxX - minX;
    box.borderTop = 0;
    box.borderBottom = maxY - minY;
    box.size = SizeF2D(maxX - minX, maxY - minY);

    return box;
  }

  @override
  String toString() {
    return 'CubicBezierCurve(p0: $p0, p1: $p1, p2: $p2, p3: $p3)';
  }
}