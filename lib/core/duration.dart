// lib/src/music_model/duration.dart

/// Definess os tipos de duração rhythmic.
///
/// Includes all as durações of the MEI v5: de [maxima] (8 semibreves) a
/// [twoThoUsesndFortyEighth] (1/2048 de semibreve).
enum DurationType {
  // === Durações longas (noteção mensural / histórica) ===
  /// Maxima — 8 semibreves (MEI `dur="maxima"`)
  maxima(8.0, 'noteheadWhole'),
  /// Longa — 4 semibreves (MEI `dur="long"`)
  long(4.0, 'noteheadWhole'),
  /// Breve — 2 semibreves (MEI `dur="breve"`)
  breve(2.0, 'noteDoubleWhole'),

  // === Durações modernas (CMN) ===
  whole(1.0, 'noteheadWhole'), // semibreve = 1
  half(0.5, 'noteheadHalf'), // mínima = 1/2
  quarter(0.25, 'noteheadBlack'), // semínima = 1/4
  eighth(0.125, 'noteheadBlack'), // colcheia = 1/8
  sixteenth(0.0625, 'noteheadBlack'), // semicolcheia = 1/16
  thirtySecond(0.03125, 'noteheadBlack'), // fusa = 1/32
  sixtyFourth(0.015625, 'noteheadBlack'), // semifusa = 1/64
  oneHundredTwentyEighth(0.0078125, 'noteheadBlack'), // 1/128

  // === Durações ultra-curtas (MEI `dur="256"` a `dur="2048"`) ===
  /// 1/256 de semibreve (MEI `dur="256"`)
  twoHundredFiftySixth(0.00390625, 'noteheadBlack'),
  /// 1/512 de semibreve (MEI `dur="512"`)
  fiveHundredTwelfth(0.001953125, 'noteheadBlack'),
  /// 1/1024 de semibreve (MEI `dur="1024"`)
  thousandTwentyFourth(0.0009765625, 'noteheadBlack'),
  /// 1/2048 de semibreve (MEI `dur="2048"`)
  twoThousandFortyEighth(0.00048828125, 'noteheadBlack');

  /// O value numérico relativo to the semibreve (semibreve = 1.0).
  final double value;

  /// O glyph name SMuFL for a cabeça of the note.
  final String glyphName;

  const DurationType(this.value, this.glyphName);

  /// O glyph name SMuFL for a paUses correspwherente a this duração.
  String get restGlyphName => switch (this) {
    DurationType.maxima => 'restMaxima',
    DurationType.long => 'restLonga',
    DurationType.breve => 'restDoubleWhole',
    DurationType.whole => 'restWhole',
    DurationType.half => 'restHalf',
    DurationType.quarter => 'restQuarter',
    DurationType.eighth => 'rest8th',
    DurationType.sixteenth => 'rest16th',
    DurationType.thirtySecond => 'rest32nd',
    DurationType.sixtyFourth => 'rest64th',
    DurationType.oneHundredTwentyEighth => 'rest128th',
    DurationType.twoHundredFiftySixth => 'rest256th',
    DurationType.fiveHundredTwelfth => 'rest512th',
    DurationType.thousandTwentyFourth => 'rest1024th',
    DurationType.twoThousandFortyEighth => 'rest2048th',
  };

  /// If notes desta duração need de stem.
  bool get needsStem =>
      this != DurationType.whole &&
      this != DurationType.breve &&
      this != DurationType.long &&
      this != DurationType.maxima;

  /// If notes desta duração need de bandeirola (flag).
  bool get needsFlag => value <= DurationType.eighth.value;

  /// If a cabeça desta note is preenchida (semínima in diante).
  bool get isFilled => value <= DurationType.quarter.value;

  /// Returns o value MEI `dur` as string (e.g., "4", "8", "breve", "long").
  String get meiDurValue => switch (this) {
    DurationType.maxima => 'maxima',
    DurationType.long => 'long',
    DurationType.breve => 'breve',
    DurationType.whole => '1',
    DurationType.half => '2',
    DurationType.quarter => '4',
    DurationType.eighth => '8',
    DurationType.sixteenth => '16',
    DurationType.thirtySecond => '32',
    DurationType.sixtyFourth => '64',
    DurationType.oneHundredTwentyEighth => '128',
    DurationType.twoHundredFiftySixth => '256',
    DurationType.fiveHundredTwelfth => '512',
    DurationType.thousandTwentyFourth => '1024',
    DurationType.twoThousandFortyEighth => '2048',
  };

  /// Constrói a [DurationType] a partir of the value MEI `dur` (string).
  static DurationType fromMeiValue(String meiDur) {
    return switch (meiDur) {
      'maxima' => DurationType.maxima,
      'long'   => DurationType.long,
      'breve'  => DurationType.breve,
      '1'      => DurationType.whole,
      '2'      => DurationType.half,
      '4'      => DurationType.quarter,
      '8'      => DurationType.eighth,
      '16'     => DurationType.sixteenth,
      '32'     => DurationType.thirtySecond,
      '64'     => DurationType.sixtyFourth,
      '128'    => DurationType.oneHundredTwentyEighth,
      '256'    => DurationType.twoHundredFiftySixth,
      '512'    => DurationType.fiveHundredTwelfth,
      '1024'   => DurationType.thousandTwentyFourth,
      '2048'   => DurationType.twoThousandFortyEighth,
      _        => throw ArgumentError('Valor MEI dur inválido: $meiDur'),
    };
  }
}

/// Representa a duração de a note or paUses.
class Duration {
  /// O type de duração (semibreve, mínima, etc.).
  final DurationType type;

  /// O number de points de aumento.
  final int dots;

  const Duration(this.type, {this.dots = 0});

  /// Calculates a duração real incluindo points de aumento.
  ///
  /// Alias for [absoluteValue].
  double get realValue => absoluteValue;

  /// Calculates a duração real incluindo points de aumento.
  /// Fórmula: valor_original + (valor_original * 0.5^1) + (valor_original * 0.5^2) + ...
  double get absoluteValue {
    double value = type.value;
    double addedValue = 0;
    double currentDot = type.value * 0.5;

    for (int i = 0; i < dots; i++) {
      addedValue += currentDot;
      currentDot *= 0.5;
    }

    return value + addedValue;
  }
}
