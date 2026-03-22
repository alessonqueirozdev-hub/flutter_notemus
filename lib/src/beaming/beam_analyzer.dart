// lib/src/beaming/beam_analyzer.dart

import 'package:flutter_notemus/core/note.dart';
import 'package:flutter_notemus/core/time_signature.dart';
import 'package:flutter_notemus/core/duration.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/beaming/beam_segment.dart';
import 'package:flutter_notemus/src/beaming/beam_types.dart';
import 'package:flutter_notemus/src/beaming/beat_position_calculator.dart'; // ✅ ADICIONADO
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

/// Analisa grupos de notas e determina geometria e estrutura de beams
class BeamAnalyzer {
  final double staffSpace;
  final double noteheadWidth;
  final SMuFLPositioningEngine positioningEngine;

  BeamAnalyzer({
    required this.staffSpace,
    required this.noteheadWidth,
    required this.positioningEngine,
  });

  /// Analisa um grupo de notas e retorna AdvancedBeamGroup configurado
  AdvancedBeamGroup analyzeAdvancedBeamGroup(
    List<Note> notes,
    TimeSignature timeSignature, {
    Map<Note, double>? noteXPositions,
    Map<Note, int>? noteStaffPositions,
    Map<Note, double>? noteYPositions, // ✅ NOVO: Y absoluto em pixels
  }) {
    if (notes.isEmpty) {
      throw ArgumentError('Beam group cannot be empty');
    }

    final group = AdvancedBeamGroup(notes: notes);

    // Etapa 1: Determinar direção das hastes
    group.stemDirection = _calculateStemDirection(notes, noteStaffPositions);

    // Etapa 2: Calcular posições X
    _calculateXPositions(group, noteXPositions);

    // Etapa 3: Calcular geometria do primary beam
    _calculatePrimaryBeamGeometry(group, noteStaffPositions, noteYPositions);

    // Etapa 4: Analisar beams secundários
    _analyzeSecondaryBeams(group, timeSignature, noteStaffPositions);

    return group;
  }

  /// Determina direção das hastes baseado na nota mais distante da linha central
  /// ✅ CORREÇÃO P3: Linha central é sempre staffPosition = 0, independente da clave
  StemDirection _calculateStemDirection(
    List<Note> notes,
    Map<Note, int>? noteStaffPositions,
  ) {
    if (noteStaffPositions == null || noteStaffPositions.isEmpty) {
      return StemDirection.up; // Padrão
    }

    // ✅ CORREÇÃO P3: Linha central é sempre staffPosition = 0
    // (independente da clave - treble, bass, alto, etc.)
    const int centerLine = 0;

    // Encontrar nota mais distante da linha central
    Note? farthest;
    int maxDistance = 0;

    for (final note in notes) {
      final pos = noteStaffPositions[note];
      if (pos != null) {
        final distance = (pos - centerLine).abs();
        if (distance > maxDistance) {
          maxDistance = distance;
          farthest = note;
        }
      }
    }

    if (farthest == null) {
      return StemDirection.up;
    }

    final farthestPos = noteStaffPositions[farthest]!;

    // ✅ staffPosition > 0: acima do centro → hastes para baixo
    // ✅ staffPosition < 0: abaixo do centro → hastes para cima
    // ✅ staffPosition = 0: exatamente no centro → hastes para baixo (convenção)
    return farthestPos >= centerLine ? StemDirection.down : StemDirection.up;
  }

  /// Calcula posições X do início e fim do beam
  /// ✅ USAR POSIÇÕES DAS HASTES (com âncoras SMuFL), não das notas!
  void _calculateXPositions(
    AdvancedBeamGroup group,
    Map<Note, double>? noteXPositions,
  ) {
    if (noteXPositions == null || noteXPositions.isEmpty) {
      // Espaçamento padrão
      group.leftX = 0;
      group.rightX = (group.notes.length - 1) * staffSpace * 2;
      return;
    }

    final firstNote = group.notes.first;
    final lastNote = group.notes.last;

    // ✅ CRÍTICO: Calcular posição X DA HASTE, não da nota!
    // Usar EXATAMENTE a mesma lógica do StemRenderer (linhas 59-72)
    final firstNoteX = noteXPositions[firstNote] ?? 0;
    final lastNoteX = noteXPositions[lastNote] ?? 0;
    
    // Obter âncoras SMuFL
    final firstNoteheadGlyph = firstNote.duration.type.glyphName;
    final lastNoteheadGlyph = lastNote.duration.type.glyphName;
    
    final firstStemAnchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(firstNoteheadGlyph)
        : positioningEngine.getStemDownAnchor(firstNoteheadGlyph);
    
    final lastStemAnchor = group.stemDirection == StemDirection.up
        ? positioningEngine.getStemUpAnchor(lastNoteheadGlyph)
        : positioningEngine.getStemDownAnchor(lastNoteheadGlyph);
    
    // ✅ CRÍTICO: Aplicar ajustes visuais empíricos (IGUAL ao StemRenderer!)
    const stemUpXOffset = 0.7;
    const stemDownXOffset = -0.8;
    final xOffset = group.stemDirection == StemDirection.up 
        ? stemUpXOffset 
        : stemDownXOffset;
    
    // Calcular posição X das hastes (IDÊNTICO ao StemRenderer linhas 66-72!)
    group.leftX = firstNoteX + (firstStemAnchor.dx * staffSpace - xOffset);
    group.rightX = lastNoteX + (lastStemAnchor.dx * staffSpace - xOffset);
  }

