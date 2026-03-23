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

/// Tipo de sílaba para hifenização de letras de música.
///
/// Corresponde ao atributo `@con` do elemento `<syl>` no MEI v5:
/// - [single]: sílaba isolada (sem hifenização)
/// - [initial]: sílaba inicial de palavra hifenizada (ex.: "can-")
/// - [middle]: sílaba intermediária ("-ta-")
/// - [terminal]: sílaba final ("-te")
/// - [hyphen]: caractere de hífen explícito
enum SyllableType {
  /// Palavra completa / sílaba única (MEI `con` ausente ou "s")
  single,
  /// Sílaba inicial, seguida de hífen (MEI `con="i"`)
  initial,
  /// Sílaba intermediária (MEI `con="m"`)
  middle,
  /// Sílaba final (MEI `con="t"`)
  terminal,
  /// Hífen explícito (MEI `con="d"` — double bar extension)
  hyphen,
}

/// Representa uma sílaba de letra de música, correspondendo ao elemento
/// `<syl>` do MEI v5.
///
/// ```dart
/// Syllable(text: 'can', type: SyllableType.initial)  // "can-"
/// Syllable(text: 'ta', type: SyllableType.terminal)  // "-ta"
/// ```
class Syllable {
  /// Texto da sílaba.
  final String text;

  /// Tipo de conexão da sílaba (hifenização).
  final SyllableType type;

  /// Indica se o texto deve ser exibido em itálico (ex.: extensão de vogal).
  final bool italic;

  const Syllable({
    required this.text,
    this.type = SyllableType.single,
    this.italic = false,
  });
}

/// Representa um verso de letra, correspondendo ao elemento `<verse>` do MEI v5.
///
/// Suporta múltiplos versos numerados (`@n`) com sílabas [Syllable] individuais.
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
  /// Número do verso (MEI `@n`). Padrão = 1.
  final int number;

  /// Sílabas deste verso.
  final List<Syllable> syllables;

  /// Idioma do verso (MEI `@xml:lang`), ex.: 'la', 'pt', 'en'.
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
