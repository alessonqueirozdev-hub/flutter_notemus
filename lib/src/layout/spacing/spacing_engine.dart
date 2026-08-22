/// Motor principal de intelligent spacing.
///
/// # Production path vs. analysis path
///
/// This class has two clearly separated halves. Read this before adding tests:
/// a green test that only exercises the second half proves nothing about what
/// the renderer draws.
///
/// **Production path** — the single source of truth for the horizontal
/// rhythmic law used by `LayoutEngine`:
///   * [interNoteSpacing] — Gould's square-root law, COMPUTED (never looked up
///     from a partial table), normalised to the quarter note.
///   * [opticalAdjustment] — context-sensitive optical compensation, added on
///     top of the base gap. Returns `0.0` when disabled in the preferences.
///   * [durationShapeFactor] — the bare model factor behind [interNoteSpacing].
///
/// **Analysis path** — offline/diagnostic tooling that the renderer does NOT
/// call: [analyzeMeasure] (a measurement report), plus the dual-algorithm
/// experiment [computeTextualSpacing] / [computeDurationalSpacing] /
/// [combineSpacings] / [applyOpticalCompensation].
library;

import 'dart:math';

import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter_notemus/core/core.dart'
    show Chord, Duration, DurationType, MusicalElement, Note, Rest;

import 'collision_detector.dart';
import 'optical_compensation.dart';
import 'spacing_model.dart';
import 'spacing_preferences.dart';
import 'spacing_result.dart';

/// Spacing engine inteligente
///
/// Processes measures in nível de system (not individual) for ensure
/// consistência de spacing according to a Regra Dourada de Gould.
class IntelligentSpacingEngine {
  /// Default base gap between two consecutive quarter notes, in staff spaces.
  ///
  /// Mirrors `LayoutEngine.noteMinSpacing`. Kept as a named constant so the
  /// engine and the layout cannot drift apart silently.
  static const double defaultBaseSpacing = 3.5;

  /// Preferences de spacing
  final SpacingPreferences preferences;

  /// Calculatora de durational spacing (analysis path — applies
  /// [SpacingPreferences.spacingFactor]).
  late final SpacingCalculator _calculator;

  /// Model shape evaluator with a UNIT ratio.
  ///
  /// Production spacing must not be multiplied by
  /// [SpacingPreferences.spacingFactor] a second time: the base gap already
  /// carries the global scale. This calculator therefore returns the pure
  /// shape of the configured [SpacingModel].
  late final SpacingCalculator _shapeCalculator;

  /// Compensador óptico
  OpticalCompensator? _compensator;

  IntelligentSpacingEngine({this.preferences = SpacingPreferences.normal}) {
    _calculator = SpacingCalculator(
      model: preferences.model,
      spacingRatio: preferences.spacingFactor,
    );
    _shapeCalculator = SpacingCalculator(
      model: preferences.model,
      spacingRatio: 1.0,
    );
  }

  /// Initialises o compensador óptico with staff space
  void initializeOpticalCompensator(double staffSpace) {
    _compensator = OpticalCompensator(
      staffSpace: staffSpace,
      enabled: preferences.enableOpticalSpacing,
      intensity: 1.0,
    );
  }

  // ===========================================================================
  // PRODUCTION PATH
  // ===========================================================================

