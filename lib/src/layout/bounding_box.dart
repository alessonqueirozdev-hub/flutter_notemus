// lib/src/layout/bounding_box.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ponto 2D para posicionamento
class PointF2D {
  double x;
  double y;

  PointF2D(this.x, this.y);

  PointF2D.zero()
      : x = 0.0,
        y = 0.0;

  /// Cria cópia do ponto
  PointF2D copy() => PointF2D(x, y);

  /// Converte para Offset
  Offset toOffset() => Offset(x, y);

  /// Cria a partir de Offset
  factory PointF2D.fromOffset(Offset offset) => PointF2D(offset.dx, offset.dy);

  /// Adiciona outro ponto
  PointF2D operator +(PointF2D other) => PointF2D(x + other.x, y + other.y);

  /// Subtrai outro ponto
  PointF2D operator -(PointF2D other) => PointF2D(x - other.x, y - other.y);

  /// Multiplica por escalar
  PointF2D operator *(double scalar) => PointF2D(x * scalar, y * scalar);

  /// Distância até outro ponto
  double distanceTo(PointF2D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Magnitude (distância da origem)
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

/// Tamanho 2D
class SizeF2D {
  double width;
  double height;

  SizeF2D(this.width, this.height);

  SizeF2D.zero()
      : width = 0.0,
        height = 0.0;

  /// Cria cópia do tamanho
  SizeF2D copy() => SizeF2D(width, height);

  /// Converte para Size
  Size toSize() => Size(width, height);

  /// Cria a partir de Size
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

/// Bounding Box Hierárquica para elementos musicais
///
/// Baseado em:
/// - OpenSheetMusicDisplay (BoundingBox.ts)
/// - Verovio (BoundingBox class com SelfBB e ContentBB)
///
/// Suporta:
/// - Hierarquia pai-filho
/// - Cálculo recursivo de posição absoluta
/// - Detecção de colisões
/// - Bordas com margem
class BoundingBox {
  // ====================
  // POSICIONAMENTO
  // ====================

  /// Posição absoluta (calculada recursivamente a partir do pai)
  PointF2D absolutePosition = PointF2D.zero();

  /// Posição relativa ao pai
  PointF2D relativePosition = PointF2D.zero();

  /// Tamanho do conteúdo
  SizeF2D size = SizeF2D.zero();

  /// Tamanho da margem
  SizeF2D marginSize = SizeF2D.zero();

  // ====================
  // BORDAS INTERNAS (CONTEÚDO)
  // ====================

  /// Borda esquerda do conteúdo (relativa à posição)
  double borderLeft = 0.0;

  /// Borda direita do conteúdo (relativa à posição)
  double borderRight = 0.0;

  /// Borda superior do conteúdo (relativa à posição)
  double borderTop = 0.0;

  /// Borda inferior do conteúdo (relativa à posição)
  double borderBottom = 0.0;

  // ====================
  // BORDAS EXTERNAS (MARGEM)
  // ====================

  /// Borda esquerda da margem (relativa à posição)
  double borderMarginLeft = 0.0;

  /// Borda direita da margem (relativa à posição)
  double borderMarginRight = 0.0;

  /// Borda superior da margem (relativa à posição)
  double borderMarginTop = 0.0;

  /// Borda inferior da margem (relativa à posição)
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

  /// Cria BoundingBox a partir de Rect
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
  // MÉTODOS DE HIERARQUIA
  // ====================

  /// Adiciona um elemento filho
  void addChild(BoundingBox child) {
    childElements.add(child);
    child.parent = this;
  }

  /// Remove um elemento filho
  void removeChild(BoundingBox child) {
    childElements.remove(child);
    child.parent = null;
  }

  /// Remove todos os filhos
  void clearChildren() {
    for (final child in childElements) {
      child.parent = null;
    }
    childElements.clear();
  }

  // ====================
  // CÁLCULO DE POSIÇÃO
  // ====================

  /// Calcula a posição absoluta recursivamente a partir dos pais
  ///
  /// Deve ser chamado após modificar posições relativas para atualizar
  /// a posição absoluta de todos os elementos na hierarquia
  void calculateAbsolutePosition() {
    absolutePosition.x = relativePosition.x;
    absolutePosition.y = relativePosition.y;

    BoundingBox? currentParent = parent;
    while (currentParent != null) {
      absolutePosition.x += currentParent.relativePosition.x;
      absolutePosition.y += currentParent.relativePosition.y;
      currentParent = currentParent.parent;
    }

    // Calcular recursivamente para todos os filhos
    for (final child in childElements) {
      child.calculateAbsolutePosition();
    }
  }

  // ====================
  // CÁLCULO DE BOUNDING BOX
  // ====================

  /// Calcula o bounding box envolvendo todos os filhos
  ///
  /// Atualiza borderLeft, borderRight, borderTop, borderBottom
  /// para englobar todos os elementos filhos
  void calculateBoundingBox() {
    if (childElements.isEmpty) {
      // Sem filhos: usar tamanho definido
      if (size.width > 0 || size.height > 0) {
        borderLeft = 0;
        borderRight = size.width;
        borderTop = 0;
        borderBottom = size.height;
      }
      return;
    }

    // Primeiro, calcular bounding box de todos os filhos
    for (final child in childElements) {
      child.calculateBoundingBox();
    }

    // Inicializar com valores extremos
    borderLeft = double.infinity;
    borderRight = double.negativeInfinity;
    borderTop = double.infinity;
    borderBottom = double.negativeInfinity;

    // Calcular envelope de todos os filhos
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

    // Atualizar tamanho
    size.width = borderRight - borderLeft;
    size.height = borderBottom - borderTop;

    // Calcular bordas de margem (adicionar margem às bordas)
    borderMarginLeft = borderLeft - marginSize.width;
    borderMarginRight = borderRight + marginSize.width;
    borderMarginTop = borderTop - marginSize.height;
    borderMarginBottom = borderBottom + marginSize.height;
  }

  // ====================
  // DETECÇÃO DE COLISÃO
  // ====================

  /// Verifica se há sobreposição horizontal com outro BoundingBox
  ///
  /// @param other Outro BoundingBox
  /// @param margin Margem adicional para a verificação
  /// @return true se houver sobreposição
  bool horizontalOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisLeft = absolutePosition.x + borderLeft - margin;
    final thisRight = absolutePosition.x + borderRight + margin;
    final otherLeft = other.absolutePosition.x + other.borderLeft;
    final otherRight = other.absolutePosition.x + other.borderRight;

    return !(thisRight < otherLeft || thisLeft > otherRight);
  }

  /// Verifica se há sobreposição vertical com outro BoundingBox
  ///
  /// @param other Outro BoundingBox
  /// @param margin Margem adicional para a verificação
  /// @return true se houver sobreposição
  bool verticalOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisTop = absolutePosition.y + borderTop - margin;
    final thisBottom = absolutePosition.y + borderBottom + margin;
    final otherTop = other.absolutePosition.y + other.borderTop;
    final otherBottom = other.absolutePosition.y + other.borderBottom;

    return !(thisBottom < otherTop || thisTop > otherBottom);
  }

  /// Verifica se há colisão (sobreposição horizontal E vertical)
  ///
  /// @param other Outro BoundingBox
  /// @param margin Margem adicional para a verificação
  /// @return true se houver colisão
  bool collidesWith(BoundingBox other, {double margin = 0.0}) {
    return horizontalOverlap(other, margin: margin) &&
        verticalOverlap(other, margin: margin);
  }

  /// Verifica se há sobreposição horizontal com margem
  ///
  /// @param other Outro BoundingBox
  /// @param margin Margem adicional
  /// @return true se houver sobreposição considerando margem
  bool horizontalMarginOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisLeft = absolutePosition.x + borderMarginLeft - margin;
    final thisRight = absolutePosition.x + borderMarginRight + margin;
    final otherLeft = other.absolutePosition.x + other.borderMarginLeft;
    final otherRight = other.absolutePosition.x + other.borderMarginRight;

    return !(thisRight < otherLeft || thisLeft > otherRight);
  }

