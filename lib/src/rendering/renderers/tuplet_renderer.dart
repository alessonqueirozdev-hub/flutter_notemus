// lib/src/rendering/renderers/tuplet_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';
import 'note_renderer.dart';
import 'rest_renderer.dart';

/// Renderizador especializado para grupos de tercina e outras quiáltera
class TupletRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final NoteRenderer noteRenderer;
  final RestRenderer restRenderer;

  TupletRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    required this.noteRenderer,
    required this.restRenderer,
  });

  void render(
    Canvas canvas,
    Tuplet tuplet,
    Offset basePosition,
    Clef currentClef,
  ) {
    double currentX = basePosition.dx;
    final spacing = coordinates.staffSpace * 2.5;
    final List<Offset> notePositions = [];
    final List<Note> notes = []; // Guardar referências às notas
    final clefString = _getClefString(currentClef);

    // Aplicar beams automáticos se apropriado
    final processedElements = _applyAutomaticBeams(tuplet.elements);

    // Renderizar elementos individuais do tuplet
    for (final element in processedElements) {
      if (element is Note) {
        // CRÍTICO: Calcular Y correto baseado no pitch da nota
        final noteY = coordinates.getNoteY(
          element.pitch.step,
          element.pitch.octave,
          clef: clefString,
        );

        // NOTA: NoteRenderer vai desenhar as hastes, mas serão cobertas pelos beams customizados
        noteRenderer.render(
          canvas,
          element,
          Offset(currentX, noteY),
          currentClef,
        );
        notePositions.add(Offset(currentX, noteY)); // Usar Y calculado!
        notes.add(element);
        currentX += spacing;
      } else if (element is Rest) {
        restRenderer.render(canvas, element, Offset(currentX, basePosition.dy));
        notePositions.add(Offset(currentX, basePosition.dy));
        currentX += spacing;
      }
    }

    // Desenhar beams se as notas foram beamadas
    if (processedElements.whereType<Note>().isNotEmpty &&
        processedElements.whereType<Note>().first.beam != null) {
      _drawSimpleBeams(
        canvas,
        notePositions,
        processedElements.whereType<Note>().toList(),
      );
    }

    // Desenhar colchete se necessário
    if (tuplet.showBracket && notePositions.length >= 2) {
      _drawTupletBracket(
        canvas,
        notePositions,
        tuplet.actualNotes,
        notes,
        currentClef,
      );
    }

    // Desenhar número
    if (tuplet.showNumber && notePositions.isNotEmpty) {
      _drawTupletNumber(
        canvas,
        notePositions,
        tuplet.actualNotes,
        notes,
        currentClef,
      );
    }
  }

  void _drawTupletBracket(
    Canvas canvas,
    List<Offset> notePositions,
    int number,
    List<Note> notes,
    Clef currentClef,
  ) {
    if (notePositions.length < 2) return;

    final firstNotePos = notePositions.first;
    final lastNotePos = notePositions.last;

    // CRÍTICO: Adicionar largura da nota para cobrir até o fim
    final noteHeadWidth = coordinates.staffSpace * 1.2;
    final actualLastX = lastNotePos.dx + noteHeadWidth;

    // ✅ CORREÇÃO P9: Determinar direção da haste (Behind Bars standard)
    final staffCenterY = coordinates.staffBaseline.dy;
    final averageY = notePositions.map((p) => p.dy).reduce((a, b) => a + b) / notePositions.length;
    final stemUp = averageY > staffCenterY; // Se média está abaixo do centro, haste vai para cima

    // ✅ CORREÇÃO P9: Encontrar nota extrema baseada na direção da haste
    double extremeY;
    if (stemUp) {
      // Stems up: bracket ABOVE (find highest note = lowest Y)
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    } else {
      // Stems down: bracket BELOW (find lowest note = highest Y)
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    }

    // ✅ CORREÇÃO P9: Calcular offset dinamicamente baseado em direção
    // Stem length típico: 3.5 SS (SMuFL spec)
    // Adicionar margem de 1.0 SS para clearance
    // Total: ~4.5 SS de offset
    final stemLength = coordinates.staffSpace * 3.5;
    final clearance = coordinates.staffSpace * 1.0;
    final bracketOffset = stemLength + clearance;

    // Bracket adapts to stem direction
    final bracketY = stemUp
        ? extremeY - bracketOffset  // Above for stems up
        : extremeY + bracketOffset; // Below for stems down

    // Espessura do bracket
    final paint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = coordinates.staffSpace * 0.12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Bracket proporcional - deixar espaço para o número no centro (30% livre)
    final totalWidth = actualLastX - firstNotePos.dx;
    final leftEnd = firstNotePos.dx + (totalWidth * 0.35);
    final rightStart = actualLastX - (totalWidth * 0.35);
    final hookLength = coordinates.staffSpace * 0.5;

    // Linha horizontal esquerda
    canvas.drawLine(
      Offset(firstNotePos.dx, bracketY),
      Offset(leftEnd, bracketY),
      paint,
    );

    // Linha horizontal direita
    canvas.drawLine(
      Offset(rightStart, bracketY),
      Offset(actualLastX, bracketY),
      paint,
    );

    // ✅ CORREÇÃO P9: Hooks adaptam à direção da haste (Behind Bars standard)
    // Stems up: hooks point DOWN (toward notes)
    // Stems down: hooks point UP (toward notes)
    final hookDirection = stemUp ? hookLength : -hookLength;

    canvas.drawLine(
      Offset(firstNotePos.dx, bracketY),
      Offset(firstNotePos.dx, bracketY + hookDirection),
      paint,
    );
    canvas.drawLine(
      Offset(actualLastX, bracketY),
      Offset(actualLastX, bracketY + hookDirection),
      paint,
    );
  }

  void _drawTupletNumber(
    Canvas canvas,
    List<Offset> notePositions,
    int number,
    List<Note> notes,
    Clef currentClef,
  ) {
    if (notePositions.isEmpty) return;

    final firstNotePos = notePositions.first;
    final lastNotePos = notePositions.last;
    final noteHeadWidth = coordinates.staffSpace * 1.2;
    final actualLastX = lastNotePos.dx + noteHeadWidth;

    // ✅ CORREÇÃO P9: Determinar direção da haste (Behind Bars standard)
    final staffCenterY = coordinates.staffBaseline.dy;
    final averageY = notePositions.map((p) => p.dy).reduce((a, b) => a + b) / notePositions.length;
    final stemUp = averageY > staffCenterY;

    // ✅ CORREÇÃO P9: Encontrar nota extrema baseada na direção da haste
    double extremeY;
    if (stemUp) {
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    } else {
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    }

    // ✅ CORREÇÃO P9: Usar MESMO offset dinâmico do bracket
    final stemLength = coordinates.staffSpace * 3.5;
    final clearance = coordinates.staffSpace * 1.0;
    final bracketOffset = stemLength + clearance;

    // Bracket adapts to stem direction
    final bracketY = stemUp
        ? extremeY - bracketOffset
        : extremeY + bracketOffset;

    final centerX = (firstNotePos.dx + actualLastX) / 2;

    // ✅ CORREÇÃO P9: Número adapta à direção (Behind Bars standard)
    // Stems up: number ABOVE bracket (negative offset)
    // Stems down: number BELOW bracket (positive offset)
    final numberOffset = stemUp
        ? -coordinates.staffSpace * 0.8  // Above
        : coordinates.staffSpace * 0.8;  // Below
    final numberY = bracketY + numberOffset;

    final glyphName = 'tuplet$number';
    final numberSize = coordinates.staffSpace * 1.0;

    _drawGlyph(
      canvas,
      glyphName: glyphName,
      position: Offset(centerX, numberY),
      size: numberSize,
      color: theme.stemColor,
      centerVertically: true,
      centerHorizontally: true,
    );
  }

  void _drawGlyph(
    Canvas canvas, {
    required String glyphName,
    required Offset position,
    required double size,
    required Color color,
    bool centerVertically = false,
    bool centerHorizontally = false,
  }) {
    final character = metadata.getCodepoint(glyphName);
    if (character.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: size,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final yOffset = centerVertically ? -textPainter.height * 0.5 : 0;
    final xOffset = centerHorizontally ? -textPainter.width * 0.5 : 0;

    textPainter.paint(
      canvas,
      Offset(position.dx + xOffset, position.dy + yOffset),
    );
  }

  /// Converte um objeto Clef para string compatível com getNoteY
  String _getClefString(Clef clef) {
    switch (clef.actualClefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return 'treble';
      case ClefType.bass:
      case ClefType.bassThirdLine:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return 'bass';
      case ClefType.alto:
        return 'alto';
      case ClefType.tenor:
        return 'tenor';
      default:
        return 'treble'; // Fallback
    }
  }

  /// Desenha beams simples para as notas do tuplet
  void _drawSimpleBeams(
    Canvas canvas,
    List<Offset> notePositions,
    List<Note> notes,
  ) {
    if (notePositions.length < 2 || notes.length < 2) return;

    // ✅ CORREÇÃO P8: Usar altura padrão SMuFL (3.5 SS, não 2.5 SS)
    final stemHeight = coordinates.staffSpace * 3.5;
    final beamThickness =
        coordinates.staffSpace * 0.5; // SMuFL spec: 0.5 SS

    // ✅ CORREÇÃO P8: Calcular centro baseado em baseline do sistema
    // O baseline está em staffSpace * 5.0 (vindo do layout)
    final staffCenterY = coordinates.staffBaseline.dy;
    final averageY =
        notePositions.map((p) => p.dy).reduce((a, b) => a + b) /
        notePositions.length;
    final stemUp =
        averageY >
        staffCenterY; // Se média está abaixo do centro, haste vai para cima

    final paint = Paint()
      ..color = theme.stemColor
      ..style = PaintingStyle.fill;

    // Calcular endpoints das hastes baseado na direção
    final stemOffset = stemUp ? -stemHeight : stemHeight;
    final firstStemTop = notePositions.first.dy + stemOffset;
    final lastStemTop = notePositions.last.dy + stemOffset;

    // Calcular slope do beam (ligeira inclinação se houver diferença de altura)
    final beamSlope =
        (lastStemTop - firstStemTop) /
        (notePositions.last.dx - notePositions.first.dx);

    double getBeamY(double x) {
      return firstStemTop + (beamSlope * (x - notePositions.first.dx));
    }

    // Determinar o número de beams baseado na duração
    int beamCount = 1;
    if (notes.first.duration.type == DurationType.sixteenth) {
      beamCount = 2;
    } else if (notes.first.duration.type == DurationType.thirtySecond) {
      beamCount = 3;
    } else if (notes.first.duration.type == DurationType.sixtyFourth) {
      beamCount = 4;
    }

    // Desenhar cada nível de beam
    final beamSpacing = coordinates.staffSpace * 0.25;
    for (int level = 0; level < beamCount; level++) {
      // Beams adicionais devem ir na direção oposta às notas
      final yOffset = stemUp ? (level * beamSpacing) : -(level * beamSpacing);
      final startX = notePositions.first.dx;
      final endX = notePositions.last.dx;
      final baseStartY = getBeamY(startX);
      final baseEndY = getBeamY(endX);
      final startY = baseStartY + yOffset;
      final endY = baseEndY + yOffset;

      // Desenhar beam como retângulo preenchido
      // Espessura na direção oposta às notas (se stem up, beam cresce para baixo)
      final thicknessDirection = stemUp ? beamThickness : -beamThickness;
      final path = Path();
      path.moveTo(startX, startY);
      path.lineTo(endX, endY);
      path.lineTo(endX, endY + thicknessDirection);
      path.lineTo(startX, startY + thicknessDirection);
      path.close();

      canvas.drawPath(path, paint);
    }

    // Desenhar hastes
    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = coordinates.staffSpace * 0.12;

    for (int i = 0; i < notePositions.length; i++) {
      final stemX = notePositions[i].dx;
      final noteY = notePositions[i].dy;
      final beamY = getBeamY(stemX);

      canvas.drawLine(Offset(stemX, noteY), Offset(stemX, beamY), stemPaint);
    }
  }

  /// Aplica beams automáticos às notas do tuplet se forem beamable
  List<MusicalElement> _applyAutomaticBeams(List<MusicalElement> elements) {
    // Verificar se há apenas notas (não rests)
    final notes = elements.whereType<Note>().toList();
    if (notes.length != elements.length || notes.length < 2) {
      return elements; // Retorna original se houver rests ou menos de 2 notas
    }

    // Verificar se todas as notas são beamable (colcheias ou menores)
    final beamable = notes.every((note) {
      return note.duration.type == DurationType.eighth ||
          note.duration.type == DurationType.sixteenth ||
          note.duration.type == DurationType.thirtySecond ||
          note.duration.type == DurationType.sixtyFourth;
    });

    if (!beamable) {
      return elements; // Retorna original se não forem beamable
    }

    // Aplicar beams
    final beamedNotes = <Note>[];
    for (int i = 0; i < notes.length; i++) {
      BeamType? beamType;
      if (i == 0) {
        beamType = BeamType.start;
      } else if (i == notes.length - 1) {
        beamType = BeamType.end;
      } else {
        beamType = BeamType.inner;
      }

      beamedNotes.add(
        Note(
          pitch: notes[i].pitch,
          duration: notes[i].duration,
          beam: beamType,
          articulations: notes[i].articulations,
          tie: notes[i].tie,
          slur: notes[i].slur,
          ornaments: notes[i].ornaments,
          dynamicElement: notes[i].dynamicElement,
          techniques: notes[i].techniques,
          voice: notes[i].voice,
        ),
      );
    }

    return beamedNotes.cast<MusicalElement>();
  }
}
