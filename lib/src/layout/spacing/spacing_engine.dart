/// Motor principal de espaçamento inteligente
/// 
/// Implementa o algoritmo dual (textual + duracional) com combinação adaptativa
/// seguindo os princípios de MuseScore MS21, Dorico e Lime/ACM.
library;

import 'dart:math';
import 'spacing_model.dart';
import 'spacing_preferences.dart';
import 'optical_compensation.dart';

/// Motor de espaçamento inteligente
/// 
/// Processa compassos em nível de sistema (não individual) para garantir
/// consistência de espaçamento conforme a Regra Dourada de Gould.
class IntelligentSpacingEngine {
  /// Preferências de espaçamento
  final SpacingPreferences preferences;

  /// Calculadora de espaçamento duracional
  late final SpacingCalculator _calculator;

  /// Compensador óptico
  OpticalCompensator? _compensator;

  // CollisionDetector disponível para uso futuro
  // final CollisionDetector _collisionDetector;

  IntelligentSpacingEngine({
    this.preferences = SpacingPreferences.normal,
  }) {
    _calculator = SpacingCalculator(
      model: preferences.model,
      spacingRatio: preferences.spacingFactor,
    );
  }

  /// Inicializa o compensador óptico com staff space
  void initializeOpticalCompensator(double staffSpace) {
    _compensator = OpticalCompensator(
      staffSpace: staffSpace,
      enabled: preferences.enableOpticalSpacing,
      intensity: 1.0,
    );
  }

  /// Calcula espaçamento textual (anti-colisão)
  /// 
  /// **Objetivo:** Evitar colisões de símbolos, ignorando duração
  /// 
  /// **Processo:**
  /// 1. Calcular largura de cada símbolo
  /// 2. Adicionar padding mínimo entre elementos adjacentes
  /// 3. Processar símbolos simultâneos em múltiplas pautas
  /// 
  /// **Retorna:** Lista de posições com espaçamento denso e uniforme
  List<SymbolSpacing> computeTextualSpacing({
    required List<MusicalSymbolInfo> symbols,
    required double minGap,
    required double staffSpace,
  }) {
    final List<SymbolSpacing> positions = [];
    double currentX = 0.0;

    for (int i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];

      // Calcular largura do símbolo
      double symbolWidth = _calculateSymbolWidth(symbol, staffSpace);

      // Adicionar padding mínimo
      double padding = minGap * staffSpace;

      // Ajustar para acidentes
      if (symbol.hasAccidental) {
        padding += _calculateAccidentalSpace(symbol, staffSpace);
      }

      positions.add(SymbolSpacing(
        symbolIndex: i,
        xPosition: currentX,
        width: symbolWidth,
        padding: padding,
      ));

      currentX += symbolWidth + padding;
    }

