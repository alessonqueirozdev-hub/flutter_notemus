// lib/core/line.dart

import 'musical_element.dart';

/// Tipos de linha
enum LineType {
  solid,
  dashed,
  dotted,
  wavy,
  zigzag,
  trill,
  glissando,
  octave,
  pedal,
  bracket,
  voltaBracket,
}

/// Representa uma linha de prolongamento
class Line extends MusicalElement {
  final LineType type;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String? text;
  final bool showArrow;

  Line({
    required this.type,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.text,
    this.showArrow = false,
  });
}
