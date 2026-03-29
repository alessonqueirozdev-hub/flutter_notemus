// lib/src/layout/collision_detector.dart

import 'dart:ui';
import '../../core/core.dart'; // 🆕 Tipos do core
import 'layout_engine.dart';

/// Prioridade de colisão for elementos musicais
/// Elementos with greater prioridade are desenhados first and not movidos
enum CollisionPriority {
  veryLow,
  low,
  medium,
  high,
  veryHigh,
}

/// Categoria de elemento musical for detecção de colisões
enum CollisionCategory {
  notehead,
  accidental,
  articulation,
  ornament,
  dynamic,
  clef,
  flag,
  beam,
  stem,
  ledgerLine,
  text,
  barline,
  other,
}

/// Item registrado no system de colisões
class CollisionItem {
  final String id;
  final Rect bounds;
  final CollisionCategory category;
  final CollisionPriority priority;

  CollisionItem({
    required this.id,
    required this.bounds,
    required this.category,
    required this.priority,
  });

  @override
  String toString() => 'CollisionItem($id, $category, $priority)';
}

/// Representa a região ocupada by a elemento musical
class BoundingBox {
  final Offset position;
  final double width;
  final double height;
  final MusicalElement element;
  final String elementType;

  BoundingBox({
    required this.position,
    required this.width,
    required this.height,
    required this.element,
    required this.elementType,
  });

  /// Returns o retângulo representando this bounding box
  Rect get rect => Rect.fromLTWH(
        position.dx - width / 2,
        position.dy - height / 2,
        width,
        height,
      );

  /// Checks if this bounding box intersecta with other
  bool intersects(BoundingBox other) {
    return rect.overlaps(other.rect);
  }

  /// Returns a área de intersecção with other bounding box
  double intersectionArea(BoundingBox other) {
    final intersection = rect.intersect(other.rect);
    if (intersection.isEmpty) return 0.0;
    return intersection.width * intersection.height;
  }

  /// Calculates a distance vertical between centros
  double verticalDistanceTo(BoundingBox other) {
    return (position.dy - other.position.dy).abs();
  }

  /// Calculates a distance horizontal between centros
  double horizontalDistanceTo(BoundingBox other) {
    return (position.dx - other.position.dx).abs();
  }

  @override
  String toString() {
    return 'BoundingBox($elementType at ${position.dx.toStringAsFixed(1)}, ${position.dy.toStringAsFixed(1)})';
  }
}

/// Estatísticas de colisões detectadas
class CollisionStatistics {
  final int totalElements;
  final int collisionCount;
  final Map<String, int> collisionsByCategory;

  CollisionStatistics({
    required this.totalElements,
    required this.collisionCount,
    required this.collisionsByCategory,
  });

  /// COMPATIBILIDADE: Getter for API legada
  int get totalCollisions => collisionCount;

  /// COMPATIBILIDADE: Taxa de colisão (0.0 a 1.0)
  double get collisionRate {
    if (totalElements == 0) return 0.0;
    return collisionCount / totalElements;
  }
}

/// Detector de colisões between elementos musicais
class CollisionDetector {
  final double staffSpace;
  final List<BoundingBox> _occupiedRegions = [];
  final List<CollisionItem> _registeredItems = [];

  // Limites de colisão by type de elemento
  static const Map<String, double> _minDistances = {
    'notehead': 0.2,
    'accidental': 0.3,
    'articulation': 0.4,
    'ornament': 0.5,
    'dynamic': 1.0,
    'text': 0.5,
  };

  CollisionDetector({
    required this.staffSpace,
    double? defaultMargin, // COMPATIBILIDADE: Parâmetro ignorado, mantido para API legacy
    Map<CollisionCategory, double>? categoryMargins, // COMPATIBILIDADE: Parâmetro ignorado
  });

  /// Registra a região ocupada by a elemento
  void registerElement(BoundingBox boundingBox) {
    _occupiedRegions.add(boundingBox);
  }

  /// Limpa all as regiões registradas
  void clear() {
    _occupiedRegions.clear();
    _registeredItems.clear();
  }

