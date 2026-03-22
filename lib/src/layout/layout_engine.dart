// lib/src/layout/layout_engine.dart
// VERSÃO CORRIGIDA: Espaçamento melhorado e beaming corrigido
// FASE 3: Suporte a BoundingBox hierárquico adicionado
// FASE 2 REFATORAÇÃO: Usando tipos do core/

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';
import 'package:flutter_notemus/src/beaming/beam_analyzer.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/layout/beam_grouper.dart';
import 'package:flutter_notemus/src/layout/measure_validator.dart'; // ✅ ADICIONADO
import 'package:flutter_notemus/src/rendering/staff_position_calculator.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';
import 'package:flutter_notemus/src/smufl/smufl_metadata_loader.dart'; // ✅ ADICIONADO
import 'spacing/spacing.dart' as spacing;

class PositionedElement {
  final MusicalElement element;
  final Offset position;
  final int system;

  PositionedElement(this.element, this.position, {this.system = 0});
}

class LayoutCursor {
  final double staffSpace;
  final double availableWidth;
  final double systemMargin;
  final double systemHeight;

  // Mapas para capturar posições das notas (para beaming)
  final Map<Note, double>? noteXPositions;
  final Map<Note, int>? noteStaffPositions;
  final Map<Note, double>? noteYPositions; // ✅ NOVO: Y absoluto em pixels

  double _currentX;
  double _currentY;
  int _currentSystem;
  bool _isFirstMeasureInSystem;
  Clef? _currentClef; // ✅ NOVO: Rastrear clave atual

  LayoutCursor({
    required this.staffSpace,
    required this.availableWidth,
    required this.systemMargin,
    this.systemHeight = 10.0,
    this.noteXPositions,
    this.noteStaffPositions,
    this.noteYPositions, // ✅ NOVO
  }) : _currentX = systemMargin,
       _currentY =
           staffSpace *
           5.0, // CORREÇÃO CRÍTICA: Baseline é staffSpace * 5, não * 4
       _currentSystem = 0,
       _isFirstMeasureInSystem = true;

  double get currentX => _currentX;
  double get currentY => _currentY;
  int get currentSystem => _currentSystem;
  bool get isFirstMeasureInSystem => _isFirstMeasureInSystem;
  double get usableWidth => availableWidth - (systemMargin * 2);

  void advance(double width) {
    _currentX += width;
  }

  bool needsSystemBreak(double measureWidth) {
    if (_isFirstMeasureInSystem) return false;
    return _currentX + measureWidth > systemMargin + usableWidth;
  }

  void startNewSystem() {
    _currentSystem++;
    _currentX = systemMargin;
    _currentY += systemHeight * staffSpace;
    _isFirstMeasureInSystem = true;
  }

  void addBarline(List<PositionedElement> elements) {
    elements.add(
      PositionedElement(
        Barline(),
        Offset(_currentX, _currentY),
        system: _currentSystem,
      ),
    );
    advance(LayoutEngine.barlineSeparation * staffSpace);
  }

  /// Adiciona barra dupla final (fim da peça)
  void addDoubleBarline(List<PositionedElement> elements) {
    elements.add(
      PositionedElement(
        Barline(type: BarlineType.final_),
        Offset(_currentX, _currentY),
        system: _currentSystem,
      ),
    );
    advance(LayoutEngine.barlineSeparation * staffSpace);
  }

  void endMeasure() {
    _isFirstMeasureInSystem = false;
    // Padding agora aplicado ANTES da barline no layout principal
  }