  /// Horizontal gap to leave before an element, given the element that
  /// precedes it. **This is the rhythmic law of the engraver.**
  ///
  /// ```text
  /// factor  = shape(previousDuration.absoluteValue / DurationType.quarter.value)
  /// spacing = baseSpacing * factor * staffSpace
  /// spacing = spacing * restSpacingRatio      // only when previousIsRest
  /// ```
  ///
  /// With the default [SpacingModel.squareRoot] the shape is `sqrt(t)`, i.e.
  /// Gould's square-root law. The factor is **computed**, never looked up:
  /// a table that only covered `whole`..`sixtyFourth` and fell back to `1.0`
  /// inverted the rhythmic proportion at both ends of the range (a breve was
  /// spaced like a quarter — narrower than a whole note — and a 128th got more
  /// space than a 64th). Being computed, all 15 [DurationType] values from
  /// [DurationType.maxima] to [DurationType.twoThousandFortyEighth] are
  /// covered, and augmentation dots are honoured because
  /// [Duration.absoluteValue] includes them.
  ///
  /// Reference values with `staffSpace = 1` and `baseSpacing = 3.5`:
  ///
  /// | previous duration | factor | spacing |
  /// |---|---|---|
  /// | breve   | 2.828 | 9.90 |
  /// | whole   | 2.0   | 7.00 |
  /// | half    | 1.414 | 4.95 |
  /// | quarter | 1.0   | 3.50 |
  /// | eighth  | 0.707 | 2.47 |
  /// | 16th    | 0.5   | 1.75 |
  ///
  /// A configured model other than [SpacingModel.squareRoot] is respected, but
  /// the default reproduces the shipped layout bit for bit.
  ///
  /// Pure function: no state is read or written. Callers add their own
  /// accidental lead-in, lyric overhang, anti-collision floor and per-measure
  /// compression scale on top of this value.
  ///
  /// - [previousDuration]: written duration of the preceding note/rest/chord.
  /// - [previousIsRest]: `true` when the preceding element is a rest, which
  ///   Gould spaces at ~80% of an equivalent note
  ///   ([SpacingPreferences.restSpacingRatio]).
  /// - [staffSpace]: one staff space in pixels.
  /// - [baseSpacing]: gap between two quarter notes, in staff spaces.
  double interNoteSpacing({
    required Duration previousDuration,
    required bool previousIsRest,
    required double staffSpace,
    double baseSpacing = defaultBaseSpacing,
  }) {
    final double factor = durationShapeFactor(previousDuration);
    double spacing = baseSpacing * factor * staffSpace;

    if (previousIsRest) {
      spacing *= preferences.restSpacingRatio;
    }

    return spacing;
  }

  /// The dimensionless spacing factor of [duration], normalised so that a
  /// quarter note yields `1.0` under [SpacingModel.squareRoot].
  ///
  /// Defined for every [DurationType] (`maxima`..`2048th`) and for any number
  /// of augmentation dots. Never negative: the logarithmic model would
  /// otherwise go below zero for very short values.
  double durationShapeFactor(Duration duration) {
    final double absolute = duration.absoluteValue;
    if (absolute <= 0) return 0.0;

    final double factor = _shapeCalculator.calculateSpace(
      absolute,
      DurationType.quarter.value,
    );
    return factor > 0.0 ? factor : 0.0;
  }

  /// Context-sensitive optical compensation to ADD to the base gap returned by
  /// [interNoteSpacing], in pixels.
  ///
  /// Implements the rules of [OpticalCompensator] (alternating stems, rest
  /// before a stem-up note, duration transitions, accidentals, augmentation
  /// dots, beamed neighbours). Returns `0.0` when
  /// [SpacingPreferences.enableOpticalSpacing] is `false`, when there is no
  /// preceding element, or when either element is not a rhythmic symbol
  /// (clef, barline, …) — those carry their own dedicated spacing.
  ///
  /// [previousStemUp] / [currentStemUp] are optional because stem direction is
  /// a layout decision that the core model does not carry; when omitted the
  /// stem rule simply contributes nothing. [localDensity] defaults to
  /// [SpacingPreferences.densityPreference].
  ///
  /// The compensator is created lazily for [staffSpace] (and reused while the
  /// staff space does not change), so [initializeOpticalCompensator] is
  /// optional for this entry point.
  double opticalAdjustment({
    required MusicalElement? previous,
    required MusicalElement current,
    required double staffSpace,
    bool? previousStemUp,
    bool? currentStemUp,
    double? localDensity,
  }) {
    if (!preferences.enableOpticalSpacing) return 0.0;
    if (previous == null) return 0.0;

    final OpticalContext? previousContext = _opticalContextFor(
      previous,
      previousStemUp,
    );
    final OpticalContext? currentContext = _opticalContextFor(
      current,
      currentStemUp,
    );
    if (previousContext == null || currentContext == null) return 0.0;

    final OpticalCompensator compensator = _compensatorFor(staffSpace);
    if (!compensator.enabled) return 0.0;

    return compensator.calculateCompensation(
      previousContext,
      currentContext,
      localDensity: localDensity ?? preferences.densityPreference,
    );
  }

