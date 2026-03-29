// lib/core/neume.dart
//
// Noteção de Neuma (MEI v5 — Capítulo: Neume Notetion)
// Suporte a canto gregoriano and noteção litúrgica medieval.

import 'musical_element.dart';

/// Forma of the componente de neuma (MEI `@nc.form` or `@form` in `<nc>`).
///
/// Each forma correspwhere a a type específico de neuma simples or ornamental.
enum NcForm {
  /// Point simples (punctum)
  punctum,
  /// Virga (point with stem ascendente)
  virga,
  /// Quilisma (note oscilante)
  quilisma,
  /// Oriscus
  oriscus,
  /// Stropha
  stropha,
  /// Liquescência ascendente
  liquescentAscending,
  /// Liquescência descendente
  liquescentDescending,
  /// Forma conectada (ligado a note seguinte)
  connected,
}

/// Intervalo direcional between neumas consecutivos.
enum NeumeInterval {
  /// Uníssono (same height)
  unison,
  /// Passo above
  stepAbove,
  /// Passo below
  stepBelow,
  /// Salto above (>= terça)
  leapAbove,
  /// Salto below (>= terça)
  leapBelow,
}

/// Representa a componente individual de neuma (MEI `<nc>` — neume component).
///
/// A neume component is a unidade mínima de a figure de neuma, equivalente
/// aproximadamente a a note in CMN. Can ter height (if adiastemático with
/// lines guia, or in noteção quadrada with staff).
///
/// ```dart
/// NeumeComponent(
///   pitchName: 'G',
///   octave: 3,
///   form: NcForm.punctum,
/// )
/// ```
class NeumeComponent {
  /// Name of the note (C–B), if a noteção is diastema (with height definida).
  final String? pitchName;

  /// Oitava of the note.
  final int? octave;

  /// Forma gráfica of the componente.
  final NcForm form;

  /// Direction of the intervalo in relação to the componente previous.
  final NeumeInterval? interval;

  /// Indicates if this componente is liquescente.
  final bool isLiquescent;

  /// Indicates conexão with o next componente (ligature graphique).
  final bool connected;

  const NeumeComponent({
    this.pitchName,
    this.octave,
    this.form = NcForm.punctum,
    this.interval,
    this.isLiquescent = false,
    this.connected = false,
  });
}

/// Type de neuma composto, identificando o default rhythmic-melódico clássico.
enum NeumeType {
  // === Neumas simples ===
  /// Punctum — note única
  punctum,
  /// Virga — note única with stem
  virga,
  /// Bivirga
  bivirga,
  /// Trivirga
  trivirga,

  // === Neumas de dois sons ===
  /// Pes / Podatus (ascendente)
  pes,
  /// Clivis (descendente)
  clivis,

  // === Neumas de três sons ===
  /// Scandicus (dois passos ascendentes)
  scandicus,
  /// Climacus (dois passos descendentes)
  climacus,
  /// Torculus (ascendente + descendente)
  torculus,
  /// Porrectus (descendente + ascendente)
  porrectus,

  // === Neumas de quatro sons ===
  /// Torculus resupinus
  torculusResupinus,
  /// Porrectus flexus
  porrectusFlexus,
  /// Scandicus flexus
  scandicusFlexus,
  /// Climacus resupinus
  climacusResupinus,

  // === Neumas especiais ===
  /// Quilisma (grupo with quilisma)
  quilismaGroup,
  /// Oriscus
  oriscusGroup,
  /// Salicus
  salicus,
  /// Trigon
  trigon,

  /// Neuma de type indefinido / customizado
  custom,
}

/// Representa a neuma completo (MEI `<neume>`).
///
/// A neuma is a grupo de sons (componentes) that formam a unidade rhythmic-
/// melódica na noteção gregoriana. Correspwhere a a or more syllables de text.
///
/// ```dart
/// Neume(
///   type: NeumeType.pes,
///   components: [
///     NeumeComponent(pitchName: 'F', octave: 3, form: NcForm.punctum),
///     NeumeComponent(pitchName: 'G', octave: 3, form: NcForm.virga),
///   ],
/// )
/// ```
class Neume extends MusicalElement {
  /// Type de neuma.
  final NeumeType type;

  /// Componentes of the neuma, in ordem de performance.
  final List<NeumeComponent> components;

  /// Syllable de text associada (lyric of the canto).
  final String? syllable;

  /// Indicates a tradition de noteção (quadrada, adiastemática, etc.).
  final NeumeNotationStyle notationStyle;

  Neume({
    required this.type,
    required this.components,
    this.syllable,
    this.notationStyle = NeumeNotationStyle.square,
  });
}

/// Style de noteção de neuma.
enum NeumeNotationStyle {
  /// Noteção quadrada (noteção gregoriana with staff, séc. XII in diante)
  square,
  /// Noteção adiastemática (sans staff, only direction melódica)
  adiastematic,
  /// Noteção neumática alemã (Hufnagel)
  hufnagel,
  /// Noteção aquitana (points on/about line)
  aquitanian,
  /// Noteção beneventana
  beneventan,
}

/// Indicates a divisão between palavras / respiração no canto gregoriano.
/// Correspwhere to the elemento `<division>` of the MEI v5.
class NeumeDivision extends MusicalElement {
  /// Type de divisão (respiração between syllables).
  final NeumeDivisionType type;

  NeumeDivision({this.type = NeumeDivisionType.minima});
}

/// Type de divisão no canto gregoriano.
enum NeumeDivisionType {
  /// Divisão mínima (curta paUses)
  minima,
  /// Divisão smaller
  minor,
  /// Divisão greater
  maior,
  /// Divisão final (finalis)
  finalis,
}
