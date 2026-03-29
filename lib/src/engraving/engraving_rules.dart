// lib/src/engraving/engraving_rules.dart

/// Regras de Music engraving (Engraving Rules)
///
/// This class centraliza All as constantes tipográficas used
/// na Rendersção de partituras musicais.
///
/// Based on:
/// - OpenSheetMusicDisplay (EngravingRules.ts with 1220+ linhas)
/// - Verovio (vrvdef.h e constantes C++)
/// - "Behind Bars" de Elaine Gould
/// - "The Art of Music Engraving" de Ted Ross
/// - Especificação SMuFL (w3c.github.io/smufl)
/// - Metadata of the fonte Bravura
class EngravingRules {
  // ====================
  // UNIDADE BASE
  // ====================

  /// Unidade base: 1.0 = distância entre duas linhas adjacentes of the staff
  /// No SMuFL, this é chamada de "staff space"
  static const double unit = 1.0;

  // ====================
  // Stems (STEMS)
  // ====================

  /// Comprimento ideal de a stem (Verovio: 7 half-spaces = 3.5 spaces)
  /// OSMD: 3.0 units
  /// Bravura metadata: stemLength default
  double idealStemLength = 3.5;

  /// Offset Y where a stem toca a borda of the notehead
  /// OSMD: 0.2 units
  double stemNoteHeadBorderYOffset = 0.2;

  /// Width of the stem
  /// Bravura metadata: stemThickness = 0.12 staff spaces
  double stemWidth = 0.12;

  /// Comprimento mínimo permitido for stems
  /// Verovio: Encurtamento máximo de 6 third-units = 2.0 spaces
  double stemMinLength = 2.5;

  /// Comprimento máximo permitido for stems
  double stemMaxLength = 4.5;

  /// Margem of the stem
  double stemMargin = 0.2;

  /// Height mínima permitida entre notehead e linha de beam
  double stemMinAllowedDistanceBetweenNoteHeadAndBeamLine = 1.0;

  // ====================
  // Beams (BEAMS)
  // ====================

  /// Espessura de um beam individual
  /// Bravura metadata: beamThickness = 0.5 staff spaces
  /// OSMD: 0.5 units
  double beamWidth = 0.5;

  /// Space entre beams múltiplos
  /// Bravura metadata: beamSpacing = 0.25 staff spaces
  /// OSMD: 0.33 units (unit / 3.0)
  /// Verovio: beamThickness * 1.5 = 0.75 na prática
  double beamSpaceWidth = 0.25;

  /// Ângulo máximo de inclinação de beams in graus
  /// OSMD: 10.0°
  /// Verovio: Mais adaptativo, mas limitado
  /// Behind Bars: Beams devem ser sutis, not excessivos
  double beamSlopeMaxAngle = 10.0;

  /// Comprimento de beam parcial (broken beam)
  /// OSMD: 1.25 units
  double beamForwardLength = 1.25;

  /// Usesr beams planos (flat beams) in vez de inclinados
  /// Útil for estilos alternativos
  bool flatBeams = false;

  /// Offset de beams planos
  double flatBeamOffset = 20.0;

  /// Offset por beam in beams planos
  double flatBeamOffsetPerBeam = 10.0;

  // ====================
  // Note spacing
  // ====================

  /// Distâncias de spacing por duração
  /// Index: 0=breve, 1=whole, 2=half, 3=quarter, 4=eighth, 5=16th, 6=32nd, 7=64th
  /// Valores in staff spaces (units)
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

  /// Fatores de escala for duração (exponencial: 1, 2, 4, 8, 16, ...)
  /// used in cálculos de spacing óptico
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

  /// Distância mínima entre notes
  /// OSMD: 2.0 units
  /// Verovio: Configurável
  double minNoteDistance = 2.0;

  /// Margem for notes deslocadas (displaced notes in chords)
  double displacedNoteMargin = 0.1;

