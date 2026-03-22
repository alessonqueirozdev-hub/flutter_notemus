// lib/src/engraving/engraving_rules.dart

/// Regras de Tipografia Musical (Engraving Rules)
///
/// Esta classe centraliza TODAS as constantes tipográficas usadas
/// na renderização de partituras musicais.
///
/// Baseado em:
/// - OpenSheetMusicDisplay (EngravingRules.ts com 1220+ linhas)
/// - Verovio (vrvdef.h e constantes C++)
/// - "Behind Bars" de Elaine Gould
/// - "The Art of Music Engraving" de Ted Ross
/// - Especificação SMuFL (w3c.github.io/smufl)
/// - Metadata da fonte Bravura
class EngravingRules {
  // ====================
  // UNIDADE BASE
  // ====================

  /// Unidade base: 1.0 = distância entre duas linhas adjacentes do pentagrama
  /// No SMuFL, esta é chamada de "staff space"
  static const double unit = 1.0;

  // ====================
  // HASTES (STEMS)
  // ====================

  /// Comprimento ideal de uma haste (Verovio: 7 half-spaces = 3.5 spaces)
  /// OSMD: 3.0 units
  /// Bravura metadata: stemLength padrão
  double idealStemLength = 3.5;

  /// Offset Y onde a haste toca a borda da cabeça de nota
  /// OSMD: 0.2 units
  double stemNoteHeadBorderYOffset = 0.2;

  /// Largura da haste
  /// Bravura metadata: stemThickness = 0.12 staff spaces
  /// OSMD: 0.15 (mais espesso para web)
  double stemWidth = 0.13;

  /// Comprimento mínimo permitido para hastes
  /// Verovio: Encurtamento máximo de 6 third-units = 2.0 spaces
  double stemMinLength = 2.5;

  /// Comprimento máximo permitido para hastes
  double stemMaxLength = 4.5;

  /// Margem da haste
  double stemMargin = 0.2;

  /// Altura mínima permitida entre cabeça de nota e linha de feixe
  double stemMinAllowedDistanceBetweenNoteHeadAndBeamLine = 1.0;

  // ====================
  // FEIXES (BEAMS)
  // ====================

  /// Espessura de um feixe individual
  /// Bravura metadata: beamThickness = 0.5 staff spaces
  /// OSMD: 0.5 units
  double beamWidth = 0.5;

  /// Espaço entre feixes múltiplos
  /// Bravura metadata: beamSpacing = 0.25 staff spaces
  /// OSMD: 0.33 units (unit / 3.0)
  /// Verovio: beamThickness * 1.5 = 0.75 na prática
  double beamSpaceWidth = 0.25;

  /// Ângulo máximo de inclinação de feixes em graus
  /// OSMD: 10.0°
  /// Verovio: Mais adaptativo, mas limitado
  /// Behind Bars: Feixes devem ser sutis, não excessivos
  double beamSlopeMaxAngle = 10.0;

  /// Comprimento de feixe parcial (broken beam)
  /// OSMD: 1.25 units
  double beamForwardLength = 1.25;

  /// Usar feixes planos (flat beams) em vez de inclinados
  /// Útil para estilos alternativos
  bool flatBeams = false;

  /// Offset de feixes planos
  double flatBeamOffset = 20.0;

  /// Offset por feixe em feixes planos
  double flatBeamOffsetPerBeam = 10.0;

  // ====================
  // ESPAÇAMENTO DE NOTAS
  // ====================

  /// Distâncias de espaçamento por duração
  /// Índice: 0=breve, 1=whole, 2=half, 3=quarter, 4=eighth, 5=16th, 6=32nd, 7=64th
  /// Valores em staff spaces (units)
  /// OSMD: [1.0, 1.0, 1.3, 1.6, 2.0, 2.5, 3.0, 4.0]
  List<double> noteDistances = [
    1.0, // Breve
    1.0, // Whole note
    1.3, // Half note
    1.6, // Quarter note
    2.0, // Eighth note
    2.5, // 16th note
    3.0, // 32nd note
    4.0, // 64th note
  ];

  /// Fatores de escala para duração (exponencial: 1, 2, 4, 8, 16, ...)
  /// Usado em cálculos de espaçamento óptico
  List<double> noteDistancesScalingFactors = [
    1.0, // Breve
    2.0, // Whole
    4.0, // Half
    8.0, // Quarter
    16.0, // Eighth
    32.0, // 16th
    64.0, // 32nd
    128.0, // 64th
  ];

