// lib/src/layout/measure_validator.dart
// System de validação rigorosa de measures based on teoria musical

import 'package:flutter/foundation.dart';
import '../../core/core.dart';
import 'tuplet_validator.dart';

/// Result detalhado of the validação de a measure
///
/// Legacy shape kept for `LayoutEngine`, which only counts valid/invalid bars.
/// For actionable, voice-aware output prefer [MeasureValidation] (obtained
/// from [MeasureValidator.validateVoiceAware]) or the ready-made sentences of
/// [MeasureValidator.describeProblems].
class MeasureValidationResult {
  final bool isValid;
  final double expectedCapacity;

  /// Rhythmic value of the bar: the **longest voice**, not the sum of every
  /// element (voices sound simultaneously). Same definition as
  /// `Measure.currentMusicalValue`.
  final double actualDuration;
  final double difference;
  final int numerator;
  final int denominator;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, double> elementBreakdown;

  /// Rhythmic value written in each voice, keyed by voice number.
  ///
  /// Empty for a bar with no rhythmic content. A single-voice bar has one
  /// entry under `Measure.defaultVoice`.
  final Map<int, double> voiceDurations;

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
    this.voiceDurations = const {},
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

/// Rigorous, voice-aware validation of a [Measure] against its time signature.
///
/// **Where this is used**
///
/// * `LayoutEngine.layout*` (`lib/src/layout/layout_engine.dart`) calls
///   [validateWithTimeSignature] for every bar it lays out, using the
///   inherited time signature, to count valid/invalid bars.
/// * Applications and tools call [describeProblems] to turn a bar into a list
///   of actionable sentences ("bar 4: 4/4 holds 1.0 but voice 2 sums 1.25"),
///   or [validateVoiceAware] when they need the structured [MeasureValidation]
///   (per-voice sums, tuplet inconsistencies, breakdown per element).
/// * Tuplet arithmetic is delegated to [TupletValidator], so the `actual:normal`
///   ratio is the same one `Measure.musicalValueOf` applies.
///
/// **Voice awareness**
///
/// Polyphonic bars are *not* the sum of their elements: every voice runs in
/// parallel and independently spans the bar. Elements are grouped with
/// `Measure.voiceNumberOf` and the value of the bar is the largest per-voice
/// sum — exactly like `Measure.currentMusicalValue`. Summing all voices
/// linearly (as this class used to do) rejects every legal polyphonic bar.
class MeasureValidator {
  /// Tolerância for erros de point flutuante (0.0001 unidades).
  ///
  /// Aliases [TupletValidator.epsilon] so both validators agree on what
  /// "the same duration" means.
  static const double tolerance = TupletValidator.epsilon;

  /// Valida a measure completo
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

    return validateWithTimeSignature(
      measure,
      timeSignature,
      allowAnacrusis: allowAnacrusis,
    );
  }

  /// Encontra o time signature no measure
  ///
  /// Walks `Measure.allElements` (so `MultiVoiceMeasure` works too) and falls
  /// back to [Measure.inheritedTimeSignature].
  ///
  /// That fallback is the AUTHOR'S opt-in hint, not something the layout wrote:
  /// since ADR-005 action item 8 `LayoutEngine` derives the inherited meter as
  /// a value ([LayoutEngine.inheritedTimeSignatures]) and never assigns to the
  /// caller's model. A bar taken out of its staff therefore knows its inherited
  /// meter only if somebody set the field; to validate a whole staff, use
  /// [validateStaff], which derives the inheritance itself.
  static TimeSignature? _findTimeSignature(Measure measure) {
    for (final element in measure.allElements) {
      if (element is TimeSignature) {
        return element;
      }
    }
    return measure.inheritedTimeSignature;
  }

  /// Calculates a capacidade total of the measure based na fórmula
  /// 
  /// Fórmula: Capacidade = Numerator × (1 ÷ Denominator)
  /// 
  /// Examples:
  /// - 4/4: 4 × (1/4) = 1.0 semibreve
  /// - 3/8: 3 × (1/8) = 0.375 semibreve
  /// - 6/8: 6 × (1/8) = 0.75 semibreve
  static double _calculateMeasureCapacity(int numerator, int denominator) {
    return numerator / denominator;
  }

  /// Calculates o value base de a figure rhythmic
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

