// lib/src/layout/layout_engine.dart
// Corrected implementation: Spacing melhorado and beaming corrigido
// Suporte a Hierarchical BoundingBox added
// Refactoring pass: Using tipos of the core/

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';
import 'package:flutter_notemus/src/beaming/beam_analyzer.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/layout/beam_grouper.dart';
import 'package:flutter_notemus/src/layout/measure_validator.dart'; // ✅ ADICIONADO
import 'package:flutter_notemus/src/rendering/accidental_resolver.dart';
import 'package:flutter_notemus/src/rendering/staff_position_calculator.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';
import 'package:flutter_notemus/src/smufl/smufl_metadata_loader.dart'; // ✅ ADICIONADO
import 'package:flutter_notemus/src/rendering/text_font.dart';
import 'package:flutter_notemus/src/utils/lru_cache.dart';
import 'onset_grid.dart';
import 'tuplet_grid.dart';
import 'spacing/spacing.dart' as spacing;

class PositionedElement {
  final MusicalElement element;
  final Offset position;
  final int system;

  /// Voice number (1, 2, ...) in polyphonic contexts. Null = single voice.
  final int? voiceNumber;

  /// Musical onset of this element, measured in whole notes from the start of
  /// the staff (a quarter note is 0.25). Non-rhythmic elements inherit the
  /// onset of the position they occupy.
  ///
  /// This is the shared time coordinate that lets several staves be aligned on
  /// one grid (see `GrandStaffPainter`): two events with the same onset must
  /// end up at the same X, whatever their individual spacing needs.
  final double onset;

  /// Index of the measure this element belongs to, or -1 when unknown.
  /// Used for measure numbering and for future selection by bar.
  final int measureIndex;

  /// Y of the staff's MIDDLE LINE for the system this element sits on.
  ///
  /// [position] does not mean the same thing for every element: for a [Note] it
  /// is the NOTEHEAD (so the pitch is readable straight off it), while for a
  /// [Chord], a [Clef] or a [Barline] it is the staff baseline. That asymmetry
  /// is a genuine trap — `ScoreHitTester` built a chord's box around
  /// `position.dy` and so drew it around the STAFF while the chord's noteheads
  /// were an octave above it, making high chords unclickable.
  ///
  /// This field removes the ambiguity: whatever `position` means for a given
  /// element, the staff it belongs to is always right here.
  final double staffBaselineY;

  PositionedElement(
    this.element,
    this.position, {
    this.system = 0,
    this.voiceNumber,
    this.onset = 0.0,
    this.measureIndex = -1,
    this.staffBaselineY = 0.0,
  });

  /// A copy of this element placed at [newPosition], keeping every other field.
  ///
  /// The post-layout passes (justification, full-bar-rest centring, cross-voice
  /// displacement, multi-staff alignment) all move elements horizontally, and
  /// each used to spell the copy out by hand — so adding a field to this class
  /// meant finding every one of them or silently losing it.
  PositionedElement movedTo(Offset newPosition) => PositionedElement(
        element,
        newPosition,
        system: system,
        voiceNumber: voiceNumber,
        onset: onset,
        measureIndex: measureIndex,
        staffBaselineY: staffBaselineY,
      );

  /// Stable signature used to cheaply compare large positioned element lists.
  ///
  /// The signature is **structural**, not identity based: laying the same
  /// [Staff] out twice must produce the same number, otherwise `shouldRepaint`
  /// can never return false and viewport culling saves nothing. (It used to mix
  /// in `element.hashCode`, which is identity for musical elements, and the
  /// engine replaced beamed notes with fresh objects on every run.)
  static int computeSignature(List<PositionedElement> elements) {
    int hash = 17;
    for (final item in elements) {
      hash = Object.hash(
        hash,
        structuralHash(item.element),
        item.position.dx,
        item.position.dy,
        item.system,
        item.voiceNumber,
        item.onset,
        item.measureIndex,
      );
    }
    return Object.hash(hash, elements.length);
  }

  /// Content-based hash for a musical element, so two runs over the same model
  /// agree even though the objects are compared by identity elsewhere.
  static int structuralHash(MusicalElement element) {
    if (element is Note) {
      return Object.hash(
        'Note',
        element.pitch,
        element.duration.type,
        element.duration.dots,
        element.beam,
        element.tie,
        element.voice,
        element.articulations.length,
        element.ornaments.length,
        element.syllables?.length ?? 0,
      );
    }
    if (element is Rest) {
      return Object.hash('Rest', element.duration.type, element.duration.dots);
    }
    if (element is Chord) {
      var h = Object.hash('Chord', element.duration.type,
          element.duration.dots, element.beam, element.voice);
      for (final n in element.notes) {
        h = Object.hash(h, n.pitch);
      }
      return h;
    }
    if (element is Clef) {
      return Object.hash('Clef', element.clefType);
    }
    if (element is KeySignature) {
      return Object.hash('Key', element.count, element.previousCount);
    }
    if (element is TimeSignature) {
      return Object.hash('Time', element.numerator, element.denominator);
    }
    if (element is Barline) {
      return Object.hash('Barline', element.type);
    }
    if (element is Tuplet) {
      return Object.hash('Tuplet', element.actualNotes, element.normalNotes,
          element.elements.length);
    }
    // Fall back to the runtime type: enough to notice a structural change,
    // and still deterministic across runs.
    return element.runtimeType.hashCode;
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

  // Mapas for capturar positions das notes (for beaming)
  final Map<Note, double>? noteXPositions;
  final Map<Note, int>? noteStaffPositions;
  final Map<Note, double>? noteYPositions; // ✅ NOVO: Y absoluto em pixels

  double _currentX;
  double _currentY;
  int _currentSystem;

  /// Index of the measure currently being laid out (set by the engine).
  int currentMeasureIndex = -1;
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
           5.0, // CORREÇÃO CRÃƒÂTICA: Baseline é staffSpace * 5, não * 4
       _currentSystem = 0,
       _isFirstMeasureInSystem = true;

  double get currentX => _currentX;
  double get currentY => _currentY;
  int get currentSystem => _currentSystem;
  bool get isFirstMeasureInSystem => _isFirstMeasureInSystem;
  double get usableWidth => availableWidth - (systemMargin * 2);

  /// Clef currently in force at the cursor, or null before the first clef.
  Clef? get activeClef => _currentClef;

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

  void addBarline(List<PositionedElement> elements, {double onset = 0.0}) {
    elements.add(
      PositionedElement(
        Barline(),
        Offset(_currentX, _currentY),
        system: _currentSystem,
        onset: onset,
        measureIndex: currentMeasureIndex,
        staffBaselineY: _currentY,
      ),
    );
    advance(LayoutEngine.barlineTrailingSpace * staffSpace);
  }

  /// Adds double barline final (end of the peça)
  void addDoubleBarline(List<PositionedElement> elements,
      {double onset = 0.0}) {
    elements.add(
      PositionedElement(
        Barline(type: BarlineType.final_),
        Offset(_currentX, _currentY),
        system: _currentSystem,
        onset: onset,
        measureIndex: currentMeasureIndex,
        staffBaselineY: _currentY,
      ),
    );
    advance(LayoutEngine.barlineTrailingSpace * staffSpace);
  }

  void endMeasure() {
    _isFirstMeasureInSystem = false;
    // Padding agora Applied Before of the barline no layout principal
  }

  void addElement(
    MusicalElement element,
    List<PositionedElement> elements, {
    int? voiceNumber,
    double onset = 0.0,
  }) {
    // Track the clef currently in force. Because system elements are now laid
    // out in document order (a mid-measure clef change stays where the author
    // put it), the notes before such a change keep the previous clef.
    if (element is Clef) {
      _currentClef = element;
    }

    // A plain (non-MultiVoice) measure can still carry voice-tagged notes —
    // that is exactly what the MusicXML importer produces. Derive the voice
    // from the element when the caller did not pass one, otherwise cross-voice
    // collision resolution and voice-based selection silently skip them.
    voiceNumber ??= element is Note
        ? element.voice
        : (element is Chord ? element.voice : null);

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
          onset: onset,
          measureIndex: currentMeasureIndex,
          staffBaselineY: _currentY,
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
        onset: onset,
        measureIndex: currentMeasureIndex,
        staffBaselineY: _currentY,
      ),
    );
  }
}

class LayoutEngine {
  final Staff staff;
  final double availableWidth;
  final double staffSpace;
  final SmuflMetadata? metadata; // ✅ Tipagem correta aplicada

  // System de Intelligent spacing
  late final spacing.IntelligentSpacingEngine _spacingEngine;
  late final spacing.SpacingPreferences _spacingPreferences;

  // System de Beaming Avançado
  late final BeamAnalyzer _beamAnalyzer;
  final Map<Note, double> _noteXPositions = {};
  final Map<Note, int> _noteStaffPositions = {};
  final Map<Note, double> _noteYPositions =
      {}; // ✅ NOVO: Y absoluto em pixels
  final List<AdvancedBeamGroup> _advancedBeamGroups = [];

  /// Within-measure accidental display decision per note (Behind Bars rule),
  /// resolved from the model so layout width and rendering agree.
  late final Map<Note, AccidentalDisplay> accidentalDecisions =
      AccidentalResolver.resolve(staff.measures);