  void addElement(MusicalElement element, List<PositionedElement> elements) {
    // BoundingBox support comentado temporariamente
    // TODO: Reativar quando BoundingBoxSupport estiver disponível

    // Rastrear clave atual
    if (element is Clef) {
      _currentClef = element;
    }

    // ✅ SUPORTE A ACORDES: Expandir notas do acorde em elementos separados
    if (element is Chord && _currentClef != null) {
      for (final note in element.notes) {
        // Calcular posição Y para cada nota do acorde
        final staffPosition = StaffPositionCalculator.calculate(
          note.pitch,
          _currentClef!,
        );
        
        final noteY = StaffPositionCalculator.toPixelY(
          staffPosition,
          staffSpace,
          _currentY,
        );
        
        // Registrar nota para beaming
        noteXPositions?[note] = _currentX;
        noteStaffPositions?[note] = staffPosition;
        noteYPositions?[note] = noteY;
        
        // Adicionar cada nota do acorde como elemento separado (mesma pos X, Y diferente)
        elements.add(
          PositionedElement(
            note,
            Offset(_currentX, noteY),
            system: _currentSystem,
          ),
        );
      }
      return; // Não adicionar o Chord como elemento único
    }
    
    // Calcular posição Y específica para notas (baseado no pitch)
    double elementY = _currentY; // Default: baseline do sistema
    
    // Capturar posições de notas para beaming avançado
    if (element is Note && _currentClef != null) {
      noteXPositions?[element] = _currentX;

      // ✅ USAR STAFFPOSITIONCALCULATOR (fonte oficial de verdade!)
      final staffPosition = StaffPositionCalculator.calculate(
        element.pitch,
        _currentClef!,
      );
      noteStaffPositions?[element] = staffPosition;

      // ✅ Converter para Y absoluto usando método oficial
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        _currentY, // baseline do sistema
      );
      noteYPositions?[element] = noteY;
      
      // ✅ CRÍTICO: Usar o noteY calculado, não o _currentY genérico!
      elementY = noteY;
    }

    elements.add(
      PositionedElement(
        element,
        Offset(_currentX, elementY), // ✅ Usar elementY específico!
        system: _currentSystem,
      ),
    );
  }
}

class LayoutEngine {
  final Staff staff;
  final double availableWidth;
  final double staffSpace;
  final SmuflMetadata? metadata; // ✅ Tipagem correta aplicada

  // Sistema de Espaçamento Inteligente
  late final spacing.IntelligentSpacingEngine _spacingEngine;

  // Sistema de Beaming Avançado
  late final BeamAnalyzer _beamAnalyzer;
  final Map<Note, double> _noteXPositions = {};
  final Map<Note, int> _noteStaffPositions = {};
  final Map<Note, double> _noteYPositions = {}; // ✅ NOVO: Y absoluto em pixels
  final List<AdvancedBeamGroup> _advancedBeamGroups = [];

  // Configuração de validação (silenciosa por padrão)
  final bool verboseValidation;

  // CORREÇÃO SMuFL: Larguras agora consultadas dinamicamente do metadata
  // Valores de fallback mantidos para compatibilidade
  static const double _gClefWidthFallback = 2.684;
  static const double _fClefWidthFallback = 2.756;
  static const double _cClefWidthFallback = 2.796;
  static const double _noteheadBlackWidthFallback = 1.18;
  static const double _accidentalSharpWidthFallback = 1.116;
  static const double _accidentalFlatWidthFallback = 1.18;
  static const double barlineSeparation = 2.5; // Espaço DEPOIS da barline
  static const double legerLineExtension = 0.4;

  // ESPAÇAMENTO INTELIGENTE: Valores balanceados
  static const double systemMargin = 2.5;
  static const double measureMinWidth = 5.0;
  static const double noteMinSpacing = 3.5; // Base para espaçamento entre notas
  static const double measureEndPadding =
      3.0; // Espaço adequado ANTES da barline (agora corrigido!)

  // QUEBRA DE LINHA INTELIGENTE
  static const int measuresPerSystem = 4; // Compassos por linha

  LayoutEngine(
    this.staff, {
    required this.availableWidth,
    this.staffSpace = 12.0,
    this.metadata,
    this.verboseValidation = false, // Silencioso por padrão
    spacing.SpacingPreferences? spacingPreferences,
  }) {
    // Inicializar motor de espaçamento
    _spacingEngine = spacing.IntelligentSpacingEngine(
      preferences: spacingPreferences ?? spacing.SpacingPreferences.normal,
    );
    _spacingEngine.initializeOpticalCompensator(staffSpace);

    // Inicializar positioning engine para beaming
    // VALIDAÇÃO: metadata pode ser null em alguns contextos
    if (metadata == null) {
      throw ArgumentError('metadata é obrigatório para beaming avançado');
    }
    final positioningEngine = SMuFLPositioningEngine(metadataLoader: metadata!);

    // Inicializar sistema de beaming avançado
    _beamAnalyzer = BeamAnalyzer(
      staffSpace: staffSpace,
      noteheadWidth: noteheadBlackWidth * staffSpace,
      positioningEngine: positioningEngine,
    );
  }

