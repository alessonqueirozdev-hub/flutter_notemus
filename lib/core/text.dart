// lib/core/text.dart

import 'musical_element.dart';

/// Tipos de texto musical
enum TextType {
  lyrics,
  chord,
  rehearsal,
  tempo,
  expression,
  instruction,
  copyright,
  title,
  subtitle,
  composer,
  arranger,
  dynamics,
  dedication,
  rights,
  partName,
  instrument,
}

/// Posicionamento de texto
enum TextPlacement { above, below, inside }

/// Type de syllable for hifenização de letras de música.
///
/// Correspwhere ao atributo `@con` of the element `<syl>` no MEI v5:
/// - [single]: syllable isolada (sem hifenização)
/// - [initial]: syllable inicial de palavra hifenizada (ex.: "can-")
/// - [middle]: syllable intermediária ("-ta-")
/// - [terminal]: syllable final ("-te")
/// - [hyphen]: caractere de hífen explícito
enum SyllableType {
  /// Palavra completa / syllable única (MEI `con` ausente ou "s")
  single,
  /// Syllable inicial, seguida de hífen (MEI `con="i"`)
  initial,
  /// Syllable intermediária (MEI `con="m"`)
  middle,
  /// Syllable final (MEI `con="t"`)
  terminal,
  /// Hífen explícito (MEI `con="d"` — double bar extension)
  hyphen,
}

/// Representa a syllable de letra de música, correspwherendo ao elemento
/// `<syl>` of the MEI v5.
///
/// ```dart
/// Syllable(text: 'can', type: SyllableType.initial)  // "can-"
/// Syllable(text: 'ta', type: SyllableType.terminal)  // "-ta"
/// ```
class Syllable {
  /// Texto of the syllable.
  final String text;

  /// Type de conexão of the syllable (hifenização).
  final SyllableType type;

  /// Indica se o texto deve ser exibido in itálico (ex.: extensão de vogal).
  final bool italic;

  const Syllable({
    required this.text,
    this.type = SyllableType.single,
    this.italic = false,
  });
}

/// Representa um verso de letra, correspwherendo ao elemento `<verse>` of the MEI v5.
///
/// Suporta múltiplos versos numerados (`@n`) with syllables [Syllable] individuais.
///
/// ```dart
/// Verse(
///   number: 1,
///   syllables: [
///     Syllable(text: 'A-', type: SyllableType.initial),
///     Syllable(text: 've', type: SyllableType.terminal),
///   ],
/// )
/// ```
class Verse extends MusicalElement {
  /// Number of the verso (MEI `@n`). Default = 1.
  final int number;

  /// Syllables deste verso.
  final List<Syllable> syllables;

  /// Idioma of the verso (MEI `@xml:lang`), ex.: 'la', 'pt', 'en'.
  final String? language;

  Verse({
    this.number = 1,
    required this.syllables,
    this.language,
  });
}

/// Representa texto musical
class MusicText extends MusicalElement {
  final String text;
  final TextType type;
  final TextPlacement placement;
  final String? fontFamily;
  final double? fontSize;
  final bool? bold;
  final bool? italic;

  MusicText({
    required this.text,
    required this.type,
    this.placement = TextPlacement.above,
    this.fontFamily,
    this.fontSize,
    this.bold,
    this.italic,
  });
}
