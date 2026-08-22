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
  /// The seven valid diatonic step letters, in ascending diatonic order.
  static const List<String> validSteps = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  /// Returns `true` if [s] is one of the seven diatonic step letters.
  ///
  /// The check is case-insensitive: both `'c'` and `'C'` are valid.
  static bool isValidStep(String s) =>
      s.length == 1 && validSteps.contains(s.toUpperCase());

  /// The note letter name (C, D, E, F, G, A, B).
  final String step;

  /// The octave number (4 is the standard middle octave).
  final int octave;

  /// Chromatic alteration: -2.0 = double flat, -1.0 = flat, 0.0 = natural,
  /// +1.0 = sharp, +2.0 = double sharp.
  /// Decimal values are supported for microtones.
  final double alter;

  /// Specific accidental type (optional, for special notations).
  final AccidentalType? accidentalType;

  /// For custom accidentals.
  final String? customAccidentalGlyph;

  /// Creates a pitch from a diatonic [step], an [octave] and an optional
  /// chromatic [alter].
  ///
  /// In debug builds the [step] must be one of [validSteps] (uppercase) and
  /// the [octave] must be in the MIDI-representable range `[-1, 10]`.
  const Pitch({
    required this.step,
    required this.octave,
    this.alter = 0.0,
    this.accidentalType,
    this.customAccidentalGlyph,
  })  : assert(
          step == 'C' ||
              step == 'D' ||
              step == 'E' ||
              step == 'F' ||
              step == 'G' ||
              step == 'A' ||
              step == 'B',
          'Invalid pitch step (expected one of C D E F G A B)',
        ),
        assert(
          octave >= -1 && octave <= 10,
          'Octave out of range (expected -1..10)',
        );

  /// Creates a pitch after validating and normalizing its [step].
  ///
  /// The [step] is upper-cased before validation; a [FormatException] is
  /// thrown when it is not a diatonic letter or when [octave] falls outside
  /// the MIDI-representable range `[-1, 10]`. Parsers should prefer this
  /// factory over the raw constructor so malformed input fails with a clear
  /// message instead of an assertion or a later crash.
  factory Pitch.validated({
    required String step,
    required int octave,
    double alter = 0.0,
    AccidentalType? accidentalType,
  }) {
    if (!isValidStep(step)) {
      throw FormatException(
        'Invalid pitch step "$step" (expected one of C D E F G A B)',
      );
    }
    if (octave < -1 || octave > 10) {
      throw FormatException(
        'Invalid octave $octave (expected a value between -1 and 10)',
      );
    }
    return Pitch(
      step: step.toUpperCase(),
      octave: octave,
      alter: alter,
      accidentalType: accidentalType,
    );
  }

  /// Effective alteration value used for calculations.
  ///
  /// Maintains backward compatibility: when [accidentalType] is provided and
  /// [alter] remains at its default value (`0.0`), uses the implicit value of
  /// the accidental for MIDI/frequency calculation.
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

  /// Constructs a Pitch from a string (e.g. "C4", "F#5", "Bb3", "C-1").
  ///
  /// Accidentals are repeatable (`"C##4"`, `"Ebb3"`, `"C###4"`) and the octave
  /// may be negative, so the lowest MIDI note `"C-1"` round-trips correctly.
  factory Pitch.fromString(String notation) {
    if (notation.isEmpty) {
      throw ArgumentError('Notation cannot be empty');
    }

    // Extract the base note (first letter)
    final step = notation[0].toUpperCase();
    if (!isValidStep(step)) {
      throw ArgumentError('Invalid note step: $step');
    }

    // Find where the octave number begins
    int octaveStart = notation.length;
    double alter = 0.0;

    // Process accidentals; stop at the first octave character
    // ('-' introduces a negative octave such as "C-1").
    for (int i = 1; i < notation.length; i++) {
      final char = notation[i];
      if (char == '#') {
        alter += 1.0;
      } else if (char == 'b') {
        alter -= 1.0;
      } else if (char == '-' ||
          (char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39)) {
        octaveStart = i;
        break;
      } else {
        throw ArgumentError('Invalid character "$char" in notation: $notation');
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

    return Pitch.validated(
      step: step,
      octave: octave,
      alter: alter,
      accidentalType: _accidentalTypeForAlter(alter),
    );
  }

  /// Returns the [AccidentalType] matching a whole-tone [alter] value, or
  /// `null` when the alteration cannot be expressed by a standard accidental
  /// (in that case only [alter] carries the information).
  static AccidentalType? _accidentalTypeForAlter(double alter) {
    if (alter == 1.0) return AccidentalType.sharp;
    if (alter == -1.0) return AccidentalType.flat;
    if (alter == 2.0) return AccidentalType.doubleSharp;
    if (alter == -2.0) return AccidentalType.doubleFlat;
    if (alter == 3.0) return AccidentalType.tripleSharp;
    if (alter == -3.0) return AccidentalType.tripleFlat;
    return null;
  }

  /// Semitone offset of [step] within the octave (C = 0 ... B = 11).
  ///
  /// Throws a [StateError] — never a null-check failure — when [step] is not
  /// a diatonic letter, so callers get an actionable message.
  int get _stepSemitone {
    const stepToSemitone = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    final semitone = stepToSemitone[step];
    if (semitone == null) {
      throw StateError(
        'Invalid pitch step "$step" (expected one of C D E F G A B)',
      );
    }
    return semitone;
  }

  /// Calculates the MIDI note number (C4 = 60).
  /// For microtones, returns the nearest integer value.
  int get midiNumber {
    return (octave + 1) * 12 + _stepSemitone + effectiveAlter.round();
  }

  /// Calculates the frequency in Hz (A4 = 440 Hz).
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
    return ((_stepSemitone + effectiveAlter.round()) % 12 + 12) % 12;
  }

  /// Returns the fixed-do solmization name of this pitch (do, re, mi, fa, sol,
  /// la, si). Equivalent to the MEI v5 solmization system.
  String get solmizationName {
    final idx = _stepToSolmIndex[step] ?? 0;
    return _solmizationNames[idx];
  }

  /// Constructs a [Pitch] from a fixed-do solmization syllable.
  /// [syllable] may be 'do', 're', 'mi', 'fa', 'sol', 'la', 'si' (or 'ti').
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

  /// Two pitches are equal when they share the same [step], [octave] and
  /// [effectiveAlter].
  ///
  /// [accidentalType] is deliberately excluded so that spelling-equivalent
  /// pitches such as `Pitch(step: 'F', octave: 4, alter: 1.0)` and
  /// `Pitch.withAccidental(step: 'F', octave: 4, accidentalType: sharp)`
  /// compare equal; the field is still preserved on the object.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Pitch &&
        other.step == step &&
        other.octave == octave &&
        other.effectiveAlter == effectiveAlter;
  }

  @override
  int get hashCode {
    return Object.hash(step, octave, effectiveAlter);
  }
}

/// Mapping from note name to solmization index (fixed-do).
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

  /// Calculates the interval in semitones between two pitches.
  ///
  /// [Pitch.midiNumber] already rounds the alteration into the note number, so
  /// only the microtonal remainder of each pitch is added on top of the MIDI
  /// difference (adding the full alteration again would double-count it).
  static double intervalInSemitones(Pitch pitch1, Pitch pitch2) {
    final fraction1 = pitch1.effectiveAlter - pitch1.effectiveAlter.round();
    final fraction2 = pitch2.effectiveAlter - pitch2.effectiveAlter.round();
    return (pitch2.midiNumber - pitch1.midiNumber).toDouble() +
        fraction2 -
        fraction1;
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
