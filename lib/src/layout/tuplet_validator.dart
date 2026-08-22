// lib/src/layout/tuplet_validator.dart

import '../../core/core.dart';

/// Tuplet rules from music theory (ratios, note values, beam counts).
///
/// **Where this is used**
///
/// This class is the single source of truth for the `actual:normal` ratio
/// arithmetic of a [Tuplet]. It is consumed by:
///
/// * [MeasureValidator] (`lib/src/layout/measure_validator.dart`), which calls
///   [getModifiedDuration] when it measures how much rhythmic time a tuplet
///   occupies inside a bar, and [describeProblems] to surface tuplet
///   inconsistencies through `MeasureValidator.describeProblems`.
/// * `MeasureValidator` is itself called by `LayoutEngine.layout*`
///   (`lib/src/layout/layout_engine.dart`) for every measure it lays out.
///
/// Everything here is pure arithmetic on plain `int`/`double` values so that it
/// can be unit tested without a Flutter binding.
///
/// See also: `Measure.musicalValueOf`, which applies the very same
/// `normalNotes / actualNotes` ratio when a measure reports its own capacity.
class TupletValidator {
  /// Tolerância for comparações de point flutuante.
  ///
  /// [MeasureValidator.tolerance] aliases this constant so that the two
  /// validators never disagree about what "the same duration" means.
  static const double epsilon = 0.0001;

  /// Valida a razão of the tuplet with base no tempo
  /// 
  /// Regras:
  /// - Tempo simples: numerator > denominator (tuplets contraentes)
  ///   Exceção: dupletos (2:3) are raros mas válidos
  /// - Tempo composto: ambos numerator < denominator (expansivas) 
  ///   and numerator > denominator (contraentes) are válidos
  static bool validateRatio(int numerator, int denominator, TimeSignature? timeSig) {
    if (timeSig == null) return true; // Sem contexto, aceitar
    
    if (timeSig.isSimple) {
      // Tempo simples: numerator > denominator (exceto dupletos)
      if (numerator == 2 && denominator == 3) return true; // Dupleto raro
      return numerator > denominator;
    } else {
      // Tempo composto: ambos tipos are válidos
      return true;
    }
  }
  
  /// Calculates a duração total that a tuplet ocupa
  /// 
  /// Fórmula:
  /// - Duração de a note × numerator = duração total before of the modificação
  /// - Modificador = denominator / numerator
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
  
  /// Calculates a duração modificada de each note within of the tuplet
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
  /// Regra Generatesl: Use a próxima divisão natural (potência de 2) below the numerator
  /// 
  /// Exceção: Dupletos in tempo composto use value Above
  /// 
  /// Examples:
  /// - Tercina (3): Use divisão de 2 → colcheias
  /// - Quintina (5): Use divisão de 4 → semicolcheias
  /// - Septina (7): Use divisão de 4 → semicolcheias
  /// - Nontupleto (9): Use divisão de 8 → fUsess
  static int determineNoteValue(
    int numerator,
    int denominator,
    TimeSignature? timeSig,
  ) {
    // Exceção: Dupleto in tempo composto
    if (isDupletInCompoundMeter(numerator, denominator, timeSig)) {
      // Use value above (divisão de 3)
      return 3;
    }
    
    // Regra Generatesl: Use potência de 2 below the numerator
    return getPowerOf2Below(numerator);
  }
  
  /// Checks if is a dupleto in tempo composto
  static bool isDupletInCompoundMeter(
    int numerator,
    int denominator,
    TimeSignature? timeSig,
  ) {
    if (timeSig == null) return false;
    return numerator == 2 && denominator == 3 && timeSig.isCompound;
  }
  
  /// Returns a potência de 2 more próxima below de n
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
  
  /// Determina o number de brackets de beam based no number de notes
  /// 
  /// Regra de Gould:
  /// - Until 3 notes: 1 bracket (colcheias)
  /// - 4-7 notes: 2 brackets (semicolcheias)
  /// - 8-15 notes: 3 brackets (fUsess)
  /// - 16-31 notes: 4 brackets (semifUsess)
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
  
