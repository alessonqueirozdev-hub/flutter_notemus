// lib/core/mensural.dart
//
// Notação Mensural (MEI v5 — Capítulo: Mensural Notation)
// Suporte a notação medieval e renascentista (séc. XIII–XVII).

import 'musical_element.dart';
import 'duration.dart';

/// Forma da cabeça de nota mensural.
enum MensuralHeadShape {
  /// Cabeça oblonga (longa, breve mensural)
  oblique,
  /// Cabeça romboide (semibreve, mínima)
  diamond,
  /// Cabeça redonda (estilo tardio)
  round,
  /// Cabeça quadrada (neuma tardio / ars antiqua)
  square,
}

/// Orientação da plica (haste ornamental em notação mensural).
enum PlicaDirection { up, down }

/// Valor mensural de uma nota (MEI `dur` em contexto mensural).
enum MensuralDuration {
  /// Maxima (Mx)
  maxima,
  /// Longa (L)
  longa,
  /// Breve (B)
  breve,
  /// Semibreve (Sb)
  semibreve,
  /// Mínima (Mn)
  minima,
  /// Semimínima (Sm)
  semiminima,
  /// Fusa (Fu)
  fusa,
  /// Semifusa (Sf)
  semifusa,
}

/// Representa uma nota em notação mensural (MEI `<note>` em contexto mensural).
///
/// Notas mensurais têm atributos específicos que não existem no CMN:
/// - [headShape]: forma da cabeça da nota
/// - [mensurQuality]: qualidade mensural (perfeita/imperfeita)
/// - [plica]: ornamento de plica
///
/// ```dart
/// MensuralNote(
///   pitchName: 'G',
///   octave: 4,
///   duration: MensuralDuration.semibreve,
///   quality: MensuralNoteQuality.perfecta,
/// )
/// ```
class MensuralNote extends MusicalElement {
  /// Nome da nota (C–B).
  final String pitchName;

  /// Oitava.
  final int octave;

  /// Duração mensural.
  final MensuralDuration duration;

  /// Forma da cabeça da nota.
  final MensuralHeadShape headShape;

  /// Qualidade da nota (perfeita = ternária, imperfeita = binária, alterada).
  final MensuralNoteQuality quality;

  /// Indica se esta nota tem plica (ornamento de haste diagonal).
  final PlicaDirection? plica;

  /// Alteração cromática (0 = natural, 1 = sustenido, -1 = bemol).
  final double alter;

  /// Indica se esta nota é colorada (nota de cor) para indicar imperfeição/alteração.
  final bool isColored;

  MensuralNote({
    required this.pitchName,
    required this.octave,
    required this.duration,
    this.headShape = MensuralHeadShape.diamond,
    this.quality = MensuralNoteQuality.imperfecta,
    this.plica,
    this.alter = 0.0,
    this.isColored = false,
  });
}

/// Qualidade de uma nota mensural.
enum MensuralNoteQuality {
  /// Perfeita: divisão ternária (valem 3 unidades menores)
  perfecta,
  /// Imperfeita: divisão binária (valem 2 unidades menores)
  imperfecta,
  /// Alterada: dobra o valor por alteração mensural (apenas breve e semibreve)
  alterata,
}

/// Pausa em notação mensural (MEI `<rest>` com `dur` mensural).
class MensuralRest extends MusicalElement {
  final MensuralDuration duration;
  final int? lines;

  MensuralRest({required this.duration, this.lines});
}

/// Ligatura mensural (MEI `<ligature>`).
///
/// Uma ligatura é um grupo de notas escritas ligadas graficamente, comum
/// na notação medieval. A forma gráfica codifica as durações implicitamente.
///
/// ```dart
/// Ligature(
///   notes: [
///     MensuralNote(pitchName: 'G', octave: 4, duration: MensuralDuration.breve),
///     MensuralNote(pitchName: 'A', octave: 4, duration: MensuralDuration.longa),
///   ],
///   form: LigatureForm.cumpropriete,
/// )
/// ```
class Ligature extends MusicalElement {
  /// Notas que compõem a ligatura.
  final List<MensuralNote> notes;

  /// Forma gráfica da ligatura.
  final LigatureForm form;

  Ligature({required this.notes, this.form = LigatureForm.cumpropriete});
}

