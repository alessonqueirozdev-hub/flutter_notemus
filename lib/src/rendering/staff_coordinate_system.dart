// lib/src/rendering/staff_coordinate_system.dart

import 'dart:ui';

/// Coordinate system based on staff spaces for posicionamento preciso
/// de elementos musicais, following padrões SMuFL.
class StaffCoordinateSystem {
  final double staffSpace;
  final Offset staffBaseline; // Linha central da pauta (3ª linha)

  StaffCoordinateSystem({
    required this.staffSpace,
    required this.staffBaseline,
  });

  /// Returns a Y position de a linha específica of the staff
  /// Linhas: 1 (inferior) até 5 (superior) - numeração default musical
  /// Linha 3 é o baseline (centro)
  double getStaffLineY(int lineNumber) {
    // Corrigir numeração: linha 1 = inferior, linha 5 = superior
    final offsetFromBaseline = (lineNumber - 3) * staffSpace;
    return staffBaseline.dy - offsetFromBaseline;
  }

  /// Returns a Y position de um space específico of the staff
  /// Spaces: 1 (between lines 1–2) through 4 (between lines 4–5)
  double getStaffSpaceY(int spaceNumber) {
    // Corrigir numeração: space 1 = inferior, space 4 = superior
    final offsetFromBaseline = (spaceNumber - 2.5) * staffSpace;
    return staffBaseline.dy - offsetFromBaseline;
  }

  /// Converts position de note (step + octave) for Y position na staff
  /// For treble clef: G4 fica na linha 2, C5 no space acima of the staff
  /// For bass clef: D3 fica na linha 4 (baseline = 3ª linha)
  /// For C clef: C4 fica na linha 3 (baseline)
  double getNoteY(String step, int octave, {String clef = 'treble'}) {
    if (clef == 'treble' || clef == 'g') {
      return _getTrebleClefNoteY(step, octave);
    } else if (clef == 'bass' || clef == 'f') {
      return _getBassClefNoteY(step, octave);
    } else if (clef == 'alto' || clef == 'c') {
      return _getAltoClefNoteY(step, octave);
    } else if (clef == 'tenor') {
      return _getTenorClefNoteY(step, octave);
    }
    return staffBaseline.dy;
  }

  double _getTrebleClefNoteY(String step, int octave) {
    // Fix: TIPOGRÁFICA SMuFL: System diatônico
    // staffBaseline = 3ª linha of the staff
    // Treble clef: G4 (Sol4) fica na 2ª linha, not B4 na 3ª linha
    // Each linha/space = 0.5 * staffSpace

    // Mapeamento diatônico das notes (position na escala de 7 notes)
    final stepToDiatonic = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    // CORRIGIDO: G4 = 2ª linha (1 space ABAIXO of the baseline)
    // Baseline = 3ª linha = B4
    const refStep = 'B';
    const refOctave = 4;
    final refDiatonicPos = stepToDiatonic[refStep]!;

    // Position diatônica of the note current
    final noteDiatonicPos = stepToDiatonic[step.toUpperCase()] ?? 0;

    // Calculatestesr distância in "passos" diatônicos
    final diatonicSteps =
        (noteDiatonicPos - refDiatonicPos) + ((octave - refOctave) * 7);

    // Each passo diatônico = 0.5 * staffSpace
    final noteY = staffBaseline.dy - (diatonicSteps * staffSpace * 0.5);

    return noteY;
  }

  double _getBassClefNoteY(String step, int octave) {
    // Bass clef: F3 = 4ª linha, D3 = 3ª linha (baseline)
    // staffBaseline = 3ª linha of the staff (D3 na bass clef)

    final stepToDiatonic = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    // D3 = linha central (baseline) = position 0
    const refStep = 'D';
    const refOctave = 3;
    final refDiatonicPos = stepToDiatonic[refStep]!;

    final noteDiatonicPos = stepToDiatonic[step.toUpperCase()] ?? 0;

    final diatonicSteps =
        (noteDiatonicPos - refDiatonicPos) + ((octave - refOctave) * 7);

    final noteY = staffBaseline.dy - (diatonicSteps * staffSpace * 0.5);

    return noteY;
  }

