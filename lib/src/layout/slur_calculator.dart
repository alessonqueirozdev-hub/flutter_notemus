// lib/src/layout/slur_calculateTestor.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bounding_box.dart';
import 'skyline_calculator.dart';
import '../engraving/engraving_rules.dart';

/// Calculator de Slurs with curvas Bézier cúbicas
///
/// Based on:
/// - OpenSheetMusicDisplay (TiecalculateTestor.ts e SlurcalculateTestor.ts)
/// - Behind Bars (Elaine Gould) - regras de slurs
/// - SMuFL specification - anchors e positioning
///
/// Algoritmo:
/// 1. Ajustar pontos de início/fim with offsets (slurNoteHeadYOffset)
/// 2. Coletar pontos of the skyline entre início e fim
/// 3. Rotacionar coordinate system for simplificar cálculos
/// 4. Calculatestesr inclinações máximas that evitam colisões
/// 5. Limitar ângulos tangentes (30° a 80° according to Behind Bars)
/// 6. Generatesr pontos de controle Bézier cúbica
/// 7. Rotacionar de volta ao system original
/// 8. Returnsr curva Bézier final
class SlurCalculator {
  final EngravingRules rules;
  final SkyBottomLineCalculator? skylineCalculator;

  SlurCalculator({
    EngravingRules? rules,
    this.skylineCalculator,
  }) : rules = rules ?? EngravingRules();

