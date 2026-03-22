// lib/src/beaming/beat_position_calculator.dart

import 'package:flutter_notemus/core/core.dart';

/// Informações sobre a posição de um evento musical dentro de um beat
class BeatPositionInfo {
  /// Índice do beat (0 = primeiro beat, 1 = segundo beat, etc.)
  final int beatIndex;
  
  /// Posição dentro do beat (0.0 = início, 1.0 = fim)
  final double positionWithinBeat;

  BeatPositionInfo({
    required this.beatIndex,
    required this.positionWithinBeat,
  });

  @override
  String toString() =>
      'BeatPositionInfo(beatIndex: $beatIndex, positionWithinBeat: ${positionWithinBeat.toStringAsFixed(3)})';
}

/// Representa um evento musical (nota ou pausa) com sua posição temporal
class NoteEvent {
  /// Posição no compasso (0.0 = início, 1.0 = fim do compasso)
  /// Normalizado em fração do compasso total
  final double positionInBar;
  
  /// Duração em semibreves (1.0 = semibreve, 0.5 = mínima, etc.)
  final double duration;

  NoteEvent({
    required this.positionInBar,
    required this.duration,
  });

  @override
  String toString() =>
      'NoteEvent(pos: ${positionInBar.toStringAsFixed(3)}, dur: ${duration.toStringAsFixed(3)})';
}

/// Calculador profissional de posições de beat para qualquer fórmula de compasso
///
/// Baseado em:
/// - Behind Bars (Elaine Gould) - regras de beaming
/// - Music Engraving Tips - convenções tipográficas
/// - Prática profissional de editoração musical
///
/// Suporta:
/// - Compassos simples (2/4, 3/4, 4/4, etc.)
/// - Compassos compostos (6/8, 9/8, 12/8, etc.)
/// - Compassos irregulares (5/8, 7/8, 11/16, etc.)
/// - Agrupamentos customizados
class BeatPositionCalculator {
  final TimeSignature timeSignature;
  
  /// Agrupamentos customizados para compassos irregulares
  /// Exemplo: 7/8 pode ser [2, 2, 3] ou [3, 2, 2]
  final List<int>? customBeatGrouping;

  BeatPositionCalculator(
    this.timeSignature, {
    this.customBeatGrouping,
  });

  /// Verifica se o compasso é composto (numerador divisível por 3, denominador 8)
  /// Exemplos: 6/8, 9/8, 12/8
  bool get isCompound =>
      timeSignature.numerator % 3 == 0 && timeSignature.denominator == 8;

  /// Retorna o comprimento de um beat em semibreves
  ///
  /// - Compasso simples: 1/denominador (ex: 4/4 → 1/4 = 0.25)
  /// - Compasso composto: 3/denominador (ex: 6/8 → 3/8 = 0.375)
  double get beatLength {
    if (isCompound) {
      // Beat é nota pontuada (3 subdivisões)
      return 3.0 / timeSignature.denominator;
    }
    return 1.0 / timeSignature.denominator;
  }

  /// Retorna o número de beats por compasso
  ///
  /// - Compasso simples: numerador (ex: 4/4 → 4 beats)
  /// - Compasso composto: numerador/3 (ex: 6/8 → 2 beats)
  int get beatsPerBar {
    if (isCompound) {
      return timeSignature.numerator ~/ 3;
    }
    return timeSignature.numerator;
  }

  /// Retorna o comprimento total do compasso em semibreves
  double barLengthInWholeNotes() =>
      timeSignature.numerator / timeSignature.denominator;

  /// Retorna informações sobre a posição de beat de um ponto temporal
  ///
  /// @param positionInBar Posição normalizada no compasso (0.0 a 1.0)
  /// @return BeatPositionInfo com índice do beat e posição dentro dele
  BeatPositionInfo getBeatPosition(double positionInBar) {
    final double beatLen = beatLength;
    final int beatIndex = (positionInBar / beatLen).floor();
    final double positionWithinBeat = (positionInBar % beatLen) / beatLen;
    
    return BeatPositionInfo(
      beatIndex: beatIndex,
      positionWithinBeat: positionWithinBeat,
    );
  }