  /// Measures one measure with the production law and reports the result.
  ///
  /// This is the **analysis** entry point: it answers "how wide would this
  /// measure be, and does anything collide?" without mutating anything and
  /// without being part of the render pass. It is built on the very same
  /// [interNoteSpacing]/[opticalAdjustment] used in production, so its numbers
  /// track the renderer instead of describing a parallel universe.
  ///
  /// Non-rhythmic elements (clefs, barlines, …) are skipped — their spacing is
  /// owned by the layout engine, not by the rhythmic law.
  SpacingResult analyzeMeasure({
    required List<MusicalElement> elements,
    required double staffSpace,
    double baseSpacing = defaultBaseSpacing,
  }) {
    final List<ElementSpacing> placed = <ElementSpacing>[];
    final List<Rect> boxes = <Rect>[];

    double cursor = 0.0;
    double shortest = double.infinity;
    MusicalElement? previous;
    Duration? previousDuration;

    final double staffHeight = staffSpace * 4.0;

    for (int i = 0; i < elements.length; i++) {
      final MusicalElement element = elements[i];
      final Duration? duration = _rhythmicDurationOf(element);
      if (duration == null) continue;

      final double value = duration.absoluteValue;
      if (value > 0 && value < shortest) shortest = value;

      double gap = 0.0;
      if (previousDuration != null) {
        gap = interNoteSpacing(
          previousDuration: previousDuration,
          previousIsRest: previous is Rest,
          staffSpace: staffSpace,
          baseSpacing: baseSpacing,
        );
        gap += opticalAdjustment(
          previous: previous,
          current: element,
          staffSpace: staffSpace,
        );
        if (gap < 0.0) gap = 0.0;
      }

      cursor += gap;

      final double width =
          TimeSlice.estimateAdvanceWidthInStaffSpaces(element) * staffSpace;

      placed.add(
        ElementSpacing(
          index: i,
          element: element,
          xPosition: cursor,
          leadingGap: gap,
          width: width,
        ),
      );
      boxes.add(Rect.fromLTWH(cursor, 0.0, width, staffHeight));

      previous = element;
      previousDuration = duration;
    }

    final List<CollisionPair> collisions = const CollisionDetector()
        .detectAllCollisions(boxes);

    final double totalWidth = placed.isEmpty
        ? 0.0
        : placed.last.xPosition + placed.last.width;

    return SpacingResult(
      elements: placed,
      shortestDuration: shortest.isFinite ? shortest : 0.0,
      totalWidth: totalWidth,
      collisions: collisions,
    );
  }

  /// Written duration of a rhythmic element, or `null` for anything else.
  static Duration? _rhythmicDurationOf(MusicalElement? element) {
    if (element is Note) return element.duration;
    if (element is Chord) return element.duration;
    if (element is Rest) return element.duration;
    return null;
  }

  /// Lazily builds (and caches) the compensator for [staffSpace].
  OpticalCompensator _compensatorFor(double staffSpace) {
    final OpticalCompensator? cached = _compensator;
    if (cached != null &&
        cached.staffSpace == staffSpace &&
        cached.enabled == preferences.enableOpticalSpacing) {
      return cached;
    }
    final OpticalCompensator created = OpticalCompensator(
      staffSpace: staffSpace,
      enabled: preferences.enableOpticalSpacing,
      intensity: 1.0,
    );
    _compensator = created;
    return created;
  }

  /// Maps a core [MusicalElement] onto an [OpticalContext].
  ///
  /// Returns `null` for elements the optical rules do not describe.
  OpticalContext? _opticalContextFor(MusicalElement element, bool? stemUp) {
    if (element is Note) {
      return OpticalContext(
        type: SymbolType.note,
        stemUp: stemUp,
        duration: element.duration.absoluteValue,
        hasAccidental: element.pitch.accidentalGlyph != null,
        isDotted: element.duration.dots > 0,
        beamCount: element.beam == null
            ? null
            : _beamCountFor(element.duration),
      );
    }
    if (element is Chord) {
      return OpticalContext(
        type: SymbolType.chord,
        stemUp: stemUp,
        duration: element.duration.absoluteValue,
        hasAccidental: element.notes.any(
          (note) => note.pitch.accidentalGlyph != null,
        ),
        isDotted: element.duration.dots > 0,
        beamCount: element.beam == null
            ? null
            : _beamCountFor(element.duration),
      );
    }
    if (element is Rest) {
      return OpticalContext(
        type: SymbolType.rest,
        duration: element.duration.absoluteValue,
        isDotted: element.duration.dots > 0,
      );
    }
    return null;
  }