  /// Obtém largura de glifo dinamicamente do metadata ou retorna fallback
  double _getGlyphWidth(String glyphName, double fallback) {
    if (metadata != null && metadata!.hasGlyph(glyphName)) {
      return metadata!.getGlyphWidth(glyphName);
    }
    return fallback;
  }

  /// Largura da clave de Sol (G clef)
  double get gClefWidth => _getGlyphWidth('gClef', _gClefWidthFallback);

  /// Largura da clave de Fá (F clef)
  double get fClefWidth => _getGlyphWidth('fClef', _fClefWidthFallback);

  /// Largura da clave de Dó (C clef)
  double get cClefWidth => _getGlyphWidth('cClef', _cClefWidthFallback);

  /// Largura da cabeça de nota preta
  double get noteheadBlackWidth =>
      _getGlyphWidth('noteheadBlack', _noteheadBlackWidthFallback);

  /// Largura do sustenido
  double get accidentalSharpWidth =>
      _getGlyphWidth('accidentalSharp', _accidentalSharpWidthFallback);

  /// Largura do bemol
  double get accidentalFlatWidth =>
      _getGlyphWidth('accidentalFlat', _accidentalFlatWidthFallback);

  /// Retorna os Advanced Beam Groups calculados pelo último layout
  List<AdvancedBeamGroup> get advancedBeamGroups =>
      List.unmodifiable(_advancedBeamGroups);

  /// ✅ Expor posições X das notas para renderização precisa
  Map<Note, double> get noteXPositions => Map.unmodifiable(_noteXPositions);

  /// ✅ Expor posições Y das notas para renderização de hastes
  Map<Note, double> get noteYPositions => Map.unmodifiable(_noteYPositions);

