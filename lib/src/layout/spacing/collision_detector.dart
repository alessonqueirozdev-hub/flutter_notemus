/// System de detecção de colisões entre símbolos musicais
/// 
/// Implementa algoritmos eficientes for detectar sobrepositions
/// e Calculatestesr separações mínimas entre elementos.
library;

import 'dart:math';
import 'package:flutter/rendering.dart';

/// Ponto de colisão with peso de importância
class CollisionPoint {
  final Offset position;
  final double weight; // 0.0 - 1.0 (importância)

  const CollisionPoint(this.position, {this.weight = 1.0});

  double distanceTo(CollisionPoint other) {
    return (position - other.position).distance;
  }
}

/// Detector de colisões entre símbolos musicais
class CollisionDetector {
  /// Distância mínima de segurança (in pixels)
  final double minSafeDistance;

  const CollisionDetector({this.minSafeDistance = 2.0});

  /// Checks se dois retângulos colidem
  bool checkCollision(Rect box1, Rect box2) {
    return box1.overlaps(box2);
  }

  /// Checks colisão with margem de segurança
  bool checkCollisionWithMargin(Rect box1, Rect box2, double margin) {
    final expanded1 = box1.inflate(margin);
    return expanded1.overlaps(box2);
  }

  /// Calculatestes a separação mínima necessária entre dois retângulos
  /// 
  /// Returns 0 se já estão separados suficientemente
  double calculateMinimumSeparation(Rect leftBox, Rect rightBox) {
    // Se not há sobreposition vertical, not precisam ser separados
    if (leftBox.bottom < rightBox.top || leftBox.top > rightBox.bottom) {
      return 0.0;
    }

    // Calculatestesr sobreposition horizontal
    final double leftEdge = leftBox.right;
    final double rightEdge = rightBox.left;
    final double gap = rightEdge - leftEdge;

    if (gap >= minSafeDistance) {
      return 0.0; // Já estão suficientemente separados
    }

    return minSafeDistance - gap;
  }

  /// Calculatestes separação mínima using pontos de colisão (mais preciso)
  double calculateMinimumSeparationFromPoints(
    List<CollisionPoint> leftPoints,
    List<CollisionPoint> rightPoints,
  ) {
    double minGap = double.infinity;

    for (final leftPoint in leftPoints) {
      for (final rightPoint in rightPoints) {
        final gap = rightPoint.position.dx - leftPoint.position.dx;
        
        // Considerar apenas se há sobreposition vertical
        final verticalDistance = (rightPoint.position.dy - leftPoint.position.dy).abs();
        if (verticalDistance < 10.0) { // Threshold vertical
          minGap = min(minGap, gap);
        }
      }
    }

    if (minGap == double.infinity || minGap >= minSafeDistance) {
      return 0.0;
    }

    return minSafeDistance - minGap;
  }

  /// Detecta all as colisões in a list of retângulos
  /// 
  /// Returns list of pares de indexs that colidem
  List<CollisionPair> detectAllCollisions(List<Rect> boxes) {
    final List<CollisionPair> collisions = [];

    for (int i = 0; i < boxes.length - 1; i++) {
      for (int j = i + 1; j < boxes.length; j++) {
        if (checkCollision(boxes[i], boxes[j])) {
          collisions.add(CollisionPair(i, j, calculateOverlap(boxes[i], boxes[j])));
        }
      }
    }

    return collisions;
  }

  /// Calculatestes a área de sobreposition entre dois retângulos
  double calculateOverlap(Rect box1, Rect box2) {
    final intersection = box1.intersect(box2);
    if (intersection.isEmpty) return 0.0;
    return intersection.width * intersection.height;
  }

  /// Algoritmo de sweep line for detecção eficiente
  /// 
  /// Complexidade: O(n log n) ao invés de O(n²)
  List<CollisionPair> detectCollisionsSweepLine(List<SymbolBounds> symbols) {
    final List<CollisionPair> collisions = [];
    
    // Ordenar por coordenada X inicial
    final sorted = List<SymbolBounds>.from(symbols);
    sorted.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    // List of símbolos ativos (still podem colidir)
    final List<SymbolBounds> active = [];

    for (int i = 0; i < sorted.length; i++) {
      final current = sorted[i];

      // Remover símbolos that já passaram
      active.removeWhere((symbol) => symbol.bounds.right < current.bounds.left);

      // Checksr colisão with símbolos ativos
      for (final activeSymbol in active) {
        if (checkCollision(current.bounds, activeSymbol.bounds)) {
          collisions.add(CollisionPair(
            current.index,
            activeSymbol.index,
            calculateOverlap(current.bounds, activeSymbol.bounds),
          ));
        }
      }

      active.add(current);
    }

    return collisions;
  }
}

/// Par de indexs that colidem
class CollisionPair {
  final int index1;
  final int index2;
  final double overlapArea;

  const CollisionPair(this.index1, this.index2, this.overlapArea);

  @override
  String toString() {
    return 'CollisionPair($index1, $index2, overlap: ${overlapArea.toStringAsFixed(2)})';
  }
}

/// Bounds de um símbolo with index
class SymbolBounds {
  final int index;
  final Rect bounds;

  const SymbolBounds(this.index, this.bounds);
}
