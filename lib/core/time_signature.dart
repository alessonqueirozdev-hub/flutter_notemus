// lib/core/time_signature.dart

import 'musical_element.dart';

/// Um grupo aditivo dentro de uma fórmula de compasso aditiva.
///
/// Fórmulas como (3+2+2)/8 são representadas como uma lista de
/// [AdditiveMeterGroup] onde cada grupo tem um [numerator] e compartilha
/// o mesmo [denominator] da [TimeSignature] pai.
///
/// Corresponde ao elemento `<meterSigGrp>` do MEI v5 quando aplicado
/// a fórmulas aditivas.
class AdditiveMeterGroup {
  final int numerator;

  const AdditiveMeterGroup(this.numerator);
}

/// Representa a fórmula de compasso.
///
/// Suporta:
/// - Fórmulas simples: `TimeSignature(numerator: 4, denominator: 4)`
/// - Fórmulas compostas: `TimeSignature(numerator: 6, denominator: 8)`
/// - Tempo livre: `TimeSignature.free()`
/// - Fórmulas aditivas: `TimeSignature.additive(groups: [3,2,2], denominator: 8)`
class TimeSignature extends MusicalElement {
  final int numerator;
  final int denominator;

  /// Indica tempo livre (senza misura). Quando `true`, a fórmula é exibida
  /// como "X" ou omitida. Corresponde à ausência de `<meterSig>` no MEI v5.
  final bool isFreeTime;

  /// Grupos aditivos para fórmulas como (3+2+2)/8.
  /// Se não-nulo, substituem [numerator] como agrupamento de batidas.
  /// Corresponde a `<meterSigGrp>` no MEI v5.
  final List<AdditiveMeterGroup>? additiveGroups;

  TimeSignature({
    required this.numerator,
    required this.denominator,
    this.isFreeTime = false,
    this.additiveGroups,
  });

  /// Cria uma fórmula de tempo livre (senza misura).
  factory TimeSignature.free() =>
      TimeSignature(numerator: 0, denominator: 4, isFreeTime: true);

  /// Cria uma fórmula aditiva, ex.: (3+2+2)/8.
  ///
  /// ```dart
  /// TimeSignature.additive(groups: [3, 2, 2], denominator: 8)
  /// ```
  factory TimeSignature.additive({
    required List<int> groups,
    required int denominator,
  }) {
    final total = groups.fold(0, (a, b) => a + b);
    return TimeSignature(
      numerator: total,
      denominator: denominator,
      additiveGroups: groups.map(AdditiveMeterGroup.new).toList(),
    );
  }

  /// Calcula o valor total permitido no compasso.
  /// Fórmula: numerator × (1 / denominator). Retorna infinito para tempo livre.
  double get measureValue {
    if (isFreeTime) return double.infinity;
    return numerator * (1.0 / denominator);
  }

  /// Verifica se é um tempo simples.
  /// Exemplos: 2/4, 3/4, 4/4, 5/4, 7/8
  bool get isSimple {
    if (isFreeTime) return false;
    if (numerator == 3) return true;
    return numerator % 3 != 0;
  }

  /// Verifica se é um tempo composto.
  /// Exemplos: 6/8, 9/8, 12/8
  bool get isCompound => !isFreeTime && !isSimple && numerator > 3;

  /// Verifica se é uma fórmula aditiva.
  bool get isAdditive => additiveGroups != null && additiveGroups!.isNotEmpty;
}
