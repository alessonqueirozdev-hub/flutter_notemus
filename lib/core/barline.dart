// lib/core/barline.dart

import 'musical_element.dart';

/// Tipos de barlines
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

/// Representa a linha de measure.
class Barline extends MusicalElement {
  final BarlineType type;
  
  Barline({this.type = BarlineType.single});
}
