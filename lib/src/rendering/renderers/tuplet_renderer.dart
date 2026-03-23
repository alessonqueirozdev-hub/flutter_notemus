// lib/src/rendering/renderers/tuplet_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../smufl_positioning_engine.dart';
import '../staff_coordinate_system.dart';
import 'note_renderer.dart';
import 'rest_renderer.dart';

/// Renderizador especializado para grupos de tercina e outras quiálteras
class TupletRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final NoteRenderer noteRenderer;
  final RestRenderer restRenderer;
  final SMuFLPositioningEngine positioningEngine;

  TupletRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    required this.noteRenderer,
    required this.restRenderer,
    required this.positioningEngine,
  });

  void render(
    Canvas canvas,
    Tuplet tuplet,
    Offset basePosition,
    Clef currentClef,
  ) {
    double currentX = basePosition.dx;
    final spacing = coordinates.staffSpace * 2.5;

    // allPositions: todos os elementos (notas + pausas) para o alcance do bracket
    final List<Offset> allPositions = [];
    // noteOnlyPositions: apenas notas, para calcular stemUp/extremeY corretamente
    final List<Offset> noteOnlyPositions = [];
    final List<Note> notes = [];
    final clefString = _getClefString(currentClef);

    // Aplicar beams automáticos se apropriado
    final processedElements = _applyAutomaticBeams(tuplet.elements);

    // Renderizar elementos individuais do tuplet
    for (final element in processedElements) {
      if (element is Note) {
        final noteY = coordinates.getNoteY(
          element.pitch.step,
          element.pitch.octave,
          clef: clefString,
        );

        noteRenderer.render(
          canvas,
          element,
          Offset(currentX, noteY),
          currentClef,
        );
        final pos = Offset(currentX, noteY);
        allPositions.add(pos);
        noteOnlyPositions.add(pos);
        notes.add(element);
        currentX += spacing;
      } else if (element is Rest) {
        restRenderer.render(canvas, element, Offset(currentX, basePosition.dy));
        allPositions.add(Offset(currentX, basePosition.dy));
        currentX += spacing;
      }
    }

    // Desenhar beams se as notas foram beamadas
    if (noteOnlyPositions.length >= 2 &&
        processedElements.whereType<Note>().isNotEmpty &&
        processedElements.whereType<Note>().first.beam != null) {
      _drawSimpleBeams(canvas, noteOnlyPositions, notes);
    }

    // Usar noteOnlyPositions para bracket e número (evita distorção das pausas)
    final bracketPositions =
        noteOnlyPositions.isNotEmpty ? noteOnlyPositions : allPositions;

    if (tuplet.showBracket && bracketPositions.length >= 2) {
      _drawTupletBracket(canvas, bracketPositions, tuplet.actualNotes);
    }

    if (tuplet.showNumber && bracketPositions.isNotEmpty) {
      _drawTupletNumber(canvas, bracketPositions, tuplet.actualNotes);
    }
  }

  /// Determina se as hastes vão para cima baseado nas posições das NOTAS.
  bool _stemUp(List<Offset> notePositions) {
    final staffCenterY = coordinates.staffBaseline.dy;
    final averageY =
        notePositions.map((p) => p.dy).reduce((a, b) => a + b) /
        notePositions.length;
    return averageY >= staffCenterY;
  }

  /// Calcula a posição Y do colchete do tuplet, com clamping dentro dos limites do pentagrama.
  double _calculateBracketY(List<Offset> notePositions) {
    final stemUp = _stemUp(notePositions);

    double extremeY;
    if (stemUp) {
      // Nota mais alta (menor Y) determina onde a haste termina
      extremeY =
          notePositions.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    } else {
      // Nota mais baixa (maior Y) determina onde a haste termina
      extremeY =
          notePositions.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    }

    final stemLength = coordinates.staffSpace * 3.5;
    final clearance = coordinates.staffSpace * 0.75;
    final bracketOffset = stemLength + clearance;

    double bracketY = stemUp
        ? extremeY - bracketOffset
        : extremeY + bracketOffset;

    // Clamp: evitar colchetes muito distantes do pentagrama
    if (stemUp) {
      final minY = coordinates.getStaffLineY(5) - coordinates.staffSpace * 2.0;
      if (bracketY < minY) bracketY = minY;
    } else {
      final maxY = coordinates.getStaffLineY(1) + coordinates.staffSpace * 1.0;
      if (bracketY > maxY) bracketY = maxY;
    }

    return bracketY;
  }

  void _drawTupletBracket(
    Canvas canvas,
    List<Offset> notePositions,
    int number,
  ) {
    if (notePositions.length < 2) return;

    final firstNotePos = notePositions.first;
    final lastNotePos = notePositions.last;

    // Adicionar largura da última nota para cobrir até o fim
    final noteHeadWidth = coordinates.staffSpace * 1.2;
    final actualLastX = lastNotePos.dx + noteHeadWidth;

    final stemUp = _stemUp(notePositions);
    final bracketY = _calculateBracketY(notePositions);

    final paint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = coordinates.staffSpace * 0.12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Bracket proporcional — deixar espaço para o número no centro (30% livre)
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

    // Behind Bars: hooks apontam na direção das notas
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
  ) {
    if (notePositions.isEmpty) return;

    final firstNotePos = notePositions.first;
    final lastNotePos = notePositions.last;
    final noteHeadWidth = coordinates.staffSpace * 1.2;
    final actualLastX = lastNotePos.dx + noteHeadWidth;

    final stemUp = _stemUp(notePositions); // consistente com bracket
    final bracketY = _calculateBracketY(notePositions);
    final centerX = (firstNotePos.dx + actualLastX) / 2;

    // Número acima do colchete para hastes para cima, abaixo para hastes para baixo
    final numberOffset = stemUp
        ? -coordinates.staffSpace * 0.7
        : coordinates.staffSpace * 0.7;
    final numberY = bracketY + numberOffset;

    final glyphName = 'tuplet$number';
    final numberSize = coordinates.staffSpace * 2.2;

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

  /// Converte Clef para string compatível com getNoteY
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
        return 'treble';
    }
  }

  /// Desenha beams para as notas beamadas do tuplet
  void _drawSimpleBeams(
    Canvas canvas,
    List<Offset> notePositions,
    List<Note> notes,
  ) {
    if (notePositions.length < 2 || notes.length < 2) return;

    final stemHeight = coordinates.staffSpace * 3.5;
    final beamThickness = coordinates.staffSpace * 0.5; // SMuFL spec: 0.5 SS
    final beamGap = coordinates.staffSpace * 0.25;      // SMuFL spec: 0.25 SS
    // Espaçamento center-to-center entre beams = espessura + gap
    final beamSpacing = beamThickness + beamGap;

    final stemUp = _stemUp(notePositions);

    final paint = Paint()
      ..color = theme.stemColor
      ..style = PaintingStyle.fill;

    // Calcular stemX de cada nota usando âncoras SMuFL (igual ao StemRenderer)
    final stemXs = List.generate(notePositions.length, (i) {
      final noteheadGlyph = notes[i].duration.type.glyphName;
      return _getStemX(notePositions[i].dx, noteheadGlyph, stemUp);
    });

    // Endpoints do beam
    final stemOffset = stemUp ? -stemHeight : stemHeight;
    final firstStemTop = notePositions.first.dy + stemOffset;
    final lastStemTop = notePositions.last.dy + stemOffset;

    final firstStemX = stemXs.first;
    final lastStemX = stemXs.last;
    final beamSlope = (lastStemX - firstStemX) != 0
        ? (lastStemTop - firstStemTop) / (lastStemX - firstStemX)
        : 0.0;

    double getBeamY(double x) {
      return firstStemTop + (beamSlope * (x - firstStemX));
    }

    // Número de beams baseado na duração
    int beamCount = 1;
    if (notes.first.duration.type == DurationType.sixteenth) {
      beamCount = 2;
    } else if (notes.first.duration.type == DurationType.thirtySecond) {
      beamCount = 3;
    } else if (notes.first.duration.type == DurationType.sixtyFourth) {
      beamCount = 4;
    }

    // Desenhar beams — cada beam deslocado por (beamThickness + beamGap) na direção certa
    for (int level = 0; level < beamCount; level++) {
      // Para stemUp: beams adicionais crescem para baixo (em direção às notas)
      // Para stemDown: beams adicionais crescem para cima (em direção às notas)
      final yOffset = stemUp ? (level * beamSpacing) : -(level * beamSpacing);
      final startX = firstStemX;
      final endX = lastStemX;
      final startY = getBeamY(startX) + yOffset;
      final endY = getBeamY(endX) + yOffset;

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
      final noteheadGlyph = notes[i].duration.type.glyphName;
      final stemX = _getStemX(notePositions[i].dx, noteheadGlyph, stemUp);
      final noteY = notePositions[i].dy;
      final beamY = getBeamY(stemX);

      canvas.drawLine(Offset(stemX, noteY), Offset(stemX, beamY), stemPaint);
    }
  }

  /// Calcula o X da haste usando âncoras SMuFL (igual ao StemRenderer).
  double _getStemX(double noteX, String noteheadGlyph, bool stemUp) {
    const stemUpXOffset = 0.7;
    const stemDownXOffset = -0.8;
    final xOffset = stemUp ? stemUpXOffset : stemDownXOffset;
    final stemAnchor = stemUp
        ? positioningEngine.getStemUpAnchor(noteheadGlyph)
        : positioningEngine.getStemDownAnchor(noteheadGlyph);
    return noteX + (stemAnchor.dx * coordinates.staffSpace - xOffset);
  }

  /// Aplica beams automáticos às notas do tuplet se todas forem beamable e sem pausas
  List<MusicalElement> _applyAutomaticBeams(List<MusicalElement> elements) {
    final notes = elements.whereType<Note>().toList();
    // Só aplica beams se não há pausas e há pelo menos 2 notas
    if (notes.length != elements.length || notes.length < 2) {
      return elements;
    }

    final beamable = notes.every((note) {
      return note.duration.type == DurationType.eighth ||
          note.duration.type == DurationType.sixteenth ||
          note.duration.type == DurationType.thirtySecond ||
          note.duration.type == DurationType.sixtyFourth;
    });

    if (!beamable) return elements;

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