  /// Number of beams/flags implied by [duration] (eighth = 1, 16th = 2, …).
  static int _beamCountFor(Duration duration) {
    final double value = duration.type.value;
    if (value > DurationType.eighth.value) return 0;

    int count = 0;
    double current = DurationType.eighth.value;
    while (current >= value && count < 16) {
      count++;
      current /= 2.0;
    }
    return count;
  }

  // ===========================================================================
  // ANALYSIS PATH — the dual-algorithm experiment.
  //
  // Nothing below is called by LayoutEngine. Kept because it documents the
  // MuseScore/Dorico dual approach and is useful for offline comparison, but
  // a passing test down here says nothing about rendered output.
  // ===========================================================================

  /// **ANALYSIS PATH — not used by the renderer.**
  ///
  /// Calculates textual spacing (anti-colisão)
  ///
  /// **Objetivo:** Avoid colisões de symbols, ignorando duração
  ///
  /// **Processo:**
  /// 1. Calculate width de each symbol
  /// 2. add padding mínimo between elementos adjacentes
  /// 3. processar symbols simultâneos in múltiplas staves
  ///
  /// **Returns:** List of positions with spacing denso and uniforme
  List<SymbolSpacing> computeTextualSpacing({
    required List<MusicalSymbolInfo> symbols,
    required double minGap,
    required double staffSpace,
  }) {
    final List<SymbolSpacing> positions = [];
    double currentX = 0.0;

    for (int i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];

      // Calculate width of the symbol
      double symbolWidth = _calculateSymbolWidth(symbol, staffSpace);

      // add padding mínimo
      double padding = minGap * staffSpace;

      // Ajustar for accidentals
      if (symbol.hasAccidental) {
        padding += _calculateAccidentalSpace(symbol, staffSpace);
      }

      positions.add(
        SymbolSpacing(
          symbolIndex: i,
          xPosition: currentX,
          width: symbolWidth,
          padding: padding,
        ),
      );

      currentX += symbolWidth + padding;
    }

