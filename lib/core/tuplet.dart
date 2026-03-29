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
  
  /// Modificador that será Applied às durações
  /// Fórmula: normalNotes / actualNotes
  double get modifier => normalNotes / actualNotes;
  
  @override
  String toString() => '$actualNotes:$normalNotes';
}

/// Representa a tuplet (tercina, quintina, etc.)
/// 
/// Implementation completa baseada in Behind Bars (Elaine Gould)
class Tuplet extends MusicalElement {
  /// Numerator of the razão (number de notes na tuplet)
  final int actualNotes;
  
  /// Denominator of the razão (number de notes normais that seriam tocadas)
  final int normalNotes;
  
  /// Elementos within of the tuplet (notes, paUsess)
  final List<MusicalElement> elements;
  
  /// Only as notes (filtradas de elements)
  final List<Note> notes;
  
  /// Configuresção of the bracket
  final TupletBracket? bracketConfig;
  
  /// Configuresção of the number
  final TupletNumber? numberConfig;
  
  /// Mostrar bracket (deprecated - use bracketConfig)
  @Deprecated('Use bracketConfig.show')
  final bool showBracket;
  
  /// Mostrar number (deprecated - use numberConfig)
  @Deprecated('Use numberConfig')
  final bool showNumber;
  
  /// Razão of the tuplet
  final TupletRatio ratio;
  
  /// If is a tuplet aninhada (nested tuplet)
  final bool isNested;
  
  /// Tuplet pai (for nested tuplets)
  final Tuplet? parentTuplet;
  
  /// TimeSignature de context (for validação)
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
  
  /// Calculates a duração modificada de a note within of the tuplet
  /// 
  /// If aninhada, applies modificadores recursivamente
  double getModifiedDuration(double baseDuration) {
    double modifiedDuration = baseDuration * ratio.modifier;
    
    // If aninhada, Appliesr modificador of the pai recursivamente
    if (isNested && parentTuplet != null) {
      return parentTuplet!.getModifiedDuration(modifiedDuration);
    }
    
    return modifiedDuration;
  }
  
  /// Calculates a duração total that a tuplet ocupa
  double get totalDuration {
    if (elements.isEmpty) return 0.0;
    
    // Assumir that all as notes têm a same duração base
    // (isso can be expanded for suportar valores mistos)
    final firstNote = elements.whereType<Note>().firstOrNull;
    if (firstNote == null) return 0.0;
    
    final singleDuration = firstNote.duration.realValue;
    final totalBefore = singleDuration * actualNotes;
    return totalBefore * ratio.modifier;
  }
  
  /// Checks if must mostrar o bracket
  bool get shouldShowBracket {
    if (bracketConfig != null) {
      return bracketConfig!.shouldShow(notes);
    }
    return showBracket;
  }
  
  /// Checks if must mostrar a razão completa (ex: 3:2) vs only numerator (3)
  bool get shouldShowRatio {
    if (numberConfig != null) {
      return numberConfig!.showAsRatio;
    }
    return TupletNumber.shouldShowRatio(actualNotes, normalNotes, timeSignature);
  }
  
  /// Text of the number a ser displayed
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
