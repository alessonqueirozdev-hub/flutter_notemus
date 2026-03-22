// lib/src/smufl/glyph_categories.dart

/// Categorias completas de símbolos SMuFL organizadas por função musical
class SmuflGlyphCategories {
  // === CLAVES ===
  static const Map<String, String> clefs = {
    'gClef': 'Clave de Sol',
    'gClef8va': 'Clave de Sol 8ª acima',
    'gClef8vb': 'Clave de Sol 8ª abaixo',
    'gClef15ma': 'Clave de Sol 15ª acima',
    'gClef15mb': 'Clave de Sol 15ª abaixo',
    'fClef': 'Clave de Fá',
    'fClef8va': 'Clave de Fá 8ª acima',
    'fClef8vb': 'Clave de Fá 8ª abaixo',
    'fClef15ma': 'Clave de Fá 15ª acima',
    'fClef15mb': 'Clave de Fá 15ª abaixo',
    'cClef': 'Clave de Dó',
    'cClef8vb': 'Clave de Dó 8ª abaixo',
    'unpitchedPercussionClef1': 'Clave de Percussão 1',
    'unpitchedPercussionClef2': 'Clave de Percussão 2',
    '6stringTabClef': 'Clave de Tablatura 6 cordas',
    '4stringTabClef': 'Clave de Tablatura 4 cordas',
  };

  // === CABEÇAS DE NOTA ===
  static const Map<String, String> noteheads = {
    'noteheadWhole': 'Semibreve',
    'noteheadHalf': 'Mínima',
    'noteheadBlack': 'Semínima e menores',
    'noteheadDoubleWhole': 'Breve',
    'noteheadDoubleWholeSquare': 'Breve quadrada',
    'noteheadHalfFilled': 'Mínima preenchida',
    'noteheadNull': 'Cabeça vazia',
    'noteheadXOrnate': 'X ornamentada',
    'noteheadXBlack': 'X preta',
    'noteheadXHalf': 'X mínima',
    'noteheadXWhole': 'X semibreve',
    'noteheadPlusBlack': 'Plus preta',
    'noteheadPlusHalf': 'Plus mínima',
    'noteheadPlusWhole': 'Plus semibreve',
    'noteheadCircleXBlack': 'Círculo X preta',
    'noteheadCircleXHalf': 'Círculo X mínima',
    'noteheadCircleXWhole': 'Círculo X semibreve',
    'noteheadTriangleUpBlack': 'Triângulo para cima preta',
    'noteheadTriangleUpHalf': 'Triângulo para cima mínima',
    'noteheadTriangleUpWhole': 'Triângulo para cima semibreve',
    'noteheadTriangleLeftBlack': 'Triângulo esquerda preta',
    'noteheadTriangleRightBlack': 'Triângulo direita preta',
    'noteheadDiamondBlack': 'Diamante preta',
    'noteheadDiamondHalf': 'Diamante mínima',
    'noteheadDiamondWhole': 'Diamante semibreve',
    'noteheadSlashedBlack1': 'Cortada 1 preta',
    'noteheadSlashedHalf1': 'Cortada 1 mínima',
    'noteheadSlashedWhole1': 'Cortada 1 semibreve',
  };

  // === ACIDENTES ===
  static const Map<String, String> accidentals = {
    'accidentalFlat': 'Bemol',
    'accidentalNatural': 'Bequadro',
    'accidentalSharp': 'Sustenido',
    'accidentalDoubleFlat': 'Dobrado bemol',
    'accidentalDoubleSharp': 'Dobrado sustenido',
    'accidentalTripleFlat': 'Triplo bemol',
    'accidentalTripleSharp': 'Triplo sustenido',
    'accidentalQuarterToneFlatStein': 'Quarto de tom bemol',
    'accidentalQuarterToneSharpStein': 'Quarto de tom sustenido',
    'accidentalThreeQuarterTonesFlatZimmermann': 'Três quartos de tom bemol',
    'accidentalThreeQuarterTonesSharpStein': 'Três quartos de tom sustenido',
    'accidentalKomaFlat': 'Koma bemol',
    'accidentalKomaSharp': 'Koma sustenido',
  };