    return positions;
  }

  /// **ANALYSIS PATH — not used by the renderer.** The production rhythmic law
  /// is [interNoteSpacing].
  ///
  /// Calculates durational spacing (proporcional to the tempo)
  ///
  /// **Objetivo:** Codificar relações temporais
  ///
  /// **Processo:**
  /// 1. Encontrar note more curta of the system
  /// 2. For each symbol: Calculate space based na duração until o next
  /// 3. Use modelo matemático (raiz quadrada recomendado)
  ///
  /// **Returns:** List of positions with spacing proporcional
  List<SymbolSpacing> computeDurationalSpacing({
    required List<MusicalSymbolInfo> symbols,
    required double shortestDuration,
    required double staffSpace,
  }) {
    final List<SymbolSpacing> positions = [];
    double currentX = 0.0;

    for (int i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];

      // Calculate space based na duração until o next symbol
      double durationForSpacing =
          symbol.duration ??
          (i < symbols.length - 1
              ? symbols[i + 1].musicalTime - symbol.musicalTime
              : shortestDuration);
      if (durationForSpacing <= 0) {
        durationForSpacing = shortestDuration;
      }

      // Calculate space using modelo matemático
      double space = _calculator.calculateSpace(
        durationForSpacing,
        shortestDuration,
      );
      space *= staffSpace; // Converter para pixels

      // PaUsess têm spacing reduzido (80%)
      if (symbol.isRest) {
        space *= preferences.restSpacingRatio;
      }

      positions.add(
        SymbolSpacing(
          symbolIndex: i,
          xPosition: currentX,
          width: space,
          padding: 0.0,
        ),
      );

      currentX += space;
    }

    return positions;
  }

  /// **ANALYSIS PATH — not used by the renderer.**
  ///
  /// Combina spacings textual and duracional adaptativamente
  ///
  /// **Algoritmo:**
  /// - If textual < target: Expand with guia duracional
  /// - If textual > target: Comprimir linearmente
  ///
  /// **Returns:** Spacing final combinado
  List<SymbolSpacing> combineSpacings({
    required List<SymbolSpacing> textual,
    required List<SymbolSpacing> durational,
    required double targetWidth,
  }) {
    final double textualWidth = textual.isEmpty
        ? 0.0
        : textual.last.xPosition + textual.last.width;

    if (textualWidth > targetWidth) {
      // Caso A: Compressão linear
      return _compressTextualSpacing(textual, targetWidth);
    } else {
      // Caso B: Expansão with guia duracional
      return _expandWithDurationalGuidance(textual, durational, targetWidth);
    }
  }

  /// Comprime textual spacing linearmente
  List<SymbolSpacing> _compressTextualSpacing(
    List<SymbolSpacing> textual,
    double targetWidth,
  ) {
    final double textualWidth = textual.last.xPosition + textual.last.width;
    final double scaleFactor = targetWidth / textualWidth;

    final List<SymbolSpacing> compressed = [];
    double currentX = 0.0;

    for (final pos in textual) {
      final double scaledWidth = pos.width * scaleFactor;
      final double scaledPadding = pos.padding * scaleFactor;

      compressed.add(
        SymbolSpacing(
          symbolIndex: pos.symbolIndex,
          xPosition: currentX,
          width: scaledWidth,
          padding: scaledPadding,
        ),
      );

      currentX += scaledWidth + scaledPadding;
    }

    return compressed;
  }

  /// Expande spacing using guia duracional
  List<SymbolSpacing> _expandWithDurationalGuidance(
    List<SymbolSpacing> textual,
    List<SymbolSpacing> durational,
    double targetWidth,
  ) {
    if (textual.isEmpty) return <SymbolSpacing>[];

    // 1) Scale durational widths to target width.
    final double durationalWidth =
        durational.last.xPosition + durational.last.width;
    final double durationalScale = durationalWidth > 0
        ? targetWidth / durationalWidth
        : 1.0;

    // 2) Build candidate widths preserving textual minimums.
    final List<double> minWidths = <double>[];
    final List<double> widths = <double>[];

    for (int i = 0; i < textual.length; i++) {
      final textWidth = textual[i].width + textual[i].padding;
      final durWidth = durational[i].width * durationalScale;
      final preferred = max(textWidth, durWidth);
      final blended =
          textWidth + ((preferred - textWidth) * preferences.consistencyWeight);

      minWidths.add(textWidth);
      widths.add(blended);
    }

    double total = widths.fold(0.0, (sum, width) => sum + width);

    // 3) Expand to target if needed.
    if (total < targetWidth && total > 0) {
      final expand = targetWidth / total;
      for (int i = 0; i < widths.length; i++) {
        widths[i] *= expand;
      }
      total = targetWidth;
    }

    // 4) If above target, compress only the part above textual minimum.
    if (total > targetWidth) {
      final compressible = <double>[];
      double totalCompressible = 0.0;
      for (int i = 0; i < widths.length; i++) {
        final c = max(0.0, widths[i] - minWidths[i]);
        compressible.add(c);
        totalCompressible += c;
      }

      final overflow = total - targetWidth;
      if (totalCompressible > 0.0) {
        final reductionRatio = (overflow / totalCompressible).clamp(0.0, 1.0);
        for (int i = 0; i < widths.length; i++) {
          widths[i] -= compressible[i] * reductionRatio;
        }
      }
    }

    // 5) Distribute tiny residual to reach target width deterministically.
    total = widths.fold(0.0, (sum, width) => sum + width);
    final residual = targetWidth - total;
    if (widths.isNotEmpty && residual.abs() > 0.0001) {
      final deltaPerItem = residual / widths.length;
      for (int i = 0; i < widths.length; i++) {
        widths[i] = max(minWidths[i], widths[i] + deltaPerItem);
      }
    }

    // 6) Emit final positioned spacing.
    final List<SymbolSpacing> expanded = <SymbolSpacing>[];
    double currentX = 0.0;
    for (int i = 0; i < textual.length; i++) {
      final width = widths[i];
      expanded.add(
        SymbolSpacing(
          symbolIndex: textual[i].symbolIndex,
          xPosition: currentX,
          width: width,
          padding: 0.0,
          compressibleSpace: max(0.0, width - minWidths[i]),
        ),
      );
      currentX += width;
    }

    return expanded;
  }

  /// **ANALYSIS PATH — not used by the renderer.** The production entry point
  /// for optical compensation is [opticalAdjustment].
  ///
  /// applies compensações ópticas
  void applyOpticalCompensation({
    required List<SymbolSpacing> spacing,
    required List<MusicalSymbolInfo> symbols,
    required double staffSpace,
  }) {
    if (_compensator == null || !preferences.enableOpticalSpacing) return;

    for (int i = 1; i < spacing.length; i++) {
      final prevSymbol = symbols[spacing[i - 1].symbolIndex];
      final currSymbol = symbols[spacing[i].symbolIndex];

      final prevContext = _createOpticalContext(prevSymbol);
      final currContext = _createOpticalContext(currSymbol);

      // Calculate densidade local
      final double density = _calculateLocalDensity(i, spacing, symbols);

      // Calculate compensação
      final double compensation = _compensator!.calculateCompensation(
        prevContext,
        currContext,
        localDensity: density,
      );

      // aplicar ajuste a all os symbols subsequentes
      for (int j = i; j < spacing.length; j++) {
        spacing[j].xPosition += compensation;
      }
    }
  }

  /// Calculates width de a symbol
  double _calculateSymbolWidth(MusicalSymbolInfo symbol, double staffSpace) {
    // Width base of the glyph (in staff spaces)
    double baseWidth = symbol.glyphWidth ?? 1.18; // noteheadBlack padrão

    // Convertsr for pixels
    return baseWidth * staffSpace;
  }

  /// Calculates space added for accidental
  double _calculateAccidentalSpace(
    MusicalSymbolInfo symbol,
    double staffSpace,
  ) {
    if (!symbol.hasAccidental) return 0.0;

    // Interpolar between spacing normal (0.5 SS) and compacto (0.25 SS)
    final double density = preferences.densityPreference;
    return SpacingConstants.lerp(
          SpacingConstants.accidentalSpacingNormal,
          SpacingConstants.accidentalSpacingCompact,
          density,
        ) *
        staffSpace;
  }

  /// Creates context óptico for a symbol
  OpticalContext _createOpticalContext(MusicalSymbolInfo symbol) {
    if (symbol.isRest) {
      return OpticalContext.rest(duration: symbol.duration ?? 0.25);
    }

    return OpticalContext.note(
      stemUp: symbol.stemUp ?? true,
      duration: symbol.duration ?? 0.25,
      hasAccidental: symbol.hasAccidental,
      isDotted: symbol.isDotted,
      beamCount: symbol.beamCount,
    );
  }

  /// Calculates densidade local to the redor de a index
  double _calculateLocalDensity(
    int index,
    List<SymbolSpacing> spacing,
    List<MusicalSymbolInfo> symbols,
  ) {
    // Janela de 5 symbols centred no index
    final int windowSize = 5;
    final int start = max(0, index - windowSize ~/ 2);
    final int end = min(spacing.length, index + windowSize ~/ 2 + 1);

    final int elementCount = end - start;
    final double windowWidth =
        spacing[end - 1].xPosition - spacing[start].xPosition;

    if (_compensator == null) return 0.5;
    return _compensator!.calculateLocalDensity(elementCount, windowWidth);
  }
}

