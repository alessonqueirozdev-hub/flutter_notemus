/// Estruturas de dados para resultados de espaçamento
/// 
/// Representa as posições calculadas dos símbolos musicais
/// em diferentes estágios do algoritmo de espaçamento.
library;

import 'package:flutter_notemus/core/core.dart';

/// Posição de um símbolo ou grupo de símbolos
class SymbolPosition {
  /// Símbolos nesta posição (podem ser múltiplos se simultâneos)
  final List<MusicalElement> symbols;

  /// Posição X calculada (em pixels)
  double xPosition;

  /// Largura total alocada para estes símbolos (em pixels)
  double width;

  /// Tempo musical absoluto (em frações de semibreve)
  /// 
  /// Usado para cálculo de espaçamento duracional
  final double musicalTime;

  /// Duração até o próximo slice temporal
  final double durationToNext;

  /// Ponto de âncora para reescalonamento (0.0 - 1.0)
  /// 
  /// 0.0 = borda esquerda, 0.5 = centro, 1.0 = borda direita
  final double anchorPoint;

  /// Espaço comprimível (diferença entre duracional e textual)
  double compressibleSpace;

  SymbolPosition({
    required this.symbols,
    required this.xPosition,
    required this.width,
    this.musicalTime = 0.0,
    this.durationToNext = 0.0,
    this.anchorPoint = 0.0,
    this.compressibleSpace = 0.0,
  });

  /// Largura intrínseca dos símbolos (sem espaçamento adicional)
  double get intrinsicWidth {
    // Será calculado pelo motor de espaçamento
    return width - compressibleSpace;
  }

  @override
  String toString() {
    return 'SymbolPosition(x: ${xPosition.toStringAsFixed(2)}, '
        'width: ${width.toStringAsFixed(2)}, '
        'time: ${musicalTime.toStringAsFixed(3)}, '
        'symbols: ${symbols.length})';
  }
}

/// Resultado de espaçamento textual (anti-colisão)
class TextualSpacing {
  /// Posições calculadas
  final List<SymbolPosition> positions;

  /// Largura total do espaçamento textual
  final double totalWidth;

  TextualSpacing(this.positions, this.totalWidth);

  /// Escalar linearmente para uma nova largura
  TextualSpacing scale(double targetWidth) {
    final double scaleFactor = targetWidth / totalWidth;
    final List<SymbolPosition> scaledPositions = [];

    double currentX = 0.0;
    for (final pos in positions) {
      final double scaledWidth = pos.width * scaleFactor;
      scaledPositions.add(SymbolPosition(
        symbols: pos.symbols,
        xPosition: currentX,
        width: scaledWidth,
        musicalTime: pos.musicalTime,
        durationToNext: pos.durationToNext,
        anchorPoint: pos.anchorPoint,
      ));
      currentX += scaledWidth;
    }

    return TextualSpacing(scaledPositions, targetWidth);
  }

  @override
  String toString() {
    return 'TextualSpacing(positions: ${positions.length}, '
        'totalWidth: ${totalWidth.toStringAsFixed(2)})';
  }
}

/// Resultado de espaçamento duracional (proporcional ao tempo)
class DurationalSpacing {
  /// Posições calculadas
  final List<SymbolPosition> positions;

  /// Largura total do espaçamento duracional
  final double totalWidth;

  /// Duração da nota mais curta usada como referência
  final double shortestNoteDuration;

  DurationalSpacing(
    this.positions,
    this.totalWidth,
    this.shortestNoteDuration,
  );

  /// Escalar linearmente para uma nova largura
  DurationalSpacing scale(double targetWidth) {
    final double scaleFactor = targetWidth / totalWidth;
    final List<SymbolPosition> scaledPositions = [];

    double currentX = 0.0;
    for (final pos in positions) {
      final double scaledWidth = pos.width * scaleFactor;
      scaledPositions.add(SymbolPosition(
        symbols: pos.symbols,
        xPosition: currentX,
        width: scaledWidth,
        musicalTime: pos.musicalTime,
        durationToNext: pos.durationToNext,
        anchorPoint: pos.anchorPoint,
      ));
      currentX += scaledWidth;
    }

    return DurationalSpacing(scaledPositions, targetWidth, shortestNoteDuration);
  }

