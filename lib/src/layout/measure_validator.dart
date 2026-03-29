// lib/src/layout/measure_validator.dart
// System de validação rigorosa de measures based on teoria musical

import 'package:flutter/foundation.dart';
import '../../core/core.dart';

/// Resultado detalhado of the validação de um measure
class MeasureValidationResult {
  final bool isValid;
  final double expectedCapacity;
  final double actualDuration;
  final double difference;
  final int numerator;
  final int denominator;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, double> elementBreakdown;

  MeasureValidationResult({
    required this.isValid,
    required this.expectedCapacity,
    required this.actualDuration,
    required this.difference,
    required this.numerator,
    required this.denominator,
    this.warnings = const [],
    this.errors = const [],
    this.elementBreakdown = const {},
  });

  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('VALIDAÇÃO DE COMPASSO: ${isValid ? "✓ VÁLIDO" : "✗ INVÁLIDO"}');
    buffer.writeln('Fórmula: $numerator/$denominator');
    buffer.writeln('Capacidade esperada: $expectedCapacity unidades');
    buffer.writeln('Duração atual: $actualDuration unidades');
    
    if (!isValid) {
      if (actualDuration > expectedCapacity) {
        buffer.writeln('⚠️ EXCESSO: +${difference.toStringAsFixed(4)} unidades');
        buffer.writeln('   Remova figuras ou use compasso maior.');
      } else {
        buffer.writeln('⚠️ FALTA: -${difference.abs().toStringAsFixed(4)} unidades');
        buffer.writeln('   Adicione pausas ou notas.');
      }
    }
    
    if (elementBreakdown.isNotEmpty) {
      buffer.writeln('\nDetalhamento por elemento:');
      elementBreakdown.forEach((key, value) {
        buffer.writeln('  - $key: $value unidades');
      });
    }
    
    if (warnings.isNotEmpty) {
      buffer.writeln('\nAvisos:');
      for (final warning in warnings) {
        buffer.writeln('  ⚠️ $warning');
      }
    }
    
    if (errors.isNotEmpty) {
      buffer.writeln('\nErros:');
      for (final error in errors) {
        buffer.writeln('  ✗ $error');
      }
    }
    
    buffer.writeln('═══════════════════════════════════════');
    return buffer.toString();
  }
}

/// Validador rigoroso de measures based on teoria musical
class MeasureValidator {
  // Tolerância for erros de ponto flutuante (0.0001 unidades)
  static const double tolerance = 0.0001;

  /// Valida um measure completo
  static MeasureValidationResult validate(
    Measure measure, {
    bool allowAnacrusis = false,
  }) {
    // Encontrar time signature
    TimeSignature? timeSignature = _findTimeSignature(measure);
    
    if (timeSignature == null) {
      return MeasureValidationResult(
        isValid: true,
        expectedCapacity: 0,
        actualDuration: 0,
        difference: 0,
        numerator: 0,
        denominator: 0,
        warnings: ['Compasso sem fórmula de compasso - validação ignorada'],
      );
    }

    // Calculatestesr capacidade total of the measure
    final expectedCapacity = _calculateMeasureCapacity(
      timeSignature.numerator,
      timeSignature.denominator,
    );

    // Processesr all os elementos e Calculatestesr duração total
    final elementBreakdown = <String, double>{};
    final warnings = <String>[];
    double actualDuration = 0.0;
    int elementIndex = 0;

    for (final element in measure.elements) {
      if (element is Note) {
        final duration = _calculateNoteDuration(element, warnings);
        actualDuration += duration;
        elementBreakdown['Nota ${elementIndex + 1} (${element.duration.type.name})'] = duration;
        elementIndex++;
      } else if (element is Rest) {
        final duration = _calculateRestDuration(element, warnings);
        actualDuration += duration;
        elementBreakdown['Pausa ${elementIndex + 1} (${element.duration.type.name})'] = duration;
        elementIndex++;
      } else if (element is Chord) {
        final duration = _calculateChordDuration(element, warnings);
        actualDuration += duration;
        elementBreakdown['Acorde ${elementIndex + 1} (${element.duration.type.name})'] = duration;
        elementIndex++;
      } else if (element is Tuplet) {
        // Critical: Validar notes DENTRO de tuplets!
        final tupletDuration = _calculateTupletDuration(element, warnings);
        actualDuration += tupletDuration;
        elementBreakdown['Tuplet ${elementIndex + 1} (${element.actualNotes}:${element.normalNotes})'] = tupletDuration;
        elementIndex++;
      }
    }

    // Calculatestesr diferença
    final difference = actualDuration - expectedCapacity;
    final isValid = difference.abs() < tolerance;

    // Generatesr erros se inválido
    final errors = <String>[];
    if (!isValid && !allowAnacrusis) {
      if (difference > 0) {
        errors.add(
          'Compasso excedido em ${difference.toStringAsFixed(4)} unidades. '
          'Remova figuras ou use fórmula de compasso maior.',
        );
      } else {
        errors.add(
          'Faltam ${difference.abs().toStringAsFixed(4)} unidades para completar o compasso. '
          'Adicione pausas ou notas.',
        );
      }
    }

    // Validações Addsis
    _performAdditionalValidations(
      measure,
      timeSignature,
      warnings,
      errors,
    );

    return MeasureValidationResult(
      isValid: isValid,
      expectedCapacity: expectedCapacity,
      actualDuration: actualDuration,
      difference: difference,
      numerator: timeSignature.numerator,
      denominator: timeSignature.denominator,
      warnings: warnings,
      errors: errors,
      elementBreakdown: elementBreakdown,
    );
  }

