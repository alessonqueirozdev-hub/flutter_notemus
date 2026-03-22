// lib/core/octave.dart

import 'musical_element.dart';

/// Tipos de marcações de oitava
enum OctaveType {
  va8,      // 8va (uma oitava acima)
  vb8,      // 8vb (uma oitava abaixo)  
  va15,     // 15ma (duas oitavas acima)
  vb15,     // 15mb (duas oitavas abaixo)
  va22,     // 22da (três oitavas acima)
  vb22,     // 22db (três oitavas abaixo)
}

/// Marca de oitava (8va, 8vb, 15ma, etc.)
class OctaveMark extends MusicalElement {
  final OctaveType type;
  final int startMeasure;
  final int endMeasure;
  final int? startNote;
  final int? endNote;
  final double length; // Comprimento da linha em pixels
  final bool showBracket; // Mostrar colchete no final

  OctaveMark({
    required this.type,
    required this.startMeasure,
    required this.endMeasure,
    this.startNote,
    this.endNote,
    this.length = 100.0,
    this.showBracket = true,
  });

  /// Retorna o deslocamento em oitavas
  int get octaveShift {
    switch (type) {
      case OctaveType.va8:
        return 1;
      case OctaveType.vb8:
        return -1;
      case OctaveType.va15:
        return 2;
      case OctaveType.vb15:
        return -2;
      case OctaveType.va22:
        return 3;
      case OctaveType.vb22:
        return -3;
    }
  }

  /// Retorna o texto da marca
  String get text {
    switch (type) {
      case OctaveType.va8:
        return '8va';
      case OctaveType.vb8:
        return '8vb';
      case OctaveType.va15:
        return '15ma';
      case OctaveType.vb15:
        return '15mb';
      case OctaveType.va22:
        return '22da';
      case OctaveType.vb22:
        return '22db';
    }
  }
}