  @override
  String toString() {
    return 'DurationalSpacing(positions: ${positions.length}, '
        'totalWidth: ${totalWidth.toStringAsFixed(2)}, '
        'shortestNote: ${shortestNoteDuration.toStringAsFixed(4)})';
  }
}

/// Resultado final de espaçamento (combinação adaptativa)
class FinalSpacing {
  /// Posições finais calculadas
  final List<SymbolPosition> positions;

  /// Largura total final
  double get totalWidth {
    if (positions.isEmpty) return 0.0;
    final last = positions.last;
    return last.xPosition + last.width;
  }

  /// Número de colisões detectadas
  int collisionCount;

  /// Métrica de consistência (0.0 - 1.0)
  /// 
  /// 1.0 = perfeito (notas de mesma duração têm espaçamento idêntico)
  /// 0.0 = caótico (espaçamento totalmente inconsistente)
  double consistencyScore;

  /// Aproveitamento de espaço (0.0 - 1.0)
  /// 
  /// Razão entre largura usada e largura disponível
  double spaceUtilization;

  FinalSpacing(
    this.positions, {
    this.collisionCount = 0,
    this.consistencyScore = 1.0,
    this.spaceUtilization = 1.0,
  });

  @override
  String toString() {
    return 'FinalSpacing(positions: ${positions.length}, '
        'totalWidth: ${totalWidth.toStringAsFixed(2)}, '
        'collisions: $collisionCount, '
        'consistency: ${(consistencyScore * 100).toStringAsFixed(1)}%, '
        'utilization: ${(spaceUtilization * 100).toStringAsFixed(1)}%)';
  }
}

/// Slice temporal - símbolos que ocorrem simultaneamente
class TimeSlice {
  /// Tempo musical absoluto (onset) deste slice
  final double time;

  /// Símbolos em cada pauta neste momento
  final Map<int, List<MusicalElement>> symbolsByStaff;

  /// Duração até o próximo slice
  double durationToNext;

  TimeSlice({
    required this.time,
    required this.symbolsByStaff,
    this.durationToNext = 0.0,
  });

  /// Todos os símbolos deste slice (todas as pautas)
  List<MusicalElement> get allSymbols {
    return symbolsByStaff.values.expand((list) => list).toList();
  }

  /// Símbolos de uma pauta específica
  List<MusicalElement> getSymbolsForStaff(int staffIndex) {
    return symbolsByStaff[staffIndex] ?? [];
  }

  /// Largura máxima entre todas as pautas
  double getMaxWidth() {
    double maxWidth = 0.0;
    for (final symbols in symbolsByStaff.values) {
      double staffWidth = symbols.fold(0.0, (sum, symbol) {
        // Largura será calculada pelo motor de espaçamento
        return sum + 1.0; // Placeholder
      });
      if (staffWidth > maxWidth) {
        maxWidth = staffWidth;
      }
    }
    return maxWidth;
  }

  @override
  String toString() {
    return 'TimeSlice(time: ${time.toStringAsFixed(3)}, '
        'staves: ${symbolsByStaff.length}, '
        'duration: ${durationToNext.toStringAsFixed(3)})';
  }
}

/// Dados de sistema para processamento de espaçamento
class SystemData {
  /// Compassos do sistema
  final List<Measure> measures;

  /// Número de pautas
  final int staffCount;

  /// Largura alvo do sistema
  final double targetWidth;

  SystemData({
    required this.measures,
    required this.staffCount,
    required this.targetWidth,
  });

  /// Obter todos os time slices do sistema
  List<TimeSlice> getTimeSlices() {
    // Será implementado pelo motor de espaçamento
    // Precisa agrupar símbolos por tempo musical
    return [];
  }

  /// Encontrar a duração da nota mais curta no sistema
  double getShortestNoteDuration() {
    double shortest = 1.0; // Semibreve como máximo inicial

    for (final measure in measures) {
      for (final element in measure.elements) {
        if (element is Note) {
          if (element.duration.realValue < shortest) {
            shortest = element.duration.realValue;
          }
        } else if (element is Rest) {
          if (element.duration.realValue < shortest) {
            shortest = element.duration.realValue;
          }
        }
        // TODO: Chord, Tuplet
      }
    }

    return shortest;
  }

  @override
  String toString() {
    return 'SystemData(measures: ${measures.length}, '
        'staves: $staffCount, '
        'targetWidth: ${targetWidth.toStringAsFixed(2)})';
  }
}
