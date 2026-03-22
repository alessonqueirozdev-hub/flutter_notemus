// lib/src/beaming/beam_segment.dart

/// Representa um segmento de beam (completo ou parcial/broken)
class BeamSegment {
  /// Nível do beam (1 = primary, 2 = secondary, 3 = tertiary, etc.)
  final int level;
  
  /// Índice da primeira nota no grupo
  final int startNoteIndex;
  
  /// Índice da última nota no grupo
  final int endNoteIndex;
  
  /// Se é um fractional beam (broken beam/stub)
  final bool isFractional;
  
  /// Lado do fractional beam (apenas para isFractional = true)
  final FractionalBeamSide? fractionalSide;
  
  /// Comprimento do fractional beam em staff spaces (padrão: largura de notehead)
  final double? fractionalLength;

  BeamSegment({
    required this.level,
    required this.startNoteIndex,
    required this.endNoteIndex,
    this.isFractional = false,
    this.fractionalSide,
    this.fractionalLength,
  });

  @override
  String toString() {
    if (isFractional) {
      return 'BeamSegment(level: $level, note: $startNoteIndex, fractional: $fractionalSide)';
    }
    return 'BeamSegment(level: $level, notes: $startNoteIndex-$endNoteIndex)';
  }
}

/// Direção do fractional beam (beam stub)
enum FractionalBeamSide {
  /// Beam stub aponta para a esquerda
  left,
  
  /// Beam stub aponta para a direita (padrão para ritmos pontuados)
  right,
}
