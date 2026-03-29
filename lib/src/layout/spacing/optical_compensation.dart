/// System de compensação óptica for spacing musical
/// 
/// Applies visual adjustments based on context to improve
/// a aparência percebida of the spacing, following princípios
/// de Sibelius, LilyPond and Behind Bars.
library;

/// Tipos de elementos musicais for compensação
enum SymbolType {
  note,
  rest,
  chord,
  clef,
  keySignature,
  timeSignature,
  barline,
  accidental,
  dynamic,
  articulation,
  ornament,
}

/// Context for calculation de compensação óptica
class OpticalContext {
  final SymbolType type;
  final bool? stemUp; // null se não aplicável
  final double? duration; // null se não aplicável
  final bool hasAccidental;
  final bool isDotted;
  final int? beamCount; // null se não em beam

  const OpticalContext({
    required this.type,
    this.stemUp,
    this.duration,
    this.hasAccidental = false,
    this.isDotted = false,
    this.beamCount,
  });

  /// Createsr context for note
  factory OpticalContext.note({
    required bool stemUp,
    required double duration,
    bool hasAccidental = false,
    bool isDotted = false,
    int? beamCount,
  }) {
    return OpticalContext(
      type: SymbolType.note,
      stemUp: stemUp,
      duration: duration,
      hasAccidental: hasAccidental,
      isDotted: isDotted,
      beamCount: beamCount,
    );
  }

  /// Createsr context for paUses
  factory OpticalContext.rest({required double duration}) {
    return OpticalContext(
      type: SymbolType.rest,
      duration: duration,
    );
  }

  /// Createsr context for chord
  factory OpticalContext.chord({
    required bool stemUp,
    required double duration,
    bool hasAccidental = false,
  }) {
    return OpticalContext(
      type: SymbolType.chord,
      stemUp: stemUp,
      duration: duration,
      hasAccidental: hasAccidental,
    );
  }
}

/// Calculatora de compensação óptica
/// 
/// Implementa as regras de ajuste visual baseadas in:
/// - Direction de stems
/// - Transições de duração
/// - Proximidade de accidentals
/// - Densidade local
class OpticalCompensator {
  /// Space base (staff space in pixels)
  final double staffSpace;

  /// Ativar compensação
  final bool enabled;

  /// Fator de intensidade (0.0 - 1.0)
  /// 
  /// 0.0 = sem compensação
  /// 1.0 = compensação completa
  final double intensity;

  const OpticalCompensator({
    required this.staffSpace,
    this.enabled = true,
    this.intensity = 1.0,
  });

  /// Calculates compensação total between dois symbols
  /// 
  /// **Returns:** Ajuste in pixels (positivo = afastar, negativo = aproximar)
  double calculateCompensation(
    OpticalContext previous,
    OpticalContext current, {
    double localDensity = 0.5,
  }) {
    if (!enabled) return 0.0;

    double totalCompensation = 0.0;

    // Regra 1: Stems alternadas
    totalCompensation += _compensateForAlternatingStem(previous, current);

    // Regra 2: PaUses seguida de note with stem up
    totalCompensation += _compensateForRestBeforeNote(previous, current);

    // Regra 3: Transição de duração
    totalCompensation += _compensateForDurationTransition(previous, current);

    // Regra 4: Accidentals
    totalCompensation += _compensateForAccidental(current, localDensity);

    // Regra 5: Points de aumento
    totalCompensation += _compensateForDots(previous, current);

    // Regra 6: Beams (barras de ligação)
    totalCompensation += _compensateForBeams(previous, current);

    return totalCompensation * intensity;
  }

  /// Regra 1: Compensação for stems alternadas
  /// 
  /// Medir between stems (not cabeças) for parecer uniforme
  double _compensateForAlternatingStem(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    if (prev.stemUp == null || curr.stemUp == null) return 0.0;

    if (prev.stemUp! && !curr.stemUp!) {
      // Stem up → Stem down: AFASTAR
      return 0.15 * staffSpace;
    } else if (!prev.stemUp! && curr.stemUp!) {
      // Stem down → Stem up: APROXIMAR
      return -0.1 * staffSpace;
    }

    return 0.0;
  }

  /// Regra 2: PaUses seguida de note with stem up
  double _compensateForRestBeforeNote(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    if (prev.type == SymbolType.rest &&
        curr.type == SymbolType.note &&
        curr.stemUp == true) {
      return 0.08 * staffSpace;
    }

    return 0.0;
  }