  /// Calcula geometria do primary beam (ângulo e posições Y)
  void _calculatePrimaryBeamGeometry(
    AdvancedBeamGroup group,
    Map<Note, int>? noteStaffPositions,
    Map<Note, double>? noteYPositions, // ✅ Y absoluto em pixels
  ) {
    final firstNote = group.notes.first;
    final lastNote = group.notes.last;

    // ✅ SEMPRE usar Y absoluto (noteYPositions deve sempre estar disponível)
    if (noteYPositions == null || noteYPositions.isEmpty) {
      throw ArgumentError('noteYPositions é obrigatório para cálculo de beams');
    }

    final firstNoteY = noteYPositions[firstNote];
    final lastNoteY = noteYPositions[lastNote];

    if (firstNoteY == null || lastNoteY == null) {
      throw ArgumentError('Posições Y das notas não encontradas');
    }

    // ✅ USAR EXATAMENTE A MESMA LÓGICA DO GroupRenderer!
    // Calcular máximo de beams no grupo
    int maxBeams = 0;
    for (final note in group.notes) {
      final beams = _getBeamCount(note.duration);
      if (beams > maxBeams) maxBeams = beams;
    }

    // Usar SMuFLPositioningEngine para calcular altura do beam (IGUAL ao GroupRenderer!)
    final beamHeightSpaces = positioningEngine.calculateBeamHeight(
      staffPosition: noteStaffPositions![firstNote]!,
      stemUp: group.stemDirection == StemDirection.up,
      allStaffPositions: noteStaffPositions.values.toList(),
      beamCount: maxBeams,
    );
    final beamHeightPixels = beamHeightSpaces * staffSpace;

    // Calcular posição média das notas (IGUAL ao GroupRenderer!)
    final avgNoteY = (firstNoteY + lastNoteY) / 2;

    // Calcular Y base do beam (IGUAL ao GroupRenderer!)
    final beamBaseY = group.stemDirection == StemDirection.up
        ? avgNoteY - beamHeightPixels
        : avgNoteY + beamHeightPixels;

    // Calcular ângulo usando positioning engine (IGUAL ao GroupRenderer!)
    final beamAngleSpaces = positioningEngine.calculateBeamAngle(
      noteStaffPositions: noteStaffPositions.values.toList(),
      stemUp: group.stemDirection == StemDirection.up,
    );
    final beamAnglePixels = beamAngleSpaces * staffSpace;

    // Calcular distância X
    final xDistance = group.rightX - group.leftX;
    final beamSlope = xDistance > 0 ? beamAnglePixels / xDistance : 0.0;

    // Definir leftY e rightY usando interpolação linear (IGUAL ao GroupRenderer!)
    group.leftY = beamBaseY;
    group.rightY = beamBaseY + (beamSlope * xDistance);
  }


  /// Analisa beams secundários e cria BeamSegments
  void _analyzeSecondaryBeams(
    AdvancedBeamGroup group,
    TimeSignature timeSignature,
    Map<Note, int>? noteStaffPositions,
  ) {
    // Primary beam: sempre completo
    group.beamSegments.add(BeamSegment(
      level: 1,
      startNoteIndex: 0,
      endNoteIndex: group.notes.length - 1,
      isFractional: false,
    ));

    // Determinar número máximo de beams necessários
    int maxLevel = 1;
    for (final note in group.notes) {
      final beamCount = _getBeamCount(note.duration);
      if (beamCount > maxLevel) {
        maxLevel = beamCount;
      }
    }

    // Analisar cada nível de beam secundário
    for (int level = 2; level <= maxLevel; level++) {
      _analyzeBeamLevel(group, level, timeSignature);
    }
  }

