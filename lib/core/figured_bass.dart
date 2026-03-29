// lib/core/figured_bass.dart

import 'musical_element.dart';

/// Sufixo de figura de baixo cifrado.
///
/// Correspwhere ao atributo `@ext` of the element `<f>` no MEI v5.
enum FigureSuffix {
  /// Nenhum sufixo
  none,
  /// Extensão horizontal (linha de prolongamento)
  extender,
  /// Barra diagonal descendente (crossing)
  slash,
  /// Backtick (tick mark)
  tick,
}

/// Sinal de alteração de a figura de baixo cifrado.
///
/// Correspwhere ao atributo `@accid` of the element `<f>` no MEI v5.
enum FigureAccidental {
  none,
  sharp,
  flat,
  natural,
  doubleSharp,
  doubleFlat,
}

/// Representa a única figura of the baixo cifrado, correspwherendo ao
/// elemento `<f>` (figure) dentro de `<fb>` no MEI v5.
///
/// ```dart
/// FigureElement(numeral: '6', accidental: FigureAccidental.sharp)
/// FigureElement(numeral: '4', suffix: FigureSuffix.slash)
/// ```
class FigureElement {
  /// Numeral of the figura (ex.: "2", "4", "6", "7", "9"). Pode ser null for
  /// figuras with apenas accidental.
  final String? numeral;

  /// Alteração Appliesda à figura.
  final FigureAccidental accidental;

  /// Sufixo of the figura (extensão, barra, etc.).
  final FigureSuffix suffix;

  const FigureElement({
    this.numeral,
    this.accidental = FigureAccidental.none,
    this.suffix = FigureSuffix.none,
  });
}

/// Representa a indicação de baixo cifrado (thoroughbass / figured bass),
/// correspwherendo ao elemento `<fb>` (figured bass) of the MEI v5.
///
/// O baixo cifrado é a convenção de noteção barroca where numbers e accidentals
/// acima ou abaixo de a note de baixo indicam quais harmonias devem ser
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
  /// Figuras of the baixo cifrado, de cima for baixo.
  final List<FigureElement> figures;

  /// Indica se a realização deve ser exibida acima of the note (default = abaixo).
  final bool above;

  FiguredBass({
    required this.figures,
    this.above = false,
  });
}
