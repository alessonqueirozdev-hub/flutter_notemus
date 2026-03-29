// lib/core/key_signature.dart

import 'musical_element.dart';

/// Modo tonal, according to o atributo `@mode` de `<staffDef>` no MEI v5.
enum KeyMode {
  major,
  minor,
  dorian,
  phrygian,
  lydian,
  mixolydian,
  aeolian,
  locrian,
  /// Armadura sem modo defined (e.g., music atonal, modal indeterminado)
  none,
}

/// Representa a armadura de clef.
///
/// [count] Uses convenção MEI: positivo = sharps, negativo = bemóis.
/// [mode] correspwhere to the atributo `@mode` de `<staffDef>` no MEI v5.
class KeySignature extends MusicalElement {
  /// Number de sharps (positivo) or bemóis (negativo).
  final int count;

  /// Contagem of the armadura previous (for Rendersr naturais de cancelamento).
  /// Positivo = sharps previouses, negativo = bemóis previouses.
  /// null = nenhum cancelamento required.
  final int? previousCount;

  /// Modo tonal associado to the armadura (MEI `@mode`).
  /// null equivale a [KeyMode.none].
  final KeyMode? mode;

  KeySignature(this.count, {this.previousCount, this.mode});
}
