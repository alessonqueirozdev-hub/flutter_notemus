/// Motor principal de intelligent spacing
///
/// Implementa o algoritmo dual (textual + duracional) with combinação adaptativa
/// following os princípios de MuseScore MS21, Dorico and Lime/ACM.
library;

import 'dart:math';
import 'spacing_model.dart';
import 'spacing_preferences.dart';
import 'optical_compensation.dart';

/// Spacing engine inteligente
///
/// Processes measures in nível de system (not individual) for ensure
/// consistência de spacing according to a Regra Dourada de Gould.
class IntelligentSpacingEngine {
  /// Preferences de spacing
  final SpacingPreferences preferences;

  /// Calculatora de durational spacing
  late final SpacingCalculator _calculator;

  /// Compensador óptico
  OpticalCompensator? _compensator;

  // Collisiwheretector disponível for uso futuro
  // final Collisiwheretector _collisiwheretector;

  IntelligentSpacingEngine({this.preferences = SpacingPreferences.normal}) {
    _calculator = SpacingCalculator(
      model: preferences.model,
      spacingRatio: preferences.spacingFactor,
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

  /// Calculates textual spacing (anti-colisão)
  ///
  /// **Objetivo:** Avoid colisões de symbols, ignorando duração
  ///
  /// **Processo:**
  /// 1. Calculate width de each symbol
  /// 2. add padding mínimo between elementos adjacentes
  /// 3. Processesr symbols simultâneos in múltiplas staves
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

      // Appliesr ajuste a all os symbols subsequentes
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

/// Informação de symbol musical for spacing
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

/// Result de spacing de a symbol
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
