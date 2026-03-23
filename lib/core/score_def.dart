// lib/core/score_def.dart
//
// Definição global de partitura (MEI v5 — scoreDef)
// Corresponde ao elemento `<scoreDef>` que agrupa definições de
// clave, armadura e fórmula de compasso de forma centralizada.

import 'clef.dart';
import 'key_signature.dart';
import 'time_signature.dart';
import 'dynamic.dart';
import 'tempo.dart';

/// Definição global de partitura, correspondendo ao elemento `<scoreDef>`
/// do MEI v5.
///
/// `<scoreDef>` centraliza informações que se aplicam a toda a partitura
/// no início de um `<section>` ou após uma mudança global, evitando repetir
/// as mesmas definições em cada `<staffDef>`.
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
  /// Clave padrão para todas as pautas (pode ser sobreposta por `<staffDef>`).
  final Clef? clef;

  /// Armadura de clave global.
  final KeySignature? keySignature;

  /// Fórmula de compasso global.
  final TimeSignature? timeSignature;

  /// Indicação de tempo (andamento).
  final TempoMark? tempo;

  /// Dinâmica inicial.
  final Dynamic? dynamic;

  /// Número de linhas padrão para todas as pautas (normalmente 5).
  /// Corresponde a `@lines` em `<staffDef>`.
  final int defaultStaffLines;

  /// Direção padrão dos acidentes acima da pauta.
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
