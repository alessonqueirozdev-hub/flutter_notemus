// lib/src/beaming/beam_types.dart

/// Direção da haste (stem) de uma nota
enum StemDirection {
  /// Haste para cima (stem up)
  up,
  
  /// Haste para baixo (stem down)
  down,
  
  /// Sem haste (para notas inteiras/breves ou casos especiais)
  none,
}

/// Tipo de inclinação do beam
enum BeamSlope {
  /// Beam horizontal (mesma altura nas duas pontas)
  horizontal,
  
  /// Beam ascendente (subindo da esquerda para direita)
  ascending,
  
  /// Beam descendente (descendo da esquerda para direita)
  descending,
}

/// Posição do beam em relação às linhas da pauta
enum BeamLineAttachment {
  /// Beam pendurado embaixo da linha (hastes para cima)
  hanging,
  
  /// Beam centrado na linha
  centered,
  
  /// Beam sentado em cima da linha (hastes para baixo)
  sitting,
}
