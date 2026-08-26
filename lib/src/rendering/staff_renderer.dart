// lib/src/rendering/staff_renderer.dart
// Professional music engraving — corrected implementation
// Refactoring pass: Using tipos of the core/

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/core.dart'; // 🆕 Tipos do core
import '../layout/layout_engine.dart';
import 'accidental_resolver.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';
import '../beaming/beaming.dart'; // Sistema de beaming avançado
import 'renderers/articulation_renderer.dart';
import 'renderers/bar_element_renderer.dart';
import 'renderers/barline_renderer.dart';
import 'renderers/breath_renderer.dart';
import 'renderers/chord_renderer.dart';
import 'renderers/glyph_renderer.dart';
import 'renderers/group_renderer.dart';
import 'renderers/note_renderer.dart';
import 'renderers/ornament_renderer.dart';
import 'renderers/rest_renderer.dart';
import 'renderers/slur_renderer.dart'; // ✅ NOVO: Ligaduras profissionais
import 'renderers/symbol_and_text_renderer.dart';
import '../layout/skyline_calculator.dart';
import 'renderers/tuplet_renderer.dart';
import 'smufl_positioning_engine.dart';
import 'staff_coordinate_system.dart';
import 'staff_position_calculator.dart';
import 'text_font.dart';
import 'lyric_layout.dart';

class StaffRenderer {
  // CONSTANTES DE AJUSTE MANUAL

  // Margin after Barlines NORMAIS (single, double, dashed, etc)
  // Controla where as staff lines end when o system ends
  // with a barline normal (not a final barline)
  //
  // Fórmula: endX = bounds.endX + (staffSpace + systemEndMargin)
  //
  // applies-if a:
  //   - BarlineType.single (barra simples)
  //   - BarlineType.double (double barline)
  //   - BarlineType.dashed (barra tracejada)
  //   - All os tipos EXCETO BarlineType.final_
  //
  // Valores sugeridos:
  //   -12.0 = Lines end exatamente na barline
  //    0.0 = Margin default de 1 staff space
  //   -3.0 = Lines end a pouco before of the barra
  static const double systemEndMargin =
      -12.0; //  Termina exatamente na barra de compasso

  // Margin after Final barline (BarlineType.final_)
  // Controla where as staff lines end when o system ends
  // with a final barline (line fina + line grossa)
  //
  // applies-if Only a:
  //   - BarlineType.final_ (final barline) ✅
  //
  // Valores sugeridos:
  //   -1.5 = Lines end exatamente na final barline ✅
  //    0.0 = Margin default de 1 staff space
  static const double finalBarlineMargin =
      -1.5; // ✅ Termina exatamente na barra final

  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;

  late final double glyphSize;
  late final double staffLineThickness;
  late final double stemThickness;
  late final SMuFLPositioningEngine positioningEngine;

  Clef? currentClef;

  late final GlyphRenderer glyphRenderer;
  late final ArticulationRenderer articulationRenderer;
  late final BarElementRenderer barElementRenderer;
  late final BarlineRenderer barlineRenderer;
  late final BeamRenderer beamRenderer;
  late final BreathRenderer breathRenderer;
  late final ChordRenderer chordRenderer;
  late final GroupRenderer groupRenderer;
  late final NoteRenderer noteRenderer;
  late final OrnamentRenderer ornamentRenderer;
  late final RestRenderer restRenderer;
  late final SymbolAndTextRenderer symbolAndTextRenderer;
  late final TupletRenderer tupletRenderer;
  late SlurRenderer slurRenderer; // ✅ NOVO: Renderizador profissional

  StaffRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
  }) {
    // CORREÇÃO TIPOGRÃIs: Size correct of the glifo based on SMuFL
    glyphSize = coordinates.staffSpace * 4.0;

    // Fix: Use valores corretos of the metadata Bravura
    // Always pass a fallback: `getEngravingDefault` returns 0.0 for a missing
    // key, and a 0-thickness staff line is an INVISIBLE staff with no error.
    staffLineThickness =
        metadata.getEngravingDefault('staffLineThickness', 0.13) *
        coordinates.staffSpace;
    stemThickness =
        metadata.getEngravingDefault('stemThickness', 0.12) *
        coordinates.staffSpace;

    // Initialize SMuFL positioning engine with already loaded metadata
    positioningEngine = SMuFLPositioningEngine(metadataLoader: metadata);

    // Initialize all the specialized renderers
    glyphRenderer = GlyphRenderer(metadata: metadata);

    ornamentRenderer = OrnamentRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      staffLineThickness: staffLineThickness,
    );

    articulationRenderer = ArticulationRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
    );

    barElementRenderer = BarElementRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
    );

    barlineRenderer = BarlineRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphRenderer: glyphRenderer,
      glyphSize: glyphSize,
    );

    beamRenderer = BeamRenderer(
      theme: theme,
      staffSpace: coordinates.staffSpace,
      noteheadWidth:
          metadata.getGlyphWidth('noteheadBlack') * coordinates.staffSpace,
      positioningEngine: positioningEngine,
    );

    breathRenderer = BreathRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      glyphRenderer: glyphRenderer,
    );

    noteRenderer = NoteRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      staffLineThickness: staffLineThickness,
      stemThickness: stemThickness,
      articulationRenderer: articulationRenderer,
      ornamentRenderer: ornamentRenderer,
      positioningEngine: positioningEngine,
    );

    chordRenderer = ChordRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      staffLineThickness: staffLineThickness,
      stemThickness: stemThickness,
      noteRenderer: noteRenderer,
    );

    restRenderer = RestRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      ornamentRenderer: ornamentRenderer,
    );

    symbolAndTextRenderer = SymbolAndTextRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
    );

    groupRenderer = GroupRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      staffLineThickness: staffLineThickness,
      stemThickness: stemThickness,
    );

    tupletRenderer = TupletRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      noteRenderer: noteRenderer,
      restRenderer: restRenderer,
      positioningEngine: positioningEngine,
      // Chords inside tuplets used to be skipped by every render branch.
      chordRenderer: chordRenderer,
    );

    // ✅ Initialise SlurRenderer profissional
    slurRenderer = SlurRenderer(
      staffSpace: coordinates.staffSpace,
      staffBaselineY: coordinates.staffBaseline.dy,
      metadata: metadata,
    );
  }

  // Set de notes that are in advanced beam groups
  final Set<Note> _notesInAdvancedBeams = {};
  final Map<Note, Clef> _noteClefs = {};

  /// 8va/8vb displacement in force at each note, filled during the first pass.
  ///
  /// The bracket axis is tracked exactly like [_noteClefs] and for the same
  /// reason: the later passes (beams, ties, slurs, ornament lines) re-derive a
  /// notehead's Y from its pitch, so they need the SAME displacement the first
  /// pass drew with. Before this existed the bracket had no reader at all —
  /// C6 measured staffPosition 8 / Y 12.0 with no mark and staffPosition 8 /
  /// Y 12.0 under each of 8va/8vb/15ma/15mb/22da/22db.
  final Map<Note, int> _noteOctaveShifts = {};

  /// Bracket spans of the element list currently being rendered, resolved by
  /// (measure, onset) rather than by document position.
  ///
  /// The octave bracket belongs to the STAFF, not to one voice
  /// ([OctaveSpanTimeline] carries the MusicXML/MEI reasoning), and a
  /// polyphonic bar reaches this renderer with voice 1 serialised in full
  /// before voice 2 — so a document-order walk gave the same marking two
  /// different meanings depending on which voice it was typed in. Every
  /// `PositionedElement` already carries the onset and measure index the
  /// layout gave it, which is exactly what the timeline needs, so this
  /// rebuilds the engine's own answer from the list alone.
  OctaveSpanTimeline _octaveSpan = OctaveSpanTimeline.empty;

  // Notes to skip drawing (drawn elsewhere, e.g. by the cross-staff beam pass).
  Set<Note> _skipNotes = const {};

  /// Within-measure accidental decisions for the current render pass (set from
  /// the layout engine, which resolves them from the model).
  Map<Note, AccidentalDisplay> _accidentalDecisions = const {};

  /// Beam membership of the notes INSIDE tuplets, decided by the layout engine
  /// and read (never recomputed, never written back) by `TupletRenderer`.
  /// See `LayoutEngine.tupletBeams` for why this is a value and not a mutation.
  Map<Note, BeamType>? _tupletBeams;

  /// Beam membership of the notes OUTSIDE tuplets, decided by the layout engine
  /// and read — never recomputed, never written back — by this renderer and by
  /// `GroupRenderer`. See `LayoutEngine.beams`: painting a score must leave the
  /// caller's `Note.beam` fields exactly as it found them.
  Map<Note, BeamType>? _beams;

  /// The beam in force for [note]: the engine's decision when it made one, the
  /// author's own [Note.beam] hint otherwise (and the hint alone when this
  /// renderer runs with no layout engine at all).
  BeamType? _beamOf(Note note) => _beams?[note] ?? note.beam;

  /// `LayoutEngine.aboveStaffLevels`: which row above the staff each floating
  /// mark was packed into, so two tempo directions stop being drawn on top of
  /// each other.
  Map<MusicalElement, int> _aboveStaffLevels = const {};
  double _aboveStaffLevelHeight = 0.0;

  /// `LayoutEngine.elementLeftExtent`, handed to `TupletRenderer` so the grid
  /// it draws on is the accidental-aware grid the layout reserved space for.
  /// Null only when this renderer runs without a layout engine.
  double Function(MusicalElement)? _elementLeftExtent;

  /// `LayoutEngine.tupletContextFloor`, handed to `TupletRenderer` for the same
  /// reason: the legibility scale of the tuplet grid is measured over the whole
  /// MEASURE (findings M-08 / M-31) and a renderer holding one tuplet cannot
  /// see the measure. Null only when this renderer runs without a layout
  /// engine, in which case the grid falls back to the per-group scale.
  Map<Tuplet, double>? _tupletContextFloor;

  void renderStaff(
    Canvas canvas,
    List<PositionedElement> elements,
    Size size, {
    LayoutEngine? layoutEngine,
    bool renderBarlines = true,
    Set<Note> skipNotes = const {},
    bool renderMeasureNumbers = true,
  }) {
    _skipNotes = skipNotes;
    // Limpar set de notes beamed
    _notesInAdvancedBeams.clear();
    _noteClefs.clear();
    _noteOctaveShifts.clear();
    _octaveSpan = OctaveSpanTimeline([
      for (final positioned in elements)
        if (positioned.element case final OctaveMark mark)
          OctaveSpanEvent(positioned.measureIndex, positioned.onset, mark),
    ]);
    // Prefer the engine's own answer: `renderStaff` may be handed ONE SYSTEM at
    // a time (`ScoreRasterizer` does), and a tracker restarted per system would
    // lose a bracket that opened on an earlier one. The tracker below is the
    // fallback for the no-layout-engine path and for notes the engine did not
    // register (a bare element list built by hand in a test, for instance).
    final layoutShifts = layoutEngine?.noteOctaveShifts ?? const <Note, int>{};
    _noteOctaveShifts.addAll(layoutShifts);
    _accidentalDecisions = layoutEngine?.accidentalDecisions ?? const {};
    _tupletBeams = layoutEngine?.tupletBeams;
    _beams = layoutEngine?.beams;
    // Stacking rows for marks above the staff. A direction has no horizontal
    // advance by design, so when two of them overlap the only way out is up.
    _aboveStaffLevels = layoutEngine?.aboveStaffLevels ?? const {};
    _aboveStaffLevelHeight = layoutEngine?.aboveStaffLevelHeight ?? 0.0;
    _elementLeftExtent = layoutEngine?.elementLeftExtent;
    _tupletContextFloor = layoutEngine?.tupletContextFloor;

    // Coletar notes that are in advanced beam groups
    if (layoutEngine != null) {
      for (final group in layoutEngine.advancedBeamGroups) {
        _notesInAdvancedBeams.addAll(group.notes);
      }
    }

    // Desenhar staff lines By System
    _drawStaffLinesBySystem(canvas, elements);
    currentClef = Clef(clefType: ClefType.treble); // Default clef

    // Primeira passagem: renderizar elementos individuais
    for (int i = 0; i < elements.length; i++) {
      _renderElement(
        canvas,
        elements[i],
        elements,
        i,
        renderBarlines: renderBarlines,
      );
    }

    // Segunda passagem: renderizar ADVANCED BEAMS (if disponível)
    if (layoutEngine != null && layoutEngine.advancedBeamGroups.isNotEmpty) {
      final noteXPositions = layoutEngine.noteXPositions;
      final noteYPositions = layoutEngine.noteYPositions;

      for (final advancedGroup in layoutEngine.advancedBeamGroups) {
        // A beam group with any skipped (cross-staff) note is redrawn whole by
        // the grand-staff cross-staff beam pass.
        if (_skipNotes.isNotEmpty &&
            advancedGroup.notes.any(_skipNotes.contains)) {
          continue;
        }
        beamRenderer.renderAdvancedBeamGroup(
          canvas,
          advancedGroup,
          noteXPositions: noteXPositions,
          noteYPositions: noteYPositions,
        );
      }
    }

    // Measure numbers above the first bar of every system (Behind Bars).
    if (renderMeasureNumbers &&
        theme.showMeasureNumbers &&
        layoutEngine != null) {
      _renderMeasureNumbers(canvas, elements, layoutEngine.measureNumbers);
    }

    // Terceira passagem: renderizar elementos de grupo (beams simples, ties, slurs)
    if (currentClef != null) {
      _renderLineOrnaments(canvas, elements);
      _renderLyricHyphens(canvas, elements);
      _renderMelismaLines(canvas, elements);

      // Pular beams simples if temos advanced beams
      if (layoutEngine == null || layoutEngine.advancedBeamGroups.isEmpty) {
        // Exclude skipped (cross-staff) notes so their beam isn't drawn here —
        // the grand-staff cross-staff pass draws it between the staves.
        final beamElements = _skipNotes.isEmpty
            ? elements
            : elements
                .where((pe) =>
                    !(pe.element is Note && _skipNotes.contains(pe.element)))
                .toList();
        groupRenderer.renderBeams(
          canvas,
          beamElements,
          currentClef!,
          octaveShifts: _noteOctaveShifts,
          beamTypes: _beams,
        );
      }

      // Build skyline from positioned elements for slur collision avoidance
      final skylineCalc = SkyBottomLineCalculator();
      if (elements.isNotEmpty) {
        final maxX =
            elements.fold(
              0.0,
              (m, e) => e.position.dx > m ? e.position.dx : m,
            ) +
            coordinates.staffSpace * 2;
        skylineCalc.initialize(maxX);
        for (final pe in elements) {
          if (pe.element is Note || pe.element is Rest) {
            final hw = coordinates.staffSpace * 0.6;
            skylineCalc.updateSkyLineRange(
              pe.position.dx - hw,
              pe.position.dx + hw,
              pe.position.dy - coordinates.staffSpace * 2.5,
            );
            skylineCalc.updateBottomLineRange(
              pe.position.dx - hw,
              pe.position.dx + hw,
              pe.position.dy + coordinates.staffSpace * 2.5,
            );
          }
        }
      }

      // Rebuild slurRenderer with the new skyline calculator
      slurRenderer = SlurRenderer(
        staffSpace: coordinates.staffSpace,
        staffBaselineY: coordinates.staffBaseline.dy,
        metadata: metadata,
        skylineCalculator: skylineCalc,
        octaveShifts: _noteOctaveShifts,
      );

      // ✅ Use SLURRENDERER PROFISSIONAL to the invés of the GroupRenderer
      final tieGroups = groupRenderer.identifyTieGroups(elements);
      final slurGroups = groupRenderer.identifySlurGroups(elements);

      slurRenderer.renderTies(
        canvas: canvas,
        tieGroups: tieGroups,
        positions: elements,
        currentClef: currentClef!,
        color: theme.tieColor ?? theme.noteheadColor,
      );

      slurRenderer.renderSlurs(
        canvas: canvas,
        slurGroups: slurGroups,
        positions: elements,
        currentClef: currentClef!,
        color: theme.slurColor ?? theme.noteheadColor,
      );
    }
  }

  /// Post-layout pass (#14): draws the connecting hyphen CENTERED between
  /// consecutive syllables of a hyphenated word, instead of gluing it to the
  /// syllable text. Operates per verse line, within a single system (this method
  /// only sees the current system's elements).
  void _renderLyricHyphens(Canvas canvas, List<PositionedElement> elements) {
    final lyricNotes = <({Note note, double x})>[];
    for (final pe in elements) {
      final el = pe.element;
      if (el is Note && el.syllables != null && el.syllables!.isNotEmpty) {
        lyricNotes.add((note: el, x: pe.position.dx));
      }
    }
    if (lyricNotes.length < 2) return;

    final fontSize = coordinates.staffSpace * 0.85;
    final lineHeight = fontSize * 1.3;
    // The same measured lyric line `NoteRenderer` drew the syllables on, so the
    // hyphens and melisma lines cannot land somewhere else. This was three
    // copies of one fixed offset; it is one function now, and it measures.
    final firstLineY = LyricLayout.firstLineY(
      elements: elements,
      system: elements.isEmpty ? 0 : elements.first.system,
      staffBaselineY: coordinates.staffBaseline.dy,
      staffSpace: coordinates.staffSpace,
    );
    final color = theme.noteheadColor.withValues(alpha: 0.85);

    TextStyle styleFor(bool italic) {
      final base = theme.lyricTextStyle ?? const TextStyle();
      return base.copyWith(
        fontSize: base.fontSize ?? fontSize,
        color: base.color ?? color,
        fontStyle:
            italic ? FontStyle.italic : (base.fontStyle ?? FontStyle.normal),
        height: 1.0,
      );
    }

    double measure(String text, bool italic) {
      final tp = TextPainter(
        text: TextSpan(
            text: text, style: styleFor(italic).withMusicTextFallback()),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    for (int verse = 0; verse < 32; verse++) {
      var anyAtVerse = false;
      ({Note note, double x})? prev;
      for (final ln in lyricNotes) {
        final syls = ln.note.syllables!;
        if (verse >= syls.length) continue;
        anyAtVerse = true;
        final syl = syls[verse];
        if (prev != null) {
          final prevSyl = prev.note.syllables![verse];
          if (prevSyl.type == SyllableType.initial ||
              prevSyl.type == SyllableType.middle) {
            final prevRight = prev.x + measure(prevSyl.text, prevSyl.italic) / 2;
            final curLeft = ln.x - measure(syl.text, syl.italic) / 2;
            final midX = (prevRight + curLeft) / 2;
            final lyricY = firstLineY + verse * lineHeight;
            final hp = TextPainter(
              text: TextSpan(
                  text: '-',
                  style: styleFor(prevSyl.italic).withMusicTextFallback()),
              textDirection: TextDirection.ltr,
            )..layout();
            hp.paint(
              canvas,
              Offset(midX - hp.width / 2, lyricY - hp.height / 2),
            );
          }
        }
        prev = ln;
      }
      if (!anyAtVerse) break;
    }
  }

  /// Post-layout pass (#13): draws melisma extension lines. A single/terminal
  /// syllable (end of a word) sung over subsequent note(s) that carry no
  /// syllable extends a horizontal line from the syllable to the last melisma
  /// note. The melisma ends at the next syllable, a rest, or the system end.
  void _renderMelismaLines(Canvas canvas, List<PositionedElement> elements) {
    var maxVerses = 0;
    for (final pe in elements) {
      final el = pe.element;
      if (el is Note && el.syllables != null) {
        if (el.syllables!.length > maxVerses) maxVerses = el.syllables!.length;
      }
    }
    if (maxVerses == 0) return;

    final fontSize = coordinates.staffSpace * 0.85;
    final lineHeight = fontSize * 1.3;
    // The same measured lyric line `NoteRenderer` drew the syllables on, so the
    // hyphens and melisma lines cannot land somewhere else. This was three
    // copies of one fixed offset; it is one function now, and it measures.
    final firstLineY = LyricLayout.firstLineY(
      elements: elements,
      system: elements.isEmpty ? 0 : elements.first.system,
      staffBaselineY: coordinates.staffBaseline.dy,
      staffSpace: coordinates.staffSpace,
    );
    final color = theme.noteheadColor.withValues(alpha: 0.85);
    final noteHalfWidth =
        ((metadata.getGlyphInfo('noteheadBlack')?.boundingBox?.width ?? 1.18) *
            coordinates.staffSpace) *
        0.5;

    double measure(String text, bool italic) {
      final base = theme.lyricTextStyle ?? const TextStyle();
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: base
              .copyWith(
                fontSize: base.fontSize ?? fontSize,
                fontStyle: italic
                    ? FontStyle.italic
                    : (base.fontStyle ?? FontStyle.normal),
              )
              .withMusicTextFallback(),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    for (int verse = 0; verse < maxVerses; verse++) {
      double? startX; // right edge of the held syllable text
      double? endX; // right edge of the last melisma note
      final y = firstLineY + verse * lineHeight + fontSize * 0.28;

      void flush() {
        if (startX != null &&
            endX != null &&
            endX! - startX! > coordinates.staffSpace * 0.6) {
          final paint = Paint()
            ..color = color
            ..strokeWidth = coordinates.staffSpace * 0.1
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(Offset(startX!, y), Offset(endX!, y), paint);
        }
        startX = null;
        endX = null;
      }

      for (final pe in elements) {
        final el = pe.element;
        if (el is Note) {
          final syls = el.syllables;
          final hasSyl =
              syls != null && verse < syls.length && syls[verse].text.isNotEmpty;
          if (hasSyl) {
            flush();
            final syl = syls[verse];
            if (syl.type == SyllableType.single ||
                syl.type == SyllableType.terminal) {
              startX = pe.position.dx +
                  measure(syl.text, syl.italic) / 2 +
                  coordinates.staffSpace * 0.35;
              endX = null;
            }
          } else if (startX != null) {
            endX = pe.position.dx + noteHalfWidth;
          }
        } else if (el is Rest) {
          flush();
        }
      }
      flush();
    }
  }

  void _renderLineOrnaments(Canvas canvas, List<PositionedElement> elements) {
    final linePaint = Paint()
      ..color = theme.ornamentColor ?? theme.noteheadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = coordinates.staffSpace * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final noteheadInfo = metadata.getGlyphInfo('noteheadBlack');
    final bbox = noteheadInfo?.boundingBox;
    final noteheadHalfWidth =
        ((bbox?.width ?? 1.18) * coordinates.staffSpace) * 0.5;
    final noteheadHalfHeight =
        ((bbox?.height ?? 1.0) * coordinates.staffSpace) * 0.5;
    final noteheadCenterX =
        ((bbox?.centerX ?? ((bbox?.width ?? 1.18) * 0.5)) *
        coordinates.staffSpace);
    final noteheadCenterY = (bbox?.centerY ?? 0.0) * coordinates.staffSpace;

    for (int i = 0; i < elements.length; i++) {
      final current = elements[i];
      if (current.element is! Note) continue;

      final note = current.element as Note;
      final lineOrnament = note.ornaments.where((ornament) {
        return ornament.type == OrnamentType.glissando ||
            ornament.type == OrnamentType.portamento ||
            ornament.type == OrnamentType.slide;
      }).firstOrNull;
      if (lineOrnament == null) continue;

      final next = _findNextNote(elements, i, current.system);
      if (next == null) continue;

      final currentCenter = _resolveRenderedNoteCenter(
        current,
        noteheadCenterX,
        noteheadCenterY,
      );
      final nextCenter = _resolveRenderedNoteCenter(
        next,
        noteheadCenterX,
        noteheadCenterY,
      );
      final start = _ellipseBoundaryToward(
        currentCenter,
        nextCenter,
        noteheadHalfWidth,
        noteheadHalfHeight,
      );
      final end = _ellipseBoundaryToward(
        nextCenter,
        currentCenter,
        noteheadHalfWidth,
        noteheadHalfHeight,
      );
      final startX = start.dx;
      final endX = end.dx;
      if (endX <= startX) continue;
      final startY = start.dy;
      final endY = end.dy;

      if (lineOrnament.type == OrnamentType.glissando) {
        final path = Path()
          ..moveTo(startX, startY)
          ..lineTo(endX, endY);
        canvas.drawPath(path, linePaint);
      } else {
        final path = Path()..moveTo(startX, startY);
        final segments =
            (((endX - startX) / coordinates.staffSpace).round() * 3).clamp(
              8,
              36,
            );
        final amplitude = coordinates.staffSpace * 0.18;
        for (int s = 1; s <= segments; s++) {
          final t = s / segments;
          final x = startX + ((endX - startX) * t);
          final yLinear = startY + ((endY - startY) * t);
          final yWave = yLinear + ((s.isEven ? -1 : 1) * amplitude);
          path.lineTo(x, yWave);
        }
        canvas.drawPath(path, linePaint);
      }

      if (lineOrnament.type == OrnamentType.glissando) {
        final labelStyle =
            theme.textStyle?.copyWith(
              fontSize: coordinates.staffSpace * 0.62,
              fontStyle: FontStyle.italic,
              color: theme.ornamentColor ?? theme.noteheadColor,
            ) ??
            TextStyle(
              fontSize: coordinates.staffSpace * 0.62,
              fontStyle: FontStyle.italic,
              color: theme.ornamentColor ?? theme.noteheadColor,
            );
        final label = TextPainter(
          text: TextSpan(
              text: 'gliss.', style: labelStyle.withMusicTextFallback()),
          textDirection: TextDirection.ltr,
        )..layout();

        final midX = (startX + endX) / 2;
        final midY = (startY + endY) / 2;
        final angle = math.atan2(endY - startY, endX - startX);
        canvas.save();
        canvas.translate(midX, midY - (coordinates.staffSpace * 0.28));
        canvas.rotate(angle);
        label.paint(canvas, Offset(-(label.width * 0.5), -label.height));
        canvas.restore();
      }
    }
  }

  /// Records the bracket displacement for every note nested inside [tuplet]
  /// (recursively), so the later beam/tie/slur passes — which only ever see the
  /// tuplet as one opaque positioned element — can still look each inner note up
  /// in [_noteOctaveShifts].
  void _recordTupletOctaveShifts(Tuplet tuplet, int extraOctaveShift) {
    for (final inner in tuplet.elements) {
      if (inner is Note) {
        // putIfAbsent, never `=`: the layout engine already registered these in
        // `_registerTupletNotes` and its answer wins.
        _noteOctaveShifts.putIfAbsent(inner, () => extraOctaveShift);
      } else if (inner is Chord) {
        for (final note in inner.notes) {
          _noteOctaveShifts.putIfAbsent(note, () => extraOctaveShift);
        }
      } else if (inner is Tuplet) {
        _recordTupletOctaveShifts(inner, extraOctaveShift);
      }
    }
  }

  /// Bracket displacement the layout engine gave the first note nested anywhere
  /// inside [tuplet], or null when the engine registered none of them.
  int? _tupletOctaveShift(Tuplet tuplet) {
    for (final inner in tuplet.elements) {
      if (inner is Note) {
        final shift = _noteOctaveShifts[inner];
        if (shift != null) return shift;
      } else if (inner is Chord) {
        for (final note in inner.notes) {
          final shift = _noteOctaveShifts[note];
          if (shift != null) return shift;
        }
      } else if (inner is Tuplet) {
        final shift = _tupletOctaveShift(inner);
        if (shift != null) return shift;
      }
    }
    return null;
  }

  Offset _resolveRenderedNoteCenter(
    PositionedElement positioned,
    double noteheadCenterX,
    double noteheadCenterY,
  ) {
    final element = positioned.element;
    if (element is! Note) {
      return positioned.position;
    }

    final clef = _noteClefs[element] ?? currentClef;
    if (clef == null) {
      return Offset(
        positioned.position.dx + noteheadCenterX,
        positioned.position.dy + noteheadCenterY,
      );
    }

    final staffPosition = StaffPositionCalculator.calculate(
      element.pitch,
      clef,
      extraOctaveShift: _noteOctaveShifts[element] ?? 0,
    );
    final renderedY = StaffPositionCalculator.toPixelY(
      staffPosition,
      coordinates.staffSpace,
      coordinates.staffBaseline.dy,
    );

    return Offset(
      positioned.position.dx + noteheadCenterX,
      renderedY + noteheadCenterY,
    );
  }

  Offset _ellipseBoundaryToward(
    Offset center,
    Offset target,
    double halfWidth,
    double halfHeight,
  ) {
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;
    if (dx.abs() < 0.0001 && dy.abs() < 0.0001) {
      return center;
    }

    final divisor = math.sqrt(
      ((dx * dx) / (halfWidth * halfWidth)) +
          ((dy * dy) / (halfHeight * halfHeight)),
    );
    final scale = divisor == 0 ? 0.0 : 1 / divisor;
    return Offset(center.dx + (dx * scale), center.dy + (dy * scale));
  }

  PositionedElement? _findNextNote(
    List<PositionedElement> elements,
    int fromIndex,
    int system,
  ) {
    for (int i = fromIndex + 1; i < elements.length; i++) {
      final candidate = elements[i];
      if (candidate.system != system) continue;
      if (candidate.element is Note) return candidate;
    }
    return null;
  }

  /// Desenha staff lines By System
  /// Each system tem their lines ending na última barline daquele system
  /// Draws the measure number above the first measure of each system.
  ///
  /// `Measure.number` (MEI `<measure @n>`) has existed in the model since 2.x
  /// but nothing ever rendered it — a professional score without bar numbers is
  /// unusable for rehearsal. Convention (Gould): number at the start of every
  /// system, above the staff, left-aligned on the first element; bar 1 is not
  /// numbered.
  void _renderMeasureNumbers(
    Canvas canvas,
    List<PositionedElement> elements,
    Map<int, int> measureNumbers,
  ) {
    if (elements.isEmpty) return;

    // First positioned element of each (system, measure) pair.
    final firstOfSystem = <int, PositionedElement>{};
    for (final pe in elements) {
      if (pe.measureIndex < 0) continue;
      final current = firstOfSystem[pe.system];
      if (current == null ||
          pe.measureIndex < current.measureIndex ||
          (pe.measureIndex == current.measureIndex &&
              pe.position.dx < current.position.dx)) {
        firstOfSystem[pe.system] = pe;
      }
    }

    // Merge, do not replace: a theme that only supplies a font family must not
    // lose the staff-derived size and colour.
    final base = TextStyle(
      fontSize: coordinates.staffSpace * 0.9,
      color: theme.textColor ?? theme.staffLineColor,
      fontWeight: FontWeight.w500,
    );
    final override = theme.measureNumberTextStyle;
    final style = override == null ? base : base.merge(override);

    for (final entry in firstOfSystem.entries) {
      final pe = entry.value;
      final number = measureNumbers[pe.measureIndex];
      if (number == null || number <= 1) continue;

      final painter = TextPainter(
        text: TextSpan(text: '$number', style: style.withMusicTextFallback()),
        textDirection: TextDirection.ltr,
      )..layout();

      // Staff top line sits 2 staff spaces above the system baseline.
      // (Never use pe.position.dy: for a Note that is the NOTEHEAD's y.)
      final staffTopY =
          coordinates.staffBaseline.dy - 2 * coordinates.staffSpace;
      painter.paint(
        canvas,
        Offset(
          pe.position.dx,
          staffTopY - coordinates.staffSpace * 1.4 - painter.height,
        ),
      );
    }
  }

  void _drawStaffLinesBySystem(
    Canvas canvas,
    List<PositionedElement> elements,
  ) {
    if (elements.isEmpty) return;

    // Agrupar elementos by system and Calculate limites
    final systemBounds = <int, ({double startX, double endX, double y})>{};
    final lastBarlineType =
        <int, BarlineType>{}; // Tipo da última barra de cada sistema

    final lastBarlineX = <int, double>{};

    for (final positioned in elements) {
      final system = positioned.system;
      final x = positioned.position.dx;
      final y = positioned.position.dy;

      if (!systemBounds.containsKey(system)) {
        systemBounds[system] = (startX: x, endX: x, y: y);
      } else {
        final current = systemBounds[system]!;
        systemBounds[system] = (
          startX: current.startX < x ? current.startX : x,
          endX: current.endX > x ? current.endX : x,
          y: current.y,
        );
      }

      // Guardar o type of the última barline de each system
      if (positioned.element is Barline) {
        lastBarlineType[system] = (positioned.element as Barline).type;
        lastBarlineX[system] = positioned.position.dx;
      }
    }

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness
      ..style = PaintingStyle.stroke;
    final thinBarlineThickness =
        metadata.getEngravingDefault('thinBarlineThickness', 0.16) *
        coordinates.staffSpace;
    final thickBarlineThickness =
        metadata.getEngravingDefault('thickBarlineThickness', 0.5) *
        coordinates.staffSpace;

    // Desenhar lines for each system separadamente
    for (final entry in systemBounds.entries) {
      final systemNumber = entry.key;
      final bounds = entry.value;
      final barlineType = lastBarlineType[systemNumber];

      // Use margin baseada no Type DE BARRA, not na position of the system
      // Final barline (BarlineType.final_) Uses finalBarlineMargin
      // Other barras use systemEndMargin
      final barlineX = lastBarlineX[systemNumber];
      final contentEndX = bounds.endX + (coordinates.staffSpace * 0.8);
      final barlineEndX = (barlineType != null && barlineX != null)
          ? barlineX +
                _barlineGlyphWidth(
                  barlineType,
                  thinBarlineThickness,
                  thickBarlineThickness,
                )
          : contentEndX;
      final endX = math.max(contentEndX, barlineEndX);

      // Desenhar as 5 staff lines for this system
      // ✅ CORREÇÃO: Use coordinates.getStaffLineY() diretamente, that already tem
      // a Y position correct for this system (baseada in staffBaseline.dy).
      // Not Use bounds.y pois can be a Y position de a note (pitch-based)
      // and not o centre of the staff.
      for (int line = 1; line <= 5; line++) {
        final lineY = coordinates.getStaffLineY(line);

        canvas.drawLine(
          Offset(coordinates.staffBaseline.dx, lineY),
          Offset(endX, lineY),
          paint,
        );
      }
    }
  }


  /// How far a hairpin with no explicit length should reach, or null.
  ///
  /// A hairpin spans to the next dynamic or the barline in the same system
  /// (Behind Bars), leaving a small gap before it.
  ///
  /// This used to live inline in the branch that draws a STANDALONE `Dynamic`,
  /// which meant a hairpin attached to a note — `Note(dynamicElement: ...)`,
  /// the form every example in this package uses — never got a musical span at
  /// all. It fell through to `staffSpace * 6`, a fixed stub with no
  /// relationship to the music, which is why the crescendo and diminuendo on
  /// the dynamics page sat bunched at the left of their bars instead of
  /// reaching across them.
  double? _hairpinSpan(
    Dynamic dynamic, {
    required double fromX,
    required int index,
    required int system,
    required List<PositionedElement> allElements,
  }) {
    if (!dynamic.isHairpin || dynamic.length != null) return null;

    double? stopX;
    var stopIsDynamic = false;
    for (int j = index + 1; j < allElements.length; j++) {
      final pe = allElements[j];
      if (pe.system != system) break;
      final other = pe.element;
      // A note carrying its own dynamic stops the hairpin just as a standalone
      // one does — otherwise a crescendo would run straight through the mark
      // that is supposed to end it.
      if (other is Dynamic || (other is Note && other.dynamicElement != null)) {
        stopX = pe.position.dx;
        stopIsDynamic = true;
        break;
      }
      if (other is Barline) {
        stopX = pe.position.dx;
        break;
      }
    }
    if (stopX == null) return null;

    // The next dynamic letter is drawn centered on its X, so leave room for its
    // left half plus a margin; a barline only needs a small gap.
    final gap = stopIsDynamic
        ? coordinates.staffSpace * 1.4
        : coordinates.staffSpace * 0.5;
    final span = stopX - fromX - gap;
    return span >= coordinates.staffSpace * 2 ? span : null;
  }

  void _renderElement(
    Canvas canvas,
    PositionedElement positioned,
    List<PositionedElement> allElements,
    int index, {
    required bool renderBarlines,
  }) {
    final element = positioned.element;
    final basePosition = positioned.position;

    // A bracket takes effect at the musical INSTANT the author put it at and
    // applies to every voice of the staff from there on, so it is resolved
    // against the timeline by (measure, onset) — not by this list's order,
    // which puts all of voice 1 before all of voice 2.
    final trackedOctaveShift = _octaveSpan.shiftAt(
      measureIndex: positioned.measureIndex,
      onset: positioned.onset,
    );
    final extraOctaveShift = switch (element) {
      Note() => _noteOctaveShifts[element] ?? trackedOctaveShift,
      Chord(notes: final ns) when ns.isNotEmpty =>
        _noteOctaveShifts[ns.first] ?? trackedOctaveShift,
      Tuplet() => _tupletOctaveShift(element) ?? trackedOctaveShift,
      _ => trackedOctaveShift,
    };

    if (element is Clef) {
      currentClef = element;
      // A clef appearing after musical content in the same system is a change,
      // drawn at cue size (~72%, Behind Bars/Verovio); the opening or restated
      // clef at a system start stays full size.
      var isCueClef = false;
      for (int j = index - 1; j >= 0; j--) {
        final prev = allElements[j];
        if (prev.system != positioned.system) break;
        if (prev.element is Note ||
            prev.element is Rest ||
            prev.element is Chord) {
          isCueClef = true;
          break;
        }
      }
      barElementRenderer.renderClef(
        canvas,
        element,
        basePosition,
        sizeFactor: isCueClef ? 0.72 : 1.0,
      );
    } else if (element is KeySignature && currentClef != null) {
      barElementRenderer.renderKeySignature(
        canvas,
        element,
        currentClef!,
        basePosition,
      );
    } else if (element is TimeSignature) {
      barElementRenderer.renderTimeSignature(canvas, element, basePosition);
    } else if (element is Note && currentClef != null) {
      _noteClefs[element] = currentClef!;
      _noteOctaveShifts[element] = extraOctaveShift;
      // Cross-staff notes are drawn (notehead + stem + beam) by the grand-staff
      // pass on the target staff, so skip them here.
      if (_skipNotes.contains(element)) return;
      // `NoteRenderer` suppresses stem + flag for a beamed note by testing
      // `note.beam == null`. The engine no longer writes its answer there
      // (M-26), so the suppression is decided HERE, off the resolved value, and
      // handed over as `renderOnlyNotehead`. `!renderOnlyNotehead &&
      // note.beam == null` and `!(onlyNotehead || beam != null)` are the same
      // predicate, so this moves no ink.
      final onlyNotehead =
          _notesInAdvancedBeams.contains(element) || _beamOf(element) != null;
      // The lyric line belongs to the SYSTEM, not to the note: it has to clear
      // the lowest notehead in the system and sit at one height across it.
      noteRenderer.lyricFirstLineY = LyricLayout.firstLineY(
        elements: allElements,
        system: positioned.system,
        staffBaselineY: coordinates.staffBaseline.dy,
        staffSpace: coordinates.staffSpace,
      );
      noteRenderer.render(
        canvas,
        element,
        basePosition,
        currentClef!,
        dynamicLengthOverride: element.dynamicElement == null
            ? null
            : _hairpinSpan(
                element.dynamicElement!,
                fromX: basePosition.dx,
                index: index,
                system: positioned.system,
                allElements: allElements,
              ),
        renderOnlyNotehead: onlyNotehead,
        voiceNumber: positioned.voiceNumber,
        accidentalDisplay:
            _accidentalDecisions[element] ?? AccidentalDisplay.show,
        extraOctaveShift: extraOctaveShift,
      );
    } else if (element is Rest) {
      restRenderer.render(
        canvas,
        element,
        basePosition,
        voiceNumber: positioned.voiceNumber,
      );
    } else if (element is Barline) {
      if (renderBarlines) {
        barlineRenderer.render(canvas, element, basePosition);
      }
    } else if (element is Chord && currentClef != null) {
      for (final note in element.notes) {
        _noteOctaveShifts[note] = extraOctaveShift;
      }
      chordRenderer.render(
        canvas,
        element,
        basePosition,
        currentClef!,
        voiceNumber: positioned.voiceNumber,
        accidentalDecisions: _accidentalDecisions,
        extraOctaveShift: extraOctaveShift,
      );
    } else if (element is Tuplet && currentClef != null) {
      _recordTupletOctaveShifts(element, extraOctaveShift);
      tupletRenderer.render(
        canvas,
        element,
        basePosition,
        currentClef!,
        extraOctaveShift: extraOctaveShift,
        // M-11: without these the tuplet drew every inner note with the
        // default `AccidentalDisplay.show`, so a triplet of three C#4 after a
        // C#4 in the same bar printed three sharps the resolver had decided to
        // hide — while the identical figure outside a tuplet was correct.
        accidentalDecisions: _accidentalDecisions,
        beamTypes: _tupletBeams,
        leftExtent: _elementLeftExtent,
        contextSmallestLeafSpaces: _tupletContextFloor?[element],
      );
    } else if (element is RepeatMark) {
      symbolAndTextRenderer.renderRepeatMark(canvas, element, basePosition);
    } else if (element is Dynamic) {
      symbolAndTextRenderer.renderDynamic(
        canvas,
        element,
        basePosition,
        lengthOverride: _hairpinSpan(
          element,
          fromX: basePosition.dx,
          index: index,
          system: positioned.system,
          allElements: allElements,
        ),
      );
    } else if (element is MusicText) {
      symbolAndTextRenderer.renderMusicText(canvas, element, basePosition);
    } else if (element is TempoMark) {
      symbolAndTextRenderer.renderTempoMark(
        canvas,
        element,
        basePosition,
        levelOffset:
            (_aboveStaffLevels[element] ?? 0) * _aboveStaffLevelHeight,
      );
    } else if (element is Breath) {
      breathRenderer.render(canvas, element, basePosition);
    } else if (element is Caesura) {
      symbolAndTextRenderer.renderCaesura(canvas, element, basePosition);
    } else if (element is OctaveMark) {
      final desiredEndX =
          basePosition.dx +
          (element.length > 0 ? element.length : coordinates.staffSpace * 3);
      final endAnchorX =
          _findNextBarlineAnchorX(
            allElements,
            index,
            positioned.system,
            desiredEndX,
            side: _BarlineAnchorSide.left,
            minimumX: basePosition.dx,
          ) ??
          desiredEndX;
      final markEndX = endAnchorX > basePosition.dx ? endAnchorX : desiredEndX;

      // Encontrar Y more extremo das notes no span for avoid overlap with ledger lines
      final isAboveOctave =
          element.type == OctaveType.va8 ||
          element.type == OctaveType.va15 ||
          element.type == OctaveType.va22;
      double? referenceNoteY;
      for (final pe in allElements) {
        if (pe.element is Note &&
            pe.position.dx >= basePosition.dx &&
            pe.position.dx <= markEndX) {
          if (isAboveOctave) {
            if (referenceNoteY == null || pe.position.dy < referenceNoteY) {
              referenceNoteY = pe.position.dy;
            }
          } else {
            if (referenceNoteY == null || pe.position.dy > referenceNoteY) {
              referenceNoteY = pe.position.dy;
            }
          }
        }
      }

      symbolAndTextRenderer.renderOctaveMark(
        canvas,
        element,
        basePosition,
        startX: basePosition.dx,
        endX: markEndX,
        referenceNoteY: referenceNoteY,
      );
    } else if (element is VoltaBracket) {
      final startAnchorX =
          _findPreviousBarlineAnchorX(
            allElements,
            index,
            positioned.system,
            side: _BarlineAnchorSide.right,
          ) ??
          basePosition.dx;
      final desiredRightX =
          startAnchorX +
          (element.length > 0 ? element.length : coordinates.staffSpace * 4);
      final endAnchorX =
          _findNextBarlineAnchorX(
            allElements,
            index,
            positioned.system,
            desiredRightX,
            side: _BarlineAnchorSide.left,
            minimumX: startAnchorX,
          ) ??
          desiredRightX;

      symbolAndTextRenderer.renderVoltaBracket(
        canvas,
        element,
        basePosition,
        startX: startAnchorX,
        endX: endAnchorX > startAnchorX ? endAnchorX : desiredRightX,
      );
    }
  }

  double? _findPreviousBarlineAnchorX(
    List<PositionedElement> elements,
    int fromIndex,
    int system, {
    required _BarlineAnchorSide side,
  }) {
    for (int i = fromIndex - 1; i >= 0; i--) {
      final positioned = elements[i];
      if (positioned.system != system) continue;
      if (positioned.element is Barline) {
        return _barlineAnchorX(positioned, side: side);
      }
    }
    return null;
  }

  double? _findNextBarlineAnchorX(
    List<PositionedElement> elements,
    int fromIndex,
    int system,
    double desiredRightX, {
    required _BarlineAnchorSide side,
    double? minimumX,
  }) {
    final candidates = <double>[];
    for (int i = fromIndex + 1; i < elements.length; i++) {
      final positioned = elements[i];
      if (positioned.system != system) continue;
      if (positioned.element is Barline) {
        final anchorX = _barlineAnchorX(positioned, side: side);
        if (minimumX != null && anchorX <= minimumX + 0.01) continue;
        candidates.add(anchorX);
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    var best = candidates.first;
    var bestDistance = (best - desiredRightX).abs();
    for (int i = 1; i < candidates.length; i++) {
      final candidate = candidates[i];
      final distance = (candidate - desiredRightX).abs();
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best;
  }

  double _barlineAnchorX(
    PositionedElement positioned, {
    required _BarlineAnchorSide side,
  }) {
    final element = positioned.element;
    if (element is! Barline) return positioned.position.dx;

    final x = positioned.position.dx;
    final barline = element;
    final thin =
        metadata.getEngravingDefault('thinBarlineThickness', 0.16) *
        coordinates.staffSpace;
    final thick =
        metadata.getEngravingDefault('thickBarlineThickness', 0.5) *
        coordinates.staffSpace;
    final glyphWidth = _barlineGlyphWidth(barline.type, thin, thick);

    double leftCenter;
    double rightCenter;

    switch (barline.type) {
      case BarlineType.double:
      case BarlineType.lightLight:
        leftCenter = x + (thin * 0.5);
        rightCenter = x + glyphWidth - (thin * 0.5);
        break;
      case BarlineType.final_:
      case BarlineType.lightHeavy:
        leftCenter = x + (thin * 0.5);
        rightCenter = x + glyphWidth - (thick * 0.5);
        break;
      case BarlineType.heavyLight:
        leftCenter = x + (thick * 0.5);
        rightCenter = x + glyphWidth - (thin * 0.5);
        break;
      case BarlineType.heavyHeavy:
        leftCenter = x + (thick * 0.5);
        rightCenter = x + glyphWidth - (thick * 0.5);
        break;
      case BarlineType.repeatForward:
        leftCenter = x + (thin * 0.5);
        rightCenter = leftCenter + (thin * 1.8);
        break;
      case BarlineType.repeatBackward:
        rightCenter = x + glyphWidth - (thin * 0.5);
        leftCenter = rightCenter - (thin * 1.8);
        break;
      case BarlineType.repeatBoth:
        leftCenter = x + (thin * 0.5);
        rightCenter = x + glyphWidth - (thin * 0.5);
        break;
      case BarlineType.single:
      case BarlineType.dashed:
      case BarlineType.heavy:
      case BarlineType.tick:
      case BarlineType.short_:
      case BarlineType.none:
        leftCenter = x + (glyphWidth * 0.5);
        rightCenter = leftCenter;
        break;
    }

    return side == _BarlineAnchorSide.left ? leftCenter : rightCenter;
  }

  double _barlineGlyphWidth(BarlineType type, double thin, double thick) {
    final glyphName = _barlineGlyphName(type);
    if (glyphName != null) {
      final width = metadata.getGlyphWidth(glyphName) * coordinates.staffSpace;
      if (width > 0) return width;
    }

    switch (type) {
      case BarlineType.double:
      case BarlineType.lightLight:
        return (thin * 2) + (coordinates.staffSpace * 0.3);
      case BarlineType.final_:
      case BarlineType.lightHeavy:
      case BarlineType.heavyLight:
        return thin + thick + (coordinates.staffSpace * 0.3);
      case BarlineType.heavyHeavy:
        return (thick * 2) + (coordinates.staffSpace * 0.3);
      case BarlineType.repeatForward:
      case BarlineType.repeatBackward:
      case BarlineType.repeatBoth:
        return coordinates.staffSpace * 1.5;
      default:
        return thin;
    }
  }

  String? _barlineGlyphName(BarlineType type) {
    switch (type) {
      case BarlineType.single:
        return 'barlineSingle';
      case BarlineType.double:
      case BarlineType.lightLight:
        return 'barlineDouble';
      case BarlineType.final_:
      case BarlineType.lightHeavy:
        return 'barlineFinal';
      case BarlineType.repeatForward:
        return 'repeatLeft';
      case BarlineType.repeatBackward:
        return 'repeatRight';
      case BarlineType.repeatBoth:
        return 'repeatLeftRight';
      case BarlineType.dashed:
        return 'barlineDashed';
      case BarlineType.heavy:
        return 'barlineHeavy';
      case BarlineType.heavyHeavy:
        return 'barlineHeavyHeavy';
      case BarlineType.heavyLight:
        // Reverse-final (heavy then light) — used at section starts.
        return 'barlineReverseFinal';
      case BarlineType.tick:
        return 'barlineTick';
      case BarlineType.short_:
        return 'barlineShort';
      case BarlineType.none:
        return null;
    }
  }
}

enum _BarlineAnchorSide { left, right }
