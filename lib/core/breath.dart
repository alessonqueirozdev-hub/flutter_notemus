// lib/core/breath.dart

import 'musical_element.dart';

/// Tipos de respiração e cesura
enum BreathType {
  comma,
  tick,
  upbow,
  caesura,
  shortCaesura,
  longCaesura,
  chokeCymbal,
}

/// Representa uma marca de respiração
class Breath extends MusicalElement {
  final BreathType type;

  Breath({required this.type});
}

/// Representa uma cesura
class Caesura extends MusicalElement {
  final BreathType type;

  Caesura({this.type = BreathType.caesura});
  
  /// Retorna o nome do glifo SMuFL apropriado
  String get glyphName {
    switch (type) {
      case BreathType.caesura:
        return 'caesura';
      case BreathType.shortCaesura:
        return 'caesuraShort';
      case BreathType.longCaesura:
        return 'caesuraThick';
      default:
        return 'caesura';
    }
  }
}
