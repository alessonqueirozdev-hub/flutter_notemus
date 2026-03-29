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
  /// Example: 7/8 can be [2, 2, 3] or [3, 2, 2]
  final List<int>? customBeatGrouping;

  BeatPositionCalculator(
    this.timeSignature, {
    this.customBeatGrouping,
  });

  /// Checks if o measure is composto (numerator divisível by 3, denominator 8)
  /// Examples: 6/8, 9/8, 12/8
  bool get isCompound =>
      timeSignature.numerator % 3 == 0 && timeSignature.denominator == 8;

  /// Returns o length de a beat in semibreves
  ///
  /// - Measure simples: 1/denominator (ex: 4/4 → 1/4 = 0.25)
  /// - Measure composto: 3/denominator (ex: 6/8 → 3/8 = 0.375)
  double get beatLength {
    if (isCompound) {
      // Beat is note pontuada (3 subdivisões)
      return 3.0 / timeSignature.denominator;
    }
    return 1.0 / timeSignature.denominator;
  }

  /// Returns o number de beats by measure
  ///
  /// - Measure simples: numerator (ex: 4/4 → 4 beats)
  /// - Measure composto: numerator/3 (ex: 6/8 → 2 beats)
  int get beatsPerBar {
    if (isCompound) {
      return timeSignature.numerator ~/ 3;
    }
    return timeSignature.numerator;
  }

  /// Returns o length total of the measure in semibreves
  double barLengthInWholeNotes() =>
      timeSignature.numerator / timeSignature.denominator;

  /// Returns informações on/about a position de beat de a point temporal
  ///
  /// @param positionInBar Normalised position within the measure (0.0 a 1.0)
  /// @return BeatPositionInfo with index of the beat and position within dele
  BeatPositionInfo getBeatPosition(double positionInBar) {
    final double beatLen = beatLength;
    final int beatIndex = (positionInBar / beatLen).floor();
    final double positionWithinBeat = (positionInBar % beatLen) / beatLen;
    
    return BeatPositionInfo(
      beatIndex: beatIndex,
      positionWithinBeat: positionWithinBeat,
    );
  }

  /// Returns a position de beat de a evento musical
  BeatPositionInfo getNoteBeatPosition(NoteEvent note) =>
      getBeatPosition(note.positionInBar);

  /// Returns as positions where beams must be broken per Behind Bars
  ///
  /// **REGRAS:**
  /// - Quebra no start de each beat (exceto beat 0)
  /// - Measures simples: quebra a each beat
  /// - Measures compostos: quebra between grupos de 3
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
      // Measures regulares: quebra no start de each beat
      for (int i = 1; i < beatsPerBar; i++) {
        final double breakPoint = beatLen * i;
        if (breakPoint < barLen) {
          positions.add(breakPoint);
        }
      }
    }

    return positions;
  }

  /// Determina if a beam must be quebrado nesta position
  ///
  /// **REGRAS BEHIND BARS:**
  /// 1. Always quebra no start of the measure (position 0.0)
  /// 2. Quebra nos points de beat definidos pela métrica
  /// 3. Never agrupa além of the middle of the measure in 4/4
  /// 4. in 6/8, quebra between os 2 beats (after 3ª colcheia)
  /// 5. Tolerância de 1e-7 for comparações de point flutuante
  ///
  /// @param note Evento musical a Check
  /// @param context List of notes no context (opcional for regras avançadas)
  bool shouldBreakBeam(NoteEvent note, {List<NoteEvent>? context}) {
    const double tolerance = 1e-7;

    // Regra básica: always quebra no start of the measure
    if (note.positionInBar.abs() < tolerance) {
      return true;
    }

    // Regra principal: quebra nos points de break definidos pela métrica
    for (final breakPoint in getStandardBeamBreakPositions()) {
      if ((note.positionInBar - breakPoint).abs() < tolerance) {
        return true;
      }
    }

    // ✅ REGRAS ESPECIAIS BEHIND BARS

    // 4/4: Never beam além of the middle of the measure (beat 3)
    if (timeSignature.numerator == 4 && timeSignature.denominator == 4) {
      const double middleOfBar = 0.5; // Beat 3 em 4/4
      if ((note.positionInBar - middleOfBar).abs() < tolerance) {
        return true;
      }
    }

    // 6/8 (and similares): Quebra na metade of the measure (between beats 1 and 2)
    if (isCompound && beatsPerBar == 2) {
      final double halfBar = barLengthInWholeNotes() / 2;
      if ((note.positionInBar - halfBar).abs() < tolerance) {
        return true;
      }
    }

    // 3/4: Quebra in each beat (already coberto by getStandardBeamBreakPositions)
    // Mas ensure that not agrupa além of the beat
    if (timeSignature.numerator == 3 && timeSignature.denominator == 4) {
      // Already tratado pela lógica default
    }

    return false;
  }

  /// Returns all as positions iniciais de beats no measure
  ///
  /// Útil for Rendering de grid visual or debug
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

  /// Converts a position absoluta (acumulada since start of the music)
  /// for position relativa within of the measure
  ///
  /// @param absolutePosition Position in semibreves since o start
  /// @param measureStartPosition Position of the start of the measure
  /// @return Normalised position within the measure (0.0 a 1.0)
  double absoluteToBarPosition(
    double absolutePosition,
    double measureStartPosition,
  ) {
    final double barLen = barLengthInWholeNotes();
    final double relativePos = absolutePosition - measureStartPosition;
    return relativePos / barLen;
  }

  /// Converts Note for NoteEvent with position Calculated
  ///
  /// @param note Note musical
  /// @param positionInMeasure Position acumulada within of the measure (in semibreves)
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
