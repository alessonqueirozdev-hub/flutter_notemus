// lib/core/cluster.dart

import 'musical_element.dart';
import 'pitch.dart';

/// Tipos de cluster
enum ClusterType {
  chromatic,    // Cluster cromático
  diatonic,     // Cluster diatônico
  pentatonic,   // Cluster pentatônico
}

/// Representa um cluster (grupo de notas adjacentes tocadas simultaneamente)
class Cluster extends MusicalElement {
  final Pitch lowestPitch;
  final Pitch highestPitch;
  final Pitch lowestNote; // Alias para lowestPitch
  final Pitch highestNote; // Alias para highestPitch
  final ClusterType type;
  final String? notation; // Notação específica
  final bool showBracket; // Mostrar colchete visual

  Cluster({
    required this.lowestPitch,
    required this.highestPitch,
    Pitch? lowestNote,
    Pitch? highestNote,
    this.type = ClusterType.chromatic,
    this.notation,
    this.showBracket = true,
  })  : lowestNote = lowestNote ?? lowestPitch,
        highestNote = highestNote ?? highestPitch;

  /// Retorna o glifo SMuFL apropriado
  String get glyphName {
    return 'noteheadClusterRoundWhite'; // Pode variar
  }
}
