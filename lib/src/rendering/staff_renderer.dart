// lib/src/rendering/staff_renderer.dart
// VERSÃO CORRIGIDA COM TIPOGRAFIA PROFISSIONAL
// FASE 2 REFATORAÇÃO: Usando tipos do core/

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
import 'renderers/tuplet_renderer.dart';
import 'smufl_positioning_engine.dart';
import 'staff_coordinate_system.dart';

class StaffRenderer {
  // CONSTANTES DE AJUSTE MANUAL

  // Margem após BARRAS DE COMPASSO NORMAIS (single, double, dashed, etc)
  // Controla onde as linhas do pentagrama terminam quando o sistema termina
  // com uma barra de compasso normal (não uma barra final)
  //
  // Fórmula: endX = bounds.endX + (staffSpace + systemEndMargin)
  //
  // Aplica-se a:
  //   - BarlineType.single (barra simples) 
  //   - BarlineType.double (barra dupla)
  //   - BarlineType.dashed (barra tracejada)
  //   - Todos os tipos EXCETO BarlineType.final_
  //
  // Valores sugeridos:
  //   -12.0 = Linhas terminam exatamente na barra de compasso 
  //    0.0 = Margem padrão de 1 staff space
  //   -3.0 = Linhas terminam um pouco antes da barra
  static const double systemEndMargin =
      -12.0; //  Termina exatamente na barra de compasso

  // Margem após BARRA FINAL (BarlineType.final_)
  // Controla onde as linhas do pentagrama terminam quando o sistema termina
  // com uma barra final (linha fina + linha grossa)
  //
  // Aplica-se APENAS a:
  //   - BarlineType.final_ (barra final) ✅
  //
  // Valores sugeridos:
  //   -1.5 = Linhas terminam exatamente na barra final ✅
  //    0.0 = Margem padrão de 1 staff space
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
  late final SlurRenderer slurRenderer; // ✅ NOVO: Renderizador profissional

  StaffRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
  }) {
    // CORREÇÃO TIPOGRÁFICA: Tamanho correto do glifo baseado em SMuFL
    glyphSize = coordinates.staffSpace * 4.0;

    // CORREÇÃO: Usar valores corretos do metadata Bravura
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
      noteheadWidth: metadata.getGlyphWidth('noteheadBlack') * coordinates.staffSpace,
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
    );
    
    // ✅ Inicializar SlurRenderer profissional
    slurRenderer = SlurRenderer(
      staffSpace: coordinates.staffSpace,
      metadata: metadata,
    );
  }

  // Set de notas que estão em advanced beam groups
  final Set<Note> _notesInAdvancedBeams = {};

  void renderStaff(
    Canvas canvas, 
    List<PositionedElement> elements, 
    Size size,
    {LayoutEngine? layoutEngine}
  ) {
    // Limpar set de notas beamed
    _notesInAdvancedBeams.clear();
    
    // Coletar notas que estão em advanced beam groups
    if (layoutEngine != null) {
      for (final group in layoutEngine.advancedBeamGroups) {
        _notesInAdvancedBeams.addAll(group.notes);
      }
    }
    
    // Desenhar linhas do pentagrama POR SISTEMA
    _drawStaffLinesBySystem(canvas, elements);
    currentClef = Clef(clefType: ClefType.treble); // Default clef

    // Primeira passagem: renderizar elementos individuais
    for (final positioned in elements) {
      _renderElement(canvas, positioned);
    }

    // Segunda passagem: renderizar ADVANCED BEAMS (se disponível)
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
      // Pular beams simples se temos advanced beams
      if (layoutEngine == null || layoutEngine.advancedBeamGroups.isEmpty) {
        groupRenderer.renderBeams(canvas, elements, currentClef!);
      }
      
      // ✅ USAR SLURRENDERER PROFISSIONAL ao invés do GroupRenderer
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

  /// Desenha linhas do pentagrama POR SISTEMA
  /// Cada sistema tem suas linhas terminando na última barline daquele sistema
  void _drawStaffLinesBySystem(
    Canvas canvas,
    List<PositionedElement> elements,
  ) {
    if (elements.isEmpty) return;

    // Agrupar elementos por sistema e calcular limites
    final systemBounds = <int, ({double startX, double endX, double y})>{};
    final lastBarlineType =
        <int, BarlineType>{}; // Tipo da última barra de cada sistema

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

      // Guardar o tipo da última barline de cada sistema
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

      // Usar margem baseada no TIPO DE BARRA, não na posição do sistema
      // Barra final (BarlineType.final_) usa finalBarlineMargin
      // Outras barras usam systemEndMargin
      final isFinalBarline = (barlineType == BarlineType.final_);
      final margin = isFinalBarline ? finalBarlineMargin : systemEndMargin;
      final endX = bounds.endX + (coordinates.staffSpace + margin);

      // Desenhar as 5 linhas do pentagrama para este sistema
      for (int line = 1; line <= 5; line++) {
        // Calcular Y baseado no sistema (cada sistema tem seu próprio Y)
        final baseY = bounds.y;
        final lineY =
            baseY +
            (coordinates.getStaffLineY(line) - coordinates.getStaffLineY(3));

        canvas.drawLine(
          Offset(coordinates.staffBaseline.dx, lineY),
          Offset(endX, lineY), // Linhas param no fim do sistema!
          paint,
        );
      }
    }
  }

  void _renderElement(Canvas canvas, PositionedElement positioned) {
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
      // Renderizar noteheads sempre!
      // Se a nota está em advanced beam, renderizar apenas notehead (sem stem/flag)
      final onlyNotehead = _notesInAdvancedBeams.contains(element);
      noteRenderer.render(
        canvas, 
        element, 
        basePosition, 
        currentClef!,
        renderOnlyNotehead: onlyNotehead,
      );
    } else if (element is Rest) {
      restRenderer.render(canvas, element, basePosition);
    } else if (element is Barline) {
      barlineRenderer.render(canvas, element, basePosition);
    } else if (element is Chord && currentClef != null) {
      chordRenderer.render(canvas, element, basePosition, currentClef!);
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
      symbolAndTextRenderer.renderOctaveMark(canvas, element, basePosition);
    }
  }
}
