// lib/core/tuplet.dart

import 'musical_element.dart';
import 'note.dart';
import 'time_signature.dart';
import 'tuplet_bracket.dart';
import 'tuplet_number.dart';

/// Razão de uma quiáltera
class TupletRatio {
  final int actualNotes;  // Numerador
  final int normalNotes;  // Denominador

  const TupletRatio(this.actualNotes, this.normalNotes);
  
  /// Modificador que será aplicado às durações
  /// Fórmula: normalNotes / actualNotes
  double get modifier => normalNotes / actualNotes;
  
  @override
  String toString() => '$actualNotes:$normalNotes';
}

/// Representa uma quiáltera (tercina, quintina, etc.)
/// 
/// Implementação completa baseada em Behind Bars (Elaine Gould)
class Tuplet extends MusicalElement {
  /// Numerador da razão (número de notas na quiáltera)
  final int actualNotes;
  
  /// Denominador da razão (número de notas normais que seriam tocadas)
  final int normalNotes;
  
  /// Elementos dentro da quiáltera (notas, pausas)
  final List<MusicalElement> elements;
  
  /// Apenas as notas (filtradas de elements)
  final List<Note> notes;
  
  /// Configuração do colchete
  final TupletBracket? bracketConfig;
  
  /// Configuração do número
  final TupletNumber? numberConfig;
  
  /// Mostrar colchete (deprecated - use bracketConfig)
  @Deprecated('Use bracketConfig.show')
  final bool showBracket;
  
  /// Mostrar número (deprecated - use numberConfig)
  @Deprecated('Use numberConfig')
  final bool showNumber;
  
  /// Razão da quiáltera
  final TupletRatio ratio;
  
  /// Se é uma quiáltera aninhada (nested tuplet)
  final bool isNested;
  
  /// Quiáltera pai (para nested tuplets)
  final Tuplet? parentTuplet;
  
  /// TimeSignature de contexto (para validação)
  final TimeSignature? timeSignature;
  
  Tuplet({
    required this.actualNotes,
    required this.normalNotes,
    required this.elements,
    List<Note>? notes,
    this.bracketConfig,
    this.numberConfig,
    @Deprecated('Use bracketConfig') this.showBracket = true,
    @Deprecated('Use numberConfig') this.showNumber = true,
    TupletRatio? ratio,
    this.isNested = false,
    this.parentTuplet,
    this.timeSignature,
  }) : notes = notes ?? elements.whereType<Note>().toList(),
       ratio = ratio ?? TupletRatio(actualNotes, normalNotes);
  
  /// Calcula a duração modificada de uma nota dentro da quiáltera
  /// 
  /// Se aninhada, aplica modificadores recursivamente
  double getModifiedDuration(double baseDuration) {
    double modifiedDuration = baseDuration * ratio.modifier;
    
    // Se aninhada, aplicar modificador do pai recursivamente
    if (isNested && parentTuplet != null) {
      return parentTuplet!.getModifiedDuration(modifiedDuration);
    }
    
    return modifiedDuration;
  }
  
  /// Calcula a duração total que a quiáltera ocupa
  double get totalDuration {
    if (elements.isEmpty) return 0.0;
    
    // Assumir que todas as notas têm a mesma duração base
    // (isso pode ser expandido para suportar valores mistos)
    final firstNote = elements.whereType<Note>().firstOrNull;
    if (firstNote == null) return 0.0;
    
    final singleDuration = firstNote.duration.realValue;
    final totalBefore = singleDuration * actualNotes;
    return totalBefore * ratio.modifier;
  }
  
  /// Verifica se deve mostrar o colchete
  bool get shouldShowBracket {
    if (bracketConfig != null) {
      return bracketConfig!.shouldShow(notes);
    }
    return showBracket;
  }
  
  /// Verifica se deve mostrar a razão completa (ex: 3:2) vs apenas numerador (3)
  bool get shouldShowRatio {
    if (numberConfig != null) {
      return numberConfig!.showAsRatio;
    }
    return TupletNumber.shouldShowRatio(actualNotes, normalNotes, timeSignature);
  }
  
  /// Texto do número a ser exibido
  String get numberText {
    if (numberConfig != null) {
      return numberConfig!.generateText(actualNotes, normalNotes);
    }
    
    if (shouldShowRatio) {
      return '$actualNotes:$normalNotes';
    }
    return actualNotes.toString();
  }
  
  /// Atalhos para criar quiálteras comuns
  
  /// Tercina (3:2)
  factory Tuplet.triplet({
    required List<MusicalElement> elements,
    TupletBracket? bracketConfig,
    TupletNumber? numberConfig,
    TimeSignature? timeSignature,
  }) {
    return Tuplet(
      actualNotes: 3,
      normalNotes: 2,
      elements: elements,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
    );
  }
  
  /// Quintina (5:4)
  factory Tuplet.quintuplet({
    required List<MusicalElement> elements,
    TupletBracket? bracketConfig,
    TupletNumber? numberConfig,
    TimeSignature? timeSignature,
  }) {
    return Tuplet(
      actualNotes: 5,
      normalNotes: 4,
      elements: elements,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
    );
  }
  
  /// Sextina (6:4)
  factory Tuplet.sextuplet({
    required List<MusicalElement> elements,
    TupletBracket? bracketConfig,
    TupletNumber? numberConfig,
    TimeSignature? timeSignature,
  }) {
    return Tuplet(
      actualNotes: 6,
      normalNotes: 4,
      elements: elements,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
    );
  }
  
  /// Septina (7:4)
  factory Tuplet.septuplet({
    required List<MusicalElement> elements,
    TupletBracket? bracketConfig,
    TupletNumber? numberConfig,
    TimeSignature? timeSignature,
  }) {
    return Tuplet(
      actualNotes: 7,
      normalNotes: 4,
      elements: elements,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
    );
  }
  
  /// Dupleto em tempo composto (2:3)
  factory Tuplet.duplet({
    required List<MusicalElement> elements,
    TupletBracket? bracketConfig,
    TupletNumber? numberConfig,
    TimeSignature? timeSignature,
  }) {
    return Tuplet(
      actualNotes: 2,
      normalNotes: 3,
      elements: elements,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
    );
  }
}
