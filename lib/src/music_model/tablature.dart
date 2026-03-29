// lib/src/music_model/tablature.dart

import '../../core/core.dart'; // Tipos do core

/// Representa a tablatura for instrumentos de corda
class Tablature {
  final List<TabStaff> staffs;
  final String instrument; // Violão, baixo, etc.
  final int numberOfStrings;
  final List<String> tuning; // Afinação das cordas

  Tablature({
    required this.staffs,
    required this.instrument,
    required this.numberOfStrings,
    required this.tuning,
  });

  void add(TabStaff staff) => staffs.add(staff);

  /// Afinações pré-definidas for instrumentos comuns
  static const Map<String, List<String>> standardTunings = {
    'guitar_6': ['E4', 'B3', 'G3', 'D3', 'A2', 'E2'], // Violão 6 cordas
    'guitar_7': ['B4', 'E4', 'B3', 'G3', 'D3', 'A2', 'E2'], // Violão 7 cordas
    'bass_4': ['G2', 'D2', 'A1', 'E1'], // Baixo 4 cordas
    'bass_5': ['B2', 'G2', 'D2', 'A1', 'E1'], // Baixo 5 cordas
    'ukulele': ['A4', 'E4', 'C4', 'G4'], // Ukulele
    'mandolin': ['E5', 'A4', 'D4', 'G3'], // Mandolina
  };

  /// Creates a tablatura default for violão
  factory Tablature.guitar() {
    return Tablature(
      staffs: [],
      instrument: 'guitar',
      numberOfStrings: 6,
      tuning: standardTunings['guitar_6']!,
    );
  }

  /// Creates a tablatura default for bottom
  factory Tablature.bass() {
    return Tablature(
      staffs: [],
      instrument: 'bass',
      numberOfStrings: 4,
      tuning: standardTunings['bass_4']!,
    );
  }
}

/// Representa a staff de tablatura
class TabStaff {
  final List<TabMeasure> measures = [];
  final String? name;

  TabStaff({this.name});

  void add(TabMeasure measure) => measures.add(measure);
}

/// Representa a measure de tablatura
class TabMeasure {
  final List<TabElement> elements = [];

  void add(TabElement element) => elements.add(element);
}

/// Elemento base for tablatura
abstract class TabElement extends MusicalElement {}

/// Representa a note na tablatura
class TabNote extends TabElement {
  final int string; // Número da corda (1-6 para violão)
  final int fret; // Casa do traste
  final Duration duration;
  final List<TabTechnique> techniques; // Técnicas especiais

  TabNote({
    required this.string,
    required this.fret,
    required this.duration,
    this.techniques = const [],
  });

  /// Calculates a height of the note based na afinação
  Pitch getPitch(List<String> tuning) {
    if (string < 1 || string > tuning.length) {
      throw ArgumentError('String number out of range');
    }

    // Aqui seria required implementar a conversão de string for Pitch
    // and add os semitons of the traste
    return const Pitch(step: 'C', octave: 4); // Placeholder
  }
}

/// Representa a chord na tablatura
class TabChord extends TabElement {
  final List<TabNote> notes;
  final Duration duration;
  final String? name; // Nome do acorde (C, Am, etc.)

  TabChord({
    required this.notes,
    required this.duration,
    this.name,
  });
}

/// Técnicas especiais for instrumentos de corda
enum TabTechnique {
  // Técnicas básicas
  hammer, // Hammer-on
  pull, // Pull-off
  slide, // Slide/glissando
  bend, // Bend
  release, // Release bend
  vibrato, // Vibrato
  trill, // Trill

  // Técnicas de mão right
  palm, // Palm mute
  harmonics, // Harmônicos
  pinch, // Pinch harmonics
  tremolo, // Tremolo picking

  // Técnicas avançadas
  tap, // Tapping
  slap, // Slap (baixo)
  pop, // Pop (baixo)
  ghost, // Ghost note
  deadNote, // Nota morta/abafada

  // Articulations específicas
  accent,
  staccato,
  legato,
}

/// Mapeamento de técnicas for glifos SMuFL
const Map<TabTechnique, String> techniqueToGlyph = {
  TabTechnique.hammer: 'guitarString0', // Placeholder
  TabTechnique.pull: 'guitarString0',
  TabTechnique.slide: 'guitarSlideUp',
  TabTechnique.bend: 'guitarBend',
  TabTechnique.vibrato: 'guitarVibratoStroke',
  TabTechnique.palm: 'guitarPalmMute',
  TabTechnique.harmonics: 'guitarHarmonic',
  TabTechnique.tap: 'guitarTap',
  TabTechnique.slap: 'guitarSlap',
  TabTechnique.pop: 'guitarPop',
  TabTechnique.ghost: 'guitarGhostNote',
};

/// PaUses na tablatura
class TabRest extends TabElement {
  final Duration duration;

  TabRest({required this.duration});
}

/// Barline na tablatura
class TabBarline extends TabElement {
  final BarlineType type;

  TabBarline({required this.type});
}