  /// Multiplicador de spacing for VexFlow
  /// OSMD: 0.85
  double voiceSpacingMultiplierVexflow = 0.85;

  /// Value Addsdo ao spacing VexFlow
  /// OSMD: 3.0
  double voiceSpacingAddendVexflow = 3.0;

  /// Fator softmax for suavizar spacing (evitar transições abruptas)
  /// OSMD: 15
  double softmaxFactorVexFlow = 15.0;

  // ====================
  // Ties (TIES)
  // ====================

  /// Height mínima de tie
  /// Behind Bars: Ties devem ser discretos, height mínima ~0.1 SS
  double tieHeightMinimum = 0.1;

  /// Height máxima de tie
  /// Behind Bars: Mesmo for ties longos, máximo 0.4 SS
  double tieHeightMaximum = 0.4;

  /// Constante K for interpolação linear de height de tie: y = k*x + d
  /// Reduzido drasticamente for ties mais achatados (Behind Bars)
  double tieHeightInterpolationK = 0.008;

  /// Constante D for interpolação linear de height de tie: y = k*x + d
  /// Height base muito pequena for ties discretos
  double tieHeightInterpolationD = 0.05;

  /// Calculatestes height de tie based na width
  /// Fórmula: height = k * width + d, limitado por min/max
  double calculateTieHeight(double width) {
    final height = tieHeightInterpolationK * width + tieHeightInterpolationD;
    return height.clamp(tieHeightMinimum, tieHeightMaximum);
  }

  // ====================
  // Slurs (SLURS)
  // ====================

  /// Offset Y of the notehead for início/fim de slur
  /// OSMD: 0.5 staff spaces
  double slurNoteHeadYOffset = 0.5;

  /// Offset X of the stem for slurs that começam/terminam in stems
  /// OSMD: 0.3 staff spaces
  double slurStemXOffset = 0.3;

  /// Ângulo máximo de inclinação de slur
  /// OSMD: 15.0°
  double slurSlopeMaxAngle = 15.0;

  /// Ângulo mínimo das tangentes of the curva de slur
  /// OSMD: 30.0°
  /// used no algoritmo de Bézier avançado
  double slurTangentMinAngle = 30.0;

  /// Ângulo máximo das tangentes of the curva de slur
  /// OSMD: 80.0°
  double slurTangentMaxAngle = 80.0;

  /// Fator de height of the curva de slur
  /// OSMD: 1.0 (100%)
  double slurHeightFactor = 1.0;

  /// Number de passos for discretização de curvas Bézier
  /// OSMD: 1000
  /// used for pré-Calculatestesr curvas
  int bezierCurveStepSize = 1000;

  /// Usesr posicionamento de slurs of the XML (se disponível)
  bool slurPlacementFromXML = true;

  /// Posicionar slurs nas stems in vez de nas cabeças
  bool slurPlacementAtStems = false;

  /// Usesr skyline/bottomline for posicionamento de slurs
  bool slurPlacementUseSkyBottomLine = false;

  /// Margem mínima de clearance entre slur e notes intermediárias
  /// Garante that o slur not colida with notes no caminho
  /// OSMD: 0.5 staff spaces
  double slurClearanceMinimum = 0.5;

  // ====================
  // Accidentals (ACCIDENTALS)
  // ====================

  /// Distância entre símbolos de armadura de clef
  /// OSMD: 0.2 staff spaces
  double betweenKeySymbolsDistance = 0.2;

  /// Margem direita após armadura de clef
  /// OSMD: 0.75 staff spaces
  double keyRightMargin = 0.75;

  /// Distância entre natural e símbolo ao cancelar armadura
  /// OSMD: 0.4 staff spaces
  double distanceBetweenNaturalAndSymbolWhenCancelling = 0.4;

  /// Distância de accidental à notehead
  /// Behind Bars: 0.16-0.20 staff spaces
  /// SMuFL Positioning Engine: 0.16 staff spaces
  double accidentalToNoteheadDistance = 0.2;

