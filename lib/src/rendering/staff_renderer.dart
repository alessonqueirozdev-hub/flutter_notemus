// lib/src/rendering/staff_renderer.dart
// Professional music engraving — corrected implementation
// Refactoring pass: Using tipos of the core/

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/core.dart'; // 🆕 Tipos do core
import '../layout/layout_engine.dart';
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
    // CORREÃ‡ÃƒO TIPOGRÃIs: Size correct of the glifo based on SMuFL
    glyphSize = coordinates.staffSpace * 4.0;

    // Fix: Use valores corretos of the metadata Bravura
    staffLineThickness =
        metadata.getEngravingDefault('staffLineThickness') *
        coordinates.staffSpace;
    stemThickness =
        metadata.getEngravingDefault('stemThickness') * coordinates.staffSpace;

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

  void renderStaff(
    Canvas canvas,
    List<PositionedElement> elements,
    Size size, {
    LayoutEngine? layoutEngine,
    bool renderBarlines = true,
  }) {
    // Limpar set de notes beamed
    _notesInAdvancedBeams.clear();
    _noteClefs.clear();

    // Coletar notes that are in advanced beam groups
    if (layoutEngine != null) {
      for (final group in layoutEngine.advancedBeamGroups) {
        _notesInAdvancedBeams.addAll(group.notes);
      }
    }

    // Desenhar staff lines By System
    _drawStaffLinesBySystem(canvas, elements);
    currentClef = Clef(clefType: ClefType.treble); // Default clef

    // Primeira passagem: Rendersr elementos individuais
    for (int i = 0; i < elements.length; i++) {
      _renderElement(
        canvas,
        elements[i],
        elements,
        i,
        renderBarlines: renderBarlines,
      );
    }

    // Segunda passagem: Rendersr ADVANCED BEAMS (if disponível)
    if (layoutEngine != null && layoutEngine.advancedBeamGroups.isNotEmpty) {
      final noteXPositions = layoutEngine.noteXPositions;
      final noteYPositions = layoutEngine.noteYPositions;

      for (final advancedGroup in layoutEngine.advancedBeamGroups) {
        beamRenderer.renderAdvancedBeamGroup(
          canvas,
          advancedGroup,
          noteXPositions: noteXPositions,
          noteYPositions: noteYPositions,
        );
      }
    }

    // Terceira passagem: Rendersr elementos de grupo (beams simples, ties, slurs)
    if (currentClef != null) {
      _renderLineOrnaments(canvas, elements);

      // Pular beams simples if temos advanced beams
      if (layoutEngine == null || layoutEngine.advancedBeamGroups.isEmpty) {
        groupRenderer.renderBeams(canvas, elements, currentClef!);
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

      // Rebuild slurRenderer with the new skyline calculateTestor
      slurRenderer = SlurRenderer(
        staffSpace: coordinates.staffSpace,
        staffBaselineY: coordinates.staffBaseline.dy,
        metadata: metadata,
        skylineCalculator: skylineCalc,
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
          text: TextSpan(text: 'gliss.', style: labelStyle),
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
        metadata.getEngravingDefault('thinBarlineThickness') *
        coordinates.staffSpace;
    final thickBarlineThickness =
        metadata.getEngravingDefault('thickBarlineThickness') *
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

  void _renderElement(
    Canvas canvas,
    PositionedElement positioned,
    List<PositionedElement> allElements,
    int index, {
    required bool renderBarlines,
  }) {
    final element = positioned.element;
    final basePosition = positioned.position;

    if (element is Clef) {
      currentClef = element;
      barElementRenderer.renderClef(canvas, element, basePosition);
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
      final onlyNotehead = _notesInAdvancedBeams.contains(element);
      noteRenderer.render(
        canvas,
        element,
        basePosition,
        currentClef!,
        renderOnlyNotehead: onlyNotehead,
        voiceNumber: positioned.voiceNumber,
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
      chordRenderer.render(
        canvas,
        element,
        basePosition,
        currentClef!,
        voiceNumber: positioned.voiceNumber,
      );
    } else if (element is Tuplet && currentClef != null) {
      tupletRenderer.render(canvas, element, basePosition, currentClef!);
    } else if (element is RepeatMark) {
      symbolAndTextRenderer.renderRepeatMark(canvas, element, basePosition);
    } else if (element is Dynamic) {
      symbolAndTextRenderer.renderDynamic(canvas, element, basePosition);
    } else if (element is MusicText) {
      symbolAndTextRenderer.renderMusicText(canvas, element, basePosition);
    } else if (element is TempoMark) {
      symbolAndTextRenderer.renderTempoMark(canvas, element, basePosition);
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
        metadata.getEngravingDefault('thinBarlineThickness') *
        coordinates.staffSpace;
    final thick =
        metadata.getEngravingDefault('thickBarlineThickness') *
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
      case BarlineType.heavyHeavy:
      case BarlineType.heavyLight:
        return 'barlineHeavy';
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
