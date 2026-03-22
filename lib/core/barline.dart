// lib/core/barline.dart

import 'musical_element.dart';

/// Tipos de barras de compasso
enum BarlineType {
  single,
  double,
  final_,
  repeatForward,
  repeatBackward,
  repeatBoth,
  dashed,
  heavy,
  lightLight,
  lightHeavy,
  heavyLight,
  heavyHeavy,
  tick,
  short_,
  none,
}

/// Representa uma linha de compasso.
class Barline extends MusicalElement {
  final BarlineType type;
  
  Barline({this.type = BarlineType.single});
}
