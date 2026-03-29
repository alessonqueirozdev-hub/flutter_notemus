// lib/src/layout/bounding_box.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Point 2D for posicionamento
class PointF2D {
  double x;
  double y;

  PointF2D(this.x, this.y);

  PointF2D.zero()
      : x = 0.0,
        y = 0.0;

  /// Creates cópia of the point
  PointF2D copy() => PointF2D(x, y);

  /// Converts for Offset
  Offset toOffset() => Offset(x, y);

  /// Creates from Offset
  factory PointF2D.fromOffset(Offset offset) => PointF2D(offset.dx, offset.dy);

  /// Adds other point
  PointF2D operator +(PointF2D other) => PointF2D(x + other.x, y + other.y);

  /// Subtrai other point
  PointF2D operator -(PointF2D other) => PointF2D(x - other.x, y - other.y);

  /// Multiplica by escalar
  PointF2D operator *(double scalar) => PointF2D(x * scalar, y * scalar);

  /// Distance until other point
  double distanceTo(PointF2D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Magnitude (distance of the origem)
  double get magnitude => math.sqrt(x * x + y * y);

  @override
  String toString() => 'PointF2D($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PointF2D &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Size 2D
class SizeF2D {
  double width;
  double height;

  SizeF2D(this.width, this.height);

  SizeF2D.zero()
      : width = 0.0,
        height = 0.0;

  /// Creates cópia of the size
  SizeF2D copy() => SizeF2D(width, height);

  /// Converts for Size
  Size toSize() => Size(width, height);

  /// Creates from Size
  factory SizeF2D.fromSize(Size size) => SizeF2D(size.width, size.height);

  @override
  String toString() => 'SizeF2D($width, $height)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeF2D &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

/// Bounding Box Hierárquica for elementos musicais
///
/// Based on:
/// - OpenSheetMusicDisplay (BoundingBox.ts)
/// - Verovio (BoundingBox class with SelfBB and ContentBB)
///
/// Suporta:
/// - Hierarquia pai-filho
/// - Calculation recursivo de position absoluta
/// - Detecção de colisões
/// - Bordas with margin
class BoundingBox {
  // ====================
  // POSICIONAMENTO
  // ====================

  /// Position absoluta (Calculated recursivamente a partir of the pai)
  PointF2D absolutePosition = PointF2D.zero();

  /// Position relativa to the pai
  PointF2D relativePosition = PointF2D.zero();

  /// Size of the content
  SizeF2D size = SizeF2D.zero();

  /// Size of the margin
  SizeF2D marginSize = SizeF2D.zero();

  // ====================
  // BORDAS INTERNAS (Content)
  // ====================

  /// Borda left of the content (relativa to the position)
  double borderLeft = 0.0;

  /// Borda right of the content (relativa to the position)
  double borderRight = 0.0;

  /// Borda upper of the content (relativa to the position)
  double borderTop = 0.0;

  /// Borda lower of the content (relativa to the position)
  double borderBottom = 0.0;

  // ====================
  // BORDAS EXTERNAS (Margin)
  // ====================

  /// Borda left of the margin (relativa to the position)
  double borderMarginLeft = 0.0;

  /// Borda right of the margin (relativa to the position)
  double borderMarginRight = 0.0;

  /// Borda upper of the margin (relativa to the position)
  double borderMarginTop = 0.0;

  /// Borda lower of the margin (relativa to the position)
  double borderMarginBottom = 0.0;

  // ====================
  // HIERARQUIA
  // ====================

  /// Elementos filhos
  final List<BoundingBox> childElements = [];

  /// Elemento pai
  BoundingBox? parent;

  // ====================
  // CONSTRUTORES
  // ====================

  BoundingBox();

  /// Creates BoundingBox from Rect
  factory BoundingBox.fromRect(Rect rect) {
    final box = BoundingBox();
    box.relativePosition = PointF2D(rect.left, rect.top);
    box.size = SizeF2D(rect.width, rect.height);
    box.borderLeft = 0;
    box.borderRight = rect.width;
    box.borderTop = 0;
    box.borderBottom = rect.height;
    return box;
  }

  // ====================
  // MethodS DE HIERARQUIA
  // ====================

  /// Adds a elemento filho
  void addChild(BoundingBox child) {
    childElements.add(child);
    child.parent = this;
  }

  /// Remove a elemento filho
  void removeChild(BoundingBox child) {
    childElements.remove(child);
    child.parent = null;
  }

  /// Remove all os filhos
  void clearChildren() {
    for (final child in childElements) {
      child.parent = null;
    }
    childElements.clear();
  }

  // ====================
  // Calculation DE Position
  // ====================

  /// Calculates a position absoluta recursivamente a partir dos pais
  ///
  /// Must be chamado after modificar positions relativas for currentizar
  /// a position absoluta de all os elementos na hierarquia
  void calculateAbsolutePosition() {
    absolutePosition.x = relativePosition.x;
    absolutePosition.y = relativePosition.y;

    BoundingBox? currentParent = parent;
    while (currentParent != null) {
      absolutePosition.x += currentParent.relativePosition.x;
      absolutePosition.y += currentParent.relativePosition.y;
      currentParent = currentParent.parent;
    }

    // Calculate recursivamente for all os filhos
    for (final child in childElements) {
      child.calculateAbsolutePosition();
    }
  }

  // ====================
  // Calculation DE BOUNDING BOX
  // ====================

  /// Calculates o bounding box envolvendo all os filhos
  ///
  /// Currentiza borderLeft, borderRight, borderTop, borderBottom
  /// for englobar all os elementos filhos
  void calculateBoundingBox() {
    if (childElements.isEmpty) {
      // Sem filhos: Use size defined
      if (size.width > 0 || size.height > 0) {
        borderLeft = 0;
        borderRight = size.width;
        borderTop = 0;
        borderBottom = size.height;
      }
      return;
    }

    // First, Calculate bounding box de all os filhos
    for (final child in childElements) {
      child.calculateBoundingBox();
    }

    // Initialise with valores extremos
    borderLeft = double.infinity;
    borderRight = double.negativeInfinity;
    borderTop = double.infinity;
    borderBottom = double.negativeInfinity;

    // Calculate envelope de all os filhos
    for (final child in childElements) {
      final childLeft = child.borderLeft + child.relativePosition.x;
      final childRight = child.borderRight + child.relativePosition.x;
      final childTop = child.borderTop + child.relativePosition.y;
      final childBottom = child.borderBottom + child.relativePosition.y;

      borderLeft = math.min(borderLeft, childLeft);
      borderRight = math.max(borderRight, childRight);
      borderTop = math.min(borderTop, childTop);
      borderBottom = math.max(borderBottom, childBottom);
    }

    // Currentizar size
    size.width = borderRight - borderLeft;
    size.height = borderBottom - borderTop;

    // Calculate bordas de margin (add margin às bordas)
    borderMarginLeft = borderLeft - marginSize.width;
    borderMarginRight = borderRight + marginSize.width;
    borderMarginTop = borderTop - marginSize.height;
    borderMarginBottom = borderBottom + marginSize.height;
  }

  // ====================
  // DETECÇÃO DE COLISÃO
  // ====================

  /// Checks if há sobreposition horizontal with The other BoundingBox
  ///
  /// @param other The other BoundingBox
  /// @param margin Margin added for the collision check
  /// @return true if houver sobreposition
  bool horizontalOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisLeft = absolutePosition.x + borderLeft - margin;
    final thisRight = absolutePosition.x + borderRight + margin;
    final otherLeft = other.absolutePosition.x + other.borderLeft;
    final otherRight = other.absolutePosition.x + other.borderRight;

    return !(thisRight < otherLeft || thisLeft > otherRight);
  }

  /// Checks if há sobreposition vertical with The other BoundingBox
  ///
  /// @param other The other BoundingBox
  /// @param margin Margin added for the collision check
  /// @return true if houver sobreposition
  bool verticalOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisTop = absolutePosition.y + borderTop - margin;
    final thisBottom = absolutePosition.y + borderBottom + margin;
    final otherTop = other.absolutePosition.y + other.borderTop;
    final otherBottom = other.absolutePosition.y + other.borderBottom;

    return !(thisBottom < otherTop || thisTop > otherBottom);
  }

  /// Checks if há colisão (sobreposition horizontal And vertical)
  ///
  /// @param other The other BoundingBox
  /// @param margin Margin added for the collision check
  /// @return true if houver colisão
  bool collidesWith(BoundingBox other, {double margin = 0.0}) {
    return horizontalOverlap(other, margin: margin) &&
        verticalOverlap(other, margin: margin);
  }

  /// Checks if há sobreposition horizontal with margin
  ///
  /// @param other The other BoundingBox
  /// @param margin Margin added
  /// @return true if houver sobreposition considerando margin
  bool horizontalMarginOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisLeft = absolutePosition.x + borderMarginLeft - margin;
    final thisRight = absolutePosition.x + borderMarginRight + margin;
    final otherLeft = other.absolutePosition.x + other.borderMarginLeft;
    final otherRight = other.absolutePosition.x + other.borderMarginRight;

    return !(thisRight < otherLeft || thisLeft > otherRight);
  }

