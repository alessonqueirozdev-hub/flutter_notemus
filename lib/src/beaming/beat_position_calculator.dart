// lib/src/beaming/beat_position_calculateTestor.dart

import 'package:flutter_notemus/core/core.dart';

/// Information about the beat position of a musical event.
class BeatPositionInfo {
  /// Beat index (0 = first beat, 1 = second beat, etc.).
  final int beatIndex;

  /// Position within the beat (0.0 = start, 1.0 = end).
  final double positionWithinBeat;

  BeatPositionInfo({
    required this.beatIndex,
    required this.positionWithinBeat,
  });

  @override
  String toString() =>
      'BeatPositionInfo(beatIndex: $beatIndex, positionWithinBeat: ${positionWithinBeat.toStringAsFixed(3)})';
}

/// Represents a musical event (note or rest) with its temporal position.
class NoteEvent {
  /// Position within the bar (0.0 = start, 1.0 = end of bar).
  /// Normalized as a fraction of the total bar length.
  final double positionInBar;

  /// Duration in whole notes (1.0 = whole, 0.5 = half, etc.).
  final double duration;

  NoteEvent({
    required this.positionInBar,
    required this.duration,
  });

  @override
  String toString() =>
      'NoteEvent(pos: ${positionInBar.toStringAsFixed(3)}, dur: ${duration.toStringAsFixed(3)})';
}

/// Calculator profissional de positions de beat for any fórmula de measure
///
/// Based on:
/// - Behind Bars (Elaine Gould) - regras de beaming
/// - Music Engraving Tips - convenções tipográficas
/// - Prática profissional de editoração musical
///
/// Suporta:
/// - Measures simples (2/4, 3/4, 4/4, etc.)
/// - Measures compostos (6/8, 9/8, 12/8, etc.)
/// - Measures irregulares (5/8, 7/8, 11/16, etc.)
/// - Agrupamentos customizados
class BeatPositionCalculator {
  final TimeSignature timeSignature;
  
  /// Agrupamentos customizados for measures irregulares
  /// Example: 7/8 pode ser [2, 2, 3] ou [3, 2, 2]
  final List<int>? customBeatGrouping;

  BeatPositionCalculator(
    this.timeSignature, {
    this.customBeatGrouping,
  });

  /// Checks se o measure é composto (numerador divisível por 3, denominador 8)
  /// Examples: 6/8, 9/8, 12/8
  bool get isCompound =>
      timeSignature.numerator % 3 == 0 && timeSignature.denominator == 8;

  /// Returns o comprimento de um beat in semibreves
  ///
  /// - Measure simples: 1/denominador (ex: 4/4 → 1/4 = 0.25)
  /// - Measure composto: 3/denominador (ex: 6/8 → 3/8 = 0.375)
  double get beatLength {
    if (isCompound) {
      // Beat é note pontuada (3 subdivisões)
      return 3.0 / timeSignature.denominator;
    }
    return 1.0 / timeSignature.denominator;
  }

  /// Returns o number de beats por measure
  ///
  /// - Measure simples: numerador (ex: 4/4 → 4 beats)
  /// - Measure composto: numerador/3 (ex: 6/8 → 2 beats)
  int get beatsPerBar {
    if (isCompound) {
      return timeSignature.numerator ~/ 3;
    }
    return timeSignature.numerator;
  }

  /// Returns o comprimento total of the measure in semibreves
  double barLengthInWholeNotes() =>
      timeSignature.numerator / timeSignature.denominator;

  /// Returns informações sobre a position de beat de um ponto temporal
  ///
  /// @param positionInBar Normalised position within the measure (0.0 a 1.0)
  /// @return BeatPositionInfo with index of the beat e position dentro dele
  BeatPositionInfo getBeatPosition(double positionInBar) {
    final double beatLen = beatLength;
    final int beatIndex = (positionInBar / beatLen).floor();
    final double positionWithinBeat = (positionInBar % beatLen) / beatLen;
    
    return BeatPositionInfo(
      beatIndex: beatIndex,
      positionWithinBeat: positionWithinBeat,
    );
  }

  /// Returns a position de beat de um evento musical
  BeatPositionInfo getNoteBeatPosition(NoteEvent note) =>
      getBeatPosition(note.positionInBar);