/// **ANALYSIS SCAFFOLDING — not on the render path.**
///
/// Informação de symbol musical for spacing (dual-algorithm experiment).
class MusicalSymbolInfo {
  final int index;
  final double musicalTime; // Onset em frações de semibreve
  final double? duration; // Duração em frações de semibreve
  final bool isRest;
  final bool hasAccidental;
  final bool isDotted;
  final bool? stemUp;
  final int? beamCount;
  final double? glyphWidth; // Largura em staff spaces (SMuFL)

  const MusicalSymbolInfo({
    required this.index,
    required this.musicalTime,
    this.duration,
    this.isRest = false,
    this.hasAccidental = false,
    this.isDotted = false,
    this.stemUp,
    this.beamCount,
    this.glyphWidth,
  });
}

/// **ANALYSIS SCAFFOLDING — not on the render path.** The production report
/// type is [SpacingResult].
///
/// Result de spacing de a symbol (dual-algorithm experiment).
class SymbolSpacing {
  final int symbolIndex;
  double xPosition;
  double width;
  double padding;
  double compressibleSpace;

  SymbolSpacing({
    required this.symbolIndex,
    required this.xPosition,
    required this.width,
    this.padding = 0.0,
    this.compressibleSpace = 0.0,
  });

  @override
  String toString() {
    return 'SymbolSpacing(#$symbolIndex, x: ${xPosition.toStringAsFixed(2)}, '
        'w: ${width.toStringAsFixed(2)}, '
        'p: ${padding.toStringAsFixed(2)})';
  }
}
