// lib/src/rendering/renderers/note_renderer.dart
// VERSÃO REFATORADA: Usa StaffPositionCalculator e BaseGlyphRenderer
//
// MELHORIAS IMPLEMENTADAS:
// ✅ Usa StaffPositionCalculator unificado para cálculo de posições
// ✅ Usa BaseGlyphRenderer.drawGlyphWithBBox para renderização consistente
// ✅ Elimina código duplicado de _calculateStaffPosition
// ✅ Elimina uso de centerVertically/centerHorizontally inconsistente
// ✅ Cache de TextPainters para melhor performance

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../smufl_positioning_engine.dart';
import '../staff_coordinate_system.dart';
import '../staff_position_calculator.dart';
import 'articulation_renderer.dart';
import 'base_glyph_renderer.dart';
import 'ornament_renderer.dart';
import 'primitives/accidental_renderer.dart';
import 'primitives/dot_renderer.dart';
import 'primitives/flag_renderer.dart';
import 'primitives/ledger_line_renderer.dart';
import 'primitives/stem_renderer.dart';
import 'symbol_and_text_renderer.dart';

class NoteRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final ArticulationRenderer articulationRenderer;
  final OrnamentRenderer ornamentRenderer;
  final SMuFLPositioningEngine positioningEngine;
  
  // 🆕 COMPONENTES ESPECIALIZADOS (SRP)
  late final DotRenderer dotRenderer;
  late final LedgerLineRenderer ledgerLineRenderer;
  late final StemRenderer stemRenderer;
  late final FlagRenderer flagRenderer;
  late final AccidentalRenderer accidentalRenderer;
  late final SymbolAndTextRenderer symbolAndTextRenderer;

  NoteRenderer({
    required StaffCoordinateSystem coordinates,
    required SmuflMetadata metadata,
    required this.theme,
    required double glyphSize,
    required double staffLineThickness,
    required double stemThickness,
    required this.articulationRenderer,
    required this.ornamentRenderer,
    required this.positioningEngine,
  }) : super(
          coordinates: coordinates,
          metadata: metadata,
          glyphSize: glyphSize,
        ) {
    // 🆕 Inicializar componentes especializados
    dotRenderer = DotRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
    );
    
    ledgerLineRenderer = LedgerLineRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      staffLineThickness: staffLineThickness,
    );
    
    stemRenderer = StemRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      stemThickness: stemThickness,
      positioningEngine: positioningEngine,
    );
    
    flagRenderer = FlagRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      positioningEngine: positioningEngine,
    );
    
    accidentalRenderer = AccidentalRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      positioningEngine: positioningEngine,
    );
    
    symbolAndTextRenderer = SymbolAndTextRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
    );
  }

  void render(
    Canvas canvas,
    Note note,
    Offset basePosition,
    Clef currentClef, {
    bool renderOnlyNotehead = false,
  }) {
    // MELHORIA: Usar StaffPositionCalculator unificado
    final staffPosition = StaffPositionCalculator.calculate(note.pitch, currentClef);

    // POLYPHONIC: Apply voice-based horizontal offset
    final voiceOffset = _getVoiceHorizontalOffset(note);
    final adjustedBasePosition = Offset(
      basePosition.dx + voiceOffset,
      basePosition.dy,
    );

    // Converter posição da pauta para coordenada Y em pixels
    final noteY = StaffPositionCalculator.toPixelY(
      staffPosition,
      coordinates.staffSpace,
      coordinates.staffBaseline.dy,
    );

    // Preparar glyph da cabeça de nota
    final noteheadGlyph = note.duration.type.glyphName;

    // 🆕 Delegar para LedgerLineRenderer
    ledgerLineRenderer.render(canvas, adjustedBasePosition.dx, staffPosition, noteheadGlyph);

    // Preparar posição da cabeça de nota
    // A correção de baseline SMuFL é aplicada automaticamente em drawGlyphWithBBox
    final notePos = Offset(adjustedBasePosition.dx, noteY);

    // CORREÇÃO CRÍTICA: Calcular o CENTRO REAL da cabeça de nota (horizontal E vertical)
    // Como noteheads usam centerHorizontally: false e centerVertically: false,
    // notePos é a posição da borda ESQUERDA e BASELINE do TextPainter
    // Mas articulações, ornamentos, e PONTOS esperam o CENTRO real da nota
    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;
    
    final centerX = bbox != null
        ? ((bbox.bBoxSwX + bbox.bBoxNeX) / 2) * coordinates.staffSpace
        : (1.18 / 2) * coordinates.staffSpace; // Fallback para noteheadBlack
    
    // CORREÇÃO CRÍTICA: noteY é a baseline do TextPainter, não o centro vertical!
    // Precisamos adicionar o centerY do bounding box SMuFL
    final centerY = bbox != null
        ? (bbox.centerY * coordinates.staffSpace)
        : 0.0; // Se não tiver bbox, assumir que noteY já está correto

    final noteCenter = Offset(adjustedBasePosition.dx + centerX, noteY + centerY);

    // 🆕 Delegar para AccidentalRenderer
    accidentalRenderer.render(canvas, note, notePos, staffPosition.toDouble());

    // MELHORIA: Desenhar cabeça de nota usando BaseGlyphRenderer
    // Usa drawGlyphWithBBox que automaticamente aplica bounding box SMuFL
    drawGlyphWithBBox(
      canvas,
      glyphName: noteheadGlyph,
      position: notePos,
      color: theme.noteheadColor,
      options: GlyphDrawOptions.noteheadDefault,
    );

    // 🆕 Delegar para StemRenderer e FlagRenderer
    // APENAS se não for renderOnlyNotehead E não tiver beam
    if (!renderOnlyNotehead && note.duration.type != DurationType.whole && note.beam == null) {
      // POLYPHONIC: Determine stem direction based on voice (if specified) or default position
      final stemUp = _getStemDirection(note, staffPosition);
      final beamCount = _getBeamCount(note.duration.type);

      final stemEnd = stemRenderer.render(
        canvas,
        notePos,
        noteheadGlyph,
        staffPosition,
        stemUp,
        beamCount,
      );

      // Desenhar bandeirola se necessário
      if (note.duration.type.value < 0.25) {
        flagRenderer.render(canvas, stemEnd, note.duration.type, stemUp);
      }

      // Tremolo strokes
      if (note.tremoloStrokes > 0 && note.tremoloStrokes <= 5) {
        final tremoloGlyph = 'tremolo${note.tremoloStrokes}';
        final tremoloY = stemUp
            ? stemEnd.dy - coordinates.staffSpace * 0.8
            : stemEnd.dy + coordinates.staffSpace * 0.8;
        drawGlyphWithBBox(
          canvas,
          glyphName: tremoloGlyph,
          position: Offset(notePos.dx, tremoloY),
          color: theme.noteheadColor,
          options: const GlyphDrawOptions(
            centerHorizontally: true,
            centerVertically: true,
          ),
        );
      }
    }

    // Renderizar articulações usando o CENTRO da cabeça de nota
    articulationRenderer.render(
      canvas,
      note.articulations,
      noteCenter,
      staffPosition,
    );

    // Renderizar ornamentos usando o CENTRO da cabeça de nota
    ornamentRenderer.renderForNote(
      canvas,
      note,
      noteCenter,
      staffPosition,
    );

    // Renderizar dinâmicas se presente
    if (note.dynamicElement != null) {
      _renderDynamic(canvas, note.dynamicElement!, adjustedBasePosition, staffPosition);
    }

    // 🆕 Delegar para DotRenderer
    if (note.duration.dots > 0) {
      dotRenderer.render(canvas, note, noteCenter, staffPosition);
    }
  }

  // 🆕 Método auxiliar: calcular número de barras
  int _getBeamCount(DurationType duration) {
    return switch (duration) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      _ => 0,
    };
  }

  /// Renderizar dinâmica associada à nota
  void _renderDynamic(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition,
    int staffPosition,
  ) {
    symbolAndTextRenderer.renderDynamic(canvas, dynamic, basePosition);
  }

  /// Get horizontal offset based on note's voice
  ///
  /// Voice 1: no offset (0.0)
  /// Voice 2: 0.6 staff spaces right
  /// Voice 3+: incremental offset
  double _getVoiceHorizontalOffset(Note note) {
    if (note.voice == null) return 0.0;

    // Create Voice instance to get proper offset calculation
    final voice = Voice(number: note.voice!);
    return voice.getHorizontalOffset(coordinates.staffSpace);
  }

  /// Determine stem direction based on voice or staff position
  ///
  /// If note has voice specified, use voice-based direction:
  /// - Voice 1: stems up
  /// - Voice 2: stems down
  /// - Voice 3+: stems up
  ///
  /// If no voice, use traditional rule: stems up if below middle line
  bool _getStemDirection(Note note, int staffPosition) {
    if (note.voice == null) {
      // Traditional rule: stems up if note is below or on middle line (staff position 0)
      return staffPosition <= 0;
    }

    // Voice-based stem direction
    final voice = Voice(number: note.voice!);
    final direction = voice.getStemDirection();

    return switch (direction) {
      StemDirection.up => true,
      StemDirection.down => false,
      StemDirection.auto => staffPosition <= 0, // Fall back to position-based
    };
  }
}