  /// Analisa um nível específico de beam
  void _analyzeBeamLevel(
    AdvancedBeamGroup group,
    int level,
    TimeSignature timeSignature,
  ) {
    int? segmentStart;

    for (int i = 0; i < group.notes.length; i++) {
      final note = group.notes[i];
      final noteBeams = _getBeamCount(note.duration);

      if (noteBeams >= level) {
        // Esta nota precisa deste nível de beam
        segmentStart ??= i;

        // Verificar se deve quebrar beam secundário
        final shouldBreak = _shouldBreakSecondaryBeam(
          group,
          i,
          level,
          timeSignature,
        );

        if (shouldBreak && segmentStart != i) {
          // Finalizar segmento anterior
          group.beamSegments.add(BeamSegment(
            level: level,
            startNoteIndex: segmentStart,
            endNoteIndex: i - 1,
            isFractional: false,
          ));
          segmentStart = i;
        }
      } else {
        // Esta nota não precisa deste nível
        if (segmentStart != null) {
          if (segmentStart == i - 1) {
            // Apenas uma nota: fractional beam
            group.beamSegments.add(_createFractionalBeam(
              group,
              segmentStart,
              i,
              level,
            ));
          } else {
            // Segmento normal
            group.beamSegments.add(BeamSegment(
              level: level,
              startNoteIndex: segmentStart,
              endNoteIndex: i - 1,
              isFractional: false,
            ));
          }
          segmentStart = null;
        }
      }
    }

    // Finalizar último segmento
    if (segmentStart != null) {
      if (segmentStart == group.notes.length - 1) {
        // Última nota sozinha: fractional beam à esquerda
        group.beamSegments.add(_createFractionalBeam(
          group,
          segmentStart,
          group.notes.length,
          level,
        ));
      } else {
        group.beamSegments.add(BeamSegment(
          level: level,
          startNoteIndex: segmentStart,
          endNoteIndex: group.notes.length - 1,
          isFractional: false,
        ));
      }
    }
  }

  /// Determina se deve quebrar beam secundário nesta posição
  ///
  /// ✅ IMPLEMENTADO: Lógica profissional baseada em beat positions (Behind Bars)
  bool _shouldBreakSecondaryBeam(
    AdvancedBeamGroup group,
    int noteIndex,
    int beamLevel,
    TimeSignature timeSignature,
  ) {
    if (noteIndex == 0) return false;

    // Implementar regra "dois níveis acima"
    int smallestBeams = 1;
    for (final note in group.notes) {
      final beams = _getBeamCount(note.duration);
      if (beams > smallestBeams) {
        smallestBeams = beams;
      }
    }

    final breakAtLevel = smallestBeams - 2;

    // Não quebrar beams de nível muito baixo
    if (beamLevel < breakAtLevel) {
      return false;
    }

    // ✅ NOVA LÓGICA: Usar BeatPositionCalculator para decisões profissionais
    final calculator = BeatPositionCalculator(timeSignature);
    
    // Calcular posição acumulada da nota atual
    double accumulatedPosition = 0.0;
    for (int i = 0; i < noteIndex; i++) {
      accumulatedPosition += group.notes[i].duration.realValue;
    }
    
    // Converter para NoteEvent e verificar se deve quebrar
    final noteEvent = NoteEvent(
      positionInBar: accumulatedPosition / calculator.barLengthInWholeNotes(),
      duration: group.notes[noteIndex].duration.realValue,
    );
    
    // Usar regra profissional do BeatPositionCalculator
    final shouldBreak = calculator.shouldBreakBeam(noteEvent);
    
    // Aplicar apenas se beam level for alto o suficiente
    return shouldBreak && beamLevel >= breakAtLevel;
  }

  /// Cria fractional beam (broken beam/stub)
  BeamSegment _createFractionalBeam(
    AdvancedBeamGroup group,
    int noteIndex,
    int nextNoteIndex,
    int level,
  ) {
    // Determinar direção
    FractionalBeamSide side;

    if (noteIndex == 0) {
      side = FractionalBeamSide.right;
    } else if (nextNoteIndex >= group.notes.length) {
      side = FractionalBeamSide.left;
    } else {
      // No meio: verificar contexto (ritmo pontuado)
      final note = group.notes[noteIndex];
      final prevNote = group.notes[noteIndex - 1];

      if (_getDurationValue(note.duration) < _getDurationValue(prevNote.duration)) {
        side = FractionalBeamSide.right;
      } else {
        side = FractionalBeamSide.left;
      }
    }

    return BeamSegment(
      level: level,
      startNoteIndex: noteIndex,
      endNoteIndex: noteIndex,
      isFractional: true,
      fractionalSide: side,
      fractionalLength: noteheadWidth,
    );
  }

  /// Retorna número de beams para uma duração
  int _getBeamCount(Duration duration) {
    return switch (duration.type) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      DurationType.oneHundredTwentyEighth => 5,
      _ => 0, // Notas mais longas não têm beams
    };
  }

  /// Retorna valor numérico da duração (para comparação)
  double _getDurationValue(Duration duration) {
    return switch (duration.type) {
      DurationType.whole => 1.0,
      DurationType.half => 0.5,
      DurationType.quarter => 0.25,
      DurationType.eighth => 0.125,
      DurationType.sixteenth => 0.0625,
      DurationType.thirtySecond => 0.03125,
      DurationType.sixtyFourth => 0.015625,
      DurationType.oneHundredTwentyEighth => 0.0078125,
    };
  }
}
