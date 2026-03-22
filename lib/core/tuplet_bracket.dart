// lib/core/tuplet_bracket.dart

import 'note.dart';  // ✅ Import needed for Note type

/// Lado do colchete de quiáltera
enum BracketSide {
  /// Lado da haste (padrão)
  stem,

  /// Lado da cabeça da nota (usado em música vocal)
  notehead,
}

/// Configuração do colchete de quiáltera
class TupletBracket {
  /// Espessura da linha do colchete (0.125 staff spaces por padrão)
  final double thickness;

  /// Comprimento dos ganchos nas extremidades
  final double hookLength;

  /// Mostrar colchete
  final bool show;

  /// Lado onde o colchete aparece
  final BracketSide side;

  /// Inclinação do colchete (0 = horizontal)
  /// Máximo recomendado: 1.75 staff spaces de diferença vertical
  final double slope;

  /// Distância mínima do colchete às notas (0.75 staff spaces)
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

  /// Determina se o colchete deve ser mostrado com base nas notas
  ///
  /// Regras (Behind Bars standard):
  /// - NÃO mostrar se todas as notas estão beamed juntas
  /// - MOSTRAR se está do lado da cabeça (música vocal)
  /// - MOSTRAR se notas não têm beams ou há rests
  /// - MOSTRAR se show=false (força esconder)
  bool shouldShow(List<dynamic> notes) {
    // Se está do lado da cabeça, sempre mostrar
    if (side == BracketSide.notehead) return true;

    // Se show=false, forçar esconder
    if (!show) return false;

    // ✅ CORREÇÃO P9: Verificar se todas as notas têm beam
    // Se sim, esconder bracket (Behind Bars standard)
    // Se não (rests, unbeamed notes), mostrar bracket

    // Filtrar apenas Notes (ignorar rests)
    final actualNotes = notes.whereType<Note>().toList();

    // Se não há notas, ou há rests misturados, mostrar bracket
    if (actualNotes.isEmpty || actualNotes.length < notes.length) {
      return true;
    }

    // Verificar se TODAS as notas têm beam definido
    final allNotesBeamed = actualNotes.every((note) => note.beam != null);

    // Se todas têm beam, esconder bracket (apenas mostrar número)
    // Se alguma não tem beam, mostrar bracket
    return !allNotesBeamed;
  }
}
