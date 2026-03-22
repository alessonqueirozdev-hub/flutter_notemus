// lib/core/repeat.dart

import 'musical_element.dart';

/// Tipos de repetição
enum RepeatType {
  start,
  end,
  segno,
  coda,
  dalSegno,
  dalSegnoAlCoda,
  dalSegnoAlFine,
  daCapo,
  daCapoAlCoda,
  daCapoAlFine,
  fine,
  toCoda,
  segnoSquare,
  codaSquare,
  repeat1Bar,
  repeat2Bars,
  repeat4Bars,
  simile,
  percentRepeat,
  repeatDots,
  repeatLeft,
  repeatRight,
  repeatBoth,
}

/// Representa uma marca de repetição
class RepeatMark extends MusicalElement {
  final RepeatType type;
  final String? label;
  final int? times;

  RepeatMark({required this.type, this.label, this.times});
}
