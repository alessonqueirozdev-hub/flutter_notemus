// lib/src/layout/layout_engine.dart
// VERSÃƒÆ’O CORRIGIDA: EspaÃƒÂ§amento melhorado e beaming corrigido
// FASE 3: Suporte a BoundingBox hierÃƒÂ¡rquico adicionado
// FASE 2 REFATORAÃƒâ€¡ÃƒÆ’O: Usando tipos do core/

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';
import 'package:flutter_notemus/src/beaming/beam_analyzer.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/layout/beam_grouper.dart';
import 'package:flutter_notemus/src/layout/measure_validator.dart'; // Ã¢Å“â€¦ ADICIONADO
import 'package:flutter_notemus/src/rendering/staff_position_calculator.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';
import 'package:flutter_notemus/src/smufl/smufl_metadata_loader.dart'; // Ã¢Å“â€¦ ADICIONADO
import 'spacing/spacing.dart' as spacing;

class PositionedElement {
  final MusicalElement element;
  final Offset position;
  final int system;

  /// NÃƒÂºmero da voz (1, 2, ...) em contextos polifÃƒÂ´nicos. Null = voz ÃƒÂºnica.
  final int? voiceNumber;

  PositionedElement(
    this.element,
    this.position, {
    this.system = 0,
    this.voiceNumber,
  });

  /// Stable signature used to cheaply compare large positioned element lists.
  ///
  /// The signature intentionally includes element identity/equality semantics,
  /// position, system and voice context so `shouldRepaint` can compare in O(1).
  static int computeSignature(List<PositionedElement> elements) {
    int hash = 17;
    for (final item in elements) {
      hash = Object.hash(
        hash,
        item.element,
        item.position.dx,
        item.position.dy,
        item.system,
        item.voiceNumber,
      );
    }
    return Object.hash(hash, elements.length);
  }
}

/// Layout output bundle with positioned elements and deterministic signature.
class LayoutResult {
  final List<PositionedElement> elements;
  final int signature;

  const LayoutResult({required this.elements, required this.signature});
}

class LayoutCursor {
  final double staffSpace;
  final double availableWidth;
  final double systemMargin;
  final double systemHeight;

  // Mapas para capturar posiÃƒÂ§ÃƒÂµes das notas (para beaming)
  final Map<Note, double>? noteXPositions;
  final Map<Note, int>? noteStaffPositions;
  final Map<Note, double>? noteYPositions; // Ã¢Å“â€¦ NOVO: Y absoluto em pixels

  double _currentX;
  double _currentY;
  int _currentSystem;
  bool _isFirstMeasureInSystem;
  Clef? _currentClef; // Ã¢Å“â€¦ NOVO: Rastrear clave atual

  LayoutCursor({
    required this.staffSpace,
    required this.availableWidth,
    required this.systemMargin,
    this.systemHeight = 10.0,
    this.noteXPositions,
    this.noteStaffPositions,
    this.noteYPositions, // Ã¢Å“â€¦ NOVO
  }) : _currentX = systemMargin,
       _currentY =
           staffSpace *
           5.0, // CORREÃƒâ€¡ÃƒÆ’O CRÃƒÂTICA: Baseline ÃƒÂ© staffSpace * 5, nÃƒÂ£o * 4
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

  /// Set cursor X to an absolute position (used for multi-voice layout)
  void setX(double x) {
    _currentX = x;
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

  /// Adiciona barra dupla final (fim da peÃƒÂ§a)
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

  void addElement(
    MusicalElement element,
    List<PositionedElement> elements, {
    int? voiceNumber,
  }) {
    // Rastrear clave atual
    if (element is Clef) {
      _currentClef = element;
    }

    if (element is Chord && _currentClef != null) {
      for (final note in element.notes) {
        final staffPosition = StaffPositionCalculator.calculate(
          note.pitch,
          _currentClef!,
        );
        final noteY = StaffPositionCalculator.toPixelY(
          staffPosition,
          staffSpace,
          _currentY,
        );
        noteXPositions?[note] = _currentX;
        noteStaffPositions?[note] = staffPosition;
        noteYPositions?[note] = noteY;
      }
      elements.add(
        PositionedElement(
          element,
          Offset(_currentX, _currentY),
          system: _currentSystem,
          voiceNumber: voiceNumber,
        ),
      );
      return;
    }

    double elementY = _currentY;

    if (element is Note && _currentClef != null) {
      noteXPositions?[element] = _currentX;
      final staffPosition = StaffPositionCalculator.calculate(
        element.pitch,
        _currentClef!,
      );
      noteStaffPositions?[element] = staffPosition;
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        _currentY,
      );
      noteYPositions?[element] = noteY;
      elementY = noteY;
    }

    elements.add(
      PositionedElement(
        element,
        Offset(_currentX, elementY),
        system: _currentSystem,
        voiceNumber: voiceNumber,
      ),
    );
  }
}

class LayoutEngine {
  final Staff staff;
  final double availableWidth;
  final double staffSpace;
  final SmuflMetadata? metadata; // Ã¢Å“â€¦ Tipagem correta aplicada

  // Sistema de EspaÃƒÂ§amento Inteligente
  late final spacing.IntelligentSpacingEngine _spacingEngine;

