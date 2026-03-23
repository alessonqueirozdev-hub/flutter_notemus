// lib/core/harmonic_analysis.dart

import 'musical_element.dart';

/// Tipo de intervalo melódico, correspondendo ao atributo `@intm` do MEI v5.
/// Suporta Código de Parsons, notação diatônica e semitons.
enum MelodicIntervalType {
  /// Código de Parsons: repetição (R), ascendente (U), descendente (D)
  parsonsCode,
  /// Notação diatônica (M2, m3, P5, etc.)
  diatonic,
  /// Número de semitons (inteiro)
  semitones,
}

/// Função melódica de uma nota (MEI `@mfunc`).
/// Baseada na sintaxe Humdrum.
enum MelodicFunction {
  /// Tom de acorde (chord tone)
  chordTone,
  /// Nota de passagem (passing tone)
  passingTone,
  /// Nota de vizinhança / bordadura (neighbor tone)
  neighborTone,
  /// Escapada (escape tone)
  escapeTone,
  /// Appoggiatura
  appoggiatura,
  /// Nota de antecipação
  anticipation,
  /// Suspensão
  suspension,
  /// Retardo
  retardation,
  /// Pedal
  pedal,
  /// Outro / indefinido
  other,
}

/// Grau da escala com possível alteração cromática (MEI `@deg`).
///
/// ```dart
/// ScaleDegree(degree: 5)          // V
/// ScaleDegree(degree: 7, alter: -1) // b7 (sétimo abaixado)
/// ```
class ScaleDegree {
  /// Grau da escala (1–7).
  final int degree;

  /// Alteração cromática do grau (-2.0 a +2.0).
  final double alter;

  const ScaleDegree({required this.degree, this.alter = 0.0});

  @override
  String toString() {
    if (alter == 0) return degree.toString();
    if (alter == -1) return 'b$degree';
    if (alter == 1) return '#$degree';
    if (alter == -2) return 'bb$degree';
    if (alter == 2) return '##$degree';
    return '$degree${alter > 0 ? '+$alter' : alter}';
  }
}

/// Intervalo melódico entre duas notas consecutivas (MEI `@intm`).
///
/// ```dart
/// MelodicInterval.diatonic('M2')   // segunda maior
/// MelodicInterval.semitones(3)     // 3 semitons (terça menor)
/// MelodicInterval.parsons('U')     // ascendente (Código de Parsons)
/// ```
class MelodicInterval {
  final MelodicIntervalType type;
  final String? diatonicValue;    // ex.: "M2", "m3", "P5", "A4"
  final int? semitonesValue;      // ex.: 2, 3, 7
  final String? parsonsValue;     // "R", "U", "D"

  const MelodicInterval._({
    required this.type,
    this.diatonicValue,
    this.semitonesValue,
    this.parsonsValue,
  });

  /// Intervalo diatônico (ex.: 'M2', 'm3', 'P4', 'P5', 'M6', 'm7', 'P8').
  factory MelodicInterval.diatonic(String value) =>
      MelodicInterval._(type: MelodicIntervalType.diatonic, diatonicValue: value);

  /// Intervalo em semitons (positivo = ascendente, negativo = descendente).
  factory MelodicInterval.semitones(int value) =>
      MelodicInterval._(type: MelodicIntervalType.semitones, semitonesValue: value);

  /// Código de Parsons: 'R' (repetição), 'U' (ascendente), 'D' (descendente).
  factory MelodicInterval.parsons(String code) {
    assert(['R', 'U', 'D'].contains(code.toUpperCase()),
        'Código de Parsons inválido: $code. Use R, U ou D.');
    return MelodicInterval._(
      type: MelodicIntervalType.parsonsCode,
      parsonsValue: code.toUpperCase(),
    );
  }

  @override
  String toString() => diatonicValue ?? semitonesValue?.toString() ?? parsonsValue ?? '';
}

/// Intervalo harmônico entre duas notas simultâneas (MEI `@inth`).
///
/// Descreve a relação intervalar entre notas de um acorde ou entre vozes.
class HarmonicInterval {
  /// Tamanho do intervalo em semitons (0 = uníssono).
  final int semitones;

  /// Nome diatônico do intervalo (ex.: 'M3', 'm7', 'P5').
  final String? diatonicName;

  const HarmonicInterval({required this.semitones, this.diatonicName});

  @override
  String toString() => diatonicName ?? '$semitones st';
}

/// Define um membro de um acorde dentro de uma `ChordTable` (MEI `<chordMember>`).
class ChordMember {
  /// Nota do membro (pname + octave relativo à fundamental, ou semitom).
  final int intervalFromRoot;

  /// Acidente opcional no membro.
  final double alter;

  const ChordMember({required this.intervalFromRoot, this.alter = 0.0});
}

/// Define um tipo de acorde na tabela de acordes (MEI `<chordDef>`).
///
/// ```dart
/// ChordDefinition(
///   id: 'maj',
///   label: 'Major',
///   members: [ChordMember(0), ChordMember(4), ChordMember(7)],
/// )
/// ```
class ChordDefinition {
  /// Identificador único do acorde (MEI `xml:id` em `<chordDef>`).
  final String id;

  /// Rótulo descritivo (ex.: 'Major', 'Minor 7th').
  final String label;

  /// Membros do acorde (intervalos em semitons a partir da fundamental).
  final List<ChordMember> members;

  const ChordDefinition({
    required this.id,
    required this.label,
    required this.members,
  });
}

/// Tabela de definições de acordes (MEI `<chordTable>`).
///
/// Permite definir vocabulário harmônico reutilizável para análise de acordes.
/// Geralmente armazenada no `<meiHead>` ou `<music>`.
class ChordTable {
  final List<ChordDefinition> definitions;

  const ChordTable({required this.definitions});

  ChordDefinition? findById(String id) {
    try {
      return definitions.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Representa uma análise harmônica de uma nota ou acorde (MEI `<harm>`).
///
/// Associado a um evento musical através de [xmlId] do elemento-alvo.
///
/// ```dart
/// HarmonicLabel(
///   symbol: 'G7',
///   scaleDegree: ScaleDegree(degree: 5),
///   targetXmlId: 'note1',
/// )
/// ```
class HarmonicLabel extends MusicalElement {
  /// Símbolo do acorde (ex.: 'Cmaj7', 'G7', 'Am', 'Bdim').
  final String? symbol;

  /// Grau da escala deste acorde no contexto tonal.
  final ScaleDegree? scaleDegree;

  /// Função melódica da nota associada.
  final MelodicFunction? melodicFunction;

  /// Intervalo melódico desde a nota anterior.
  final MelodicInterval? melodicInterval;

  /// Intervalo harmônico em relação a outra voz.
  final HarmonicInterval? harmonicInterval;

  /// ID do elemento-alvo desta análise (MEI `@startid`).
  final String? targetXmlId;

  HarmonicLabel({
    this.symbol,
    this.scaleDegree,
    this.melodicFunction,
    this.melodicInterval,
    this.harmonicInterval,
    this.targetXmlId,
  });
}
