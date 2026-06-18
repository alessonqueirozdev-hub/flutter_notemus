// Within-measure accidental persistence (Behind Bars / Gould).
//
// In CMN an accidental is shown only on the FIRST occurrence of an altered
// pitch (same step+octave) within a measure; later identical notes show none; a
// note reverting to its key-signature/diatonic value mid-measure gets an
// auto-natural; the state resets at every barline. This resolver computes that
// decision per note from the MODEL (independent of layout), so both the layout
// width reservation and the renderer agree.

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
  static Map<Note, AccidentalDisplay> resolve(List<Measure> measures) {
    final result = Map<Note, AccidentalDisplay>.identity();
    var keyCount = 0;

    for (final measure in measures) {
      // step+octave -> alteration currently sounding this measure.
      final state = <String, int>{};

      void process(List<MusicalElement> elements) {
        for (final el in elements) {
          if (el is KeySignature) {
            keyCount = el.count;
          } else if (el is Note) {
            _decide(el, state, keyCount, result);
          } else if (el is Chord) {
            for (final n in el.notes) {
              _decide(n, state, keyCount, result);
            }
          } else if (el is Tuplet) {
            process(el.elements);
          }
        }
      }

      if (measure is MultiVoiceMeasure) {
        process(measure.elements);
        for (final voice in measure.sortedVoices) {
          process(voice.elements);
        }
      } else {
        process(measure.elements);
      }
    }
    return result;
  }

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
