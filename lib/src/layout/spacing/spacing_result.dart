/// Structures de data for results de spacing
/// 
/// Representa as positions Calculated dos symbols musicais
/// in diferentes estágios of the algoritmo de spacing.
library;

import 'package:flutter_notemus/core/core.dart';

/// Position de a symbol or grupo de symbols
class SymbolPosition {
  /// Symbols nesta position (can be múltiplos if simultâneos)
  final List<MusicalElement> symbols;

  /// X position Calculated (in pixels)
  double xPosition;

  /// Width total alocada for estes symbols (in pixels)
  double width;

  /// Tempo musical absoluto (in frações de semibreve)
  /// 
  /// used for calculation de durational spacing
  final double musicalTime;

  /// Duração until o next slice temporal
  final double durationToNext;

  /// Point de âncora for reescalonamento (0.0 - 1.0)
  /// 
  /// 0.0 = borda left, 0.5 = centre, 1.0 = borda right
  final double anchorPoint;

  /// Space comprimível (diferença between duracional and textual)
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

  /// Width intrínseca dos symbols (sem spacing added)
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

/// Result de textual spacing (anti-colisão)
class TextualSpacing {
  /// Positions Calculated
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

/// Result de durational spacing (proporcional to the tempo)
class DurationalSpacing {
  /// Positions Calculated
  final List<SymbolPosition> positions;

  /// Width total of the durational spacing
  final double totalWidth;

  /// Duração of the note more curta used as reference
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

/// Result final de spacing (combinação adaptativa)
class FinalSpacing {
  /// Positions finais Calculated
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
  /// 1.0 = perfeito (notes de same duração têm spacing idêntico)
  /// 0.0 = caótico (spacing totalmente inconsistente)
  double consistencyScore;

  /// Aproveitamento de space (0.0 - 1.0)
  /// 
  /// Razão between width used and width disponível
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

/// Slice temporal - symbols that ocorrem simultaneamente
class TimeSlice {
  /// Tempo musical absoluto (onset) deste slice
  final double time;

  /// Symbols in each staff neste momento
  final Map<int, List<MusicalElement>> symbolsByStaff;

  /// Duração until o next slice
  double durationToNext;

  TimeSlice({
    required this.time,
    required this.symbolsByStaff,
    this.durationToNext = 0.0,
  });

  /// All os symbols deste slice (all as staves)
  List<MusicalElement> get allSymbols {
    return symbolsByStaff.values.expand((list) => list).toList();
  }

  /// Symbols de a staff específica
  List<MusicalElement> getSymbolsForStaff(int staffIndex) {
    return symbolsByStaff[staffIndex] ?? [];
  }

  /// Maximum coarse width (in staff spaces) across all staves of this slice.
  ///
  /// This is a pre-layout estimate per element kind. The precise per-glyph
  /// width is resolved later by the spacing engine using SMuFL metadata; here
  /// we only need a proportional, non-zero advance for each element type so
  /// that chords and tuplets are not under-allocated relative to plain notes.
  double getMaxWidth() {
    double maxWidth = 0.0;
    for (final symbols in symbolsByStaff.values) {
      final double staffWidth = symbols.fold(
        0.0,
        (sum, symbol) => sum + estimateAdvanceWidthInStaffSpaces(symbol),
      );
      if (staffWidth > maxWidth) {
        maxWidth = staffWidth;
      }
    }
    return maxWidth;
  }

  /// Coarse nominal advance width of a single element, in staff spaces.
  ///
  /// Notehead reference is ~1.18 SS (Bravura `noteheadBlack`); accidentals add
  /// roughly one notehead; a chord is as wide as a single notehead plus its
  /// widest accidental; a tuplet is the sum of its visible children.
  static double estimateAdvanceWidthInStaffSpaces(MusicalElement element) {
    const double noteheadWidth = 1.18;
    const double accidentalWidth = 0.9;

    if (element is Note) {
      final double accidental =
          element.pitch.accidentalGlyph != null ? accidentalWidth : 0.0;
      return noteheadWidth + accidental;
    }
    if (element is Rest) {
      return 1.0;
    }
    if (element is Chord) {
      final bool hasAccidental =
          element.notes.any((n) => n.pitch.accidentalGlyph != null);
      return noteheadWidth + (hasAccidental ? accidentalWidth : 0.0);
    }
    if (element is Tuplet) {
      double sum = 0.0;
      for (final child in element.elements) {
        sum += estimateAdvanceWidthInStaffSpaces(child);
      }
      return sum;
    }
    return noteheadWidth;
  }

  @override
  String toString() {
    return 'TimeSlice(time: ${time.toStringAsFixed(3)}, '
        'staves: ${symbolsByStaff.length}, '
        'duration: ${durationToNext.toStringAsFixed(3)})';
  }
}

/// Data de system for Processing de spacing
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
    // Needs agrupar symbols by tempo musical
    return [];
  }

  /// Shortest *sounding* note value in the system (in fractions of a whole
  /// note). Drives the durational-spacing reference.
  ///
  /// Chords contribute their own duration. For tuplets the sounding value of
  /// each child is its written value scaled by the tuplet ratio (e.g. an
  /// eighth inside a 3:2 triplet sounds as 1/12, not 1/8), applied recursively
  /// for nested tuplets via [Tuplet.getModifiedDuration].
  double getShortestNoteDuration() {
    double shortest = 1.0; // Whole note as the initial maximum.

    for (final measure in measures) {
      for (final element in measure.elements) {
        shortest = _shortestSoundingDuration(element, shortest);
      }
    }

    return shortest;
  }

  static double _shortestSoundingDuration(
    MusicalElement element,
    double current, [
    Tuplet? enclosingTuplet,
  ]) {
    double sounding(double written) =>
        enclosingTuplet?.getModifiedDuration(written) ?? written;

    if (element is Note) {
      final v = sounding(element.duration.realValue);
      return v < current ? v : current;
    }
    if (element is Rest) {
      final v = sounding(element.duration.realValue);
      return v < current ? v : current;
    }
    if (element is Chord) {
      final v = sounding(element.duration.realValue);
      return v < current ? v : current;
    }
    if (element is Tuplet) {
      double shortest = current;
      for (final child in element.elements) {
        shortest = _shortestSoundingDuration(child, shortest, element);
      }
      return shortest;
    }
    return current;
  }

  @override
  String toString() {
    return 'SystemData(measures: ${measures.length}, '
        'staves: $staffCount, '
        'targetWidth: ${targetWidth.toStringAsFixed(2)})';
  }
}
