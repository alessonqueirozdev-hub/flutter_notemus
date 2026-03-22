/// Sistema de compensação óptica para espaçamento musical
/// 
/// Aplica ajustes visuais baseados em contexto para melhorar
/// a aparência percebida do espaçamento, seguindo princípios
/// de Sibelius, LilyPond e Behind Bars.
library;

/// Tipos de elementos musicais para compensação
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

/// Contexto para cálculo de compensação óptica
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

  /// Criar contexto para nota
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

  /// Criar contexto para pausa
  factory OpticalContext.rest({required double duration}) {
    return OpticalContext(
      type: SymbolType.rest,
      duration: duration,
    );
  }

  /// Criar contexto para acorde
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

/// Calculadora de compensação óptica
/// 
/// Implementa as regras de ajuste visual baseadas em:
/// - Direção de hastes
/// - Transições de duração
/// - Proximidade de acidentes
/// - Densidade local
class OpticalCompensator {
  /// Espaço base (staff space em pixels)
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

  /// Calcula compensação total entre dois símbolos
  /// 
  /// **Retorna:** Ajuste em pixels (positivo = afastar, negativo = aproximar)
  double calculateCompensation(
    OpticalContext previous,
    OpticalContext current, {
    double localDensity = 0.5,
  }) {
    if (!enabled) return 0.0;

    double totalCompensation = 0.0;

    // Regra 1: Hastes alternadas
    totalCompensation += _compensateForAlternatingStem(previous, current);

    // Regra 2: Pausa seguida de nota com haste para cima
    totalCompensation += _compensateForRestBeforeNote(previous, current);

    // Regra 3: Transição de duração
    totalCompensation += _compensateForDurationTransition(previous, current);

    // Regra 4: Acidentes
    totalCompensation += _compensateForAccidental(current, localDensity);

    // Regra 5: Pontos de aumento
    totalCompensation += _compensateForDots(previous, current);

    // Regra 6: Beams (barras de ligação)
    totalCompensation += _compensateForBeams(previous, current);

    return totalCompensation * intensity;
  }

  /// Regra 1: Compensação para hastes alternadas
  /// 
  /// Medir entre hastes (não cabeças) para parecer uniforme
  double _compensateForAlternatingStem(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    if (prev.stemUp == null || curr.stemUp == null) return 0.0;

    if (prev.stemUp! && !curr.stemUp!) {
      // Haste para cima → Haste para baixo: AFASTAR
      return 0.15 * staffSpace;
    } else if (!prev.stemUp! && curr.stemUp!) {
      // Haste para baixo → Haste para cima: APROXIMAR
      return -0.1 * staffSpace;
    }

    return 0.0;
  }

  /// Regra 2: Pausa seguida de nota com haste para cima
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
  /// Nota curta após nota longa: leve aproximação
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

  /// Regra 4: Compensação para acidentes
  /// 
  /// Ajusta espaço baseado em densidade local
  double _compensateForAccidental(
    OpticalContext curr,
    double density,
  ) {
    if (!curr.hasAccidental) return 0.0;

    // Interpolar entre espaçamento ideal (0.5 SS) e mínimo (0.25 SS)
    final double idealSpace = 0.5 * staffSpace;
    final double minSpace = 0.25 * staffSpace;

    return _lerp(idealSpace, minSpace, density);
  }

  /// Regra 5: Compensação para pontos de aumento
  /// 
  /// Notas pontuadas precisam de espaço extra à direita
  double _compensateForDots(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    double compensation = 0.0;

    // Se o anterior é pontuado, adicionar espaço
    if (prev.isDotted) {
      compensation += 0.12 * staffSpace;
    }

    // Se o atual é pontuado, verificar se há espaço suficiente
    if (curr.isDotted) {
      compensation += 0.05 * staffSpace;
    }

    return compensation;
  }

  /// Regra 6: Compensação para beams (barras de ligação)
  /// 
  /// Notas com beams podem ser aproximadas
  double _compensateForBeams(
    OpticalContext prev,
    OpticalContext curr,
  ) {
    // Se ambas estão em beams, podem ser ligeiramente mais próximas
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

  /// Calcula densidade local baseada em número de elementos
  /// 
  /// **Parâmetros:**
  /// - `elementCount`: Número de elementos em uma janela
  /// - `windowWidth`: Largura da janela em pixels
  /// 
  /// **Retorna:** Densidade normalizada (0.0 - 1.0)
  double calculateLocalDensity(int elementCount, double windowWidth) {
    if (windowWidth <= 0) return 0.5;

    // Densidade = elementos por staff space
    final double density = elementCount / (windowWidth / staffSpace);

    // Normalizar (assumindo 1-5 elementos por SS como range típico)
    return ((density - 1.0) / 4.0).clamp(0.0, 1.0);
  }

  /// Calcula compensação para compassos compostos
  /// 
  /// Adiciona espaço entre pulsos ternários (6/8, 9/8, 12/8)
  double compensateForCompoundMeterPulse({
    required bool isStartOfPulse,
    required double pulseSpacing,
  }) {
    if (!enabled || !isStartOfPulse) return 0.0;

    return pulseSpacing * staffSpace * intensity;
  }

  /// Calcula compensação para barlines
  /// 
  /// Retorna [spaceBefore, spaceAfter] em pixels
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

  /// Calcula compensação para mudança de clave
  /// 
  /// Retorna [spaceBefore, spaceAfter] em pixels
  List<double> compensateForClefChange({
    required bool isAtBeginning,
  }) {
    if (!enabled) return [0.0, 0.0];

    if (isAtBeginning) {
      return [0.0, 0.0]; // Sem espaço extra no início
    }

    // Mudança no meio do compasso
    return [
      0.5 * staffSpace * intensity,
      0.75 * staffSpace * intensity,
    ];
  }
}

/// Tipos de barline para compensação
enum BarlineType {
  single,
  doubleBar,
  repeat,
  finalBar,
}
