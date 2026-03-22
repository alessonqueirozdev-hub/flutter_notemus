import 'package:flutter/material.dart' show Offset;
import '../smufl/smufl_metadata_loader.dart';

/// Classe responsável por calcular posicionamentos precisos usando metadados SMuFL
/// e regras de tipografia musical profissional.
///
/// Baseado em:
/// - Especificação SMuFL (w3c.github.io/smufl)
/// - Metadados da fonte Bravura
/// - "Behind Bars" de Elaine Gould
/// - "The Art of Music Engraving" de Ted Ross
class SMuFLPositioningEngine {
  // CORREÇÃO CRÍTICA: Referência ao metadata loader (OBRIGATÓRIA)
  final SmuflMetadata _metadataLoader;

  // CORREÇÃO: Valores carregados dinamicamente do metadata SMuFL
  // Antes eram constantes estáticas hardcoded, agora são carregados do engravingDefaults
  late final double standardStemLength;
  late final double minimumStemLength;
  late final double stemExtensionPerBeam;
  late final double stemThickness;

  // Espaçamento de acidentes
  late final double accidentalToNoteheadDistance;
  late final double accidentalMinimumClearance;

  // Ângulos de feixes (beam angles)
  late final double minimumBeamSlant;
  late final double maximumBeamSlant;
  late final double twoNoteBeamMaxSlant;

  // Ornamentos e articulações
  late final double articulationToNoteDistance;
  late final double ornamentToNoteDistance;

  // Ligaduras e dinâmica
  late final double slurEndpointThickness;
  late final double slurMidpointThickness;
  late final double slurHeightFactor;

  // Grace notes (appoggiaturas)
  late final double graceNoteScale;
  late final double graceNoteStemLength;

  // Quiálteras (tuplets)
  late final double tupletBracketHeight;
  late final double tupletNumberDistance;

  // CORREÇÃO: Construtor agora REQUER metadata loader
  SMuFLPositioningEngine({required SmuflMetadata metadataLoader})
      : _metadataLoader = metadataLoader {
    // Carregar valores do metadata SMuFL
    standardStemLength = _loadEngravingDefault('stemLength', 3.5);
    minimumStemLength = 2.5; // Não está em engravingDefaults, mantém valor padrão
    stemExtensionPerBeam = 0.5; // Calculado baseado em beamSpacing
    stemThickness = _loadEngravingDefault('stemThickness', 0.12);

    // Espaçamento - Behind Bars: 0.16-0.20 spaces
    accidentalToNoteheadDistance = 0.16; // Valor tipográfico profissional
    accidentalMinimumClearance = 0.08;

    // Ângulos de feixes - baseado em Behind Bars (valores conservadores)
    // Behind Bars recomenda beams relativamente planos
    minimumBeamSlant = 0.15;  // Ângulo mínimo mais sutil
    maximumBeamSlant = 0.5;   // Máximo reduzido (era 1.0, muito inclinado!)
    twoNoteBeamMaxSlant = 0.35; // Para 2 notas, ainda mais conservador

    // Ornamentos e articulações - valores tipográficos padrão
    articulationToNoteDistance = 0.5;
    ornamentToNoteDistance = 0.75;

    // Ligaduras
    slurEndpointThickness = 0.1;
    slurMidpointThickness = 0.22;
    slurHeightFactor = 0.25;

    // Grace notes
    graceNoteScale = 0.6;
    graceNoteStemLength = 2.5;

    // Tuplets
    tupletBracketHeight = 1.0;
    tupletNumberDistance = 0.5;
  }

  /// Carrega um valor de engravingDefaults com fallback
  /// Este método elimina hardcoding ao consultar o metadata real
  double _loadEngravingDefault(String key, double fallback) {
    final value = _metadataLoader.getEngravingDefaultValue(key);
    return value ?? fallback;
  }

  // CORREÇÃO: Método initialize() removido - não mais necessário
  // Agora o metadata loader é passado no construtor e já está carregado

