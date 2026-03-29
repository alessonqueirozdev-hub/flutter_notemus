// lib/src/engraving/engraving_rules.dart

/// Regras de Music engraving (Engraving Rules)
///
/// This class centraliza All as constantes tipográficas used
/// na Rendering de partituras musicais.
///
/// Based on:
/// - OpenSheetMusicDisplay (EngravingRules.ts with 1220+ lines)
/// - Verovio (vrvdef.h and constantes C++)
/// - "Behind Bars" de Elaine Gould
/// - "The Art of Music Engraving" de Ted Ross
/// - Especificação SMuFL (w3c.github.io/smufl)
/// - Metadata of the fonte Bravura
class EngravingRules {
  // ====================
  // UNIDADE Base
  // ====================

  /// Unidade base: 1.0 = distance between duas lines adjacentes of the staff
  /// No SMuFL, this is chamada de "staff space"
  static const double unit = 1.0;

  // ====================
  // Stems (STEMS)
  // ====================

  /// Length ideal de a stem (Verovio: 7 half-spaces = 3.5 spaces)
  /// OSMD: 3.0 units
  /// Bravura metadata: stemLength default
  double idealStemLength = 3.5;

  /// Offset Y where a stem toca a borda of the notehead
  /// OSMD: 0.2 units
  double stemNoteHeadBorderYOffset = 0.2;

  /// Width of the stem
  /// Bravura metadata: stemThickness = 0.12 staff spaces
  double stemWidth = 0.12;

  /// Length mínimo permitido for stems
  /// Verovio: Encurtamento máximo de 6 third-units = 2.0 spaces
  double stemMinLength = 2.5;

  /// Length máximo permitido for stems
  double stemMaxLength = 4.5;

  /// Margin of the stem
  double stemMargin = 0.2;

  /// Height mínima permitida between notehead and line de beam
  double stemMinAllowedDistanceBetweenNoteHeadAndBeamLine = 1.0;

  // ====================
  // Beams (BEAMS)
  // ====================

  /// Thickness de a beam individual
  /// Bravura metadata: beamThickness = 0.5 staff spaces
  /// OSMD: 0.5 units
  double beamWidth = 0.5;

  /// Space between beams múltiplos
  /// Bravura metadata: beamSpacing = 0.25 staff spaces
  /// OSMD: 0.33 units (unit / 3.0)
  /// Verovio: beamThickness * 1.5 = 0.75 na prática
  double beamSpaceWidth = 0.25;

  /// Angle máximo de slope de beams in graus
  /// OSMD: 10.0°
  /// Verovio: More adaptativo, mas limitado
  /// Behind Bars: Beams must be sutis, not excessivos
  double beamSlopeMaxAngle = 10.0;

  /// Length de beam parcial (broken beam)
  /// OSMD: 1.25 units
  double beamForwardLength = 1.25;

  /// Use beams planos (flat beams) in vez de inclinados
  /// Útil for styles alternativos
  bool flatBeams = false;

  /// Offset de beams planos
  double flatBeamOffset = 20.0;

  /// Offset by beam in beams planos
  double flatBeamOffsetPerBeam = 10.0;

  // ====================
  // Note spacing
  // ====================

  /// Distâncias de spacing by duração
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
  /// used in calculations de spacing óptico
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

  /// Distance mínima between notes
  /// OSMD: 2.0 units
  /// Verovio: Configurável
  double minNoteDistance = 2.0;

  /// Margin for notes deslocadas (displaced notes in chords)
  double displacedNoteMargin = 0.1;

  /// Multiplicador de spacing for VexFlow
  /// OSMD: 0.85
  double voiceSpacingMultiplierVexflow = 0.85;

  /// Value Addsdo to the spacing VexFlow
  /// OSMD: 3.0
  double voiceSpacingAddendVexflow = 3.0;

  /// Fator softmax for suavizar spacing (avoid transições abruptas)
  /// OSMD: 15
  double softmaxFactorVexFlow = 15.0;

  // ====================
  // Ties (TIES)
  // ====================

  /// Height mínima de tie
  /// Behind Bars: Ties must be discretos, height mínima ~0.1 SS
  double tieHeightMinimum = 0.1;

  /// Height máxima de tie
  /// Behind Bars: Same for ties longos, máximo 0.4 SS
  double tieHeightMaximum = 0.4;

  /// Constante K for interpolação linear de height de tie: y = k*x + d
  /// Reduzido drasticamente for ties more achatados (Behind Bars)
  double tieHeightInterpolationK = 0.008;

  /// Constante D for interpolação linear de height de tie: y = k*x + d
  /// Height base very small for ties discretos
  double tieHeightInterpolationD = 0.05;

