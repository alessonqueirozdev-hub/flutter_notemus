// Jianpu (numbered notation) pitch mapping — GB/T 46845-2025, §6.2.
//
// Maps a notation-agnostic [Pitch] to a movable-do Jianpu numeral (1–7),
// an accidental prefix, and an octave-dot register, given the key tonic.

import 'package:flutter_notemus/core/core.dart';

/// A pitch expressed in Jianpu terms.
class JianpuNote {
  /// Scale-degree numeral: '1'–'7' (or '0' for a rest, set by the renderer).
  final String numeral;

  /// Accidental prefix: '' (none), '#' (sharp) or 'b' (flat).
  final String accidental;

  /// Octave register relative to the central tonic octave.
  /// `0` = no dots; `> 0` = that many dots above; `< 0` = dots below.
  final int octaveDots;

  const JianpuNote(this.numeral, this.accidental, this.octaveDots);

  @override
  String toString() => '$accidental$numeral@$octaveDots';
}

/// Maps pitches to Jianpu numerals for a given key tonic (movable-do).
class JianpuPitchMapper {
  /// Pitch class of the tonic (0 = C … 11 = B). "1" (do) maps to this.
  final int tonicPitchClass;

  /// Whether chromatic degrees and the tonic name prefer flat spelling.
  final bool preferFlats;

  const JianpuPitchMapper(this.tonicPitchClass, {this.preferFlats = false});

  /// Builds a mapper from a [KeySignature] count (circle-of-fifths).
  ///
  /// Major-key assumption (1 = do): tonic pitch class = `fifths * 7 mod 12`.
  factory JianpuPitchMapper.fromKeySignature(KeySignature key) {
    final fifths = key.count;
    final pc = (((fifths * 7) % 12) + 12) % 12;
    return JianpuPitchMapper(pc, preferFlats: fifths < 0);
  }

  static const Map<int, String> _diatonic = {
    0: '1', 2: '2', 4: '3', 5: '4', 7: '5', 9: '6', 11: '7',
  };
  // Chromatic degree spelled as sharp-of-lower vs flat-of-upper.
  static const Map<int, String> _sharpLower = {
    1: '1', 3: '2', 6: '4', 8: '5', 10: '6',
  };
  static const Map<int, String> _flatUpper = {
    1: '2', 3: '3', 6: '5', 8: '6', 10: '7',
  };

  static const Map<int, String> _sharpNames = {
    0: 'C', 7: 'G', 2: 'D', 9: 'A', 4: 'E', 11: 'B', 6: 'F#', 1: 'C#',
    8: 'G#', 3: 'D#', 10: 'A#', 5: 'F',
  };
  static const Map<int, String> _flatNames = {
    0: 'C', 5: 'F', 10: 'Bb', 3: 'Eb', 8: 'Ab', 1: 'Db', 6: 'Gb', 11: 'B',
    4: 'E', 9: 'A', 2: 'D', 7: 'G',
  };

  /// Tonic note name used in the `1=<name>` header.
  String get tonicName =>
      (preferFlats ? _flatNames : _sharpNames)[tonicPitchClass] ?? 'C';

  /// Maps [pitch] to its Jianpu numeral, accidental and octave register.
  JianpuNote map(Pitch pitch) {
    final semis = (((pitch.pitchClass - tonicPitchClass) % 12) + 12) % 12;

    String numeral;
    String accidental;
    if (_diatonic.containsKey(semis)) {
      numeral = _diatonic[semis]!;
      accidental = '';
    } else if (preferFlats || pitch.alter < 0) {
      numeral = _flatUpper[semis]!;
      accidental = 'b';
    } else {
      numeral = _sharpLower[semis]!;
      accidental = '#';
    }

    // Register: 0 when the note sits in the tonic's central octave (the tonic
    // placed in the C4 region, MIDI 60–71); ±1 per octave away.
    final tonicCentralMidi = 60 + tonicPitchClass;
    final register =
        ((pitch.midiNumber - semis - tonicCentralMidi) / 12).round();

    return JianpuNote(numeral, accidental, register);
  }
}
