// lib/core/dynamic.dart

import 'musical_element.dart';

/// Tipos de dinâmicas musicais
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

  // Dinâmicas especiais
  subito,
  possibile,
  menoMosso,
  piuMosso,
  custom,
}

/// Representa uma indicação dinâmica
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