  /// Calculates height de tie based na width
  /// Fórmula: height = k * width + d, limitado by min/max
  double calculateTieHeight(double width) {
    final height = tieHeightInterpolationK * width + tieHeightInterpolationD;
    return height.clamp(tieHeightMinimum, tieHeightMaximum);
  }

  // ====================
  // Slurs (SLURS)
  // ====================

  /// Offset Y of the notehead for start/end de slur
  /// OSMD: 0.5 staff spaces
  double slurNoteHeadYOffset = 0.5;

  /// Offset X of the stem for slurs that começam/end in stems
  /// OSMD: 0.3 staff spaces
  double slurStemXOffset = 0.3;

  /// Angle máximo de slope de slur
  /// OSMD: 15.0°
  double slurSlopeMaxAngle = 15.0;

  /// Angle mínimo das tangentes of the curva de slur
  /// OSMD: 30.0°
  /// used no algoritmo de Bézier avançado
  double slurTangentMinAngle = 30.0;

  /// Angle máximo das tangentes of the curva de slur
  /// OSMD: 80.0°
  double slurTangentMaxAngle = 80.0;

  /// Fator de height of the curva de slur
  /// OSMD: 1.0 (100%)
  double slurHeightFactor = 1.0;

  /// Number de passos for discretização de curvas Bézier
  /// OSMD: 1000
  /// used for pré-Calculate curvas
  int bezierCurveStepSize = 1000;

  /// Use posicionamento de slurs of the XML (if disponível)
  bool slurPlacementFromXML = true;

  /// Position slurs nas stems in vez de nas cabeças
  bool slurPlacementAtStems = false;

  /// Use skyline/bottomline for posicionamento de slurs
  bool slurPlacementUseSkyBottomLine = false;

  /// Margin mínima de clearance between slur and notes intermediárias
  /// Ensures that o slur not colida with notes no caminho
  /// OSMD: 0.5 staff spaces
  double slurClearanceMinimum = 0.5;

  // ====================
  // Accidentals (ACCIDENTALS)
  // ====================

  /// Distance between symbols de armadura de clef
  /// OSMD: 0.2 staff spaces
  double betweenKeySymbolsDistance = 0.2;

  /// Margin right after armadura de clef
  /// OSMD: 0.75 staff spaces
  double keyRightMargin = 0.75;

  /// Distance between natural and symbol to the cancelar armadura
  /// OSMD: 0.4 staff spaces
  double distanceBetweenNaturalAndSymbolWhenCancelling = 0.4;

  /// Distance de accidental to the notehead
  /// Behind Bars: 0.16-0.20 staff spaces
  /// SMuFL Positioning Engine: 0.16 staff spaces
  double accidentalToNoteheadDistance = 0.2;

  /// Margin mínima for avoid colisões de accidentals
  double accidentalMinimumClearance = 0.08;

  // ====================
  // Articulations
  // ====================

  /// Articulation above the note when stem está for top
  /// OSMD: false (articulation is of the lado oposto of the stem)
  /// Behind Bars: Articulations Generateslmente opostas às stems
  bool articulationAboveNoteForStemUp = false;

  /// Padding for soft accent wedge
  double softAccentWedgePadding = 0.4;

  /// Fator de size for soft accent
  double softAccentSizeFactor = 0.6;

  /// Fator de escala for staccato
  /// OSMD: 0.8 (80% of the size)
  double staccatoScalingFactor = 0.8;

  /// Distance between points (ex: staccatissimo duplo)
  double betweenDotsDistance = 0.8;

  /// Distance de articulation to the note
  /// SMuFL Positioning Engine: 0.5 staff spaces
  double articulationToNoteDistance = 0.5;

  // ====================
  // Ornaments
  // ====================

  /// Fator de escala for accidentals in ornaments (ex: trill with sharp)
  /// OSMD: 0.65 (65% of the size)
  double ornamentAccidentalScalingFactor = 0.65;

  /// Distance de ornament to the note
  /// SMuFL Positioning Engine: 0.75 staff spaces
  double ornamentToNoteDistance = 0.75;

  // ====================
  // Ledger lines (LEDGER LINES)
  // ====================

  /// Extension das ledger lines além of the note
  /// Bravura metadata: legerLineExtension = 0.4 staff spaces
  double legerLineExtension = 0.4;

  /// Thickness das ledger lines
  /// Bravura metadata: legerLineThickness = 0.16 staff spaces
  double legerLineWidth = 0.16;

  // ====================
  // ESPESSURAS DE Line
  // ====================

