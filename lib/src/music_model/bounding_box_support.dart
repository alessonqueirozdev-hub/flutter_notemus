// lib/src/music_model/bounding_box_support.dart

import '../layout/bounding_box.dart';

/// Mixin that Adds suporte a Hierarchical BoundingBox for elementos musicais
///
/// This mixin pode ser Appliesdo a any MusicalElement for that it possa
/// armazenar e gerenciar its Hierarchical BoundingBox.
///
/// Default: Mixin Pattern
///
/// Uso:
/// ```dart
/// class Note extends MusicalElement with BoundingBoxSupport {
///   // ...
/// }
/// ```
mixin BoundingBoxSupport {
  /// Hierarchical BoundingBox associado a this elemento
  ///
  /// This é preenchido durante o processo de layout e currentizado
  /// durante a Rendersção. Pode ser null se o layout still not
  /// foi executado.
  BoundingBox? _boundingBox;

  /// Gets o Hierarchical BoundingBox deste elemento
  BoundingBox? get boundingBox => _boundingBox;

  /// Definess o Hierarchical BoundingBox deste elemento
  set boundingBox(BoundingBox? bbox) => _boundingBox = bbox;

  /// Checks se this elemento tem um Hierarchical BoundingBox válido
  bool get hasBoundingBox => _boundingBox != null;

  /// Creates e Returns um new Hierarchical BoundingBox for this elemento
  ///
  /// Se já existe um BoundingBox, Returns o existente.
  /// Caso contrário, Creates um new e o armazena.
  ///
  /// @return Hierarchical BoundingBox (new ou existente)
  BoundingBox getOrCreateBoundingBox() {
    _boundingBox ??= BoundingBox();
    return _boundingBox!;
  }

  /// Limpa o Hierarchical BoundingBox deste elemento
  ///
  /// Remove all os filhos e Definess como null.
  /// Útil for reCalculatestesr layout of the zero.
  void clearBoundingBox() {
    if (_boundingBox != null) {
      _boundingBox!.clearChildren();
      _boundingBox = null;
    }
  }

  /// Currentiza a position relativa of the BoundingBox
  ///
  /// Conveniência for Define position sem acessar boundingBox diretamente.
  ///
  /// @param x X position relative to parent
  /// @param y Y position relative to parent
  void setBoundingBoxPosition(double x, double y) {
    if (_boundingBox != null) {
      _boundingBox!.relativePosition = PointF2D(x, y);
    }
  }

  /// Currentiza o Size of the BoundingBox
  ///
  /// Conveniência for Define size sem acessar boundingBox diretamente.
  ///
  /// @param width Width
  /// @param height Height
  void setBoundingBoxSize(double width, double height) {
    if (_boundingBox != null) {
      _boundingBox!.size = SizeF2D(width, height);
    }
  }

  /// ReCalculatestes recursivamente as positions absolutas of the BoundingBox
  ///
  /// Deve ser chamado após modificar positions relativas na hierarquia.
  void updateBoundingBoxPositions() {
    if (_boundingBox != null) {
      _boundingBox!.calculateAbsolutePosition();
    }
  }

  /// ReCalculatestes recursivamente os bounds of the BoundingBox
  ///
  /// Deve ser chamado após modificar sizes ou add/remover filhos.
  void updateBoundingBoxBounds() {
    if (_boundingBox != null) {
      _boundingBox!.calculateBoundingBox();
    }
  }

  /// Adds um filho ao Hierarchical BoundingBox deste elemento
  ///
  /// Útil for construir hierarquia durante Rendersção.
  ///
  /// @param childBBox BoundingBox of the element filho
  void addBoundingBoxChild(BoundingBox childBBox) {
    if (_boundingBox != null) {
      _boundingBox!.addChild(childBBox);
    }
  }
}

/// Extension for facilitar uso de BoundingBoxSupport in listas
extension BoundingBoxSupportList on List {
  /// Currentiza positions de all os elementos that têm BoundingBoxSupport
  void updateAllBoundingBoxPositions() {
    for (final element in this) {
      if (element is BoundingBoxSupport) {
        element.updateBoundingBoxPositions();
      }
    }
  }

  /// Currentiza bounds de all os elementos that têm BoundingBoxSupport
  void updateAllBoundingBoxBounds() {
    for (final element in this) {
      if (element is BoundingBoxSupport) {
        element.updateBoundingBoxBounds();
      }
    }
  }

  /// Limpa BoundingBoxes de all os elementos
  void clearAllBoundingBoxes() {
    for (final element in this) {
      if (element is BoundingBoxSupport) {
        element.clearBoundingBox();
      }
    }
  }
}
