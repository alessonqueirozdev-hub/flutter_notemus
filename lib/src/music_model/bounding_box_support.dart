// lib/src/music_model/bounding_box_support.dart

import '../layout/bounding_box.dart';

/// Mixin que adiciona suporte a BoundingBox hierárquico para elementos musicais
///
/// Este mixin pode ser aplicado a qualquer MusicalElement para que ele possa
/// armazenar e gerenciar seu BoundingBox hierárquico.
///
/// PADRÃO: Mixin Pattern
///
/// Uso:
/// ```dart
/// class Note extends MusicalElement with BoundingBoxSupport {
///   // ...
/// }
/// ```
mixin BoundingBoxSupport {
  /// BoundingBox hierárquico associado a este elemento
  ///
  /// Este é preenchido durante o processo de layout e atualizado
  /// durante a renderização. Pode ser null se o layout ainda não
  /// foi executado.
  BoundingBox? _boundingBox;

  /// Obtém o BoundingBox hierárquico deste elemento
  BoundingBox? get boundingBox => _boundingBox;

  /// Define o BoundingBox hierárquico deste elemento
  set boundingBox(BoundingBox? bbox) => _boundingBox = bbox;

  /// Verifica se este elemento tem um BoundingBox hierárquico válido
  bool get hasBoundingBox => _boundingBox != null;

  /// Cria e retorna um novo BoundingBox hierárquico para este elemento
  ///
  /// Se já existe um BoundingBox, retorna o existente.
  /// Caso contrário, cria um novo e o armazena.
  ///
  /// @return BoundingBox hierárquico (novo ou existente)
  BoundingBox getOrCreateBoundingBox() {
    _boundingBox ??= BoundingBox();
    return _boundingBox!;
  }

  /// Limpa o BoundingBox hierárquico deste elemento
  ///
  /// Remove todos os filhos e define como null.
  /// Útil para recalcular layout do zero.
  void clearBoundingBox() {
    if (_boundingBox != null) {
      _boundingBox!.clearChildren();
      _boundingBox = null;
    }
  }

  /// Atualiza a posição relativa do BoundingBox
  ///
  /// Conveniência para definir posição sem acessar boundingBox diretamente.
  ///
  /// @param x Posição X relativa ao pai
  /// @param y Posição Y relativa ao pai
  void setBoundingBoxPosition(double x, double y) {
    if (_boundingBox != null) {
      _boundingBox!.relativePosition = PointF2D(x, y);
    }
  }

  /// Atualiza o tamanho do BoundingBox
  ///
  /// Conveniência para definir tamanho sem acessar boundingBox diretamente.
  ///
  /// @param width Largura
  /// @param height Altura
  void setBoundingBoxSize(double width, double height) {
    if (_boundingBox != null) {
      _boundingBox!.size = SizeF2D(width, height);
    }
  }

  /// Recalcula recursivamente as posições absolutas do BoundingBox
  ///
  /// Deve ser chamado após modificar posições relativas na hierarquia.
  void updateBoundingBoxPositions() {
    if (_boundingBox != null) {
      _boundingBox!.calculateAbsolutePosition();
    }
  }

  /// Recalcula recursivamente os bounds do BoundingBox
  ///
  /// Deve ser chamado após modificar tamanhos ou adicionar/remover filhos.
  void updateBoundingBoxBounds() {
    if (_boundingBox != null) {
      _boundingBox!.calculateBoundingBox();
    }
  }

  /// Adiciona um filho ao BoundingBox hierárquico deste elemento
  ///
  /// Útil para construir hierarquia durante renderização.
  ///
  /// @param childBBox BoundingBox do elemento filho
  void addBoundingBoxChild(BoundingBox childBBox) {
    if (_boundingBox != null) {
      _boundingBox!.addChild(childBBox);
    }
  }
}

/// Extension para facilitar uso de BoundingBoxSupport em listas
extension BoundingBoxSupportList on List {
  /// Atualiza posições de todos os elementos que têm BoundingBoxSupport
  void updateAllBoundingBoxPositions() {
    for (final element in this) {
      if (element is BoundingBoxSupport) {
        element.updateBoundingBoxPositions();
      }
    }
  }

  /// Atualiza bounds de todos os elementos que têm BoundingBoxSupport
  void updateAllBoundingBoxBounds() {
    for (final element in this) {
      if (element is BoundingBoxSupport) {
        element.updateBoundingBoxBounds();
      }
    }
  }

  /// Limpa BoundingBoxes de todos os elementos
  void clearAllBoundingBoxes() {
    for (final element in this) {
      if (element is BoundingBoxSupport) {
        element.clearBoundingBox();
      }
    }
  }
}