  double _getAltoClefNoteY(String step, int octave) {
    // C clef (Alto): C4 = 3ª linha (baseline)
    // staffBaseline = 3ª linha of the staff (C4 na C clef)

    final stepToDiatonic = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    // C4 = linha central (baseline) = position 0
    const refStep = 'C';
    const refOctave = 4;
    final refDiatonicPos = stepToDiatonic[refStep]!;

    final noteDiatonicPos = stepToDiatonic[step.toUpperCase()] ?? 0;

    final diatonicSteps =
        (noteDiatonicPos - refDiatonicPos) + ((octave - refOctave) * 7);

    final noteY = staffBaseline.dy - (diatonicSteps * staffSpace * 0.5);

    return noteY;
  }

  double _getTenorClefNoteY(String step, int octave) {
    // Fix: MUSICOLÓGICA: Clef de Dó (Tenor): C4 = 4ª linha
    // staffBaseline = 3ª linha of the staff
    // CORRETO: C4 está a linha ACIMA of the baseline (4ª linha)

    final stepToDiatonic = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    // CORRIGIDO: A3 = linha central (baseline = 3ª linha) for clef de tenor
    const refStep = 'A';
    const refOctave = 3;
    final refDiatonicPos = stepToDiatonic[refStep]!;

    final noteDiatonicPos = stepToDiatonic[step.toUpperCase()] ?? 0;

    final diatonicSteps =
        (noteDiatonicPos - refDiatonicPos) + ((octave - refOctave) * 7);

    final noteY = staffBaseline.dy - (diatonicSteps * staffSpace * 0.5);

    return noteY;
  }

  /// Returns positions for accidentals na armadura de clef
  List<double> getKeySignaturePositions(int count, {String clef = 'treble'}) {
    if (clef == 'treble' || clef == 'g') {
      if (count > 0) {
        // Sharps in treble clef: F# C# G# D# A# E# B#
        return [
          getNoteY('F', 5, clef: clef), // F#
          getNoteY('C', 5, clef: clef), // C#
          getNoteY('G', 5, clef: clef), // G#
          getNoteY('D', 5, clef: clef), // D#
          getNoteY('A', 4, clef: clef), // A#
          getNoteY('E', 5, clef: clef), // E#
          getNoteY('B', 4, clef: clef), // B#
        ].take(count).toList();
      } else {
        // Bemóis in treble clef: Bb Eb Ab Db Gb Cb Fb
        return [
          getNoteY('B', 4, clef: clef), // Bb
          getNoteY('E', 5, clef: clef), // Eb
          getNoteY('A', 4, clef: clef), // Ab
          getNoteY('D', 5, clef: clef), // Db
          getNoteY('G', 4, clef: clef), // Gb
          getNoteY('C', 5, clef: clef), // Cb
          getNoteY('F', 4, clef: clef), // Fb
        ].take(count.abs()).toList();
      }
    } else if (clef == 'bass' || clef == 'f') {
      if (count > 0) {
        // Sharps in bass clef: F# C# G# D# A# E# B#
        return [
          getNoteY('F', 3, clef: clef), // F#
          getNoteY('C', 4, clef: clef), // C#
          getNoteY('G', 3, clef: clef), // G#
          getNoteY('D', 4, clef: clef), // D#
          getNoteY('A', 2, clef: clef), // A#
          getNoteY('E', 3, clef: clef), // E#
          getNoteY('B', 2, clef: clef), // B#
        ].take(count).toList();
      } else {
        // Bemóis in bass clef: Bb Eb Ab Db Gb Cb Fb
        return [
          getNoteY('B', 2, clef: clef), // Bb
          getNoteY('E', 3, clef: clef), // Eb
          getNoteY('A', 2, clef: clef), // Ab
          getNoteY('D', 3, clef: clef), // Db
          getNoteY('G', 2, clef: clef), // Gb
          getNoteY('C', 3, clef: clef), // Cb
          getNoteY('F', 2, clef: clef), // Fb
        ].take(count.abs()).toList();
      }
    } else if (clef == 'alto' || clef == 'c') {
      if (count > 0) {
        // Sharps in C clef (alto): F# C# G# D# A# E# B#
        return [
          getNoteY('F', 4, clef: clef), // F#
          getNoteY('C', 5, clef: clef), // C#
          getNoteY('G', 4, clef: clef), // G#
          getNoteY('D', 5, clef: clef), // D#
          getNoteY('A', 3, clef: clef), // A#
          getNoteY('E', 4, clef: clef), // E#
          getNoteY('B', 3, clef: clef), // B#
        ].take(count).toList();
      } else {
        // Bemóis in C clef (alto): Bb Eb Ab Db Gb Cb Fb
        return [
          getNoteY('B', 3, clef: clef), // Bb
          getNoteY('E', 4, clef: clef), // Eb
          getNoteY('A', 3, clef: clef), // Ab
          getNoteY('D', 4, clef: clef), // Db
          getNoteY('G', 3, clef: clef), // Gb
          getNoteY('C', 4, clef: clef), // Cb
          getNoteY('F', 3, clef: clef), // Fb
        ].take(count.abs()).toList();
      }
    } else if (clef == 'tenor') {
      if (count > 0) {
        // Sharps in clef de tenor: F# C# G# D# A# E# B#
        return [
          getNoteY('F', 4, clef: clef), // F#
          getNoteY('C', 5, clef: clef), // C#
          getNoteY('G', 4, clef: clef), // G#
          getNoteY('D', 5, clef: clef), // D#
          getNoteY('A', 4, clef: clef), // A#
          getNoteY('E', 5, clef: clef), // E#
          getNoteY('B', 4, clef: clef), // B#
        ].take(count).toList();
      } else {
        // Bemóis in clef de tenor: Bb Eb Ab Db Gb Cb Fb
        return [
          getNoteY('B', 4, clef: clef), // Bb
          getNoteY('E', 5, clef: clef), // Eb
          getNoteY('A', 4, clef: clef), // Ab
          getNoteY('D', 5, clef: clef), // Db
          getNoteY('G', 4, clef: clef), // Gb
          getNoteY('C', 5, clef: clef), // Cb
          getNoteY('F', 4, clef: clef), // Fb
        ].take(count.abs()).toList();
      }
    }
    return [];
  }