  List<PositionedElement> layout() {
    // Limpar mapas de posições
    _noteXPositions.clear();
    _noteStaffPositions.clear();
    _noteYPositions.clear(); // ✅ NOVO
    _advancedBeamGroups.clear();

    final cursor = LayoutCursor(
      staffSpace: staffSpace,
      availableWidth: availableWidth,
      systemMargin: systemMargin * staffSpace,
      noteXPositions: _noteXPositions,
      noteStaffPositions: _noteStaffPositions,
      noteYPositions: _noteYPositions, // ✅ NOVO
    );

    final List<PositionedElement> positionedElements = [];

    // Armazenar compassos por sistema para justificação
    final systemMeasures = <int, List<int>>{};
    final measureStartIndices = <int, int>{};

    // Sistema de herança de TimeSignature
    TimeSignature? currentTimeSignature;

    // Contador de validação (apenas para estatísticas)
    int validMeasures = 0;
    int invalidMeasures = 0;

    for (int i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      final isFirst = cursor.isFirstMeasureInSystem;
      final isLast = i == staff.measures.length - 1;
      final isLastInSystem = (i + 1) % measuresPerSystem == 0 && !isLast;

      // HERANÇA DE TIME SIGNATURE: Procurar no compasso atual
      TimeSignature? measureTimeSignature;
      for (final element in measure.elements) {
        if (element is TimeSignature) {
          measureTimeSignature = element;
          currentTimeSignature = element; // Atualizar TimeSignature corrente
          break;
        }
      }

      // Se não encontrou, usar o TimeSignature herdado
      final timeSignatureToUse = measureTimeSignature ?? currentTimeSignature;

      // Definir TimeSignature herdado no Measure para validação preventiva
      if (timeSignatureToUse != null && measureTimeSignature == null) {
        measure.inheritedTimeSignature = timeSignatureToUse;
      }

      // ✅ Validação de compasso (silenciosa - apenas estatísticas)
      if (timeSignatureToUse != null) {
        final validation = MeasureValidator.validateWithTimeSignature(
          measure,
          timeSignatureToUse,
          allowAnacrusis: isFirst && i == 0,
        );
        if (validation.isValid) {
          validMeasures++;
        } else {
          invalidMeasures++;
        }
      }

      final measureWidth = _calculateMeasureWidthCursor(measure, isFirst);

      // QUEBRA INTELIGENTE: A cada N compassos OU se não couber
      if (!isFirst &&
          (isLastInSystem || cursor.needsSystemBreak(measureWidth))) {
        cursor.startNewSystem();
      }

      // Guardar índice inicial do compasso para justificação
      final measureStartIndex = positionedElements.length;
      measureStartIndices[i] = measureStartIndex;

      // Registrar compasso no sistema
      final currentSystem = cursor.currentSystem;
      systemMeasures[currentSystem] = systemMeasures[currentSystem] ?? [];
      systemMeasures[currentSystem]!.add(i);

      _layoutMeasureCursor(
        measure,
        cursor,
        positionedElements,
        cursor.isFirstMeasureInSystem,
      );

      // Verificar se compasso ATUAL termina com barline
      final currentMeasureEndsWithBarline =
          measure.elements.isNotEmpty && measure.elements.last is Barline;

      // Verificar se PRÓXIMO compasso começa com barline (ex: repeat)
      final nextMeasure = (i < staff.measures.length - 1)
          ? staff.measures[i + 1]
          : null;
      final nextMeasureStartsWithBarline =
          nextMeasure != null &&
          nextMeasure.elements.isNotEmpty &&
          nextMeasure.elements.first is Barline;

      // Adicionar barline apropriada SOMENTE se:
      // 1. Próximo compasso não começar com uma
      // 2. Compasso atual não terminar com uma
      if (!nextMeasureStartsWithBarline && !currentMeasureEndsWithBarline) {
        if (isLast) {
          // BARRA DUPLA FINAL
          cursor.advance(measureEndPadding * staffSpace);
          cursor.addDoubleBarline(positionedElements);
        } else if (isLastInSystem) {
          // BARLINE NORMAL no final do sistema
          cursor.advance(measureEndPadding * staffSpace);
          cursor.addBarline(positionedElements);
        } else {
          // BARLINE NORMAL entre compassos
          cursor.advance(measureEndPadding * staffSpace);
          cursor.addBarline(positionedElements);
        }
      } else {
        // Compasso termina com barline OU próximo começa com barline - apenas adicionar padding
        cursor.advance(measureEndPadding * staffSpace);
      }

      cursor.endMeasure();
    }

    // Relatório resumido (apenas se verbose)
    if (verboseValidation && (validMeasures + invalidMeasures) > 0) {}

    // JUSTIFICAÇÃO HORIZONTAL: Esticar compassos para preencher largura
    _justifyHorizontally(positionedElements, systemMeasures);

    // ANÁLISE DE BEAMING AVANÇADO: Criar AdvancedBeamGroups
    _analyzeBeamGroups(currentTimeSignature, positionedElements);

    return positionedElements;
  }

  /// Analisa beam groups e cria AdvancedBeamGroups para renderização
  /// ✅ CORREÇÃO: Usar notas PROCESSADAS de positionedElements, não de measure.elements
  void _analyzeBeamGroups(
    TimeSignature? timeSignature,
    List<PositionedElement> positionedElements,
  ) {
    if (timeSignature == null) {
      return;
    }

    // ✅ CORREÇÃO: Extrair notas PROCESSADAS diretamente de positionedElements
    // As notas processadas são aquelas que foram adicionadas aos mapas
    final processedNotes = positionedElements
        .where((p) => p.element is Note)
        .map((p) => p.element as Note)
        .toList();

    if (processedNotes.isEmpty) {
      return;
    }

    // Detectar beam groups usando as notas PROCESSADAS
    final beamGroups = BeamGrouper.groupNotesForBeaming(
      processedNotes,
      timeSignature,
      autoBeaming: true, // Usar auto-beaming padrão
      beamingMode: BeamingMode.automatic,
    );

    // Analisar cada beam group
    int groupIndex = 0;
    for (final beamGroup in beamGroups) {
      groupIndex++;

      if (beamGroup.isValid && beamGroup.notes.length >= 2) {
        try {
          final advancedGroup = _beamAnalyzer.analyzeAdvancedBeamGroup(
            beamGroup.notes,
            timeSignature,
            noteXPositions: _noteXPositions,
            noteStaffPositions: _noteStaffPositions,
            noteYPositions: _noteYPositions,
          );
          _advancedBeamGroups.add(advancedGroup);
        } catch (e, stackTrace) {}
      } else {}
    }
  }