  /// applies modificadores de duração (points, tuplets)
  static double _applyModifiers(
    double baseValue,
    Duration duration,
    List<String> warnings,
  ) {
    double modifiedValue = baseValue;

    // aplicar points de aumento
    if (duration.dots > 0) {
      if (duration.dots == 1) {
        // Point simples: Adds 50% of the value
        modifiedValue = baseValue * 1.5;
      } else if (duration.dots == 2) {
        // Duplo point: Adds 75% of the value (50% + 25%)
        modifiedValue = baseValue * 1.75;
      } else {
        warnings.add(
          'Figura com ${duration.dots} pontos é incomum. '
          'Verifique a notação.',
        );
        // Fórmula Generatesl for n points: 1 + 0.5 + 0.25 + ... + 0.5^n
        double multiplier = 1.0;
        for (int i = 1; i <= duration.dots; i++) {
          multiplier += 1.0 / (1 << i); // 2^i
        }
        modifiedValue = baseValue * multiplier;
      }
    }

    // Tuplet scaling is not a per-Duration property in this model: tuplets are
    // modeled as Tuplet elements wrapping their children, and the ratio is
    // applied in _calculateTupletDuration when summing the measure.
    return modifiedValue;
  }

  /// Calculates duração de a note
  static double _calculateNoteDuration(Note note, List<String> warnings) {
    final baseValue = _calculateBaseValue(note.duration.type);
    return _applyModifiers(baseValue, note.duration, warnings);
  }

  /// Calculates duração de a pausa (same value that note)
  static double _calculateRestDuration(Rest rest, List<String> warnings) {
    final baseValue = _calculateBaseValue(rest.duration.type);
    return _applyModifiers(baseValue, rest.duration, warnings);
  }

  /// Calculates duração de a chord (all as notes têm same duração)
  static double _calculateChordDuration(Chord chord, List<String> warnings) {
    final baseValue = _calculateBaseValue(chord.duration.type);
    return _applyModifiers(baseValue, chord.duration, warnings);
  }

