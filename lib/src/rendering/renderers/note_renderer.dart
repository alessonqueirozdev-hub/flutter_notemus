// lib/src/rendering/renderers/note_renderer.dart
// Refactored implementation: Usa StaffPositionCalculator e BaseGlyphRenderer
//
// MELHORIAS IMPLEMENTADAS:
// ✅ Uses StaffPositioncalculateTestor unificado for cálculo de positions
// ✅ Uses BaseGlyphRenderer.drawGlyphWithBBox for Rendersção consistente
// ✅ Elimina código duplicado de _calculateTesteStaffPosition
// ✅ Elimina uso de centerVertically/centerHorizontally inconsistente
// ✅ Cache de TextPainters for melhor performance

import 'package:flutter/material.dart';
import '../../../core/core.dart';
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
    // 🆕 Initialise componentes especializados
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
    final staffPosition = StaffPositionCalculator.calculate(
      note.pitch,
      currentClef,
    );

    // O offset horizontal of the voice já está embutido in basePosition (Appliesdo pelo layout engine).
    // Not Appliesr offset newmente aqui.
    final noteY = StaffPositionCalculator.toPixelY(
      staffPosition,
      coordinates.staffSpace,
      coordinates.staffBaseline.dy,
    );
    final stemUp = _getStemDirectionByVoice(note, staffPosition, voiceNumber);

    final noteheadGlyph = note.duration.type.glyphName;

    ledgerLineRenderer.render(
      canvas,
      basePosition.dx,
      staffPosition,
      noteheadGlyph,
    );

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

    if (!renderOnlyNotehead &&
        note.duration.type != DurationType.whole &&
        note.beam == null) {
      // Direção of the stem: forçada por voice in contexto polifônico, senão por position
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

    // Rendersr articulations using o CENTRO of the notehead
    articulationRenderer.render(
      canvas,
      note.articulations,
      noteCenter,
      stemUp: stemUp,
    );

    // Rendersr ornaments using o CENTRO of the notehead
    ornamentRenderer.renderForNote(
      canvas,
      note,
      noteCenter,
      staffPosition,
      voiceNumber: voiceNumber,
    );

    // Rendersr dynamics se presente
    if (note.dynamicElement != null) {
      _renderDynamic(canvas, note.dynamicElement!, basePosition, staffPosition);
    }

    // 🆕 Delegar for DotRenderer
    if (note.duration.dots > 0) {
      dotRenderer.render(canvas, note, noteCenter, staffPosition);
    }

    // Rendersr syllables/letras abaixo of the staff
    if (note.syllables != null && note.syllables!.isNotEmpty) {
      _renderSyllables(canvas, note.syllables!, noteCenter.dx);
    }
  }

  // 🆕 Method auxiliar: Calculatestesr number de barras
  int _getBeamCount(DurationType duration) {
    return switch (duration) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      _ => 0,
    };
  }

  /// Rendersr dynamic associada à note
  void _renderDynamic(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition,
    int staffPosition,
  ) {
    symbolAndTextRenderer.renderDynamic(canvas, dynamic, basePosition);
  }

  /// Renders as syllables de letra abaixo of the staff.
  ///
  /// Posicionamento: abaixo of the 1ª linha of the staff + 1.5 staff spaces de margem.
  /// Each verso ocupa a linha vertical separada (spacing = 1.2 * fontSize).
  ///
  /// Convenções tipográficas:
  /// - [SyllableType.initial] / [SyllableType.middle]: Adds "-" após o texto
  ///   (o hífen ideal seria centralizado entre as notes, mas requer 2ª passagem)
  /// - [SyllableType.hyphen]: desenha apenas "-"
  /// - Melisma: extensão de linha horizontal após o texto (conecta à próxima note)
  void _renderSyllables(Canvas canvas, List<Syllable> syllables, double noteX) {
    // Linha 1 (inferior) of the staff: baseline.dy + 2 * staffSpace
    final staffBottomY =
        coordinates.staffBaseline.dy + 2 * coordinates.staffSpace;
    final fontSize = coordinates.staffSpace * 0.85;
    final lineHeight = fontSize * 1.3;
    // Clearance entre linha inferior of the staff e primeira linha de letra
    final firstLineY = staffBottomY + coordinates.staffSpace * 1.5;

    for (int verseIndex = 0; verseIndex < syllables.length; verseIndex++) {
      final syllable = syllables[verseIndex];
      final lyricY = firstLineY + verseIndex * lineHeight;
      _renderSyllable(canvas, syllable, noteX, lyricY, fontSize);
    }
  }

  void _renderSyllable(
    Canvas canvas,
    Syllable syllable,
    double noteX,
    double y,
    double fontSize,
  ) {
    final color = theme.noteheadColor.withValues(alpha: 0.85);

    String displayText;
    switch (syllable.type) {
      case SyllableType.initial:
      case SyllableType.middle:
        displayText = '${syllable.text}-';
      case SyllableType.hyphen:
        displayText = '-';
      case SyllableType.single:
      case SyllableType.terminal:
        displayText = syllable.text;
    }

    final textStyle = TextStyle(
      fontSize: fontSize,
      color: color,
      fontStyle: syllable.italic ? FontStyle.italic : FontStyle.normal,
      height: 1.0,
    );

    final painter = TextPainter(
      text: TextSpan(text: displayText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // Centralizar o texto na X position of the note
    final textX = noteX - painter.width * 0.5;
    painter.paint(canvas, Offset(textX, y - painter.height * 0.5));

    // For syllables únicas/terminais, desenhar linha de melisma curta se a note
    // for melismática (texto igual à syllable = vocalização estendida).
    // A extensão completa requer position of the note seguinte (Rendersda pelo StaffRenderer).
    // Aqui apenas marcamos o início of the linha with um traço de 1 SS de comprimento.
    if (syllable.type == SyllableType.single ||
        syllable.type == SyllableType.terminal) {
      if (syllable.italic) {
        // Convenção: itálico sinaliza melisma — traço de extensão inicial
        final lineStartX = textX + painter.width + fontSize * 0.2;
        final lineEndX = lineStartX + coordinates.staffSpace;
        final paint = Paint()
          ..color = color
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(lineStartX, y), Offset(lineEndX, y), paint);
      }
    }
  }

  /// Determina a direção of the stem pela voice (polyphony) ou pela staff position.
  ///
  /// in contexto polifônico (voiceNumber != null):
  ///   - Voice ímpar (1, 3, ...): stem always for cima
  ///   - Voice par (2, 4, ...): stem always for baixo
  ///
  /// Sem voice: regra tradded — stem up se a note está na linha of the
  /// meio ou abaixo (staffPosition <= 0).
  bool _getStemDirectionByVoice(
    Note note,
    int staffPosition,
    int? voiceNumber,
  ) {
    // Voice explícita via parameter (propagada pelo layout engine)
    if (voiceNumber != null) {
      return voiceNumber.isOdd; // ímpar = up, par = down
    }

    // Voice definida diretamente na note
    if (note.voice != null) {
      return note.voice!.isOdd;
    }

    // Regra posicional (voice única)
    return staffPosition <= 0;
  }
}