  /// Justifica horizontalmente os compassos para preencher a largura disponível
  void _justifyHorizontally(
    List<PositionedElement> elements,
    Map<int, List<int>> systemMeasures,
  ) {
    final usableWidth = availableWidth - (systemMargin * staffSpace * 2);

    for (final entry in systemMeasures.entries) {
      final system = entry.key;
      final measures = entry.value;

      if (measures.isEmpty) continue;

      // Encontrar X mínimo e máximo dos elementos neste sistema
      double minX = double.infinity;
      double maxX = 0;

      for (final positioned in elements) {
        if (positioned.system == system) {
          if (positioned.position.dx < minX) minX = positioned.position.dx;
          if (positioned.position.dx > maxX) maxX = positioned.position.dx;
        }
      }

      final usedWidth = maxX - minX;
      final extraSpace = usableWidth - usedWidth;

      // Se há espaço extra, distribuir proporcionalmente
      if (extraSpace > 0 && measures.length > 1) {
        // Ajustar posições dos elementos após cada compasso
        for (int i = 0; i < elements.length; i++) {
          final positioned = elements[i];
          if (positioned.system != system) continue;

          // Calcular proporção de posição no sistema (simplificado)
          final positionRatio = (maxX - minX) > 0
              ? (positioned.position.dx - minX) / (maxX - minX)
              : 0.0;

          // Aplicar offset proporcional baseado na posição
          final offset = extraSpace * positionRatio;
          elements[i] = PositionedElement(
            positioned.element,
            Offset(positioned.position.dx + offset, positioned.position.dy),
            system: positioned.system,
          );
        }
      }
    }
  }

  double _calculateMeasureWidthCursor(Measure measure, bool isFirstInSystem) {
    double totalWidth = 0;
    int musicalElementCount = 0;

    for (final element in measure.elements) {
      if (!isFirstInSystem && _isSystemElement(element)) {
        continue;
      }

      totalWidth += _getElementWidthSimple(element);

      if (element is Note || element is Rest || element is Chord) {
        musicalElementCount++;
      }
    }

    if (musicalElementCount > 1) {
      totalWidth += (musicalElementCount - 1) * noteMinSpacing * staffSpace;
    }

    final minWidth = measureMinWidth * staffSpace;
    return totalWidth < minWidth ? minWidth : totalWidth;
  }

  void _layoutMeasureCursor(
    Measure measure,
    LayoutCursor cursor,
    List<PositionedElement> positionedElements,
    bool isFirstInSystem,
  ) {
    // CORREÇÃO #9: Processar beaming considerando anacrusis
    final processedElements = _processBeamsWithAnacrusis(
      measure.elements,
      measure.timeSignature,
      autoBeaming: measure.autoBeaming,
      beamingMode: measure.beamingMode,
      manualBeamGroups: measure.manualBeamGroups,
    );

    final elementsToRender = processedElements.where((element) {
      return isFirstInSystem || !_isSystemElement(element);
    }).toList();

    if (elementsToRender.isEmpty) return;

    final systemElements = <MusicalElement>[];
    final musicalElements = <MusicalElement>[];

    for (final element in elementsToRender) {
      if (_isSystemElement(element)) {
        systemElements.add(element);
      } else {
        musicalElements.add(element);
      }
    }

    for (final element in systemElements) {
      cursor.addElement(element, positionedElements);
      cursor.advance(_getElementWidthSimple(element));
    }

    // CORREÇÃO #3: Espaçamento inteligente melhorado
    if (systemElements.isNotEmpty) {
      final spacingAfterSystem = _calculateSpacingAfterSystemElementsCorrected(
        systemElements,
        musicalElements,
      );
      cursor.advance(spacingAfterSystem);
    }

    for (int i = 0; i < musicalElements.length; i++) {
      final element = musicalElements[i];

      if (i > 0) {
        // CORREÇÃO VISUAL #2: Usar espaçamento rítmico ao invés de constante
        final previousElement = musicalElements[i - 1];
        final rhythmicSpacing = _calculateRhythmicSpacing(
          element,
          previousElement,
        );
        cursor.advance(rhythmicSpacing);
      }

      cursor.addElement(element, positionedElements);
      cursor.advance(_getElementWidthSimple(element));
    }
  }

