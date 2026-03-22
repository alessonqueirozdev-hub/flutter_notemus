// lib/core/key_signature.dart

import 'musical_element.dart';

/// Representa a armadura de clave.
class KeySignature extends MusicalElement {
  /// Número de sustenidos (positivo) ou bemóis (negativo).
  final int count;

  /// Contagem da armadura anterior (para renderizar naturais de cancelamento).
  /// Positivo = sustenidos anteriores, negativo = bemóis anteriores.
  /// null = nenhum cancelamento necessário.
  final int? previousCount;

  KeySignature(this.count, {this.previousCount});
}