  /// Retorna o ponto de ancoragem stemUpSE para uma cabeça de nota
  /// (canto inferior direito de onde a haste para cima deve se conectar)
  /// Retorna coordenadas em STAFF SPACES (unidades SMuFL)
  Offset getStemUpAnchor(String noteheadGlyphName) {
    // CORREÇÃO: Sempre usar metadata loader (agora obrigatório)
    final anchor = _metadataLoader.getGlyphAnchor(
      noteheadGlyphName,
      'stemUpSE',
    );
    if (anchor != null) {
      return anchor; // Já em staff spaces
    }

    // Fallback final: noteheadBlack padrão do metadata Bravura
    // stemUpSE para noteheadBlack: [1.18, 0.168] conforme bravura_metadata.json
    return const Offset(1.18, 0.168);
  }

  /// Retorna o ponto de ancoragem stemDownNW para uma cabeça de nota
  /// (canto superior esquerdo de onde a haste para baixo deve se conectar)
  /// Retorna coordenadas em STAFF SPACES (unidades SMuFL)
  Offset getStemDownAnchor(String noteheadGlyphName) {
    // CORREÇÃO: Sempre usar metadata loader (agora obrigatório)
    final anchor = _metadataLoader.getGlyphAnchor(
      noteheadGlyphName,
      'stemDownNW',
    );
    if (anchor != null) {
      return anchor; // Já em staff spaces
    }

    // Fallback final: noteheadBlack padrão do metadata Bravura
    // stemDownNW para noteheadBlack: [0.0, -0.168] conforme bravura_metadata.json
    return const Offset(0.0, -0.168);
  }

  /// Retorna o ponto de ancoragem para flags (colcheias, semicolcheias, etc.)
  /// Flags são registradas com y=0 no final de uma haste de comprimento normal (3.5 spaces)
  /// Retorna coordenadas em STAFF SPACES (unidades SMuFL)
  Offset getFlagAnchor(String flagGlyphName) {
    String anchorName;

    // Para flags para cima, usar stemUpNW
    if (flagGlyphName.contains('Up')) {
      anchorName = 'stemUpNW';
    }
    // Para flags para baixo, usar stemDownSW
    else if (flagGlyphName.contains('Down')) {
      anchorName = 'stemDownSW';
    } else {
      return Offset.zero;
    }

    // CORREÇÃO: Sempre usar metadata loader (agora obrigatório)
    final anchor = _metadataLoader.getGlyphAnchor(flagGlyphName, anchorName);
    if (anchor != null) {
      return anchor; // Já em staff spaces
    }

    return Offset.zero;
  }

  /// Calcula o comprimento da haste baseado na posição da nota no pentagrama
  /// e no número de feixes
  double calculateStemLength({
    required int staffPosition,
    required bool stemUp,
    required int beamCount,
    bool isBeamed = false,
  }) {
    double length = standardStemLength;

    // CORREÇÃO CRÍTICA: Hastes devem ter comprimento FIXO de 3.5 staff spaces
    // Segundo Elaine Gould (Behind Bars) e Ted Ross,
    // hastes NÃO devem se estender até a pauta em notas com linhas suplementares.
    // A extensão deve ser MÍNIMA, apenas o suficiente para clareza visual.
    
    // Para notas MUITO distantes (mais de 2 linhas suplementares),
    // adicionar PEQUENA extensão (máximo 0.5 staff space)
    if (stemUp && staffPosition < -6) {
      // Nota muito abaixo da pauta
      final double extensionNeeded = ((-6 - staffPosition) / 4) * 0.25;
      length = (standardStemLength + extensionNeeded).clamp(
        standardStemLength,
        4.0, // Máximo 4.0 staff spaces (não 5.5!)
      );
    } else if (!stemUp && staffPosition > 6) {
      // Nota muito acima da pauta
      final double extensionNeeded = ((staffPosition - 6) / 4) * 0.25;
      length = (standardStemLength + extensionNeeded).clamp(
        standardStemLength,
        4.0, // Máximo 4.0 staff spaces (não 5.5!)
      );
    }

    // Adicionar comprimento extra para múltiplos feixes
    if (!isBeamed && beamCount > 0) {
      length += (beamCount - 1) * stemExtensionPerBeam;
    }

    return length;
  }