  /// Horizontal compression applied to the rhythmic spacing of the measure
  /// currently being laid out.
  ///
  /// 1.0 = natural spacing. A measure whose natural width exceeds the usable
  /// line width is squeezed instead of being allowed to run off the canvas
  /// (F-05: a bar of 32 sixteenths at 400 px used to reach x = 1222 px, and the
  /// widget clipped everything past the viewport with no way to scroll to it).
  double _spacingScale = 1.0;

  /// True while a measure is being MEASURED into a throw-away cursor rather
  /// than laid out for real. Side effects on the engine's own state must be
  /// suppressed while it is set.
  bool _measuring = false;

  /// Lower bound for [_spacingScale]; past this the notes would collide, so the
  /// measure is allowed to overflow (the canvas is horizontally scrollable).
  static const double minimumSpacingScale = 0.35;

  /// Musical time, in whole notes, at which the measure being laid out starts.
  double _measureOnsetBase = 0.0;

  // Validation configuration (silent by default).
  final bool verboseValidation;

  /// Number of measures that precede this [staff] in the real score.
  ///
  /// A wrapped system is laid out from a SUB-staff, so its measure indices
  /// restart at 0. Rather than stamping the absolute number onto the caller's
  /// `Measure` objects (a surprising mutation of the model, and one that gets
  /// anacrusis numbering wrong), the offset is passed here and applied only
  /// when the measure carries no explicit `Measure.number`.
  final int measureNumberOffset;

  // Fix: SMuFL: Larguras agora consultadas dinamicamente of the metadata
  // Valores de fallback mantidos for compatibilidade
  static const double _gClefWidthFallback = 2.684;
  static const double _fClefWidthFallback = 2.756;
  static const double _cClefWidthFallback = 2.796;
  static const double _noteheadBlackWidthFallback = 1.18;
  static const double _accidentalSharpWidthFallback = 1.116;
  static const double _accidentalFlatWidthFallback = 1.18;
  /// Space left AFTER a barline before the next measure's content, in staff
  /// spaces.
  ///
  /// NOTE: this is NOT SMuFL's `barlineSeparation` engraving default (0.4),
  /// which describes the gap BETWEEN the two strokes of a double/final barline
  /// and is read straight from the metadata by `BarlineRenderer`. The name
  /// collision was misleading, so the constant is now [barlineTrailingSpace];
  /// [barlineSeparation] stays as a deprecated alias.
  static const double barlineTrailingSpace = 2.5;

  @Deprecated(
    'Renamed to barlineTrailingSpace: this is not SMuFL barlineSeparation',
  )
  static const double barlineSeparation = barlineTrailingSpace;
  static const double legerLineExtension = 0.4;

  /// Size factor applied to a clef/key/meter change that happens INSIDE a bar
  /// (Behind Bars / Verovio draw those at cue size). Matches the 0.72 used by
  /// `StaffRenderer` when it detects a mid-system clef.
  static const double midMeasureCueScale = 0.72;

  /// Slot width, in staff spaces, of a quarter note inside a tuplet.
  ///
  /// Kept for source compatibility; the real grid is
  /// [TupletGrid], which BOTH this engine and `TupletRenderer` read. It used to
  /// be a flat step applied to every child regardless of duration, which is why
  /// a quarter and an eighth in the same triplet were 30.00 px apart each.
  @Deprecated('Use TupletGrid.quarterSlotSpaces; the grid is proportional now')
  static const double tupletInnerSpacing = TupletGrid.quarterSlotSpaces;

  // Intelligent spacing: Valores balanceados
  static const double systemMargin = 2.5;
  static const double measureMinWidth = 5.0;
  static const double noteMinSpacing =
      3.5; // Base para espaçamento entre notas
  static const double measureEndPadding =
      3.0; // Espaço adequado ANTES da barline (agora corrigido!)

  LayoutEngine(
    this.staff, {
    required this.availableWidth,
    this.staffSpace = 12.0,
    this.metadata,
    this.verboseValidation = false, // Silencioso por padrão
    this.measureNumberOffset = 0,
    spacing.SpacingPreferences? spacingPreferences,
  }) {
    // Initialise spacing engine
    _spacingPreferences = spacingPreferences ?? spacing.SpacingPreferences.normal;
    _spacingEngine = spacing.IntelligentSpacingEngine(
      preferences: _spacingPreferences,
    );
    _spacingEngine.initializeOpticalCompensator(staffSpace);

    // Initialise positioning engine for beaming
    // Validation: metadata can be null in some context
    if (metadata == null) {
      throw ArgumentError(
        'metadata é obrigatório para beaming avançado',
      );
    }
    final positioningEngine = SMuFLPositioningEngine(metadataLoader: metadata!);

    // Initialise system de beaming avançado
    _beamAnalyzer = BeamAnalyzer(
      staffSpace: staffSpace,
      noteheadWidth: noteheadBlackWidth * staffSpace,
      positioningEngine: positioningEngine,
    );
  }

  /// Effective accidental glyph after within-measure resolution: null = hide
  /// (alteration already in force), the natural glyph when reverting, else the
  /// note's own accidental.
  String? _effectiveAccidentalGlyph(Note note) {
    switch (accidentalDecisions[note] ?? AccidentalDisplay.show) {
      case AccidentalDisplay.hide:
        return null;
      case AccidentalDisplay.natural:
        return 'accidentalNatural';
      case AccidentalDisplay.show:
        return note.pitch.accidentalGlyph;
    }
  }

  /// Gets width de glifo dinamicamente of the metadata or Returns fallback
  double _getGlyphWidth(String glyphName, double fallback) {
    if (metadata != null && metadata!.hasGlyph(glyphName)) {
      return metadata!.getGlyphWidth(glyphName);
    }
    return fallback;
  }

  /// Width of the treble clef (G clef)
  double get gClefWidth => _getGlyphWidth('gClef', _gClefWidthFallback);

  /// Width of the bass clef (F clef)
  double get fClefWidth => _getGlyphWidth('fClef', _fClefWidthFallback);

  /// Width of the C clef (C clef)
  double get cClefWidth => _getGlyphWidth('cClef', _cClefWidthFallback);

  /// Width of the notehead preta
  double get noteheadBlackWidth =>
      _getGlyphWidth('noteheadBlack', _noteheadBlackWidthFallback);

  /// Width of the sharp
  double get accidentalSharpWidth =>
      _getGlyphWidth('accidentalSharp', _accidentalSharpWidthFallback);

  /// Width of the flat
  double get accidentalFlatWidth =>
      _getGlyphWidth('accidentalFlat', _accidentalFlatWidthFallback);

  /// Display number for each measure index, honouring `Measure.number`
  /// (MEI `<measure @n>`) and falling back to 1-based position.
  ///
  /// The model has carried `Measure.number` since 2.x but nothing ever drew it;
  /// measure numbers are part of any professional score, so `StaffRenderer`
  /// now reads this map.
  Map<int, int> get measureNumbers {
    final result = <int, int>{};
    for (var i = 0; i < staff.measures.length; i++) {
      result[i] = staff.measures[i].number ?? (i + 1 + measureNumberOffset);
    }
    return result;
  }

  /// Returns os Advanced Beam Groups Calculados pelo last layout
  List<AdvancedBeamGroup> get advancedBeamGroups =>
      List.unmodifiable(_advancedBeamGroups);

  /// ✅ Expor positions X das notes for Rendering needs
  Map<Note, double> get noteXPositions => Map.unmodifiable(_noteXPositions);

  /// ✅ Expor positions Y das notes for Rendering de stems
  Map<Note, double> get noteYPositions => Map.unmodifiable(_noteYPositions);

  /// Staff position of each note (0 = middle line, +1 per diatonic step up).
  ///
  /// Exposed so consumers that need to reason about a note's DRAWN geometry —
  /// stem direction, ledger lines, hit-test boxes — can do it from the same
  /// numbers the renderers use instead of re-deriving them and drifting.
  Map<Note, int> get noteStaffPositions =>
      Map.unmodifiable(_noteStaffPositions);

  /// Overrides a note's horizontal position after layout (used by the
  /// multi-staff aligner so beams follow re-aligned noteheads). No-op for notes
  /// the engine never positioned.
  void overrideNoteX(Note note, double x) {
    if (_noteXPositions.containsKey(note)) _noteXPositions[note] = x;
  }

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
    // Limpar mapas de positions
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

    // Armazenar measures by system for justificação
    final systemMeasures = <int, List<int>>{};
    final measureStartIndices = <int, int>{};

    // System de inheritance de TimeSignature
    TimeSignature? currentTimeSignature;
    // Running clef/key, restated at the start of each new system.
    Clef? currentClef;
    KeySignature? currentKey;

    // Musical time, in whole notes, consumed by the measures laid out so far.
    // Carried onto every PositionedElement so several staves can later be
    // aligned on one shared time grid.
    double onsetCursor = 0.0;

    // Contador de validação (only for estatísticas)
    int validMeasures = 0;
    int invalidMeasures = 0;

