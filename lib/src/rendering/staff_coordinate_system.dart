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

  /// Returns a Y position de a line específica of the staff
  /// Lines: 1 (lower) until 5 (upper) - numbering default musical
  /// Line \1 is o baseline (centre)
  double getStaffLineY(int lineNumber) {
    // Corrigir numbering: line \1 = lower, line \1 = upper
    final offsetFromBaseline = (lineNumber - 3) * staffSpace;
    return staffBaseline.dy - offsetFromBaseline;
  }

  /// Returns a Y position de a space específico of the staff
  /// Spaces: 1 (between lines 1–2) through 4 (between lines 4–5)
  double getStaffSpaceY(int spaceNumber) {
    // Corrigir numbering: space 1 = lower, space 4 = upper
    final offsetFromBaseline = (spaceNumber - 2.5) * staffSpace;
    return staffBaseline.dy - offsetFromBaseline;
  }

  /// Converts position de note (step + octave) for Y position na staff
  /// For treble clef: G4 is na line \1, C5 no space above the staff
  /// For bass clef: D3 is na line \1 (baseline = 3ª line)
  /// For C clef: C4 is na line \1 (baseline)
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
    // Fix: Typographic SMuFL: System diatônico
    // staffBaseline = 3ª staff line
    // Treble clef: G4 (Sol4) is na 2ª line, not B4 na 3ª line
    // Each line/space = 0.5 * staffSpace

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

    // CORRIGIDO: G4 = 2ª line (1 space Below the baseline)
    // Baseline = 3ª line = B4
    const refStep = 'B';
    const refOctave = 4;
    final refDiatonicPos = stepToDiatonic[refStep]!;

    // Position diatônica of the note current
    final noteDiatonicPos = stepToDiatonic[step.toUpperCase()] ?? 0;

    // Calculate distance in "passos" diatônicos
    final diatonicSteps =
        (noteDiatonicPos - refDiatonicPos) + ((octave - refOctave) * 7);

    // Each passo diatônico = 0.5 * staffSpace
    final noteY = staffBaseline.dy - (diatonicSteps * staffSpace * 0.5);

    return noteY;
  }

  double _getBassClefNoteY(String step, int octave) {
    // Bass clef: F3 = 4ª line, D3 = 3ª line (baseline)
    // staffBaseline = 3ª staff line (D3 na bass clef)

    final stepToDiatonic = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    // D3 = middle line (baseline) = position 0
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
    // C clef (Alto): C4 = 3ª line (baseline)
    // staffBaseline = 3ª staff line (C4 na C clef)

    final stepToDiatonic = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    // C4 = middle line (baseline) = position 0
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
    // Fix: MUSICOLÓGICA: Clef de Dó (Tenor): C4 = 4ª line
    // staffBaseline = 3ª staff line
    // Correct: C4 está a line Above the baseline (4ª line)

    final stepToDiatonic = {
      'C': 0,
      'D': 1,
      'E': 2,
      'F': 3,
      'G': 4,
      'A': 5,
      'B': 6,
    };

    // CORRIGIDO: A3 = middle line (baseline = 3ª line) for clef de tenor
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
        // Sharps in treble clef: F# C# G# D# A# And# B#
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
        // Sharps in bass clef: F# C# G# D# A# And# B#
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
        // Sharps in C clef (alto): F# C# G# D# A# And# B#
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
        // Sharps in clef de tenor: F# C# G# D# A# And# B#
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

  /// Calculates position for fórmula de measure
  /// Numerator above the middle line, denominator below
  Offset getTimeSignatureNumeratorPosition(Offset basePosition) {
    return Offset(basePosition.dx, staffBaseline.dy - (staffSpace * 0.5));
  }

  Offset getTimeSignatureDenominatorPosition(Offset basePosition) {
    return Offset(basePosition.dx, staffBaseline.dy + (staffSpace * 0.5));
  }

  /// Position default for treble clef
  /// A clef must be positioned de forma that o circle be placed na 2ª line
  Offset getClefPosition(Offset basePosition, {String clef = 'treble'}) {
    if (clef == 'treble' || clef == 'g') {
      // A treble clef must be placed centred na staff
      return Offset(basePosition.dx, staffBaseline.dy);
    }
    return basePosition;
  }

  /// Desenha as staff lines
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

  /// Calculates height total required for a staff
  double get totalStaffHeight => staffSpace * 4; // 4 espaços entre 5 linhas

  /// Margin added above and below the staff for elementos externos
  double get staffMargin => staffSpace * 2;

  /// Height total incluindo margins
  double get totalHeight => totalStaffHeight + (staffMargin * 2);

  /// Calculates a position staff position (line number) based on Y
  /// Returns valores as: -4, -3, -2, -1, 0, 1, 2, 3, 4
  /// where 0 = middle line, positivo = above, negativo = below
  int getStaffPosition(double y) {
    final deltaY = staffBaseline.dy - y;
    final staffSpacePosition = deltaY / (staffSpace * 0.5);
    return staffSpacePosition.round();
  }
}