  /// Distância mínima entre notas
  /// OSMD: 2.0 units
  /// Verovio: Configurável
  double minNoteDistance = 2.0;

  /// Margem para notas deslocadas (displaced notes em acordes)
  double displacedNoteMargin = 0.1;

  /// Multiplicador de espaçamento para VexFlow
  /// OSMD: 0.85
  double voiceSpacingMultiplierVexflow = 0.85;

  /// Valor adicionado ao espaçamento VexFlow
  /// OSMD: 3.0
  double voiceSpacingAddendVexflow = 3.0;

  /// Fator softmax para suavizar espaçamento (evitar transições abruptas)
  /// OSMD: 15
  double softmaxFactorVexFlow = 15.0;

  // ====================
  // LIGADURAS DE VALOR (TIES)
  // ====================

  /// Altura mínima de tie
  /// Behind Bars: Ties devem ser discretos, altura mínima ~0.1 SS
  double tieHeightMinimum = 0.1;

  /// Altura máxima de tie
  /// Behind Bars: Mesmo para ties longos, máximo 0.4 SS
  double tieHeightMaximum = 0.4;

  /// Constante K para interpolação linear de altura de tie: y = k*x + d
  /// Reduzido drasticamente para ties mais achatados (Behind Bars)
  double tieHeightInterpolationK = 0.008;

  /// Constante D para interpolação linear de altura de tie: y = k*x + d
  /// Altura base muito pequena para ties discretos
  double tieHeightInterpolationD = 0.05;

  /// Calcula altura de tie baseado na largura
  /// Fórmula: height = k * width + d, limitado por min/max
  double calculateTieHeight(double width) {
    final height = tieHeightInterpolationK * width + tieHeightInterpolationD;
    return height.clamp(tieHeightMinimum, tieHeightMaximum);
  }

  // ====================
  // LIGADURAS DE EXPRESSÃO (SLURS)
  // ====================

  /// Offset Y da cabeça de nota para início/fim de slur
  /// OSMD: 0.5 staff spaces
  double slurNoteHeadYOffset = 0.5;

  /// Offset X da haste para slurs que começam/terminam em hastes
  /// OSMD: 0.3 staff spaces
  double slurStemXOffset = 0.3;

  /// Ângulo máximo de inclinação de slur
  /// OSMD: 15.0°
  double slurSlopeMaxAngle = 15.0;

  /// Ângulo mínimo das tangentes da curva de slur
  /// OSMD: 30.0°
  /// Usado no algoritmo de Bézier avançado
  double slurTangentMinAngle = 30.0;

  /// Ângulo máximo das tangentes da curva de slur
  /// OSMD: 80.0°
  double slurTangentMaxAngle = 80.0;

  /// Fator de altura da curva de slur
  /// OSMD: 1.0 (100%)
  double slurHeightFactor = 1.0;

  /// Número de passos para discretização de curvas Bézier
  /// OSMD: 1000
  /// Usado para pré-calcular curvas
  int bezierCurveStepSize = 1000;

  /// Usar posicionamento de slurs do XML (se disponível)
  bool slurPlacementFromXML = true;

  /// Posicionar slurs nas hastes em vez de nas cabeças
  bool slurPlacementAtStems = false;

  /// Usar skyline/bottomline para posicionamento de slurs
  bool slurPlacementUseSkyBottomLine = false;

  /// Margem mínima de clearance entre slur e notas intermediárias
  /// Garante que o slur não colida com notas no caminho
  /// OSMD: 0.5 staff spaces
  double slurClearanceMinimum = 0.5;

  // ====================
  // ACIDENTES (ACCIDENTALS)
  // ====================

  /// Distância entre símbolos de armadura de clave
  /// OSMD: 0.2 staff spaces
  double betweenKeySymbolsDistance = 0.2;

  /// Margem direita após armadura de clave
  /// OSMD: 0.75 staff spaces
  double keyRightMargin = 0.75;

  /// Distância entre natural e símbolo ao cancelar armadura
  /// OSMD: 0.4 staff spaces
  double distanceBetweenNaturalAndSymbolWhenCancelling = 0.4;

  /// Distância de acidente à cabeça de nota
  /// Behind Bars: 0.16-0.20 staff spaces
  /// SMuFL Positioning Engine: 0.16 staff spaces
  double accidentalToNoteheadDistance = 0.2;

  /// Margem mínima para evitar colisões de acidentes
  double accidentalMinimumClearance = 0.08;

