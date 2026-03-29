// lib/core/neume.dart
//
// Noteção de Neuma (MEI v5 — Capítulo: Neume Notetion)
// Suporte a canto gregoriano e noteção litúrgica medieval.

import 'musical_element.dart';

/// Forma of the componente de neuma (MEI `@nc.form` ou `@form` in `<nc>`).
///
/// Each forma correspwhere a um type específico de neuma simples ou ornamental.
enum NcForm {
  /// Ponto simples (punctum)
  punctum,
  /// Virga (ponto with stem ascendente)
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

/// Intervalo direcional entre neumas consecutivos.
enum NeumeInterval {
  /// Uníssono (mesma height)
  unison,
  /// Passo acima
  stepAbove,
  /// Passo abaixo
  stepBelow,
  /// Salto acima (>= terça)
  leapAbove,
  /// Salto abaixo (>= terça)
  leapBelow,
}

/// Representa um componente individual de neuma (MEI `<nc>` — neume component).
///
/// Um neume component é a unidade mínima de a figura de neuma, equivalente
/// aproximadamente a a note in CMN. Pode ter height (se adiastemático with
/// linhas guia, ou in noteção quadrada with staff).
///
/// ```dart
/// NeumeComponent(
///   pitchName: 'G',
///   octave: 3,
///   form: NcForm.punctum,
/// )
/// ```
class NeumeComponent {
  /// Name of the note (C–B), se a noteção é diastema (with height definida).
  final String? pitchName;

  /// Oitava of the note.
  final int? octave;

  /// Forma gráfica of the componente.
  final NcForm form;

  /// Direção of the intervalo in relação ao componente previous.
  final NeumeInterval? interval;

  /// Indica se this componente é liquescente.
  final bool isLiquescent;

  /// Indica conexão with o next componente (ligature graphique).
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

/// Type de neuma composto, identificando o default rítmico-melódico clássico.
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

/// Representa um neuma completo (MEI `<neume>`).
///
/// Um neuma é um grupo de sons (componentes) that formam a unidade rítmico-
/// melódica na noteção gregoriana. Correspwhere a a ou mais syllables de texto.
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

  /// Syllable de texto associada (letra of the canto).
  final String? syllable;

  /// Indica a tradição de noteção (quadrada, adiastemática, etc.).
  final NeumeNotationStyle notationStyle;

  Neume({
    required this.type,
    required this.components,
    this.syllable,
    this.notationStyle = NeumeNotationStyle.square,
  });
}

/// Estilo de noteção de neuma.
enum NeumeNotationStyle {
  /// Noteção quadrada (noteção gregoriana with staff, séc. XII in diante)
  square,
  /// Noteção adiastemática (sans staff, apenas direção melódica)
  adiastematic,
  /// Noteção neumática alemã (Hufnagel)
  hufnagel,
  /// Noteção aquitana (pontos sobre linha)
  aquitanian,
  /// Noteção beneventana
  beneventan,
}

/// Indica a divisão entre palavras / respiração no canto gregoriano.
/// Correspwhere ao elemento `<division>` of the MEI v5.
class NeumeDivision extends MusicalElement {
  /// Type de divisão (respiração entre syllables).
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
