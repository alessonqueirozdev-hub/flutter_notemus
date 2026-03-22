// lib/src/music_model/duration.dart

/// Define os tipos de duração rítmica.
enum DurationType {
  whole(1.0, 'noteheadWhole'), // semibreve = 1
  half(0.5, 'noteheadHalf'), // mínima = 1/2
  quarter(0.25, 'noteheadBlack'), // semínima = 1/4
  eighth(0.125, 'noteheadBlack'), // colcheia = 1/8
  sixteenth(0.0625, 'noteheadBlack'), // semicolcheia = 1/16
  thirtySecond(0.03125, 'noteheadBlack'), // fusa = 1/32
  sixtyFourth(0.015625, 'noteheadBlack'), // semifusa = 1/64
  oneHundredTwentyEighth(0.0078125, 'noteheadBlack'); // 1/128

  /// O valor numérico relativo à semibreve (semibreve = 1.0).
  final double value;

  /// O nome do glifo SMuFL para a cabeça da nota.
  final String glyphName;

  const DurationType(this.value, this.glyphName);
}

/// Representa a duração de uma nota ou pausa.
class Duration {
  /// O tipo de duração (semibreve, mínima, etc.).
  final DurationType type;

  /// O número de pontos de aumento.
  final int dots;

  const Duration(this.type, {this.dots = 0});

  /// Calcula a duração real incluindo pontos de aumento.
  /// Fórmula: valor_original + (valor_original * 0.5^1) + (valor_original * 0.5^2) + ...
  double get realValue {
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
