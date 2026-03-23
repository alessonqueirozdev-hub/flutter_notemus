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
    int? voiceNumber,
  }) {
    final staffPosition = StaffPositionCalculator.calculate(note.pitch, currentClef);

    // O offset horizontal da voz já está embutido em basePosition (aplicado pelo layout engine).
    // Não aplicar offset novamente aqui.
    final noteY = StaffPositionCalculator.toPixelY(
      staffPosition,
      coordinates.staffSpace,
      coordinates.staffBaseline.dy,
    );

    final noteheadGlyph = note.duration.type.glyphName;

    ledgerLineRenderer.render(canvas, basePosition.dx, staffPosition, noteheadGlyph);

    final notePos = Offset(basePosition.dx, noteY);

    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;

    final centerX = bbox != null
        ? ((bbox.bBoxSwX + bbox.bBoxNeX) / 2) * coordinates.staffSpace
        : (1.18 / 2) * coordinates.staffSpace;

    final centerY = bbox != null
        ? (bbox.centerY * coordinates.staffSpace)
        : 0.0;

    final noteCenter = Offset(basePosition.dx + centerX, noteY + centerY);

    accidentalRenderer.render(canvas, note, notePos, staffPosition.toDouble());

    drawGlyphWithBBox(
      canvas,
      glyphName: noteheadGlyph,
      position: notePos,
      color: theme.noteheadColor,
      options: GlyphDrawOptions.noteheadDefault,
    );

    if (!renderOnlyNotehead && note.duration.type != DurationType.whole && note.beam == null) {
      // Direção da haste: forçada por voz em contexto polifônico, senão por posição
      final stemUp = _getStemDirectionByVoice(note, staffPosition, voiceNumber);
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
      _renderDynamic(canvas, note.dynamicElement!, basePosition, staffPosition);
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

  /// Determina a direção da haste pela voz (polifonia) ou pela posição na pauta.
  ///
  /// Em contexto polifônico (voiceNumber != null):
  ///   - Voz ímpar (1, 3, ...): haste sempre para cima
  ///   - Voz par (2, 4, ...): haste sempre para baixo
  ///
  /// Sem voz: regra tradicional — haste para cima se a nota está na linha do
  /// meio ou abaixo (staffPosition <= 0).
  bool _getStemDirectionByVoice(Note note, int staffPosition, int? voiceNumber) {
    // Voz explícita via parâmetro (propagada pelo layout engine)
    if (voiceNumber != null) {
      return voiceNumber.isOdd; // ímpar = up, par = down
    }

    // Voz definida diretamente na nota
    if (note.voice != null) {
      return note.voice!.isOdd;
    }

    // Regra posicional (voz única)
    return staffPosition <= 0;
  }
}
