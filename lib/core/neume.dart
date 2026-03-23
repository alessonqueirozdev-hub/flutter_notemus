// lib/core/neume.dart
//
// Notação de Neuma (MEI v5 — Capítulo: Neume Notation)
// Suporte a canto gregoriano e notação litúrgica medieval.

import 'musical_element.dart';

/// Forma do componente de neuma (MEI `@nc.form` ou `@form` em `<nc>`).
///
/// Cada forma corresponde a um tipo específico de neuma simples ou ornamental.
enum NcForm {
  /// Ponto simples (punctum)
  punctum,
  /// Virga (ponto com haste ascendente)
  virga,
  /// Quilisma (nota oscilante)
  quilisma,
  /// Oriscus
  oriscus,
  /// Stropha
  stropha,
  /// Liquescência ascendente
  liquescentAscending,
  /// Liquescência descendente
  liquescentDescending,
  /// Forma conectada (ligado a nota seguinte)
  connected,
}

/// Intervalo direcional entre neumas consecutivos.
enum NeumeInterval {
  /// Uníssono (mesma altura)
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
/// Um neume component é a unidade mínima de uma figura de neuma, equivalente
/// aproximadamente a uma nota em CMN. Pode ter altura (se adiastemático com
/// linhas guia, ou em notação quadrada com pauta).
///
/// ```dart
/// NeumeComponent(
///   pitchName: 'G',
///   octave: 3,
///   form: NcForm.punctum,
/// )
/// ```
class NeumeComponent {
  /// Nome da nota (C–B), se a notação é diastema (com altura definida).
  final String? pitchName;

  /// Oitava da nota.
  final int? octave;

  /// Forma gráfica do componente.
  final NcForm form;

  /// Direção do intervalo em relação ao componente anterior.
  final NeumeInterval? interval;

  /// Indica se este componente é liquescente.
  final bool isLiquescent;

  /// Indica conexão com o próximo componente (ligature graphique).
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

/// Tipo de neuma composto, identificando o padrão rítmico-melódico clássico.
enum NeumeType {
  // === Neumas simples ===
  /// Punctum — nota única
  punctum,
  /// Virga — nota única com haste
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
  /// Quilisma (grupo com quilisma)
  quilismaGroup,
  /// Oriscus
  oriscusGroup,
  /// Salicus
  salicus,
  /// Trigon
  trigon,

  /// Neuma de tipo indefinido / customizado
  custom,
}

/// Representa um neuma completo (MEI `<neume>`).
///
/// Um neuma é um grupo de sons (componentes) que formam uma unidade rítmico-
/// melódica na notação gregoriana. Corresponde a uma ou mais sílabas de texto.
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
  /// Tipo de neuma.
  final NeumeType type;

  /// Componentes do neuma, em ordem de performance.
  final List<NeumeComponent> components;

  /// Sílaba de texto associada (letra do canto).
  final String? syllable;

  /// Indica a tradição de notação (quadrada, adiastemática, etc.).
  final NeumeNotationStyle notationStyle;

  Neume({
    required this.type,
    required this.components,
    this.syllable,
    this.notationStyle = NeumeNotationStyle.square,
  });
}

/// Estilo de notação de neuma.
enum NeumeNotationStyle {
  /// Notação quadrada (notação gregoriana com pauta, séc. XII em diante)
  square,
  /// Notação adiastemática (sans pauta, apenas direção melódica)
  adiastematic,
  /// Notação neumática alemã (Hufnagel)
  hufnagel,
  /// Notação aquitana (pontos sobre linha)
  aquitanian,
  /// Notação beneventana
  beneventan,
}

/// Indica a divisão entre palavras / respiração no canto gregoriano.
/// Corresponde ao elemento `<division>` do MEI v5.
class NeumeDivision extends MusicalElement {
  /// Tipo de divisão (respiração entre sílabas).
  final NeumeDivisionType type;

  NeumeDivision({this.type = NeumeDivisionType.minima});
}

/// Tipo de divisão no canto gregoriano.
enum NeumeDivisionType {
  /// Divisão mínima (curta pausa)
  minima,
  /// Divisão menor
  minor,
  /// Divisão maior
  maior,
  /// Divisão final (finalis)
  finalis,
}