/// Indicação de tempo for tablatura
class TabTimeSignature extends TabElement {
  final int numerator;
  final int denominator;

  TabTimeSignature({required this.numerator, required this.denominator});
}

/// Armadura de clef for tablatura (opcional)
class TabKeySignature extends TabElement {
  final int count;

  TabKeySignature(this.count);
}

/// Clef de tablatura
class TabClef extends TabElement {
  final int numberOfStrings;

  TabClef({required this.numberOfStrings});

  /// Returns o glifo SMuFL apropriado
  String get glyphName {
    switch (numberOfStrings) {
      case 4:
        return '4stringTabClef';
      case 6:
        return '6stringTabClef';
      default:
        return '6stringTabClef'; // Padrão
    }
  }
}

/// Representação de fingering (dedilhado)
class Fingering extends TabElement {
  final int finger; // 1-5 (polegar = 1, ou 0)
  final FingeringHand hand; // Mão esquerda ou direita

  Fingering({required this.finger, required this.hand});
}

enum FingeringHand { left, right }

/// Mapeamento de fingering for glifos
const Map<int, String> fingeringToGlyph = {
  0: 'fingering0', // Polegar
  1: 'fingering1',
  2: 'fingering2',
  3: 'fingering3',
  4: 'fingering4',
  5: 'fingering5',
};

/// Capo/pestana for guitarra
class Capo extends TabElement {
  final int fret; // Casa onde está o capo
  final String? label; // Texto opcional

  Capo({required this.fret, this.label});
}

/// Bend with informações detalhadas
class DetailedBend extends TabElement {
  final int startFret;
  final int endFret;
  final double semitones; // Quantidade de bend em semitons
  final BendType type;

  DetailedBend({
    required this.startFret,
    required this.endFret,
    required this.semitones,
    required this.type,
  });
}

enum BendType {
  full, // Bend completo
  half, // Meio bend
  quarter, // Quarto de bend
  release, // Release
  preBend, // Pré-bend
}

/// Slide detalhado
class DetailedSlide extends TabElement {
  final int startFret;
  final int endFret;
  final SlideType type;

  DetailedSlide({
    required this.startFret,
    required this.endFret,
    required this.type,
  });
}

enum SlideType {
  legato, // Slide legato
  shift, // Slide shift
  glissando, // Glissando
}

/// Tipos de harmônicos
enum HarmonicType {
  natural, // Harmônico natural
  artificial, // Harmônico artificial
  pinch, // Pinch harmonic
  tap, // Tap harmonic
}

/// Harmônico na tablatura
class TabHarmonic extends TabElement {
  final int fret;
  final HarmonicType type;
  final String? notation; // Notação específica (12, 7, etc.)

  TabHarmonic({
    required this.fret,
    required this.type,
    this.notation,
  });
}

/// Tremolo picking
class TremoloPicking extends TabElement {
  final int numberOfStrokes;
  final Duration totalDuration;

  TremoloPicking({
    required this.numberOfStrokes,
    required this.totalDuration,
  });
}

/// Representação de rhythm/groove
class RhythmSlash extends TabElement {
  final Duration duration;
  final bool accent;
  final RhythmSlashType type;

  RhythmSlash({
    required this.duration,
    this.accent = false,
    this.type = RhythmSlashType.normal,
  });
}

enum RhythmSlashType {
  normal,
  muted,
  ghost,
}

/// Utilitários for tablatura
class TabUtils {
  /// Converts a height for position na tablatura
  static List<TabPosition> pitchToTabPositions(
    Pitch pitch,
    List<String> tuning,
  ) {
    final positions = <TabPosition>[];

    // Implementation simplificada
    // Na realidade, seria required Calculate all as positions possible
    // for a determinada height in diferentes cordas

    return positions;
  }

  /// Checks if a position is fisicamente possible
  static bool isPositionPlayable(List<TabNote> notes) {
    // Checks if as positions are fisicamente alcançáveis
    // considerando o stretch máximo dos dedos
    return true; // Placeholder
  }

  /// Sugere fingering otimizado for a sequência de notes
  static List<Fingering> suggestFingering(List<TabNote> notes) {
    // Algoritmo for sugerir dedilhado otimizado
    return []; // Placeholder
  }
}

/// Position na tablatura (corda + traste)
class TabPosition {
  final int string;
  final int fret;
  final double difficulty; // Dificuldade da posição (0.0 - 1.0)

  TabPosition({
    required this.string,
    required this.fret,
    this.difficulty = 0.0,
  });
}

/// Template de chord
class ChordTemplate {
  final String name;
  final List<TabPosition> positions;
  final List<int> mutedStrings; // Cordas abafadas
  final List<int> openStrings; // Cordas soltas

  ChordTemplate({
    required this.name,
    required this.positions,
    this.mutedStrings = const [],
    this.openStrings = const [],
  });

  /// Biblioteca de chords comuns
  static const Map<String, ChordTemplate> commonChords = {
    // Será implementado with chords more comuns
  };
}