  // === PAUSAS ===
  static const Map<String, String> rests = {
    'restMaxima': 'Pausa de máxima',
    'restLonga': 'Pausa de longa',
    'restDoubleWhole': 'Pausa de breve',
    'restWhole': 'Pausa de semibreve',
    'restHalf': 'Pausa de mínima',
    'restQuarter': 'Pausa de semínima',
    'rest8th': 'Pausa de colcheia',
    'rest16th': 'Pausa de semicolcheia',
    'rest32nd': 'Pausa de fusa',
    'rest64th': 'Pausa de semifusa',
    'rest128th': 'Pausa de quartifusa',
    'rest256th': 'Pausa de octifusa',
    'rest512th': 'Pausa de decimassexta',
    'rest1024th': 'Pausa de trigésima segunda',
  };

  // === BANDEIROLAS ===
  static const Map<String, String> flags = {
    'flag8thUp': 'Bandeirola colcheia para cima',
    'flag8thDown': 'Bandeirola colcheia para baixo',
    'flag16thUp': 'Bandeirola semicolcheia para cima',
    'flag16thDown': 'Bandeirola semicolcheia para baixo',
    'flag32ndUp': 'Bandeirola fusa para cima',
    'flag32ndDown': 'Bandeirola fusa para baixo',
    'flag64thUp': 'Bandeirola semifusa para cima',
    'flag64thDown': 'Bandeirola semifusa para baixo',
    'flag128thUp': 'Bandeirola quartifusa para cima',
    'flag128thDown': 'Bandeirola quartifusa para baixo',
    'flag256thUp': 'Bandeirola octifusa para cima',
    'flag256thDown': 'Bandeirola octifusa para baixo',
    'flag512thUp': 'Bandeirola decimassexta para cima',
    'flag512thDown': 'Bandeirola decimassexta para baixo',
    'flag1024thUp': 'Bandeirola trigésima segunda para cima',
    'flag1024thDown': 'Bandeirola trigésima segunda para baixo',
  };

  // === FÓRMULAS DE COMPASSO ===
  static const Map<String, String> timeSignatures = {
    'timeSig0': 'Número 0',
    'timeSig1': 'Número 1',
    'timeSig2': 'Número 2',
    'timeSig3': 'Número 3',
    'timeSig4': 'Número 4',
    'timeSig5': 'Número 5',
    'timeSig6': 'Número 6',
    'timeSig7': 'Número 7',
    'timeSig8': 'Número 8',
    'timeSig9': 'Número 9',
    'timeSigCommon': 'Compasso comum (C)',
    'timeSigCutCommon': 'Compasso cortado (Φ)',
    'timeSigPlus': 'Mais (+)',
    'timeSigMinus': 'Menos (-)',
    'timeSigMultiply': 'Multiplicação (×)',
    'timeSigParensLeft': 'Parênteses esquerdo',
    'timeSigParensRight': 'Parênteses direito',
    'timeSigEquals': 'Igual (=)',
    'timeSigFractionalSlash': 'Barra fracional',
  };

  // === ARTICULAÇÕES ===
  static const Map<String, String> articulations = {
    'articAccentAbove': 'Acento acima',
    'articAccentBelow': 'Acento abaixo',
    'articStaccatoAbove': 'Staccato acima',
    'articStaccatoBelow': 'Staccato abaixo',
    'articTenutoAbove': 'Tenuto acima',
    'articTenutoBelow': 'Tenuto abaixo',
    'articStaccatissimoAbove': 'Staccatissimo acima',
    'articStaccatissimoBelow': 'Staccatissimo abaixo',
    'articMarcatoAbove': 'Marcato acima',
    'articMarcatoBelow': 'Marcato abaixo',
    'articMarcatoStaccatoAbove': 'Marcato staccato acima',
    'articMarcatoStaccatoBelow': 'Marcato staccato abaixo',
    'articAccentStaccatoAbove': 'Acento staccato acima',
    'articAccentStaccatoBelow': 'Acento staccato abaixo',
    'articTenutoStaccatoAbove': 'Tenuto staccato acima',
    'articTenutoStaccatoBelow': 'Tenuto staccato abaixo',
    'articTenutoAccentAbove': 'Tenuto acento acima',
    'articTenutoAccentBelow': 'Tenuto acento abaixo',
    'articStressAbove': 'Stress acima',
    'articStressBelow': 'Stress abaixo',
    'articUnstressAbove': 'Unstress acima',
    'articUnstressBelow': 'Unstress abaixo',
  };