  /// Verifica se há sobreposição vertical com margem
  ///
  /// @param other Outro BoundingBox
  /// @param margin Margem adicional
  /// @return true se houver sobreposição considerando margem
  bool verticalMarginOverlap(BoundingBox other, {double margin = 0.0}) {
    final thisTop = absolutePosition.y + borderMarginTop - margin;
    final thisBottom = absolutePosition.y + borderMarginBottom + margin;
    final otherTop = other.absolutePosition.y + other.borderMarginTop;
    final otherBottom = other.absolutePosition.y + other.borderMarginBottom;

    return !(thisBottom < otherTop || thisTop > otherBottom);
  }

  /// Calcula distância horizontal até outro BoundingBox
  ///
  /// @param other Outro BoundingBox
  /// @return Distância horizontal (negativa se sobreposto)
  double horizontalDistanceTo(BoundingBox other) {
    final thisRight = absolutePosition.x + borderRight;
    final otherLeft = other.absolutePosition.x + other.borderLeft;

    if (horizontalOverlap(other)) {
      // Sobreposto: retornar distância negativa
      final thisLeft = absolutePosition.x + borderLeft;
      final otherRight = other.absolutePosition.x + other.borderRight;
      return math.max(thisLeft - otherRight, otherLeft - thisRight);
    }

    return otherLeft - thisRight;
  }

