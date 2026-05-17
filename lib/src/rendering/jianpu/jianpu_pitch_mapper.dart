// Jianpu (numbered notation) pitch mapping — GB/T 46845-2025, §6.2.
//
// Maps a notation-agnostic [Pitch] to a movable-do Jianpu numeral (1–7), an
// accidental (♯ ♭ ♮ and doubles) and an octave-dot register, given the key.
//
// The numeral is the *diatonic letter degree* relative to the key tonic, and
// the accidental is the note's chromatic deviation from that degree in the
// key — so enharmonics and key-cancelling naturals are spelled correctly.

import 'package:flutter_notemus/core/core.dart';

/// A pitch expressed in Jianpu terms.
class JianpuNote {
  /// Scale-degree numeral: '1'–'7' (or '0' for a rest, set by the renderer).
  final String numeral;

  /// Accidental prefix: '' (none), '♯', '♭', '♮', '×' (double sharp) or
  /// '♭♭' (double flat).
  final String accidental;

  /// Octave register relative to the central tonic octave.
  /// `0` = no dots; `> 0` = that many dots above; `< 0` = dots below.
  final int octaveDots;

  const JianpuNote(this.numeral, this.accidental, this.octaveDots);

  @override
  String toString() => '$accidental$numeral@$octaveDots';
}

/// Maps pitches to Jianpu numerals for a major key (movable-do, 1 = do).
class JianpuPitchMapper {
  /// Pitch class of the tonic (0 = C … 11 = B). "1" (do) maps to this.
  final int tonicPitchClass;

  /// Letter index of the tonic in C-based order (C=0, D=1 … B=6).
  final int tonicLetterIndex;

  /// Circle-of-fifths count of the key (sharps > 0, flats < 0).
  final int fifths;

  const JianpuPitchMapper._(
    this.tonicPitchClass,
    this.tonicLetterIndex,
    this.fifths,
  );

  /// C major (1=C) default.
  factory JianpuPitchMapper(int tonicPitchClass, {bool preferFlats = false}) {
    // Derive a plausible letter for an ad-hoc pitch class (used by tests and
    // simple callers): natural letter whose pitch class matches, else nearest.
    const naturalPc = [0, 2, 4, 5, 7, 9, 11]; // C D E F G A B
    var letter = naturalPc.indexOf(tonicPitchClass);
    if (letter < 0) {
      // Chromatic tonic: pick letter below (sharp) or above (flat).
      letter = preferFlats
          ? naturalPc.indexWhere((pc) => pc > tonicPitchClass)
          : naturalPc.lastIndexWhere((pc) => pc < tonicPitchClass);
      if (letter < 0) letter = 0;
    }
    return JianpuPitchMapper._(
      tonicPitchClass,
      letter,
      preferFlats ? -1 : 0,
    );
  }

  /// Builds a mapper from a [KeySignature] (major-key assumption, 1 = do).
  factory JianpuPitchMapper.fromKeySignature(KeySignature key) {
    final f = key.count;
    final pc = (((f * 7) % 12) + 12) % 12;
    final letter = (((f * 4) % 7) + 7) % 7; // each fifth = +4 letters mod 7
    return JianpuPitchMapper._(pc, letter, f);
  }

  static const List<int> _letterPc = [0, 2, 4, 5, 7, 9, 11]; // C D E F G A B
  static const List<String> _letterNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  // Order in which sharps / flats are applied (C-based letter indices).
  static const List<int> _sharpOrder = [3, 0, 4, 1, 5, 2, 6]; // F C G D A E B
  static const List<int> _flatOrder = [6, 2, 5, 1, 4, 0, 3]; // B E A D G C F
  // Major-scale semitone offsets for degrees 1..7.
  static const List<int> _majorSemitone = [0, 2, 4, 5, 7, 9, 11];

  static int _stepIndex(String step) =>
      const {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6}[step
          .toUpperCase()] ??
      0;

  /// The key's diatonic alteration (+1 sharp, -1 flat, 0 natural) for a letter.
  int _keyAlterForLetter(int letterIdx) {
    if (fifths > 0) {
      for (var i = 0; i < fifths && i < 7; i++) {
        if (_sharpOrder[i] == letterIdx) return 1;
      }
    } else if (fifths < 0) {
      for (var i = 0; i < -fifths && i < 7; i++) {
        if (_flatOrder[i] == letterIdx) return -1;
      }
    }
    return 0;
  }

  /// Tonic note name used in the `1=<name>` header (e.g. C, G, F, Bb, F#).
  String get tonicName {
    final natural = _letterPc[tonicLetterIndex];
    var diff = tonicPitchClass - natural;
    if (diff > 6) diff -= 12;
    if (diff < -6) diff += 12;
    final suffix = switch (diff) {
      2 => '##',
      1 => '#',
      -1 => 'b',
      -2 => 'bb',
      _ => '',
    };
    return '${_letterNames[tonicLetterIndex]}$suffix';
  }

  /// Maps [pitch] to its Jianpu numeral, accidental and octave register.
  JianpuNote map(Pitch pitch) {
    final letterIdx = _stepIndex(pitch.step);
    final degree = (((letterIdx - tonicLetterIndex) % 7) + 7) % 7; // 0..6
    final numeral = '${degree + 1}';

    final actual = (((pitch.pitchClass - tonicPitchClass) % 12) + 12) % 12;
    var alt = actual - _majorSemitone[degree];
    if (alt > 6) alt -= 12;
    if (alt < -6) alt += 12;

    final String accidental;
    final keyAlter = _keyAlterForLetter(letterIdx);
    if (alt == 0) {
      accidental = '';
    } else if (pitch.alter == 0 && keyAlter != 0) {
      // The key alters this letter but the note is natural → cancel sign.
      accidental = '♮';
    } else {
      accidental = switch (alt) {
        2 => '×',
        1 => '♯',
        -1 => '♭',
        -2 => '♭♭',
        _ => '',
      };
    }

    // Register: 0 when the note sits in the tonic's central octave (the tonic
    // placed in the C4 region, MIDI 60–71); ±1 per octave away.
    final tonicCentralMidi = 60 + tonicPitchClass;
    final degSemis = (((pitch.pitchClass - tonicPitchClass) % 12) + 12) % 12;
    final register =
        ((pitch.midiNumber - degSemis - tonicCentralMidi) / 12).round();

    return JianpuNote(numeral, accidental, register);
  }
}