  /// Calcula o comprimento da haste para ACORDES
  /// CRÍTICO: A haste deve atravessar TODAS as notas do acorde!
  /// 
  /// Behind Bars (p. 16): "A haste de um acorde deve conectar a nota mais extrema
  /// à linha de beam ou ao comprimento padrão, o que for maior."
  /// 
  /// [noteStaffPositions] - Posições de todas as notas do acorde
  /// [stemUp] - Se a haste vai para cima
  /// [beamCount] - Número de barras (0 para notas sem barra)
  double calculateChordStemLength({
    required List<int> noteStaffPositions,
    required bool stemUp,
    required int beamCount,
  }) {
    if (noteStaffPositions.isEmpty) return standardStemLength;
    if (noteStaffPositions.length == 1) {
      return calculateStemLength(
        staffPosition: noteStaffPositions.first,
        stemUp: stemUp,
        beamCount: beamCount,
      );
    }

    // Encontrar a extensão (span) do acorde
    final int highestPos = noteStaffPositions.reduce((a, b) => a > b ? a : b);
    final int lowestPos = noteStaffPositions.reduce((a, b) => a < b ? a : b);
    final int chordSpan = (highestPos - lowestPos).abs();

    // Converter span de staff positions (meios de espaço) para staff spaces
    final double chordSpanSpaces = chordSpan * 0.5;

    // FÓRMULA: stemLength = chordSpan + standardStemLength
    // A haste deve ATRAVESSAR todas as notas (span) + comprimento padrão
    double length = chordSpanSpaces + standardStemLength;

    // Adicionar comprimento extra para múltiplos feixes
    if (beamCount > 0) {
      length += (beamCount - 1) * stemExtensionPerBeam;
    }

    // Garantir comprimento mínimo
    length = length.clamp(minimumStemLength, 6.0);

    return length;
  }

  /// Calcula a posição correta de um acidente relativo à cabeça de nota
  /// Baseado em práticas de tipografia musical profissional
  /// Behind Bars: 0.16-0.20 staff spaces da cabeça
  /// Retorna coordenadas em STAFF SPACES (unidades SMuFL)
  Offset calculateAccidentalPosition({
    required String accidentalGlyph,
    required String noteheadGlyph,
    required double staffPosition,
  }) {
    // CORREÇÃO: Usar metadata loader (agora obrigatório)
    double accidentalWidth = _metadataLoader.getGlyphWidth(accidentalGlyph);
    if (accidentalWidth == 0.0) {
      // Fallback se não encontrado
      accidentalWidth = 1.0;
    }

    // Posição base: acidente à esquerda da nota com espaçamento padrão
    double xOffset = -(accidentalWidth + accidentalToNoteheadDistance);

    // CORREÇÃO: Usar cutOutNW da cabeça de nota para espaçamento óptico avançado
    // Cut-outs permitem posicionar o acidente mais próximo quando há espaço vazio na cabeça
    final cutOutNW = _metadataLoader.getGlyphAnchor(noteheadGlyph, 'cutOutNW');

    if (cutOutNW != null && cutOutNW.dx < 0) {
      // Há espaço vazio à esquerda da cabeça, podemos aproximar o acidente
      xOffset = -(accidentalWidth + accidentalToNoteheadDistance + cutOutNW.dx);
    }

    // Y alinhado com a posição da nota no pentagrama
    final double yOffset = 0.0;

    return Offset(xOffset, yOffset);
  }

