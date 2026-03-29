// lib/core/score_def.dart
//
// Definition global de partitura (MEI v5 — scoreDef)
// Correspwhere to the elemento `<scoreDef>` that agrupa definitions de
// clef, armadura and fórmula de measure de forma centred.

import 'clef.dart';
import 'key_signature.dart';
import 'time_signature.dart';
import 'dynamic.dart';
import 'tempo.dart';

/// Definition global de partitura, correspwherendo to the elemento `<scoreDef>`
/// of the MEI v5.
///
/// `<scoreDef>` centraliza informações that if Appliesm a toda a partitura
/// no start de a `<section>` or after a mudança global, evitando repetir
/// as same definitions in each `<staffDef>`.
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
  /// Clef default for all as staves (can be sobreposta by `<staffDef>`).
  final Clef? clef;

  /// Armadura de clef global.
  final KeySignature? keySignature;

  /// Fórmula de measure global.
  final TimeSignature? timeSignature;

  /// Indicação de tempo (tempo).
  final TempoMark? tempo;

  /// Dynamic initial.
  final Dynamic? dynamic;

  /// Number de lines default for all as staves (normally 5).
  /// Correspwhere a `@lines` in `<staffDef>`.
  final int defaultStaffLines;

  /// Direction default dos accidentals above the staff.
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