  /// New: Registra a item no system de colisões moderno
  /// This method is used by BaseGlyphRenderer when trackBounds = true
  void register({
    required String id,
    required Rect bounds,
    required CollisionCategory category,
    required CollisionPriority priority,
  }) {
    _registeredItems.add(CollisionItem(
      id: id,
      bounds: bounds,
      category: category,
      priority: priority,
    ));
  }

  /// Returns all os itens registrados
  List<CollisionItem> get registeredItems => List.unmodifiable(_registeredItems);

  /// Detecta colisões between itens registrados
  List<CollisionItem> detectCollisions() {
    final collisions = <CollisionItem>[];

    for (int i = 0; i < _registeredItems.length; i++) {
      for (int j = i + 1; j < _registeredItems.length; j++) {
        final item1 = _registeredItems[i];
        final item2 = _registeredItems[j];

        if (item1.bounds.overlaps(item2.bounds)) {
          collisions.add(item1);
          collisions.add(item2);
        }
      }
    }

    return collisions;
  }

  /// Checks if a position caUsesria colisão
  bool wouldCollide(
    BoundingBox proposedBox,
    List<String> ignoreTypes,
  ) {
    for (final region in _occupiedRegions) {
      if (ignoreTypes.contains(region.elementType)) continue;

      if (proposedBox.intersects(region)) {
        final minDistance =
            _getMinDistance(proposedBox.elementType, region.elementType);
        final actualDistance = proposedBox.verticalDistanceTo(region);

        if (actualDistance < minDistance * staffSpace) {
          return true;
        }
      }
    }
    return false;
  }

  /// Encontra a position sem colisão próxima to the position preferida
  Offset findNonCollidingPosition(
    BoundingBox proposedBox,
    Offset preferredPosition, {
    List<String> ignoreTypes = const [],
    double maxAdjustment = 2.0,
  }) {
    // If not há colisão, Returnsr position preferida
    final testBox = BoundingBox(
      position: preferredPosition,
      width: proposedBox.width,
      height: proposedBox.height,
      element: proposedBox.element,
      elementType: proposedBox.elementType,
    );

    if (!wouldCollide(testBox, ignoreTypes)) {
      return preferredPosition;
    }

    // Tentar ajustes verticais incrementais
    final adjustmentStep = staffSpace * 0.25;
    final maxSteps = (maxAdjustment * staffSpace / adjustmentStep).round();

    for (int step = 1; step <= maxSteps; step++) {
      // Tentar for top
      final upPosition = Offset(
        preferredPosition.dx,
        preferredPosition.dy - (step * adjustmentStep),
      );
      final upBox = BoundingBox(
        position: upPosition,
        width: proposedBox.width,
        height: proposedBox.height,
        element: proposedBox.element,
        elementType: proposedBox.elementType,
      );

      if (!wouldCollide(upBox, ignoreTypes)) {
        return upPosition;
      }

      // Tentar for bottom
      final downPosition = Offset(
        preferredPosition.dx,
        preferredPosition.dy + (step * adjustmentStep),
      );
      final downBox = BoundingBox(
        position: downPosition,
        width: proposedBox.width,
        height: proposedBox.height,
        element: proposedBox.element,
        elementType: proposedBox.elementType,
      );

      if (!wouldCollide(downBox, ignoreTypes)) {
        return downPosition;
      }
    }

    // If not encontrou position, Returnsr a preferida same with colisão
    return preferredPosition;
  }

  /// Encontra all as colisões for a elemento proposto
  List<BoundingBox> findCollisions(
    BoundingBox proposedBox, {
    List<String> ignoreTypes = const [],
  }) {
    final collisions = <BoundingBox>[];

    for (final region in _occupiedRegions) {
      if (ignoreTypes.contains(region.elementType)) continue;

      if (proposedBox.intersects(region)) {
        collisions.add(region);
      }
    }

    return collisions;
  }

  /// Returns a distance mínima between dois tipos de elementos
  double _getMinDistance(String type1, String type2) {
    final dist1 = _minDistances[type1] ?? 0.5;
    final dist2 = _minDistances[type2] ?? 0.5;
    return (dist1 + dist2) / 2;
  }