/// Forma de ligatura mensural (MEI `@form` em `<ligature>`).
enum LigatureForm {
  /// Cum proprietate, cum perfectione (forma padrão)
  cumpropriete,
  /// Sine proprietate (sem propriedade)
  sinepropriete,
  /// Cum opposita proprietate (com propriedade oposta — indica semibreves)
  cumoppositapropriete,
  /// Sine perfectione
  sineperfectione,
}

/// Definição de mensura (MEI `<mensur>`).
///
/// Especifica as relações de divisão entre os valores mensurais:
/// - [modusmaior]: relação Maxima → Longa (2 ou 3)
/// - [modusmino]: relação Longa → Breve (2 ou 3)
/// - [tempus]: relação Breve → Semibreve (2=binário, 3=ternário)
/// - [prolatio]: relação Semibreve → Mínima (2=minor, 3=maior)
///
/// ```dart
/// Mensur(tempus: 3, prolatio: 2)  // Tempus perfectum, prolatio minor
/// Mensur(tempus: 2, prolatio: 3)  // Tempus imperfectum, prolatio maior
/// ```
class Mensur extends MusicalElement {
  /// Modus maior (relação Maxima/Longa): 2 ou 3.
  final int? modusmaior;

  /// Modus minor (relação Longa/Breve): 2 ou 3.
  final int? modusmino;

  /// Tempus (relação Breve/Semibreve): 2 ou 3.
  final int? tempus;

  /// Prolatio (relação Semibreve/Mínima): 2 ou 3.
  final int? prolatio;

  /// Sinal visual de mensura (círculo, semicírculo, etc.).
  final MensurSign? sign;

  /// Indica mensura com ponto de perfeição.
  final bool dot;

  /// Indica mensura com barra de diminuição (alla breve).
  final bool slash;

  Mensur({
    this.modusmaior,
    this.modusmino,
    this.tempus,
    this.prolatio,
    this.sign,
    this.dot = false,
    this.slash = false,
  });
}

/// Sinal gráfico de mensura.
enum MensurSign {
  /// Círculo (tempus perfectum)
  circle,
  /// Semicírculo (tempus imperfectum)
  semicircle,
  /// Semicírculo cortado (alla breve / cut time mensural)
  cut,
  /// Símbolo C com ponto
  cWithDot,
}

/// Proporção mensural (MEI `<proport>`).
///
/// Indica uma mudança de proporção rítmica (ex.: sesquialtera 3:2,
/// dupla proporção 2:1).
///
/// ```dart
/// ProportMark(num: 3, numbase: 2)  // Sesquialtera (3:2)
/// ProportMark(num: 2, numbase: 1)  // Dupla proporção
/// ```
class ProportMark extends MusicalElement {
  /// Numerador da proporção.
  final int num;

  /// Denominador da proporção.
  final int numbase;

  ProportMark({required this.num, required this.numbase});

  /// Retorna o modificador de duração (numbase / num).
  double get modifier => numbase / num;
}

/// Converte uma duração mensural para valor relativo à semibreve.
/// Apenas indicativo; o valor real depende da mensura ativa.
double mensuralDurationToValue(MensuralDuration duration) =>
    switch (duration) {
      MensuralDuration.maxima     => 8.0,
      MensuralDuration.longa      => 4.0,
      MensuralDuration.breve      => 2.0,
      MensuralDuration.semibreve  => 1.0,
      MensuralDuration.minima     => 0.5,
      MensuralDuration.semiminima => 0.25,
      MensuralDuration.fusa       => 0.125,
      MensuralDuration.semifusa   => 0.0625,
    };

/// Retorna o [DurationType] moderno mais próximo de uma [MensuralDuration].
DurationType mensuralToModernDuration(MensuralDuration d) =>
    switch (d) {
      MensuralDuration.maxima     => DurationType.maxima,
      MensuralDuration.longa      => DurationType.long,
      MensuralDuration.breve      => DurationType.breve,
      MensuralDuration.semibreve  => DurationType.whole,
      MensuralDuration.minima     => DurationType.half,
      MensuralDuration.semiminima => DurationType.quarter,
      MensuralDuration.fusa       => DurationType.eighth,
      MensuralDuration.semifusa   => DurationType.sixteenth,
    };
