// lib/core/musical_element.dart

/// A classe base para todos os elementos em uma partitura.
abstract class MusicalElement {}

/// Descreve o estado de uma nota em relação a uma barra de ligação (beam).
enum BeamType { start, inner, end }

/// Define se uma nota inicia ou termina uma ligadura de valor (tie).
enum TieType { start, end }

/// Define se uma nota inicia ou termina uma ligadura de expressão (slur).
enum SlurType { start, end }

/// Modos de beaming para controle fino do agrupamento
enum BeamingMode {
  /// Beaming automático baseado na fórmula de compasso (padrão)
  automatic,

  /// Forçar flags individuais (sem beams)
  forceFlags,

  /// Agrupar todas as notas possíveis em um único beam
  forceBeamAll,

  /// Beaming manual - usar apenas os grupos explicitamente definidos
  manual,

  /// Beaming conservador - apenas grupos óbvios (2 notas consecutivas)
  conservative,
}