  /// Thickness das staff lines
  /// Bravura metadata: staffLineThickness = 0.13 staff spaces
  /// OSMD: 0.10 (more fino)
  double staffLineWidth = 0.13;

  /// Thickness das ledger lines
  /// OSMD: 1 (pixel absoluto, not staff space)
  /// Aqui: 0.16 staff spaces (consistente with Bravura)
  double ledgerLineWidth = 0.16;

  /// Thickness de line de wedge (crescendo/diminuendo)
  double wedgeLineWidth = 0.12;

  /// Thickness de line de tuplet bracket
  double tupletLineWidth = 0.12;

  /// Thickness de line fina de system (thin barline)
  /// Bravura metadata: thinBarlineThickness = 0.16 staff spaces
  double systemThinLineWidth = 0.16;

  /// Thickness de line grossa de system (thick barline)
  /// Bravura metadata: thickBarlineThickness = 0.5 staff spaces
  double systemBoldLineWidth = 0.5;

  // ====================
  // Barlines (BARLINES)
  // ====================

  /// Thickness de barline normal
  double barlineWidth = 0.16;

  /// Thickness de barline grossa
  double thickBarlineWidth = 0.5;

  /// Separação between barlines duplas
  /// Bravura metadata: barlineSeparation = 0.4 staff spaces
  double barlineSeparation = 0.4;

  // ====================
  // Dynamics
  // ====================

  /// Distance máxima for agrupar expressões dynamics for alinhamento
  /// OSMD: 4.0 staff spaces
  double dynamicExpressionMaxDistance = 4.0;

  // ====================
  // Tuplets (TUPLETS)
  // ====================

  /// Height of the bracket de tuplet above/below das notes
  /// SMuFL Positioning Engine: 1.0 staff spaces
  double tupletBracketHeight = 1.0;

  /// Distance of the number of the tuplet to the bracket
  /// SMuFL Positioning Engine: 0.5 staff spaces
  double tupletNumberDistance = 0.5;

  // ====================
  // GRACE NOTES
  // ====================

  /// Escala de grace notes in relação a notes normais
  /// SMuFL Positioning Engine: 0.6 (60%)
  /// Verovio: ~0.66 (graceFactor)
  double graceNoteScale = 0.6;

  /// Length de stem de grace note
  /// SMuFL Positioning Engine: 2.5 staff spaces
  double graceNoteStemLength = 2.5;

  /// Offset X de grace note before of the note principal
  /// SMuFL Positioning Engine: -1.5 staff spaces
  double graceNoteXOffset = -1.5;

  /// Grace notes must ter slash through of the stem
  bool graceNoteHasSlash = true;

  /// Angle of the slash in grace notes
  double graceNoteSlashAngle = 45.0; // graus

  // ====================
  // Spacing DE System
  // ====================

  /// Distance between staffs
  /// OSMD: 7.0 staff spaces
  double staffDistance = 7.0;

  /// Distance added between staffs
  /// OSMD: 5.0 staff spaces
  double betweenStaffDistance = 5.0;

  /// Distance mínima between staff lines
  /// OSMD: 4.0 staff spaces
  double minimumStaffLineDistance = 4.0;

  /// Distance mínima skyline/bottomline between staffs
  /// OSMD: 1.0 staff spaces
  double minSkyBottomDistBetweenStaves = 1.0;

  /// Distance mínima skyline/bottomline between systems
  /// OSMD: 5.0 staff spaces
  double minSkyBottomDistBetweenSystems = 5.0;

  /// Margin of the system (left/right)
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

  /// Padding to the final of the measure
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

  /// Thickness de line de repeat ending
  double repeatEndingLineThickness = 0.16;

  // ====================
  // MethodS AUXILIARES
  // ====================

  /// Gets distance de spacing for index de duração
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
  /// Útil for temas or styles alternativos
  EngravingRules copyWith({
    double? idealStemLength,
    double? stemWidth,
    double? beamWidth,
    double? beamSlopeMaxAngle,
    List<double>? noteDistances,
    double? minNoteDistance,
    // ... add other parameters according to required
  }) {
    final copy = EngravingRules();
    copy.idealStemLength = idealStemLength ?? this.idealStemLength;
    copy.stemWidth = stemWidth ?? this.stemWidth;
    copy.beamWidth = beamWidth ?? this.beamWidth;
    copy.beamSlopeMaxAngle = beamSlopeMaxAngle ?? this.beamSlopeMaxAngle;
    copy.noteDistances = noteDistances ?? List.from(this.noteDistances);
    copy.minNoteDistance = minNoteDistance ?? this.minNoteDistance;
    // ... copiar other valores
    return copy;
  }

  /// Instance singleton default
  static final EngravingRules defaultRules = EngravingRules();
}