  /// Encontra o time signature no measure
  static TimeSignature? _findTimeSignature(Measure measure) {
    for (final element in measure.elements) {
      if (element is TimeSignature) {
        return element;
      }
    }
    return null;
  }

  /// Calculatestes a capacidade total of the measure based na fórmula
  /// 
  /// Fórmula: Capacidade = Numerador × (1 ÷ Denominador)
  /// 
  /// Examples:
  /// - 4/4: 4 × (1/4) = 1.0 semibreve
  /// - 3/8: 3 × (1/8) = 0.375 semibreve
  /// - 6/8: 6 × (1/8) = 0.75 semibreve
  static double _calculateMeasureCapacity(int numerator, int denominator) {
    return numerator / denominator;
  }

  /// Calculatestes o value base de a figura rítmica
  /// 
  /// Hierarquia de Valores (base = semibreve = 1.0):
  /// - Semibreve: 1.0
  /// - Mínima: 0.5
  /// - Semínima: 0.25
  /// - Colcheia: 0.125
  /// - Semicolcheia: 0.0625
  /// - FUses: 0.03125
  /// - SemifUses: 0.015625
  static double _calculateBaseValue(DurationType type) {
    switch (type) {
      case DurationType.whole:
        return 1.0;
      case DurationType.half:
        return 0.5;
      case DurationType.quarter:
        return 0.25;
      case DurationType.eighth:
        return 0.125;
      case DurationType.sixteenth:
        return 0.0625;
      case DurationType.thirtySecond:
        return 0.03125;
      case DurationType.sixtyFourth:
        return 0.015625;
      default:
        return 0.25; // Fallback para semínima
    }
  }

  /// applies modificadores de duração (pontos, tuplets)
  static double _applyModifiers(
    double baseValue,
    Duration duration,
    List<String> warnings,
  ) {
    double modifiedValue = baseValue;

    // Appliesr pontos de aumento
    if (duration.dots > 0) {
      if (duration.dots == 1) {
        // Ponto simples: Adds 50% of the value
        modifiedValue = baseValue * 1.5;
      } else if (duration.dots == 2) {
        // Duplo ponto: Adds 75% of the value (50% + 25%)
        modifiedValue = baseValue * 1.75;
      } else {
        warnings.add(
          'Figura com ${duration.dots} pontos é incomum. '
          'Verifique a notação.',
        );
        // Fórmula Generatesl for n pontos: 1 + 0.5 + 0.25 + ... + 0.5^n
        double multiplier = 1.0;
        for (int i = 1; i <= duration.dots; i++) {
          multiplier += 1.0 / (1 << i); // 2^i
        }
        modifiedValue = baseValue * multiplier;
      }
    }

    // TODO: Appliesr tuplets when implementadas
    // if (duration.tuplet != null) {
    //   modifiedValue = _applyTuplet(modifiedValue, duration.tuplet, warnings);
    // }

    return modifiedValue;
  }

  /// Calculatestes duração de a note
  static double _calculateNoteDuration(Note note, List<String> warnings) {
    final baseValue = _calculateBaseValue(note.duration.type);
    return _applyModifiers(baseValue, note.duration, warnings);
  }

  /// Calculatestes duração de a paUses (mesmo value that note)
  static double _calculateRestDuration(Rest rest, List<String> warnings) {
    final baseValue = _calculateBaseValue(rest.duration.type);
    return _applyModifiers(baseValue, rest.duration, warnings);
  }