  /// Retorna a posição de beat de um evento musical
  BeatPositionInfo getNoteBeatPosition(NoteEvent note) =>
      getBeatPosition(note.positionInBar);

  /// Retorna as posições onde beams devem ser quebrados segundo Behind Bars
  ///
  /// **REGRAS:**
  /// - Quebra no início de cada beat (exceto beat 0)
  /// - Compassos simples: quebra a cada beat
  /// - Compassos compostos: quebra entre grupos de 3
  /// - Compassos irregulares: usa agrupamentos customizados
  List<double> getStandardBeamBreakPositions() {
    final List<double> positions = [];
    final double beatLen = beatLength;
    final double barLen = barLengthInWholeNotes();

    if (customBeatGrouping != null) {
      // Compassos irregulares com agrupamentos customizados
      double currentPos = 0.0;
      for (int i = 0; i < customBeatGrouping!.length; i++) {
        currentPos += customBeatGrouping![i] / timeSignature.denominator;
        if (currentPos < barLen) {
          positions.add(currentPos);
        }
      }
    } else {
      // Compassos regulares: quebra no início de cada beat
      for (int i = 1; i < beatsPerBar; i++) {
        final double breakPoint = beatLen * i;
        if (breakPoint < barLen) {
          positions.add(breakPoint);
        }
      }
    }

    return positions;
  }

  /// Determina se um beam deve ser quebrado nesta posição
  ///
  /// **REGRAS BEHIND BARS:**
  /// 1. Sempre quebra no início do compasso (posição 0.0)
  /// 2. Quebra nos pontos de beat definidos pela métrica
  /// 3. Nunca agrupa além do meio do compasso em 4/4
  /// 4. Em 6/8, quebra entre os 2 beats (após 3ª colcheia)
  /// 5. Tolerância de 1e-7 para comparações de ponto flutuante
  ///
  /// @param note Evento musical a verificar
  /// @param context Lista de notas no contexto (opcional para regras avançadas)
  bool shouldBreakBeam(NoteEvent note, {List<NoteEvent>? context}) {
    const double tolerance = 1e-7;

    // Regra básica: sempre quebra no início do compasso
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

    // 4/4: Nunca beam além do meio do compasso (beat 3)
    if (timeSignature.numerator == 4 && timeSignature.denominator == 4) {
      const double middleOfBar = 0.5; // Beat 3 em 4/4
      if ((note.positionInBar - middleOfBar).abs() < tolerance) {
        return true;
      }
    }

    // 6/8 (e similares): Quebra na metade do compasso (entre beats 1 e 2)
    if (isCompound && beatsPerBar == 2) {
      final double halfBar = barLengthInWholeNotes() / 2;
      if ((note.positionInBar - halfBar).abs() < tolerance) {
        return true;
      }
    }

    // 3/4: Quebra em cada beat (já coberto por getStandardBeamBreakPositions)
    // Mas garantir que não agrupa além do beat
    if (timeSignature.numerator == 3 && timeSignature.denominator == 4) {
      // Já tratado pela lógica padrão
    }

    return false;
  }

  /// Retorna todas as posições iniciais de beats no compasso
  ///
  /// Útil para renderização de grid visual ou debug
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

  /// Converte uma posição absoluta (acumulada desde início da música)
  /// para posição relativa dentro do compasso
  ///
  /// @param absolutePosition Posição em semibreves desde o início
  /// @param measureStartPosition Posição do início do compasso
  /// @return Posição normalizada no compasso (0.0 a 1.0)
  double absoluteToBarPosition(
    double absolutePosition,
    double measureStartPosition,
  ) {
    final double barLen = barLengthInWholeNotes();
    final double relativePos = absolutePosition - measureStartPosition;
    return relativePos / barLen;
  }

  /// Converte Note para NoteEvent com posição calculada
  ///
  /// @param note Nota musical
  /// @param positionInMeasure Posição acumulada dentro do compasso (em semibreves)
  /// @return NoteEvent pronto para análise
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
