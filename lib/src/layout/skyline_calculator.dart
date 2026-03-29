// lib/src/layout/skyline_calculateTestor.dart

import 'dart:math' as math;
import 'bounding_box.dart';

/// Calculator de Skyline and Bottomline for detecção de colisões
///
/// Based on:
/// - OpenSheetMusicDisplay (SkyBottomLinecalculateTestor.ts)
/// - Algoritmo used for posicionamento inteligente de slurs, dynamics, etc.
///
/// Conceito:
/// - **Skyline**: Array de heights Y máximas (limite upper ocupado)
/// - **Bottomline**: Array de heights Y mínimas (limite lower ocupado)
/// - Resolução: definida by samplingUnit (spacing between points)
///
/// Uso:
/// 1. Initialise with width
/// 2. Currentizar skyline/bottomline according to elementos are posicionados
/// 3. Consultar space disponível for news elementos
class SkyBottomLineCalculator {
  /// Unidade de amostragem (spacing between points in pixels)
  /// OSMD Uses 3.0 pixels by default
  final double samplingUnit;

  /// Skyline: array de positions Y máximas (limite upper)
  /// Valores smalleres = more alto na página
  List<double> skyLine = [];

  /// Bottomline: array de positions Y mínimas (limite lower)
  /// Valores greateres = more bottom na página
  List<double> bottomLine = [];

  /// Width total sendo monitorada
  double _width = 0.0;

  SkyBottomLineCalculator({this.samplingUnit = 3.0});

  // ====================
  // InitialisesÇÃO
  // ====================

  /// Initialises os arrays with a width especificada
  ///
  /// @param width Width total in pixels
  void initialize(double width) {
    _width = width;
    final length = (width / samplingUnit).ceil();

    // Skyline Initialises with infinito (nenhum limite upper)
    skyLine = List.filled(length, double.infinity);

    // Bottomline Initialises with infinito negativo (nenhum limite lower)
    bottomLine = List.filled(length, double.negativeInfinity);
  }

  /// Reseta os arrays mantendo o size
  void reset() {
    skyLine.fillRange(0, skyLine.length, double.infinity);
    bottomLine.fillRange(0, bottomLine.length, double.negativeInfinity);
  }

  // ====================
  // CurrentIZAÇÃO DE SKYLINE
  // ====================