  // ====================
  // ARTICULAÇÕES
  // ====================

  /// Articulação acima da nota quando haste está para cima
  /// OSMD: false (articulação fica do lado oposto da haste)
  /// Behind Bars: Articulações geralmente opostas às hastes
  bool articulationAboveNoteForStemUp = false;

  /// Padding para soft accent wedge
  double softAccentWedgePadding = 0.4;

  /// Fator de tamanho para soft accent
  double softAccentSizeFactor = 0.6;

  /// Fator de escala para staccato
  /// OSMD: 0.8 (80% do tamanho)
  double staccatoScalingFactor = 0.8;

  /// Distância entre pontos (ex: staccatissimo duplo)
  double betweenDotsDistance = 0.8;

  /// Distância de articulação à nota
  /// SMuFL Positioning Engine: 0.5 staff spaces
  double articulationToNoteDistance = 0.5;

  // ====================
  // ORNAMENTOS
  // ====================

  /// Fator de escala para acidentes em ornamentos (ex: trill com sustenido)
  /// OSMD: 0.65 (65% do tamanho)
  double ornamentAccidentalScalingFactor = 0.65;

  /// Distância de ornamento à nota
  /// SMuFL Positioning Engine: 0.75 staff spaces
  double ornamentToNoteDistance = 0.75;

  // ====================
  // LINHAS SUPLEMENTARES (LEDGER LINES)
  // ====================

  /// Extensão das linhas suplementares além da nota
  /// Bravura metadata: legerLineExtension = 0.4 staff spaces
  double legerLineExtension = 0.4;

  /// Espessura das linhas suplementares
  /// Bravura metadata: legerLineThickness = 0.16 staff spaces
  double legerLineWidth = 0.16;

  // ====================
  // ESPESSURAS DE LINHA
  // ====================

  /// Espessura das linhas da pauta
  /// Bravura metadata: staffLineThickness = 0.13 staff spaces
  /// OSMD: 0.10 (mais fino)
  double staffLineWidth = 0.13;

  /// Espessura das linhas suplementares
  /// OSMD: 1 (pixel absoluto, não staff space)
  /// Aqui: 0.16 staff spaces (consistente com Bravura)
  double ledgerLineWidth = 0.16;

  /// Espessura de linha de wedge (crescendo/diminuendo)
  double wedgeLineWidth = 0.12;

  /// Espessura de linha de tuplet bracket
  double tupletLineWidth = 0.12;

  /// Espessura de linha fina de sistema (thin barline)
  /// Bravura metadata: thinBarlineThickness = 0.16 staff spaces
  double systemThinLineWidth = 0.16;

  /// Espessura de linha grossa de sistema (thick barline)
  /// Bravura metadata: thickBarlineThickness = 0.5 staff spaces
  double systemBoldLineWidth = 0.5;

  // ====================
  // BARRAS DE COMPASSO (BARLINES)
  // ====================

  /// Espessura de barra de compasso normal
  double barlineWidth = 0.16;

  /// Espessura de barra de compasso grossa
  double thickBarlineWidth = 0.5;

  /// Separação entre barras de compasso duplas
  /// Bravura metadata: barlineSeparation = 0.4 staff spaces
  double barlineSeparation = 0.4;

  // ====================
  // DINÂMICAS
  // ====================

  /// Distância máxima para agrupar expressões dinâmicas para alinhamento
  /// OSMD: 4.0 staff spaces
  double dynamicExpressionMaxDistance = 4.0;

  // ====================
  // QUIÁLTERAS (TUPLETS)
  // ====================

  /// Altura do bracket de quiáltera acima/abaixo das notas
  /// SMuFL Positioning Engine: 1.0 staff spaces
  double tupletBracketHeight = 1.0;

  /// Distância do número da quiáltera ao bracket
  /// SMuFL Positioning Engine: 0.5 staff spaces
  double tupletNumberDistance = 0.5;

  // ====================
  // GRACE NOTES
  // ====================

  /// Escala de grace notes em relação a notas normais
  /// SMuFL Positioning Engine: 0.6 (60%)
  /// Verovio: ~0.66 (graceFactor)
  double graceNoteScale = 0.6;

  /// Comprimento de haste de grace note
  /// SMuFL Positioning Engine: 2.5 staff spaces
  double graceNoteStemLength = 2.5;

  /// Offset X de grace note antes da nota principal
  /// SMuFL Positioning Engine: -1.5 staff spaces
  double graceNoteXOffset = -1.5;

