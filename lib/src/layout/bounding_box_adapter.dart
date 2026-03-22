// lib/src/layout/bounding_box_adapter.dart

import 'package:flutter/material.dart';

import '../../core/core.dart'; // 🆕 Tipos do core
import 'bounding_box.dart';
import 'collision_detector.dart' as collision;

/// Adapter para integração entre BoundingBox hierárquico e sistema de colisão
///
/// Este adapter permite:
/// 1. Converter BoundingBox hierárquico para BoundingBox simples (CollisionDetector)
/// 2. Registrar hierarquia no CollisionDetector
/// 3. Manter compatibilidade com código existente
///
/// PADRÃO: Adapter Pattern
class BoundingBoxAdapter {
  /// Converte BoundingBox hierárquico para BoundingBox simples do CollisionDetector
  ///
  /// @param hierarchical BoundingBox hierárquico
  /// @param element Elemento musical associado
  /// @param elementType Tipo do elemento para detecção de colisão
  /// @return BoundingBox simples compatível com CollisionDetector
  static collision.BoundingBox toCollisionBoundingBox(
    BoundingBox hierarchical,
    MusicalElement element,
    String elementType,
  ) {
    // Garantir que posições estão atualizadas
    hierarchical.calculateAbsolutePosition();
    hierarchical.calculateBoundingBox();

    // Criar Rect a partir das bordas calculadas
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

  /// Registra BoundingBox hierárquico e todos seus filhos no CollisionDetector
  ///
  /// Percorre recursivamente a hierarquia e registra cada elemento
  ///
  /// @param hierarchical BoundingBox hierárquico raiz
  /// @param element Elemento musical associado ao bbox raiz
  /// @param elementType Tipo do elemento
  /// @param detector CollisionDetector onde registrar
  /// @param registerChildren Se true, registra filhos recursivamente
  static void registerInCollisionDetector(
    BoundingBox hierarchical,
    MusicalElement element,
    String elementType,
    collision.CollisionDetector detector, {
    bool registerChildren = true,
  }) {
    // Atualizar hierarquia antes de registrar
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

        // Recursão para registrar toda a subárvore
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

  /// Cria BoundingBox hierárquico a partir de GlyphInfo SMuFL
  ///
  /// @param glyphBBox Bounding box do glifo (do metadata SMuFL)
  /// @param staffSpace Tamanho do staff space para conversão
  /// @return BoundingBox hierárquico configurado
  static BoundingBox fromSmuflGlyphBBox(
    SmuflBoundingBox glyphBBox,
    double staffSpace,
  ) {
    final bbox = BoundingBox();

    // Converter coordenadas SMuFL (staff spaces) para pixels
    bbox.borderLeft = glyphBBox.bBoxSwX * staffSpace;
    bbox.borderRight = glyphBBox.bBoxNeX * staffSpace;
    bbox.borderTop = glyphBBox.bBoxNeY * staffSpace; // SMuFL: Y negativo = acima
    bbox.borderBottom = glyphBBox.bBoxSwY * staffSpace;

    // Calcular tamanho
    bbox.size = SizeF2D(
      bbox.borderRight - bbox.borderLeft,
      bbox.borderBottom - bbox.borderTop,
    );

    return bbox;
  }

  /// Cria BoundingBox hierárquico simples a partir de dimensões
  ///
  /// @param width Largura em pixels
  /// @param height Altura em pixels
  /// @param centerX Se true, centraliza horizontalmente (borderLeft negativo)
  /// @param centerY Se true, centraliza verticalmente (borderTop negativo)
  /// @return BoundingBox configurado
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

  /// Mescla múltiplos BoundingBoxes em um único envelope
  ///
  /// Útil para criar bounding box de grupos (acordes, tuplas, etc.)
  ///
  /// @param boxes Lista de BoundingBoxes a mesclar
  /// @return BoundingBox que engloba todos os boxes fornecidos
  static BoundingBox merge(List<BoundingBox> boxes) {
    if (boxes.isEmpty) {
      return BoundingBox();
    }

    if (boxes.length == 1) {
      return boxes.first;
    }

    final merged = BoundingBox();

    // Adicionar todos como filhos
    for (final box in boxes) {
      merged.addChild(box);
    }

    // Calcular envelope
    merged.calculateBoundingBox();

    return merged;
  }

  // ====================
  // MÉTODOS AUXILIARES PRIVADOS
  // ====================

  /// Converte string de tipo para enum CollisionCategory
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

  /// Converte int de prioridade para enum CollisionPriority
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

  /// Mapeia tipo de elemento para prioridade de colisão
  static int _elementTypeToPriority(String elementType) {
    // Prioridades baseadas em importância visual
    // Valores menores = maior prioridade (não serão movidos)

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

/// Classe auxiliar para representar BoundingBox de glifo SMuFL
///
/// Apenas para facilitar conversão, não substitui GlyphBoundingBox real
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
