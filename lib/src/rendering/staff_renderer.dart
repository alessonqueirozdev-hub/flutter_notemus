// lib/src/rendering/staff_renderer.dart
// VERSÃƒO CORRIGIDA COM TIPOGRAFIA PROFISSIONAL
// FASE 2 REFATORAÃ‡ÃƒO: Usando tipos do core/

import 'package:flutter/material.dart';
import '../../core/core.dart'; // ðŸ†• Tipos do core
import '../layout/layout_engine.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';
import '../beaming/beaming.dart'; // Sistema de beaming avanÃ§ado
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
import 'renderers/slur_renderer.dart'; // âœ… NOVO: Ligaduras profissionais
import 'renderers/symbol_and_text_renderer.dart';
import '../layout/skyline_calculator.dart';
import 'renderers/tuplet_renderer.dart';
import 'smufl_positioning_engine.dart';
import 'staff_coordinate_system.dart';

class StaffRenderer {
  // CONSTANTES DE AJUSTE MANUAL

  // Margem apÃ³s BARRAS DE COMPASSO NORMAIS (single, double, dashed, etc)
  // Controla onde as linhas do pentagrama terminam quando o sistema termina
  // com uma barra de compasso normal (nÃ£o uma barra final)
  //
  // FÃ³rmula: endX = bounds.endX + (staffSpace + systemEndMargin)
  //
  // Aplica-se a:
  //   - BarlineType.single (barra simples)
  //   - BarlineType.double (barra dupla)
  //   - BarlineType.dashed (barra tracejada)
  //   - Todos os tipos EXCETO BarlineType.final_
  //
  // Valores sugeridos:
  //   -12.0 = Linhas terminam exatamente na barra de compasso
  //    0.0 = Margem padrÃ£o de 1 staff space
  //   -3.0 = Linhas terminam um pouco antes da barra
  static const double systemEndMargin =
      -12.0; //  Termina exatamente na barra de compasso

  // Margem apÃ³s BARRA FINAL (BarlineType.final_)
  // Controla onde as linhas do pentagrama terminam quando o sistema termina
  // com uma barra final (linha fina + linha grossa)
  //
  // Aplica-se APENAS a:
  //   - BarlineType.final_ (barra final) âœ…
  //
  // Valores sugeridos:
  //   -1.5 = Linhas terminam exatamente na barra final âœ…
  //    0.0 = Margem padrÃ£o de 1 staff space
  static const double finalBarlineMargin =
      -1.5; // âœ… Termina exatamente na barra final

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
  late SlurRenderer slurRenderer; // âœ… NOVO: Renderizador profissional

  StaffRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
  }) {
    // CORREÃ‡ÃƒO TIPOGRÃFICA: Tamanho correto do glifo baseado em SMuFL
    glyphSize = coordinates.staffSpace * 4.0;

    // CORREÃ‡ÃƒO: Usar valores corretos do metadata Bravura
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

    // âœ… Inicializar SlurRenderer profissional
    slurRenderer = SlurRenderer(
      staffSpace: coordinates.staffSpace,
      metadata: metadata,
    );
  }

  // Set de notas que estÃ£o em advanced beam groups
  final Set<Note> _notesInAdvancedBeams = {};

  void renderStaff(
    Canvas canvas,
    List<PositionedElement> elements,
    Size size, {
    LayoutEngine? layoutEngine,
  }) {
    // Limpar set de notas beamed
    _notesInAdvancedBeams.clear();

    // Coletar notas que estÃ£o em advanced beam groups
    if (layoutEngine != null) {
      for (final group in layoutEngine.advancedBeamGroups) {
        _notesInAdvancedBeams.addAll(group.notes);
      }
    }

    // Desenhar linhas do pentagrama POR SISTEMA
    _drawStaffLinesBySystem(canvas, elements);
    currentClef = Clef(clefType: ClefType.treble); // Default clef

    // Primeira passagem: renderizar elementos individuais
    for (int i = 0; i < elements.length; i++) {
      _renderElement(canvas, elements[i], elements, i);
    }

    // Segunda passagem: renderizar ADVANCED BEAMS (se disponÃ­vel)
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

    // Terceira passagem: renderizar elementos de grupo (beams simples, ties, slurs)
    if (currentClef != null) {
      _renderLineOrnaments(canvas, elements);

      // Pular beams simples se temos advanced beams
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

      // Rebuild slurRenderer with the new skyline calculator
      slurRenderer = SlurRenderer(
        staffSpace: coordinates.staffSpace,
        metadata: metadata,
        skylineCalculator: skylineCalc,
      );

      // âœ… USAR SLURRENDERER PROFISSIONAL ao invÃ©s do GroupRenderer
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
    final paint = Paint()
      ..color = theme.ornamentColor ?? theme.noteheadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = coordinates.staffSpace * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < elements.length; i++) {
      final current = elements[i];
      if (current.element is! Note) continue;

      final note = current.element as Note;
      final hasLineOrnament = note.ornaments.any((ornament) {
        return ornament.type == OrnamentType.glissando ||
            ornament.type == OrnamentType.portamento ||
            ornament.type == OrnamentType.slide;
      });
      if (!hasLineOrnament) continue;

      final next = _findNextNote(elements, i, current.system);
      if (next == null) continue;

      final startX = current.position.dx + (coordinates.staffSpace * 0.85);
      final endX = next.position.dx + (coordinates.staffSpace * 0.25);
      if (endX <= startX) continue;

      final startY = current.position.dy - (coordinates.staffSpace * 0.2);
      final endY = next.position.dy - (coordinates.staffSpace * 0.2);
      final path = Path()..moveTo(startX, startY);

      final segments = (((endX - startX) / coordinates.staffSpace).round() * 2)
          .clamp(4, 16);
      final amplitude = coordinates.staffSpace * 0.16;
      for (int s = 1; s <= segments; s++) {
        final t = s / segments;
        final x = startX + ((endX - startX) * t);
        final yLinear = startY + ((endY - startY) * t);
        final yWave = yLinear + ((s.isEven ? -1 : 1) * amplitude);
        path.lineTo(x, yWave);
      }

      canvas.drawPath(path, paint);
    }
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

  /// Desenha linhas do pentagrama POR SISTEMA
  /// Cada sistema tem suas linhas terminando na Ãºltima barline daquele sistema
  void _drawStaffLinesBySystem(
    Canvas canvas,
    List<PositionedElement> elements,
  ) {
    if (elements.isEmpty) return;

    // Agrupar elementos por sistema e calcular limites
    final systemBounds = <int, ({double startX, double endX, double y})>{};
    final lastBarlineType =
        <int, BarlineType>{}; // Tipo da Ãºltima barra de cada sistema

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

      // Guardar o tipo da Ãºltima barline de cada sistema
      if (positioned.element is Barline) {
        lastBarlineType[system] = (positioned.element as Barline).type;
      }
    }

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness
      ..style = PaintingStyle.stroke;

    // Desenhar linhas para cada sistema separadamente
    for (final entry in systemBounds.entries) {
      final systemNumber = entry.key;
      final bounds = entry.value;
      final barlineType = lastBarlineType[systemNumber];

      // Usar margem baseada no TIPO DE BARRA, nÃ£o na posiÃ§Ã£o do sistema
      // Barra final (BarlineType.final_) usa finalBarlineMargin
      // Outras barras usam systemEndMargin
      final isFinalBarline = (barlineType == BarlineType.final_);
      final margin = isFinalBarline ? finalBarlineMargin : systemEndMargin;
      final endX = bounds.endX + (coordinates.staffSpace + margin);

      // Desenhar as 5 linhas do pentagrama para este sistema
      // âœ… CORREÃ‡ÃƒO: Usar coordinates.getStaffLineY() diretamente, que jÃ¡ tem
      // a posiÃ§Ã£o Y correta para este sistema (baseada em staffBaseline.dy).
      // NÃƒO usar bounds.y pois pode ser a posiÃ§Ã£o Y de uma nota (pitch-based)
      // e nÃ£o o centro da pauta.
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
    int index,
  ) {
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
      barlineRenderer.render(canvas, element, basePosition);
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

      symbolAndTextRenderer.renderOctaveMark(
        canvas,
        element,
        basePosition,
        startX: basePosition.dx,
        endX: endAnchorX > basePosition.dx ? endAnchorX : desiredEndX,
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
