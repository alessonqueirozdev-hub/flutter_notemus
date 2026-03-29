// lib/core/musical_element.dart

/// A class base for all os elementos in a partitura.
///
/// O field [xmlId] é o identificador único MEI (`xml:id`), used for
/// references cruzadas entre elementos (ex.: `@startid`, `@endid`, `@corresp`).
abstract class MusicalElement {
  /// Identificador único MEI (`xml:id`). Opcional; necessário for elementos
  /// referenciados por outros via atributos de ligação of the MEI v5.
  String? xmlId;
}

/// Descreve o estado de a note in relação a a barra de ligação (beam).
enum BeamType { start, inner, end }

/// Definess se a note inicia ou termina a tie (tie).
enum TieType { start, inner, end }

/// Definess se a note inicia ou termina a slur (slur).
enum SlurType { start, inner, end }

/// Modos de beaming for controle fino of the agrupamento
enum BeamingMode {
  /// Beaming automático based na fórmula de measure (default)
  automatic,

  /// Forçar flags individuais (sem beams)
  forceFlags,

  /// Agrupar all as notes possíveis in um único beam
  forceBeamAll,

  /// Beaming manual - Usesr apenas os grupos explicitamente definidos
  manual,

  /// Beaming conservador - apenas grupos óbvios (2 notes consecutivas)
  conservative,
}