  /// Calculatestes position for fórmula de measure
  /// Numerador acima of the linha central, denominador abaixo
  Offset getTimeSignatureNumeratorPosition(Offset basePosition) {
    return Offset(basePosition.dx, staffBaseline.dy - (staffSpace * 0.5));
  }

  Offset getTimeSignatureDenominatorPosition(Offset basePosition) {
    return Offset(basePosition.dx, staffBaseline.dy + (staffSpace * 0.5));
  }

  /// Position default for treble clef
  /// A clef deve ser posicionada de forma that o círculo fique na 2ª linha
  Offset getClefPosition(Offset basePosition, {String clef = 'treble'}) {
    if (clef == 'treble' || clef == 'g') {
      // A treble clef deve ficar centrada na staff
      return Offset(basePosition.dx, staffBaseline.dy);
    }
    return basePosition;
  }

  /// Desenha as linhas of the staff
  void drawStaffLines(Canvas canvas, double width, Paint paint) {
    for (int line = 1; line <= 5; line++) {
      final y = getStaffLineY(line);
      canvas.drawLine(
        Offset(staffBaseline.dx, y),
        Offset(staffBaseline.dx + width, y),
        paint,
      );
    }
  }

  /// Calculatestes height total necessária for a staff
  double get totalStaffHeight => staffSpace * 4; // 4 espaços entre 5 linhas

  /// Margem added acima e abaixo of the staff for elementos externos
  double get staffMargin => staffSpace * 2;

  /// Height total incluindo margens
  double get totalHeight => totalStaffHeight + (staffMargin * 2);

  /// Calculatestes a position staff position (line number) based on Y
  /// Returns valores como: -4, -3, -2, -1, 0, 1, 2, 3, 4
  /// where 0 = linha central, positivo = acima, negativo = abaixo
  int getStaffPosition(double y) {
    final deltaY = staffBaseline.dy - y;
    final staffSpacePosition = deltaY / (staffSpace * 0.5);
    return staffSpacePosition.round();
  }
}
