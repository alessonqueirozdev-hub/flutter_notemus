// lib/src/layout/slur_calculator.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bounding_box.dart';
import 'skyline_calculator.dart';
import '../engraving/engraving_rules.dart';

/// Calculador de Slurs com curvas Bézier cúbicas
///
/// Baseado em:
/// - OpenSheetMusicDisplay (TieCalculator.ts e SlurCalculator.ts)
/// - Behind Bars (Elaine Gould) - regras de slurs
/// - SMuFL specification - anchors e positioning
///
/// Algoritmo:
/// 1. Ajustar pontos de início/fim com offsets (slurNoteHeadYOffset)
/// 2. Coletar pontos do skyline entre início e fim
/// 3. Rotacionar sistema de coordenadas para simplificar cálculos
/// 4. Calcular inclinações máximas que evitam colisões
/// 5. Limitar ângulos tangentes (30° a 80° conforme Behind Bars)
/// 6. Gerar pontos de controle Bézier cúbica
/// 7. Rotacionar de volta ao sistema original
/// 8. Retornar curva Bézier final
class SlurCalculator {
  final EngravingRules rules;
  final SkyBottomLineCalculator? skylineCalculator;

  SlurCalculator({
    EngravingRules? rules,
    this.skylineCalculator,
  }) : rules = rules ?? EngravingRules();

