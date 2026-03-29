// lib/src/layout/tuplet_validator.dart

import '../../core/core.dart';

/// Validador de tuplets based on teoria musical
class TupletValidator {
  /// Tolerância for comparações de ponto flutuante
  static const double epsilon = 0.0001;
  
  /// Valida a razão of the tuplet with base no tempo
  /// 
  /// Regras:
  /// - Tempo simples: numerador > denominador (tuplets contraentes)
  ///   Exceção: dupletos (2:3) are raros mas válidos
  /// - Tempo composto: ambos numerador < denominador (expansivas) 
  ///   e numerador > denominador (contraentes) are válidos
  static bool validateRatio(int numerator, int denominator, TimeSignature? timeSig) {
    if (timeSig == null) return true; // Sem contexto, aceitar
    
    if (timeSig.isSimple) {
      // Tempo simples: numerador > denominador (exceto dupletos)
      if (numerator == 2 && denominator == 3) return true; // Dupleto raro
      return numerator > denominator;
    } else {
      // Tempo composto: ambos tipos are válidos
      return true;
    }
  }
  
  /// Calculatestes a duração total that a tuplet ocupa
  /// 
  /// Fórmula:
  /// - Duração de a note × numerador = duração total antes of the modificação
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
  
  /// Calculatestes a duração modificada de each note dentro of the tuplet
  /// 
  /// Example:
  /// - Tercina (3:2) de colcheias in 4/4
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
  
  /// Determina o value de note apropriado for a tuplet
  /// 
  /// Regra Generatesl: Usesr a próxima divisão natural (potência de 2) abaixo of the numerador
  /// 
  /// Exceção: Dupletos in tempo composto use value ACIMA
  /// 
  /// Examples:
  /// - Tercina (3): Usesr divisão de 2 → colcheias
  /// - Quintina (5): Usesr divisão de 4 → semicolcheias
  /// - Septina (7): Usesr divisão de 4 → semicolcheias
  /// - Nontupleto (9): Usesr divisão de 8 → fUsess
  static int determineNoteValue(
    int numerator,
    int denominator,
    TimeSignature? timeSig,
  ) {
    // Exceção: Dupleto in tempo composto
    if (isDupletInCompoundMeter(numerator, denominator, timeSig)) {
      // Usesr value acima (divisão de 3)
      return 3;
    }
    
    // Regra Generatesl: Usesr potência de 2 abaixo of the numerador
    return getPowerOf2Below(numerator);
  }
  
  /// Checks se é um dupleto in tempo composto
  static bool isDupletInCompoundMeter(
    int numerator,
    int denominator,
    TimeSignature? timeSig,
  ) {
    if (timeSig == null) return false;
    return numerator == 2 && denominator == 3 && timeSig.isCompound;
  }
  
  /// Returns a potência de 2 mais próxima abaixo de n
  /// 
  /// Examples:
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
  
  /// Determina o number de colchetes de beam based no number de notes
  /// 
  /// Regra de Gould:
  /// - Até 3 notes: 1 colchete (colcheias)
  /// - 4-7 notes: 2 colchetes (semicolcheias)
  /// - 8-15 notes: 3 colchetes (fUsess)
  /// - 16-31 notes: 4 colchetes (semifUsess)
  static int getBeamCount(int numerator) {
    if (numerator <= 3) return 1;
    if (numerator <= 7) return 2;
    if (numerator <= 15) return 3;
    if (numerator <= 31) return 4;
    return 5;
  }
  
  /// Valida that a tuplet cabe no tempo disponível
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
  
  /// Checks se a tuplet é irracional
  /// (denominador not é potência de 2 ou 3)
  /// 
  /// Examples irracionais: 7:5, 11:7, 5:3
  static bool isIrrational(int denominator) {
    return TupletNumber.isIrrational(denominator);
  }
}
