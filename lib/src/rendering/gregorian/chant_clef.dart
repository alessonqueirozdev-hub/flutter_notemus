// Chant clef model (do/fa on a staff line) and the mid-score clef CHANGE
// element, kept deliberately FLUTTER-FREE.
//
// Both the square-notation renderer (which needs dart:ui) and the pure-Dart
// chant→MIDI mapper have to agree on what a clef is: the clef fixes where "do"
// (or "fa") falls, hence which staff slot sounds as which pitch, and its
// optional clef-flat is a key-signature-like soft si-flat. Putting the model in
// its own leaf library lets `ChantMidiMapper` react to a clef change without
// dragging Flutter into the MIDI layer.
//
// Spec: Gregorio GABC — clef tokens `c1..c4` (do clef) and `f1..f4` (fa clef),
// with `cb`/`fb` adding the clef-flat; a clef token may appear anywhere in the
// score, and every token after the first one is a CLEF CHANGE that re-anchors
// the notes that follow it.

import '../../../core/musical_element.dart';

/// Which chant clef: the do (C) clef or the fa (F) clef.
enum ChantClefType { doClef, faClef }

/// A Gregorian chant clef: a do/fa sign sitting on one of the four staff lines,
/// optionally carrying a clef-flat.
class ChantClef {
  final ChantClefType type;

  /// Staff line the clef sits on, 1 (bottom) .. 4 (top). Default: top line.
  final int line;

  /// Clef-flat (GABC `cb`/`fb`): a soft B-flat in force like a key signature
  /// (every si is flat until cancelled by a natural). Drawn just after the clef.
  final bool flat;

  const ChantClef({
    this.type = ChantClefType.doClef,
    this.line = 4,
    this.flat = false,
  });

  String get glyphName => type == ChantClefType.doClef ? 'CClef' : 'FClef';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChantClef &&
          other.type == type &&
          other.line == line &&
          other.flat == flat);

  @override
  int get hashCode => Object.hash(type, line, flat);

  @override
  String toString() =>
      'ChantClef(${type == ChantClefType.doClef ? 'c' : 'f'}'
      '${flat ? 'b' : ''}$line)';
}

/// A clef change **inside** the chant: an element in the same
/// `List<MusicalElement>` stream as [Neume]/[NeumeDivision], marking the point
/// from which a new [clef] governs.
///
/// GABC writes a clef as an ordinary `(...)` token, so a chant may re-clef in
/// the middle of a piece (typically to keep a rising melody on the staff). The
/// first clef token of a document is the score's initial clef and is reported by
/// `GabcResult.clef`; every later one is emitted as a [ChantClefChange] in
/// document order so that:
///
///  * `GregorianLayout.build` re-anchors the staff positions of the notes that
///    follow (without it, every later note would be drawn against the initial
///    clef and appear transposed), and draws the new clef sign in place;
///  * `ChantMidiMapper` picks up the new clef-flat for playback.
///
/// The sounding pitch of the notes after the change is resolved by the importer
/// (`GabcParser`), which already knows the active clef when it turns staff slots
/// into pitch names; this element carries the clef so downstream consumers can
/// react to it too.
class ChantClefChange extends MusicalElement {
  final ChantClef clef;

  ChantClefChange(this.clef);

  @override
  String toString() => 'ChantClefChange($clef)';
}
