// lib/core/harmonic_analysis.dart

import 'musical_element.dart';

/// Type de intervalo melódico, correspwherendo ao atributo `@intm` of the MEI v5.
/// Suporta Código de Parsons, noteção diatônica e semitons.
enum MelodicIntervalType {
  /// Código de Parsons: repetição (R), ascendente (U), descendente (D)
  parsonsCode,
  /// Noteção diatônica (M2, m3, P5, etc.)
  diatonic,
  /// Number de semitons (inteiro)
  semitones,
}

/// Função melódica de a note (MEI `@mfunc`).
/// Baseada na sintaxe Humdrum.
enum MelodicFunction {
  /// Tom de chord (chord tone)
  chordTone,
  /// Note de passagem (passing tone)
  passingTone,
  /// Note de vizinhança / bordadura (neighbor tone)
  neighborTone,
  /// Escapada (escape tone)
  escapeTone,
  /// Appoggiatura
  appoggiatura,
  /// Note de antecipação
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

/// Grau of the escala with possível alteração cromática (MEI `@deg`).
///
/// ```dart
/// ScaleDegree(degree: 5)          // V
/// ScaleDegree(degree: 7, alter: -1) // b7 (sétimo abaixado)
/// ```
class ScaleDegree {
  /// Grau of the escala (1–7).
  final int degree;

  /// Alteração cromática of the grau (-2.0 a +2.0).
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

/// Intervalo melódico entre duas notes consecutivas (MEI `@intm`).
///
/// ```dart
/// MelodicInterval.diatonic('M2')   // segunda greater
/// MelodicInterval.semitones(3)     // 3 semitons (terça smaller)
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

  /// Intervalo in semitons (positivo = ascendente, negativo = descendente).
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

/// Intervalo harmônico entre duas notes simultâneas (MEI `@inth`).
///
/// Descreve a relação intervalar entre notes de um chord ou entre voices.
class HarmonicInterval {
  /// Size of the intervalo in semitons (0 = uníssono).
  final int semitones;

  /// Name diatônico of the intervalo (ex.: 'M3', 'm7', 'P5').
  final String? diatonicName;

  const HarmonicInterval({required this.semitones, this.diatonicName});

  @override
  String toString() => diatonicName ?? '$semitones st';
}

/// Definess um membro de um chord dentro de a `ChordTable` (MEI `<chordMember>`).
class ChordMember {
  /// Note of the membro (pname + octave relativo à fundamental, ou semitom).
  final int intervalFromRoot;

  /// Accidental opcional no membro.
  final double alter;

  const ChordMember({required this.intervalFromRoot, this.alter = 0.0});
}

/// Definess um type de chord na tabela de chords (MEI `<chordDef>`).
///
/// ```dart
/// ChordDefinition(
///   id: 'maj',
///   label: 'Major',
///   members: [ChordMember(0), ChordMember(4), ChordMember(7)],
/// )
/// ```
class ChordDefinition {
  /// Identificador único of the chord (MEI `xml:id` in `<chordDef>`).
  final String id;

  /// Rótulo descritivo (ex.: 'Major', 'Minor 7th').
  final String label;

  /// Membros of the chord (intervalos in semitons a partir of the fundamental).
  final List<ChordMember> members;

  const ChordDefinition({
    required this.id,
    required this.label,
    required this.members,
  });
}

/// Tabela de definições de chords (MEI `<chordTable>`).
///
/// Permite Define vocabulário harmônico reutilizável for análise de chords.
/// Generateslmente armazenada no `<meiHead>` ou `<music>`.
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

/// Representa a análise harmônica de a note ou chord (MEI `<harm>`).
///
/// Associado a um evento musical through [xmlId] of the element-alvo.
///
/// ```dart
/// HarmonicLabel(
///   symbol: 'G7',
///   scaleDegree: ScaleDegree(degree: 5),
///   targetXmlId: 'note1',
/// )
/// ```
class HarmonicLabel extends MusicalElement {
  /// Símbolo of the chord (ex.: 'Cmaj7', 'G7', 'Am', 'Bdim').
  final String? symbol;

  /// Grau of the escala deste chord no contexto tonal.
  final ScaleDegree? scaleDegree;

  /// Função melódica of the note associada.
  final MelodicFunction? melodicFunction;

  /// Intervalo melódico desde a note previous.
  final MelodicInterval? melodicInterval;

  /// Intervalo harmônico in relação a outra voice.
  final HarmonicInterval? harmonicInterval;

  /// ID of the element-alvo desta análise (MEI `@startid`).
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
