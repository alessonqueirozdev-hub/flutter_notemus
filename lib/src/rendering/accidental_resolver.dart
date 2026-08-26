// Within-measure accidental persistence (Behind Bars / Gould).
//
// In CMN an accidental is shown only on the FIRST occurrence of an altered
// pitch (same step+octave) within a measure; later identical notes show none; a
// note reverting to its key-signature/diatonic value mid-measure gets an
// auto-natural; the state resets at every barline. Two exceptions apply:
// cautionary/editorial (bracketed) accidentals are always engraved, and the
// destination of a tie never takes a fresh accidental. This resolver computes
// that decision per note from the MODEL (independent of layout), so both the
// layout width reservation and the renderer agree.

import '../../core/core.dart';

/// What to draw for a note's accidental after measure-context resolution.
enum AccidentalDisplay {
  /// Draw nothing (the alteration is already in force this measure).
  hide,

  /// Draw the note's own accidental (sharp/flat/double…).
  show,

  /// Draw a natural — the pitch reverts to natural against an active alteration.
  natural,
}

class AccidentalResolver {
  /// Resolves the display decision for every [Note] in [measures] (identity-
  /// keyed), applying the standard within-measure rule and the active key
  /// signature (which persists across measures until changed).
  ///
  /// Rules implemented (Gould, *Behind Bars*, chapter "Accidentals"):
  ///
  /// * **Persistence within the bar.** An accidental holds for the rest of the
  ///   measure at the same step *and* octave; identical later pitches are
  ///   drawn bare. A pitch returning to its key-signature value against an
  ///   active alteration gets an auto-natural.
  /// * **Reset at every barline.** [state] is created inside the per-measure
  ///   loop, so nothing survives a barline; only the key signature persists
  ///   across measures (until another [KeySignature] changes it).
  /// * **Unisons in a chord.** Two notes of the same [Chord] sharing step and
  ///   octave share one entry in [state], so the accidental is engraved once
  ///   (on the first of the two) and suppressed on the duplicate.
  /// * **Cautionary / editorial accidentals are never suppressed.** See
  ///   [_decide].
  /// * **Ties across a barline.** See [_decide].
  ///
  /// Voice ordering in a [MultiVoiceMeasure]: the measure-level elements are
  /// processed first (they carry the clef/key that opens the bar), then the
  /// voices in ascending voice number (`sortedVoices`). All voices of one
  /// measure share a single [state] map, which is what CMN prescribes — an
  /// accidental in voice 1 holds for voice 2 at the same pitch in the same bar.
  /// A [KeySignature] appearing *inside* a voice, however, is scoped to that
  /// voice: every voice starts from the key established by the measure-level
  /// elements, so a mid-voice key change cannot leak sideways into a sibling
  /// voice. For the following measures the key carried forward is the one
  /// declared by the lowest-numbered voice that changed it (voice 1 wins),
  /// falling back to the measure-level key when no voice changed it.
  static Map<Note, AccidentalDisplay> resolve(List<Measure> measures) {
    final result = Map<Note, AccidentalDisplay>.identity();
    var keyCount = 0;

    for (final measure in measures) {
      // step+octave -> alteration currently sounding this measure.
      final state = <String, int>{};

      // Processes [elements] under key signature [key] and returns the key
      // signature in force after them (a [KeySignature] element may change it).
      int process(List<MusicalElement> elements, int key) {
        var activeKey = key;
        for (final el in elements) {
          if (el is KeySignature) {
            activeKey = el.count;
          } else if (el is Note) {
            _decide(el, state, activeKey, result);
          } else if (el is Chord) {
            for (final n in el.notes) {
              _decide(n, state, activeKey, result);
            }
          } else if (el is Tuplet) {
            activeKey = process(el.elements, activeKey);
          }
        }
        return activeKey;
      }

      if (measure is MultiVoiceMeasure) {
        final measureKey = process(measure.elements, keyCount);
        int? carriedKey;
        for (final voice in measure.sortedVoices) {
          final voiceKey = process(voice.elements, measureKey);
          if (carriedKey == null && voiceKey != measureKey) {
            carriedKey = voiceKey;
          }
        }
        keyCount = carriedKey ?? measureKey;
      } else {
        keyCount = process(measure.elements, keyCount);
      }
    }
    return result;
  }

  /// Decides what to draw for a single [note] and updates the measure [state].
  ///
  /// Order of the rules matters (Gould, *Behind Bars*, "Accidentals"):
  ///
  /// 1. **Cautionary / editorial accidentals always show.** A note carrying
  ///    [AccidentalParenthesis.parentheses] (cautionary) or
  ///    [AccidentalParenthesis.brackets] (editorial) is an explicit engraving
  ///    decision by the author: it is drawn even when the alteration is
  ///    already in force in the bar — that reminder is the whole point of the
  ///    bracketed form. It still refreshes [state] like any other accidental.
  ///    This rule outranks rule 2: a tied note that is also marked cautionary
  ///    shows its accidental.
  /// 2. **A tie destination never takes a fresh accidental.** For
  ///    [TieType.end] and [TieType.inner] the pitch is a continuation of a
  ///    note already sounding, so no accidental is engraved even when the tie
  ///    crosses a barline and the alteration is no longer in force. The
  ///    measure [state] is deliberately *not* updated: the tied-over
  ///    alteration applies to the tied note only, so a later, separately
  ///    attacked note at the same pitch in the new bar still gets its own
  ///    accidental.
  /// 3. **Standard within-measure persistence.** Otherwise the note is
  ///    compared against the alteration currently sounding at that step and
  ///    octave (the last accidental in the bar, or the key signature when
  ///    there was none): equal means nothing is drawn, different means the
  ///    accidental is drawn (a natural when the note is unaltered).
  static void _decide(
    Note note,
    Map<String, int> state,
    int keyCount,
    Map<Note, AccidentalDisplay> out,
  ) {
    final step = note.pitch.step.toUpperCase();
    final key = '$step${note.pitch.octave}';
    final alter = note.pitch.effectiveAlter.round();
    final keyAlter = keyAlterForStep(step, keyCount);
    final sounding = state[key] ?? keyAlter;

    // Rule 1: cautionary/editorial accidentals are never suppressed.
    if (note.accidentalParenthesis != AccidentalParenthesis.none) {
      state[key] = alter;
      out[note] =
          alter == 0 ? AccidentalDisplay.natural : AccidentalDisplay.show;
      return;
    }

    // Rule 2: destination of a tie — no new accidental, no state change.
    final tie = note.tie;
    if (tie == TieType.end || tie == TieType.inner) {
      out[note] = AccidentalDisplay.hide;
      return;
    }

    // Rule 3: standard within-measure persistence.
    if (alter == sounding) {
      out[note] = AccidentalDisplay.hide;
      return;
    }
    state[key] = alter;
    out[note] =
        alter == 0 ? AccidentalDisplay.natural : AccidentalDisplay.show;
  }

  /// Alteration a key signature of [keyCount] (>0 sharps, <0 flats) applies to
  /// the diatonic [step].
  static int keyAlterForStep(String step, int keyCount) {
    const sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
    const flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];
    final s = step.toUpperCase();
    if (keyCount > 0) {
      final idx = sharpOrder.indexOf(s);
      return (idx >= 0 && idx < keyCount) ? 1 : 0;
    } else if (keyCount < 0) {
      final idx = flatOrder.indexOf(s);
      return (idx >= 0 && idx < -keyCount) ? -1 : 0;
    }
    return 0;
  }
}
