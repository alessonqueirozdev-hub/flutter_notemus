// lib/core/tuplet_number.dart

import 'time_signature.dart';

/// Configuração do número da quiáltera
class TupletNumber {
  /// Tamanho da fonte (padrão: 1.2 staff spaces)
  final double fontSize;
  
  /// Espaço à esquerda do número (0.4 staff spaces)
  final double gapLeft;
  
  /// Espaço à direita do número (0.5 staff spaces)
  final double gapRight;
  
  /// Mostrar como razão completa (ex: 3:2) em vez de apenas numerador (3)
  final bool showAsRatio;
  
  /// Mostrar figura de nota junto à razão (ex: 3:2♩)
  final bool showNoteValue;
  
  const TupletNumber({
    this.fontSize = 1.2,
    this.gapLeft = 0.4,
    this.gapRight = 0.5,
    this.showAsRatio = false,
    this.showNoteValue = false,
  });
  
  /// Determina se deve mostrar a razão completa
  /// 
  /// Regras:
  /// - Mostrar para quiálteras irracionais (denominador não é potência de 2 ou 3)
  /// - Mostrar se há ambiguidade no contexto
  /// - Mostrar se duração total é incomum
  static bool shouldShowRatio(int numerator, int denominator, TimeSignature? timeSig) {
    // Quiálteras irracionais sempre mostram razão
    if (isIrrational(denominator)) return true;
    
    // Razões comuns podem ser simplificadas
    if (isCommonRatio(numerator, denominator, timeSig)) return false;
    
    // Por padrão, mostrar razão completa se não é comum
    return true;
  }
  
  /// Verifica se o denominador é irracional (não é potência de 2 ou 3)
  static bool isIrrational(int denominator) {
    // Potências de 2: 1, 2, 4, 8, 16, 32...
    if (isPowerOf2(denominator)) return false;
    
    // Potências de 3: 1, 3, 9, 27...
    if (isPowerOf3(denominator)) return false;
    
    // Não é potência de 2 nem 3 = irracional
    return true;
  }
  
  /// Verifica se é uma razão comum e inequívoca
  static bool isCommonRatio(int numerator, int denominator, TimeSignature? timeSig) {
    if (timeSig == null) return false;
    
    if (timeSig.isSimple) {
      // Tempo simples: razões comuns
      if (numerator == 3 && denominator == 2) return true; // Tercina
      if (numerator == 5 && denominator == 4) return true; // Quintina
      if (numerator == 6 && denominator == 4) return true; // Sextina
      if (numerator == 7 && denominator == 4) return true; // Septina
      if (numerator == 9 && denominator == 8) return true; // Nontupleto
    } else {
      // Tempo composto: razões comuns
      if (numerator == 2 && denominator == 3) return true; // Dupleto
      if (numerator == 4 && (denominator == 3 || denominator == 6)) return true; // Quadrupleto
      if (numerator == 8 && denominator == 6) return true; // Octupleto
    }
    
    return false;
  }
  
  /// Verifica se n é potência de 2
  static bool isPowerOf2(int n) {
    if (n <= 0) return false;
    return (n & (n - 1)) == 0;
  }
  
  /// Verifica se n é potência de 3
  static bool isPowerOf3(int n) {
    if (n <= 0) return false;
    while (n > 1) {
      if (n % 3 != 0) return false;
      n ~/= 3;
    }
    return n == 1;
  }
  
  /// Gera o texto do número
  String generateText(int numerator, int denominator, {bool forceRatio = false}) {
    if (forceRatio || showAsRatio) {
      return '$numerator:$denominator';
    }
    return numerator.toString();
  }
}
