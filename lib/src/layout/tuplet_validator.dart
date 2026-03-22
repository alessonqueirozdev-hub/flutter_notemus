// lib/src/layout/tuplet_validator.dart

import '../../core/core.dart';
import '../../core/tuplet_number.dart';

/// Validador de quiálteras baseado em teoria musical
class TupletValidator {
  /// Tolerância para comparações de ponto flutuante
  static const double epsilon = 0.0001;
  
  /// Valida a razão da quiáltera com base no tempo
  /// 
  /// Regras:
  /// - Tempo simples: numerador > denominador (quiálteras contraentes)
  ///   Exceção: dupletos (2:3) são raros mas válidos
  /// - Tempo composto: ambos numerador < denominador (expansivas) 
  ///   e numerador > denominador (contraentes) são válidos
  static bool validateRatio(int numerator, int denominator, TimeSignature? timeSig) {
    if (timeSig == null) return true; // Sem contexto, aceitar
    
    if (timeSig.isSimple) {
      // Tempo simples: numerador > denominador (exceto dupletos)
      if (numerator == 2 && denominator == 3) return true; // Dupleto raro
      return numerator > denominator;
    } else {
      // Tempo composto: ambos tipos são válidos
      return true;
    }
  }
  
  /// Calcula a duração total que a quiáltera ocupa
  /// 
  /// Fórmula:
  /// - Duração de uma nota × numerador = duração total antes da modificação
  /// - Modificador = denominador / numerador
  /// - Duração final = duração total × modificador
  static double calculateTotalDuration(
    int numerator,
    int denominator,
    double singleNoteDuration,
  ) {
    final totalBeforeModification = singleNoteDuration * numerator;
    final modifier = denominator / numerator;
    return totalBeforeModification * modifier;
  }
  
  /// Calcula a duração modificada de cada nota dentro da quiáltera
  /// 
  /// Exemplo:
  /// - Tercina (3:2) de colcheias em 4/4
  /// - Colcheia normal = 0.5 (1/2 de semínima)
  /// - Modificador = 2/3
  /// - Colcheia de tercina = 0.5 × (2/3) = 0.333... (1/3 de semínima)
  static double getModifiedDuration(
    int numerator,
    int denominator,
    double baseDuration,
  ) {
    final modifier = denominator / numerator;
    return baseDuration * modifier;
  }
  
  /// Determina o valor de nota apropriado para a quiáltera
  /// 
  /// Regra Geral: Usar a próxima divisão natural (potência de 2) abaixo do numerador
  /// 
  /// Exceção: Dupletos em tempo composto usam valor ACIMA
  /// 
  /// Exemplos:
  /// - Tercina (3): usar divisão de 2 → colcheias
  /// - Quintina (5): usar divisão de 4 → semicolcheias
  /// - Septina (7): usar divisão de 4 → semicolcheias
  /// - Nontupleto (9): usar divisão de 8 → fusas
  static int determineNoteValue(
    int numerator,
    int denominator,
    TimeSignature? timeSig,
  ) {
    // Exceção: Dupleto em tempo composto
    if (isDupletInCompoundMeter(numerator, denominator, timeSig)) {
      // Usar valor acima (divisão de 3)
      return 3;
    }
    
    // Regra geral: usar potência de 2 abaixo do numerador
    return getPowerOf2Below(numerator);
  }
  
  /// Verifica se é um dupleto em tempo composto
  static bool isDupletInCompoundMeter(
    int numerator,
    int denominator,
    TimeSignature? timeSig,
  ) {
    if (timeSig == null) return false;
    return numerator == 2 && denominator == 3 && timeSig.isCompound;
  }
  
  /// Retorna a potência de 2 mais próxima abaixo de n
  /// 
  /// Exemplos:
  /// - 3 → 2
  /// - 5, 6, 7 → 4
  /// - 9, 10, 11, 12, 13, 14, 15 → 8
  /// - 17...31 → 16
  static int getPowerOf2Below(int n) {
    if (n <= 2) return 2;
    if (n <= 4) return 4;
    if (n <= 8) return 8;
    if (n <= 16) return 16;
    if (n <= 32) return 32;
    return 64;
  }
  
  /// Determina o número de colchetes de beam baseado no número de notas
  /// 
  /// Regra de Gould:
  /// - Até 3 notas: 1 colchete (colcheias)
  /// - 4-7 notas: 2 colchetes (semicolcheias)
  /// - 8-15 notas: 3 colchetes (fusas)
  /// - 16-31 notas: 4 colchetes (semifusas)
  static int getBeamCount(int numerator) {
    if (numerator <= 3) return 1;
    if (numerator <= 7) return 2;
    if (numerator <= 15) return 3;
    if (numerator <= 31) return 4;
    return 5;
  }
  
  /// Valida que a quiáltera cabe no tempo disponível
  static bool fitsInAvailableTime(
    int numerator,
    int denominator,
    double singleNoteDuration,
    double availableTime,
  ) {
    final duration = calculateTotalDuration(
      numerator,
      denominator,
      singleNoteDuration,
    );
    return duration <= availableTime + epsilon;
  }
  
  /// Verifica se a quiáltera é irracional
  /// (denominador não é potência de 2 ou 3)
  /// 
  /// Exemplos irracionais: 7:5, 11:7, 5:3
  static bool isIrrational(int denominator) {
    return TupletNumber.isIrrational(denominator);
  }
}
