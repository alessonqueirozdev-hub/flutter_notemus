/// Preferências configuráveis de espaçamento
/// 
/// Permite aos usuários ajustar o comportamento do sistema de espaçamento
/// para balancear estética, densidade e legibilidade.
import 'spacing_model.dart';

/// Preferências globais de espaçamento
/// 
/// Use esta classe para controlar o comportamento do motor de espaçamento
/// sem modificar o código interno.
class SpacingPreferences {
  /// Modelo matemático de espaçamento
  /// 
  /// **Valores recomendados:**
  /// - `SpacingModel.squareRoot` (padrão): Melhor aproximação da tabela de Gould
  /// - `SpacingModel.logarithmic`: Para música muito compacta
  /// - `SpacingModel.linear`: Para uniformidade visual
  final SpacingModel model;

  /// Fator de espaçamento global (1.0 = normal)
  /// 
  /// **Valores típicos:**
  /// - `0.8 - 1.0`: Música compacta (livros, pocket scores)
  /// - `1.0 - 1.5`: Música normal (performance parts)
  /// - `1.5 - 2.0`: Música espaçada (estudantes, pedagogia)
  /// - `2.0+`: Música muito espaçada (crianças, iniciantes)
  final double spacingFactor;

  /// Preferência de densidade (0.0 = apertado, 1.0 = espaçado)
  /// 
  /// Controla o trade-off entre compactação e clareza:
  /// - `0.0 - 0.3`: Máxima densidade (economizar papel)
  /// - `0.3 - 0.7`: Balanceado (padrão: 0.5)
  /// - `0.7 - 1.0`: Máxima clareza (facilitar leitura)
  final double densityPreference;

  /// Ativar compensação óptica
  /// 
  /// Ajusta espaçamento baseado em:
  /// - Direção de hastes
  /// - Transições de duração
  /// - Proximidade de acidentes
  /// 
  /// **Recomendado: true** para aparência profissional
  final bool enableOpticalSpacing;

  /// Espaçamento mínimo entre símbolos (em staff spaces)
  /// 
  /// **Valores típicos:**
  /// - `0.15 - 0.20`: Música muito compacta
  /// - `0.25 - 0.30`: Normal (padrão: 0.25)
  /// - `0.35 - 0.50`: Espaçada
  final double minGap;

  /// Priorizar uniformidade vs. compactação (0.0 - 1.0)
  /// 
  /// - `0.0`: Máxima compactação (minimizar largura)
  /// - `0.5`: Balanceado
  /// - `1.0`: Máxima uniformidade (notas de mesma duração sempre iguais)
  /// 
  /// **Recomendado: 0.7** para qualidade profissional
  final double consistencyWeight;

  /// Espaçamento de pausas relativo a notas (0.0 - 1.0)
  /// 
  /// Elaine Gould recomenda 80% do espaçamento de notas equivalentes
  /// 
  /// **Padrão: 0.8**
  final double restSpacingRatio;

  /// Permitir sobreposição de símbolos em casos extremos
  /// 
  /// Quando false, forçará espaçamento mínimo mesmo que afete proporções
  /// Quando true, permitirá leve sobreposição para manter proporções
  /// 
  /// **Padrão: false** (segurança em primeiro lugar)
  final bool allowSymbolOverlap;

  /// Ajuste de espaçamento para compassos compostos (6/8, 9/8, 12/8)
  /// 
  /// Adiciona espaço extra entre pulsos ternários para clareza visual
  /// 
  /// **Valores típicos:**
  /// - `0.0`: Sem ajuste
  /// - `0.1 - 0.15`: Sutil (padrão: 0.15)
  /// - `0.2 - 0.3`: Pronunciado
  final double compoundMeterPulseSpacing;

  const SpacingPreferences({
    this.model = SpacingModel.squareRoot,
    this.spacingFactor = 1.5,
    this.densityPreference = 0.5,
    this.enableOpticalSpacing = true,
    this.minGap = 0.25,
    this.consistencyWeight = 0.7,
    this.restSpacingRatio = 0.8,
    this.allowSymbolOverlap = false,
    this.compoundMeterPulseSpacing = 0.15,
  });

  /// Preferências para música compacta (economizar espaço)
  static const SpacingPreferences compact = SpacingPreferences(
    spacingFactor: 1.0,
    densityPreference: 0.2,
    minGap: 0.20,
    consistencyWeight: 0.5,
  );