  // === ORNAMENTOS ===
  static const Map<String, String> ornaments = {
    'ornamentTrill': 'Trinado',
    'ornamentTrillFlat': 'Trinado com bemol',
    'ornamentTrillNatural': 'Trinado com bequadro',
    'ornamentTrillSharp': 'Trinado com sustenido',
    'ornamentMordent': 'Mordente',
    'ornamentShortTrill': 'Trinado curto',
    'ornamentTurn': 'Grupeto',
    'ornamentTurnInverted': 'Grupeto invertido',
    'ornamentTurnSlash': 'Grupeto cortado',
    'ornamentAppoggiaturaUp': 'Apogiatura para cima',
    'ornamentAppoggiaturaDown': 'Apogiatura para baixo',
    'ornamentPrecompMordentUpperPrefix': 'Mordente superior prefixo',
    'ornamentPrecompMordentLowerPrefix': 'Mordente inferior prefixo',
    'ornamentPrecompSlide': 'Glissando ornamental',
    'ornamentZigZagLineNoRightEnd': 'Linha zigzag sem fim direito',
    'ornamentZigZagLineWithRightEnd': 'Linha zigzag com fim direito',
  };

  // === DINÂMICAS ===
  static const Map<String, String> dynamics = {
    'dynamicPiano': 'Piano (p)',
    'dynamicMezzo': 'Mezzo (m)',
    'dynamicForte': 'Forte (f)',
    'dynamicPP': 'Pianissimo (pp)',
    'dynamicMP': 'Mezzo piano (mp)',
    'dynamicMF': 'Mezzo forte (mf)',
    'dynamicFF': 'Fortissimo (ff)',
    'dynamicPPP': 'Pianississimo (ppp)',
    'dynamicFFF': 'Fortississimo (fff)',
    'dynamicPPPP': 'Pianissississimo (pppp)',
    'dynamicFFFF': 'Fortissississimo (ffff)',
    'dynamicPPPPP': 'Pianississississimo (ppppp)',
    'dynamicFFFFF': 'Fortississississimo (fffff)',
    'dynamicPPPPPP': 'Pianissississississimo (pppppp)',
    'dynamicFFFFFF': 'Fortissississississimo (ffffff)',
    'dynamicSforzando1': 'Sforzando',
    'dynamicSforzando2': 'Sforzando 2',
    'dynamicSforzatoFF': 'Sforzato ff',
    'dynamicSforzatoPiano': 'Sforzato piano',
    'dynamicRinforzando1': 'Rinforzando',
    'dynamicRinforzando2': 'Rinforzando 2',
    'dynamicCrescendoHairpin': 'Crescendo',
    'dynamicDiminuendoHairpin': 'Diminuendo',
  };

  // === BARRAS DE COMPASSO ===
  static const Map<String, String> barlines = {
    'barlineSingle': 'Barra simples',
    'barlineDouble': 'Barra dupla',
    'barlineFinal': 'Barra final',
    'barlineRepeatDots': 'Pontos de repetição',
    'barlineRepeatLeft': 'Repetição esquerda',
    'barlineRepeatRight': 'Repetição direita',
    'barlineThick': 'Barra grossa',
    'barlineThin': 'Barra fina',
    'barlineDashed': 'Barra tracejada',
    'barlineDotted': 'Barra pontilhada',
    'barlineShort': 'Barra curta',
    'barlineTick': 'Tick',
  };

  // === NÚMEROS ===
  static const Map<String, String> numbers = {
    'tuplet0': 'Número 0 (quiáltera)',
    'tuplet1': 'Número 1 (quiáltera)',
    'tuplet2': 'Número 2 (quiáltera)',
    'tuplet3': 'Número 3 (quiáltera)',
    'tuplet4': 'Número 4 (quiáltera)',
    'tuplet5': 'Número 5 (quiáltera)',
    'tuplet6': 'Número 6 (quiáltera)',
    'tuplet7': 'Número 7 (quiáltera)',
    'tuplet8': 'Número 8 (quiáltera)',
    'tuplet9': 'Número 9 (quiáltera)',
    'tupletColon': 'Dois pontos (quiáltera)',
  };

  // === REPETIÇÕES E CODAS ===
  static const Map<String, String> repeats = {
    'segno': 'Segno',
    'coda': 'Coda',
    'codaSquare': 'Coda quadrada',
    'dalSegno': 'Dal Segno',
    'daCapo': 'Da Capo',
    'fine': 'Fine',
    'repeat1Bar': 'Repetir 1 compasso',
    'repeat2Bars': 'Repetir 2 compassos',
    'repeat4Bars': 'Repetir 4 compassos',
    'repeatLeft': 'Repetição esquerda',
    'repeatRight': 'Repetição direita',
    'repeatDots': 'Pontos de repetição',
    'simile': 'Simile',
    'percent': 'Repetição porcentagem',
  };

