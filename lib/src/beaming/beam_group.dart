// lib/src/beaming/beam_group.dart

import 'package:flutter_notemus/core/note.dart';
import 'package:flutter_notemus/src/beaming/beam_segment.dart';
import 'package:flutter_notemus/src/beaming/beam_types.dart';

/// Representa um grupo de notas conectadas por beams com geometria calculada
/// (Versão avançada com análise de inclinação e segmentos)
class AdvancedBeamGroup {
  /// Notas no grupo (devem ser consecutivas)
  List<Note> notes;
  
  /// Direção das hastes para todo o grupo
  StemDirection stemDirection = StemDirection.up;
  
  /// Segmentos de beam (primary, secondary, fractional, etc.)
  final List<BeamSegment> beamSegments = [];
  
  /// Posição X do início do beam (primeira nota)
  double leftX = 0;
  
  /// Posição X do fim do beam (última nota)
  double rightX = 0;
  
  /// Posição Y do beam na primeira nota (topo/base da haste)
  double leftY = 0;
  
  /// Posição Y do beam na última nota (topo/base da haste)
  double rightY = 0;
  
  /// Inclinação do beam (slope)
  double get slope {
    if (rightX == leftX) return 0;
    return (rightY - leftY) / (rightX - leftX);
  }
  
  /// Se o beam é horizontal (sem inclinação)
  bool get isHorizontal => leftY == rightY;

  AdvancedBeamGroup({
    required this.notes,
    this.stemDirection = StemDirection.up,
  });

  /// Interpola a posição Y do beam em uma posição X específica
  double interpolateBeamY(double x) {
    if (isHorizontal || rightX == leftX) {
      return leftY;
    }
    return leftY + (slope * (x - leftX));
  }

  @override
  String toString() {
    return 'AdvancedBeamGroup(notes: ${notes.length}, '
           'segments: ${beamSegments.length}, '
           'slope: ${slope.toStringAsFixed(3)}';
  }
}
