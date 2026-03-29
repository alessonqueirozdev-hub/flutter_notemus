// lib/core/score_def.dart
//
// Definição global de partitura (MEI v5 — scoreDef)
// Correspwhere ao elemento `<scoreDef>` that agrupa definições de
// clef, armadura e fórmula de measure de forma centralizada.

import 'clef.dart';
import 'key_signature.dart';
import 'time_signature.dart';
import 'dynamic.dart';
import 'tempo.dart';

/// Definição global de partitura, correspwherendo ao elemento `<scoreDef>`
/// of the MEI v5.
///
/// `<scoreDef>` centraliza informações that se Appliesm a toda a partitura
/// no início de um `<section>` ou após a mudança global, evitando repetir
/// as mesmas definições in each `<staffDef>`.
///
/// ```dart
/// ScoreDefinition(
///   clef: Clef(clefType: ClefType.treble),
///   keySignature: KeySignature(0),
///   timeSignature: TimeSignature(numerator: 4, denominator: 4),
///   tempo: TempoMark(beatUnit: DurationType.quarter, bpm: 120, text: 'Allegro'),
/// )
/// ```
class ScoreDefinition {
  /// Clef default for all as staves (pode ser sobreposta por `<staffDef>`).
  final Clef? clef;

  /// Armadura de clef global.
  final KeySignature? keySignature;

  /// Fórmula de measure global.
  final TimeSignature? timeSignature;

  /// Indicação de tempo (tempo).
  final TempoMark? tempo;

  /// Dynamic inicial.
  final Dynamic? dynamic;

  /// Number de linhas default for all as staves (normalmente 5).
  /// Correspwhere a `@lines` in `<staffDef>`.
  final int defaultStaffLines;

  /// Direção default dos accidentals acima of the staff.
  final bool accidentalsAbove;

  /// Identificador único MEI (`xml:id`).
  final String? xmlId;

  const ScoreDefinition({
    this.clef,
    this.keySignature,
    this.timeSignature,
    this.tempo,
    this.dynamic,
    this.defaultStaffLines = 5,
    this.accidentalsAbove = true,
    this.xmlId,
  });

  ScoreDefinition copyWith({
    Clef? clef,
    KeySignature? keySignature,
    TimeSignature? timeSignature,
    TempoMark? tempo,
    Dynamic? dynamic,
    int? defaultStaffLines,
    bool? accidentalsAbove,
    String? xmlId,
  }) {
    return ScoreDefinition(
      clef: clef ?? this.clef,
      keySignature: keySignature ?? this.keySignature,
      timeSignature: timeSignature ?? this.timeSignature,
      tempo: tempo ?? this.tempo,
      dynamic: dynamic ?? this.dynamic,
      defaultStaffLines: defaultStaffLines ?? this.defaultStaffLines,
      accidentalsAbove: accidentalsAbove ?? this.accidentalsAbove,
      xmlId: xmlId ?? this.xmlId,
    );
  }
}