  // === RESPIRAÇÕES E CAESURAS ===
  static const Map<String, String> breaths = {
    'breathMarkComma': 'Vírgula de respiração',
    'breathMarkTick': 'Tick de respiração',
    'breathMarkUpbow': 'Respiração arco para cima',
    'caesura': 'Caesura',
    'caesuraShort': 'Caesura curta',
    'caesuraThick': 'Caesura grossa',
    'caesuraCurved': 'Caesura curva',
  };

  // === SINAIS DE OITAVA ===
  static const Map<String, String> octaves = {
    'ottava': '8va (oitava acima)',
    'ottavaBassa': '8vb (oitava abaixo)',
    'quindicesima': '15ma (duas oitavas acima)',
    'quindicesimaAlta': '15mb (duas oitavas abaixo)',
    'ventiduesima': '22ma (três oitavas acima)',
    'ventiduesimaAlta': '22mb (três oitavas abaixo)',
  };

  // === CLUSTERS ===
  static const Map<String, String> clusters = {
    'noteClusterSquareBlack': 'Cluster quadrado preto',
    'noteClusterSquareWhite': 'Cluster quadrado branco',
    'noteClusterRoundBlack': 'Cluster redondo preto',
    'noteClusterRoundWhite': 'Cluster redondo branco',
  };

  // === HARMÔNICOS ===
  static const Map<String, String> harmonics = {
    'noteheadDiamondHalf': 'Harmônico natural (losango)',
    'noteheadCircleXHalf': 'Harmônico artificial (círculo X)',
    'stringsHarmonic': 'Harmônico (cordas)',
    'brassMuteOpen': 'Som aberto (sopros)',
    'brassMuteClosed': 'Som fechado (sopros)',
  };

  // === SÍMBOLOS MICROTONAIS ===
  static const Map<String, String> microtonals = {
    'accidentalQuarterToneSharpStein': 'Quarto de tom sustenido',
    'accidentalQuarterToneFlatStein': 'Quarto de tom bemol',
    'accidentalThreeQuarterTonesSharpStein': 'Três quartos de tom sustenido',
    'accidentalThreeQuarterTonesFlatZimmermann': 'Três quartos de tom bemol',
    'accidentalKomaSharp': 'Koma sustenido',
    'accidentalKomaFlat': 'Koma bemol',
    'accSagittal11MediumDiesisUp': 'Sagittal médio diesis para cima',
    'accSagittal11MediumDiesisDown': 'Sagittal médio diesis para baixo',
    'accSagittal11LargeDiesisUp': 'Sagittal grande diesis para cima',
    'accSagittal11LargeDiesisDown': 'Sagittal grande diesis para baixo',
  };

  // === MÉTODOS UTILITÁRIOS ===

  /// Retorna todas as categorias disponíveis
  static Map<String, Map<String, String>> getAllCategories() {
    return {
      'clefs': clefs,
      'noteheads': noteheads,
      'accidentals': accidentals,
      'rests': rests,
      'flags': flags,
      'timeSignatures': timeSignatures,
      'articulations': articulations,
      'ornaments': ornaments,
      'dynamics': dynamics,
      'barlines': barlines,
      'numbers': numbers,
      'repeats': repeats,
      'breaths': breaths,
      'octaves': octaves,
      'clusters': clusters,
      'harmonics': harmonics,
      'microtonals': microtonals,
    };
  }

  /// Busca um glifo por nome em todas as categorias
  static String? findGlyphDescription(String glyphName) {
    final allCategories = getAllCategories();
    for (final category in allCategories.values) {
      if (category.containsKey(glyphName)) {
        return category[glyphName];
      }
    }
    return null;
  }

  /// Retorna a categoria de um glifo
  static String? findGlyphCategory(String glyphName) {
    final allCategories = getAllCategories();
    for (final entry in allCategories.entries) {
      if (entry.value.containsKey(glyphName)) {
        return entry.key;
      }
    }
    return null;
  }

  /// Retorna todos os glifos de uma categoria específica
  static Map<String, String> getGlyphsInCategory(String category) {
    final allCategories = getAllCategories();
    return allCategories[category] ?? {};
  }

  /// Conta total de glifos categorizados
  static int getTotalCategorizedGlyphs() {
    return getAllCategories().values
        .map((category) => category.length)
        .reduce((a, b) => a + b);
  }
}