  /// Checks if a tuplet is irracional
  /// (denominator not is potência de 2 or 3)
  ///
  /// Examples irracionais: 7:5, 11:7, 5:3
  static bool isIrrational(int denominator) {
    return TupletNumber.isIrrational(denominator);
  }

  /// The factor that converts the *written* duration of the notes inside
  /// [actualNotes]:[normalNotes] into the duration they really occupy.
  ///
  /// `3:2` (a triplet) returns `2/3`: three written eighths sound in the time
  /// of two. Returns `1.0` for a malformed ratio (`actualNotes <= 0`) so that
  /// callers degrade to the written duration instead of dividing by zero.
  ///
  /// This is the same arithmetic as [getModifiedDuration]; that method takes
  /// loose ints, this one is the guarded version used by [MeasureValidator].
  static double ratioModifier(int actualNotes, int normalNotes) {
    if (actualNotes <= 0 || normalNotes <= 0) return 1.0;
    return normalNotes / actualNotes;
  }

  /// Counts the elements of [tuplet] that actually carry rhythmic time.
  ///
  /// Notes, rests, chords and nested tuplets count; clefs, barlines and other
  /// time-less elements do not. A well formed tuplet declares `actualNotes`
  /// equal to this count.
  static int countRhythmicElements(Tuplet tuplet) {
    var count = 0;
    for (final element in tuplet.elements) {
      if (Measure.musicalValueOf(element) > 0) count++;
    }
    return count;
  }

  /// Actionable descriptions of everything that looks wrong with [tuplet].
  ///
  /// Returns an empty list when the tuplet is well formed. Each entry is a
  /// single human readable sentence, prefixed with [label] when one is given
  /// (`MeasureValidator` passes something like `bar 4: tuplet 2`), e.g.:
  ///
  /// ```text
  /// bar 4: tuplet 2 declares 3:2 but contains 4 rhythmic elements
  /// ```
  ///
  /// [timeSignature] is optional context: when it is supplied the ratio is
  /// additionally checked against simple/compound meter via [validateRatio].
  /// When it is `null` the tuplet's own [Tuplet.timeSignature] is used.
  ///
  /// Called by `MeasureValidator.describeProblems`; safe to call directly.
  static List<String> describeProblems(
    Tuplet tuplet, {
    TimeSignature? timeSignature,
    String? label,
  }) {
    final problems = <String>[];
    final prefix = (label == null || label.isEmpty) ? 'tuplet' : label;
    final actual = tuplet.actualNotes;
    final normal = tuplet.normalNotes;

    if (actual <= 0 || normal <= 0) {
      problems.add(
        '$prefix has an impossible ratio $actual:$normal; '
        'both sides must be positive.',
      );
      // Nothing else can be checked with a broken ratio.
      return problems;
    }

    final rhythmicCount = countRhythmicElements(tuplet);
    if (rhythmicCount != actual) {
      problems.add(
        '$prefix declares $actual:$normal but contains $rhythmicCount '
        'rhythmic element${rhythmicCount == 1 ? '' : 's'}; '
        'set actualNotes to $rhythmicCount or fix its contents.',
      );
    }

    final ts = timeSignature ?? tuplet.timeSignature;
    if (ts != null && !validateRatio(actual, normal, ts)) {
      problems.add(
        '$prefix uses ratio $actual:$normal in ${ts.numerator}/'
        '${ts.denominator} (simple time), where tuplets are normally '
        'contracting ($actual should be greater than $normal).',
      );
    }

    if (isIrrational(normal)) {
      problems.add(
        '$prefix is irrational ($actual:$normal): $normal is neither a power '
        'of two nor a multiple of three, so the ratio has no plain note value.',
      );
    }

    if (actual > 7) {
      problems.add(
        '$prefix groups $actual notes, which is unusual; '
        'check the ratio or split the group.',
      );
    }

    return problems;
  }
}
