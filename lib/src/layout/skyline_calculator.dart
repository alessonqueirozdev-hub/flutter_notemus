// lib/src/layout/skyline_calculator.dart

import 'dart:math' as math;
import 'bounding_box.dart';

/// Calculador de Skyline e Bottomline para detecção de colisões
///
/// Baseado em:
/// - OpenSheetMusicDisplay (SkyBottomLineCalculator.ts)
/// - Algoritmo usado para posicionamento inteligente de slurs, dinâmicas, etc.
///
/// Conceito:
/// - **Skyline**: Array de alturas Y máximas (limite superior ocupado)
/// - **Bottomline**: Array de alturas Y mínimas (limite inferior ocupado)
/// - Resolução: definida por samplingUnit (espaçamento entre pontos)
///
/// Uso:
/// 1. Inicializar com largura
/// 2. Atualizar skyline/bottomline conforme elementos são posicionados
/// 3. Consultar espaço disponível para novos elementos
class SkyBottomLineCalculator {
  /// Unidade de amostragem (espaçamento entre pontos em pixels)
  /// OSMD usa 3.0 pixels por padrão
  final double samplingUnit;

  /// Skyline: array de posições Y máximas (limite superior)
  /// Valores menores = mais alto na página
  List<double> skyLine = [];

  /// Bottomline: array de posições Y mínimas (limite inferior)
  /// Valores maiores = mais baixo na página
  List<double> bottomLine = [];

  /// Largura total sendo monitorada
  double _width = 0.0;

  SkyBottomLineCalculator({this.samplingUnit = 3.0});

  // ====================
  // INICIALIZAÇÃO
  // ====================

  /// Inicializa os arrays com a largura especificada
  ///
  /// @param width Largura total em pixels
  void initialize(double width) {
    _width = width;
    final length = (width / samplingUnit).ceil();

    // Skyline inicializa com infinito (nenhum limite superior)
    skyLine = List.filled(length, double.infinity);

    // Bottomline inicializa com infinito negativo (nenhum limite inferior)
    bottomLine = List.filled(length, double.negativeInfinity);
  }

  /// Reseta os arrays mantendo o tamanho
  void reset() {
    skyLine.fillRange(0, skyLine.length, double.infinity);
    bottomLine.fillRange(0, bottomLine.length, double.negativeInfinity);
  }

  // ====================
  // ATUALIZAÇÃO DE SKYLINE
  // ====================

