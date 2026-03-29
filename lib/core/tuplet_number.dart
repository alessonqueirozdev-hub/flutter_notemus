// lib/core/tuplet_number.dart

import 'time_signature.dart';

/// Configuresção of the number of the tuplet
class TupletNumber {
  /// Size of the fonte (default: 1.2 staff spaces)
  final double fontSize;
  
  /// Space to the left of the number (0.4 staff spaces)
  final double gapLeft;
  
  /// Space to the right of the number (0.5 staff spaces)
  final double gapRight;
  
  /// Mostrar as razão completa (ex: 3:2) in vez de only numerator (3)
  final bool showAsRatio;
  
  /// Mostrar figure de note junto to the razão (ex: 3:2♩)
  final bool showNoteValue;
  
  const TupletNumber({
    this.fontSize = 1.2,
    this.gapLeft = 0.4,
    this.gapRight = 0.5,
    this.showAsRatio = false,
    this.showNoteValue = false,
  });
  
  /// Determina if must mostrar a razão completa
  /// 
  /// Regras:
  /// - Mostrar for tuplets irracionais (denominator not is potência de 2 or 3)
  /// - Mostrar if há ambiguidade no context
  /// - Mostrar if duração total is incomum
  static bool shouldShowRatio(int numerator, int denominator, TimeSignature? timeSig) {
    // Tuplets irracionais always mostram razão
    if (isIrrational(denominator)) return true;
    
    // Razões comuns can be simplificadas
    if (isCommonRatio(numerator, denominator, timeSig)) return false;
    
    // By default, mostrar razão completa if not is comum
    return true;
  }
  
  /// Checks if o denominator is irracional (not is potência de 2 or 3)
  static bool isIrrational(int denominator) {
    // Potências de 2: 1, 2, 4, 8, 16, 32...
    if (isPowerOf2(denominator)) return false;
    
    // Potências de 3: 1, 3, 9, 27...
    if (isPowerOf3(denominator)) return false;
    
    // Not is potência de 2 nem 3 = irracional
    return true;
  }
  
  /// Checks if is a razão comum and inequívoca
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
  
  /// Checks if n is potência de 2
  static bool isPowerOf2(int n) {
    if (n <= 0) return false;
    return (n & (n - 1)) == 0;
  }
  
  /// Checks if n is potência de 3
  static bool isPowerOf3(int n) {
    if (n <= 0) return false;
    while (n > 1) {
      if (n % 3 != 0) return false;
      n ~/= 3;
    }
    return n == 1;
  }
  
  /// Generates o text of the number
  String generateText(int numerator, int denominator, {bool forceRatio = false}) {
    if (forceRatio || showAsRatio) {
      return '$numerator:$denominator';
    }
    return numerator.toString();
  }
}
