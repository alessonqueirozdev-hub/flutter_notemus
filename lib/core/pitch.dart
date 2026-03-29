// lib/src/music_model/pitch.dart

import 'dart:math';

/// Available accidental types in SMuFL.
enum AccidentalType {
  natural,
  sharp,
  flat,
  doubleSharp,
  doubleFlat,
  tripleSharp,
  tripleFlat,
  quarterToneSharp,
  quarterToneFlat,
  threeQuarterToneSharp,
  threeQuarterToneFlat,
  komaSharp,
  komaFlat,

  // Microtonal accidentals
  sagittal11MediumDiesisUp,
  sagittal11MediumDiesisDown,
  sagittal11LargeDiesisUp,
  sagittal11LargeDiesisDown,

  // Custom accidentals
  custom,
}

/// Mapping from AccidentalType to alteration value.
const Map<AccidentalType, double> accidentalToAlter = {
  AccidentalType.natural: 0.0,
  AccidentalType.sharp: 1.0,
  AccidentalType.flat: -1.0,
  AccidentalType.doubleSharp: 2.0,
  AccidentalType.doubleFlat: -2.0,
  AccidentalType.tripleSharp: 3.0,
  AccidentalType.tripleFlat: -3.0,
  AccidentalType.quarterToneSharp: 0.5,
  AccidentalType.quarterToneFlat: -0.5,
  AccidentalType.threeQuarterToneSharp: 1.5,
  AccidentalType.threeQuarterToneFlat: -1.5,
  AccidentalType.komaSharp: 0.25,
  AccidentalType.komaFlat: -0.25,
  AccidentalType.sagittal11MediumDiesisUp: 0.166667,
  AccidentalType.sagittal11MediumDiesisDown: -0.166667,
  AccidentalType.sagittal11LargeDiesisUp: 0.333333,
  AccidentalType.sagittal11LargeDiesisDown: -0.333333,
};

/// Mapping from AccidentalType to SMuFL glyph name.
const Map<AccidentalType, String> accidentalToGlyph = {
  AccidentalType.natural: 'accidentalNatural',
  AccidentalType.sharp: 'accidentalSharp',
  AccidentalType.flat: 'accidentalFlat',
  AccidentalType.doubleSharp: 'accidentalDoubleSharp',
  AccidentalType.doubleFlat: 'accidentalDoubleFlat',
  AccidentalType.tripleSharp: 'accidentalTripleSharp',
  AccidentalType.tripleFlat: 'accidentalTripleFlat',
  AccidentalType.quarterToneSharp: 'accidentalQuarterToneSharpStein',
  AccidentalType.quarterToneFlat: 'accidentalQuarterToneFlatStein',
  AccidentalType.threeQuarterToneSharp: 'accidentalThreeQuarterTonesSharpStein',
  AccidentalType.threeQuarterToneFlat:
      'accidentalThreeQuarterTonesFlatZimmermann',
  AccidentalType.komaSharp: 'accidentalKomaSharp',
  AccidentalType.komaFlat: 'accidentalKomaFlat',
  AccidentalType.sagittal11MediumDiesisUp: 'accSagittal11MediumDiesisUp',
  AccidentalType.sagittal11MediumDiesisDown: 'accSagittal11MediumDiesisDown',
  AccidentalType.sagittal11LargeDiesisUp: 'accSagittal11LargeDiesisUp',
  AccidentalType.sagittal11LargeDiesisDown: 'accSagittal11LargeDiesisDown',
};

/// Represents the musical pitch of a note.
///
/// A pitch is fully described by its diatonic [step] (`"C"`–`"B"`),
/// [octave] number, and optional chromatic [alter] value. Microtonal
/// alterations are supported through fractional [alter] values and the
/// [accidentalType] field.
///
/// Example:
/// ```dart
/// const Pitch(step: 'F', octave: 4, alter: 1.0) // F-sharp 4
/// Pitch.withAccidental(step: 'B', octave: 3, accidentalType: AccidentalType.flat) // B-flat 3
/// Pitch.fromString('C#5') // C-sharp 5
/// ```
class Pitch {
  /// The note letter name (C, D, E, F, G, A, B).
  final String step;

  /// The octave number (4 is the standard middle octave).
  final int octave;

  /// Chromatic alteration: -2.0 = double flat, -1.0 = flat, 0.0 = natural,
  /// +1.0 = sharp, +2.0 = double sharp.
  /// Decimal values are supported for microtones.
  final double alter;

  /// Specific accidental type (optional, for special notetions).
  final AccidentalType? accidentalType;

  /// For custom accidentals.
  final String? customAccidentalGlyph;