  /// Grace notes devem ter slash através da haste
  bool graceNoteHasSlash = true;

  /// Ângulo do slash em grace notes
  double graceNoteSlashAngle = 45.0; // graus

  // ====================
  // ESPAÇAMENTO DE SISTEMA
  // ====================

  /// Distância entre pentagramas
  /// OSMD: 7.0 staff spaces
  double staffDistance = 7.0;

  /// Distância adicional entre pentagramas
  /// OSMD: 5.0 staff spaces
  double betweenStaffDistance = 5.0;

  /// Distância mínima entre linhas de pauta
  /// OSMD: 4.0 staff spaces
  double minimumStaffLineDistance = 4.0;

  /// Distância mínima skyline/bottomline entre pentagramas
  /// OSMD: 1.0 staff spaces
  double minSkyBottomDistBetweenStaves = 1.0;

  /// Distância mínima skyline/bottomline entre sistemas
  /// OSMD: 5.0 staff spaces
  double minSkyBottomDistBetweenSystems = 5.0;

  /// Margem do sistema (esquerda/direita)
  /// Layout Engine: 2.0 staff spaces
  double systemMargin = 2.0;

  // ====================
  // ESPAÇAMENTO DE COMPASSO
  // ====================

  /// Largura mínima de compasso
  /// Layout Engine: 4.0 staff spaces
  double measureMinWidth = 4.0;

  /// Espaçamento mínimo de nota
  /// Layout Engine: 2.0 staff spaces (corrigido de 1.5)
  double noteMinSpacing = 2.0;

  /// Padding ao final do compasso
  /// Layout Engine: 1.0 staff spaces
  double measureEndPadding = 1.0;

  // ====================
  // ESCALA DE FONTES
  // ====================

  /// Escala padrão de fonte de notação VexFlow
  /// OSMD: 39
  /// Verovio usa unitsPerEm = 20480 (2048 * 10)
  double vexFlowDefaultNotationFontScale = 39.0;

  /// Escala de fonte para tablatura
  /// OSMD: 39
  double vexFlowDefaultTabFontScale = 39.0;

  /// Fonte padrão de notação VexFlow
  /// OSMD: "gonville", mas suporta "bravura", "petaluma"
  String defaultVexFlowNoteFont = "bravura";

  // ====================
  // SINAIS DE REPETIÇÃO
  // ====================

  /// Espessura de linha de repeat ending
  double repeatEndingLineThickness = 0.16;

  // ====================
  // MÉTODOS AUXILIARES
  // ====================

  /// Obtém distância de espaçamento para índice de duração
  /// @param index 0=breve, 1=whole, 2=half, 3=quarter, 4=eighth, etc.
  double getNoteDistanceByIndex(int index) {
    if (index < 0 || index >= noteDistances.length) {
      return noteDistances[3]; // Default: quarter note
    }
    return noteDistances[index];
  }

  /// Converte enum de duração para índice de espaçamento
  /// Útil para mapear DurationType → noteDistances[]
  static int durationTypeToIndex(String durationType) {
    switch (durationType.toLowerCase()) {
      case 'breve':
        return 0;
      case 'whole':
        return 1;
      case 'half':
        return 2;
      case 'quarter':
        return 3;
      case 'eighth':
        return 4;
      case 'sixteenth':
        return 5;
      case 'thirtysecond':
        return 6;
      case 'sixtyfourth':
        return 7;
      default:
        return 3; // Default: quarter
    }
  }

  /// Cria uma cópia com valores modificados
  /// Útil para temas ou estilos alternativos
  EngravingRules copyWith({
    double? idealStemLength,
    double? stemWidth,
    double? beamWidth,
    double? beamSlopeMaxAngle,
    List<double>? noteDistances,
    double? minNoteDistance,
    // ... adicionar outros parâmetros conforme necessário
  }) {
    final copy = EngravingRules();
    copy.idealStemLength = idealStemLength ?? this.idealStemLength;
    copy.stemWidth = stemWidth ?? this.stemWidth;
    copy.beamWidth = beamWidth ?? this.beamWidth;
    copy.beamSlopeMaxAngle = beamSlopeMaxAngle ?? this.beamSlopeMaxAngle;
    copy.noteDistances = noteDistances ?? List.from(this.noteDistances);
    copy.minNoteDistance = minNoteDistance ?? this.minNoteDistance;
    // ... copiar outros valores
    return copy;
  }

  /// Instância singleton padrão
  static final EngravingRules defaultRules = EngravingRules();
}