  /// Margem mínima for evitar colisões de accidentals
  double accidentalMinimumClearance = 0.08;

  // ====================
  // Articulations
  // ====================

  /// Articulation acima of the note when stem está for cima
  /// OSMD: false (articulation fica of the lado oposto of the stem)
  /// Behind Bars: Articulations Generateslmente opostas às stems
  bool articulationAboveNoteForStemUp = false;

  /// Padding for soft accent wedge
  double softAccentWedgePadding = 0.4;

  /// Fator de size for soft accent
  double softAccentSizeFactor = 0.6;

  /// Fator de escala for staccato
  /// OSMD: 0.8 (80% of the size)
  double staccatoScalingFactor = 0.8;

  /// Distância entre pontos (ex: staccatissimo duplo)
  double betweenDotsDistance = 0.8;

  /// Distância de articulation à note
  /// SMuFL Positioning Engine: 0.5 staff spaces
  double articulationToNoteDistance = 0.5;

  // ====================
  // Ornaments
  // ====================

  /// Fator de escala for accidentals in ornaments (ex: trill with sharp)
  /// OSMD: 0.65 (65% of the size)
  double ornamentAccidentalScalingFactor = 0.65;

  /// Distância de ornament à note
  /// SMuFL Positioning Engine: 0.75 staff spaces
  double ornamentToNoteDistance = 0.75;

  // ====================
  // LINHAS SUPLEMENTARES (LEDGER LINES)
  // ====================

  /// Extensão das linhas suplementares além of the note
  /// Bravura metadata: legerLineExtension = 0.4 staff spaces
  double legerLineExtension = 0.4;

  /// Espessura das linhas suplementares
  /// Bravura metadata: legerLineThickness = 0.16 staff spaces
  double legerLineWidth = 0.16;

  // ====================
  // ESPESSURAS DE LINHA
  // ====================

  /// Espessura das linhas of the staff
  /// Bravura metadata: staffLineThickness = 0.13 staff spaces
  /// OSMD: 0.10 (mais fino)
  double staffLineWidth = 0.13;

  /// Espessura das linhas suplementares
  /// OSMD: 1 (pixel absoluto, not staff space)
  /// Aqui: 0.16 staff spaces (consistente with Bravura)
  double ledgerLineWidth = 0.16;

  /// Espessura de linha de wedge (crescendo/diminuendo)
  double wedgeLineWidth = 0.12;

  /// Espessura de linha de tuplet bracket
  double tupletLineWidth = 0.12;

  /// Espessura de linha fina de system (thin barline)
  /// Bravura metadata: thinBarlineThickness = 0.16 staff spaces
  double systemThinLineWidth = 0.16;

  /// Espessura de linha grossa de system (thick barline)
  /// Bravura metadata: thickBarlineThickness = 0.5 staff spaces
  double systemBoldLineWidth = 0.5;

  // ====================
  // Barlines (BARLINES)
  // ====================

  /// Espessura de barline normal
  double barlineWidth = 0.16;

  /// Espessura de barline grossa
  double thickBarlineWidth = 0.5;

  /// Separação entre barlines duplas
  /// Bravura metadata: barlineSeparation = 0.4 staff spaces
  double barlineSeparation = 0.4;

  // ====================
  // Dynamics
  // ====================

  /// Distância máxima for agrupar expressões dynamics for alinhamento
  /// OSMD: 4.0 staff spaces
  double dynamicExpressionMaxDistance = 4.0;

  // ====================
  // Tuplets (TUPLETS)
  // ====================

  /// Height of the bracket de tuplet acima/abaixo das notes
  /// SMuFL Positioning Engine: 1.0 staff spaces
  double tupletBracketHeight = 1.0;

  /// Distância of the number of the tuplet ao bracket
  /// SMuFL Positioning Engine: 0.5 staff spaces
  double tupletNumberDistance = 0.5;