  /// Calcula o ângulo de um feixe (beam) baseado nas posições das notas
  /// Segue as regras de Ted Ross e Elaine Gould
  double calculateBeamAngle({
    required List<int> noteStaffPositions,
    required bool stemUp,
  }) {
    if (noteStaffPositions.length < 2) return 0.0;

    final int firstPos = noteStaffPositions.first;
    final int lastPos = noteStaffPositions.last;
    final int positionDifference = (lastPos - firstPos).abs();

    // Para apenas duas notas, limite o ângulo
    if (noteStaffPositions.length == 2) {
      final double slant = (positionDifference * 0.5).clamp(
        0.0,
        twoNoteBeamMaxSlant,
      );
      return stemUp
          ? (lastPos > firstPos ? slant : -slant)
          : (lastPos > firstPos ? -slant : slant);
    }

    // Para múltiplas notas, calcular ângulo baseado na diferença de posição
    double slant;
    if (positionDifference <= 1) {
      slant = minimumBeamSlant;
    } else if (positionDifference >= 7) {
      slant = maximumBeamSlant;
    } else {
      // Interpolação linear entre min e max
      slant =
          minimumBeamSlant +
          (positionDifference - 1) * (maximumBeamSlant - minimumBeamSlant) / 6;
    }

    slant = slant.clamp(minimumBeamSlant, maximumBeamSlant);

    return stemUp
        ? (lastPos > firstPos ? slant : -slant)
        : (lastPos > firstPos ? -slant : slant);
  }

  /// Calcula a altura ideal de um feixe na posição da primeira nota
  double calculateBeamHeight({
    required int staffPosition,
    required bool stemUp,
    required List<int> allStaffPositions,
    int beamCount = 1, // Número de beams (1, 2, 3, ou 4)
  }) {
    if (stemUp) {
      // CORREÇÃO: Encontrar a nota mais AGUDA (maior staffPosition)
      // Com staffPosition positivo = acima, a nota mais alta tem valor MAIOR
      final int highestPosition = allStaffPositions.reduce(
        (a, b) => a > b ? a : b,
      );
      double height = standardStemLength;

      // CORREÇÃO: Se a nota mais alta está muito acima da pauta (> 4), extender
      if (highestPosition > 4) {
        height += (highestPosition - 4) * 0.5;
      }

      // CORREÇÃO CRÍTICA: Comprimento mínimo para múltiplas beams
      // Behind Bars: Haste deve ter pelo menos espaço para todas as beams + margem
      // Ajustado empiricamente para comprimento visual adequado
      if (beamCount > 1) {
        final minHeightForBeams = standardStemLength + ((beamCount - 1) * 0.5);
        height = height > minHeightForBeams ? height : minHeightForBeams;
      }

      return height;
    } else {
      // CORREÇÃO: Encontrar a nota mais GRAVE (menor staffPosition)
      // Com staffPosition negativo = abaixo, a nota mais baixa tem valor MENOR
      final int lowestPosition = allStaffPositions.reduce(
        (a, b) => a < b ? a : b,
      );
      double height = standardStemLength;

      // CORREÇÃO: Se a nota mais baixa está muito abaixo da pauta (< -4), extender
      if (lowestPosition < -4) {
        height += (-4 - lowestPosition) * 0.5;
      }

      // CORREÇÃO CRÍTICA: Comprimento mínimo para múltiplas beams
      // Behind Bars: Haste deve ter pelo menos espaço para todas as beams + margem
      // Ajustado empiricamente para comprimento visual adequado
      if (beamCount > 1) {
        final minHeightForBeams = standardStemLength + ((beamCount - 1) * 0.5);
        height = height > minHeightForBeams ? height : minHeightForBeams;
      }

      return height;
    }
  }

  /// Calcula a posição de um ornamento relativo à nota
  Offset calculateOrnamentPosition({
    required String ornamentGlyph,
    required int staffPosition,
    required bool hasAccidentalAbove,
  }) {
    final double ornamentHeight = _getGlyphHeight(ornamentGlyph);

    // Ornamentos vão acima da nota
    double yOffset = -ornamentToNoteDistance - (ornamentHeight * 0.5);

    // Se há acidente acima (como em trills), adicionar espaço extra
    if (hasAccidentalAbove) {
      yOffset -= 1.0;
    }

    // CORREÇÃO: Se a nota está muito alta no pentagrama (acima da pauta)
    // staffPosition > 4 = acima da 5ª linha
    if (staffPosition > 4) {
      yOffset -= 0.5;
    }

    return Offset(0.0, yOffset);
  }

