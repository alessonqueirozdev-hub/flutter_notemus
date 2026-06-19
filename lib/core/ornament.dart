// lib/core/ornament.dart

import 'musical_element.dart';
import 'pitch.dart';

/// Tipos de ornaments musicais
enum OrnamentType {
  // Básicos
  trill,
  trillFlat,
  trillNatural,
  trillSharp,
  mordent,
  invertedMordent,
  shortTrill,
  turn,
  turnInverted,
  invertedTurn,
  turnSlash,

  // Apoggiaturas
  appoggiaturaUp,
  appoggiaturaDown,
  acciaccatura,

  // Glissandos
  glissando,
  portamento,
  slide,
  scoop,
  fall,
  doit,
  plop,
  bend,

  // Avançados
  shake,
  wavyLine,
  zigzagLine,
  fermata,
  fermataBelow,
  fermataBelowInverted,
  schleifer,
  mordentUpperPrefix,
  mordentLowerPrefix,
  trillLigature,
  haydn,
  zigZagLineNoRightEnd,
  zigZagLineWithRightEnd,
  arpeggio,
  grace,

  // Ornaments barrocos and clássicos
  pralltriller,
  mordentWithUpperPrefix,
  slideUp,
  slideDown,
  doubleTongue,
  tripleTongue,
}

/// Representa a ornament musical
class Ornament extends MusicalElement {
  final OrnamentType type;
  final bool above;
  final String? text;
  final Pitch? alternatePitch;

  /// Optional accidental drawn (reduced size) above the ornament — e.g. a trill
  /// or turn that raises/lowers its auxiliary note. null = none.
  final AccidentalType? accidentalAbove;

  /// Optional accidental drawn below the ornament (turns can carry one). null =
  /// none.
  final AccidentalType? accidentalBelow;

  Ornament({
    required this.type,
    this.above = true,
    this.text,
    this.alternatePitch,
    this.accidentalAbove,
    this.accidentalBelow,
  });
}
