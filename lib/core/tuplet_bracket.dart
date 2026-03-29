// lib/core/tuplet_bracket.dart

import 'note.dart';  // ✅ Import needed for Note type

/// Lado of the colchete de tuplet
enum BracketSide {
  /// Lado of the stem (default)
  stem,

  /// Lado of the cabeça of the note (used in música vocal)
  notehead,
}

/// Configuresção of the colchete de tuplet
class TupletBracket {
  /// Espessura of the linha of the colchete (0.125 staff spaces por default)
  final double thickness;

  /// Comprimento dos ganchos nas extremidades
  final double hookLength;

  /// Mostrar colchete
  final bool show;

  /// Lado where o colchete aparece
  final BracketSide side;

  /// Inclinação of the colchete (0 = horizontal)
  /// Máximo recomendado: 1.75 staff spaces de diferença vertical
  final double slope;

  /// Distância mínima of the colchete às notes (0.75 staff spaces)
  final double minDistanceFromNotes;

  /// Máxima inclinação permitida (1.75 staff spaces)
  static const double maxSlope = 1.75;

  const TupletBracket({
    this.thickness = 0.125,
    this.hookLength = 0.9,
    this.show = true,
    this.side = BracketSide.stem,
    this.slope = 0.0,
    this.minDistanceFromNotes = 0.75,
  });

  /// Determina se o colchete deve ser mostrado with base nas notes
  ///
  /// Regras (Behind Bars standard):
  /// - Not mostrar se all as notes estão beamed juntas
  /// - MOSTRAR se está of the lado of the cabeça (música vocal)
  /// - MOSTRAR se notes not têm beams ou há rests
  /// - MOSTRAR se show=false (força escwherer)
  bool shouldShow(List<dynamic> notes) {
    // Se está of the lado of the cabeça, always mostrar
    if (side == BracketSide.notehead) return true;

    // Se show=false, forçar escwherer
    if (!show) return false;

    // ✅ CORREÇÃO P9: Checksr se all as notes têm beam
    // Se sim, escwherer bracket (Behind Bars standard)
    // Se not (rests, unbeamed notes), mostrar bracket

    // Filtrar apenas Notes (ignorar rests)
    final actualNotes = notes.whereType<Note>().toList();

    // Se not há notes, ou há rests misturados, mostrar bracket
    if (actualNotes.isEmpty || actualNotes.length < notes.length) {
      return true;
    }

    // Checksr se All as notes têm beam defined
    final allNotesBeamed = actualNotes.every((note) => note.beam != null);

    // Se all têm beam, escwherer bracket (apenas mostrar number)
    // Se alguma not tem beam, mostrar bracket
    return !allNotesBeamed;
  }
}
