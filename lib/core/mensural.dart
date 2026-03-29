// lib/core/mensural.dart
//
// Noteção Mensural (MEI v5 — Capítulo: Mensural Notetion)
// Suporte a noteção medieval e renascentista (séc. XIII–XVII).

import 'musical_element.dart';
import 'duration.dart';

/// Forma of the notehead mensural.
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

/// Orientação of the plica (stem ornamental in noteção mensural).
enum PlicaDirection { up, down }

/// Value mensural de a note (MEI `dur` in contexto mensural).
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
  /// FUses (Fu)
  fusa,
  /// SemifUses (Sf)
  semifusa,
}

/// Representa a note in noteção mensural (MEI `<note>` in contexto mensural).
///
/// Notes mensurais têm atributos específicos that not existem no CMN:
/// - [headShape]: forma of the cabeça of the note
/// - [mensurQuality]: qualidade mensural (perfeita/imperfeita)
/// - [plica]: ornament de plica
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
  /// Name of the note (C–B).
  final String pitchName;

  /// Oitava.
  final int octave;

  /// Duração mensural.
  final MensuralDuration duration;

  /// Forma of the cabeça of the note.
  final MensuralHeadShape headShape;

  /// Qualidade of the note (perfeita = ternária, imperfeita = binária, alterada).
  final MensuralNoteQuality quality;

  /// Indica se this note tem plica (ornament de stem diagonal).
  final PlicaDirection? plica;

  /// Alteração cromática (0 = natural, 1 = sharp, -1 = flat).
  final double alter;

  /// Indica se this note é colorada (note de cor) for indicar imperfeição/alteração.
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

/// Qualidade de a note mensural.
enum MensuralNoteQuality {
  /// Perfeita: divisão ternária (valem 3 unidades smalleres)
  perfecta,
  /// Imperfeita: divisão binária (valem 2 unidades smalleres)
  imperfecta,
  /// Alterada: dobra o value por alteração mensural (apenas breve e semibreve)
  alterata,
}

/// PaUses in noteção mensural (MEI `<rest>` with `dur` mensural).
class MensuralRest extends MusicalElement {
  final MensuralDuration duration;
  final int? lines;

  MensuralRest({required this.duration, this.lines});
}

/// Ligatura mensural (MEI `<ligature>`).
///
/// A ligatura é um grupo de notes escritas ligadas graficamente, comum
/// na noteção medieval. A forma gráfica codifica as durações implicitamente.
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
  /// Notes that compõem a ligatura.
  final List<MensuralNote> notes;

  /// Forma gráfica of the ligatura.
  final LigatureForm form;

  Ligature({required this.notes, this.form = LigatureForm.cumpropriete});
}

/// Forma de ligatura mensural (MEI `@form` in `<ligature>`).
enum LigatureForm {
  /// Cum proprietate, cum perfectione (forma default)
  cumpropriete,
  /// Sine proprietate (sem property)
  sinepropriete,
  /// Cum opposita proprietate (with property oposta — indica semibreves)
  cumoppositapropriete,
  /// Sine perfectione
  sineperfectione,
}

/// Definição de mensura (MEI `<mensur>`).
///
/// Especifica as relações de divisão entre os valores mensurais:
/// - [modusgreater]: relação Maxima → Longa (2 ou 3)
/// - [modusmino]: relação Longa → Breve (2 ou 3)
/// - [tempus]: relação Breve → Semibreve (2=binário, 3=ternário)
/// - [prolatio]: relação Semibreve → Mínima (2=minor, 3=greater)
///
/// ```dart
/// Mensur(tempus: 3, prolatio: 2)  // Tempus perfectum, prolatio minor
/// Mensur(tempus: 2, prolatio: 3)  // Tempus imperfectum, prolatio greater
/// ```
class Mensur extends MusicalElement {
  /// Modus greater (relação Maxima/Longa): 2 ou 3.
  final int? modusmaior;

  /// Modus minor (relação Longa/Breve): 2 ou 3.
  final int? modusmino;

  /// Tempus (relação Breve/Semibreve): 2 ou 3.
  final int? tempus;

  /// Prolatio (relação Semibreve/Mínima): 2 ou 3.
  final int? prolatio;

  /// Sinal visual de mensura (círculo, semicírculo, etc.).
  final MensurSign? sign;

  /// Indica mensura with ponto de perfeição.
  final bool dot;

  /// Indica mensura with barra de diminuição (alla breve).
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
  /// Símbolo C with ponto
  cWithDot,
}

/// Proporção mensural (MEI `<proport>`).
///
/// Indica a mudança de proporção rítmica (ex.: sesquialtera 3:2,
/// dupla proporção 2:1).
///
/// ```dart
/// ProportMark(num: 3, numbase: 2)  // Sesquialtera (3:2)
/// ProportMark(num: 2, numbase: 1)  // Dupla proporção
/// ```
class ProportMark extends MusicalElement {
  /// Numerador of the proporção.
  final int num;

  /// Denominador of the proporção.
  final int numbase;

  ProportMark({required this.num, required this.numbase});

  /// Returns o modificador de duração (numbase / num).
  double get modifier => numbase / num;
}

/// Converts a duração mensural for value relativo à semibreve.
/// Apenas indicativo; o value real depende of the mensura ativa.
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

/// Returns o [DurationType] moderno mais next de a [MensuralDuration].
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