  /// Calcula distância vertical até outro BoundingBox
  ///
  /// @param other Outro BoundingBox
  /// @return Distância vertical (negativa se sobreposto)
  double verticalDistanceTo(BoundingBox other) {
    final thisBottom = absolutePosition.y + borderBottom;
    final otherTop = other.absolutePosition.y + other.borderTop;

    if (verticalOverlap(other)) {
      // Sobreposto: retornar distância negativa
      final thisTop = absolutePosition.y + borderTop;
      final otherBottom = other.absolutePosition.y + other.borderBottom;
      return math.max(thisTop - otherBottom, otherTop - thisBottom);
    }

    return otherTop - thisBottom;
  }

  // ====================
  // PROPRIEDADES CALCULADAS
  // ====================

  /// Largura total do conteúdo
  double get width => borderRight - borderLeft;

  /// Altura total do conteúdo
  double get height => borderBottom - borderTop;

  /// Largura total com margem
  double get widthWithMargin => borderMarginRight - borderMarginLeft;

  /// Altura total com margem
  double get heightWithMargin => borderMarginBottom - borderMarginTop;

  /// Centro X (relativo)
  double get centerX => (borderLeft + borderRight) / 2;

  /// Centro Y (relativo)
  double get centerY => (borderTop + borderBottom) / 2;

  /// Centro absoluto
  PointF2D get absoluteCenter => PointF2D(
        absolutePosition.x + centerX,
        absolutePosition.y + centerY,
      );

  /// Converte para Rect (absoluto)
  Rect toRect() {
    return Rect.fromLTRB(
      absolutePosition.x + borderLeft,
      absolutePosition.y + borderTop,
      absolutePosition.x + borderRight,
      absolutePosition.y + borderBottom,
    );
  }

  /// Converte para Rect com margem (absoluto)
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

  /// Define o bounding box a partir de um Rect
  void setFromRect(Rect rect) {
    borderLeft = rect.left;
    borderRight = rect.right;
    borderTop = rect.top;
    borderBottom = rect.bottom;
    size.width = rect.width;
    size.height = rect.height;
  }

  /// Define margem uniforme
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