    for (int i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      final isFirst = cursor.isFirstMeasureInSystem;
      final isLast = i == staff.measures.length - 1;
      // Inheritance DE TIME SIGNATURE: Procurar no current measure
      TimeSignature? measureTimeSignature;
      for (final element in measure.elements) {
        if (element is TimeSignature) {
          measureTimeSignature = element;
          currentTimeSignature = element; // Atualizar TimeSignature corrente
          break;
        }
      }

      // If not encontrou, Use o TimeSignature inherited
      final timeSignatureToUse = measureTimeSignature ?? currentTimeSignature;

      // Define TimeSignature inherited no Measure for validação preventiva
      if (timeSignatureToUse != null && measureTimeSignature == null) {
        measure.inheritedTimeSignature = timeSignatureToUse;
      }

      // ✅ Validação de measure (silenciosa - only estatísticas)
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

      // QUEBRA INTELIGENTE: A each N measures Or if not couber
      if (!isFirst && cursor.needsSystemBreak(measureWidth)) {
        final measureStartsWithBarline =
            measure.elements.isNotEmpty && measure.elements.first is Barline;
        final previousSystemAlreadyEndsWithBarline =
            positionedElements.isNotEmpty &&
            positionedElements.last.system == cursor.currentSystem &&
            positionedElements.last.element is Barline;

        // If the next system starts with a barline (for example a repeat
        // start), the previous system still needs a normal closing barline.
        if (measureStartsWithBarline && !previousSystemAlreadyEndsWithBarline) {
          cursor.addBarline(positionedElements, onset: onsetCursor);
        }
        cursor.startNewSystem();
      }

      // The restated clef/key below belong to the measure ABOUT to be laid
      // out, so stamp the index first — otherwise the restatement carried the
      // PREVIOUS bar's index and the measure-number pass read the wrong number
      // (and picked the wrong left-most element) at every system start.
      cursor.currentMeasureIndex = i;

      // Restate the running clef (and key signature) at the start of every
      // system after the first, when this measure does not carry its own — so
      // each wrapped line begins with its prevailing clef/key (Gould/Verovio).
      if (cursor.isFirstMeasureInSystem && i > 0) {
        final hasClef = measure.elements.any((e) => e is Clef);
        final hasKey = measure.elements.any((e) => e is KeySignature);
        var restated = false;
        final clef = currentClef;
        if (!hasClef && clef != null) {
          cursor.addElement(clef, positionedElements, onset: onsetCursor);
          cursor.advance(_getElementWidthSimple(clef));
          restated = true;
        }
        final key = currentKey;
        if (!hasKey && key != null && key.count != 0) {
          cursor.addElement(key, positionedElements, onset: onsetCursor);
          cursor.advance(_getElementWidthSimple(key));
          restated = true;
        }
        if (restated) cursor.advance(staffSpace * 1.0);
      }
      // Update the running clef/key from this measure (used by later systems).
      for (final e in measure.elements) {
        if (e is Clef) currentClef = e;
        if (e is KeySignature) currentKey = e;
      }

      // Guardar index initial of the measure for justificação
      final measureStartIndex = positionedElements.length;
      measureStartIndices[i] = measureStartIndex;

      // Registrar measure no system
      final currentSystem = cursor.currentSystem;
      systemMeasures[currentSystem] = systemMeasures[currentSystem] ?? [];
      systemMeasures[currentSystem]!.add(i);

      // A measure that cannot fit the line is COMPRESSED instead of being let
      // run off the canvas. `needsSystemBreak` never fires for the first
      // measure of a system (there is nowhere to break to), so without this a
      // dense bar simply overflowed and the widget clipped it.
      final usable = cursor.usableWidth;
      final headroom = usable - (cursor.currentX - cursor.systemMargin);
      if (measureWidth > headroom && headroom > 0) {
        _spacingScale =
            (headroom / measureWidth).clamp(minimumSpacingScale, 1.0);
      }

      _measureOnsetBase = onsetCursor;
      _layoutMeasureCursor(
        measure,
        cursor,
        positionedElements,
        cursor.isFirstMeasureInSystem,
      );
      _spacingScale = 1.0;
      onsetCursor += _measureMusicalDuration(measure);

      // Check if current measure ends with barline
      final currentMeasureEndsWithBarline =
          measure.elements.isNotEmpty && measure.elements.last is Barline;

      // Check if Next measure começa with barline (ex: repeat)
      final nextMeasure = (i < staff.measures.length - 1)
          ? staff.measures[i + 1]
          : null;
      final nextMeasureStartsWithBarline =
          nextMeasure != null &&
          nextMeasure.elements.isNotEmpty &&
          nextMeasure.elements.first is Barline;

      // add barline apropriada SOMENTE if:
      // 1. Next measure not começar with a
      // 2. Current measure not terminar with a
      if (!nextMeasureStartsWithBarline && !currentMeasureEndsWithBarline) {
        if (isLast) {
          // Double barline Final
          cursor.advance(measureEndPadding * staffSpace);
          cursor.addDoubleBarline(positionedElements, onset: onsetCursor);
        } else {
          // BARLINE NORMAL between measures
          cursor.advance(measureEndPadding * staffSpace);
          cursor.addBarline(positionedElements, onset: onsetCursor);
        }
      } else {
        // Measure ends with barline Or next começa with barline - only add padding
        cursor.advance(measureEndPadding * staffSpace);
      }

      cursor.endMeasure();
    }

    // Relatório resumido (only if verbose)
    if (verboseValidation && (validMeasures + invalidMeasures) > 0) {}

    // JUSTIFICAÇÃO HORIZONTAL: Esticar measures for preencher width
    _justifyHorizontally(positionedElements, systemMeasures);

    // Center a lone full-measure rest within its bar (Behind Bars p.158).
    _centerFullMeasureRests(positionedElements, measureStartIndices);

    // Displace cross-voice noteheads that would overlap (seconds/unisons).
    _resolveCrossVoiceCollisions(positionedElements);

    // Re-sync `_noteXPositions` with the post-justification positions.
    // Justification moves `positionedElements` but not the note map, and beams
    // read the map — so without this the beam and its noteheads drift apart.
    // The old loop only handled top-level `Note`s, leaving every note INSIDE a
    // Chord holding its pre-justification X.
    for (final positioned in positionedElements) {
      final element = positioned.element;
      final x = positioned.position.dx;
      if (element is Note) {
        if (_noteXPositions.containsKey(element)) {
          _noteXPositions[element] = x;
        }
      } else if (element is Chord) {
        for (final note in element.notes) {
          if (_noteXPositions.containsKey(note)) {
            _noteXPositions[note] = x;
          }
        }
      } else if (element is Tuplet) {
        // Inner notes sit on the renderer's grid, anchored on the tuplet.
        _reanchorTupletX(element, x);
      }
    }

    // ANÃƒÂLISE DE BEAMING AVANÇADO: criar AdvancedBeamGroups
    _analyzeBeamGroups(currentTimeSignature, positionedElements);

