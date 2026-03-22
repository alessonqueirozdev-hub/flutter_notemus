// lib/core/ornament.dart

import 'musical_element.dart';
import 'pitch.dart';

/// Tipos de ornamentos musicais
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

  // Ornamentos barrocos e clássicos
  pralltriller,
  mordentWithUpperPrefix,
  slideUp,
  slideDown,
  doubleTongue,
  tripleTongue,
}

/// Representa um ornamento musical
class Ornament extends MusicalElement {
  final OrnamentType type;
  final bool above;
  final String? text;
  final Pitch? alternatePitch;

  Ornament({
    required this.type,
    this.above = true,
    this.text,
    this.alternatePitch,
  });
}