  /// Calculatestes duração de um chord (all as notes têm mesma duração)
  static double _calculateChordDuration(Chord chord, List<String> warnings) {
    final baseValue = _calculateBaseValue(chord.duration.type);
    return _applyModifiers(baseValue, chord.duration, warnings);
  }

  /// Calculatestes duração de um tuplet (tuplet)
  /// 
  /// Fórmula: Duração = (Soma das notes internas) × (normalNotes / actualNotes)
  /// 
  /// Examples:
  /// - Tercina (3:2): 3 colcheias no tempo de 2 → each a vale 2/3 of the value original
  /// - Quintina (5:4): 5 semicolcheias no tempo de 4 → each a vale 4/5 of the value original
  static double _calculateTupletDuration(Tuplet tuplet, List<String> warnings) {
    // Somar duração de all os elementos dentro of the tuplet
    double totalInternalDuration = 0.0;
    
    for (final element in tuplet.elements) {
      if (element is Note) {
        final baseValue = _calculateBaseValue(element.duration.type);
        final modifiedValue = _applyModifiers(baseValue, element.duration, warnings);
        totalInternalDuration += modifiedValue;
      } else if (element is Rest) {
        final baseValue = _calculateBaseValue(element.duration.type);
        final modifiedValue = _applyModifiers(baseValue, element.duration, warnings);
        totalInternalDuration += modifiedValue;
      } else if (element is Chord) {
        final baseValue = _calculateBaseValue(element.duration.type);
        final modifiedValue = _applyModifiers(baseValue, element.duration, warnings);
        totalInternalDuration += modifiedValue;
      }
    }
    
    // Appliesr proporção of the tuplet
    // Example: Tercina (3:2) = 3 notes ocupam tempo de 2
    // Então: duração_real = duração_nominal × (2/3)
    final tupletRatio = tuplet.normalNotes / tuplet.actualNotes;
    final actualTupletDuration = totalInternalDuration * tupletRatio;
    
    // add warning se tuplet tiver proporção incomum
    if (tuplet.actualNotes > 7) {
      warnings.add(
        'Tuplet com ${tuplet.actualNotes} notas é incomum. '
        'Verifique se está correto.',
      );
    }
    
    return actualTupletDuration;
  }

  /// Realiza validações Addsis específicas
  static void _performAdditionalValidations(
    Measure measure,
    TimeSignature timeSignature,
    List<String> warnings,
    List<String> errors,
  ) {
    // Validar measures compostos (6/8, 9/8, 12/8)
    if (timeSignature.denominator == 8 && timeSignature.numerator % 3 == 0) {
      warnings.add(
        'Compasso composto ${timeSignature.numerator}/8: '
        'Verifique agrupamento em pulsos ternários '
        '(${timeSignature.numerator ~/ 3} pulsos de 3 colcheias).',
      );
    }

    // Validar measures irregulares
    final irregularNumerators = [5, 7, 11, 13];
    if (irregularNumerators.contains(timeSignature.numerator)) {
      warnings.add(
        'Compasso irregular ${timeSignature.numerator}/${timeSignature.denominator}: '
        'Verifique acentuação métrica e agrupamento.',
      );
    }

    // Detectar excesso de figuras pequenas
    int smallNotesCount = 0;
    for (final element in measure.elements) {
      if (element is Note || element is Rest || element is Chord) {
        final duration = element is Note
            ? element.duration
            : element is Rest
                ? element.duration
                : (element as Chord).duration;
        
        if (duration.type == DurationType.sixteenth ||
            duration.type == DurationType.thirtySecond ||
            duration.type == DurationType.sixtyFourth) {
          smallNotesCount++;
        }
      }
    }

    if (smallNotesCount > 8) {
      warnings.add(
        'Compasso com muitas figuras pequenas ($smallNotesCount). '
        'Considere usar beaming apropriado para facilitar leitura.',
      );
    }
  }

  /// Valida a sequência de measures (with herança de TimeSignature)
  static List<MeasureValidationResult> validateStaff(
    Staff staff, {
    bool allowAnacrusis = false,
  }) {
    final results = <MeasureValidationResult>[];
    TimeSignature? currentTimeSignature;
    
    for (int i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      final isFirstMeasure = i == 0;
      
      // Procurar TimeSignature neste measure
      TimeSignature? measureTimeSignature = _findTimeSignature(measure);
      
      // Se encontrou, currentizar o TimeSignature corrente
      if (measureTimeSignature != null) {
        currentTimeSignature = measureTimeSignature;
      }
      
      // Validar with TimeSignature herdado
      final result = validateWithTimeSignature(
        measure,
        currentTimeSignature,
        allowAnacrusis: allowAnacrusis && isFirstMeasure,
      );
      
      results.add(result);
    }

    return results;
  }
  
