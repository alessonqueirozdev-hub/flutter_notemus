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
  ///
  /// **Apojaturas não contam.** Uma nota de ornamento (`Note.isGraceNote`) é
  /// um ornamento, não parte do valor escrito do grupo: ela é desenhada e
  /// ocupa largura, mas o relógio não avança por ela. Essa é exatamente a
  /// regra que `Measure.musicalValueOf` (e o `MidiMapper`) já aplicam, e as
  /// duas implementações discordavam: medido, uma tercina 3:2 contendo uma
  /// apojatura devolvia `totalDuration = 0.3333` contra
  /// `musicalValueOf = 0.25`. Como o `LayoutEngine` usa `musicalValueOf` para
  /// o onset e o resto do pacote lê `totalDuration`, a grade de onsets
  /// compartilhada do ADR-002 — a única razão pela qual duas pautas de um
  /// grande sistema se alinham — divergia para qualquer quiáltera ornamentada.
  double get totalDuration {
    if (elements.isEmpty) return 0.0;

    double written = 0.0;
    for (final element in elements) {
      if (element is Note) {
        if (element.isGraceNote) continue;
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
  
  /// Whether this group prints a bracket, under Behind Bars p.201.
  ///
  /// **Behaviour change (2.7.2), and it moves ink.** An UN-CONFIGURED tuplet no
  /// longer always gets a bracket. It gets a bracket *unless its notes are
  /// joined by a beam* — a beamed group is already delimited by its own beam,
  /// so Gould has it print the numeral ALONE, which is what Sibelius, Finale
  /// and MuseScore all print. Measured on a 3:2 triplet of three beamed
  /// eighths at `staffSpace = 12`: 1960 dark pixels before, 1832 after — the
  /// 128 px the bracket and its two hooks were adding over a beam that already
  /// said the same thing.
  ///
  /// The old behaviour was not a decision, it was the absence of one. This
  /// getter was a getter and had ZERO callers in `lib/`, `example/` and
  /// `test/`; `TupletRenderer` gated on the deprecated [showBracket] instead,
  /// which defaults to `true`, so every tuplet ever drawn by this package was
  /// bracketed and `bracketConfig` was inert too — measured, a triplet built
  /// with `bracketConfig: TupletBracket(show: false)` rasterised to the same
  /// 1960 px as the default. The rule existed, was fixed twice, and was never
  /// asked.
  ///
  /// The author still wins, in this order:
  ///
  /// 1. the deprecated [showBracket] `= false` suppresses unconditionally;
  /// 2. [bracketConfig] decides — `show: false` off, `alwaysShow: true` or
  ///    [BracketSide.notehead] on;
  /// 3. otherwise the automatic rule, evaluated against a default
  ///    [TupletBracket].
  ///
  /// Note that `showBracket: true` is NOT read as "force on". It cannot be:
  /// it is the constructor's default, so `true` carries no evidence that anyone
  /// asked for it — `parser_support.dart` passes a literal `true` for every
  /// tuplet it builds, and honouring that would disable the rule for every
  /// parsed score. Force-on is spelled `bracketConfig: TupletBracket(
  /// alwaysShow: true)`.
  ///
  /// [beamOf] is the beam decision, taken by whoever HAS it — pass
  /// `LayoutEngine.beamOf`, or `TupletRenderer`'s own draw-pass map. `core/`
  /// cannot see the layout and must not: the dependency runs the other way.
  /// Taking the answer as a plain `BeamType? Function(Note)` keeps this class
  /// free of layout types (`BeamType` is core's own), which is why the
  /// parameter lives here rather than the whole method being moved into the
  /// layout — see the ADR-005 note on [TupletBracket.shouldShow]. With no
  /// [beamOf] the rule falls back to the author's own `Note.beam` hint, which
  /// on an automatically beamed score is `null` everywhere and yields the
  /// conservative answer (draw the bracket).
  ///
  /// This was a getter through 2.7.1. It is now a method so it can take that
  /// argument; call sites add `()`. There were none to update.
  bool shouldShowBracket({BeamType? Function(Note note)? beamOf}) {
    // The deprecated flag is only evidence when it is `false` (see above).
    // ignore: deprecated_member_use_from_same_package
    if (!showBracket) return false;
    final config = bracketConfig ?? const TupletBracket();
    return config.shouldShow(elements, beamOf: beamOf);
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
