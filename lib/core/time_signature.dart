// lib/core/time_signature.dart

import 'musical_element.dart';

/// Representa a fórmula de compasso.
class TimeSignature extends MusicalElement {
  final int numerator;
  final int denominator;
  
  TimeSignature({required this.numerator, required this.denominator});

  /// Calcula o valor total permitido no compasso.
  /// Fórmula: numerator × (1 / denominator)
  double get measureValue => numerator * (1.0 / denominator);
  
  /// Verifica se é um tempo simples
  /// Tempo simples: numerador não é múltiplo de 3 (exceto 3 em si)
  /// Exemplos: 2/4, 3/4, 4/4, 5/4, 7/8
  bool get isSimple {
    if (numerator == 3) return true; // 3/4 é simples
    return numerator % 3 != 0; // Não é múltiplo de 3
  }
  
  /// Verifica se é um tempo composto
  /// Tempo composto: numerador é múltiplo de 3 e maior que 3
  /// Exemplos: 6/8, 9/8, 12/8
  bool get isCompound => !isSimple && numerator > 3;
}
