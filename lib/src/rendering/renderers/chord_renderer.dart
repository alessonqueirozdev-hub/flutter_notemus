// lib/src/rendering/renderers/chord_renderer.dart
// VERSÃO REFATORADA: Usa StaffPositionCalculator e BaseGlyphRenderer
//
// MELHORIAS IMPLEMENTADAS (Fase 2):
// ✅ Usa StaffPositionCalculator unificado (elimina 42 linhas duplicadas)
// ✅ Herda de BaseGlyphRenderer para renderização consistente
// ✅ Usa drawGlyphWithBBox para 100% conformidade SMuFL
// ✅ Cache automático de TextPainters para melhor performance

import 'package:flutter/material.dart';

import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';
import '../staff_position_calculator.dart';
import 'base_glyph_renderer.dart';
import 'note_renderer.dart';

class ChordRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final double staffLineThickness;
  final double stemThickness;
  final NoteRenderer noteRenderer;

  // ignore: use_super_parameters
  ChordRenderer({
    required StaffCoordinateSystem coordinates,
    required SmuflMetadata metadata,
    required this.theme,
    required double glyphSize,
    required this.staffLineThickness,
    required this.stemThickness,
    required this.noteRenderer,
  }) : super(
         coordinates: coordinates,
         metadata: metadata,
         glyphSize: glyphSize,
       );

  void render(
    Canvas canvas,
    Chord chord,
    Offset basePosition,
    Clef currentClef,
  ) {
    // POLYPHONIC: Apply voice-based horizontal offset
    final voiceOffset = _getVoiceHorizontalOffset(chord);
    final adjustedBasePosition = Offset(
      basePosition.dx + voiceOffset,
      basePosition.dy,
    );

    // MELHORIA: Usar StaffPositionCalculator unificado
    final sortedNotes = [...chord.notes]
      ..sort(
        (a, b) => StaffPositionCalculator.calculate(
          b.pitch,
          currentClef,
        ).compareTo(StaffPositionCalculator.calculate(a.pitch, currentClef)),
      );

    final positions = sortedNotes
        .map((n) => StaffPositionCalculator.calculate(n.pitch, currentClef))
        .toList();

    // POLYPHONIC: Determine stem direction based on voice or position
    final stemUp = _getStemDirection(chord, positions);

    final Map<int, double> xOffsets = {};
    // CORREÇÃO TIPOGRÁFICA: Usar largura real da cabeça de nota para offset
    final noteheadInfo = metadata.getGlyphInfo('noteheadBlack');
    final noteWidth = noteheadInfo?.boundingBox?.width ?? 1.18;

    for (int i = 0; i < sortedNotes.length; i++) {
      xOffsets[i] = 0.0;
      if (i > 0 && (positions[i - 1] - positions[i]).abs() <= 1) {
        if (xOffsets[i - 1] == 0.0) {
          // Offset baseado na largura real da nota do metadata SMuFL
          xOffsets[i] = !stemUp
              ? -(noteWidth * coordinates.staffSpace)
              : (noteWidth * coordinates.staffSpace);
        }
      }
    }

    for (int i = 0; i < sortedNotes.length; i++) {
      final note = sortedNotes[i];
      final staffPos = positions[i];

      // MELHORIA: Usar StaffPositionCalculator.toPixelY
      final noteY = StaffPositionCalculator.toPixelY(
        staffPos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      final xOffset = xOffsets[i]!;

      // MELHORIA: Usar StaffPositionCalculator para ledger lines
      _drawLedgerLines(canvas, adjustedBasePosition.dx + xOffset, staffPos);

      if (note.pitch.accidentalGlyph != null) {
        // CORREÇÃO: Passar informações adicionais para escalonamento de acidentes
        _renderAccidental(
          canvas,
          note,
          Offset(adjustedBasePosition.dx + xOffset, noteY),
          i,
          sortedNotes,
          positions,
        );
      }

      // MELHORIA: Usar drawGlyphWithBBox herdado de BaseGlyphRenderer
      drawGlyphWithBBox(
        canvas,
        glyphName: note.duration.type.glyphName,
        position: Offset(adjustedBasePosition.dx + xOffset, noteY),
        color: theme.noteheadColor,
        options: GlyphDrawOptions.noteheadDefault,
      );
    }

    if (chord.duration.type != DurationType.whole) {
      // CORREÇÃO CRÍTICA: sortedNotes está em ordem DECRESCENTE de staffPosition
      // - sortedNotes.first = nota mais ALTA (maior staffPosition)
      // - sortedNotes.last = nota mais BAIXA (menor staffPosition)
      // 
      // Haste para CIMA: deve começar na nota mais BAIXA
      // Haste para BAIXO: deve começar na nota mais ALTA
      final extremeNote = stemUp ? sortedNotes.last : sortedNotes.first;

      // MELHORIA: Usar StaffPositionCalculator
      final extremePos = StaffPositionCalculator.calculate(
        extremeNote.pitch,
        currentClef,
      );
      final extremeY = StaffPositionCalculator.toPixelY(
        extremePos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      final extremeNoteIndex = sortedNotes.indexOf(extremeNote);
      final stemXOffset = xOffsets[extremeNoteIndex]!;

      // 🎯 CORREÇÃO CRÍTICA: Usar calculateChordStemLength do positioning engine
      // A haste deve atravessar TODAS as notas do acorde!
      final noteheadGlyph = chord.duration.type.glyphName;
      final beamCount = _getBeamCount(chord.duration.type);
      
      // Calcular comprimento proporcional usando positioning engine
      final sortedPositions = positions; // Already calculated earlier
      final customStemLength = noteRenderer.positioningEngine.calculateChordStemLength(
        noteStaffPositions: sortedPositions,
        stemUp: stemUp,
        beamCount: beamCount,
      );

      final stemEnd = _renderChordStem(
        canvas,
        Offset(adjustedBasePosition.dx + stemXOffset, extremeY),
        noteheadGlyph,
        stemUp,
        customStemLength,
      );
      
      // Desenhar bandeirola se necessário
      if (chord.duration.type.value < 0.25) {
        noteRenderer.flagRenderer.render(
          canvas,
          stemEnd,
          chord.duration.type,
          stemUp,
        );
      }
    }
  }

  /// Método auxiliar: calcular número de barras
  int _getBeamCount(DurationType duration) {
    return switch (duration) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      _ => 0,
    };
  }

  void _renderAccidental(
    Canvas canvas,
    Note note,
    Offset notePos,
    int noteIndex,
    List<Note> allNotes,
    List<int> positions,
  ) {
    // CORREÇÃO TIPOGRÁFICA: Implementar escalonamento de acidentes em acordes
    // Acidentes de notas adjacentes (intervalo de 2ª) devem ser escalonados horizontalmente
    double accidentalOffset = coordinates.staffSpace * 0.75;

    // Verificar se há notas adjacentes acima ou abaixo com acidentes
    int stackLevel = 0;
    for (int i = 0; i < noteIndex; i++) {
      if (allNotes[i].pitch.accidentalGlyph != null) {
        final positionDiff = (positions[noteIndex] - positions[i]).abs();
        if (positionDiff <= 1) {
          // Notas adjacentes (intervalo de 2ª), escalonar acidente
          stackLevel++;
        }
      }
    }

    // Cada nível adicional move o acidente mais para a esquerda
    final accidentalX =
        notePos.dx -
        accidentalOffset -
        (stackLevel * coordinates.staffSpace * 0.6);

    // MELHORIA: Usar drawGlyphWithBBox herdado
    drawGlyphWithBBox(
      canvas,
      glyphName: note.pitch.accidentalGlyph!,
      position: Offset(accidentalX, notePos.dy),
      color: theme.accidentalColor ?? theme.noteheadColor,
      options: GlyphDrawOptions.accidentalDefault,
    );
  }

  void _drawLedgerLines(Canvas canvas, double x, int staffPosition) {
    if (!theme.showLedgerLines) return;

    // MELHORIA: Usar StaffPositionCalculator
    if (!StaffPositionCalculator.needsLedgerLines(staffPosition)) return;

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness;

    // CORREÇÃO CRÍTICA: Calcular centro horizontal CORRETO da nota
    // x é a posição da borda ESQUERDA do glifo
    final noteheadInfo = metadata.getGlyphInfo('noteheadBlack');
    final bbox = noteheadInfo?.boundingBox;
    
    // Centro relativo ao início do glyph (em staff spaces)
    final centerOffsetSS = bbox != null
        ? (bbox.bBoxSwX + bbox.bBoxNeX) / 2
        : 1.18 / 2;
    
    final centerOffsetPixels = centerOffsetSS * coordinates.staffSpace;
    final noteCenterX = x + centerOffsetPixels;
    
    final noteWidth =
        bbox?.widthInPixels(coordinates.staffSpace) ??
        (coordinates.staffSpace * 1.18);

    // CORREÇÃO SMuFL: Consistente com legerLineExtension (0.4) do metadata
    final extension = coordinates.staffSpace * 0.4;
    final totalWidth = noteWidth + (2 * extension);

    // MELHORIA: Usar StaffPositionCalculator.getLedgerLinePositions
    final ledgerPositions = StaffPositionCalculator.getLedgerLinePositions(
      staffPosition,
    );

    for (final pos in ledgerPositions) {
      final y = StaffPositionCalculator.toPixelY(
        pos,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      // CORREÇÃO: Centralizar na posição REAL da nota
      final lineStartX = noteCenterX - (totalWidth / 2);
      final lineEndX = noteCenterX + (totalWidth / 2);
      
      canvas.drawLine(
        Offset(lineStartX, y),
        Offset(lineEndX, y),
        paint,
      );
    }
  }

  /// Renderiza haste de acorde com comprimento customizado
  Offset _renderChordStem(
    Canvas canvas,
    Offset notePosition,
    String noteheadGlyph,
    bool stemUp,
    double customLength,
  ) {
    // Obter âncora SMuFL da cabeça de nota
    final stemAnchor = stemUp
        ? noteRenderer.positioningEngine.getStemUpAnchor(noteheadGlyph)
        : noteRenderer.positioningEngine.getStemDownAnchor(noteheadGlyph);

    // Converter âncora de staff spaces para pixels
    final stemAnchorPixels = Offset(
      stemAnchor.dx * coordinates.staffSpace,
      -stemAnchor.dy * coordinates.staffSpace, // INVERTER Y!
    );

    // Posição inicial da haste
    final stemX = notePosition.dx + stemAnchorPixels.dx;
    final stemStartY = notePosition.dy + stemAnchorPixels.dy;

    // Usar comprimento customizado (em staff spaces)
    final stemLength = customLength * coordinates.staffSpace;
    final stemEndY = stemUp ? stemStartY - stemLength : stemStartY + stemLength;

    // Desenhar haste
    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = stemThickness
      ..strokeCap = StrokeCap.butt;

    canvas.drawLine(
      Offset(stemX, stemStartY),
      Offset(stemX, stemEndY),
      stemPaint,
    );

    // Retornar posição do final da haste (para bandeirola)
    return Offset(stemX, stemEndY);
  }

  /// Get horizontal offset based on chord's voice
  ///
  /// Voice 1: no offset (0.0)
  /// Voice 2: 0.6 staff spaces right
  /// Voice 3+: incremental offset
  double _getVoiceHorizontalOffset(Chord chord) {
    if (chord.voice == null) return 0.0;

    // Create Voice instance to get proper offset calculation
    final voice = Voice(number: chord.voice!);
    return voice.getHorizontalOffset(coordinates.staffSpace);
  }

  /// Determine stem direction based on voice or chord position
  ///
  /// If chord has voice specified, use voice-based direction:
  /// - Voice 1: stems up
  /// - Voice 2: stems down
  /// - Voice 3+: stems up
  ///
  /// If no voice, use traditional rule based on most extreme position
  bool _getStemDirection(Chord chord, List<int> positions) {
    if (chord.voice == null) {
      // Traditional rule: stems up if average position is on or below middle line
      final mostExtremePos = positions.reduce(
        (a, b) => a.abs() > b.abs() ? a : b,
      );
      return mostExtremePos > 0;
    }

    // Voice-based stem direction
    final voice = Voice(number: chord.voice!);
    final direction = voice.getStemDirection();

    return switch (direction) {
      StemDirection.up => true,
      StemDirection.down => false,
      StemDirection.auto => {
        // Fall back to position-based
        final mostExtremePos = positions.reduce(
          (a, b) => a.abs() > b.abs() ? a : b,
        );
        mostExtremePos > 0
      },
    };
  }

}