  /// Validation: with TimeSignature explícito (útil for herança)
  static MeasureValidationResult validateWithTimeSignature(
    Measure measure,
    TimeSignature? timeSignature, {
    bool allowAnacrusis = false,
  }) {
    if (timeSignature == null) {
      return MeasureValidationResult(
        isValid: false,
        expectedCapacity: 0,
        actualDuration: 0,
        difference: 0,
        numerator: 0,
        denominator: 0,
        errors: ['Compasso sem fórmula de compasso definida'],
      );
    }

    // Calculatestesr capacidade total of the measure
    final expectedCapacity = _calculateMeasureCapacity(
      timeSignature.numerator,
      timeSignature.denominator,
    );

    // Processesr all os elementos e Calculatestesr duração total
    final elementBreakdown = <String, double>{};
    final warnings = <String>[];
    double actualDuration = 0.0;
    int elementIndex = 0;

    for (final element in measure.elements) {
      if (element is Note) {
        final duration = _calculateNoteDuration(element, warnings);
        actualDuration += duration;
        elementBreakdown['Nota ${elementIndex + 1} (${element.duration.type.name})'] = duration;
        elementIndex++;
      } else if (element is Rest) {
        final duration = _calculateRestDuration(element, warnings);
        actualDuration += duration;
        elementBreakdown['Pausa ${elementIndex + 1} (${element.duration.type.name})'] = duration;
        elementIndex++;
      } else if (element is Chord) {
        final duration = _calculateChordDuration(element, warnings);
        actualDuration += duration;
        elementBreakdown['Acorde ${elementIndex + 1} (${element.duration.type.name})'] = duration;
        elementIndex++;
      } else if (element is Tuplet) {
        // Critical: Validar notes DENTRO de tuplets!
        final tupletDuration = _calculateTupletDuration(element, warnings);
        actualDuration += tupletDuration;
        elementBreakdown['Tuplet ${elementIndex + 1} (${element.actualNotes}:${element.normalNotes})'] = tupletDuration;
        elementIndex++;
      }
    }

    // Calculatestesr diferença
    final difference = actualDuration - expectedCapacity;
    final isValid = difference.abs() < tolerance;

    // Generatesr erros se inválido
    final errors = <String>[];
    if (!isValid && !allowAnacrusis) {
      if (difference > 0) {
        errors.add(
          'Compasso excedido em ${difference.toStringAsFixed(4)} unidades. '
          'Remova figuras ou use fórmula de compasso maior.',
        );
      } else {
        errors.add(
          'Faltam ${difference.abs().toStringAsFixed(4)} unidades para completar o compasso. '
          'Adicione pausas ou notas.',
        );
      }
    }

    // Validações Addsis
    _performAdditionalValidations(
      measure,
      timeSignature,
      warnings,
      errors,
    );

    return MeasureValidationResult(
      isValid: isValid,
      expectedCapacity: expectedCapacity,
      actualDuration: actualDuration,
      difference: difference,
      numerator: timeSignature.numerator,
      denominator: timeSignature.denominator,
      warnings: warnings,
      errors: errors,
      elementBreakdown: elementBreakdown,
    );
  }

  /// Imprime relatório completo de validação
  static void printValidationReport(List<MeasureValidationResult> results) {
    debugPrint('\n╔═══════════════════════════════════════════════════════╗');
    debugPrint('║     RELATÓRIO DE VALIDAÇÃO DE COMPASSOS              ║');
    debugPrint('╚═══════════════════════════════════════════════════════╝\n');

    int validCount = 0;
    int invalidCount = 0;

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      
      if (result.isValid) {
        validCount++;
      } else {
        invalidCount++;
        debugPrint('📊 COMPASSO ${i + 1}:');
        debugPrint(result.getSummary());
      }
    }

    debugPrint('\n╔═══════════════════════════════════════════════════════╗');
    debugPrint('║ RESUMO FINAL                                          ║');
    debugPrint('╠═══════════════════════════════════════════════════════╣');
    debugPrint('║ Total de compassos: ${results.length.toString().padLeft(31)} ║');
    debugPrint('║ Compassos válidos: ${validCount.toString().padLeft(32)} ║');
    debugPrint('║ Compassos inválidos: ${invalidCount.toString().padLeft(30)} ║');
    debugPrint('╚═══════════════════════════════════════════════════════╝\n');
  }
}
