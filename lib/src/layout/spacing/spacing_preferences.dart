/// Preferences configuráveis de spacing
///
/// Permite aos usuários ajustar o comportamento of the system de spacing
/// for balancear estética, densidade and legibilidade.
library;

import 'spacing_model.dart';

/// Preferences globais de spacing
/// 
/// Use this class for controlar o comportamento of the spacing engine
/// sem modificar o código interno.
class SpacingPreferences {
  /// Modelo matemático de spacing
  /// 
  /// **Valores recomendados:**
  /// - `SpacingModel.squareRoot` (default): Melhor aproximação of the tabela de Gould
  /// - `SpacingModel.logarithmic`: For music very compacta
  /// - `SpacingModel.linear`: For uniformidade visual
  final SpacingModel model;

  /// Fator de spacing global (1.0 = normal)
  /// 
  /// **Valores típicos:**
  /// - `0.8 - 1.0`: Music compacta (livros, pocket scores)
  /// - `1.0 - 1.5`: Music normal (performance parts)
  /// - `1.5 - 2.0`: Music espaçada (estudantes, pedagogia)
  /// - `2.0+`: Music very espaçada (Createsnças, iniciantes)
  final double spacingFactor;

  /// Preference de densidade (0.0 = apertado, 1.0 = espaçado)
  /// 
  /// Controla o trade-off between compactação and clareza:
  /// - `0.0 - 0.3`: Máxima densidade (economizar papel)
  /// - `0.3 - 0.7`: Balanceado (default: 0.5)
  /// - `0.7 - 1.0`: Máxima clareza (facilitar leitura)
  final double densityPreference;

  /// Ativar compensação óptica
  /// 
  /// Ajusta spacing based on:
  /// - Direction de stems
  /// - Transições de duração
  /// - Proximidade de accidentals
  /// 
  /// **Recomendado: true** for aparência profissional
  final bool enableOpticalSpacing;

  /// Spacing mínimo between symbols (in staff spaces)
  /// 
  /// **Valores típicos:**
  /// - `0.15 - 0.20`: Music very compacta
  /// - `0.25 - 0.30`: Normal (default: 0.25)
  /// - `0.35 - 0.50`: Espaçada
  final double minGap;

  /// Priorizar uniformidade vs. compactação (0.0 - 1.0)
  /// 
  /// - `0.0`: Máxima compactação (minimizar width)
  /// - `0.5`: Balanceado
  /// - `1.0`: Máxima uniformidade (notes de same duração always iguais)
  /// 
  /// **Recomendado: 0.7** for qualidade profissional
  final double consistencyWeight;

  /// Spacing de paUsess relativo a notes (0.0 - 1.0)
  /// 
  /// Elaine Gould recomenda 80% of the note spacing equivalentes
  /// 
  /// **Default: 0.8**
  final double restSpacingRatio;

  /// Permitir sobreposition de symbols in casos extremos
  /// 
  /// When false, forçará spacing mínimo same that afete proporções
  /// When true, permitirá leve sobreposition for manter proporções
  /// 
  /// **Default: false** (segurança in first lugar)
  final bool allowSymbolOverlap;

  /// Ajuste de spacing for measures compostos (6/8, 9/8, 12/8)
  /// 
  /// Adds space extra between pulsos ternários for clareza visual
  /// 
  /// **Valores típicos:**
  /// - `0.0`: Sem ajuste
  /// - `0.1 - 0.15`: Subtle (default: 0.15)
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

  /// Preferences for music compacta (economizar space)
  static const SpacingPreferences compact = SpacingPreferences(
    spacingFactor: 1.0,
    densityPreference: 0.2,
    minGap: 0.20,
    consistencyWeight: 0.5,
  );

  /// Preferences for music normal (balanceada)
  static const SpacingPreferences normal = SpacingPreferences(
    spacingFactor: 1.5,
    densityPreference: 0.5,
    minGap: 0.25,
    consistencyWeight: 0.7,
  );

  /// Preferences for music espaçada (máxima legibilidade)
  static const SpacingPreferences spacious = SpacingPreferences(
    spacingFactor: 2.0,
    densityPreference: 0.8,
    minGap: 0.35,
    consistencyWeight: 0.9,
  );

  /// Preferences for pedagogia (estudantes/Createsnças)
  static const SpacingPreferences pedagogical = SpacingPreferences(
    spacingFactor: 2.5,
    densityPreference: 0.9,
    minGap: 0.40,
    consistencyWeight: 1.0,
    compoundMeterPulseSpacing: 0.25,
  );

  /// Createsr cópia with modificações
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

/// Constantes de spacing baseadas in SMuFL and práticas profissionais
class SpacingConstants {
  /// Tolerância for comparações de point flutuante
  static const double epsilon = 0.0001;

  /// Spacing de accidentals in music normal (staff spaces)
  static const double accidentalSpacingNormal = 0.5;

  /// Spacing de accidentals in music compacta (staff spaces)
  static const double accidentalSpacingCompact = 0.25;

  /// Spacing before de barline (staff spaces)
  static const double barlineSpaceBefore = 0.75;

  /// Spacing after de barline (staff spaces)
  static const double barlineSpaceAfter = 0.5;

  /// Spacing de barras duplas (before)
  static const double doubleBarSpaceBefore = 1.0;

  /// Spacing de barras duplas (after)
  static const double doubleBarSpaceAfter = 0.75;

  /// Spacing de barras de repetição (before)
  static const double repeatBarSpaceBefore = 1.25;

  /// Spacing de barras de repetição (after)
  static const double repeatBarSpaceAfter = 1.0;

  /// Spacing before de mudança de clef
  static const double clefChangeSpaceBefore = 0.5;

  /// Spacing after de mudança de clef
  static const double clefChangeSpaceAfter = 0.75;

  /// Slope máxima de bracket de tuplet (staff spaces)
  static const double maxTupletBracketSlope = 0.5;

  /// Gap between notes and bracket de tuplet (staff spaces)
  static const double tupletBracketGap = 0.75;

  /// Height dos ganchos of the bracket de tuplet (staff spaces)
  static const double tupletBracketHookHeight = 0.5;

  /// Offset of the extremidade right of the bracket (staff spaces)
  static const double tupletRightEdgeOffset = 0.25;

  /// Checks if dois valores are quase iguais (within of the tolerância)
  static bool almostEqual(double a, double b) {
    return (a - b).abs() < epsilon;
  }

  /// Arredonda value for múltiplos de 1/4 staff space
  /// 
  /// Ensures alinhamento visual with a grade of the staff
  static double roundToQuarterStaffSpace(double value, double staffSpace) {
    final double quarterSpace = staffSpace * 0.25;
    return (value / quarterSpace).round() * quarterSpace;
  }

  /// Interpola linearmente between dois valores
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }
}
