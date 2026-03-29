// lib/core/tuplet.dart

import 'musical_element.dart';
import 'note.dart';
import 'time_signature.dart';
import 'tuplet_bracket.dart';
import 'tuplet_number.dart';

/// Razão de a tuplet
class TupletRatio {
  final int actualNotes;  // Numerador
  final int normalNotes;  // Denominador

  const TupletRatio(this.actualNotes, this.normalNotes);
  
  /// Modificador that será Appliesdo às durações
  /// Fórmula: normalNotes / actualNotes
  double get modifier => normalNotes / actualNotes;
  
  @override
  String toString() => '$actualNotes:$normalNotes';
}

/// Representa a tuplet (tercina, quintina, etc.)
/// 
/// Implementação completa baseada in Behind Bars (Elaine Gould)
class Tuplet extends MusicalElement {
  /// Numerador of the razão (number de notes na tuplet)
  final int actualNotes;
  
  /// Denominador of the razão (number de notes normais that seriam tocadas)
  final int normalNotes;
  
  /// Elementos dentro of the tuplet (notes, paUsess)
  final List<MusicalElement> elements;
  
  /// Apenas as notes (filtradas de elements)
  final List<Note> notes;
  
  /// Configuresção of the colchete
  final TupletBracket? bracketConfig;
  
  /// Configuresção of the number
  final TupletNumber? numberConfig;
  
  /// Mostrar colchete (deprecated - use bracketConfig)
  @Deprecated('Use bracketConfig.show')
  final bool showBracket;
  
  /// Mostrar number (deprecated - use numberConfig)
  @Deprecated('Use numberConfig')
  final bool showNumber;
  
  /// Razão of the tuplet
  final TupletRatio ratio;
  
  /// Se é a tuplet aninhada (nested tuplet)
  final bool isNested;
  
  /// Tuplet pai (for nested tuplets)
  final Tuplet? parentTuplet;
  
  /// TimeSignature de contexto (for validação)
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
  
  /// Calculatestes a duração modificada de a note dentro of the tuplet
  /// 
  /// Se aninhada, applies modificadores recursivamente
  double getModifiedDuration(double baseDuration) {
    double modifiedDuration = baseDuration * ratio.modifier;
    
    // Se aninhada, Appliesr modificador of the pai recursivamente
    if (isNested && parentTuplet != null) {
      return parentTuplet!.getModifiedDuration(modifiedDuration);
    }
    
    return modifiedDuration;
  }
  
  /// Calculatestes a duração total that a tuplet ocupa
  double get totalDuration {
    if (elements.isEmpty) return 0.0;
    
    // Assumir that all as notes têm a mesma duração base
    // (isso pode ser expandido for suportar valores mistos)
    final firstNote = elements.whereType<Note>().firstOrNull;
    if (firstNote == null) return 0.0;
    
    final singleDuration = firstNote.duration.realValue;
    final totalBefore = singleDuration * actualNotes;
    return totalBefore * ratio.modifier;
  }
  
  /// Checks se deve mostrar o colchete
  bool get shouldShowBracket {
    if (bracketConfig != null) {
      return bracketConfig!.shouldShow(notes);
    }
    return showBracket;
  }
  
  /// Checks se deve mostrar a razão completa (ex: 3:2) vs apenas numerador (3)
  bool get shouldShowRatio {
    if (numberConfig != null) {
      return numberConfig!.showAsRatio;
    }
    return TupletNumber.shouldShowRatio(actualNotes, normalNotes, timeSignature);
  }
  
  /// Texto of the number a ser exibido
  String get numberText {
    if (numberConfig != null) {
      return numberConfig!.generateText(actualNotes, normalNotes);
    }
    
    if (shouldShowRatio) {
      return '$actualNotes:$normalNotes';
    }
    return actualNotes.toString();
  }
  
  /// Atalhos for Createsr tuplets comuns
  
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
  
  /// Dupleto in tempo composto (2:3)
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
