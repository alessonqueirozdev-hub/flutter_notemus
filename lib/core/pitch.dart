// lib/src/music_model/pitch.dart

/// Tipos de acidentes disponíveis na SMuFL
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

  // Acidentes microtonais
  sagittal11MediumDiesisUp,
  sagittal11MediumDiesisDown,
  sagittal11LargeDiesisUp,
  sagittal11LargeDiesisDown,

  // Acidentes personalizados
  custom,
}

/// Conversão de AccidentalType para valor de alteração
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

/// Mapeamento de AccidentalType para nome do glifo SMuFL
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

/// Representa a altura musical de uma nota.
class Pitch {
  /// A letra da nota (C, D, E, F, G, A, B).
  final String step;

  /// A oitava (normalmente 4 é a oitava central).
  final int octave;

  /// Alteração cromática: -2.0 = dobrado bemol, -1.0 = bemol, 0.0 = natural,
  /// +1.0 = sustenido, +2.0 = dobrado sustenido.
  /// Suporte para microtons com valores decimais.
  final double alter;

  /// Tipo específico de acidente (opcional, para notações especiais)
  final AccidentalType? accidentalType;

  /// Para acidentes personalizados
  final String? customAccidentalGlyph;

  const Pitch({
    required this.step,
    required this.octave,
    this.alter = 0.0,
    this.accidentalType,
    this.customAccidentalGlyph,
  });

  /// Construtor com tipo de acidente específico
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

  /// Constrói um Pitch a partir de uma string (ex: "C4", "F#5", "Bb3")
  factory Pitch.fromString(String notation) {
    if (notation.isEmpty) {
      throw ArgumentError('Notation cannot be empty');
    }

    // Extrair a nota base (primeira letra)
    final step = notation[0].toUpperCase();
    if (!'CDEFGAB'.contains(step)) {
      throw ArgumentError('Invalid note step: $step');
    }

    // Encontrar onde começa o número da oitava
    int octaveStart = 1;
    double alter = 0.0;
    AccidentalType? accidentalType;

    // Processar acidentes
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

    // Extrair a oitava
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

  /// Calcula o número MIDI da nota (C4 = 60).
  /// Para microtons, retorna o valor mais próximo.
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
    return (octave + 1) * 12 + semitone + alter.round();
  }

  /// Calcula a frequência em Hz (A4 = 440Hz)
  double get frequency {
    const a4MidiNumber = 69; // A4
    const a4Frequency = 440.0;
    final midiDifference = midiNumber - a4MidiNumber + (alter - alter.round());
    return a4Frequency * (2.0 * (midiDifference / 12.0));
  }

  /// Retorna o nome do glifo SMuFL para o acidente
  String? get accidentalGlyph {
    if (customAccidentalGlyph != null) return customAccidentalGlyph;
    if (accidentalType != null) return accidentalToGlyph[accidentalType];

    // Inferir acidente baseado no valor de alter
    if (alter == 0.0) return null; // Sem acidente
    if (alter == 1.0) return accidentalToGlyph[AccidentalType.sharp];
    if (alter == -1.0) return accidentalToGlyph[AccidentalType.flat];
    if (alter == 2.0) return accidentalToGlyph[AccidentalType.doubleSharp];
    if (alter == -2.0) return accidentalToGlyph[AccidentalType.doubleFlat];
    if (alter == 0.5) return accidentalToGlyph[AccidentalType.quarterToneSharp];
    if (alter == -0.5) return accidentalToGlyph[AccidentalType.quarterToneFlat];

    return null; // Para valores não mapeados
  }

  /// Verifica se a nota tem microtom
  bool get hasMicrotone {
    return alter != alter.round().toDouble();
  }

  /// Retorna o intervalo em cents da nota temperada mais próxima
  double get centsDeviation {
    final semitoneDeviation = alter - alter.round();
    return semitoneDeviation * 100.0; // 100 cents = 1 semitom
  }

  @override
  String toString() => '$step$octave${_alterToString()}';

  String _alterToString() {
    if (alter == 0) return '';
    if (alter == 1) return '#';
    if (alter == -1) return 'b';
    if (alter == 2) return '##';
    if (alter == -2) return 'bb';
    if (alter == 0.5) return '+';
    if (alter == -0.5) return '-';
    return alter > 0 ? '+$alter' : '$alter';
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

/// Classe utilitária para operações com alturas
class PitchUtils {
  /// Converte um número MIDI para Pitch
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

  /// Calcula o intervalo em semitons entre duas alturas
  static double intervalInSemitones(Pitch pitch1, Pitch pitch2) {
    return (pitch2.midiNumber - pitch1.midiNumber).toDouble() +
        (pitch2.alter - pitch1.alter);
  }

  /// Transpõe uma altura por um número de semitons
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