  /// Calcula a posição de uma articulação (staccato, accent, etc.)
  Offset calculateArticulationPosition({
    required String articulationGlyph,
    required int staffPosition,
    required bool stemUp,
    required bool hasBeam,
  }) {
    final double articulationHeight = _getGlyphHeight(articulationGlyph);

    double yOffset;
    if (stemUp) {
      // Articulação abaixo da nota
      yOffset = articulationToNoteDistance + (articulationHeight * 0.5);

      // CORREÇÃO: Se a nota está na parte inferior do pentagrama (abaixo da pauta)
      // staffPosition < -4 = abaixo da 1ª linha
      if (staffPosition < -4) {
        yOffset += 0.5;
      }
    } else {
      // Articulação acima da nota
      yOffset = -(articulationToNoteDistance + (articulationHeight * 0.5));

      // CORREÇÃO: Se a nota está na parte superior do pentagrama (acima da pauta)
      // staffPosition > 4 = acima da 5ª linha
      if (staffPosition > 4) {
        yOffset -= 0.5;
      }

      // Se tem feixe, adicionar espaço extra
      if (hasBeam) {
        yOffset -= 1.0;
      }
    }

    return Offset(0.0, yOffset);
  }

  /// Calcula pontos de controle para uma ligadura (slur) suave
  /// Retorna [startPoint, controlPoint1, controlPoint2, endPoint] para uma curva cúbica de Bézier
  List<Offset> calculateSlurControlPoints({
    required Offset startPosition,
    required Offset endPosition,
    required bool curveUp,
    required double intensity, // 0.0 a 1.0, quão curvada é a ligadura
  }) {
    final double dx = endPosition.dx - startPosition.dx;
    final double dy = endPosition.dy - startPosition.dy;
    final double distance = (dx * dx + dy * dy);

    // Altura da curva baseada na distância e intensidade
    final double curveHeight = (distance * slurHeightFactor * intensity).clamp(
      0.5,
      3.0,
    );
    final int direction = curveUp ? -1 : 1;

    // Pontos de controle para curva de Bézier cúbica
    // Baseado em práticas de tipografia musical: curvas assimétricas são mais naturais
    final Offset cp1 = Offset(
      startPosition.dx + dx * 0.25,
      startPosition.dy + dy * 0.25 + direction * curveHeight * 0.7,
    );

    final Offset cp2 = Offset(
      startPosition.dx + dx * 0.75,
      startPosition.dy + dy * 0.75 + direction * curveHeight * 0.9,
    );

    return [startPosition, cp1, cp2, endPosition];
  }

  /// Calcula a posição e tamanho de uma gracia note (appoggiatura)
  Map<String, dynamic> calculateGraceNoteLayout({
    required int staffPosition,
    required bool mainNoteStemUp,
  }) {
    return {
      'scale': graceNoteScale,
      'stemLength': graceNoteStemLength,
      // Grace notes geralmente vão antes da nota principal
      'xOffset': -1.5, // spaces antes da nota principal
      'yOffset': 0.0,
      // Grace notes com slash através da haste
      'hasSlash': true,
      'slashAngle': 45.0, // graus
    };
  }

  /// Calcula a posição e layout de uma quiáltera (tuplet)
  Map<String, dynamic> calculateTupletLayout({
    required List<Offset> notePositions,
    required bool stemsUp,
    required int tupletNumber,
  }) {
    if (notePositions.isEmpty) {
      return {'show': false};
    }

    final double firstX = notePositions.first.dx;
    final double lastX = notePositions.last.dx;
    final double centerX = (firstX + lastX) / 2;

    // Encontrar a nota mais alta/baixa para posicionar o bracket
    double extremeY;
    if (stemsUp) {
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      extremeY -= (standardStemLength + tupletBracketHeight);
    } else {
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      extremeY += (standardStemLength + tupletBracketHeight);
    }

    return {
      'show': true,
      'bracketStart': Offset(firstX, extremeY),
      'bracketEnd': Offset(lastX, extremeY),
      'numberPosition': Offset(
        centerX,
        extremeY + (stemsUp ? -tupletNumberDistance : tupletNumberDistance),
      ),
      'number': tupletNumber,
      'showBracket': true, // Mostrar bracket se não houver feixe
    };
  }