  /// Returns as positions where beams devem ser broken per Behind Bars
  ///
  /// **REGRAS:**
  /// - Quebra no início de each beat (exceto beat 0)
  /// - Measures simples: quebra a each beat
  /// - Measures compostos: quebra entre grupos de 3
  /// - Measures irregulares: Uses agrupamentos customizados
  List<double> getStandardBeamBreakPositions() {
    final List<double> positions = [];
    final double beatLen = beatLength;
    final double barLen = barLengthInWholeNotes();

    if (customBeatGrouping != null) {
      // Measures irregulares with agrupamentos customizados
      double currentPos = 0.0;
      for (int i = 0; i < customBeatGrouping!.length; i++) {
        currentPos += customBeatGrouping![i] / timeSignature.denominator;
        if (currentPos < barLen) {
          positions.add(currentPos);
        }
      }
    } else {
      // Measures regulares: quebra no início de each beat
      for (int i = 1; i < beatsPerBar; i++) {
        final double breakPoint = beatLen * i;
        if (breakPoint < barLen) {
          positions.add(breakPoint);
        }
      }
    }

    return positions;
  }

  /// Determina se um beam deve ser quebrado nesta position
  ///
  /// **REGRAS BEHIND BARS:**
  /// 1. Always quebra no início of the measure (position 0.0)
  /// 2. Quebra nos pontos de beat definidos pela métrica
  /// 3. Never agrupa além of the meio of the measure in 4/4
  /// 4. in 6/8, quebra entre os 2 beats (após 3ª colcheia)
  /// 5. Tolerância de 1e-7 for comparações de ponto flutuante
  ///
  /// @param note Evento musical a Checksr
  /// @param context List of notes no contexto (opcional for regras avançadas)
  bool shouldBreakBeam(NoteEvent note, {List<NoteEvent>? context}) {
    const double tolerance = 1e-7;

    // Regra básica: always quebra no início of the measure
    if (note.positionInBar.abs() < tolerance) {
      return true;
    }

    // Regra principal: quebra nos pontos de break definidos pela métrica
    for (final breakPoint in getStandardBeamBreakPositions()) {
      if ((note.positionInBar - breakPoint).abs() < tolerance) {
        return true;
      }
    }

    // ✅ REGRAS ESPECIAIS BEHIND BARS

    // 4/4: Never beam além of the meio of the measure (beat 3)
    if (timeSignature.numerator == 4 && timeSignature.denominator == 4) {
      const double middleOfBar = 0.5; // Beat 3 em 4/4
      if ((note.positionInBar - middleOfBar).abs() < tolerance) {
        return true;
      }
    }

    // 6/8 (e similares): Quebra na metade of the measure (entre beats 1 e 2)
    if (isCompound && beatsPerBar == 2) {
      final double halfBar = barLengthInWholeNotes() / 2;
      if ((note.positionInBar - halfBar).abs() < tolerance) {
        return true;
      }
    }

    // 3/4: Quebra in each beat (já coberto por getStandardBeamBreakPositions)
    // Mas garantir that not agrupa além of the beat
    if (timeSignature.numerator == 3 && timeSignature.denominator == 4) {
      // Já tratado pela lógica default
    }

    return false;
  }

  /// Returns all as positions iniciais de beats no measure
  ///
  /// Útil for Rendersção de grid visual ou debug
  List<double> getAllBeatPositionsInBar() {
    final List<double> positions = [0.0]; // Sempre inclui início
    final double beatLen = beatLength;
    final double barLen = barLengthInWholeNotes();

    for (int i = 1; i < beatsPerBar; i++) {
      final double beatPos = beatLen * i;
      if (beatPos < barLen) {
        positions.add(beatPos);
      }
    }

    return positions;
  }

  /// Converts a position absoluta (acumulada desde início of the música)
  /// for position relativa dentro of the measure
  ///
  /// @param absolutePosition Position in semibreves desde o início
  /// @param measureStartPosition Position of the início of the measure
  /// @return Normalised position within the measure (0.0 a 1.0)
  double absoluteToBarPosition(
    double absolutePosition,
    double measureStartPosition,
  ) {
    final double barLen = barLengthInWholeNotes();
    final double relativePos = absolutePosition - measureStartPosition;
    return relativePos / barLen;
  }

  /// Converts Note for NoteEvent with position Calculatestesda
  ///
  /// @param note Note musical
  /// @param positionInMeasure Position acumulada dentro of the measure (in semibreves)
  /// @return NoteEvent pronto for análise
  NoteEvent noteToEvent(Note note, double positionInMeasure) {
    final double barLen = barLengthInWholeNotes();
    final double normalizedPosition = positionInMeasure / barLen;
    final double duration = note.duration.realValue;

    return NoteEvent(
      positionInBar: normalizedPosition,
      duration: duration,
    );
  }

  @override
  String toString() {
    final String type = isCompound ? 'Compound' : 'Simple';
    return 'BeatPositionCalculator($type ${timeSignature.numerator}/${timeSignature.denominator}, '
        'beatLength: ${beatLength.toStringAsFixed(3)}, '
        'beatsPerBar: $beatsPerBar)';
  }
}