  /// Preferências para música normal (balanceada)
  static const SpacingPreferences normal = SpacingPreferences(
    spacingFactor: 1.5,
    densityPreference: 0.5,
    minGap: 0.25,
    consistencyWeight: 0.7,
  );

  /// Preferências para música espaçada (máxima legibilidade)
  static const SpacingPreferences spacious = SpacingPreferences(
    spacingFactor: 2.0,
    densityPreference: 0.8,
    minGap: 0.35,
    consistencyWeight: 0.9,
  );

  /// Preferências para pedagogia (estudantes/crianças)
  static const SpacingPreferences pedagogical = SpacingPreferences(
    spacingFactor: 2.5,
    densityPreference: 0.9,
    minGap: 0.40,
    consistencyWeight: 1.0,
    compoundMeterPulseSpacing: 0.25,
  );

  /// Criar cópia com modificações
  SpacingPreferences copyWith({
    SpacingModel? model,
    double? spacingFactor,
    double? densityPreference,
    bool? enableOpticalSpacing,
    double? minGap,
    double? consistencyWeight,
    double? restSpacingRatio,
    bool? allowSymbolOverlap,
    double? compoundMeterPulseSpacing,
  }) {
    return SpacingPreferences(
      model: model ?? this.model,
      spacingFactor: spacingFactor ?? this.spacingFactor,
      densityPreference: densityPreference ?? this.densityPreference,
      enableOpticalSpacing: enableOpticalSpacing ?? this.enableOpticalSpacing,
      minGap: minGap ?? this.minGap,
      consistencyWeight: consistencyWeight ?? this.consistencyWeight,
      restSpacingRatio: restSpacingRatio ?? this.restSpacingRatio,
      allowSymbolOverlap: allowSymbolOverlap ?? this.allowSymbolOverlap,
      compoundMeterPulseSpacing: compoundMeterPulseSpacing ?? this.compoundMeterPulseSpacing,
    );
  }
}

/// Constantes de espaçamento baseadas em SMuFL e práticas profissionais
class SpacingConstants {
  /// Tolerância para comparações de ponto flutuante
  static const double epsilon = 0.0001;

  /// Espaçamento de acidentes em música normal (staff spaces)
  static const double accidentalSpacingNormal = 0.5;

  /// Espaçamento de acidentes em música compacta (staff spaces)
  static const double accidentalSpacingCompact = 0.25;

  /// Espaçamento antes de barline (staff spaces)
  static const double barlineSpaceBefore = 0.75;

  /// Espaçamento depois de barline (staff spaces)
  static const double barlineSpaceAfter = 0.5;

  /// Espaçamento de barras duplas (antes)
  static const double doubleBarSpaceBefore = 1.0;

  /// Espaçamento de barras duplas (depois)
  static const double doubleBarSpaceAfter = 0.75;

  /// Espaçamento de barras de repetição (antes)
  static const double repeatBarSpaceBefore = 1.25;

  /// Espaçamento de barras de repetição (depois)
  static const double repeatBarSpaceAfter = 1.0;

  /// Espaçamento antes de mudança de clave
  static const double clefChangeSpaceBefore = 0.5;

  /// Espaçamento depois de mudança de clave
  static const double clefChangeSpaceAfter = 0.75;

  /// Inclinação máxima de colchete de tuplet (staff spaces)
  static const double maxTupletBracketSlope = 0.5;

  /// Gap entre notas e colchete de tuplet (staff spaces)
  static const double tupletBracketGap = 0.75;

  /// Altura dos ganchos do colchete de tuplet (staff spaces)
  static const double tupletBracketHookHeight = 0.5;

  /// Offset da extremidade direita do colchete (staff spaces)
  static const double tupletRightEdgeOffset = 0.25;

  /// Verifica se dois valores são quase iguais (dentro da tolerância)
  static bool almostEqual(double a, double b) {
    return (a - b).abs() < epsilon;
  }

  /// Arredonda valor para múltiplos de 1/4 staff space
  /// 
  /// Garante alinhamento visual com a grade da pauta
  static double roundToQuarterStaffSpace(double value, double staffSpace) {
    final double quarterSpace = staffSpace * 0.25;
    return (value / quarterSpace).round() * quarterSpace;
  }

  /// Interpola linearmente entre dois valores
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }
}