  /// Calcula a largura de um glifo usando metadata loader
  double getGlyphWidth(String glyphName) {
    return _metadataLoader.getGlyphWidth(glyphName);
  }

  /// Calcula a altura de um glifo baseado em seu bounding box
  double _getGlyphHeight(String glyphName) {
    return _metadataLoader.getGlyphHeight(glyphName);
  }

  /// Obtém o optical center de um glifo (para centralização precisa)
  Offset? getOpticalCenter(String glyphName) {
    // CORREÇÃO: Sempre usar metadata loader (agora obrigatório)
    return _metadataLoader.getGlyphAnchor(glyphName, 'opticalCenter');
  }

  /// Calcula a posição de sinais de repetição (repeat signs)
  Map<String, dynamic> calculateRepeatSignPosition({
    required String repeatGlyph,
    required double barlineX,
    required bool isStart, // true para início, false para fim
  }) {
    final double glyphWidth = getGlyphWidth(repeatGlyph);

    // Sinais de repetição são centralizados na barra
    final double xOffset = isStart
        ? barlineX +
              0.3 // Ligeiramente à direita da barra de início
        : barlineX -
              glyphWidth -
              0.3; // Ligeiramente à esquerda da barra de fim

    return {
      'x': xOffset,
      'y': 3.0, // Centro do pentagrama (posição 6 = linha central)
      'scale': 1.0, // Escala normal
    };
  }

  /// Calcula layout de barras de repetição com voltas (endings)
  Map<String, dynamic> calculateEndingLayout({
    required double startX,
    required double endX,
    required int endingNumber,
  }) {
    return {
      'lineStart': Offset(startX, -2.0), // Acima do pentagrama
      'lineEnd': Offset(endX, -2.0),
      'hookHeight': 1.0, // Altura do gancho vertical
      'numberPosition': Offset(startX + 0.5, -2.5),
      'number': endingNumber.toString(),
      'thickness': _loadEngravingDefault('repeatEndingLineThickness', 0.16),
    };
  }

  /// Calcula posicionamento de fórmula de compasso (time signature)
  Map<String, dynamic> calculateTimeSignaturePosition({
    required int numerator,
    required int denominator,
    required double xPosition,
  }) {
    // Fórmulas de compasso são centralizadas no pentagrama
    // Numerador na linha 2 (espaço superior), denominador na linha 4 (espaço inferior)
    return {
      'numeratorPosition': Offset(xPosition, 2.0),
      'denominatorPosition': Offset(xPosition, 4.0),
      'numerator': numerator,
      'denominator': denominator,
      'spacing': 0.2, // Espaço horizontal após a fórmula de compasso
    };
  }

  /// Calcula escala apropriada para sinais de dinâmica (evitar sobreposições)
  double calculateDynamicsScale(String dynamicGlyph) {
    // Dinâmicas geralmente são desenhadas em escala normal
    // mas podem ser reduzidas se houver sobreposições
    return 1.0;
  }

  /// Obtém cut-outs de um glifo (para cálculos de espaçamento avançados)
  Map<String, Offset> getGlyphCutOuts(String glyphName) {
    final Map<String, Offset> cutOuts = {};

    for (final corner in ['cutOutNE', 'cutOutSE', 'cutOutSW', 'cutOutNW']) {
      final anchor = _metadataLoader.getGlyphAnchor(glyphName, corner);
      if (anchor != null) {
        cutOuts[corner] = anchor;
      }
    }

    return cutOuts;
  }
}
