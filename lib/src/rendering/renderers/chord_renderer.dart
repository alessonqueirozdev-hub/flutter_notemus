// lib/src/rendering/renderers/chord_renderer.dart
// VERSÃƒO REFATORADA: Usa StaffPositionCalculator e BaseGlyphRenderer
//
// MELHORIAS IMPLEMENTADAS (Fase 2):
// âœ… Usa StaffPositionCalculator unificado (elimina 42 linhas duplicadas)
// âœ… Herda de BaseGlyphRenderer para renderizaÃ§Ã£o consistente
// âœ… Usa drawGlyphWithBBox para 100% conformidade SMuFL
// âœ… Cache automÃ¡tico de TextPainters para melhor performance

import 'package:flutter/material.dart';

import '../../../core/core.dart'; // ðŸ†• Tipos do core
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
    Clef currentClef, {
    int? voiceNumber,
  }) {
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
    final stemUp = _getStemDirection(chord, positions, voiceNumber);

    final Map<int, double> xOffsets = {
      for (int i = 0; i < sortedNotes.length; i++) i: 0.0,
    };

    // CORREÃ‡ÃƒO TIPOGRÃFICA: colisÃµes de 2Âª/cluster exigem cabeÃ§as alternadas.
    // Regra prÃ¡tica adotada:
    // - haste para cima: nota SUPERIOR desloca para a direita;
    // - haste para baixo: nota INFERIOR desloca para a esquerda.
    final noteheadInfo = metadata.getGlyphInfo('noteheadBlack');
    final noteWidth = noteheadInfo?.boundingBox?.width ?? 1.18;
    final clusterOffset = noteWidth * coordinates.staffSpace;

    for (int i = 0; i < sortedNotes.length - 1; i++) {
      final interval = (positions[i] - positions[i + 1]).abs();
      if (interval > 1) continue;

      if (stemUp) {
        // Nota superior (dissonÃ¢ncia do cluster) vai para o lado direito.
        xOffsets[i] = clusterOffset;
      } else {
        // Nota inferior vai para o lado esquerdo.
        xOffsets[i + 1] = -clusterOffset;
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
      _drawLedgerLines(canvas, basePosition.dx + xOffset, staffPos);

      if (note.pitch.accidentalGlyph != null) {
        // CORREÃ‡ÃƒO: Passar informaÃ§Ãµes adicionais para escalonamento de acidentes
        _renderAccidental(
          canvas,
          note,
          Offset(basePosition.dx + xOffset, noteY),
          i,
          sortedNotes,
          positions,
        );
      }

      // MELHORIA: Usar drawGlyphWithBBox herdado de BaseGlyphRenderer
      drawGlyphWithBBox(
        canvas,
        glyphName: note.duration.type.glyphName,
        position: Offset(basePosition.dx + xOffset, noteY),
        color: theme.noteheadColor,
        options: GlyphDrawOptions.noteheadDefault,
      );
    }

    if (chord.duration.type != DurationType.whole) {
      // CORREÃ‡ÃƒO CRÃTICA: sortedNotes estÃ¡ em ordem DECRESCENTE de staffPosition
      // - sortedNotes.first = nota mais ALTA (maior staffPosition)
      // - sortedNotes.last = nota mais BAIXA (menor staffPosition)
      //
      // Haste para CIMA: deve comeÃ§ar na nota mais BAIXA
      // Haste para BAIXO: deve comeÃ§ar na nota mais ALTA
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

      // ðŸŽ¯ CORREÃ‡ÃƒO CRÃTICA: Usar calculateChordStemLength do positioning engine
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
        Offset(basePosition.dx + stemXOffset, extremeY),
        noteheadGlyph,
        stemUp,
        customStemLength,
      );
      
      // Desenhar bandeirola se necessÃ¡rio
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

  /// MÃ©todo auxiliar: calcular nÃºmero de barras
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
    final accidentalGlyph = note.pitch.accidentalGlyph!;

    // Largura real do acidente vinda do metadata (em staff spaces)
    final accidentalWidth = metadata.getGlyphWidth(accidentalGlyph);

    // Behind Bars: clearance de ~0.16 SS entre borda direita do acidente e borda esquerda da nota
    const clearance = 0.16;
    final baseOffset = (accidentalWidth + clearance) * coordinates.staffSpace;

    // Escalonamento horizontal para acidentes em notas adjacentes (intervalo de 2Âª)
    int stackLevel = 0;
    for (int i = 0; i < noteIndex; i++) {
      if (allNotes[i].pitch.accidentalGlyph != null) {
        if ((positions[noteIndex] - positions[i]).abs() <= 1) {
          stackLevel++;
        }
      }
    }

    // Borda ESQUERDA do acidente posicionada com clearance correto
    // (sem centerHorizontally: a posiÃ§Ã£o Ã© a borda esquerda do glifo)
    final accidentalX = notePos.dx - baseOffset - (stackLevel * coordinates.staffSpace * 0.6);

    drawGlyphWithBBox(
      canvas,
      glyphName: accidentalGlyph,
      position: Offset(accidentalX, notePos.dy),
      color: theme.accidentalColor ?? theme.noteheadColor,
      options: const GlyphDrawOptions(trackBounds: true),
    );
  }

  void _drawLedgerLines(Canvas canvas, double x, int staffPosition) {
    if (!theme.showLedgerLines) return;

    // MELHORIA: Usar StaffPositionCalculator
    if (!StaffPositionCalculator.needsLedgerLines(staffPosition)) return;

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness;

    // CORREÃ‡ÃƒO CRÃTICA: Calcular centro horizontal CORRETO da nota
    // x Ã© a posiÃ§Ã£o da borda ESQUERDA do glifo
    final noteheadInfo = metadata.getGlyphInfo('noteheadBlack');
    final bbox = noteheadInfo?.boundingBox;
    
    // Centro relativo ao inÃ­cio do glyph (em staff spaces)
    final centerOffsetSS = bbox != null
        ? (bbox.bBoxSwX + bbox.bBoxNeX) / 2
        : 1.18 / 2;
    
    final centerOffsetPixels = centerOffsetSS * coordinates.staffSpace;
    final noteCenterX = x + centerOffsetPixels;
    
    final noteWidth =
        bbox?.widthInPixels(coordinates.staffSpace) ??
        (coordinates.staffSpace * 1.18);

    // CORREÃ‡ÃƒO SMuFL: Consistente com legerLineExtension (0.4) do metadata
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

      // CORREÃ‡ÃƒO: Centralizar na posiÃ§Ã£o REAL da nota
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
    // Obter Ã¢ncora SMuFL da cabeÃ§a de nota
    final stemAnchor = stemUp
        ? noteRenderer.positioningEngine.getStemUpAnchor(noteheadGlyph)
        : noteRenderer.positioningEngine.getStemDownAnchor(noteheadGlyph);

    // Converter Ã¢ncora de staff spaces para pixels
    final stemAnchorPixels = Offset(
      stemAnchor.dx * coordinates.staffSpace,
      -stemAnchor.dy * coordinates.staffSpace, // INVERTER Y!
    );

    // PosiÃ§Ã£o inicial da haste
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

    // Retornar posiÃ§Ã£o do final da haste (para bandeirola)
    return Offset(stemX, stemEndY);
  }

  /// Determine stem direction based on voiceNumber (from PositionedElement) or chord position.
  ///
  /// In polyphonic context (voiceNumber != null):
  ///   - Odd voice (1, 3, ...): stems up
  ///   - Even voice (2, 4, ...): stems down
  ///
  /// Without voice: traditional rule based on most extreme position.
  bool _getStemDirection(Chord chord, List<int> positions, int? voiceNumber) {
    if (voiceNumber != null) {
      return voiceNumber.isOdd;
    }

    if (chord.voice != null) {
      return chord.voice!.isOdd;
    }

    // Traditional rule: stems up if average position is on or below middle line
    final mostExtremePos = positions.reduce(
      (a, b) => a.abs() > b.abs() ? a : b,
    );
    return mostExtremePos > 0;
  }

}
