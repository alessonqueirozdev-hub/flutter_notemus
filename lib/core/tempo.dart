// lib/core/tempo.dart

import 'musical_element.dart';
import 'duration.dart';

/// Representa a indicação de tempo/tempo
class TempoMark extends MusicalElement {
  final DurationType beatUnit;
  final int? bpm;
  final String? text;
  final bool showMetronome;

  TempoMark({
    required this.beatUnit,
    this.bpm,
    this.text,
    this.showMetronome = true,
  });
}

/// Marca de metrônomo
class MetronomeMark extends MusicalElement {
  final DurationType? beatUnit;
  final DurationType? secondBeatUnit;
  final int? bpm;
  final String? text;

  MetronomeMark({
    this.beatUnit,
    this.secondBeatUnit,
    this.bpm,
    this.text,
  });
}