  /// Regra 3: Transição de duração
  /// 
  /// Note curta after note longa: leve aproximação
  double _compensateForDurationTransition(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    if (prev.duration == null || curr.duration == null) return 0.0;

    if (curr.duration! < prev.duration!) {
      return -0.05 * staffSpace;
    }

    return 0.0;
  }

  /// Regra 4: Compensação for accidentals
  /// 
  /// Ajusta space based on densidade local
  double _compensateForAccidental(
    OpticalContext curr,
    double density,
  ) {
    if (!curr.hasAccidental) return 0.0;

    // Interpolar between spacing ideal (0.5 SS) and mínimo (0.25 SS)
    final double idealSpace = 0.5 * staffSpace;
    final double minSpace = 0.25 * staffSpace;

    return _lerp(idealSpace, minSpace, density);
  }

  /// Regra 5: Compensação for points de aumento
  /// 
  /// Notes pontuadas need de space extra to the right
  double _compensateForDots(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    double compensation = 0.0;

    // If o previous is pontuado, add space
    if (prev.isDotted) {
      compensation += 0.12 * staffSpace;
    }

    // If o current is pontuado, Check if há space suficiente
    if (curr.isDotted) {
      compensation += 0.05 * staffSpace;
    }

    return compensation;
  }

  /// Regra 6: Compensação for beams (barras de ligação)
  /// 
  /// Notes with beams can be aproximadas
  double _compensateForBeams(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    // If ambas are in beams, can be ligeiramente more próximas
    if (prev.beamCount != null &&
        curr.beamCount != null &&
        prev.beamCount! > 0 &&
        curr.beamCount! > 0) {
      return -0.03 * staffSpace;
    }

    return 0.0;
  }

  /// Interpolação linear
  double _lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }

  /// Calculates densidade local baseada in number de elementos
  /// 
  /// **Parameters:**
  /// - `elementCount`: Number de elementos in a janela
  /// - `windowWidth`: Width of the janela in pixels
  /// 
  /// **Returns:** Densidade normalizada (0.0 - 1.0)
  double calculateLocalDensity(int elementCount, double windowWidth) {
    if (windowWidth <= 0) return 0.5;

    // Densidade = elementos by staff space
    final double density = elementCount / (windowWidth / staffSpace);

    // Normalizar (assumindo 1-5 elementos by SS as range típico)
    return ((density - 1.0) / 4.0).clamp(0.0, 1.0);
  }

  /// Calculates compensação for measures compostos
  /// 
  /// Adds space between pulsos ternários (6/8, 9/8, 12/8)
  double compensateForCompoundMeterPulse({
    required bool isStartOfPulse,
    required double pulseSpacing,
  }) {
    if (!enabled || !isStartOfPulse) return 0.0;

    return pulseSpacing * staffSpace * intensity;
  }

  /// Calculates compensação for barlines
  /// 
  /// Returns [spaceBefore, spaceAfter] in pixels
  List<double> compensateForBarline({
    required BarlineType type,
  }) {
    if (!enabled) return [0.0, 0.0];

    double before = 0.0;
    double after = 0.0;

    switch (type) {
      case BarlineType.single:
        before = 0.75 * staffSpace;
        after = 0.5 * staffSpace;
        break;

      case BarlineType.doubleBar:
        before = 1.0 * staffSpace;
        after = 0.75 * staffSpace;
        break;

      case BarlineType.repeat:
        before = 1.25 * staffSpace;
        after = 1.0 * staffSpace;
        break;

      case BarlineType.finalBar:
        before = 1.0 * staffSpace;
        after = 1.5 * staffSpace;
        break;
    }

    return [before * intensity, after * intensity];
  }

  /// Calculates compensação for mudança de clef
  /// 
  /// Returns [spaceBefore, spaceAfter] in pixels
  List<double> compensateForClefChange({
    required bool isAtBeginning,
  }) {
    if (!enabled) return [0.0, 0.0];

    if (isAtBeginning) {
      return [0.0, 0.0]; // Sem espaço extra no início
    }

    // Mudança no meio of the measure
    return [
      0.5 * staffSpace * intensity,
      0.75 * staffSpace * intensity,
    ];
  }
}

/// Tipos de barline for compensação
enum BarlineType {
  single,
  doubleBar,
  repeat,
  finalBar,
}
