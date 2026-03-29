// lib/core/tuplet_bracket.dart

import 'note.dart';  // ✅ Import needed for Note type

/// Lado of the bracket de tuplet
enum BracketSide {
  /// Lado of the stem (default)
  stem,

  /// Lado of the cabeça of the note (used in music vocal)
  notehead,
}

/// Configuresção of the bracket de tuplet
class TupletBracket {
  /// Thickness of the line of the bracket (0.125 staff spaces by default)
  final double thickness;

  /// Length dos ganchos nas extremidades
  final double hookLength;

  /// Mostrar bracket
  final bool show;

  /// Lado where o bracket aparece
  final BracketSide side;

  /// Slope of the bracket (0 = horizontal)
  /// Máximo recomendado: 1.75 staff spaces de diferença vertical
  final double slope;

  /// Distance mínima of the bracket às notes (0.75 staff spaces)
  final double minDistanceFromNotes;

  /// Máxima slope permitida (1.75 staff spaces)
  static const double maxSlope = 1.75;

  const TupletBracket({
    this.thickness = 0.125,
    this.hookLength = 0.9,
    this.show = true,
    this.side = BracketSide.stem,
    this.slope = 0.0,
    this.minDistanceFromNotes = 0.75,
  });

  /// Determina if o bracket must be mostrado with base nas notes
  ///
  /// Regras (Behind Bars standard):
  /// - Not mostrar if all as notes are beamed juntas
  /// - MOSTRAR if está of the lado of the cabeça (music vocal)
  /// - MOSTRAR if notes not têm beams or há rests
  /// - MOSTRAR if show=false (força escwherer)
  bool shouldShow(List<dynamic> notes) {
    // If está of the lado of the cabeça, always mostrar
    if (side == BracketSide.notehead) return true;

    // If show=false, forçar escwherer
    if (!show) return false;

    // ✅ CORREÇÃO P9: Check if all as notes têm beam
    // If sim, escwherer bracket (Behind Bars standard)
    // If not (rests, unbeamed notes), mostrar bracket

    // Filtrar only Notes (ignorar rests)
    final actualNotes = notes.whereType<Note>().toList();

    // If not há notes, or há rests misturados, mostrar bracket
    if (actualNotes.isEmpty || actualNotes.length < notes.length) {
      return true;
    }

    // Check if All as notes têm beam defined
    final allNotesBeamed = actualNotes.every((note) => note.beam != null);

    // If all têm beam, escwherer bracket (only mostrar number)
    // If some not tem beam, mostrar bracket
    return !allNotesBeamed;
  }
}
