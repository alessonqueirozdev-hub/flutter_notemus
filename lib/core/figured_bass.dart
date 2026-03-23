// lib/core/figured_bass.dart

import 'musical_element.dart';

/// Sufixo de figura de baixo cifrado.
///
/// Corresponde ao atributo `@ext` do elemento `<f>` no MEI v5.
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

/// Sinal de alteração de uma figura de baixo cifrado.
///
/// Corresponde ao atributo `@accid` do elemento `<f>` no MEI v5.
enum FigureAccidental {
  none,
  sharp,
  flat,
  natural,
  doubleSharp,
  doubleFlat,
}

/// Representa uma única figura do baixo cifrado, correspondendo ao
/// elemento `<f>` (figure) dentro de `<fb>` no MEI v5.
///
/// ```dart
/// FigureElement(numeral: '6', accidental: FigureAccidental.sharp)
/// FigureElement(numeral: '4', suffix: FigureSuffix.slash)
/// ```
class FigureElement {
  /// Numeral da figura (ex.: "2", "4", "6", "7", "9"). Pode ser null para
  /// figuras com apenas acidente.
  final String? numeral;

  /// Alteração aplicada à figura.
  final FigureAccidental accidental;

  /// Sufixo da figura (extensão, barra, etc.).
  final FigureSuffix suffix;

  const FigureElement({
    this.numeral,
    this.accidental = FigureAccidental.none,
    this.suffix = FigureSuffix.none,
  });
}

/// Representa uma indicação de baixo cifrado (thoroughbass / figured bass),
/// correspondendo ao elemento `<fb>` (figured bass) do MEI v5.
///
/// O baixo cifrado é uma convenção de notação barroca onde números e acidentes
/// acima ou abaixo de uma nota de baixo indicam quais harmonias devem ser
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
  /// Figuras do baixo cifrado, de cima para baixo.
  final List<FigureElement> figures;

  /// Indica se a realização deve ser exibida acima da nota (padrão = abaixo).
  final bool above;

  FiguredBass({
    required this.figures,
    this.above = false,
  });
}
