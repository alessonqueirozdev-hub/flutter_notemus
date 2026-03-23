// lib/core/key_signature.dart

import 'musical_element.dart';

/// Modo tonal, conforme o atributo `@mode` de `<staffDef>` no MEI v5.
enum KeyMode {
  major,
  minor,
  dorian,
  phrygian,
  lydian,
  mixolydian,
  aeolian,
  locrian,
  /// Armadura sem modo definido (ex.: música atonal, modal indeterminado)
  none,
}

/// Representa a armadura de clave.
///
/// [count] usa convenção MEI: positivo = sustenidos, negativo = bemóis.
/// [mode] corresponde ao atributo `@mode` de `<staffDef>` no MEI v5.
class KeySignature extends MusicalElement {
  /// Número de sustenidos (positivo) ou bemóis (negativo).
  final int count;

  /// Contagem da armadura anterior (para renderizar naturais de cancelamento).
  /// Positivo = sustenidos anteriores, negativo = bemóis anteriores.
  /// null = nenhum cancelamento necessário.
  final int? previousCount;

  /// Modo tonal associado à armadura (MEI `@mode`).
  /// null equivale a [KeyMode.none].
  final KeyMode? mode;

  KeySignature(this.count, {this.previousCount, this.mode});
}
