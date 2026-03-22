// lib/core/key_signature.dart

import 'musical_element.dart';

/// Representa a armadura de clave.
class KeySignature extends MusicalElement {
  /// Número de sustenidos (positivo) ou bemóis (negativo).
  final int count;
  
  KeySignature(this.count);
}