  bool _isSystemElement(MusicalElement element) {
    return element is Clef ||
        element is KeySignature ||
        element is TimeSignature ||
        element is TempoMark; // TempoMark não ocupa espaço horizontal
  }

  // ESPAÇAMENTO APÓS ELEMENTOS DE SISTEMA: MÍNIMO necessário
  double _calculateSpacingAfterSystemElementsCorrected(
    List<MusicalElement> systemElements,
    List<MusicalElement> musicalElements,
  ) {
    // Espaço MÍNIMO após elementos de sistema
    double baseSpacing = staffSpace * 1.2; // MUITO REDUZIDO!

    bool hasClef = systemElements.any((e) => e is Clef);
    bool hasTimeSignature = systemElements.any((e) => e is TimeSignature);

    if (hasClef && hasTimeSignature) {
      // Se tem clave E fórmula de compasso, reduzir ainda mais
      baseSpacing = staffSpace * 1.0; // MÍNIMO!
    } else if (hasClef) {
      baseSpacing = staffSpace * 1.2;
    }

    // Armadura com muitos acidentes precisa de um pouco mais
    for (final element in systemElements) {
      if (element is KeySignature && element.count.abs() >= 4) {
        baseSpacing += staffSpace * 0.3; // Pequeno incremento
      }
    }

    // CORREÇÃO: Verificar se primeira nota tem acidente EXPLÍCITO
    if (musicalElements.isNotEmpty) {
      final firstMusicalElement = musicalElements.first;

      if (firstMusicalElement is Note &&
          firstMusicalElement.pitch.accidentalGlyph != null) {
        baseSpacing += staffSpace * 0.8; // Espaço para acidente explícito
      } else if (firstMusicalElement is Chord) {
        bool hasAccidental = firstMusicalElement.notes.any(
          (note) => note.pitch.accidentalGlyph != null,
        );
        if (hasAccidental) {
          baseSpacing += staffSpace * 0.8;
        }
      }
    }

    return baseSpacing.clamp(
      staffSpace * 1.0,
      staffSpace * 3.0,
    ); // Limites reduçidos
  }