    return positions;
  }

  /// Calcula espaçamento duracional (proporcional ao tempo)
  /// 
  /// **Objetivo:** Codificar relações temporais
  /// 
  /// **Processo:**
  /// 1. Encontrar nota mais curta do sistema
  /// 2. Para cada símbolo: calcular espaço baseado na duração até o próximo
  /// 3. Usar modelo matemático (raiz quadrada recomendado)
  /// 
  /// **Retorna:** Lista de posições com espaçamento proporcional
  List<SymbolSpacing> computeDurationalSpacing({
    required List<MusicalSymbolInfo> symbols,
    required double shortestDuration,
    required double staffSpace,
  }) {
    final List<SymbolSpacing> positions = [];
    double currentX = 0.0;

    for (int i = 0; i < symbols.length; i++) {
      final symbol = symbols[i];

      // Calcular espaço baseado na duração até o próximo símbolo
      double timeToNext = (i < symbols.length - 1)
          ? symbols[i + 1].musicalTime - symbol.musicalTime
          : 0.25; // Padrão: semínima

      // Calcular espaço usando modelo matemático
      double space = _calculator.calculateSpace(timeToNext, shortestDuration);
      space *= staffSpace; // Converter para pixels

      // Pausas têm espaçamento reduzido (80%)
      if (symbol.isRest) {
        space *= preferences.restSpacingRatio;
      }

      positions.add(SymbolSpacing(
        symbolIndex: i,
        xPosition: currentX,
        width: space,
        padding: 0.0,
      ));

      currentX += space;
    }

    return positions;
  }

  /// Combina espaçamentos textual e duracional adaptativamente
  /// 
  /// **Algoritmo:**
  /// - Se textual < target: Expandir com guia duracional
  /// - Se textual > target: Comprimir linearmente
  /// 
  /// **Retorna:** Espaçamento final combinado
  List<SymbolSpacing> combineSpacings({
    required List<SymbolSpacing> textual,
    required List<SymbolSpacing> durational,
    required double targetWidth,
  }) {
    final double textualWidth = textual.isEmpty ? 0.0 : 
        textual.last.xPosition + textual.last.width;

    if (textualWidth > targetWidth) {
      // Caso A: Compressão linear
      return _compressTextualSpacing(textual, targetWidth);
    } else {
      // Caso B: Expansão com guia duracional
      return _expandWithDurationalGuidance(
        textual,
        durational,
        targetWidth,
      );
    }
  }

  /// Comprime espaçamento textual linearmente
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

      compressed.add(SymbolSpacing(
        symbolIndex: pos.symbolIndex,
        xPosition: currentX,
        width: scaledWidth,
        padding: scaledPadding,
      ));

      currentX += scaledWidth + scaledPadding;
    }

    return compressed;
  }

  /// Expande espaçamento usando guia duracional
  List<SymbolSpacing> _expandWithDurationalGuidance(
    List<SymbolSpacing> textual,
    List<SymbolSpacing> durational,
    double targetWidth,
  ) {
    // 1. Escalar espaçamento duracional para target width
    final double durationalWidth = durational.last.xPosition + durational.last.width;
    final double scaleFactor = targetWidth / durationalWidth;

    // 2. Para cada posição: max(textual, durational_escalado)
    final List<SymbolSpacing> expanded = [];
    double totalCompressibleSpace = 0.0;

    for (int i = 0; i < textual.length; i++) {
      final textPos = textual[i];
      final durPos = durational[i];

      final double textWidth = textPos.width + textPos.padding;
      final double durWidth = durPos.width * scaleFactor;
      final double finalWidth = max(textWidth, durWidth);

      final double compressible = finalWidth - textWidth;
      totalCompressibleSpace += compressible;

      expanded.add(SymbolSpacing(
        symbolIndex: textPos.symbolIndex,
        xPosition: 0.0, // Será recalculado
        width: finalWidth,
        padding: 0.0,
        compressibleSpace: compressible,
      ));
    }

    // 3. Redistribuir espaço comprimível
    final double compressionFactor = totalCompressibleSpace > 0
        ? (targetWidth - (textual.last.xPosition + textual.last.width)) / totalCompressibleSpace
        : 1.0;

    // Recalcular posições finais
    double currentX = 0.0;
    for (int i = 0; i < expanded.length; i++) {
      final textWidth = textual[i].width + textual[i].padding;
      final shrinkable = expanded[i].compressibleSpace;

      final finalWidth = textWidth + (shrinkable * compressionFactor * preferences.consistencyWeight);

      expanded[i] = SymbolSpacing(
        symbolIndex: expanded[i].symbolIndex,
        xPosition: currentX,
        width: finalWidth,
        padding: 0.0,
        compressibleSpace: shrinkable,
      );

      currentX += finalWidth;
    }

    return expanded;
  }

  /// Aplica compensações ópticas
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

      // Calcular densidade local
      final double density = _calculateLocalDensity(i, spacing, symbols);

      // Calcular compensação
      final double compensation = _compensator!.calculateCompensation(
        prevContext,
        currContext,
        localDensity: density,
      );

      // Aplicar ajuste a todos os símbolos subsequentes
      for (int j = i; j < spacing.length; j++) {
        spacing[j].xPosition += compensation;
      }
    }
  }

  /// Calcula largura de um símbolo
  double _calculateSymbolWidth(MusicalSymbolInfo symbol, double staffSpace) {
    // Largura base do glyph (em staff spaces)
    double baseWidth = symbol.glyphWidth ?? 1.18; // noteheadBlack padrão

    // Converter para pixels
    return baseWidth * staffSpace;
  }

  /// Calcula espaço adicional para acidente
  double _calculateAccidentalSpace(MusicalSymbolInfo symbol, double staffSpace) {
    if (!symbol.hasAccidental) return 0.0;

    // Interpolar entre espaçamento normal (0.5 SS) e compacto (0.25 SS)
    final double density = preferences.densityPreference;
    return SpacingConstants.lerp(
      SpacingConstants.accidentalSpacingNormal,
      SpacingConstants.accidentalSpacingCompact,
      density,
    ) * staffSpace;
  }

  /// Cria contexto óptico para um símbolo
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

  /// Calcula densidade local ao redor de um índice
  double _calculateLocalDensity(
    int index,
    List<SymbolSpacing> spacing,
    List<MusicalSymbolInfo> symbols,
  ) {
    // Janela de 5 símbolos centrada no índice
    final int windowSize = 5;
    final int start = max(0, index - windowSize ~/ 2);
    final int end = min(spacing.length, index + windowSize ~/ 2 + 1);

    final int elementCount = end - start;
    final double windowWidth = spacing[end - 1].xPosition - spacing[start].xPosition;

    if (_compensator == null) return 0.5;
    return _compensator!.calculateLocalDensity(elementCount, windowWidth);
  }
}

/// Informação de símbolo musical para espaçamento
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

/// Resultado de espaçamento de um símbolo
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