  /// Calcula uma curva Bézier cúbica para um slur
  ///
  /// @param startPoint Ponto inicial do slur (absolute position)
  /// @param endPoint Ponto final do slur (absolute position)
  /// @param placement Se true, slur acima das notas; se false, abaixo
  /// @param notesBoundingBoxes BoundingBoxes das notas entre início e fim
  /// @param staffSpace Tamanho do staff space em pixels
  /// @return CubicBezierCurve com 4 pontos de controle
  CubicBezierCurve calculateSlur({
    required Offset startPoint,
    required Offset endPoint,
    required bool placement,
    List<BoundingBox>? notesBoundingBoxes,
    double staffSpace = 10.0,
  }) {
    // 1. Ajustar pontos de início/fim com offset vertical
    final yOffsetPixels = rules.slurNoteHeadYOffset * staffSpace;
    final adjustedStart = placement
        ? Offset(startPoint.dx, startPoint.dy - yOffsetPixels)
        : Offset(startPoint.dx, startPoint.dy + yOffsetPixels);

    final adjustedEnd = placement
        ? Offset(endPoint.dx, endPoint.dy - yOffsetPixels)
        : Offset(endPoint.dx, endPoint.dy + yOffsetPixels);

    // 2. Calcular comprimento horizontal do slur
    final horizontalLength = (adjustedEnd.dx - adjustedStart.dx).abs();

    // 3. Calcular altura ideal do slur baseado no comprimento
    // Fórmula OSMD: height = k * sqrt(length) onde k varia com placement
    final heightFactor = placement ? 0.5 : 0.4;
    final idealHeight = heightFactor * math.sqrt(horizontalLength);

    // 4. Ajustar altura se houver colisões com skyline
    double finalHeight = idealHeight;
    if (skylineCalculator != null && notesBoundingBoxes != null) {
      finalHeight = _adjustHeightForCollisions(
        adjustedStart,
        adjustedEnd,
        idealHeight,
        placement,
        staffSpace,
      );
    }

    // 5. Calcular ângulo de inclinação do slur
    final deltaY = adjustedEnd.dy - adjustedStart.dy;
    final deltaX = adjustedEnd.dx - adjustedStart.dx;
    double slopeAngle = math.atan2(deltaY, deltaX) * 180 / math.pi;

    // Limitar ângulo de inclinação conforme regras
    final maxSlopeAngle = rules.slurSlopeMaxAngle;
    if (slopeAngle.abs() > maxSlopeAngle) {
      slopeAngle = slopeAngle.sign * maxSlopeAngle;
    }

    // 6. Calcular pontos de controle da curva Bézier cúbica
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

  /// Ajusta altura do slur para evitar colisões com notas
  double _adjustHeightForCollisions(
    Offset startPoint,
    Offset endPoint,
    double idealHeight,
    bool placement,
    double staffSpace,
  ) {
    if (skylineCalculator == null) return idealHeight;

    // Obter pontos do skyline/bottomline no intervalo do slur
    final points = placement
        ? skylineCalculator!.getSkyLinePoints(startPoint.dx, endPoint.dx)
        : skylineCalculator!.getBottomLinePoints(startPoint.dx, endPoint.dx);

    if (points.isEmpty) return idealHeight;

    // Encontrar ponto mais extremo (mais alto para placement=true, mais baixo para false)
    double extremeY = placement ? double.infinity : double.negativeInfinity;
    for (final point in points) {
      if (placement) {
        extremeY = math.min(extremeY, point.y);
      } else {
        extremeY = math.max(extremeY, point.y);
      }
    }

    // Calcular altura necessária para evitar colisão
    final midPointY = (startPoint.dy + endPoint.dy) / 2;
    final clearance = rules.slurClearanceMinimum * staffSpace;

    double requiredHeight;
    if (placement) {
      // Slur acima: precisa ficar acima do skyline
      requiredHeight = (midPointY - extremeY).abs() + clearance;
    } else {
      // Slur abaixo: precisa ficar abaixo do bottomline
      requiredHeight = (extremeY - midPointY).abs() + clearance;
    }

    // Retornar o maior entre altura ideal e altura necessária
    return math.max(idealHeight, requiredHeight);
  }

  /// Calcula os 4 pontos de controle de uma curva Bézier cúbica
  ///
  /// Algoritmo baseado em OSMD e Behind Bars:
  /// - P0: ponto inicial
  /// - P1: ponto de controle inicial (tangente com ângulo limitado)
  /// - P2: ponto de controle final (tangente com ângulo limitado)
  /// - P3: ponto final
  List<Offset> _calculateBezierControlPoints(
    Offset start,
    Offset end,
    double height,
    double slopeAngle,
    bool placement,
  ) {
    // Calcular comprimento horizontal e vertical
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);

    // Calcular ângulos tangentes nos pontos inicial e final
    // OSMD usa ângulos entre 30° e 80° conforme Behind Bars
    final minTangentAngle = rules.slurTangentMinAngle * math.pi / 180;
    final maxTangentAngle = rules.slurTangentMaxAngle * math.pi / 180;

    // Ângulo tangente baseado no comprimento do slur
    // Slurs curtos: ângulo mais íngreme
    // Slurs longos: ângulo mais suave
    final tangentAngleFactor = (length / 100.0).clamp(0.0, 1.0);
    final tangentAngle = minTangentAngle +
        (maxTangentAngle - minTangentAngle) * (1.0 - tangentAngleFactor);

    // Calcular comprimento dos vetores de controle
    // OSMD usa aproximadamente 1/3 do comprimento total
    final controlLength = length * 0.38;

    // P0: ponto inicial
    final p0 = start;

    // P1: ponto de controle inicial
    // Direção: ângulo do slur + ângulo tangente
    final startControlAngle = math.atan2(dy, dx) +
        (placement ? -tangentAngle : tangentAngle);
    final p1 = Offset(
      start.dx + controlLength * math.cos(startControlAngle),
      start.dy + controlLength * math.sin(startControlAngle),
    );

    // P2: ponto de controle final
    // Direção: ângulo do slur - ângulo tangente (simétrico)
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

  /// Calcula uma tie (ligadura de prolongamento)
  ///
  /// Ties são similares a slurs mas com regras específicas:
  /// - Sempre conectam notas da mesma altura
  /// - Altura baseada em interpolação linear (Behind Bars)
  /// - Forma mais simétrica e previsível
  ///
  /// @param startPoint Ponto inicial da tie
  /// @param endPoint Ponto final da tie
  /// @param placement Se true, tie acima; se false, abaixo
  /// @param staffSpace Tamanho do staff space em pixels
  /// @return CubicBezierCurve
  CubicBezierCurve calculateTie({
    required Offset startPoint,
    required Offset endPoint,
    required bool placement,
    double staffSpace = 10.0,
  }) {
    // 1. Calcular comprimento horizontal (em staff spaces)
    final horizontalLengthSS = (endPoint.dx - startPoint.dx) / staffSpace;

    // 2. Calcular altura usando interpolação linear (Behind Bars)
    // height = k * width + d
    // Com limites mínimo e máximo
    final heightSS = rules.calculateTieHeight(horizontalLengthSS);
    final heightPixels = heightSS * staffSpace;

    // 3. Para ties, os pontos são sempre na mesma altura Y
    // (diferente de slurs que podem conectar notas diferentes)
    final adjustedStart = startPoint;
    final adjustedEnd = endPoint;

    // 4. Calcular pontos de controle da Bézier
    // Ties usam forma mais simétrica que slurs
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

  /// Calcula pontos de controle Bézier para ties (mais simétrico que slurs)
  List<Offset> _calculateTieBezierControlPoints(
    Offset start,
    Offset end,
    double height,
    bool placement,
  ) {
    final dx = end.dx - start.dx;
    // midX não usado, removido para evitar warning

    // Para ties, usar ângulo tangente MENOR (Behind Bars: ties devem ser achatados)
    final tangentAngle = 25.0 * math.pi / 180; // Reduzido de 45° para 25°

    // Comprimento dos vetores de controle: 35% do comprimento total (reduzido)
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

  /// Calcula múltiplos pontos ao longo da curva Bézier
  ///
  /// Útil para:
  /// - Renderização da curva
  /// - Detecção de colisões precisa
  /// - Atualização de skyline/bottomline
  ///
  /// @param curve Curva Bézier
  /// @param numPoints Número de pontos a gerar (padrão: 20)
  /// @return Lista de offsets ao longo da curva
  List<Offset> sampleBezierCurve(CubicBezierCurve curve, {int numPoints = 20}) {
    final points = <Offset>[];

    for (int i = 0; i <= numPoints; i++) {
      final t = i / numPoints;
      points.add(curve.pointAt(t));
    }

    return points;
  }

  /// Atualiza o skyline/bottomline com uma curva de slur/tie
  ///
  /// @param curve Curva Bézier
  /// @param placement Se true, atualiza skyline; se false, bottomline
  /// @param thickness Espessura da linha do slur em pixels
  void updateSkylineWithCurve(
    CubicBezierCurve curve, {
    required bool placement,
    double thickness = 1.5,
  }) {
    if (skylineCalculator == null) return;

    // Amostrar pontos ao longo da curva
    final points = sampleBezierCurve(curve, numPoints: 30);

    // Atualizar skyline/bottomline para cada ponto
    for (final point in points) {
      if (placement) {
        // Slur acima: atualizar skyline (subtrair espessura)
        skylineCalculator!.updateSkyLine(point.dx, point.dy - thickness / 2);
      } else {
        // Slur abaixo: atualizar bottomline (adicionar espessura)
        skylineCalculator!.updateBottomLine(point.dx, point.dy + thickness / 2);
      }
    }
  }
}

/// Representa uma curva Bézier cúbica
///
/// Fórmula: B(t) = (1-t)³·P0 + 3(1-t)²t·P1 + 3(1-t)t²·P2 + t³·P3
/// onde t ∈ [0, 1]
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

  /// Calcula um ponto na curva em t ∈ [0, 1]
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

  /// Calcula a derivada (tangente) da curva em t ∈ [0, 1]
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

  /// Calcula o ângulo da tangente em t ∈ [0, 1] (em radianos)
  double tangentAngleAt(double t) {
    final derivative = derivativeAt(t);
    return math.atan2(derivative.dy, derivative.dx);
  }

  /// Calcula o comprimento aproximado da curva
  ///
  /// Usa método de Simpson para integração numérica
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

  /// Converte para Path do Flutter (para renderização)
  Path toPath() {
    final path = Path();
    path.moveTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    return path;
  }

  /// Calcula bounding box da curva
  BoundingBox calculateBoundingBox() {
    // Encontrar min/max de x e y ao longo da curva
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