// lib/core/tuplet.dart

import 'musical_element.dart';
import 'note.dart';
import 'rest.dart';
import 'chord.dart';
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
  
  /// Elementos within of the tuplet (notes, pausas)
  final List<MusicalElement> elements;
  
  /// Only as notes (filtradas de elements)
  final List<Note> notes;
  
  /// configuração of the bracket
  final TupletBracket? bracketConfig;
  
  /// configuração of the number
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
    
    // If aninhada, aplicar modificador of the pai recursivamente
    if (isNested && parentTuplet != null) {
      return parentTuplet!.getModifiedDuration(modifiedDuration);
    }
    
    return modifiedDuration;
  }
  
  /// Real duração que a quiáltera ocupa no compasso, em semibreves.
  ///
  /// Soma a duração escrita de **cada** elemento e aplica a razão
  /// `normalNotes / actualNotes` uma única vez.
  ///
  /// A implementação anterior lia apenas a PRIMEIRA nota e multiplicava por
  /// [actualNotes], o que assumia que toda quiáltera é homogênea. Isso estava
  /// errado em três casos comuns:
  ///
  /// * duraçōes mistas — uma tercina de colcheia + semínima + colcheia é
  ///   perfeitamente legal e era medida como três colcheias;
  /// * quiálteras só com pausas ou só com acordes — `whereType<Note>()` não
  ///   encontrava nada e a duração virava **0.0**, colapsando o tempo de tudo
  ///   que vinha depois;
  /// * quiálteras aninhadas — o grupo interno não era contado.
  ///
  /// Como o onset musical de cada evento é derivado daqui, um erro deste valor
  /// desloca tudo o que segue — inclusive o alinhamento entre pautas e a
  /// seleção por intervalo de tempo.
  double get totalDuration {
    if (elements.isEmpty) return 0.0;

    double written = 0.0;
    for (final element in elements) {
      if (element is Note) {
        written += element.duration.realValue;
      } else if (element is Rest) {
        written += element.duration.realValue;
      } else if (element is Chord) {
        // Um acorde soa uma vez, não uma vez por nota.
        written += element.duration.realValue;
      } else if (element is Tuplet) {
        // Já traz a própria razão aplicada.
        written += element.totalDuration;
      }
    }

    return written * ratio.modifier;
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
  
  /// Atalhos for criar tuplets comuns
  
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
