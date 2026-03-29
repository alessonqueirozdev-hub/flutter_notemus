// lib/src/layout/bounding_box_adapter.dart

import 'package:flutter/material.dart';

import '../../core/core.dart'; // 🆕 Tipos do core
import 'bounding_box.dart';
import 'collision_detector.dart' as collision;

/// Adapter for integração entre Hierarchical BoundingBox e system de colisão
///
/// This adapter permite:
/// 1. Convertsr Hierarchical BoundingBox for BoundingBox simples (Collisiwheretector)
/// 2. Registrar hierarquia no Collisiwheretector
/// 3. Manter compatibilidade with código existente
///
/// Default: Adapter Pattern
class BoundingBoxAdapter {
  /// Converts Hierarchical BoundingBox for BoundingBox simples of the Collisiwheretector
  ///
  /// @param hierarchical Hierarchical BoundingBox
  /// @param element Associated musical element
  /// @param elementType Element type for collision detection
  /// @return BoundingBox simples compatível with Collisiwheretector
  static collision.BoundingBox toCollisionBoundingBox(
    BoundingBox hierarchical,
    MusicalElement element,
    String elementType,
  ) {
    // Garantir that positions estão currentizadas
    hierarchical.calculateAbsolutePosition();
    hierarchical.calculateBoundingBox();

    // Createsr Rect a partir das bordas Calculatestesdas
    final rect = Rect.fromLTRB(
      hierarchical.absolutePosition.x + hierarchical.borderLeft,
      hierarchical.absolutePosition.y + hierarchical.borderTop,
      hierarchical.absolutePosition.x + hierarchical.borderRight,
      hierarchical.absolutePosition.y + hierarchical.borderBottom,
    );

    return collision.BoundingBox(
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      element: element,
      elementType: elementType,
    );
  }

  /// Registra Hierarchical BoundingBox e all their filhos no Collisiwheretector
  ///
  /// Percorre recursivamente a hierarquia e registra each elemento
  ///
  /// @param hierarchical Hierarchical BoundingBox raiz
  /// @param element Associated musical element ao bbox raiz
  /// @param elementType Type of the element
  /// @param detector Collisiwheretector where registrar
  /// @param registerChildren if true, registra filhos recursivamente
  static void registerInCollisionDetector(
    BoundingBox hierarchical,
    MusicalElement element,
    String elementType,
    collision.CollisionDetector detector, {
    bool registerChildren = true,
  }) {
    // Currentizar hierarquia antes de registrar
    hierarchical.calculateAbsolutePosition();
    hierarchical.calculateBoundingBox();

    // Registrar elemento raiz
    final simpleBBox = toCollisionBoundingBox(
      hierarchical,
      element,
      elementType,
    );

    detector.register(
      id: element.hashCode.toString(),
      bounds: Rect.fromLTWH(
        simpleBBox.position.dx,
        simpleBBox.position.dy,
        simpleBBox.width,
        simpleBBox.height,
      ),
      category: _stringToCollisionCategory(elementType),
      priority: _stringToCollisionPriority(_elementTypeToPriority(elementType)),
    );

    // Registrar filhos recursivamente (se solicitado)
    if (registerChildren) {
      for (int i = 0; i < hierarchical.childElements.length; i++) {
        final child = hierarchical.childElements[i];
        final childType = '$elementType.child$i';

        // Recursão for registrar toda a subárvore
        registerInCollisionDetector(
          child,
          element, // Mantém referência ao elemento musical principal
          childType,
          detector,
          registerChildren: true,
        );
      }
    }
  }

  /// Creates Hierarchical BoundingBox from GlyphInfo SMuFL
  ///
  /// @param glyphBBox Bounding box of the glifo (of the metadata SMuFL)
  /// @param staffSpace Staff space size for conversão
  /// @return Hierarchical BoundingBox Configuresdo
  static BoundingBox fromSmuflGlyphBBox(
    SmuflBoundingBox glyphBBox,
    double staffSpace,
  ) {
    final bbox = BoundingBox();

    // Convertsr coordenadas SMuFL (staff spaces) for pixels
    bbox.borderLeft = glyphBBox.bBoxSwX * staffSpace;
    bbox.borderRight = glyphBBox.bBoxNeX * staffSpace;
    bbox.borderTop = glyphBBox.bBoxNeY * staffSpace; // SMuFL: Y negativo = acima
    bbox.borderBottom = glyphBBox.bBoxSwY * staffSpace;

    // Calculatestesr size
    bbox.size = SizeF2D(
      bbox.borderRight - bbox.borderLeft,
      bbox.borderBottom - bbox.borderTop,
    );

    return bbox;
  }