  double _getElementWidthSimple(MusicalElement element) {
    if (element is Clef) {
      double clefWidth;
      switch (element.actualClefType) {
        case ClefType.treble:
        case ClefType.treble8va:
        case ClefType.treble8vb:
        case ClefType.treble15ma:
        case ClefType.treble15mb:
          clefWidth = gClefWidth;
          break;
        case ClefType.bass:
        case ClefType.bassThirdLine:
        case ClefType.bass8va:
        case ClefType.bass8vb:
        case ClefType.bass15ma:
        case ClefType.bass15mb:
          clefWidth = fClefWidth;
          break;
        default:
          clefWidth = cClefWidth;
      }
      return (clefWidth + 0.5) * staffSpace;
    }

    if (element is KeySignature) {
      if (element.count == 0) return 0.5 * staffSpace;
      final accidentalWidth = element.count > 0
          ? accidentalSharpWidth
          : accidentalFlatWidth;
      return (element.count.abs() * 0.8 + accidentalWidth) * staffSpace;
    }

    if (element is TimeSignature) {
      return 3.0 * staffSpace;
    }

    if (element is Note) {
      double width = noteheadBlackWidth * staffSpace;
      if (element.pitch.accidentalGlyph != null) {
        // CORREÇÃO SMuFL: Detecção mais robusta e uso de valores corretos
        final glyphName = element.pitch.accidentalGlyph!;
        double accWidth = accidentalSharpWidth; // Default

        // Identificar tipo de acidente corretamente
        if (glyphName.contains('Flat') || glyphName.contains('flat')) {
          accWidth = accidentalFlatWidth;
        } else if (glyphName.contains('Natural') ||
            glyphName.contains('natural')) {
          accWidth = 0.92; // Largura típica de natural
        } else if (glyphName.contains('DoubleSharp')) {
          accWidth = 1.0; // Largura de dobrado sustenido
        } else if (glyphName.contains('DoubleFlat')) {
          accWidth = 1.5; // Largura de dobrado bemol
        }

        // CORRIGIDO: Espaçamento recomendado SMuFL é 0.25-0.3 staff spaces
        width += (accWidth + 0.3) * staffSpace;
      }
      return width;
    }

    if (element is Rest) {
      return 1.5 * staffSpace;
    }

    if (element is Chord) {
      double width = noteheadBlackWidth * staffSpace;
      double maxAccidentalWidth = 0;

      for (final note in element.notes) {
        if (note.pitch.accidentalGlyph != null) {
          // CORREÇÃO: Usar mesma lógica robusta de detecção que Note
          final glyphName = note.pitch.accidentalGlyph!;
          double accWidth = accidentalSharpWidth;

          if (glyphName.contains('Flat') || glyphName.contains('flat')) {
            accWidth = accidentalFlatWidth;
          } else if (glyphName.contains('Natural') ||
              glyphName.contains('natural')) {
            accWidth = 0.92;
          } else if (glyphName.contains('DoubleSharp')) {
            accWidth = 1.0;
          } else if (glyphName.contains('DoubleFlat')) {
            accWidth = 1.5;
          }
          if (accWidth > maxAccidentalWidth) {
            maxAccidentalWidth = accWidth;
          }
        }
      }

      if (maxAccidentalWidth > 0) {
        width += (maxAccidentalWidth + 0.5) * staffSpace;
      }
      return width;
    }

    if (element is Dynamic) return 2.0 * staffSpace;
    if (element is Ornament) return 1.0 * staffSpace;

    if (element is Tuplet) {
      // CRÍTICO: Calcular largura baseada nas notas INTERNAS do tuplet
      final numElements = element.elements.length;
      final elementSpacing = staffSpace * 2.5; // Mesma do TupletRenderer
      final totalWidth = numElements * elementSpacing;
      return totalWidth;
    }

    if (element is TempoMark)
      return 0.0; // TempoMark renderizado acima, sem largura

    return staffSpace;
  }

  /// CORREÇÃO VISUAL #2: Calcula espaçamento rítmico baseado na duração
  ///
  /// Implementa espaçamento proporcional à duração das notas conforme
  /// práticas profissionais de tipografia musical (Behind Bars, Ted Ross)
  ///
  /// @param currentElement Elemento atual
  /// @param previousElement Elemento anterior (opcional)
  /// @return Espaçamento em pixels
  double _calculateRhythmicSpacing(
    MusicalElement currentElement,
    MusicalElement? previousElement,
  ) {
    // Base: espaçamento mínimo entre notas (semínima como referência)
    const double baseSpacing = noteMinSpacing;

    // Fatores de espaçamento PROPORCIONAIS (modelo √2 aproximado)
    // Progressão geométrica suave para proporção visual correta
    final durationFactors = {
      DurationType.whole: 2.0, // Semibreve: 2x
      DurationType.half: 1.5, // Mínima: 1.5x (√2 ≈ 1.41)
      DurationType.quarter: 1.0, // Semínima: 1x (base)
      DurationType.eighth: 0.8, // Colcheia: 0.8x
      DurationType.sixteenth: 0.7, // Semicolcheia: 0.7x
      DurationType.thirtySecond: 0.6, // Fusa: 0.6x
      DurationType.sixtyFourth: 0.55, // Semifusa: 0.55x
    };

    // Obter duração do elemento atual
    DurationType? currentDuration;
    if (currentElement is Note) {
      currentDuration = currentElement.duration.type;
    } else if (currentElement is Chord) {
      currentDuration = currentElement.duration.type;
    } else if (currentElement is Rest) {
      currentDuration = currentElement.duration.type;
    }

    // Se não for elemento musical rítmico, usar espaçamento base
    if (currentDuration == null) {
      return baseSpacing * staffSpace;
    }

    // Aplicar fator de duração
    final factor = durationFactors[currentDuration] ?? 1.0;
    double spacing = baseSpacing * factor * staffSpace;

    // AJUSTE: Espaçamento adicional para pausas (80% conforme Gould)
    if (currentElement is Rest) {
      spacing *= 1.15; // Pausas têm pouco mais ar
    }

    // AJUSTE: Espaçamento adicional se elemento anterior tem ponto de aumentação
    if (previousElement is Note && previousElement.duration.dots > 0) {
      spacing +=
          staffSpace * 0.2 * previousElement.duration.dots; // REDUZIDO de 0.3
    } else if (previousElement is Chord && previousElement.duration.dots > 0) {
      spacing +=
          staffSpace * 0.2 * previousElement.duration.dots; // REDUZIDO de 0.3
    }

    // AJUSTE: Mais espaçamento se elemento anterior tem acidente
    if (previousElement is Note &&
        previousElement.pitch.accidentalGlyph != null) {
      spacing += staffSpace * 0.15; // REDUZIDO de 0.2
    } else if (previousElement is Chord) {
      final hasAccidental = previousElement.notes.any(
        (note) => note.pitch.accidentalGlyph != null,
      );
      if (hasAccidental) {
        spacing += staffSpace * 0.15; // REDUZIDO de 0.2
      }
    }

    return spacing;
  }