  // Sistema de Beaming AvanÃƒÂ§ado
  late final BeamAnalyzer _beamAnalyzer;
  final Map<Note, double> _noteXPositions = {};
  final Map<Note, int> _noteStaffPositions = {};
  final Map<Note, double> _noteYPositions =
      {}; // Ã¢Å“â€¦ NOVO: Y absoluto em pixels
  final List<AdvancedBeamGroup> _advancedBeamGroups = [];

  // ConfiguraÃƒÂ§ÃƒÂ£o de validaÃƒÂ§ÃƒÂ£o (silenciosa por padrÃƒÂ£o)
  final bool verboseValidation;

  // CORREÃƒâ€¡ÃƒÆ’O SMuFL: Larguras agora consultadas dinamicamente do metadata
  // Valores de fallback mantidos para compatibilidade
  static const double _gClefWidthFallback = 2.684;
  static const double _fClefWidthFallback = 2.756;
  static const double _cClefWidthFallback = 2.796;
  static const double _noteheadBlackWidthFallback = 1.18;
  static const double _accidentalSharpWidthFallback = 1.116;
  static const double _accidentalFlatWidthFallback = 1.18;
  static const double barlineSeparation = 2.5; // EspaÃƒÂ§o DEPOIS da barline
  static const double legerLineExtension = 0.4;

  // ESPAÃƒâ€¡AMENTO INTELIGENTE: Valores balanceados
  static const double systemMargin = 2.5;
  static const double measureMinWidth = 5.0;
  static const double noteMinSpacing =
      3.5; // Base para espaÃƒÂ§amento entre notas
  static const double measureEndPadding =
      3.0; // EspaÃƒÂ§o adequado ANTES da barline (agora corrigido!)

  // QUEBRA DE LINHA INTELIGENTE
  static const int measuresPerSystem = 4; // Compassos por linha

  LayoutEngine(
    this.staff, {
    required this.availableWidth,
    this.staffSpace = 12.0,
    this.metadata,
    this.verboseValidation = false, // Silencioso por padrÃƒÂ£o
    spacing.SpacingPreferences? spacingPreferences,
  }) {
    // Inicializar motor de espaÃƒÂ§amento
    _spacingEngine = spacing.IntelligentSpacingEngine(
      preferences: spacingPreferences ?? spacing.SpacingPreferences.normal,
    );
    _spacingEngine.initializeOpticalCompensator(staffSpace);

    // Inicializar positioning engine para beaming
    // VALIDAÃƒâ€¡ÃƒÆ’O: metadata pode ser null em alguns contextos
    if (metadata == null) {
      throw ArgumentError(
        'metadata ÃƒÂ© obrigatÃƒÂ³rio para beaming avanÃƒÂ§ado',
      );
    }
    final positioningEngine = SMuFLPositioningEngine(metadataLoader: metadata!);

    // Inicializar sistema de beaming avanÃƒÂ§ado
    _beamAnalyzer = BeamAnalyzer(
      staffSpace: staffSpace,
      noteheadWidth: noteheadBlackWidth * staffSpace,
      positioningEngine: positioningEngine,
    );
  }

  /// ObtÃƒÂ©m largura de glifo dinamicamente do metadata ou retorna fallback
  double _getGlyphWidth(String glyphName, double fallback) {
    if (metadata != null && metadata!.hasGlyph(glyphName)) {
      return metadata!.getGlyphWidth(glyphName);
    }
    return fallback;
  }

  /// Largura da clave de Sol (G clef)
  double get gClefWidth => _getGlyphWidth('gClef', _gClefWidthFallback);

  /// Largura da clave de FÃƒÂ¡ (F clef)
  double get fClefWidth => _getGlyphWidth('fClef', _fClefWidthFallback);

  /// Largura da clave de DÃƒÂ³ (C clef)
  double get cClefWidth => _getGlyphWidth('cClef', _cClefWidthFallback);

  /// Largura da cabeÃƒÂ§a de nota preta
  double get noteheadBlackWidth =>
      _getGlyphWidth('noteheadBlack', _noteheadBlackWidthFallback);

  /// Largura do sustenido
  double get accidentalSharpWidth =>
      _getGlyphWidth('accidentalSharp', _accidentalSharpWidthFallback);

  /// Largura do bemol
  double get accidentalFlatWidth =>
      _getGlyphWidth('accidentalFlat', _accidentalFlatWidthFallback);

  /// Retorna os Advanced Beam Groups calculados pelo ÃƒÂºltimo layout
  List<AdvancedBeamGroup> get advancedBeamGroups =>
      List.unmodifiable(_advancedBeamGroups);

  /// Ã¢Å“â€¦ Expor posiÃƒÂ§ÃƒÂµes X das notas para renderizaÃƒÂ§ÃƒÂ£o precisa
  Map<Note, double> get noteXPositions => Map.unmodifiable(_noteXPositions);

  /// Ã¢Å“â€¦ Expor posiÃƒÂ§ÃƒÂµes Y das notas para renderizaÃƒÂ§ÃƒÂ£o de hastes
  Map<Note, double> get noteYPositions => Map.unmodifiable(_noteYPositions);

  List<PositionedElement> layout() {
    return _layoutInternal();
  }

