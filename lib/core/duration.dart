// lib/src/music_model/duration.dart

/// Define os tipos de duração rítmica.
///
/// Inclui todas as durações do MEI v5: de [maxima] (8 semibreves) a
/// [twoThousandFortyEighth] (1/2048 de semibreve).
enum DurationType {
  // === Durações longas (notação mensural / histórica) ===
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

  /// O valor numérico relativo à semibreve (semibreve = 1.0).
  final double value;

  /// O nome do glifo SMuFL para a cabeça da nota.
  final String glyphName;

  const DurationType(this.value, this.glyphName);

  /// O nome do glifo SMuFL para a pausa correspondente a esta duração.
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

  /// Se as notas desta duração precisam de haste (stem).
  bool get needsStem =>
      this != DurationType.whole &&
      this != DurationType.breve &&
      this != DurationType.long &&
      this != DurationType.maxima;

  /// Se as notas desta duração precisam de bandeirola (flag).
  bool get needsFlag => value <= DurationType.eighth.value;

  /// Se a cabeça desta nota é preenchida (semínima em diante).
  bool get isFilled => value <= DurationType.quarter.value;

  /// Retorna o valor MEI `dur` como string (ex.: "4", "8", "breve", "long").
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

/// A rhythmic duration: a [DurationType] plus augmentation dots.
///
/// ## Why this type has two names
///
/// This class is exported by `package:flutter_notemus/flutter_notemus.dart`
/// under BOTH `MusicDuration` and the legacy alias [Duration]. `MusicDuration`
/// is the canonical name and the one to use in new code.
///
/// The legacy name shadows `dart:core.Duration` for anyone importing the
/// package barrel, which is a real and repeatedly-hit trap:
///
/// ```dart
/// import 'package:flutter_notemus/flutter_notemus.dart';
///
/// Timeout(Duration(minutes: 5));   // does NOT compile: this is the music one
/// Future.delayed(Duration(seconds: 1));  // same
/// ```
///
/// Two ways out, both supported today:
///
/// ```dart
/// // 1. Keep the time Duration, name the music one explicitly.
/// import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;
/// final quarter = MusicDuration(DurationType.quarter);
/// await Future.delayed(const Duration(seconds: 1));   // dart:core, unshadowed
///
/// // 2. Prefix the package.
/// import 'package:flutter_notemus/flutter_notemus.dart' as notemus;
/// final quarter = notemus.MusicDuration(notemus.DurationType.quarter);
/// ```
///
/// The [Duration] alias is kept so that no existing code breaks. It is
/// scheduled to stop being exported in 3.0; `MusicDuration` will remain. There
/// is no deprecation annotation on it yet precisely because that would emit a
/// warning at every one of the several hundred call sites inside this package
/// and in every app using it, before there is a major version to land the
/// removal in.
class MusicDuration {
  /// O tipo de duração (semibreve, mínima, etc.).
  final DurationType type;

  /// O número de pontos de aumento.
  final int dots;

  const MusicDuration(this.type, {this.dots = 0});

  /// Calcula a duração real incluindo pontos de aumento.
  ///
  /// Alias para [absoluteValue].
  double get realValue => absoluteValue;

  /// Calcula a duração real incluindo pontos de aumento.
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

  /// Duas durações são iguais quando têm o mesmo [type] e o mesmo número
  /// de [dots].
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MusicDuration &&
        other.type == type &&
        other.dots == dots;
  }

  @override
  int get hashCode => Object.hash(type, dots);

  /// Representação legível, ex.: `MusicDuration(quarter)` ou `MusicDuration(half..)`.
  @override
  String toString() => 'MusicDuration(${type.name}${'.' * dots})';
}

/// Legacy alias for [MusicDuration].
///
/// Kept so that existing code — including the several hundred call sites inside
/// this package — keeps compiling unchanged. It SHADOWS `dart:core.Duration`
/// for anyone importing the package barrel; see [MusicDuration] for the two
/// supported ways around that.
///
/// Scheduled to stop being exported in 3.0.
typedef Duration = MusicDuration;
