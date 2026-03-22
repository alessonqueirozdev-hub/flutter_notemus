// lib/src/music_model/tablature.dart

import '../../core/core.dart'; // Tipos do core

/// Representa uma tablatura para instrumentos de corda
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

  /// Afinações pré-definidas para instrumentos comuns
  static const Map<String, List<String>> standardTunings = {
    'guitar_6': ['E4', 'B3', 'G3', 'D3', 'A2', 'E2'], // Violão 6 cordas
    'guitar_7': ['B4', 'E4', 'B3', 'G3', 'D3', 'A2', 'E2'], // Violão 7 cordas
    'bass_4': ['G2', 'D2', 'A1', 'E1'], // Baixo 4 cordas
    'bass_5': ['B2', 'G2', 'D2', 'A1', 'E1'], // Baixo 5 cordas
    'ukulele': ['A4', 'E4', 'C4', 'G4'], // Ukulele
    'mandolin': ['E5', 'A4', 'D4', 'G3'], // Mandolina
  };

  /// Cria uma tablatura padrão para violão
  factory Tablature.guitar() {
    return Tablature(
      staffs: [],
      instrument: 'guitar',
      numberOfStrings: 6,
      tuning: standardTunings['guitar_6']!,
    );
  }

  /// Cria uma tablatura padrão para baixo
  factory Tablature.bass() {
    return Tablature(
      staffs: [],
      instrument: 'bass',
      numberOfStrings: 4,
      tuning: standardTunings['bass_4']!,
    );
  }
}

/// Representa uma pauta de tablatura
class TabStaff {
  final List<TabMeasure> measures = [];
  final String? name;

  TabStaff({this.name});

  void add(TabMeasure measure) => measures.add(measure);
}

/// Representa um compasso de tablatura
class TabMeasure {
  final List<TabElement> elements = [];

  void add(TabElement element) => elements.add(element);
}

/// Elemento base para tablatura
abstract class TabElement extends MusicalElement {}

/// Representa uma nota na tablatura
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

  /// Calcula a altura da nota baseado na afinação
  Pitch getPitch(List<String> tuning) {
    if (string < 1 || string > tuning.length) {
      throw ArgumentError('String number out of range');
    }

    // Aqui seria necessário implementar a conversão de string para Pitch
    // e adicionar os semitons do traste
    return const Pitch(step: 'C', octave: 4); // Placeholder
  }
}

/// Representa um acorde na tablatura
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

/// Técnicas especiais para instrumentos de corda
enum TabTechnique {
  // Técnicas básicas
  hammer, // Hammer-on
  pull, // Pull-off
  slide, // Slide/glissando
  bend, // Bend
  release, // Release bend
  vibrato, // Vibrato
  trill, // Trill

  // Técnicas de mão direita
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

  // Articulações específicas
  accent,
  staccato,
  legato,
}

/// Mapeamento de técnicas para glifos SMuFL
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

/// Pausa na tablatura
class TabRest extends TabElement {
  final Duration duration;

  TabRest({required this.duration});
}

/// Barra de compasso na tablatura
class TabBarline extends TabElement {
  final BarlineType type;

  TabBarline({required this.type});
}

/// Indicação de tempo para tablatura
class TabTimeSignature extends TabElement {
  final int numerator;
  final int denominator;

  TabTimeSignature({required this.numerator, required this.denominator});
}

/// Armadura de clave para tablatura (opcional)
class TabKeySignature extends TabElement {
  final int count;

  TabKeySignature(this.count);
}

/// Clave de tablatura
class TabClef extends TabElement {
  final int numberOfStrings;

  TabClef({required this.numberOfStrings});

  /// Retorna o glifo SMuFL apropriado
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

/// Mapeamento de fingering para glifos
const Map<int, String> fingeringToGlyph = {
  0: 'fingering0', // Polegar
  1: 'fingering1',
  2: 'fingering2',
  3: 'fingering3',
  4: 'fingering4',
  5: 'fingering5',
};

/// Capo/pestana para guitarra
class Capo extends TabElement {
  final int fret; // Casa onde está o capo
  final String? label; // Texto opcional

  Capo({required this.fret, this.label});
}

/// Bend com informações detalhadas
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

/// Representação de ritmo/groove
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

/// Utilitários para tablatura
class TabUtils {
  /// Converte uma altura para posição na tablatura
  static List<TabPosition> pitchToTabPositions(
    Pitch pitch,
    List<String> tuning,
  ) {
    final positions = <TabPosition>[];

    // Implementação simplificada
    // Na realidade, seria necessário calcular todas as posições possíveis
    // para uma determinada altura em diferentes cordas

    return positions;
  }

  /// Verifica se uma posição é fisicamente possível
  static bool isPositionPlayable(List<TabNote> notes) {
    // Verifica se as posições são fisicamente alcançáveis
    // considerando o stretch máximo dos dedos
    return true; // Placeholder
  }

  /// Sugere fingering otimizado para uma sequência de notas
  static List<Fingering> suggestFingering(List<TabNote> notes) {
    // Algoritmo para sugerir dedilhado otimizado
    return []; // Placeholder
  }
}

/// Posição na tablatura (corda + traste)
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

/// Template de acorde
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

  /// Biblioteca de acordes comuns
  static const Map<String, ChordTemplate> commonChords = {
    // Será implementado com acordes mais comuns
  };
}