  LayoutResult layoutWithSignature() {
    final elements = _layoutInternal();
    return LayoutResult(
      elements: elements,
      signature: PositionedElement.computeSignature(elements),
    );
  }

  List<PositionedElement> _layoutInternal() {
    // Limpar mapas de posiÃƒÂ§ÃƒÂµes
    _noteXPositions.clear();
    _noteStaffPositions.clear();
    _noteYPositions.clear(); // Ã¢Å“â€¦ NOVO
    _advancedBeamGroups.clear();

    final cursor = LayoutCursor(
      staffSpace: staffSpace,
      availableWidth: availableWidth,
      systemMargin: systemMargin * staffSpace,
      noteXPositions: _noteXPositions,
      noteStaffPositions: _noteStaffPositions,
      noteYPositions: _noteYPositions, // Ã¢Å“â€¦ NOVO
    );

    final List<PositionedElement> positionedElements = [];

    // Armazenar compassos por sistema para justificaÃƒÂ§ÃƒÂ£o
    final systemMeasures = <int, List<int>>{};
    final measureStartIndices = <int, int>{};

    // Sistema de heranÃƒÂ§a de TimeSignature
    TimeSignature? currentTimeSignature;

    // Contador de validaÃƒÂ§ÃƒÂ£o (apenas para estatÃƒÂ­sticas)
    int validMeasures = 0;
    int invalidMeasures = 0;

    for (int i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      final isFirst = cursor.isFirstMeasureInSystem;
      final isLast = i == staff.measures.length - 1;
      final isLastInSystem = (i + 1) % measuresPerSystem == 0 && !isLast;

      // HERANÃƒâ€¡A DE TIME SIGNATURE: Procurar no compasso atual
      TimeSignature? measureTimeSignature;
      for (final element in measure.elements) {
        if (element is TimeSignature) {
          measureTimeSignature = element;
          currentTimeSignature = element; // Atualizar TimeSignature corrente
          break;
        }
      }

      // Se nÃƒÂ£o encontrou, usar o TimeSignature herdado
      final timeSignatureToUse = measureTimeSignature ?? currentTimeSignature;

      // Definir TimeSignature herdado no Measure para validaÃƒÂ§ÃƒÂ£o preventiva
      if (timeSignatureToUse != null && measureTimeSignature == null) {
        measure.inheritedTimeSignature = timeSignatureToUse;
      }

      // Ã¢Å“â€¦ ValidaÃƒÂ§ÃƒÂ£o de compasso (silenciosa - apenas estatÃƒÂ­sticas)
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

      // QUEBRA INTELIGENTE: A cada N compassos OU se nÃƒÂ£o couber
      if (!isFirst &&
          (isLastInSystem || cursor.needsSystemBreak(measureWidth))) {
        cursor.startNewSystem();
      }

      // Guardar ÃƒÂ­ndice inicial do compasso para justificaÃƒÂ§ÃƒÂ£o
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

      // Verificar se PRÃƒâ€œXIMO compasso comeÃƒÂ§a com barline (ex: repeat)
      final nextMeasure = (i < staff.measures.length - 1)
          ? staff.measures[i + 1]
          : null;
      final nextMeasureStartsWithBarline =
          nextMeasure != null &&
          nextMeasure.elements.isNotEmpty &&
          nextMeasure.elements.first is Barline;

      // Adicionar barline apropriada SOMENTE se:
      // 1. PrÃƒÂ³ximo compasso nÃƒÂ£o comeÃƒÂ§ar com uma
      // 2. Compasso atual nÃƒÂ£o terminar com uma
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
        // Compasso termina com barline OU prÃƒÂ³ximo comeÃƒÂ§a com barline - apenas adicionar padding
        cursor.advance(measureEndPadding * staffSpace);
      }

      cursor.endMeasure();
    }

    // RelatÃƒÂ³rio resumido (apenas se verbose)
    if (verboseValidation && (validMeasures + invalidMeasures) > 0) {}

    // JUSTIFICAÃƒâ€¡ÃƒÆ’O HORIZONTAL: Esticar compassos para preencher largura
    _justifyHorizontally(positionedElements, systemMeasures);

    // Sincronizar _noteXPositions com as posiÃƒÂ§ÃƒÂµes pÃƒÂ³s-justificaÃƒÂ§ÃƒÂ£o.
    // _justifyHorizontally modifica positionedElements mas nÃƒÂ£o _noteXPositions,
    // causando desalinhamento entre beams (que usam _noteXPositions) e noteheads.
    for (final positioned in positionedElements) {
      if (positioned.element is Note) {
        final note = positioned.element as Note;
        if (_noteXPositions.containsKey(note)) {
          _noteXPositions[note] = positioned.position.dx;
        }
      }
    }

    // ANÃƒÂLISE DE BEAMING AVANÃƒâ€¡ADO: Criar AdvancedBeamGroups
    _analyzeBeamGroups(currentTimeSignature, positionedElements);