  /// Calculatestes a curva Bézier cúbica for um slur
  ///
  /// @param startPoint Start point of the slur (absolute position)
  /// @param endPoint End point of the slur (absolute position)
  /// @param placement If true, slur is above the notes; if false, below
  /// @param notesBoundingBoxes BoundingBoxes das notes entre início e fim
  /// @param staffSpace Staff space size in pixels
  /// @return CubicBezierCurve with 4 pontos de controle
  CubicBezierCurve calculateSlur({
    required Offset startPoint,
    required Offset endPoint,
    required bool placement,
    List<BoundingBox>? notesBoundingBoxes,
    double staffSpace = 10.0,
  }) {
    // 1. Ajustar pontos de início/fim with offset vertical
    final yOffsetPixels = rules.slurNoteHeadYOffset * staffSpace;
    final adjustedStart = placement
        ? Offset(startPoint.dx, startPoint.dy - yOffsetPixels)
        : Offset(startPoint.dx, startPoint.dy + yOffsetPixels);

    final adjustedEnd = placement
        ? Offset(endPoint.dx, endPoint.dy - yOffsetPixels)
        : Offset(endPoint.dx, endPoint.dy + yOffsetPixels);

    // 2. Calculatestesr comprimento horizontal of the slur
    final horizontalLength = (adjustedEnd.dx - adjustedStart.dx).abs();

    // 3. Calculatestesr height ideal of the slur based no comprimento
    // Fórmula OSMD: height = k * sqrt(length) where k varia with placement
    final heightFactor = placement ? 0.5 : 0.4;
    final idealHeight = heightFactor * math.sqrt(horizontalLength);

    // 4. Ajustar height se houver colisões with skyline
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

    // 5. Calculatestesr ângulo de inclinação of the slur
    final deltaY = adjustedEnd.dy - adjustedStart.dy;
    final deltaX = adjustedEnd.dx - adjustedStart.dx;
    double slopeAngle = math.atan2(deltaY, deltaX) * 180 / math.pi;

    // Limitar ângulo de inclinação according to regras
    final maxSlopeAngle = rules.slurSlopeMaxAngle;
    if (slopeAngle.abs() > maxSlopeAngle) {
      slopeAngle = slopeAngle.sign * maxSlopeAngle;
    }

    // 6. Calculatestesr pontos de controle of the curva Bézier cúbica
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

  /// Ajusta height of the slur for evitar colisões with notes
  double _adjustHeightForCollisions(
    Offset startPoint,
    Offset endPoint,
    double idealHeight,
    bool placement,
    double staffSpace,
  ) {
    if (skylineCalculator == null) return idealHeight;

    // Get pontos of the skyline/bottomline no intervalo of the slur
    final points = placement
        ? skylineCalculator!.getSkyLinePoints(startPoint.dx, endPoint.dx)
        : skylineCalculator!.getBottomLinePoints(startPoint.dx, endPoint.dx);

    if (points.isEmpty) return idealHeight;

    // Encontrar ponto mais extremo (mais alto for placement=true, mais baixo for false)
    double extremeY = placement ? double.infinity : double.negativeInfinity;
    for (final point in points) {
      if (placement) {
        extremeY = math.min(extremeY, point.y);
      } else {
        extremeY = math.max(extremeY, point.y);
      }
    }

    // Calculatestesr height necessária for evitar colisão
    final midPointY = (startPoint.dy + endPoint.dy) / 2;
    final clearance = rules.slurClearanceMinimum * staffSpace;

    double requiredHeight;
    if (placement) {
      // Slur acima: precisa ficar acima of the skyline
      requiredHeight = (midPointY - extremeY).abs() + clearance;
    } else {
      // Slur abaixo: precisa ficar abaixo of the bottomline
      requiredHeight = (extremeY - midPointY).abs() + clearance;
    }

    // Returnsr o greater entre height ideal e height necessária
    return math.max(idealHeight, requiredHeight);
  }

  /// Calculatestes os 4 pontos de controle de a curva Bézier cúbica
  ///
  /// Algoritmo based on OSMD e Behind Bars:
  /// - P0: ponto inicial
  /// - P1: ponto de controle inicial (tangente with ângulo limitado)
  /// - P2: ponto de controle final (tangente with ângulo limitado)
  /// - P3: ponto final
  List<Offset> _calculateBezierControlPoints(
    Offset start,
    Offset end,
    double height,
    double slopeAngle,
    bool placement,
  ) {
    // Calculatestesr comprimento horizontal e vertical
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);

    // Calculatestesr ângulos tangentes nos pontos inicial e final
    // OSMD Uses ângulos entre 30° e 80° according to Behind Bars
    final minTangentAngle = rules.slurTangentMinAngle * math.pi / 180;
    final maxTangentAngle = rules.slurTangentMaxAngle * math.pi / 180;

    // Ângulo tangente based no comprimento of the slur
    // Slurs curtos: ângulo mais íngreme
    // Slurs longos: ângulo mais suave
    final tangentAngleFactor = (length / 100.0).clamp(0.0, 1.0);
    final tangentAngle = minTangentAngle +
        (maxTangentAngle - minTangentAngle) * (1.0 - tangentAngleFactor);

    // Calculatestesr comprimento dos vetores de controle
    // OSMD Uses aproximadamente 1/3 of the comprimento total
    final controlLength = length * 0.38;

    // P0: ponto inicial
    final p0 = start;

    // P1: ponto de controle inicial
    // Direção: ângulo of the slur + ângulo tangente
    final startControlAngle = math.atan2(dy, dx) +
        (placement ? -tangentAngle : tangentAngle);
    final p1 = Offset(
      start.dx + controlLength * math.cos(startControlAngle),
      start.dy + controlLength * math.sin(startControlAngle),
    );

    // P2: ponto de controle final
    // Direção: ângulo of the slur - ângulo tangente (simétrico)
    final endControlAngle = math.atan2(dy, dx) +
        (placement ? tangentAngle : -tangentAngle);
    final p2 = Offset(
      end.dx - controlLength * math.cos(endControlAngle),
      end.dy - controlLength * math.sin(endControlAngle),
    );

    // P3: ponto final
    final p3 = end;

    return [p0, p1, p2, p3];
  }