  /// Atualiza o skyline em uma posição específica
  ///
  /// @param x Posição X em pixels
  /// @param y Posição Y (valores menores = mais alto)
  void updateSkyLine(double x, double y) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < skyLine.length) {
      // Skyline pega o valor MÍNIMO (mais alto na página)
      skyLine[index] = math.min(skyLine[index], y);
    }
  }

  /// Atualiza o skyline para um intervalo [startX, endX]
  ///
  /// @param startX Posição X inicial
  /// @param endX Posição X final
  /// @param y Posição Y
  void updateSkyLineRange(double startX, double endX, double y) {
    final startIndex = (startX / samplingUnit).floor();
    final endIndex = (endX / samplingUnit).ceil();

    for (int i = startIndex; i <= endIndex && i < skyLine.length; i++) {
      if (i >= 0) {
        skyLine[i] = math.min(skyLine[i], y);
      }
    }
  }

  /// Atualiza o skyline a partir de um BoundingBox
  ///
  /// @param box BoundingBox do elemento
  void updateSkyLineFromBox(BoundingBox box) {
    final left = box.absolutePosition.x + box.borderLeft;
    final right = box.absolutePosition.x + box.borderRight;
    final top = box.absolutePosition.y + box.borderTop;

    updateSkyLineRange(left, right, top);
  }

  // ====================
  // ATUALIZAÇÃO DE BOTTOMLINE
  // ====================

  /// Atualiza o bottomline em uma posição específica
  ///
  /// @param x Posição X em pixels
  /// @param y Posição Y (valores maiores = mais baixo)
  void updateBottomLine(double x, double y) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < bottomLine.length) {
      // Bottomline pega o valor MÁXIMO (mais baixo na página)
      bottomLine[index] = math.max(bottomLine[index], y);
    }
  }

  /// Atualiza o bottomline para um intervalo [startX, endX]
  ///
  /// @param startX Posição X inicial
  /// @param endX Posição X final
  /// @param y Posição Y
  void updateBottomLineRange(double startX, double endX, double y) {
    final startIndex = (startX / samplingUnit).floor();
    final endIndex = (endX / samplingUnit).ceil();

    for (int i = startIndex; i <= endIndex && i < bottomLine.length; i++) {
      if (i >= 0) {
        bottomLine[i] = math.max(bottomLine[i], y);
      }
    }
  }

  /// Atualiza o bottomline a partir de um BoundingBox
  ///
  /// @param box BoundingBox do elemento
  void updateBottomLineFromBox(BoundingBox box) {
    final left = box.absolutePosition.x + box.borderLeft;
    final right = box.absolutePosition.x + box.borderRight;
    final bottom = box.absolutePosition.y + box.borderBottom;

    updateBottomLineRange(left, right, bottom);
  }

  // ====================
  // CONSULTA
  // ====================

  /// Obtém o valor do skyline em uma posição X específica
  ///
  /// @param x Posição X em pixels
  /// @return Valor Y do skyline (double.infinity se não definido)
  double getSkyLineAt(double x) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < skyLine.length) {
      return skyLine[index];
    }
    return double.infinity;
  }

  /// Obtém o valor do bottomline em uma posição X específica
  ///
  /// @param x Posição X em pixels
  /// @return Valor Y do bottomline (double.negativeInfinity se não definido)
  double getBottomLineAt(double x) {
    final index = (x / samplingUnit).floor();
    if (index >= 0 && index < bottomLine.length) {
      return bottomLine[index];
    }
    return double.negativeInfinity;
  }

  /// Obtém pontos do skyline entre startX e endX
  ///
  /// @param startX Posição X inicial
  /// @param endX Posição X final
  /// @return Lista de PointF2D com (x, y) do skyline
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

  /// Obtém pontos do bottomline entre startX e endX
  ///
  /// @param startX Posição X inicial
  /// @param endX Posição X final
  /// @return Lista de PointF2D com (x, y) do bottomline
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
  // ANÁLISE DE ESPAÇO DISPONÍVEL
  // ====================

  /// Calcula o espaço vertical disponível entre skyline e bottomline
  ///
  /// @param x Posição X
  /// @return Espaço disponível (positivo), ou negativo se há colisão
  double getAvailableSpaceAt(double x) {
    final skyY = getSkyLineAt(x);
    final bottomY = getBottomLineAt(x);

    if (skyY == double.infinity || bottomY == double.negativeInfinity) {
      return double.infinity; // Espaço ilimitado
    }

    return bottomY - skyY; // Espaço entre limite inferior e superior
  }

  /// Calcula o espaço vertical mínimo em um intervalo
  ///
  /// @param startX Posição X inicial
  /// @param endX Posição X final
  /// @return Menor espaço disponível no intervalo
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

  /// Verifica se um BoundingBox pode ser posicionado sem colisão
  ///
  /// @param box BoundingBox a verificar
  /// @param margin Margem de segurança adicional
  /// @return true se cabe sem colisão
  bool canFit(BoundingBox box, {double margin = 0.0}) {
    final left = box.absolutePosition.x + box.borderLeft;
    final right = box.absolutePosition.x + box.borderRight;
    final top = box.absolutePosition.y + box.borderTop - margin;
    final bottom = box.absolutePosition.y + box.borderBottom + margin;

    final startIndex = (left / samplingUnit).floor();
    final endIndex = (right / samplingUnit).ceil();

    for (int i = startIndex; i <= endIndex && i < skyLine.length; i++) {
      if (i >= 0) {
        // Verificar se o box colide com o skyline ou bottomline
        if (top < skyLine[i] && bottom > bottomLine[i]) {
          continue; // OK, cabe entre skyline e bottomline
        }
        return false; // Colisão detectada
      }
    }

    return true;
  }

  /// Encontra a posição Y ótima para um elemento horizontal
  ///
  /// @param startX Posição X inicial
  /// @param endX Posição X final
  /// @param height Altura do elemento
  /// @param placeAbove Se true, posicionar acima do skyline; se false, abaixo do bottomline
  /// @param margin Margem de segurança
  /// @return Posição Y ótima
  double findOptimalY({
    required double startX,
    required double endX,
    required double height,
    required bool placeAbove,
    double margin = 0.0,
  }) {
    if (placeAbove) {
      // Posicionar acima: encontrar skyline mais baixo (valor Y máximo) no intervalo
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

      // Posicionar acima do skyline com margem
      return lowestSkyline - height - margin;
    } else {
      // Posicionar abaixo: encontrar bottomline mais alto (valor Y mínimo) no intervalo
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

      // Posicionar abaixo do bottomline com margem
      return highestBottomline + margin;
    }
  }

  // ====================
  // UTILITÁRIOS
  // ====================

  /// Retorna o índice do array para uma posição X
  int getIndexForX(double x) {
    return (x / samplingUnit).floor();
  }

  /// Retorna a posição X para um índice do array
  double getXForIndex(int index) {
    return index * samplingUnit;
  }

  /// Largura monitorada
  double get width => _width;

  /// Número de pontos de amostragem
  int get length => skyLine.length;

  @override
  String toString() {
    return 'SkyBottomLineCalculator('
        'width: $_width, '
        'samplingUnit: $samplingUnit, '
        'points: ${skyLine.length})';
  }
}