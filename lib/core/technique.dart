// lib/core/technique.dart

import 'musical_element.dart';

/// Tipos de técnicas de execução
enum TechniqueType {
  pizzicato,
  snapPizzicato,
  colLegno,
  bowOnBridge,
  bowOnTailpiece,
  sulTasto,
  sulPonticello,
  martellato,
  ricochet,
  jet,
  vibrato,
  naturalHarmonic,
  artificialHarmonic,
  // Técnicas estendidas
  multiphonics,
  overblowing,
  tongueram,
  circularBreathing,
  flutter,
  whistle,
  growl,
}

/// Representa uma técnica de execução
class PlayingTechnique extends MusicalElement {
  final TechniqueType type;
  final String? text;

  PlayingTechnique({required this.type, this.text});
}

/// Técnicas específicas de nota
enum NoteTechnique {
  harmonic,
  glissando,
  tremolo,
  bend,
  slide,
  vibrato,
  tapping,
  hammer,
  pullOff,
  pinchHarmonic,
  artificialHarmonic,
  palmMute,
  deadNote,
  ghost,
  // Técnicas especiais
  chokeSymbol,
  damp,
  dampAll,
  openRim,
  closedRim,
}