  // ====================
  // GRACE NOTES
  // ====================

  /// Escala de grace notes in relação a notes normais
  /// SMuFL Positioning Engine: 0.6 (60%)
  /// Verovio: ~0.66 (graceFactor)
  double graceNoteScale = 0.6;

  /// Comprimento de stem de grace note
  /// SMuFL Positioning Engine: 2.5 staff spaces
  double graceNoteStemLength = 2.5;

  /// Offset X de grace note antes of the note principal
  /// SMuFL Positioning Engine: -1.5 staff spaces
  double graceNoteXOffset = -1.5;

  /// Grace notes devem ter slash através of the stem
  bool graceNoteHasSlash = true;

  /// Ângulo of the slash in grace notes
  double graceNoteSlashAngle = 45.0; // graus

  // ====================
  // Spacing DE System
  // ====================

  /// Distância entre staffs
  /// OSMD: 7.0 staff spaces
  double staffDistance = 7.0;

  /// Distância added entre staffs
  /// OSMD: 5.0 staff spaces
  double betweenStaffDistance = 5.0;

  /// Distância mínima entre staff lines
  /// OSMD: 4.0 staff spaces
  double minimumStaffLineDistance = 4.0;

  /// Distância mínima skyline/bottomline entre staffs
  /// OSMD: 1.0 staff spaces
  double minSkyBottomDistBetweenStaves = 1.0;

  /// Distância mínima skyline/bottomline entre systems
  /// OSMD: 5.0 staff spaces
  double minSkyBottomDistBetweenSystems = 5.0;

  /// Margem of the system (esquerda/direita)
  /// Layout Engine: 2.0 staff spaces
  double systemMargin = 2.0;

  // ====================
  // Spacing DE Measure
  // ====================

  /// Width mínima de measure
  /// Layout Engine: 4.0 staff spaces
  double measureMinWidth = 4.0;

  /// Spacing mínimo de note
  /// Layout Engine: 2.0 staff spaces (corrigido de 1.5)
  double noteMinSpacing = 2.0;

  /// Padding ao final of the measure
  /// Layout Engine: 1.0 staff spaces
  double measureEndPadding = 1.0;

  // ====================
  // ESCALA DE FONTES
  // ====================

  /// Escala default de fonte de noteção VexFlow
  /// OSMD: 39
  /// Verovio Uses unitsPerEm = 20480 (2048 * 10)
  double vexFlowDefaultNotationFontScale = 39.0;

  /// Escala de fonte for tablatura
  /// OSMD: 39
  double vexFlowDefaultTabFontScale = 39.0;

  /// Fonte default de noteção VexFlow
  /// OSMD: "gonville", mas suporta "bravura", "petaluma"
  String defaultVexFlowNoteFont = "bravura";

  // ====================
  // SINAIS DE REPETIÇÃO
  // ====================

  /// Espessura de linha de repeat ending
  double repeatEndingLineThickness = 0.16;

  // ====================
  // MethodS AUXILIARES
  // ====================

  /// Gets distância de spacing for index de duração
  /// @param index 0=breve, 1=whole, 2=half, 3=quarter, 4=eighth, etc.
  double getNoteDistanceByIndex(int index) {
    if (index < 0 || index >= noteDistances.length) {
      return noteDistances[3]; // Default: quarter note
    }
    return noteDistances[index];
  }

  /// Converts enum de duração for index de spacing
  /// Útil for Map DurationType → noteDistances[]
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

  /// Creates a cópia with valores modificados
  /// Útil for temas ou estilos alternativos
  EngravingRules copyWith({
    double? idealStemLength,
    double? stemWidth,
    double? beamWidth,
    double? beamSlopeMaxAngle,
    List<double>? noteDistances,
    double? minNoteDistance,
    // ... add outros parameters according to necessário
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

  /// Instance singleton default
  static final EngravingRules defaultRules = EngravingRules();
}