  /// Otimiza o posicionamento de a conjunto de elementos
  List<PositionedElement> optimizePositioning(
    List<PositionedElement> elements,
  ) {
    clear();
    final optimized = <PositionedElement>[];

    for (final element in elements) {
      // Elementos estruturais not need de otimização
      if (_isStructuralElement(element.element)) {
        optimized.add(element);
        continue;
      }

      // Createsr bounding box for o elemento
      final bbox = _createBoundingBox(element);
      if (bbox == null) {
        optimized.add(element);
        continue;
      }

      // Encontrar position sem colisão
      final newPosition = findNonCollidingPosition(
        bbox,
        element.position,
        ignoreTypes: _getIgnoreTypes(element.element),
      );

      // add elemento otimizado
      final optimizedElement = PositionedElement(
        element.element,
        newPosition,
        system: element.system,
      );
      optimized.add(optimizedElement);

      // Registrar região ocupada
      registerElement(
        BoundingBox(
          position: newPosition,
          width: bbox.width,
          height: bbox.height,
          element: element.element,
          elementType: bbox.elementType,
        ),
      );
    }

    return optimized;
  }

  /// Checks if a elemento is estrutural (not needs de ajuste de colisão)
  bool _isStructuralElement(MusicalElement element) {
    return element is Clef ||
        element is KeySignature ||
        element is TimeSignature ||
        element is Barline;
  }

  /// Creates a bounding box estimada for a elemento
  BoundingBox? _createBoundingBox(PositionedElement element) {
    double width = staffSpace;
    double height = staffSpace;
    String type = 'unknown';

    if (element.element is Note) {
      width = staffSpace * 1.2;
      height = staffSpace * 3.5; // Inclui haste
      type = 'notehead';
    } else if (element.element is Rest) {
      width = staffSpace * 1.5;
      height = staffSpace * 2.0;
      type = 'rest';
    } else if (element.element is Chord) {
      width = staffSpace * 1.2;
      height = staffSpace * 4.0;
      type = 'chord';
    } else if (element.element is Dynamic) {
      width = staffSpace * 2.0;
      height = staffSpace * 1.0;
      type = 'dynamic';
    } else if (element.element is Ornament) {
      width = staffSpace * 1.0;
      height = staffSpace * 1.0;
      type = 'ornament';
    } else {
      return null;
    }

    return BoundingBox(
      position: element.position,
      width: width,
      height: height,
      element: element.element,
      elementType: type,
    );
  }

  /// Returns tipos de elementos a ignorar na detecção de colisão
  List<String> _getIgnoreTypes(MusicalElement element) {
    if (element is Dynamic) {
      return ['notehead', 'rest']; // Dinâmicas podem ficar perto de notas
    }
    if (element is Ornament) {
      return ['articulation']; // Ornamentos e articulações em lados opostos
    }
    return [];
  }

  /// Estatísticas de colisões detectadas (method legado)
  Map<String, int> getCollisionStatistics() {
    final stats = <String, int>{};

    for (int i = 0; i < _occupiedRegions.length; i++) {
      for (int j = i + 1; j < _occupiedRegions.length; j++) {
        if (_occupiedRegions[i].intersects(_occupiedRegions[j])) {
          final key =
              '${_occupiedRegions[i].elementType}-${_occupiedRegions[j].elementType}';
          stats[key] = (stats[key] ?? 0) + 1;
        }
      }
    }

    return stats;
  }

  /// Returns estatísticas estruturadas de colisões
  CollisionStatistics getStatistics() {
    final collisions = detectCollisions();
    final collisionsByCategory = <String, int>{};

    for (final item in collisions) {
      final categoryName = item.category.toString();
      collisionsByCategory[categoryName] = (collisionsByCategory[categoryName] ?? 0) + 1;
    }

    return CollisionStatistics(
      totalElements: _registeredItems.length,
      collisionCount: collisions.length,
      collisionsByCategory: collisionsByCategory,
    );
  }
}

/// Extension for facilitar o uso of the detector de colisões
extension CollisionDetectorExtension on LayoutEngine {
  /// applies detecção de colisões to the layout
  List<PositionedElement> layoutWithCollisionDetection() {
    final detector = CollisionDetector(staffSpace: staffSpace);
    final elements = layout();
    return detector.optimizePositioning(elements);
  }
}