  /// Checks if há sobreposition vertical with margin
  ///
  /// @param other The other BoundingBox
  /// @param margin Margin added
  /// @return true if houver sobreposition considerando margin
  bool verticalMarginOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisTop = absolutePosition.y + borderMarginTop - margin;
    final thisBottom = absolutePosition.y + borderMarginBottom + margin;
    final otherTop = other.absolutePosition.y + other.borderMarginTop;
    final otherBottom = other.absolutePosition.y + other.borderMarginBottom;

    return !(thisBottom < otherTop || thisTop > otherBottom);
  }

  /// Calculates distance horizontal until The other BoundingBox
  ///
  /// @param other The other BoundingBox
  /// @return Distance horizontal (negativa if overlapping)
  double horizontalDistanceTo(BoundingBox other) {
    final thisRight = absolutePosition.x + borderRight;
    final otherLeft = other.absolutePosition.x + other.borderLeft;

    if (horizontalOverlap(other)) {
      // Overlapping: Returnsr distance negativa
      final thisLeft = absolutePosition.x + borderLeft;
      final otherRight = other.absolutePosition.x + other.borderRight;
      return math.max(thisLeft - otherRight, otherLeft - thisRight);
    }

    return otherLeft - thisRight;
  }

  /// Calculates distance vertical until The other BoundingBox
  ///
  /// @param other The other BoundingBox
  /// @return Distance vertical (negativa if overlapping)
  double verticalDistanceTo(BoundingBox other) {
    final thisBottom = absolutePosition.y + borderBottom;
    final otherTop = other.absolutePosition.y + other.borderTop;

    if (verticalOverlap(other)) {
      // Overlapping: Returnsr distance negativa
      final thisTop = absolutePosition.y + borderTop;
      final otherBottom = other.absolutePosition.y + other.borderBottom;
      return math.max(thisTop - otherBottom, otherTop - thisBottom);
    }

    return otherTop - thisBottom;
  }

  // ====================
  // PropertyS Calculated
  // ====================

  /// Width total of the content
  double get width => borderRight - borderLeft;

  /// Height total of the content
  double get height => borderBottom - borderTop;

  /// Width total with margin
  double get widthWithMargin => borderMarginRight - borderMarginLeft;

  /// Height total with margin
  double get heightWithMargin => borderMarginBottom - borderMarginTop;

  /// Centre X (relativo)
  double get centerX => (borderLeft + borderRight) / 2;

  /// Centre Y (relativo)
  double get centerY => (borderTop + borderBottom) / 2;

  /// Centre absoluto
  PointF2D get absoluteCenter => PointF2D(
        absolutePosition.x + centerX,
        absolutePosition.y + centerY,
      );

  /// Converts for Rect (absoluto)
  Rect toRect() {
    return Rect.fromLTRB(
      absolutePosition.x + borderLeft,
      absolutePosition.y + borderTop,
      absolutePosition.x + borderRight,
      absolutePosition.y + borderBottom,
    );
  }

  /// Converts for Rect with margin (absoluto)
  Rect toRectWithMargin() {
    return Rect.fromLTRB(
      absolutePosition.x + borderMarginLeft,
      absolutePosition.y + borderMarginTop,
      absolutePosition.x + borderMarginRight,
      absolutePosition.y + borderMarginBottom,
    );
  }

  // ====================
  // UTILITÁRIOS
  // ====================

  /// Definess o bounding box from a Rect
  void setFromRect(Rect rect) {
    borderLeft = rect.left;
    borderRight = rect.right;
    borderTop = rect.top;
    borderBottom = rect.bottom;
    size.width = rect.width;
    size.height = rect.height;
  }

  /// Definess margin uniforme
  void setUniformMargin(double margin) {
    marginSize.width = margin;
    marginSize.height = margin;
    borderMarginLeft = borderLeft - margin;
    borderMarginRight = borderRight + margin;
    borderMarginTop = borderTop - margin;
    borderMarginBottom = borderBottom + margin;
  }

  @override
  String toString() {
    return 'BoundingBox(pos: $relativePosition, '
        'size: ${size.width}x${size.height}, '
        'borders: L:$borderLeft R:$borderRight T:$borderTop B:$borderBottom)';
  }
}