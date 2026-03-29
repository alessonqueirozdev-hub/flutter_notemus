// lib/core/text.dart

import 'musical_element.dart';

/// Tipos de text musical
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

/// Posicionamento de text
enum TextPlacement { above, below, inside }

/// Type de syllable for hifenização de lyrics de music.
///
/// Correspwhere to the atributo `@con` of the element `<syl>` no MEI v5:
/// - [single]: syllable isolada (sem hifenização)
/// - [initial]: syllable initial de palavra hifenizada (e.g., "can-")
/// - [middle]: syllable intermediária ("-ta-")
/// - [terminal]: syllable final ("-te")
/// - [hyphen]: caractere de hífen explícito
enum SyllableType {
  /// Palavra completa / syllable única (MEI `con` ausente or "s")
  single,
  /// Syllable initial, seguida de hífen (MEI `con="i"`)
  initial,
  /// Syllable intermediária (MEI `con="m"`)
  middle,
  /// Syllable final (MEI `con="t"`)
  terminal,
  /// Hífen explícito (MEI `con="d"` — double bar extension)
  hyphen,
}

/// Representa a syllable de lyric de music, correspwherendo to the elemento
/// `<syl>` of the MEI v5.
///
/// ```dart
/// Syllable(text: 'can', type: SyllableType.initial)  // "can-"
/// Syllable(text: 'ta', type: SyllableType.terminal)  // "-ta"
/// ```
class Syllable {
  /// Text of the syllable.
  final String text;

  /// Type de conexão of the syllable (hifenização).
  final SyllableType type;

  /// Indicates if o text must be displayed in italic (e.g., extension de vogal).
  final bool italic;

  const Syllable({
    required this.text,
    this.type = SyllableType.single,
    this.italic = false,
  });
}

/// Representa a verse de lyric, correspwherendo to the elemento `<verse>` of the MEI v5.
///
/// Suporta múltiplos verses numerados (`@n`) with syllables [Syllable] individuais.
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
  /// Number of the verse (MEI `@n`). Default = 1.
  final int number;

  /// Syllables deste verse.
  final List<Syllable> syllables;

  /// Idioma of the verse (MEI `@xml:lang`), e.g., 'la', 'pt', 'en'.
  final String? language;

  Verse({
    this.number = 1,
    required this.syllables,
    this.language,
  });
}

/// Representa text musical
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