  /// Creates Hierarchical BoundingBox simples from dimensões
  ///
  /// @param width Width in pixels
  /// @param height Height in pixels
  /// @param centerX if true, centraliza horizontalmente (borderLeft negativo)
  /// @param centerY if true, centraliza verticalmente (borderTop negativo)
  /// @return BoundingBox Configuresdo
  static BoundingBox fromDimensions(
    double width,
    double height, {
    bool centerX = true,
    bool centerY = true,
  }) {
    final bbox = BoundingBox();

    if (centerX) {
      bbox.borderLeft = -width / 2;
      bbox.borderRight = width / 2;
    } else {
      bbox.borderLeft = 0;
      bbox.borderRight = width;
    }

    if (centerY) {
      bbox.borderTop = -height / 2;
      bbox.borderBottom = height / 2;
    } else {
      bbox.borderTop = 0;
      bbox.borderBottom = height;
    }

    bbox.size = SizeF2D(width, height);

    return bbox;
  }

  /// Mescla múltiplos BoundingBoxes in um único envelope
  ///
  /// Útil for Createsr bounding box de grupos (chords, tuplets, etc.)
  ///
  /// @param boxes List of BoundingBoxes a mesclar
  /// @return BoundingBox that engloba all os boxes fornecidos
  static BoundingBox merge(List<BoundingBox> boxes) {
    if (boxes.isEmpty) {
      return BoundingBox();
    }

    if (boxes.length == 1) {
      return boxes.first;
    }

    final merged = BoundingBox();

    // add all como filhos
    for (final box in boxes) {
      merged.addChild(box);
    }

    // Calculatestesr envelope
    merged.calculateBoundingBox();

    return merged;
  }

  // ====================
  // MethodS AUXILIARES PRIVADOS
  // ====================

  /// Converts string de type for enum CollisionCategory
  static collision.CollisionCategory _stringToCollisionCategory(String elementType) {
    if (elementType.contains('notehead') || elementType.contains('note')) {
      return collision.CollisionCategory.notehead;
    }
    if (elementType.contains('accidental')) {
      return collision.CollisionCategory.accidental;
    }
    if (elementType.contains('articulation')) {
      return collision.CollisionCategory.articulation;
    }
    if (elementType.contains('ornament')) {
      return collision.CollisionCategory.ornament;
    }
    if (elementType.contains('stem')) {
      return collision.CollisionCategory.stem;
    }
    if (elementType.contains('beam')) {
      return collision.CollisionCategory.beam;
    }
    if (elementType.contains('slur') || elementType.contains('tie')) {
      return collision.CollisionCategory.other; // Não há categoria slur no enum
    }
    if (elementType.contains('dynamic')) {
      return collision.CollisionCategory.dynamic;
    }
    if (elementType.contains('text')) {
      return collision.CollisionCategory.text;
    }

    return collision.CollisionCategory.other;
  }

  /// Converts int de prioridade for enum CollisionPriority
  static collision.CollisionPriority _stringToCollisionPriority(int priorityValue) {
    if (priorityValue <= 2) {
      return collision.CollisionPriority.veryHigh;
    } else if (priorityValue <= 4) {
      return collision.CollisionPriority.high;
    } else if (priorityValue <= 6) {
      return collision.CollisionPriority.medium;
    } else if (priorityValue <= 8) {
      return collision.CollisionPriority.low;
    } else {
      return collision.CollisionPriority.veryLow;
    }
  }

  /// Maps type de elemento for prioridade de colisão
  static int _elementTypeToPriority(String elementType) {
    // Prioridades baseadas in importância visual
    // Valores smalleres = greater prioridade (not serão movidos)

    if (elementType.contains('notehead')) {
      return 1; // Cabeças de nota: maior prioridade
    }
    if (elementType.contains('stem')) {
      return 2; // Hastes: alta prioridade
    }
    if (elementType.contains('accidental')) {
      return 3; // Acidentes: alta prioridade
    }
    if (elementType.contains('beam')) {
      return 4; // Feixes
    }
    if (elementType.contains('articulation')) {
      return 5; // Articulações podem mover um pouco
    }
    if (elementType.contains('ornament')) {
      return 6; // Ornamentos
    }
    if (elementType.contains('dynamic')) {
      return 7; // Dinâmicas podem mover
    }
    if (elementType.contains('slur') || elementType.contains('tie')) {
      return 8; // Ligaduras são flexíveis
    }
    if (elementType.contains('text')) {
      return 9; // Texto: menor prioridade
    }

    return 10; // Outros
  }
}

/// Class auxiliar for representar BoundingBox de glifo SMuFL
///
/// Apenas for facilitar conversão, not substitui GlyphBoundingBox real
class SmuflBoundingBox {
  final double bBoxSwX; // Southwest X (canto inferior esquerdo)
  final double bBoxSwY; // Southwest Y
  final double bBoxNeX; // Northeast X (canto superior direito)
  final double bBoxNeY; // Northeast Y

  const SmuflBoundingBox({
    required this.bBoxSwX,
    required this.bBoxSwY,
    required this.bBoxNeX,
    required this.bBoxNeY,
  });

  double get width => bBoxNeX - bBoxSwX;
  double get height => bBoxSwY - bBoxNeY; // SMuFL: Y invertido
  double get centerX => (bBoxSwX + bBoxNeX) / 2;
  double get centerY => (bBoxSwY + bBoxNeY) / 2;
}