  // CORREÇÃO #9: Processamento de beams considerando anacrusis
  List<MusicalElement> _processBeamsWithAnacrusis(
    List<MusicalElement> elements,
    TimeSignature? timeSignature, {
    bool autoBeaming = true,
    BeamingMode beamingMode = BeamingMode.automatic,
    List<List<int>> manualBeamGroups = const [],
  }) {
    timeSignature ??= TimeSignature(numerator: 4, denominator: 4);

    final notes = elements.whereType<Note>().toList();
    if (notes.isEmpty) return elements;

    // Calcular posição inicial no compasso (para detectar anacrusis)
    for (final element in elements) {
      if (element is Note || element is Rest) {
        break;
      }
    }

    // Agrupar notas considerando anacrusis
    final beamGroups = BeamGrouper.groupNotesForBeaming(
      notes,
      timeSignature,
      autoBeaming: autoBeaming,
      beamingMode: beamingMode,
      manualBeamGroups: manualBeamGroups,
    );

    final processedElements = <MusicalElement>[];
    final processedNotes = <Note>{};

    for (final element in elements) {
      if (element is Note && !processedNotes.contains(element)) {
        BeamGroup? group;
        for (final beamGroup in beamGroups) {
          if (beamGroup.notes.contains(element)) {
            group = beamGroup;
            break;
          }
        }

        if (group != null && group.isValid) {
          for (int i = 0; i < group.notes.length; i++) {
            final note = group.notes[i];
            BeamType? beamType;

            if (i == 0) {
              beamType = BeamType.start;
            } else if (i == group.notes.length - 1) {
              beamType = BeamType.end;
            } else {
              beamType = BeamType.inner;
            }

            final beamedNote = Note(
              pitch: note.pitch,
              duration: note.duration,
              beam: beamType,
              articulations: note.articulations,
              tie: note.tie,
              slur: note.slur,
              ornaments: note.ornaments,
              dynamicElement: note.dynamicElement,
              techniques: note.techniques,
              voice: note.voice,
            );

            processedElements.add(beamedNote);
            processedNotes.add(note);
          }
        } else {
          processedElements.add(element);
          processedNotes.add(element);
        }
      } else if (element is! Note) {
        processedElements.add(element);
      }
    }

    return processedElements;
  }

  double calculateTotalHeight(List<PositionedElement> elements) {
    if (elements.isEmpty) {
      return staffSpace * 8;
    }

    int maxSystem = 0;
    for (final element in elements) {
      if (element.system > maxSystem) {
        maxSystem = element.system;
      }
    }

    final double systemHeight = staffSpace * 10.0;
    final double topMargin = staffSpace * 4.0;
    final double bottomMargin = staffSpace * 2.0;

    return topMargin + ((maxSystem + 1) * systemHeight) + bottomMargin;
  }
}
