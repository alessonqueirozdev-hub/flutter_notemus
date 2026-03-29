// lib/core/figured_bass.dart

import 'musical_element.dart';

/// Sufixo de figure de bottom cifrado.
///
/// Correspwhere to the atributo `@ext` of the element `<f>` no MEI v5.
enum FigureSuffix {
  /// Nenhum sufixo
  none,
  /// Extension horizontal (extension line)
  extender,
  /// Barra diagonal descendente (crossing)
  slash,
  /// Backtick (tick mark)
  tick,
}

/// Sinal de alteração de a figure de bottom cifrado.
///
/// Correspwhere to the atributo `@accid` of the element `<f>` no MEI v5.
enum FigureAccidental {
  none,
  sharp,
  flat,
  natural,
  doubleSharp,
  doubleFlat,
}

/// Representa a única figure of the bottom cifrado, correspwherendo to the
/// elemento `<f>` (figure) within de `<fb>` no MEI v5.
///
/// ```dart
/// FigureElement(numeral: '6', accidental: FigureAccidental.sharp)
/// FigureElement(numeral: '4', suffix: FigureSuffix.slash)
/// ```
class FigureElement {
  /// Numeral of the figure (e.g., "2", "4", "6", "7", "9"). Can be null for
  /// figures with only accidental.
  final String? numeral;

  /// Alteração Applied to the figure.
  final FigureAccidental accidental;

  /// Sufixo of the figure (extension, barra, etc.).
  final FigureSuffix suffix;

  const FigureElement({
    this.numeral,
    this.accidental = FigureAccidental.none,
    this.suffix = FigureSuffix.none,
  });
}

/// Representa a indicação de bottom cifrado (thoroughbass / figured bass),
/// correspwherendo to the elemento `<fb>` (figured bass) of the MEI v5.
///
/// O bottom cifrado is a convenção de noteção barroca where numbers and accidentals
/// above or below de a note de bottom indicate quais harmonias must be
/// realizadas pelo instrumentista.
///
/// ```dart
/// FiguredBass(
///   figures: [
///     FigureElement(numeral: '6'),
///     FigureElement(numeral: '4', accidental: FigureAccidental.sharp),
///   ],
/// )
/// ```
class FiguredBass extends MusicalElement {
  /// Figures of the bottom cifrado, de top for bottom.
  final List<FigureElement> figures;

  /// Indicates if a realização must be displayed above the note (default = below).
  final bool above;

  FiguredBass({
    required this.figures,
    this.above = false,
  });
}
