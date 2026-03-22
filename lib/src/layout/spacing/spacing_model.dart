/// Modelos matemáticos de espaçamento duracional
/// 
/// Baseado em pesquisa acadêmica e implementações profissionais:
/// - Modelo de Raiz Quadrada (Dorico) - RECOMENDADO
/// - Modelo Logarítmico (MuseScore antigo)
/// - Modelo Linear
/// - Modelo Exponencial (Lime)
import 'dart:math';

/// Tipo de modelo de espaçamento a ser usado
enum SpacingModel {
  /// Modelo de raiz quadrada (√2 entre durações consecutivas)
  /// 
  /// **RECOMENDADO** - Usado por Dorico
  /// - Aproximação quase perfeita da tabela de Gould
  /// - Transições suaves entre todas as durações
  /// - Proporcionalidade perceptual ótima
  /// 
  /// Fórmula: s = 1 - 0.777 + 0.777 × √t
  squareRoot,

  /// Modelo logarítmico (MuseScore 3.6 antigo)
  /// 
  /// Fórmula: s = 1 + 0.865617 × log(t)
  /// - Vantagens: Impede explosão de espaço em notas longas
  /// - Desvantagens: Diferenças excessivas entre notas curtas
  logarithmic,

  /// Modelo linear
  /// 
  /// Fórmula: s = 1 - 0.134 + 0.134 × t
  /// - Vantagens: Proporcionalidade direta
  /// - Desvantagens: Notas longas ocupam espaço excessivo
  linear,

  /// Modelo exponencial (Lime)
  /// 
  /// Fórmula: s = base^(1/duração)
  /// - base → 1.0: duração tem menos impacto
  /// - base → 0.0: duração tem impacto máximo
  exponential,
}

/// Calculadora de espaçamento baseada em durações
/// 
/// Implementa os modelos matemáticos de espaçamento profissional
/// seguindo a tabela de Elaine Gould (Behind Bars) e algoritmos
/// de MuseScore, Dorico e LilyPond.
class SpacingCalculator {
  /// Modelo de espaçamento a ser usado
  final SpacingModel model;

  /// Fator de multiplicação global (1.0 = normal)
  /// 
  /// Valores típicos:
  /// - 0.8 - 1.0: Música compacta
  /// - 1.0 - 1.5: Música normal
  /// - 1.5 - 2.0: Música espaçada
  final double spacingRatio;

  /// Base para modelo exponencial (0.0 - 1.0)
  /// 
  /// Usado apenas quando model = SpacingModel.exponential
  final double exponentialBase;

  const SpacingCalculator({
    this.model = SpacingModel.squareRoot,
    this.spacingRatio = 1.5,
    this.exponentialBase = 0.7,
  });

  /// Calcula o espaço para uma duração relativa
  /// 
  /// **Parâmetros:**
  /// - `duration`: Duração da nota/acorde atual
  /// - `shortestDuration`: Menor duração no sistema (referência)
  /// 
  /// **Retorna:** Espaço em unidades relativas (multiplicar por staffSpace depois)
  /// 
  /// **Exemplo:**
  /// ```dart
  /// // Nota de 1/4 quando a menor nota é 1/16
  /// double space = calculator.calculateSpace(0.25, 0.0625);
  /// // t = 0.25 / 0.0625 = 4.0
  /// // Com raiz quadrada: s = (1 - 0.777 + 0.777 × √4) × 1.5
  /// //                      = (1 - 0.777 + 0.777 × 2.0) × 1.5
  /// //                      = 1.777 × 1.5 = 2.666 unidades
  /// ```
  double calculateSpace(double duration, double shortestDuration) {
    if (shortestDuration <= 0) {
      return spacingRatio; // Fallback
    }

    // t = duração relativa (nota mais curta = 1)
    final double t = duration / shortestDuration;

    double baseSpace;

    switch (model) {
      case SpacingModel.squareRoot:
        // Modelo de Dorico (RECOMENDADO)
        // s = 1 - 0.777 + 0.777 × √t
        baseSpace = 1.0 - 0.777 + (0.777 * sqrt(t));
        break;

      case SpacingModel.logarithmic:
        // Modelo antigo do MuseScore
        // s = 1 + 0.865617 × log(t)
        baseSpace = 1.0 + (0.865617 * log(t));
        break;

      case SpacingModel.linear:
        // Modelo linear simples
        // s = 1 - 0.134 + 0.134 × t
        baseSpace = 1.0 - 0.134 + (0.134 * t);
        break;

      case SpacingModel.exponential:
        // Modelo Lime
        // s = base^(1/t)
        if (t > 0) {
          baseSpace = pow(exponentialBase, 1.0 / t).toDouble();
        } else {
          baseSpace = 1.0;
        }
        break;
    }

    return baseSpace * spacingRatio;
  }

  /// Tabela de referência de Elaine Gould (Behind Bars)
  /// 
  /// Valores relativos de espaçamento por tipo de nota:
  /// - Fusa (1/32): 1.0 unidade
  /// - Semicolcheia (1/16): 1.5 unidades
  /// - Colcheia (1/8): 2.0 unidades
  /// - Semínima (1/4): 3.0 unidades
  /// - Mínima (1/2): 4.0 unidades
  /// - Semibreve (1/1): 5.0 unidades
  /// - Breve (2/1): ~9.0 unidades (extrapolado)
  static final Map<double, double> gouldSpacingTable = {
    1.0 / 32.0: 1.0, // Fusa
    1.0 / 16.0: 1.5, // Semicolcheia
    1.0 / 8.0: 2.0, // Colcheia
    1.0 / 4.0: 3.0, // Semínima
    1.0 / 2.0: 4.0, // Mínima
    1.0: 5.0, // Semibreve
    2.0: 9.0, // Breve (extrapolado)
  };

  /// Verifica a precisão do modelo comparando com a tabela de Gould
  /// 
  /// **Retorna:** Mapa de duração → erro percentual
  Map<double, double> validateAgainstGould() {
    final Map<double, double> errors = {};
    final double referenceShort = 1.0 / 32.0; // Fusa como referência

    gouldSpacingTable.forEach((duration, expectedSpace) {
      final double calculatedSpace = calculateSpace(duration, referenceShort);
      final double error = ((calculatedSpace - expectedSpace).abs() / expectedSpace) * 100;
      errors[duration] = error;
    });

    return errors;
  }
}