    return positionedElements;
  }

  /// Analisa beam groups e cria AdvancedBeamGroups para renderizaÃƒÂ§ÃƒÂ£o
  /// Ã¢Å“â€¦ CORREÃƒâ€¡ÃƒÆ’O: Usar notas PROCESSADAS de positionedElements, nÃƒÂ£o de measure.elements
  void _analyzeBeamGroups(
    TimeSignature? timeSignature,
    List<PositionedElement> positionedElements,
  ) {
    if (timeSignature == null) {
      return;
    }

    // Ã¢Å“â€¦ CORREÃƒâ€¡ÃƒÆ’O: Extrair notas PROCESSADAS diretamente de positionedElements
    // As notas processadas sÃƒÂ£o aquelas que foram adicionadas aos mapas
    final processedNotes = positionedElements
        .where((p) => p.element is Note)
        .map((p) => p.element as Note)
        .toList();

    if (processedNotes.isEmpty) {
      return;
    }

    // Usar beam types jÃƒÂ¡ atribuÃƒÂ­dos por _processBeamsWithAnacrusis para identificar grupos.
    // NÃƒÆ’O chamar BeamGrouper novamente, pois ele processa todas as notas em conjunto
    // sem respeitar limites de compasso, causando agrupamentos incorretos entre compassos.
    List<Note>? currentGroup;
    for (final note in processedNotes) {
      switch (note.beam) {
        case BeamType.start:
          currentGroup = [note];
        case BeamType.inner:
          currentGroup?.add(note);
        case BeamType.end:
          if (currentGroup != null) {
            currentGroup.add(note);
            if (currentGroup.length >= 2) {
              try {
                final advancedGroup = _beamAnalyzer.analyzeAdvancedBeamGroup(
                  currentGroup,
                  timeSignature,
                  noteXPositions: _noteXPositions,
                  noteStaffPositions: _noteStaffPositions,
                  noteYPositions: _noteYPositions,
                );
                _advancedBeamGroups.add(advancedGroup);
              } catch (_) {
                // Ignore beam analysis errors for individual groups
              }
            }
            currentGroup = null;
          }
        case null:
          currentGroup = null;
      }
    }
  }

  /// Justifica horizontalmente os compassos para preencher a largura disponÃƒÂ­vel
  void _justifyHorizontally(
    List<PositionedElement> elements,
    Map<int, List<int>> systemMeasures,
  ) {
    final usableWidth = availableWidth - (systemMargin * staffSpace * 2);

    for (final entry in systemMeasures.entries) {
      final system = entry.key;
      final measures = entry.value;

      if (measures.isEmpty) continue;

      // Encontrar X mÃƒÂ­nimo e mÃƒÂ¡ximo dos elementos neste sistema
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

      // Se hÃƒÂ¡ espaÃƒÂ§o extra, distribuir proporcionalmente
      if (extraSpace > 0 && measures.length > 1) {
        // Ajustar posiÃƒÂ§ÃƒÂµes dos elementos apÃƒÂ³s cada compasso
        for (int i = 0; i < elements.length; i++) {
          final positioned = elements[i];
          if (positioned.system != system) continue;

          // Calcular proporÃƒÂ§ÃƒÂ£o de posiÃƒÂ§ÃƒÂ£o no sistema (simplificado)
          final positionRatio = (maxX - minX) > 0
              ? (positioned.position.dx - minX) / (maxX - minX)
              : 0.0;

          // Aplicar offset proporcional baseado na posiÃƒÂ§ÃƒÂ£o
          final offset = extraSpace * positionRatio;
          elements[i] = PositionedElement(
            positioned.element,
            Offset(positioned.position.dx + offset, positioned.position.dy),
            system: positioned.system,
            voiceNumber: positioned.voiceNumber,
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

  void _layoutMultiVoiceMeasure(
    MultiVoiceMeasure measure,
    LayoutCursor cursor,
    List<PositionedElement> positionedElements,
    bool isFirstInSystem,
  ) {
    final startX = cursor.currentX;
    double maxAdvanceX = startX;
    // Tracks where musical elements (post clef/key/time) start in voice 1.
    // Voices 2+ must start at this X so notes align with voice 1.
    double firstMusicX = startX;
    final leadTimelineAnchors = <({double time, double x})>[];
    double leadTotalTime = 0.0;

    final sortedVoices = measure.sortedVoices;

    for (int voiceIdx = 0; voiceIdx < sortedVoices.length; voiceIdx++) {
      final voice = sortedVoices[voiceIdx];

      // Voices 2+ skip system elements and start where voice 1's music begins
      final isLeadVoice = voiceIdx == 0;
      cursor.setX(isLeadVoice ? startX : firstMusicX);

      // Processar beaming separadamente para cada voz
      final processedElements = _processBeamsWithAnacrusis(
        voice.elements,
        measure.timeSignature,
        autoBeaming: measure.autoBeaming,
        beamingMode: measure.beamingMode,
        manualBeamGroups: measure.manualBeamGroups,
      );

      // Voice 2+ never renders system elements (clef/key/time sig belong to voice 1)
      final elementsToRender = processedElements.where((element) {
        if (!isLeadVoice && _isSystemElement(element)) return false;
        return isFirstInSystem || !_isSystemElement(element);
      }).toList();

      bool seenFirstMusicElement =
          !isLeadVoice; // voice 2+ already positioned past system elements
      double voiceTime = 0.0;

      for (int i = 0; i < elementsToRender.length; i++) {
        final element = elementsToRender[i];

        if (i > 0 && isLeadVoice) {
          final previousElement = elementsToRender[i - 1];
          cursor.advance(_calculateRhythmicSpacing(element, previousElement));
        } else if (i > 0 && !isLeadVoice && leadTimelineAnchors.isEmpty) {
          // Fallback se nÃƒÂ£o houver ÃƒÂ¢ncoras da voz principal.
          final previousElement = elementsToRender[i - 1];
          cursor.advance(_calculateRhythmicSpacing(element, previousElement));
        }

        // Record where voice 1's first non-system element lands so other voices align
        if (isLeadVoice &&
            !seenFirstMusicElement &&
            !_isSystemElement(element)) {
          seenFirstMusicElement = true;
          firstMusicX = cursor.currentX;
        }

        if (isLeadVoice && !_isSystemElement(element)) {
          _addTimelineAnchor(
            leadTimelineAnchors,
            leadTotalTime,
            cursor.currentX,
          );
        }

        if (!isLeadVoice &&
            !_isSystemElement(element) &&
            leadTimelineAnchors.isNotEmpty) {
          final alignedX = _interpolateTimelineX(
            leadTimelineAnchors,
            voiceTime,
            fallbackX: cursor.currentX,
          );
          cursor.setX(alignedX);
        }

        // Aplicar offset horizontal da voz ÃƒÂ  posiÃƒÂ§ÃƒÂ£o X
        final savedX = cursor.currentX;
        cursor.addElement(
          element,
          positionedElements,
          voiceNumber: voice.number,
        );
        cursor.setX(savedX);

        cursor.advance(_getElementWidthSimple(element));

        if (!_isSystemElement(element)) {
          final rhythmicValue = _getRhythmicValue(element);
          if (isLeadVoice) {
            leadTotalTime += rhythmicValue;
          } else {
            voiceTime += rhythmicValue;
          }
        }

        if (cursor.currentX > maxAdvanceX) {
          maxAdvanceX = cursor.currentX;
        }
      }

      if (isLeadVoice && leadTimelineAnchors.isNotEmpty) {
        _addTimelineAnchor(leadTimelineAnchors, leadTotalTime, cursor.currentX);
      }
    }

    cursor.setX(maxAdvanceX);
  }

  void _addTimelineAnchor(
    List<({double time, double x})> anchors,
    double time,
    double x,
  ) {
    if (anchors.isEmpty) {
      anchors.add((time: time, x: x));
      return;
    }

    final last = anchors.last;
    if ((last.time - time).abs() < 0.000001) {
      anchors[anchors.length - 1] = (time: time, x: x);
    } else {
      anchors.add((time: time, x: x));
    }
  }

  double _interpolateTimelineX(
    List<({double time, double x})> anchors,
    double time, {
    required double fallbackX,
  }) {
    if (anchors.isEmpty) return fallbackX;

    if (time <= anchors.first.time) {
      return anchors.first.x;
    }

    if (time >= anchors.last.time) {
      return anchors.last.x;
    }

    for (int i = 0; i < anchors.length - 1; i++) {
      final left = anchors[i];
      final right = anchors[i + 1];
      if (time < left.time || time > right.time) continue;

      final span = right.time - left.time;
      if (span.abs() < 0.000001) return left.x;
      final ratio = (time - left.time) / span;
      return left.x + ((right.x - left.x) * ratio);
    }

    return fallbackX;
  }

  double _getRhythmicValue(MusicalElement element) {
    if (element is Note) return element.duration.realValue;
    if (element is Rest) return element.duration.realValue;
    if (element is Chord) return element.duration.realValue;
    if (element is Tuplet) return element.totalDuration;
    return 0.0;
  }

  void _layoutMeasureCursor(
    Measure measure,
    LayoutCursor cursor,
    List<PositionedElement> positionedElements,
    bool isFirstInSystem,
  ) {
    // Handle MultiVoiceMeasure: layout each voice independently
    if (measure is MultiVoiceMeasure) {
      _layoutMultiVoiceMeasure(
        measure,
        cursor,
        positionedElements,
        isFirstInSystem,
      );
      return;
    }
    // CORREÃƒâ€¡ÃƒÆ’O #9: Processar beaming considerando anacrusis
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

    // CORREÃƒâ€¡ÃƒÆ’O #3: EspaÃƒÂ§amento inteligente melhorado
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
        // CORREÃƒâ€¡ÃƒÆ’O VISUAL #2: Usar espaÃƒÂ§amento rÃƒÂ­tmico ao invÃƒÂ©s de constante
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
        element is TimeSignature;
  }

  // ESPAÃƒâ€¡AMENTO APÃƒâ€œS ELEMENTOS DE SISTEMA: MÃƒÂNIMO necessÃƒÂ¡rio
  double _calculateSpacingAfterSystemElementsCorrected(
    List<MusicalElement> systemElements,
    List<MusicalElement> musicalElements,
  ) {
    // EspaÃƒÂ§o MÃƒÂNIMO apÃƒÂ³s elementos de sistema
    double baseSpacing = staffSpace * 1.2; // MUITO REDUZIDO!

    bool hasClef = systemElements.any((e) => e is Clef);
    bool hasTimeSignature = systemElements.any((e) => e is TimeSignature);

    if (hasClef && hasTimeSignature) {
      // Se tem clave E fÃƒÂ³rmula de compasso, reduzir ainda mais
      baseSpacing = staffSpace * 1.0; // MÃƒÂNIMO!
    } else if (hasClef) {
      baseSpacing = staffSpace * 1.2;
    }

    // Armadura com muitos acidentes precisa de um pouco mais
    for (final element in systemElements) {
      if (element is KeySignature && element.count.abs() >= 4) {
        baseSpacing += staffSpace * 0.3; // Pequeno incremento
      }
    }

    // CORREÃƒâ€¡ÃƒÆ’O: Verificar se primeira nota tem acidente EXPLÃƒÂCITO
    if (musicalElements.isNotEmpty) {
      final firstMusicalElement = musicalElements.first;

      if (firstMusicalElement is Note &&
          firstMusicalElement.pitch.accidentalGlyph != null) {
        baseSpacing += staffSpace * 0.8; // EspaÃƒÂ§o para acidente explÃƒÂ­cito
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
    ); // Limites reduÃƒÂ§idos
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
        // CORREÃƒâ€¡ÃƒÆ’O SMuFL: DetecÃƒÂ§ÃƒÂ£o mais robusta e uso de valores corretos
        final glyphName = element.pitch.accidentalGlyph!;
        double accWidth = accidentalSharpWidth; // Default

        // Identificar tipo de acidente corretamente
        if (glyphName.contains('Flat') || glyphName.contains('flat')) {
          accWidth = accidentalFlatWidth;
        } else if (glyphName.contains('Natural') ||
            glyphName.contains('natural')) {
          accWidth = 0.92; // Largura tÃƒÂ­pica de natural
        } else if (glyphName.contains('DoubleSharp')) {
          accWidth = 1.0; // Largura de dobrado sustenido
        } else if (glyphName.contains('DoubleFlat')) {
          accWidth = 1.5; // Largura de dobrado bemol
        }

        // CORRIGIDO: EspaÃƒÂ§amento recomendado SMuFL ÃƒÂ© 0.25-0.3 staff spaces
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
          // CORREÃƒâ€¡ÃƒÆ’O: Usar mesma lÃƒÂ³gica robusta de detecÃƒÂ§ÃƒÂ£o que Note
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

    if (element is RepeatMark) {
      return _estimateRepeatMarkWidth(element);
    }

    if (element is MusicText) {
      return _estimateMusicTextWidth(element);
    }

    if (element is Dynamic) return 2.0 * staffSpace;
    if (element is Ornament) return 1.0 * staffSpace;

    if (element is Tuplet) {
      // CRÃƒÂTICO: Calcular largura baseada nas notas INTERNAS do tuplet
      final numElements = element.elements.length;
      final elementSpacing = staffSpace * 2.5; // Mesma do TupletRenderer
      final totalWidth = numElements * elementSpacing;
      return totalWidth;
    }

    if (element is TempoMark) {
      return _estimateTempoMarkWidth(element);
    }

    if (element is VoltaBracket) {
      return 0.0; // VoltaBracket renderizado acima, sem largura
    }

    if (element is OctaveMark) {
      return 0.0; // OctaveMark renderizado acima, sem largura
    }

    return staffSpace;
  }

  double _estimateMusicTextWidth(MusicText text) {
    final trimmedText = text.text.trim();
    if (trimmedText.isEmpty) {
      return 0.0;
    }

    final fontSize = text.fontSize ?? _defaultMusicTextFontSize(text.type);
    return _estimatePlainTextWidth(
      trimmedText,
      fontSize: fontSize,
      averageCharacterFactor: 0.58,
      horizontalPadding: coordinatesTextPaddingFor(text.type),
    );
  }

  double _estimateRepeatMarkWidth(RepeatMark repeatMark) {
    final fallbackText = _repeatMarkFallbackTextForLayout(repeatMark.type);
    if (fallbackText != null) {
      return _estimatePlainTextWidth(
        fallbackText,
        fontSize: staffSpace * 1.25,
        averageCharacterFactor: 0.62,
        horizontalPadding: staffSpace,
      );
    }

    final glyphName = _getRepeatMarkGlyphNameForLayout(repeatMark.type);
    final scale = _getRepeatMarkScaleForLayout(repeatMark.type);
    double width = staffSpace * 1.8;

    if (glyphName != null) {
      width =
          (_getGlyphWidth(glyphName, noteheadBlackWidth) * staffSpace * scale) +
          (staffSpace * 0.75);
    } else {
      switch (repeatMark.type) {
        case RepeatType.repeat4Bars:
          width = staffSpace * 2.6;
          break;
        case RepeatType.repeat2Bars:
        case RepeatType.simile:
        case RepeatType.percentRepeat:
          width = staffSpace * 2.2;
          break;
        default:
          break;
      }
    }

    if (_getRepeatCountLabelForLayout(repeatMark) != null) {
      width += staffSpace * 0.65;
    }

    if (width < staffSpace * 1.6) {
      width = staffSpace * 1.6;
    }

    return width;
  }

  double _estimatePlainTextWidth(
    String text, {
    required double fontSize,
    required double averageCharacterFactor,
    required double horizontalPadding,
  }) {
    return (text.length * fontSize * averageCharacterFactor) +
        horizontalPadding;
  }

  double _defaultMusicTextFontSize(TextType type) {
    switch (type) {
      case TextType.tempo:
        return staffSpace * 1.3;
      case TextType.expression:
      case TextType.instruction:
      case TextType.dynamics:
        return staffSpace * 1.1;
      default:
        return staffSpace;
    }
  }

  double coordinatesTextPaddingFor(TextType type) {
    switch (type) {
      case TextType.tempo:
        return staffSpace * 1.1;
      case TextType.expression:
      case TextType.instruction:
      case TextType.dynamics:
        return staffSpace * 0.9;
      default:
        return staffSpace * 0.7;
    }
  }

  String? _repeatMarkFallbackTextForLayout(RepeatType type) {
    switch (type) {
      case RepeatType.dalSegno:
        return 'D.S.';
      case RepeatType.dalSegnoAlCoda:
        return 'D.S. al Coda';
      case RepeatType.dalSegnoAlFine:
        return 'D.S. al Fine';
      case RepeatType.daCapo:
        return 'D.C.';
      case RepeatType.daCapoAlCoda:
        return 'D.C. al Coda';
      case RepeatType.daCapoAlFine:
        return 'D.C. al Fine';
      case RepeatType.fine:
        return 'Fine';
      case RepeatType.toCoda:
        return 'To Coda';
      default:
        return null;
    }
  }

  String? _getRepeatMarkGlyphNameForLayout(RepeatType type) {
    for (final glyph in _repeatGlyphCandidatesForLayout(type)) {
      if (metadata != null && metadata!.hasGlyph(glyph)) {
        return glyph;
      }
    }
    return null;
  }

  List<String> _repeatGlyphCandidatesForLayout(RepeatType type) {
    switch (type) {
      case RepeatType.segno:
        return const ['segno'];
      case RepeatType.coda:
        return const ['coda'];
      case RepeatType.segnoSquare:
        return const ['segnoSerpent1', 'segno'];
      case RepeatType.codaSquare:
        return const ['codaSquare', 'coda'];
      case RepeatType.repeat1Bar:
        return const ['repeat1Bar'];
      case RepeatType.repeat2Bars:
        return const ['repeat2Bars'];
      case RepeatType.repeat4Bars:
        return const ['repeat4Bars'];
      case RepeatType.simile:
        return const ['simile', 'repeatBarSlash'];
      case RepeatType.percentRepeat:
        return const ['percent', 'repeatSlash'];
      case RepeatType.repeatDots:
        return const ['repeatDots'];
      case RepeatType.repeatLeft:
      case RepeatType.start:
        return const ['repeatLeft'];
      case RepeatType.repeatRight:
      case RepeatType.end:
        return const ['repeatRight'];
      case RepeatType.repeatBoth:
        return const ['repeatLeftRight'];
      case RepeatType.dalSegno:
      case RepeatType.dalSegnoAlCoda:
      case RepeatType.dalSegnoAlFine:
      case RepeatType.daCapo:
      case RepeatType.daCapoAlCoda:
      case RepeatType.daCapoAlFine:
      case RepeatType.fine:
      case RepeatType.toCoda:
        return const [];
    }
  }

  double _getRepeatMarkScaleForLayout(RepeatType type) {
    switch (type) {
      case RepeatType.segno:
      case RepeatType.coda:
      case RepeatType.segnoSquare:
      case RepeatType.codaSquare:
        return 0.64;
      case RepeatType.repeat1Bar:
      case RepeatType.simile:
      case RepeatType.percentRepeat:
        return 0.92;
      case RepeatType.repeat2Bars:
      case RepeatType.repeat4Bars:
        return 0.9;
      case RepeatType.repeatDots:
      case RepeatType.repeatLeft:
      case RepeatType.repeatRight:
      case RepeatType.repeatBoth:
      case RepeatType.start:
      case RepeatType.end:
        return 1.0;
      case RepeatType.dalSegno:
      case RepeatType.dalSegnoAlCoda:
      case RepeatType.dalSegnoAlFine:
      case RepeatType.daCapo:
      case RepeatType.daCapoAlCoda:
      case RepeatType.daCapoAlFine:
      case RepeatType.fine:
      case RepeatType.toCoda:
        return 0.9;
    }
  }

  String? _getRepeatCountLabelForLayout(RepeatMark repeatMark) {
    if (repeatMark.times != null) {
      return repeatMark.times!.toString();
    }

    switch (repeatMark.type) {
      case RepeatType.repeat2Bars:
        return '2';
      case RepeatType.repeat4Bars:
        return '4';
      default:
        return null;
    }
  }

  double _estimateTempoMarkWidth(TempoMark tempo) {
    double width = 0.0;
    final tempoText = tempo.text?.trim();

    if (tempoText != null && tempoText.isNotEmpty) {
      double textUnits = tempoText.length * 0.38;
      if (textUnits < 2.4) {
        textUnits = 2.4;
      }
      width += textUnits * staffSpace;
    }

    if (tempo.bpm != null && tempo.showMetronome) {
      width +=
          (tempoText == null || tempoText.isEmpty ? 0.8 : 1.1) * staffSpace;

      final metronomeGlyphName = _getTempoMetronomeGlyphName(tempo.beatUnit);
      final metronomeGlyphWidth = _getGlyphWidth(
        metronomeGlyphName,
        noteheadBlackWidth,
      );
      width += metronomeGlyphWidth * staffSpace * 0.46;

      final bpmDigits = tempo.bpm!.abs().toString().length;
      width += (2.6 + (bpmDigits * 0.55)) * staffSpace;
    }

    return width;
  }

  String _getTempoMetronomeGlyphName(DurationType durationType) {
    switch (durationType) {
      case DurationType.maxima:
      case DurationType.long:
      case DurationType.breve:
        return 'metNoteDoubleWhole';
      case DurationType.whole:
        return 'metNoteWhole';
      case DurationType.half:
        return 'metNoteHalfUp';
      case DurationType.quarter:
        return 'metNoteQuarterUp';
      case DurationType.eighth:
        return 'metNote8thUp';
      case DurationType.sixteenth:
        return 'metNote16thUp';
      case DurationType.thirtySecond:
        return 'metNote32ndUp';
      case DurationType.sixtyFourth:
        return 'metNote64thUp';
      case DurationType.oneHundredTwentyEighth:
      case DurationType.twoHundredFiftySixth:
      case DurationType.fiveHundredTwelfth:
      case DurationType.thousandTwentyFourth:
      case DurationType.twoThousandFortyEighth:
        return 'metNote128thUp';
    }
  }

  /// CORREÃƒâ€¡ÃƒÆ’O VISUAL #2: Calcula espaÃƒÂ§amento rÃƒÂ­tmico baseado na duraÃƒÂ§ÃƒÂ£o
  ///
  /// Implementa espaÃƒÂ§amento proporcional ÃƒÂ  duraÃƒÂ§ÃƒÂ£o das notas conforme
  /// prÃƒÂ¡ticas profissionais de tipografia musical (Behind Bars, Ted Ross)
  ///
  /// @param currentElement Elemento atual
  /// @param previousElement Elemento anterior (opcional)
  /// @return EspaÃƒÂ§amento em pixels
  double _calculateRhythmicSpacing(
    MusicalElement currentElement,
    MusicalElement? previousElement,
  ) {
    // Base: espaÃƒÂ§amento mÃƒÂ­nimo entre notas (semÃƒÂ­nima como referÃƒÂªncia)
    const double baseSpacing = noteMinSpacing;

    // Fatores de espaÃƒÂ§amento PROPORCIONAIS (modelo Ã¢Ë†Å¡2 aproximado)
    // ProgressÃƒÂ£o geomÃƒÂ©trica suave para proporÃƒÂ§ÃƒÂ£o visual correta
    final durationFactors = {
      DurationType.whole: 2.0, // Semibreve: 2x
      DurationType.half: 1.5, // MÃƒÂ­nima: 1.5x (Ã¢Ë†Å¡2 Ã¢â€°Ë† 1.41)
      DurationType.quarter: 1.0, // SemÃƒÂ­nima: 1x (base)
      DurationType.eighth: 0.8, // Colcheia: 0.8x
      DurationType.sixteenth: 0.7, // Semicolcheia: 0.7x
      DurationType.thirtySecond: 0.6, // Fusa: 0.6x
      DurationType.sixtyFourth: 0.55, // Semifusa: 0.55x
    };

    // Obter duraÃƒÂ§ÃƒÂ£o do elemento atual
    DurationType? currentDuration;
    if (currentElement is Note) {
      currentDuration = currentElement.duration.type;
    } else if (currentElement is Chord) {
      currentDuration = currentElement.duration.type;
    } else if (currentElement is Rest) {
      currentDuration = currentElement.duration.type;
    }

    // Se nÃƒÂ£o for elemento musical rÃƒÂ­tmico, usar espaÃƒÂ§amento base
    if (currentDuration == null) {
      return baseSpacing * staffSpace;
    }

    // Aplicar fator de duraÃƒÂ§ÃƒÂ£o
    final factor = durationFactors[currentDuration] ?? 1.0;
    double spacing = baseSpacing * factor * staffSpace;

    // AJUSTE: EspaÃƒÂ§amento adicional para pausas (80% conforme Gould)
    if (currentElement is Rest) {
      spacing *= 1.15; // Pausas tÃƒÂªm pouco mais ar
    }

    // AJUSTE: EspaÃƒÂ§amento adicional se elemento anterior tem ponto de aumentaÃƒÂ§ÃƒÂ£o
    if (previousElement is Note && previousElement.duration.dots > 0) {
      spacing +=
          staffSpace * 0.2 * previousElement.duration.dots; // REDUZIDO de 0.3
    } else if (previousElement is Chord && previousElement.duration.dots > 0) {
      spacing +=
          staffSpace * 0.2 * previousElement.duration.dots; // REDUZIDO de 0.3
    }

    // AJUSTE: Mais espaÃƒÂ§amento se elemento anterior tem acidente
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

  // CORREÃƒâ€¡ÃƒÆ’O #9: Processamento de beams considerando anacrusis
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

    // Calcular posiÃƒÂ§ÃƒÂ£o inicial no compasso (para detectar anacrusis)
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
              tremoloStrokes: note.tremoloStrokes,
              isGraceNote: note.isGraceNote,
              alternatePitch: note.alternatePitch,
              tabFret: note.tabFret,
              tabString: note.tabString,
            );
            beamedNote.xmlId = note.xmlId;

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