  const Pitch({
    required this.step,
    required this.octave,
    this.alter = 0.0,
    this.accidentalType,
    this.customAccidentalGlyph,
  });

  /// Effective alteration value used for calculateTestions.
  ///
  /// Maintains backward compatibility: when [accidentalType] is provided and
  /// [alter] remains at its default value (`0.0`), uses the implicit value of
  /// the accidental for MIDI/frequency calculateTestion.
  double get effectiveAlter {
    if (alter != 0.0 || accidentalType == null) {
      return alter;
    }
    return accidentalToAlter[accidentalType] ?? alter;
  }

  /// Constructor with a specific accidental type.
  factory Pitch.withAccidental({
    required String step,
    required int octave,
    required AccidentalType accidentalType,
  }) {
    return Pitch(
      step: step,
      octave: octave,
      alter: accidentalToAlter[accidentalType] ?? 0.0,
      accidentalType: accidentalType,
    );
  }

  /// Constructs a Pitch from a string (e.g. "C4", "F#5", "Bb3").
  factory Pitch.fromString(String notation) {
    if (notation.isEmpty) {
      throw ArgumentError('Notation cannot be empty');
    }

    // Extract the base note (first letter)
    final step = notation[0].toUpperCase();
    if (!'CDEFGAB'.contains(step)) {
      throw ArgumentError('Invalid note step: $step');
    }

    // Find where the octave number begins
    int octaveStart = 1;
    double alter = 0.0;
    AccidentalType? accidentalType;

    // Process accidentals
    if (notation.length > 1) {
      for (int i = 1; i < notation.length; i++) {
        final char = notation[i];
        if (char == '#') {
          alter += 1.0;
          accidentalType = alter == 1.0 ? AccidentalType.sharp : AccidentalType.doubleSharp;
        } else if (char == 'b') {
          alter -= 1.0;
          accidentalType = alter == -1.0 ? AccidentalType.flat : AccidentalType.doubleFlat;
        } else if (char.contains(RegExp(r'[0-9]'))) {
          octaveStart = i;
          break;
        }
      }
    }

    // Extract the octave
    if (octaveStart >= notation.length) {
      throw ArgumentError('Missing octave number in notation: $notation');
    }

    final octaveString = notation.substring(octaveStart);
    final octave = int.tryParse(octaveString);
    if (octave == null) {
      throw ArgumentError('Invalid octave number: $octaveString');
    }

    return Pitch(
      step: step,
      octave: octave,
      alter: alter,
      accidentalType: accidentalType,
    );
  }

  /// calculateTestes the MIDI note number (C4 = 60).
  /// For microtones, returns the nearest integer value.
  int get midiNumber {
    const stepToSemitone = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    final semitone = stepToSemitone[step]!;
    return (octave + 1) * 12 + semitone + effectiveAlter.round();
  }

  /// calculateTestes the frequency in Hz (A4 = 440 Hz).
  double get frequency {
    const a4MidiNumber = 69; // A4
    const a4Frequency = 440.0;
    final midiDifference =
        midiNumber - a4MidiNumber + (effectiveAlter - effectiveAlter.round());
    return a4Frequency * pow(2.0, midiDifference / 12.0).toDouble();
  }

  /// Returns the SMuFL glyph name for the accidental.
  String? get accidentalGlyph {
    if (customAccidentalGlyph != null) return customAccidentalGlyph;
    if (accidentalType != null) return accidentalToGlyph[accidentalType];

    // Infer accidental from alter value
    if (effectiveAlter == 0.0) return null; // No accidental
    if (effectiveAlter == 1.0) return accidentalToGlyph[AccidentalType.sharp];
    if (effectiveAlter == -1.0) return accidentalToGlyph[AccidentalType.flat];
    if (effectiveAlter == 2.0) return accidentalToGlyph[AccidentalType.doubleSharp];
    if (effectiveAlter == -2.0) return accidentalToGlyph[AccidentalType.doubleFlat];
    if (effectiveAlter == 0.5) return accidentalToGlyph[AccidentalType.quarterToneSharp];
    if (effectiveAlter == -0.5) return accidentalToGlyph[AccidentalType.quarterToneFlat];

    return null; // For unmapped values
  }

  /// Returns true if the pitch has a microtonal alteration.
  bool get hasMicrotone {
    return effectiveAlter != effectiveAlter.round().toDouble();
  }

  /// Returns the deviation in cents from the nearest tempered pitch.
  double get centsDeviation {
    final semitoneDeviation = effectiveAlter - effectiveAlter.round();
    return semitoneDeviation * 100.0; // 100 cents = 1 semitone
  }

