// lib/core/time_signature.dart

import 'musical_element.dart';

/// Um grupo aditivo dentro de a fórmula de measure aditiva.
///
/// Fórmulas como (3+2+2)/8 are representadas como a list of
/// [AdditiveMeterGroup] where each grupo tem um [numerator] e compartilha
/// o mesmo [denominator] of the [TimeSignature] pai.
///
/// Correspwhere ao elemento `<meterSigGrp>` of the MEI v5 when Appliesdo
/// a fórmulas aditivas.
class AdditiveMeterGroup {
  final int numerator;

  const AdditiveMeterGroup(this.numerator);
}

/// Representa a fórmula de measure.
///
/// Suporta:
/// - Fórmulas simples: `TimeSignature(numerator: 4, denominator: 4)`
/// - Fórmulas compostas: `TimeSignature(numerator: 6, denominator: 8)`
/// - Tempo livre: `TimeSignature.free()`
/// - Fórmulas aditivas: `TimeSignature.additive(groups: [3,2,2], denominator: 8)`
class TimeSignature extends MusicalElement {
  final int numerator;
  final int denominator;

  /// Indica tempo livre (senza misura). When `true`, a fórmula é exibida
  /// como "X" ou omitida. Correspwhere à ausência de `<meterSig>` no MEI v5.
  final bool isFreeTime;

  /// Grupos aditivos for fórmulas como (3+2+2)/8.
  /// When not null, overrides [numerator] as the beat grouping.
  /// Correspwhere a `<meterSigGrp>` no MEI v5.
  final List<AdditiveMeterGroup>? additiveGroups;

  TimeSignature({
    required this.numerator,
    required this.denominator,
    this.isFreeTime = false,
    this.additiveGroups,
  });

  /// Creates a fórmula de tempo livre (senza misura).
  factory TimeSignature.free() =>
      TimeSignature(numerator: 0, denominator: 4, isFreeTime: true);

  /// Creates a fórmula aditiva, ex.: (3+2+2)/8.
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

  /// Calculatestes o value total permitido no measure.
  /// Fórmula: numerator × (1 / denominator). Returns infinito for tempo livre.
  double get measureValue {
    if (isFreeTime) return double.infinity;
    return numerator * (1.0 / denominator);
  }

  /// Checks se é um tempo simples.
  /// Examples: 2/4, 3/4, 4/4, 5/4, 7/8
  bool get isSimple {
    if (isFreeTime) return false;
    if (numerator == 3) return true;
    return numerator % 3 != 0;
  }

  /// Checks se é um tempo composto.
  /// Examples: 6/8, 9/8, 12/8
  bool get isCompound => !isFreeTime && !isSimple && numerator > 3;

  /// Checks se é a fórmula aditiva.
  bool get isAdditive => additiveGroups != null && additiveGroups!.isNotEmpty;
}
