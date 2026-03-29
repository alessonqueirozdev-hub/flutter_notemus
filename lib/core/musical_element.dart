// lib/core/musical_element.dart

/// A class base for all os elementos in a partitura.
///
/// O field [xmlId] is o identificador único MEI (`xml:id`), used for
/// references cruzadas between elementos (e.g., `@startid`, `@endid`, `@corresp`).
abstract class MusicalElement {
  /// Identificador único MEI (`xml:id`). Opcional; required for elementos
  /// referenciados by other via atributos de ligação of the MEI v5.
  String? xmlId;
}

/// Descreve o estado de a note in relação a a barra de ligação (beam).
enum BeamType { start, inner, end }

/// Definess if a note inicia or ends a tie (tie).
enum TieType { start, inner, end }

/// Definess if a note inicia or ends a slur (slur).
enum SlurType { start, inner, end }

/// Modos de beaming for control fino of the agrupamento
enum BeamingMode {
  /// Beaming automático based na fórmula de measure (default)
  automatic,

  /// Forçar flags individuais (sem beams)
  forceFlags,

  /// Agrupar all as notes possible in a único beam
  forceBeamAll,

  /// Beaming manual - Use only os grupos explicitamente definidos
  manual,

  /// Beaming conservador - only grupos óbvios (2 notes consecutivas)
  conservative,
}