  /// Returns the pitch class as an integer 0–11, as per the MEI v5
  /// `pclass` attribute. C=0, C#=1, D=2, ..., B=11.
  int get pitchClass {
    const stepToSemitone = {
      'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11,
    };
    return ((stepToSemitone[step]! + effectiveAlter.round()) % 12 + 12) % 12;
  }

  /// Returns the fixed-of the solmization name of this pitch (of the, re, mi, fa, sol, la, si).
  /// Equivalent to the MEI v5 solmization system.
  String get solmizationName {
    final idx = _stepToSolmIndex[step] ?? 0;
    return _solmizationNames[idx];
  }

  /// Constructs a [Pitch] from a fixed-of the solmization syllable.
  /// [syllable] may be 'of the', 're', 'mi', 'fa', 'sol', 'la', 'si' (or 'ti').
  /// [octave] is the octave number; [alter] is the chromatic alteration.
  factory Pitch.fromSolmization(
    String syllable, {
    required int octave,
    double alter = 0.0,
    AccidentalType? accidentalType,
  }) {
    const solmToStep = {
      'do': 'C', 're': 'D', 'mi': 'E', 'fa': 'F',
      'sol': 'G', 'la': 'A', 'si': 'B', 'ti': 'B',
    };
    final normalized = syllable.toLowerCase();
    final step = solmToStep[normalized];
    if (step == null) {
      throw ArgumentError('Invalid solmization syllable: $syllable. '
          'Use: do, re, mi, fa, sol, la, si');
    }
    return Pitch(
      step: step,
      octave: octave,
      alter: alter,
      accidentalType: accidentalType,
    );
  }

  @override
  String toString() => '$step$octave${_alterToString()}';

  String _alterToString() {
    final value = effectiveAlter;
    if (value == 0) return '';
    if (value == 1) return '#';
    if (value == -1) return 'b';
    if (value == 2) return '##';
    if (value == -2) return 'bb';
    if (value == 0.5) return '+';
    if (value == -0.5) return '-';
    return value > 0 ? '+$value' : '$value';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pitch &&
        other.step == step &&
        other.octave == octave &&
        other.alter == alter &&
        other.accidentalType == accidentalType;
  }

  @override
  int get hashCode {
    return Object.hash(step, octave, alter, accidentalType);
  }
}

/// Mapping from note name to solmization index (fixed-of the).
const Map<String, int> _stepToSolmIndex = {
  'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6,
};

const List<String> _solmizationNames = [
  'do', 're', 'mi', 'fa', 'sol', 'la', 'si',
];

/// Utility class for pitch operations.
class PitchUtils {
  /// Converts a MIDI number to a Pitch.
  static Pitch fromMidiNumber(
    int midiNumber, {
    AccidentalType preferredAccidental = AccidentalType.sharp,
  }) {
    final octave = (midiNumber ~/ 12) - 1;
    final semitone = midiNumber % 12;

    const sharpNames = [
      'C',
      'C',
      'D',
      'D',
      'E',
      'F',
      'F',
      'G',
      'G',
      'A',
      'A',
      'B',
    ];
    const flatNames = [
      'C',
      'D',
      'D',
      'E',
      'E',
      'F',
      'G',
      'G',
      'A',
      'A',
      'B',
      'B',
    ];
    const isSharp = [
      false,
      true,
      false,
      true,
      false,
      false,
      true,
      false,
      true,
      false,
      true,
      false,
    ];

    if (!isSharp[semitone]) {
      return Pitch(step: sharpNames[semitone], octave: octave);
    }

    if (preferredAccidental == AccidentalType.sharp) {
      return Pitch(
        step: sharpNames[semitone],
        octave: octave,
        alter: 1.0,
        accidentalType: AccidentalType.sharp,
      );
    } else {
      return Pitch(
        step: flatNames[semitone],
        octave: octave,
        alter: -1.0,
        accidentalType: AccidentalType.flat,
      );
    }
  }

  /// calculateTestes the interval in semitones between two pitches.
  static double intervalInSemitones(Pitch pitch1, Pitch pitch2) {
    return (pitch2.midiNumber - pitch1.midiNumber).toDouble() +
        (pitch2.alter - pitch1.alter);
  }

  /// Transposes a pitch by a number of semitones.
  static Pitch transpose(Pitch pitch, double semitones) {
    final newMidiNumber = pitch.midiNumber + semitones.round();
    final remainder = semitones - semitones.round();
    final newPitch = fromMidiNumber(newMidiNumber);

    return Pitch(
      step: newPitch.step,
      octave: newPitch.octave,
      alter: newPitch.alter + remainder,
    );
  }
}
