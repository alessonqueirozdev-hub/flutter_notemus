// lib/core/key_signature.dart

import '../src/rendering/accidental_resolver.dart';
import 'musical_element.dart';
import 'pitch.dart';

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

  /// Contagem of the armadura previous (for renderizar naturais de cancelamento).
  /// Positivo = sharps previouses, negativo = bemóis previouses.
  /// null = nenhum cancelamento required.
  final int? previousCount;

  /// Modo tonal associado to the armadura (MEI `@mode`).
  /// null equivale a [KeyMode.none].
  final KeyMode? mode;

  /// The chromatic alteration this key applies to the diatonic [step], as a
  /// `Pitch.alter` value: `1.0` for a sharp, `-1.0` for a flat, `0.0` for a
  /// step the key leaves alone.
  ///
  /// This exists because of a trap that caught this package's own flagship
  /// example. `Pitch.alter` is the SOUNDING alteration (ADR-003) and defaults
  /// to `0.0`, so `Pitch(step: 'F', octave: 5)` is an F NATURAL — even under a
  /// two-sharp key signature. Writing a piece in D major therefore means
  /// spelling `alter: 1.0` on every F and every C, and forgetting to is not a
  /// rendering bug: the engraver correctly prints a natural on each one to
  /// cancel the key, which is exactly what the model asked for.
  ///
  /// `complete_music_piece.dart` did forget, and printed a natural in front of
  /// nearly every F in a D-major piece. Nothing was wrong with the resolver —
  /// measured, it hides the accidental on the first F when the pitch really is
  /// F sharp, and cancels correctly when it is not.
  ///
  /// So write it this way instead:
  ///
  /// ```dart
  /// const key = KeySignature(2); // D major
  /// Pitch(step: 'F', octave: 5, alter: key.alterFor('F')); // F sharp
  /// ```
  double alterFor(String step) =>
      AccidentalResolver.keyAlterForStep(step, count).toDouble();

  /// A [Pitch] on [step]/[octave] spelled as this key signature implies.
  ///
  /// The short form of [alterFor] for the common case: a note that simply
  /// belongs to the key. Pass an explicit `alter` to [Pitch] instead when the
  /// note deliberately departs from it.
  Pitch pitch(String step, int octave) =>
      Pitch(step: step, octave: octave, alter: alterFor(step));


  KeySignature(this.count, {this.previousCount, this.mode});
}
