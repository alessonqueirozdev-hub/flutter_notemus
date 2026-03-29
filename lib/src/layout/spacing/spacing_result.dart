/// Estruturas de dados for resultados de spacing
/// 
/// Representa as positions Calculatestesdas dos símbolos musicais
/// in diferentes estágios of the algoritmo de spacing.
library;

import 'package:flutter_notemus/core/core.dart';

/// Position de um símbolo ou grupo de símbolos
class SymbolPosition {
  /// Símbolos nesta position (podem ser múltiplos se simultâneos)
  final List<MusicalElement> symbols;

  /// X position Calculatestesda (in pixels)
  double xPosition;

  /// Width total alocada for estes símbolos (in pixels)
  double width;

  /// Tempo musical absoluto (in frações de semibreve)
  /// 
  /// used for cálculo de durational spacing
  final double musicalTime;

  /// Duração até o next slice temporal
  final double durationToNext;

  /// Ponto de âncora for reescalonamento (0.0 - 1.0)
  /// 
  /// 0.0 = borda esquerda, 0.5 = centro, 1.0 = borda direita
  final double anchorPoint;

  /// Space comprimível (diferença entre duracional e textual)
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

  /// Width intrínseca dos símbolos (sem spacing added)
  double get intrinsicWidth {
    // Será Calculatestesdo pelo spacing engine
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

/// Resultado de textual spacing (anti-colisão)
class TextualSpacing {
  /// Positions Calculatestesdas
  final List<SymbolPosition> positions;

  /// Width total of the textual spacing
  final double totalWidth;

  TextualSpacing(this.positions, this.totalWidth);

  /// Escalar linearmente for a new width
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

/// Resultado de durational spacing (proporcional ao tempo)
class DurationalSpacing {
  /// Positions Calculatestesdas
  final List<SymbolPosition> positions;

  /// Width total of the durational spacing
  final double totalWidth;

  /// Duração of the note mais curta used como reference
  final double shortestNoteDuration;

  DurationalSpacing(
    this.positions,
    this.totalWidth,
    this.shortestNoteDuration,
  );

  /// Escalar linearmente for a new width
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

/// Resultado final de spacing (combinação adaptativa)
class FinalSpacing {
  /// Positions finais Calculatestesdas
  final List<SymbolPosition> positions;

  /// Width total final
  double get totalWidth {
    if (positions.isEmpty) return 0.0;
    final last = positions.last;
    return last.xPosition + last.width;
  }

  /// Number de colisões detectadas
  int collisionCount;

  /// Métrica de consistência (0.0 - 1.0)
  /// 
  /// 1.0 = perfeito (notes de mesma duração têm spacing idêntico)
  /// 0.0 = caótico (spacing totalmente inconsistente)
  double consistencyScore;

  /// Aproveitamento de space (0.0 - 1.0)
  /// 
  /// Razão entre width used e width disponível
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

/// Slice temporal - símbolos that ocorrem simultaneamente
class TimeSlice {
  /// Tempo musical absoluto (onset) deste slice
  final double time;

  /// Símbolos in each staff neste momento
  final Map<int, List<MusicalElement>> symbolsByStaff;

  /// Duração até o next slice
  double durationToNext;

  TimeSlice({
    required this.time,
    required this.symbolsByStaff,
    this.durationToNext = 0.0,
  });

  /// All os símbolos deste slice (all as staves)
  List<MusicalElement> get allSymbols {
    return symbolsByStaff.values.expand((list) => list).toList();
  }

  /// Símbolos de a staff específica
  List<MusicalElement> getSymbolsForStaff(int staffIndex) {
    return symbolsByStaff[staffIndex] ?? [];
  }

  /// Width máxima entre all as staves
  double getMaxWidth() {
    double maxWidth = 0.0;
    for (final symbols in symbolsByStaff.values) {
      double staffWidth = symbols.fold(0.0, (sum, symbol) {
        // Width será Calculatestesda pelo spacing engine
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

/// Dados de system for Processesmento de spacing
class SystemData {
  /// Measures of the system
  final List<Measure> measures;

  /// Number de staves
  final int staffCount;

  /// Width alvo of the system
  final double targetWidth;

  SystemData({
    required this.measures,
    required this.staffCount,
    required this.targetWidth,
  });

  /// Get all os time slices of the system
  List<TimeSlice> getTimeSlices() {
    // Será implementado pelo spacing engine
    // Precisa agrupar símbolos por tempo musical
    return [];
  }

  /// Encontrar a duração of the note mais curta no system
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