  /// Currentiza o skyline in a position específica
  ///
  /// @param x X position in pixels
  /// @param y Y position (lower values = higher on screen)
  void updateSkyLine(double x, double y) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < skyLine.length) {
      // Skyline pega o minimum value (more alto na página)
      skyLine[index] = math.min(skyLine[index], y);
    }
  }

  /// Currentiza o skyline for a intervalo [startX, endX]
  ///
  /// @param startX X position initial
  /// @param endX X position final
  /// @param y Y position
  void updateSkyLineRange(double startX, double endX, double y) {
    final startIndex = (startX / samplingUnit).floor();
    final endIndex = (endX / samplingUnit).ceil();

    for (int i = startIndex; i <= endIndex && i < skyLine.length; i++) {
      if (i >= 0) {
        skyLine[i] = math.min(skyLine[i], y);
      }
    }
  }

  /// Currentiza o skyline from a BoundingBox
  ///
  /// @param box BoundingBox of the element
  void updateSkyLineFromBox(BoundingBox box) {
    final left = box.absolutePosition.x + box.borderLeft;
    final right = box.absolutePosition.x + box.borderRight;
    final top = box.absolutePosition.y + box.borderTop;

    updateSkyLineRange(left, right, top);
  }

  // ====================
  // CurrentIZAÇÃO DE BOTTOMLINE
  // ====================

  /// Currentiza o bottomline in a position específica
  ///
  /// @param x X position in pixels
  /// @param y Y position (valores greateres = more bottom)
  void updateBottomLine(double x, double y) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < bottomLine.length) {
      // Bottomline pega o maximum value (more bottom na página)
      bottomLine[index] = math.max(bottomLine[index], y);
    }
  }

  /// Currentiza o bottomline for a intervalo [startX, endX]
  ///
  /// @param startX X position initial
  /// @param endX X position final
  /// @param y Y position
  void updateBottomLineRange(double startX, double endX, double y) {
    final startIndex = (startX / samplingUnit).floor();
    final endIndex = (endX / samplingUnit).ceil();

    for (int i = startIndex; i <= endIndex && i < bottomLine.length; i++) {
      if (i >= 0) {
        bottomLine[i] = math.max(bottomLine[i], y);
      }
    }
  }

  /// Currentiza o bottomline from a BoundingBox
  ///
  /// @param box BoundingBox of the element
  void updateBottomLineFromBox(BoundingBox box) {
    final left = box.absolutePosition.x + box.borderLeft;
    final right = box.absolutePosition.x + box.borderRight;
    final bottom = box.absolutePosition.y + box.borderBottom;

    updateBottomLineRange(left, right, bottom);
  }

  // ====================
  // CONSULTA
  // ====================

  /// Gets o value of the skyline in a X position específica
  ///
  /// @param x X position in pixels
  /// @return Value Y of the skyline (double.infinity if not defined)
  double getSkyLineAt(double x) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < skyLine.length) {
      return skyLine[index];
    }
    return double.infinity;
  }

  /// Gets o value of the bottomline in a X position específica
  ///
  /// @param x X position in pixels
  /// @return Value Y of the bottomline (double.negativeInfinity if not defined)
  double getBottomLineAt(double x) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < bottomLine.length) {
      return bottomLine[index];
    }
    return double.negativeInfinity;
  }

  /// Gets points of the skyline between startX and endX
  ///
  /// @param startX X position initial
  /// @param endX X position final
  /// @return List of PointF2D with (x, y) of the skyline
  List<PointF2D> getSkyLinePoints(double startX, double endX) {
    final startIndex = (startX / samplingUnit).floor();
    final endIndex = (endX / samplingUnit).ceil();

    final points = <PointF2D>[];
    for (int i = startIndex; i <= endIndex && i < skyLine.length; i++) {
      if (i >= 0 && skyLine[i] != double.infinity) {
        points.add(PointF2D(i * samplingUnit, skyLine[i]));
      }
    }
    return points;
  }

  /// Gets points of the bottomline between startX and endX
  ///
  /// @param startX X position initial
  /// @param endX X position final
  /// @return List of PointF2D with (x, y) of the bottomline
  List<PointF2D> getBottomLinePoints(double startX, double endX) {
    final startIndex = (startX / samplingUnit).floor();
    final endIndex = (endX / samplingUnit).ceil();

    final points = <PointF2D>[];
    for (int i = startIndex; i <= endIndex && i < bottomLine.length; i++) {
      if (i >= 0 && bottomLine[i] != double.negativeInfinity) {
        points.add(PointF2D(i * samplingUnit, bottomLine[i]));
      }
    }
    return points;
  }

  // ====================
  // ANÁLISE DE Space DISPONÍVEL
  // ====================

  /// Calculates o space vertical disponível between skyline and bottomline
  ///
  /// @param x X position
  /// @return Space disponível (positivo), or negativo if há colisão
  double getAvailableSpaceAt(double x) {
    final skyY = getSkyLineAt(x);
    final bottomY = getBottomLineAt(x);

    if (skyY == double.infinity || bottomY == double.negativeInfinity) {
      return double.infinity; // Espaço ilimitado
    }

    return bottomY - skyY; // Espaço entre limite inferior e superior
  }

  /// Calculates o space vertical mínimo in a intervalo
  ///
  /// @param startX X position initial
  /// @param endX X position final
  /// @return Smaller space disponível no intervalo
  double getMinimumAvailableSpace(double startX, double endX) {
    final startIndex = (startX / samplingUnit).floor();
    final endIndex = (endX / samplingUnit).ceil();

    double minSpace = double.infinity;

    for (int i = startIndex; i <= endIndex && i < skyLine.length; i++) {
      if (i >= 0) {
        final space = getAvailableSpaceAt(i * samplingUnit);
        if (space < minSpace) {
          minSpace = space;
        }
      }
    }

    return minSpace;
  }

  /// Checks if a BoundingBox can be positioned sem colisão
  ///
  /// @param box BoundingBox a Check
  /// @param margin Margin de segurança added
  /// @return true if cabe sem colisão
  bool canFit(BoundingBox box, {double margin = 0.0}) {
    final left = box.absolutePosition.x + box.borderLeft;
    final right = box.absolutePosition.x + box.borderRight;
    final top = box.absolutePosition.y + box.borderTop - margin;
    final bottom = box.absolutePosition.y + box.borderBottom + margin;

    final startIndex = (left / samplingUnit).floor();
    final endIndex = (right / samplingUnit).ceil();

    for (int i = startIndex; i <= endIndex && i < skyLine.length; i++) {
      if (i >= 0) {
        // Check if o box colide with o skyline or bottomline
        if (top < skyLine[i] && bottom > bottomLine[i]) {
          continue; // OK, cabe entre skyline e bottomline
        }
        return false; // Colisão detectada
      }
    }

    return true;
  }

  /// Encontra a Y position ótima for a elemento horizontal
  ///
  /// @param startX X position initial
  /// @param endX X position final
  /// @param height Height of the element
  /// @param placeAbove if true, position above the skyline; if false, below of the bottomline
  /// @param margin Margin de segurança
  /// @return Y position ótima
  double findOptimalY({
    required double startX,
    required double endX,
    required double height,
    required bool placeAbove,
    double margin = 0.0,
  }) {
    if (placeAbove) {
      // Position above: encontrar skyline more bottom (value Y máximo) no intervalo
      final points = getSkyLinePoints(startX, endX);
      if (points.isEmpty) {
        return 0.0; // Sem restrições, posicionar no topo
      }

      double lowestSkyline = double.infinity;
      for (final point in points) {
        if (point.y < lowestSkyline) {
          lowestSkyline = point.y;
        }
      }

      // Position above the skyline with margin
      return lowestSkyline - height - margin;
    } else {
      // Position below: encontrar bottomline more alto (value Y mínimo) no intervalo
      final points = getBottomLinePoints(startX, endX);
      if (points.isEmpty) {
        return 0.0; // Sem restrições, posicionar no topo
      }

      double highestBottomline = double.negativeInfinity;
      for (final point in points) {
        if (point.y > highestBottomline) {
          highestBottomline = point.y;
        }
      }

      // Position below the bottomline with margin
      return highestBottomline + margin;
    }
  }

  // ====================
  // UTILITÁRIOS
  // ====================

  /// Returns o index of the array for a X position
  int getIndexForX(double x) {
    return (x / samplingUnit).floor();
  }

  /// Returns a X position for a index of the array
  double getXForIndex(int index) {
    return index * samplingUnit;
  }

  /// Width monitorada
  double get width => _width;

  /// Number de points de amostragem
  int get length => skyLine.length;

  @override
  String toString() {
    return 'SkyBottomLineCalculator('
        'width: $_width, '
        'samplingUnit: $samplingUnit, '
        'points: ${skyLine.length})';
  }
}