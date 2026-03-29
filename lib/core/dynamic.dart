// lib/core/dynamic.dart

import 'musical_element.dart';

/// Tipos de dynamics musicais
enum DynamicType {
  // Básicas
  pianississimo,
  pianissimo,
  piano,
  mezzoPiano,
  mezzoForte,
  forte,
  fortissimo,
  fortississimo,

  // Extremas
  pppp,
  ppppp,
  pppppp,
  ffff,
  fffff,
  ffffff,

  // Abreviações
  ppp,
  pp,
  p,
  mp,
  mf,
  f,
  ff,
  fff,

  // Especiais
  sforzando,
  sforzandoFF,
  sforzandoPiano,
  sforzandoPianissimo,
  rinforzando,
  fortePiano,
  crescendo,
  diminuendo,
  niente,

  // Dynamics especiais
  subito,
  possibile,
  menoMosso,
  piuMosso,
  custom,
}

/// Representa a indicação dynamic
class Dynamic extends MusicalElement {
  final DynamicType type;
  final String? customText;
  final bool isHairpin;
  final double? length;

  Dynamic({
    required this.type,
    this.customText,
    this.isHairpin = false,
    this.length,
  });
}