  /// Calculatestes a tie (tie/slur de prolongamento)
  ///
  /// Ties are similares a slurs mas with regras específicas:
  /// - Always conectam notes of the mesma height
  /// - Height baseada in interpolação linear (Behind Bars)
  /// - Forma mais simétrica e previsível
  ///
  /// @param startPoint Ponto inicial of the tie
  /// @param endPoint Ponto final of the tie
  /// @param placement if true, tie acima; if false, below
  /// @param staffSpace Staff space size in pixels
  /// @return CubicBezierCurve
  CubicBezierCurve calculateTie({
    required Offset startPoint,
    required Offset endPoint,
    required bool placement,
    double staffSpace = 10.0,
  }) {
    // 1. Calculatestesr comprimento horizontal (in staff spaces)
    final horizontalLengthSS = (endPoint.dx - startPoint.dx) / staffSpace;

    // 2. Calculatestesr height using interpolação linear (Behind Bars)
    // height = k * width + d
    // With limites mínimo e máximo
    final heightSS = rules.calculateTieHeight(horizontalLengthSS);
    final heightPixels = heightSS * staffSpace;

    // 3. For ties, os pontos are always na mesma height Y
    // (diferente de slurs that podem conectar notes diferentes)
    final adjustedStart = startPoint;
    final adjustedEnd = endPoint;

    // 4. Calculatestesr pontos de controle of the Bézier
    // Ties use forma mais simétrica that slurs
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

  /// Calculatestes pontos de controle Bézier for ties (mais simétrico that slurs)
  List<Offset> _calculateTieBezierControlPoints(
    Offset start,
    Offset end,
    double height,
    bool placement,
  ) {
    final dx = end.dx - start.dx;
    // midX not used, removido for evitar warning

    // For ties, Usesr ângulo tangente Smaller (Behind Bars: ties devem ser achatados)
    final tangentAngle = 25.0 * math.pi / 180; // Reduzido de 45° para 25°

    // Comprimento dos vetores de controle: 35% of the comprimento total (reduzido)
    final controlLength = dx * 0.35; // Reduzido de 0.4 para 0.35

    // P0: ponto inicial
    final p0 = start;

    // P1: ponto de controle inicial
    final p1 = Offset(
      start.dx + controlLength,
      placement
          ? start.dy - controlLength * math.tan(tangentAngle)
          : start.dy + controlLength * math.tan(tangentAngle),
    );

    // P2: ponto de controle final (simétrico a P1)
    final p2 = Offset(
      end.dx - controlLength,
      placement
          ? end.dy - controlLength * math.tan(tangentAngle)
          : end.dy + controlLength * math.tan(tangentAngle),
    );

    // P3: ponto final
    final p3 = end;

    return [p0, p1, p2, p3];
  }

  /// Calculatestes múltiplos pontos ao longo of the curva Bézier
  ///
  /// Útil for:
  /// - Rendersção of the curva
  /// - Detecção de colisões precisa
  /// - Currentização de skyline/bottomline
  ///
  /// @param curve Curva Bézier
  /// @param numPoints Number de pontos a Generatesr (default: 20)
  /// @return List of offsets ao longo of the curva
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
  /// @param thickness Espessura of the linha of the slur in pixels
  void updateSkylineWithCurve(
    CubicBezierCurve curve, {
    required bool placement,
    double thickness = 1.5,
  }) {
    if (skylineCalculator == null) return;

    // Amostrar pontos ao longo of the curva
    final points = sampleBezierCurve(curve, numPoints: 30);

    // Currentizar skyline/bottomline for each ponto
    for (final point in points) {
      if (placement) {
        // Slur acima: currentizar skyline (subtrair espessura)
        skylineCalculator!.updateSkyLine(point.dx, point.dy - thickness / 2);
      } else {
        // Slur abaixo: currentizar bottomline (add espessura)
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

  /// Calculatestes um ponto na curva in t ∈ [0, 1]
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

  /// Calculatestes a derivada (tangente) of the curva in t ∈ [0, 1]
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

  /// Calculatestes o ângulo of the tangente in t ∈ [0, 1] (in radianos)
  double tangentAngleAt(double t) {
    final derivative = derivativeAt(t);
    return math.atan2(derivative.dy, derivative.dx);
  }

  /// Calculatestes o comprimento aproximado of the curva
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

  /// Converts for Path of the Flutter (for Rendersção)
  Path toPath() {
    final path = Path();
    path.moveTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    return path;
  }

  /// Calculatestes bounding box of the curva
  BoundingBox calculateBoundingBox() {
    // Encontrar min/max de x e y ao longo of the curva
    double minX = math.min(p0.dx, p3.dx);
    double maxX = math.max(p0.dx, p3.dx);
    double minY = math.min(p0.dy, p3.dy);
    double maxY = math.max(p0.dy, p3.dy);

    // Amostrar pontos intermediários
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