  /// Calculates duração de a tuplet (tuplet)
  ///
  /// Fórmula: Duração = (Soma das notes internas) × (normalNotes / actualNotes)
  ///
  /// Examples:
  /// - Tercina (3:2): 3 colcheias no tempo de 2 → each a vale 2/3 of the value original
  /// - Quintina (5:4): 5 semicolcheias no tempo de 4 → each a vale 4/5 of the value original
  ///
  /// The ratio itself comes from [TupletValidator.ratioModifier] (guarded
  /// against a zero/negative `actualNotes`), so tuplet arithmetic lives in a
  /// single place. Nested tuplets are handled recursively: their own ratio is
  /// applied before the outer one.
  ///
  /// Inconsistencies of the tuplet (wrong element count, irrational or
  /// implausible ratio) are *not* reported here; they are collected by
  /// [TupletValidator.describeProblems] while scanning the measure.
  static double _calculateTupletDuration(Tuplet tuplet, List<String> warnings) {
    // Somar duração de all os elementos within of the tuplet
    double totalInternalDuration = 0.0;

    for (final element in tuplet.elements) {
      if (element is Note) {
        final baseValue = _calculateBaseValue(element.duration.type);
        totalInternalDuration +=
            _applyModifiers(baseValue, element.duration, warnings);
      } else if (element is Rest) {
        final baseValue = _calculateBaseValue(element.duration.type);
        totalInternalDuration +=
            _applyModifiers(baseValue, element.duration, warnings);
      } else if (element is Chord) {
        final baseValue = _calculateBaseValue(element.duration.type);
        totalInternalDuration +=
            _applyModifiers(baseValue, element.duration, warnings);
      } else if (element is Tuplet) {
        // Nested tuplet: its inner ratio is applied by the recursive call.
        totalInternalDuration += _calculateTupletDuration(element, warnings);
      }
    }

    // aplicar proporção of the tuplet
    // Example: Tercina (3:2) = 3 notes ocupam tempo de 2
    // Então: duração_real = duração_nominal × (2/3)
    return totalInternalDuration *
        TupletValidator.ratioModifier(tuplet.actualNotes, tuplet.normalNotes);
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

    // Detectar excesso de figures pequenas
    int smallNotesCount = 0;
    for (final element in measure.allElements) {
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

  /// Validates every bar of [staff] against the meter IN FORCE for it, which
  /// for a bar that declares none is the meter declared by an earlier bar.
  ///
  /// Use this rather than calling [validate] bar by bar. [validate] can only
  /// see what one [Measure] carries, and since ADR-005 action item 8 the layout
  /// no longer stamps the inherited meter onto the caller's `Measure`: writing
  /// there made `Measure.add` throw for an element it had accepted moments
  /// earlier, so rendering a score changed whether a public method threw.
  /// Measured before that fix, on a two-bar staff whose bar 2 declares no meter
  /// and holds four quarters under an inherited 4/4 — a fifth quarter was
  /// accepted before `LayoutEngine.layout()` and threw
  /// `MeasureCapacityException` after it.
  ///
  /// The inheritance is therefore derived HERE, per call, and nothing is
  /// written back. The rule is the same one
  /// `LayoutEngine._resolveInheritedTimeSignatures` applies, so the two cannot
  /// disagree:
  ///
  /// * a meter declared IN the staff always wins, and stays in force until the
  ///   next declaration;
  /// * [Measure.inheritedTimeSignature] is an author-supplied hint that only
  ///   SEEDS the walk — it is honoured while nothing has been declared yet and
  ///   ignored afterwards. That seed is what lets a `GrandStaffPainter`
  ///   sub-staff validate at all: such a staff starts mid-score, so the meter
  ///   it runs under was declared in a bar the sub-staff does not contain.
  ///
  /// This used to read `_findTimeSignature(measure)` per bar instead, which
  /// let a stale hint on bar 5 override the 4/4 the staff declared in bar 1.
  ///
  /// A bar before the staff's first meter is reported through [validate], i.e.
  /// valid with the "no time signature" warning, instead of the hard
  /// "Compasso sem fórmula de compasso definida" error the previous version
  /// produced for it. [allowAnacrusis] applies to bar 0 only, matching layout.
  static List<MeasureValidationResult> validateStaff(
    Staff staff, {
    bool allowAnacrusis = false,
  }) {
    final results = <MeasureValidationResult>[];
    TimeSignature? running;

    for (int i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      final declaredHere = measure.timeSignature;
      if (declaredHere != null) {
        running = declaredHere;
      } else {
        running ??= measure.inheritedTimeSignature;
      }

      results.add(
        running == null
            ? validate(measure, allowAnacrusis: allowAnacrusis && i == 0)
            : validateWithTimeSignature(
                measure,
                running,
                allowAnacrusis: allowAnacrusis && i == 0,
              ),
      );
    }

    return results;
  }
  
  /// Validation: with TimeSignature explícito (útil for inheritance)
  ///
  /// This is the entry point used by `LayoutEngine`. It is voice aware: the
  /// reported [MeasureValidationResult.actualDuration] is the longest voice,
  /// so a legal two-voice bar is no longer reported as "twice too long".
  ///
  /// Equivalent to `validateVoiceAware(...).toResult()`.
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

    return validateVoiceAware(
      measure,
      timeSignature,
      allowAnacrusis: allowAnacrusis,
    ).toResult();
  }

  /// Full, voice-aware validation of [measure].
  ///
  /// [timeSignature] may be `null`, in which case it is looked up in the
  /// measure (including the signature inherited by `LayoutEngine`); when none
  /// can be found the returned [MeasureValidation] has
  /// [MeasureValidation.hasTimeSignature] `false` and reports no problem.
  ///
  /// [allowAnacrusis] tolerates voices that are *shorter* than the bar (pickup
  /// bars); voices that overflow are always reported.
  ///
  /// [barNumber] is only used to prefix the messages; when omitted
  /// `Measure.number` is used, and when that is `null` too the messages carry
  /// no bar prefix.
  ///
  /// Used by [validateWithTimeSignature] (and therefore by `LayoutEngine`) and
  /// by [describeProblems].
  static MeasureValidation validateVoiceAware(
    Measure measure,
    TimeSignature? timeSignature, {
    bool allowAnacrusis = false,
    int? barNumber,
  }) {
    final ts = timeSignature ?? _findTimeSignature(measure);
    final number = barNumber ?? measure.number;

    if (ts == null) {
      return MeasureValidation._(
        hasTimeSignature: false,
        barNumber: number,
        numerator: 0,
        denominator: 0,
        expectedCapacity: 0.0,
        allowAnacrusis: allowAnacrusis,
        voiceDurations: const {},
        elementBreakdown: const {},
        problems: const [],
        warnings: const [
          'Compasso sem fórmula de compasso - validação ignorada',
        ],
      );
    }

    final expectedCapacity =
        _calculateMeasureCapacity(ts.numerator, ts.denominator);
    final scan = _scan(measure, ts);
    final prefix = number != null ? 'bar $number: ' : '';
    final meter = '${ts.numerator}/${ts.denominator}';
    final capacity = _format(expectedCapacity);

    final problems = <String>[];
    if (ts.isFreeTime) {
      // Free time (chant, cadenzas): the bar has no metric capacity, so no
      // rhythmic verdict is possible — only tuplet consistency is checked.
    } else if (scan.voiceDurations.isEmpty) {
      if (!allowAnacrusis && expectedCapacity > tolerance) {
        problems.add(
          '$prefix$meter holds $capacity but the measure is empty; '
          'add notes or a full-bar rest.',
        );
      }
    } else {
      // One message per voice: a voice is an independent, parallel line, so
      // each one has to fill the bar on its own.
      final voices = scan.voiceDurations.keys.toList()..sort();
      for (final voice in voices) {
        final sum = scan.voiceDurations[voice]!;
        final difference = sum - expectedCapacity;
        if (difference.abs() < tolerance) continue;
        if (difference > 0) {
          problems.add(
            '$prefix$meter holds $capacity but voice $voice sums '
            '${_format(sum)} (${_format(difference)} too much); '
            'remove figures or move them to the next bar.',
          );
        } else if (!allowAnacrusis) {
          problems.add(
            '$prefix$meter holds $capacity but voice $voice sums '
            '${_format(sum)} (${_format(-difference)} missing); '
            'add notes or rests.',
          );
        }
      }
    }

    // Tuplet inconsistencies detected by TupletValidator are reported next to
    // the rhythmic ones — an unreadable 5:4 is just as actionable.
    for (final tupletProblem in scan.tupletProblems) {
      problems.add('$prefix$tupletProblem');
    }

    final warnings = <String>[...scan.warnings];
    _performAdditionalValidations(measure, ts, warnings, <String>[]);

    return MeasureValidation._(
      hasTimeSignature: true,
      isFreeTime: ts.isFreeTime,
      barNumber: number,
      numerator: ts.numerator,
      denominator: ts.denominator,
      expectedCapacity: expectedCapacity,
      allowAnacrusis: allowAnacrusis,
      voiceDurations: Map.unmodifiable(scan.voiceDurations),
      elementBreakdown: Map.unmodifiable(scan.elementBreakdown),
      problems: List.unmodifiable(problems),
      warnings: List.unmodifiable(warnings),
      tupletProblems: List.unmodifiable(scan.tupletProblems),
    );
  }

  /// Actionable, one-sentence descriptions of everything wrong with [measure].
  ///
  /// Returns an empty list for a well formed bar. Example output:
  ///
  /// ```text
  /// bar 4: 4/4 holds 1.0 but voice 2 sums 1.25 (0.25 too much); remove figures or move them to the next bar.
  /// bar 4: tuplet 3 declares 3:2 but contains 4 rhythmic elements; set actualNotes to 4 or fix its contents.
  /// ```
  ///
  /// This is the readable face of [validateVoiceAware]: rhythmic mismatches
  /// are reported per voice and tuplet inconsistencies come straight from
  /// [TupletValidator.describeProblems].
  static List<String> describeProblems(
    Measure measure,
    TimeSignature? timeSignature, {
    bool allowAnacrusis = false,
    int? barNumber,
  }) {
    return validateVoiceAware(
      measure,
      timeSignature,
      allowAnacrusis: allowAnacrusis,
      barNumber: barNumber,
    ).problems;
  }

  /// Problems of every bar of [staff], with inherited time signatures.
  ///
  /// Bars are numbered from 1 (or by `Measure.number` when set) so the
  /// messages point at a real bar of the score.
  static List<String> describeStaffProblems(
    Staff staff, {
    bool allowAnacrusis = false,
  }) {
    final problems = <String>[];
    TimeSignature? current;
    for (var i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      current = _findTimeSignature(measure) ?? current;
      problems.addAll(
        describeProblems(
          measure,
          current,
          allowAnacrusis: allowAnacrusis && i == 0,
          barNumber: measure.number ?? (i + 1),
        ),
      );
    }
    return problems;
  }

  /// Walks a measure once, accumulating per-voice sums, a per-element
  /// breakdown, rhythmic warnings and tuplet inconsistencies.
  ///
  /// Shared by every entry point of this class so that there is exactly one
  /// definition of "how long is this bar".
  static _MeasureScan _scan(Measure measure, TimeSignature? timeSignature) {
    final scan = _MeasureScan();

    // Pre-pass: only disambiguate the breakdown labels by voice when the bar
    // really is polyphonic (keeps single-voice labels stable).
    final voicesSeen = <int>{};
    for (final element in measure.allElements) {
      if (Measure.musicalValueOf(element) > 0) {
        voicesSeen.add(Measure.voiceNumberOf(element));
      }
    }
    final polyphonic = voicesSeen.length > 1;

    var elementIndex = 0;
    for (final element in measure.allElements) {
      double duration;
      String label;

      if (element is Note) {
        duration = _calculateNoteDuration(element, scan.warnings);
        label = 'Nota ${elementIndex + 1} (${element.duration.type.name})';
      } else if (element is Rest) {
        duration = _calculateRestDuration(element, scan.warnings);
        label = 'Pausa ${elementIndex + 1} (${element.duration.type.name})';
      } else if (element is Chord) {
        duration = _calculateChordDuration(element, scan.warnings);
        label = 'Acorde ${elementIndex + 1} (${element.duration.type.name})';
      } else if (element is Tuplet) {
        // Critical: the actual:normal ratio has to be applied, otherwise every
        // bar containing a tuplet is reported as too long.
        duration = _calculateTupletDuration(element, scan.warnings);
        label = 'Tuplet ${elementIndex + 1} '
            '(${element.actualNotes}:${element.normalNotes})';
        scan.tupletProblems.addAll(
          TupletValidator.describeProblems(
            element,
            timeSignature: timeSignature,
            label: 'tuplet ${elementIndex + 1}',
          ),
        );
      } else {
        // Clefs, key signatures, barlines… occupy no musical time.
        continue;
      }

      final voice = Measure.voiceNumberOf(element);
      scan.voiceDurations[voice] = (scan.voiceDurations[voice] ?? 0.0) + duration;
      scan.elementBreakdown[polyphonic ? '$label [voz $voice]' : label] =
          duration;
      elementIndex++;
    }

    return scan;
  }

  /// Compact, stable rendering of a rhythmic value for the messages
  /// (`1.0`, `0.25`, `1.3333`) — never scientific notation, never 16 digits.
  static String _format(double value) {
    final rounded = double.parse(value.toStringAsFixed(4));
    if (rounded == rounded.roundToDouble()) {
      return rounded.toStringAsFixed(1);
    }
    return rounded
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '.0');
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

/// Accumulator used by `MeasureValidator._scan` while walking a measure.
class _MeasureScan {
  /// Rhythmic value written in each voice, keyed by voice number.
  final Map<int, double> voiceDurations = <int, double>{};

  /// Duration contributed by each element, for human readable reports.
  final Map<String, double> elementBreakdown = <String, double>{};

  /// Notation warnings raised while measuring (unusual dot counts, …).
  final List<String> warnings = <String>[];

  /// Tuplet inconsistencies found by `TupletValidator`, without a bar prefix.
  final List<String> tupletProblems = <String>[];
}

/// Voice-aware validation of one measure, with actionable messages.
///
/// **Where this is used**
///
/// Produced by [MeasureValidator.validateVoiceAware]; [MeasureValidator
/// .describeProblems] returns just its [problems] and
/// [MeasureValidator.validateWithTimeSignature] — the entry point called by
/// `LayoutEngine` for every bar — returns [toResult].
///
/// Unlike the legacy [MeasureValidationResult], this class keeps the value of
/// **each voice**: voices sound in parallel, so a bar is well formed when
/// every voice fills it, not when their sum does.
class MeasureValidation {
  /// Whether a time signature could be resolved for the measure.
  ///
  /// When `false` nothing was validated: [problems] is empty and [isValid] is
  /// `true` (a bar without a meter cannot be wrong).
  final bool hasTimeSignature;

  /// The bar is in free time (chant, cadenza): it has no metric capacity, so
  /// no rhythmic verdict is issued and [isRhythmicallyComplete] is `true`.
  final bool isFreeTime;

  /// Bar number used to prefix the messages (`null` = no prefix).
  final int? barNumber;

  /// Numerator of the time signature used (0 when [hasTimeSignature] is false).
  final int numerator;

  /// Denominator of the time signature used (0 when there is none).
  final int denominator;

  /// Rhythmic value each voice must reach, in whole notes (4/4 → 1.0).
  final double expectedCapacity;

  /// Whether voices shorter than the bar were tolerated (pickup bar).
  final bool allowAnacrusis;

  /// Rhythmic value written in each voice, keyed by voice number.
  final Map<int, double> voiceDurations;

  /// Duration contributed by each element (`'Nota 1 (quarter)' -> 0.25`).
  final Map<String, double> elementBreakdown;

  /// Actionable, one-sentence descriptions of what is wrong. Empty = fine.
  final List<String> problems;

  /// Notation advice that does not make the bar invalid (compound-meter
  /// grouping, irregular meters, unusual dot counts, …).
  final List<String> warnings;

  /// Tuplet inconsistencies, unprefixed (also present, prefixed, in
  /// [problems]).
  final List<String> tupletProblems;

  const MeasureValidation._({
    required this.hasTimeSignature,
    required this.barNumber,
    this.isFreeTime = false,
    required this.numerator,
    required this.denominator,
    required this.expectedCapacity,
    required this.allowAnacrusis,
    required this.voiceDurations,
    required this.elementBreakdown,
    required this.problems,
    required this.warnings,
    this.tupletProblems = const [],
  });

  /// No problem was found (honours [allowAnacrusis]).
  bool get isValid => problems.isEmpty;

  /// Rhythmic value of the bar: the **longest** voice (0.0 when empty).
  ///
  /// Same definition as `Measure.currentMusicalValue`.
  double get actualDuration {
    var longest = 0.0;
    for (final value in voiceDurations.values) {
      if (value > longest) longest = value;
    }
    return longest;
  }

  /// [actualDuration] minus [expectedCapacity] (positive = bar too long).
  double get difference => actualDuration - expectedCapacity;

  /// Every voice — including the longest one — exactly fills the bar.
  ///
  /// This is the strict rhythmic verdict, independent of [allowAnacrusis] and
  /// of tuplet inconsistencies; it is what [toResult] reports as
  /// `MeasureValidationResult.isValid`.
  bool get isRhythmicallyComplete {
    if (!hasTimeSignature || isFreeTime) return true;
    if (voiceDurations.isEmpty) {
      return expectedCapacity.abs() < MeasureValidator.tolerance;
    }
    for (final value in voiceDurations.values) {
      if ((value - expectedCapacity).abs() >= MeasureValidator.tolerance) {
        return false;
      }
    }
    return true;
  }

  /// Voices whose content exceeds the bar.
  List<int> get overfullVoices => _voicesWhere((v) => v > expectedCapacity);

  /// Voices that do not reach the end of the bar.
  List<int> get incompleteVoices => _voicesWhere((v) => v < expectedCapacity);

  List<int> _voicesWhere(bool Function(double) test) {
    final result = <int>[];
    if (!hasTimeSignature || isFreeTime) return result;
    voiceDurations.forEach((voice, value) {
      if ((value - expectedCapacity).abs() >= MeasureValidator.tolerance &&
          test(value)) {
        result.add(voice);
      }
    });
    result.sort();
    return result;
  }

  /// Rhythmic value written in [voice] (0.0 when the voice is empty).
  double durationOfVoice(int voice) => voiceDurations[voice] ?? 0.0;

  /// Bridges to the legacy [MeasureValidationResult] consumed by
  /// `LayoutEngine`, keeping its Portuguese error messages.
  MeasureValidationResult toResult() {
    final valid = isRhythmicallyComplete;
    final errors = <String>[];
    if (!valid && !allowAnacrusis) {
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
      // Incomplete inner voices do not move `difference` (which looks at the
      // longest voice), so spell them out explicitly.
      for (final voice in incompleteVoices) {
        errors.add(
          'Voz $voice tem ${durationOfVoice(voice).toStringAsFixed(4)} de '
          '${expectedCapacity.toStringAsFixed(4)} unidades.',
        );
      }
    }

    return MeasureValidationResult(
      isValid: valid,
      expectedCapacity: expectedCapacity,
      actualDuration: actualDuration,
      difference: difference,
      numerator: numerator,
      denominator: denominator,
      warnings: [...warnings, ...tupletProblems],
      errors: errors,
      elementBreakdown: elementBreakdown,
      voiceDurations: voiceDurations,
    );
  }

  /// Multi-line, human readable report (problems first, then warnings).
  String describe() {
    final buffer = StringBuffer();
    final label = barNumber != null ? 'bar $barNumber' : 'measure';
    buffer.writeln(
      '$label — $numerator/$denominator: ${isValid ? "ok" : "${problems.length} problem(s)"}',
    );
    for (final problem in problems) {
      buffer.writeln('  ✗ $problem');
    }
    for (final warning in warnings) {
      buffer.writeln('  ⚠️ $warning');
    }
    return buffer.toString();
  }

  @override
  String toString() =>
      'MeasureValidation($numerator/$denominator, voices: $voiceDurations, '
      'problems: ${problems.length})';
}