    return positionedElements;
  }

  /// Analisa beam groups and Creates AdvancedBeamGroups for Rendering
  /// ✅ CORREÇÃO: Use notes ProcessesDAS de positionedElements, not de measure.elements
  void _analyzeBeamGroups(
    TimeSignature? timeSignature,
    List<PositionedElement> positionedElements,
  ) {
    // A staff with no explicit meter still gets beams: `_processBeamsWithAnacrusis`
    // already defaults to 4/4 and stamps them. Bailing out here left those beams
    // with NO geometry — no stem lengths, no slope, no secondary-beam segments —
    // and `advancedBeamGroups` empty, so `StaffRenderer` fell through to the
    // crude fallback drawer. The README's own quick-start snippet
    // (`Measure()..add(Note(...))`, no TimeSignature) hit this path.
    timeSignature ??= TimeSignature(numerator: 4, denominator: 4);

    // ✅ CORREÇÃO: Extrair notes ProcessesDAS diretamente de positionedElements
    // As notes processadas are aquelas that foram adicionadas aos mapas
    final processedNotes = positionedElements
        .where((p) => p.element is Note)
        .map((p) => p.element as Note)
        .toList();

    if (processedNotes.isEmpty) {
      return;
    }

    // Use beam types already atribuídos by _processBeamsWithAnacrusis for identificar grupos.
    // Not chamar BeamGrouper newmente, pois it Processes all as notes in conjunto
    // sem respeitar limites de measure, causing agrupamentos incorretos between measures.
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

  /// Justifica horizontalmente os measures for preencher a width disponível
  /// Stretches each system (except the last) so its music reaches the right
  /// margin.
  ///
  /// Two things were wrong before:
  ///
  /// * the offset was proportional to the element's absolute X, which scales
  ///   EVERY gap by the same factor — including the fixed opening block
  ///   (clef -> key -> meter), which by convention must never be stretched.
  ///   Only the region from the first rhythmic event onwards is elastic now.
  /// * a `fillThreshold` of 0.7 left any system filling less than 70% of the
  ///   line ragged. That is a last-system rule, not a mid-score one: a 1400 px
  ///   viewport measured 69% fill and produced a ragged right edge in the
  ///   MIDDLE of the piece.
  void _justifyHorizontally(
    List<PositionedElement> elements,
    Map<int, List<int>> systemMeasures,
  ) {
    final rightEdge = availableWidth - (systemMargin * staffSpace);
    final int lastSystem = systemMeasures.keys.isEmpty
        ? -1
        : systemMeasures.keys.reduce((a, b) => a > b ? a : b);

    // Index the elements by system ONCE.
    //
    // This loop used to scan the whole `elements` list twice per system, which
    // is O(systems x elements) — and since the number of systems grows with the
    // number of elements, that is quadratic in the size of the score. Measured
    // before: 400 bars 160 ms, 1600 bars 262 ms, 3200 bars 1156 ms, 6400 bars
    // 5991 ms; the same 3200 bars laid out as ONE system (where justification
    // is skipped, because the last system keeps its natural spacing) took
    // 115 ms. Justification alone accounted for a 6.3x slowdown.
    final bySystem = <int, List<int>>{};
    for (var i = 0; i < elements.length; i++) {
      (bySystem[elements[i].system] ??= <int>[]).add(i);
    }

    for (final entry in systemMeasures.entries) {
      final system = entry.key;
      if (system == lastSystem) continue; // Behind Bars: last line stays natural
      if (entry.value.isEmpty) continue;

      final indices = bySystem[system];
      if (indices == null || indices.isEmpty) continue;

      // Elastic region = from the first rhythmic event of the system to the
      // right-most element on it.
      double? contentStartX;
      double maxX = double.negativeInfinity;
      for (final i in indices) {
        final positioned = elements[i];
        final e = positioned.element;
        final isRhythmic =
            e is Note || e is Rest || e is Chord || e is Tuplet;
        if (isRhythmic &&
            (contentStartX == null || positioned.position.dx < contentStartX)) {
          contentStartX = positioned.position.dx;
        }
        if (positioned.position.dx > maxX) maxX = positioned.position.dx;
      }
      if (contentStartX == null || maxX <= contentStartX) continue;

      final extraSpace = rightEdge - maxX;
      if (extraSpace <= 0) continue; // already full (or compressed)

      final span = maxX - contentStartX;
      for (final i in indices) {
        final positioned = elements[i];
        final dx = positioned.position.dx;
        if (dx <= contentStartX) continue; // opening block stays put

        final ratio = (dx - contentStartX) / span;
        elements[i] = positioned
            .movedTo(Offset(dx + extraSpace * ratio, positioned.position.dy));
      }
    }
  }

  /// Centers a measure that contains a single full-bar rest between its left
  /// content edge and its closing barline (Behind Bars p.158: a whole-measure
  /// rest sits centered regardless of meter). Runs after justification so the
  /// barline X is final.
  void _centerFullMeasureRests(
    List<PositionedElement> elements,
    Map<int, int> measureStartIndices,
  ) {
    final keys = measureStartIndices.keys.toList()..sort();
    for (var ki = 0; ki < keys.length; ki++) {
      final i = keys[ki];
      final measure = staff.measures[i];
      if (measure is MultiVoiceMeasure) continue;

      final musical = measure.elements
          .where((e) => e is Note || e is Rest || e is Chord)
          .toList();
      if (musical.length != 1 || musical.first is! Rest) continue;
      final rest = musical.first as Rest;

      // Only a true full-bar rest: a whole rest (used as a measure rest in any
      // meter) or a rest whose value fills the measure.
      final ts = measure.timeSignature ?? measure.inheritedTimeSignature;
      final isFullBar = rest.duration.type == DurationType.whole ||
          (ts != null &&
              !ts.isFreeTime &&
              rest.duration.realValue >= ts.measureValue - 1e-6);
      if (!isFullBar) continue;

      final start = measureStartIndices[i]!;
      final end =
          ki + 1 < keys.length ? measureStartIndices[keys[ki + 1]]! : elements.length;

      var restIdx = -1;
      double? barlineX;
      for (var j = start; j < end; j++) {
        final el = elements[j].element;
        if (el is Rest && restIdx < 0) restIdx = j;
        if (el is Barline) barlineX = elements[j].position.dx;
      }
      if (restIdx < 0 || barlineX == null) continue;

      final positioned = elements[restIdx];
      final restWidth = _getElementWidthSimple(positioned.element);
      final leftBound = positioned.position.dx;
      final available = barlineX - leftBound;
      if (available <= restWidth) continue;

      final newX = leftBound + (available - restWidth) / 2;
      elements[restIdx] =
          positioned.movedTo(Offset(newX, positioned.position.dy));
    }
  }

  /// When two voices place noteheads a second or unison apart at the same
  /// onset, the heads overlap. Displace the lower voice's head(s) by one
  /// notehead width so the interval reads clearly (Gould p.39-46). Runs after
  /// justification; only handles the two-voice case.
  void _resolveCrossVoiceCollisions(List<PositionedElement> elements) {
    final noteW = noteheadBlackWidth * staffSpace;

    // Group notes by system + MUSICAL ONSET.
    //
    // The grouping key used to be the rounded X. Voices 2+ are placed by linear
    // interpolation on voice 1's timeline, so two simultaneous notes routinely
    // landed on 123.4 and 123.6 -> keys '123' and '124' -> no group at all and
    // the collision went unresolved. Onset is exact and is what "simultaneous"
    // actually means.
    final groups = <String, List<int>>{};
    for (var i = 0; i < elements.length; i++) {
      final pe = elements[i];
      if (pe.element is! Note || pe.voiceNumber == null) continue;
      final onsetKey = (pe.onset * kOnsetGrid).round();
      final key = '${pe.system}_$onsetKey';
      (groups[key] ??= <int>[]).add(i);
    }

    for (final idxs in groups.values) {
      if (idxs.length < 2) continue;

      // (positioned-index, voice, staffPosition) for each note in the group.
      final infos = <({int idx, int voice, int pos})>[];
      for (final i in idxs) {
        final sp = _noteStaffPositions[elements[i].element as Note];
        if (sp == null) continue;
        infos.add((idx: i, voice: elements[i].voiceNumber!, pos: sp));
      }
      if (infos.length < 2) continue;
      if (infos.map((n) => n.voice).toSet().length < 2) continue;

      // Closest cross-voice interval.
      var minDiff = 9999;
      for (final a in infos) {
        for (final b in infos) {
          if (a.voice == b.voice) continue;
          final d = (a.pos - b.pos).abs();
          if (d < minDiff) minDiff = d;
        }
      }
      if (minDiff > 1) continue; // only seconds and unisons collide

      // A UNISON is not displaced.
      //
      // Behind Bars p.44: when two voices meet on the same pitch with the same
      // note value, they share ONE notehead carrying two stems — the heads are
      // coincident on purpose, and pushing one aside by a full head width turns
      // a unison into what reads as a second. Only a genuine SECOND is offset.
      // (Two voices on the same pitch with DIFFERENT values do need separate
      // heads, so those are still displaced.)
      if (minDiff == 0) {
        final durations = <DurationType>{};
        for (final n in infos) {
          final element = elements[n.idx].element;
          if (element is Note) durations.add(element.duration.type);
        }
        if (durations.length <= 1) continue;
      }

      // Pick the lower voice (smallest staff position; tie -> larger voice id).
      int? lowerVoice;
      int? lowerPos;
      for (final n in infos) {
        if (lowerVoice == null ||
            n.pos < lowerPos! ||
            (n.pos == lowerPos && n.voice > lowerVoice)) {
          lowerVoice = n.voice;
          lowerPos = n.pos;
        }
      }

      // Shift that voice's note(s) in this onset group left by one head width.
      for (final n in infos) {
        if (n.voice != lowerVoice) continue;
        final pe = elements[n.idx];
        elements[n.idx] =
            pe.movedTo(Offset(pe.position.dx - noteW, pe.position.dy));
      }
    }
  }

  /// Exact width the measure will occupy, obtained by laying it out into a
  /// throw-away cursor.
  ///
  /// This used to be an independent estimate: sum of glyph widths plus a FLAT
  /// `3.5 staff spaces` per note gap, while the real layout advanced by a
  /// duration-proportional amount. The two numbers disagreed by up to 2x, so
  /// system breaks were decided with a figure that did not describe the
  /// drawing. Measuring by dry-run makes the two agree by construction — they
  /// cannot drift apart again because there is only one implementation.
  ///
  /// The probe cursor is created WITHOUT the note position maps so the dry run
  /// leaves no trace in [_noteXPositions] and friends.
  double _calculateMeasureWidthCursor(Measure measure, bool isFirstInSystem) {
    final probe = LayoutCursor(
      staffSpace: staffSpace,
      availableWidth: availableWidth,
      systemMargin: 0,
    );
    final scrap = <PositionedElement>[];
    final savedScale = _spacingScale;
    _spacingScale = 1.0;
    // The probe cursor carries no position maps, but `_registerTupletGeometry`
    // writes straight into the ENGINE's maps, so a tuplet did leave a trace:
    // its inner notes were stamped with probe coordinates (origin 0) until the
    // real pass happened to overwrite them. Harmless today only because the
    // real pass always follows; a latent trap either way.
    _measuring = true;
    _layoutMeasureCursor(measure, probe, scrap, isFirstInSystem);
    _measuring = false;
    _spacingScale = savedScale;

    final width = probe.currentX;
    final minWidth = measureMinWidth * staffSpace;
    return width < minWidth ? minWidth : width;
  }

  void _layoutMultiVoiceMeasure(
    MultiVoiceMeasure measure,
    LayoutCursor cursor,
    List<PositionedElement> positionedElements,
    bool isFirstInSystem,
  ) {
    double startX = cursor.currentX;

    // The measure's OWN elements are its opening block.
    //
    // This method used to walk `measure.sortedVoices` and nothing else, so a
    // clef, key, meter or dynamic written into `MultiVoiceMeasure.elements` —
    // the inherited, public, documented list that `Measure.add` writes to — was
    // dropped without a word. Worse, because the cursor never saw a Clef it had
    // no active clef, so EVERY note in the bar was placed on the staff baseline
    // instead of at its pitch (measured: a C6 and a C4 both at y = 60.0) and
    // none of them was registered in the note-position maps, which silently
    // disabled beams, hit-testing and the public position API for that bar.
    //
    // Polyphonic music imported from MusicXML/MEI escaped the bug only because
    // the parsers wrote every system element TWICE — once here and once into
    // voice 1. That duplication is removed in the parsers now that this path
    // reads the measure's own elements.
    final opening = canonicalOpeningBlock(
      measure.elements.where(_isSystemElement).toList(),
    );
    final measureExtras =
        measure.elements.where((e) => !_isSystemElement(e)).toList();

    double onsetBase = _measureOnsetBase;
    for (final element in opening) {
      cursor.addElement(element, positionedElements, onset: onsetBase);
      cursor.advance(_getElementWidthSimple(element));
    }
    if (opening.isNotEmpty) {
      cursor.advance(
        _calculateSpacingAfterSystemElementsCorrected(
          opening,
          measure.sortedVoices.isEmpty
              ? const <MusicalElement>[]
              : measure.sortedVoices.first.elements
                  .where((e) => !_isSystemElement(e))
                  .toList(),
        ),
      );
      startX = cursor.currentX;
    }

    // Non-system extras (dynamics, texts, octave marks) are co-positioned with
    // the start of the bar's music and must not advance the cursor.
    for (final element in measureExtras) {
      cursor.addElement(element, positionedElements, onset: onsetBase);
    }

    double maxAdvanceX = startX;
    // Tracks where musical elements (post clef/key/time) start in voice 1.
    // voices 2+ must start at this X so notes align with voice 1.
    double firstMusicX = startX;
    final leadTimelineAnchors = <({double time, double x})>[];
    double leadTotalTime = 0.0;

    final sortedVoices = measure.sortedVoices;

    for (int voiceIdx = 0; voiceIdx < sortedVoices.length; voiceIdx++) {
      final voice = sortedVoices[voiceIdx];

      // voices 2+ skip system elements and start where voice 1's music begins
      final isLeadVoice = voiceIdx == 0;
      cursor.setX(isLeadVoice ? startX : firstMusicX);

      // processar beaming separadamente for each voice
      final processedElements = _processBeamsWithAnacrusis(
        voice.elements,
        measure.timeSignature,
        autoBeaming: measure.autoBeaming,
        beamingMode: measure.beamingMode,
        manualBeamGroups: measure.manualBeamGroups,
      );

      // Voice 2+ never renders system elements (clef/key/time sig belong to
      // voice 1). The lead voice renders every system element it carries —
      // those are author-placed openings or genuine mid-line changes.
      final elementsToRender = processedElements.where((element) {
        if (!isLeadVoice && _isSystemElement(element)) return false;
        return true;
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
          // Fallback if not houver âncoras of the voice principal.
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

        // Apply the voice's horizontal offset to the X position.
        final savedX = cursor.currentX;
        cursor.addElement(
          element,
          positionedElements,
          voiceNumber: voice.number,
          onset: _measureOnsetBase + (isLeadVoice ? leadTotalTime : voiceTime),
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
    // Handle MultiVoiceMeasure: layout each voice independently.
    if (measure is MultiVoiceMeasure) {
      _layoutMultiVoiceMeasure(
        measure,
        cursor,
        positionedElements,
        isFirstInSystem,
      );
      return;
    }

    final elementsToRender = _processBeamsWithAnacrusis(
      measure.elements,
      measure.timeSignature,
      autoBeaming: measure.autoBeaming,
      beamingMode: measure.beamingMode,
      manualBeamGroups: measure.manualBeamGroups,
    );

    if (elementsToRender.isEmpty) return;

    // Only the LEADING run of clef/key/time is the measure's opening block.
    //
    // The engine used to hoist EVERY system element to the head of the bar.
    // That moved a genuine mid-measure clef change to the barline AND — because
    // the cursor tracks the clef in the order it receives elements — made every
    // note in the bar be positioned with the LAST clef of the bar. A measure
    // `[treble, C4, bass, C4]` drew both C4s at the bass-clef position: a
    // twelfth off for the first one. System elements now stay in document
    // order, so notes before a change keep the previous clef.
    int lead = 0;
    while (lead < elementsToRender.length &&
        _isSystemElement(elementsToRender[lead])) {
      lead++;
    }
    final openingBlock =
        canonicalOpeningBlock(elementsToRender.sublist(0, lead));
    final body = elementsToRender.sublist(lead);

    double onset = _measureOnsetBase;

    for (final element in openingBlock) {
      cursor.addElement(element, positionedElements, onset: onset);
      cursor.advance(_getElementWidthSimple(element));
    }

    if (openingBlock.isNotEmpty) {
      cursor.advance(
        _calculateSpacingAfterSystemElementsCorrected(
          openingBlock,
          body.where((e) => !_isSystemElement(e)).toList(),
        ),
      );
    }

    // FLOATING ELEMENTS (tempo marks, segno/coda, dynamics, expression texts,
    // octave marks, ...) must NOT advance the cursor. They are co-positioned
    // with the rhythmic element that follows them (or with the last element in
    // the measure if they trail at the end), so extra-staff symbols never widen
    // the inter-note spacing inside the staff.
    final pendingFloating = <MusicalElement>[];
    MusicalElement? previousRhythmic;

    for (int i = 0; i < body.length; i++) {
      final element = body[i];

      if (_isAboveOrBelowStaffElement(element)) {
        pendingFloating.add(element);
        continue;
      }

      // A mid-measure clef / key / meter change sits in the flow: it needs a
      // little air on both sides but carries no rhythmic value.
      if (_isSystemElement(element)) {
        if (previousRhythmic != null) {
          cursor.advance(staffSpace * 0.8);
        }
        for (final floating in pendingFloating) {
          cursor.addElement(floating, positionedElements, onset: onset);
        }
        pendingFloating.clear();
        cursor.addElement(element, positionedElements, onset: onset);
        cursor.advance(_getElementWidthSimple(element) * midMeasureCueScale);
        cursor.advance(staffSpace * 0.6);
        continue;
      }

      if (previousRhythmic != null) {
        cursor.advance(_calculateRhythmicSpacing(element, previousRhythmic));
      } else {
        // First rhythmic element of the bar: there is no preceding gap to
        // charge its left extent to, so reserve it explicitly. Without this an
        // opening note's accidental leans back into the barline — the accidental
        // width moved OUT of the trailing advance when it was reassigned to the
        // leading gap, and the first note is the one element that has no
        // leading gap.
        cursor.advance(_leftExtent(element));
      }

      for (final floating in pendingFloating) {
        cursor.addElement(floating, positionedElements, onset: onset);
      }
      pendingFloating.clear();

      cursor.addElement(element, positionedElements, onset: onset);
      _registerTupletGeometry(element, cursor, onset);
      cursor.advance(_rightExtent(element));
      onset += _getRhythmicValue(element);
      previousRhythmic = element;
    }

    for (final floating in pendingFloating) {
      cursor.addElement(floating, positionedElements, onset: onset);
    }
  }

  /// Records X / staff position / Y for the notes INSIDE a tuplet.
  ///
  /// A [Tuplet] is positioned as one opaque element, so its inner notes used to
  /// get no geometry at all (`noteXPositions` returned null for every one of
  /// them) and were therefore invisible to beam analysis, to the public
  /// position API and to anything doing hit-testing. The renderer lays the
  /// inner notes out on an even grid of `tupletInnerSpacing` staff spaces; the
  /// same grid is mirrored here so the two agree.
  void _registerTupletGeometry(
    MusicalElement element,
    LayoutCursor cursor,
    double onset,
  ) {
    if (element is! Tuplet) return;
    if (_measuring) return; // a dry run must not touch the position maps
    final clef = cursor.activeClef;
    if (clef == null) return;
    _registerTupletNotes(element, clef, cursor.currentX, cursor.currentY);
  }

  /// Re-anchors the X of every note inside [tuplet] (recursively) after the
  /// tuplet itself has moved — justification, cross-staff alignment, and the
  /// full-bar-rest centring all move elements after the fact, and beams read
  /// these positions.
  double _reanchorTupletX(Tuplet tuplet, double startX) {
    var x = startX;
    for (final inner in tuplet.elements) {
      final step = TupletGrid.slotWidth(inner, staffSpace);
      if (inner is Note) {
        if (_noteXPositions.containsKey(inner)) _noteXPositions[inner] = x;
      } else if (inner is Chord) {
        for (final note in inner.notes) {
          if (_noteXPositions.containsKey(note)) _noteXPositions[note] = x;
        }
      } else if (inner is Tuplet) {
        _reanchorTupletX(inner, x);
      }
      x += step;
    }
    return x - startX;
  }

  /// Recursive worker for [_registerTupletGeometry]. Returns the width consumed,
  /// so a NESTED tuplet advances the outer grid by its own content rather than
  /// by a single slot.
  double _registerTupletNotes(
    Tuplet tuplet,
    Clef clef,
    double startX,
    double baselineY,
  ) {
    void place(Note note, double x) {
      final staffPosition = StaffPositionCalculator.calculate(note.pitch, clef);
      _noteXPositions[note] = x;
      _noteStaffPositions[note] = staffPosition;
      _noteYPositions[note] = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        baselineY,
      );
    }

    var x = startX;
    for (final inner in tuplet.elements) {
      final step = TupletGrid.slotWidth(inner, staffSpace);
      if (inner is Note) {
        place(inner, x);
      } else if (inner is Chord) {
        for (final note in inner.notes) {
          place(note, x);
        }
      } else if (inner is Tuplet) {
        // Nested tuplet: mirrors TupletRenderer, which recurses the same way
        // through the shared [TupletGrid].
        _registerTupletNotes(inner, clef, x, baselineY);
      }
      x += step;
    }
    return x - startX;
  }

  bool _isSystemElement(MusicalElement element) {
    return element is Clef ||
        element is KeySignature ||
        element is TimeSignature;
  }

  /// Sorts a measure's OPENING run of system elements into engraving order:
  /// clef, then key signature, then time signature (Behind Bars p.78; the same
  /// order Verovio, Finale, Sibelius and MuseScore all emit).
  ///
  /// Why this is not "document order"
  /// --------------------------------
  /// F-01 made the engine keep system elements where the author wrote them,
  /// which is REQUIRED for a mid-measure change: `[treble, C4, bass, C4]` must
  /// draw the bass clef after the first C4. But it also applied to the opening
  /// block, and MusicXML's `<attributes>` has a FIXED child order of
  /// `divisions, key, time, ..., clef` — the clef comes LAST in the file. So
  /// every imported score drew its key signature and meter before its clef.
  /// Measured on a 3-flat 4/4 import: KeySignature@30.0, TimeSignature@69.6,
  /// Clef@105.6.
  ///
  /// The distinction is positional, not textual: elements BEFORE the first
  /// rhythmic event describe the start of the system and have a canonical
  /// order; elements after it are events in time and keep document order.
  ///
  /// The sort is stable, so two elements of the same kind (a courtesy meter
  /// change written twice, say) keep their relative order.
  static List<MusicalElement> canonicalOpeningBlock(
    List<MusicalElement> leading,
  ) {
    if (leading.length < 2) return leading;
    int rank(MusicalElement e) {
      if (e is Clef) return 0;
      if (e is KeySignature) return 1;
      if (e is TimeSignature) return 2;
      return 3;
    }

    final indexed = <({int order, MusicalElement element})>[
      for (var i = 0; i < leading.length; i++)
        (order: i, element: leading[i]),
    ];
    indexed.sort((a, b) {
      final byKind = rank(a.element).compareTo(rank(b.element));
      return byKind != 0 ? byKind : a.order.compareTo(b.order);
    });
    return [for (final item in indexed) item.element];
  }

  /// Returns true for elements that render above or below the staff and must
  /// Not affect the horizontal spacing between notes inside the staff.
  ///
  /// These elements are "co-positioned" with their associated rhythmic element
  /// (the one that immediately follows in the measure) instead of advancing
  /// the layout cursor.
  bool _isAboveOrBelowStaffElement(MusicalElement element) {
    if (element is TempoMark) return true;
    if (element is Dynamic) return true;
    if (element is OctaveMark) return true;
    if (element is VoltaBracket) return true;
    if (element is Verse) return true;
    if (element is Breath) return true;
    if (element is MusicText) {
      // Lyrics can affect note spacing (syllable width); everything else floats.
      return element.type != TextType.lyrics;
    }
    if (element is RepeatMark) {
      // Bar-repeat and simile marks are part of the staff layout and of the affect
      // spacing. Navigation/text marks (segno, coda, D.C., D.S.) float above.
      return !_isBarRepeatMark(element);
    }
    return false;
  }

  /// Navigation/text repeat marks float above the staff (no spacing impact).
  /// Bar-repeat marks (double-bar repeats, simile strokes) stay in the flow.
  bool _isBarRepeatMark(RepeatMark mark) {
    switch (mark.type) {
      case RepeatType.repeatLeft:
      case RepeatType.repeatRight:
      case RepeatType.repeatBoth:
      case RepeatType.start:
      case RepeatType.end:
      case RepeatType.repeat1Bar:
      case RepeatType.repeat2Bars:
      case RepeatType.repeat4Bars:
      case RepeatType.simile:
      case RepeatType.percentRepeat:
      case RepeatType.repeatDots:
        return true;
      default:
        return false;
    }
  }

  // ESPAÇAMENTO APÓS ELEMENTOS DE System: MÃƒÂNIMO necessário
  double _calculateSpacingAfterSystemElementsCorrected(
    List<MusicalElement> systemElements,
    List<MusicalElement> musicalElements,
  ) {
    // Espaço MÃƒÂNIMO após elementos de system
    double baseSpacing = staffSpace * 1.2; // MUITO REDUZIDO!

    bool hasClef = systemElements.any((e) => e is Clef);
    bool hasTimeSignature = systemElements.any((e) => e is TimeSignature);

    if (hasClef && hasTimeSignature) {
      // If tem clef And fórmula de measure, reduzir still more
      baseSpacing = staffSpace * 1.0; // MÃƒÂNIMO!
    } else if (hasClef) {
      baseSpacing = staffSpace * 1.2;
    }

    // Armadura with muitos accidentals needs de a pouco more
    for (final element in systemElements) {
      if (element is KeySignature && element.count.abs() >= 4) {
        baseSpacing += staffSpace * 0.3; // Pequeno incremento
      }
    }

    // CORREÇÃO: Check if primeira note tem accidental EXPLÃƒÂCITO
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
    ); // Limites reduzidos
  }

  /// Horizontal advance this element occupies, in pixels.
  ///
  /// Public so hit-testing and export can build the same boxes the layout used
  /// (they must not re-derive them, or selection drifts from what is drawn).
  /// Width an element hangs to the LEFT of its own origin (the accidental).
  ///
  /// Exposed so hit-testing and collision code can build a box that matches
  /// what is drawn instead of assuming the whole width lies to the right.
  double elementLeftExtent(MusicalElement element) => _leftExtent(element);

  double elementWidth(MusicalElement element) =>
      _getElementWidthSimple(element);

  /// Advance width of an accidental glyph, in staff spaces, straight from the
  /// SMuFL metadata.
  ///
  /// This replaces a chain of `glyphName.contains(...)` tests whose branch
  /// order made the double-flat case UNREACHABLE ('accidentalDoubleFlat'
  /// contains 'Flat', so it matched the first branch and reserved 1.18 instead
  /// of Bravura's real 1.652 — the accidental then collided with the previous
  /// note). The natural was hardcoded at 0.92 against a real 0.672, and the
  /// flat fallback had been copied from `noteheadBlack`. All of those numbers
  /// were already sitting in `bravura_metadata.json`.
  double _accidentalAdvanceWidth(String glyphName) {
    if (metadata != null && metadata!.hasGlyph(glyphName)) {
      return metadata!.getGlyphWidth(glyphName);
    }
    // Fallbacks are the Bravura values, used only when metadata is missing.
    const fallbacks = <String, double>{
      'accidentalSharp': 0.996,
      'accidentalFlat': 0.904,
      'accidentalNatural': 0.672,
      'accidentalDoubleSharp': 1.0,
      'accidentalDoubleFlat': 1.652,
    };
    return fallbacks[glyphName] ?? _accidentalSharpWidthFallback;
  }

  /// Width an element occupies to the LEFT of its own origin, in pixels.
  ///
  /// An accidental is drawn BEFORE its notehead, so the space it needs belongs
  /// to the gap that precedes the note — not to the gap that follows it. The
  /// engine used to charge the whole of [_getElementWidthSimple] (accidental
  /// included) to the advance AFTER the note and put a flat `0.15` staff spaces
  /// in front of it. Measured on `C4, E4-sharp, G4, B4` at unbounded width:
  /// the gap BEFORE the sharp grew by 6.30 px and the gap AFTER it by 15.55 px,
  /// with a baseline gap of 56.16 px. The reservation was on the wrong side, so
  /// the accidental leaned into the previous note while an equal amount of
  /// empty space opened up on its right.
  double _leftExtent(MusicalElement element) {
    if (element is Note) {
      final glyph = _effectiveAccidentalGlyph(element);
      if (glyph == null) return 0.0;
      // SMuFL advises 0.25-0.3 staff spaces between accidental and notehead.
      return (_accidentalAdvanceWidth(glyph) + 0.3) * staffSpace;
    }
    if (element is Chord) {
      var widest = 0.0;
      for (final note in element.notes) {
        final glyph = _effectiveAccidentalGlyph(note);
        if (glyph == null) continue;
        final w = _accidentalAdvanceWidth(glyph);
        if (w > widest) widest = w;
      }
      return widest == 0 ? 0.0 : (widest + 0.5) * staffSpace;
    }
    return 0.0;
  }

  /// Width an element occupies to the RIGHT of its own origin, in pixels:
  /// the total width minus whatever hangs to the left. This is what the cursor
  /// advances by once the element has been placed.
  double _rightExtent(MusicalElement element) =>
      _getElementWidthSimple(element) - _leftExtent(element);

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
      // Reserve width for cancellation naturals of the outgoing key, which the
      // renderer draws before the new accidentals: previousCount.abs() naturals
      // at 0.8 SS each + a 0.5 SS gap (mirrors bar_element_renderer).
      double width = 0;
      final prev = element.previousCount;
      if (prev != null && prev != 0) {
        width += (prev.abs() * 0.8 + 0.5) * staffSpace;
      }
      if (element.count == 0) {
        // C major: only the cancellation naturals (if any), else a small pad.
        return width == 0 ? 0.5 * staffSpace : width;
      }
      final accidentalWidth = element.count > 0
          ? accidentalSharpWidth
          : accidentalFlatWidth;
      width += (element.count.abs() * 0.8 + accidentalWidth) * staffSpace;
      return width;
    }

    if (element is TimeSignature) {
      // Free time draws nothing, so it reserves no width.
      if (element.isFreeTime) return 0;
      // Width scales with the widest of the numerator/denominator digit counts
      // so multi-digit meters (12/8, 16, …) reserve enough room.
      final denDigits = element.denominator.toString().length;
      int numDigits;
      if (element.isAdditive) {
        // Group digits + one '+' separator slot per inter-group gap.
        final groups = element.additiveGroups!;
        numDigits = groups.fold<int>(0, (a, g) => a + g.numerator.toString().length) +
            (groups.length - 1);
      } else {
        numDigits = element.numerator.toString().length;
      }
      final digits = numDigits > denDigits ? numDigits : denDigits;
      return (1.6 + 1.4 * digits) * staffSpace;
    }

    if (element is Note) {
      double width = noteheadBlackWidth * staffSpace;
      final accGlyph = _effectiveAccidentalGlyph(element);
      if (accGlyph != null) {
        // SMuFL advises 0.25-0.3 staff spaces between accidental and notehead.
        width += (_accidentalAdvanceWidth(accGlyph) + 0.3) * staffSpace;
      }
      // Augmentation dots sit to the right of the notehead (DotRenderer: first
      // dot at centre + 1.0 SS, each further +0.6 SS), extending ~0.7 SS past
      // the notehead's right edge. Reserve it so dots never crowd the next note.
      if (element.duration.dots > 0) {
        width += (0.7 + (element.duration.dots - 1) * 0.6) * staffSpace;
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
        final accGlyph = _effectiveAccidentalGlyph(note);
        if (accGlyph != null) {
          final accWidth = _accidentalAdvanceWidth(accGlyph);
          if (accWidth > maxAccidentalWidth) {
            maxAccidentalWidth = accWidth;
          }
        }
      }

      if (maxAccidentalWidth > 0) {
        width += (maxAccidentalWidth + 0.5) * staffSpace;
      }
      // Reserve augmentation-dot space (see the Note branch).
      if (element.duration.dots > 0) {
        width += (0.7 + (element.duration.dots - 1) * 0.6) * staffSpace;
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
      // Width comes from the inner content laid out on the SHARED grid, so the
      // measure width, the note positions and the drawing all agree.
      return TupletGrid.totalWidth(element, staffSpace);
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

  /// Fix: calculates rhythmic spacing based on note duration
  ///
  /// Implementa spacing proporcional to the duração das notes according to
  /// práticas profissionais de music engraving (Behind Bars, Ted Ross)
  ///
  /// @param currentElement Elemento current
  /// @param previousElement Elemento previous (opcional)
  /// @return Spacing in pixels
  /// Horizontal gap to leave BEFORE [currentElement], given the element that
  /// precedes it.
  ///
  /// Gould's square-root law: the space an event occupies grows with the square
  /// root of its duration, normalised to the quarter note. The factor is
  /// COMPUTED, not looked up: the old table only covered `whole`..`sixtyFourth`
  /// and fell back to `1.0` for everything else, so a breve was spaced like a
  /// quarter (narrower than a whole note!) and a 128th got 2.3x the space of a
  /// 64th — the rhythmic proportion inverted at both ends of the range. It also
  /// ignored augmentation dots; `absoluteValue` includes them.
  double _calculateRhythmicSpacing(
    MusicalElement currentElement,
    MusicalElement? previousElement,
  ) {
    const double baseSpacing = noteMinSpacing;

    Duration? durationOf(MusicalElement? e) {
      if (e is Note) return e.duration;
      if (e is Chord) return e.duration;
      if (e is Rest) return e.duration;
      return null;
    }

    final prevDuration = durationOf(previousElement);

    // No previous rhythmic element (start of measure/system): use base spacing.
    if (prevDuration == null) {
      return baseSpacing * staffSpace * _spacingScale;
    }

    // The law itself lives in IntelligentSpacingEngine: sqrt(duration/quarter),
    // normalised to the quarter note, times the rest ratio when the previous
    // event was a rest. Calling it here is what puts that engine on the
    // production path — it used to be constructed, covered by 390 lines of
    // green tests, and never invoked, so those tests proved nothing about what
    // the renderer actually did.
    double spacing = _spacingEngine.interNoteSpacing(
      previousDuration: prevDuration,
      previousIsRest: previousElement is Rest,
      staffSpace: staffSpace,
      baseSpacing: baseSpacing,
    );

    // Context-sensitive optical compensation (alternating stems, rest before a
    // stem-up note, duration transitions). Returns 0.0 unless the caller
    // enabled it in SpacingPreferences.
    spacing += _spacingEngine.opticalAdjustment(
      previous: previousElement,
      current: currentElement,
      staffSpace: staffSpace,
    );

    // Leading space for the CURRENT element's accidental, which hangs to the
    // left of its notehead into THIS gap. The real metadata advance is used,
    // not a flat constant: `accidentalDoubleFlat` is 1.652 staff spaces wide
    // against `accidentalNatural`'s 0.672, and a constant cannot serve both.
    spacing += _leftExtent(currentElement);

    // A lyric syllable is centred on its notehead, so its left half hangs into
    // this gap. Without this a long syllable simply overlapped the previous
    // note (measured: "Extraordinarily" produced exactly the same spacing as no
    // syllable at all).
    final leadIn = _syllableOverhang(currentElement) +
        _syllableOverhang(previousElement);
    if (leadIn > 0) spacing += leadIn;

    spacing *= _spacingScale;

    // Never let compression (or an ultra-short duration) push two noteheads
    // into each other.
    final minimum = _minimumInterNoteGap(currentElement, previousElement);
    return spacing < minimum ? minimum : spacing;
  }

  /// Half of the width a note's widest lyric syllable sticks out past its
  /// notehead, in pixels. Zero when the element carries no syllable.
  double _syllableOverhang(MusicalElement? element) {
    final syllables = element is Note
        ? element.syllables
        : (element is Chord
            ? element.notes
                .map((n) => n.syllables)
                .firstWhere((s) => s != null && s.isNotEmpty,
                    orElse: () => null)
            : null);
    if (syllables == null || syllables.isEmpty) return 0.0;

    double widest = 0;
    for (final syllable in syllables) {
      final w = _syllableWidth(syllable);
      if (w > widest) widest = w;
    }
    final head = noteheadBlackWidth * staffSpace;
    final overhang = (widest - head) / 2;
    return overhang > 0 ? overhang : 0.0;
  }

  /// Rendered width of one lyric syllable, matching `NoteRenderer` metrics
  /// (font size = 0.85 staff spaces; ~0.5 em average advance per character).
  double _syllableWidth(Syllable syllable) {
    var text = syllable.text;
    if (syllable.type == SyllableType.initial ||
        syllable.type == SyllableType.middle) {
      text = '$text-';
    }
    if (text.isEmpty) return 0.0;

    const double lyricFontFactor = 0.85;
    final fontSize = staffSpace * lyricFontFactor;
    return _measuredTextWidth(text, fontSize, syllable.italic);
  }

  /// Rendered width of [text], measured with the same font stack and metrics
  /// `NoteRenderer._renderSyllable` draws with.
  ///
  /// This used to be `text.length * staffSpace * 0.85 * 0.5` — a character
  /// COUNT with an assumed half-em advance. "WWWWW" and "iiiii" reserved the
  /// same room, an ideograph reserved a third of what it needs, and the number
  /// never agreed with what the renderer actually painted. Layout and rendering
  /// disagreeing about a width is the F-12 pattern; measuring both with the
  /// same `TextPainter` makes them agree by construction.
  ///
  /// The measurement is cached: a syllable is re-measured on every relayout
  /// otherwise, and a `TextPainter.layout()` is not free.
  static final LruCache<String, double> _textWidthCache = LruCache(512);

  double _measuredTextWidth(String text, double fontSize, bool italic) {
    final key = '${fontSize.toStringAsFixed(2)}|${italic ? 'i' : 'r'}|$text';
    final cached = _textWidthCache.get(key);
    if (cached != null) return cached;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          height: 1.0,
        ).withMusicTextFallback(),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    _textWidthCache.put(key, width);
    return width;
  }

  /// Absolute floor for the gap between two consecutive rhythmic events.
  ///
  /// It has to clear whatever the PREVIOUS element leaves behind to its right
  /// plus whatever the CURRENT element hangs to its left, with a hair of air
  /// between them. Compression may squeeze the proportional spacing away, but
  /// it may never squeeze this.
  ///
  /// The accidental term used to be a flat `staffSpace * 0.6`, which is smaller
  /// than most accidentals and less than a third of a double flat. Measured: 32
  /// sixteenths each carrying a double flat, compressed into 400 px, came out
  /// 26.90 px apart — a 14.16 px notehead leaves 12.74 px of free space, and
  /// `accidentalDoubleFlat` is 19.82 px wide, so it drove 7.08 px into the
  /// previous notehead. The floor now asks the metadata.
  double _minimumInterNoteGap(
    MusicalElement currentElement,
    MusicalElement? previousElement,
  ) {
    final head = noteheadBlackWidth * staffSpace;
    // The cursor has already advanced past the previous element's right extent
    // when this gap is applied, so the floor only has to cover what the CURRENT
    // element hangs to its left, plus air. Adding the previous extent here
    // would double-count it.
    return _leftExtent(currentElement) + head * 0.9;
  }

  /// Resolves beam membership for [elements] and writes it back onto the
  /// notes **in place**.
  ///
  /// The engine used to build replacement [Note] objects here so it could store
  /// the resolved [BeamType]. That silently broke every identity-keyed map
  /// built before this point (accidental decisions, note X/Y positions), made
  /// the layout signature differ between two identical runs, and dropped a note
  /// whenever the same instance appeared twice in a measure. Beams are now
  /// stamped on the caller's own objects, so identity survives the whole
  /// pipeline — which is also what a future editor needs for hit-testing.
  ///
  /// Notes that end up in no valid group keep whatever beam the author set.
  List<MusicalElement> _processBeamsWithAnacrusis(
    List<MusicalElement> elements,
    TimeSignature? timeSignature, {
    bool autoBeaming = true,
    BeamingMode beamingMode = BeamingMode.automatic,
    List<List<int>> manualBeamGroups = const [],
  }) {
    timeSignature ??= TimeSignature(numerator: 4, denominator: 4);

    if (!elements.any((e) => e is Note)) return elements;

    final beamGroups = BeamGrouper.groupElementsForBeaming(
      elements,
      timeSignature,
      autoBeaming: autoBeaming,
      beamingMode: beamingMode,
      manualBeamGroups: manualBeamGroups,
    );

    for (final group in beamGroups) {
      if (!group.isValid) continue;
      final last = group.notes.length - 1;
      for (int i = 0; i <= last; i++) {
        group.notes[i].beam = i == 0
            ? BeamType.start
            : (i == last ? BeamType.end : BeamType.inner);
      }
    }

    return elements;
  }

  /// Total musical duration of [measure] in whole notes, voice aware: two
  /// voices sounding together occupy the same time, so the bar lasts as long as
  /// its longest voice, not as long as the sum of every note in it.
  double _measureMusicalDuration(Measure measure) {
    double durationOf(Iterable<MusicalElement> els) {
      double total = 0;
      for (final e in els) {
        total += _getRhythmicValue(e);
      }
      return total;
    }

    if (measure is MultiVoiceMeasure) {
      double longest = durationOf(measure.elements);
      for (final voice in measure.sortedVoices) {
        final v = durationOf(voice.elements);
        if (v > longest) longest = v;
      }
      return longest;
    }

    // Single-voice measures may still carry `Note.voice` tags (MusicXML import
    // writes them), so bucket by voice before summing.
    final byVoice = <int, double>{};
    for (final e in measure.elements) {
      final value = _getRhythmicValue(e);
      if (value <= 0) continue;
      final v = e is Note ? (e.voice ?? 1) : (e is Chord ? (e.voice ?? 1) : 1);
      byVoice[v] = (byVoice[v] ?? 0) + value;
    }
    if (byVoice.isEmpty) return 0.0;
    return byVoice.values.reduce((a, b) => a > b ? a : b);
  }

  /// Total horizontal extent of [elements], including the right-hand glyph of
  /// the last element and the right margin.
  ///
  /// The widget sizes its canvas from this number. If it under-reports, music
  /// is clipped away with no way to scroll to it (F-05b).
  double contentWidth(List<PositionedElement> elements) {
    if (elements.isEmpty) return systemMargin * 2 * staffSpace;
    var maxRight = 0.0;
    for (final positioned in elements) {
      final right =
          positioned.position.dx + _getElementWidthSimple(positioned.element);
      if (right > maxRight) maxRight = right;
    }
    // Justification already parks the last element on the right margin, so only
    // a hair of trailing air is added here — adding a full margin again would
    // report a phantom overflow for every justified system.
    return maxRight + staffSpace * 0.5;
  }

  /// Whether the laid-out music is wider than the line it was given, i.e. the
  /// host must provide horizontal scrolling for all of it to be reachable.
  bool overflowsAvailableWidth(List<PositionedElement> elements) =>
      contentWidth(elements) > availableWidth + 0.5;

  /// Vertical distance, in staff spaces, from the top of a system's block to
  /// its staff baseline. The painter places system N's baseline at
  /// `N * systemHeightSpaces + firstBaselineSpaces` staff spaces.
  static const double firstBaselineSpaces = 5.0;
  static const double systemHeightSpaces = 10.0;

  /// How much taller than the default headroom this score needs above the first
  /// staff line, in pixels. Zero when everything fits.
  ///
  /// The canvas used to start exactly [firstBaselineSpaces] staff spaces above
  /// the first baseline, whatever the music did. Anything reaching higher was
  /// simply cut off with no scroll and no warning: a C9 in treble clef landed at
  /// y = -114 on a canvas 192 px tall, and a boxed rehearsal mark sat entirely
  /// above the top edge. Callers add this to their canvas height and translate
  /// the origin down by the same amount.
  double contentTopOverflow(List<PositionedElement> elements) {
    if (elements.isEmpty) return 0.0;

    final headroom = firstBaselineSpaces * staffSpace;
    var worst = 0.0;

    for (final positioned in elements) {
      final baseline =
          (positioned.system * systemHeightSpaces + firstBaselineSpaces) *
              staffSpace;
      final reach =
          (baseline - positioned.position.dy) + _aboveStaffExtent(positioned);
      final overflow = reach - headroom;
      if (overflow > worst) worst = overflow;
    }
    return worst;
  }

  /// How much taller than the default bottom margin this score needs below the
  /// last staff line, in pixels. Zero when everything fits.
  ///
  /// The mirror of [contentTopOverflow]: a C0 in treble clef lands 264 px down
  /// on a canvas the old formula sized at 192 px, so it was cut off exactly the
  /// same way — the bug simply had two sides.
  double contentBottomOverflow(List<PositionedElement> elements) {
    if (elements.isEmpty) return 0.0;

    var maxSystem = 0;
    for (final positioned in elements) {
      if (positioned.system > maxSystem) maxSystem = positioned.system;
    }

    // Space the default formula already leaves below the LAST system's
    // baseline: the rest of its block plus the bottom margin.
    final lastBaseline =
        (maxSystem * systemHeightSpaces + firstBaselineSpaces) * staffSpace;
    final defaultBottom =
        (systemHeightSpaces - firstBaselineSpaces) * staffSpace +
            staffSpace * 2.0;

    var worst = 0.0;
    for (final positioned in elements) {
      if (positioned.system != maxSystem) continue;
      final reach = (positioned.position.dy - lastBaseline) +
          _belowStaffExtent(positioned);
      final overflow = reach - defaultBottom;
      if (overflow > worst) worst = overflow;
    }
    return worst;
  }

  /// How far below its own anchor an element draws, in pixels.
  double _belowStaffExtent(PositionedElement positioned) {
    final element = positioned.element;
    if (element is Note) {
      // Notehead half-height, plus the lyric block when the note is sung.
      var extent = staffSpace * 2.2;
      final syllables = element.syllables;
      if (syllables != null && syllables.isNotEmpty) {
        extent = staffSpace * (4.0 + 1.1 * syllables.length);
      }
      return extent;
    }
    if (element is Chord) {
      final sung = element.notes
          .map((n) => n.syllables?.length ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      return sung > 0 ? staffSpace * (4.0 + 1.1 * sung) : staffSpace * 2.2;
    }
    if (element is Dynamic) return staffSpace * 4.5;
    if (element is Rest) return staffSpace * 2.2;
    return staffSpace * 2.0;
  }

  /// How far above its own anchor an element draws, in pixels.
  ///
  /// Floating elements are positioned by the RENDERER relative to the staff, not
  /// by the layout, so their reach is expressed here as an allowance measured
  /// from the staff baseline (the top staff line is 2 staff spaces above it).
  double _aboveStaffExtent(PositionedElement positioned) {
    final element = positioned.element;
    if (element is MusicText) {
      switch (element.type) {
        case TextType.rehearsal:
          // centre 3.2 SS above the top line, plus half the box.
          return staffSpace * 6.4;
        case TextType.tempo:
          return staffSpace * 5.0;
        default:
          return staffSpace * 4.6;
      }
    }
    if (element is TempoMark) return staffSpace * 5.0;
    if (element is OctaveMark) return staffSpace * 4.6;
    if (element is Note || element is Chord) {
      // Notehead half-height plus a stem's worth of clearance; ledger lines and
      // articulations live inside this.
      return staffSpace * 2.2;
    }
    if (element is Rest) return staffSpace * 2.2;
    return staffSpace * 2.0;
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

    final double systemHeight = staffSpace * systemHeightSpaces;
    final double topMargin = staffSpace * 4.0;
    final double bottomMargin = staffSpace * 2.0;

    return topMargin +
        contentTopOverflow(elements) +
        ((maxSystem + 1) * systemHeight) +
        bottomMargin +
        contentBottomOverflow(elements);
  }
}
