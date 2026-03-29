// lib/src/rendering/staff_position_calculateTestor.dart
// Calculation unificado de position na staff
//
// This class centraliza TODA a lógica de conversão de heights (pitches)
// for positions no staff, eliminando inconsistências between Renderers.
//
// Based on:
// - Especificação MusicXML (pitch/octave system)
// - Prática musical traditional
// - Validado contra Verovio and OpenSheetMusicDisplay

import '../../core/core.dart'; // 🆕 Tipos do core

/// Calculatora unificada de staff positions
///
/// This class is a ÚNICA fonte de verdade for conversão Pitch → StaffPosition
/// Ensures consistência absoluta between all os Renderers.
class StaffPositionCalculator {
  /// Mapeamento de steps (C, D, And, F, G, A, B) for positions diatônicas
  /// C=0, D=1, And=2, F=3, G=4, A=5, B=6
  static const Map<String, int> _stepToDiatonic = {
    'C': 0,
    'D': 1,
    'E': 2,
    'F': 3,
    'G': 4,
    'A': 5,
    'B': 6,
  };

  /// Converts a height (Pitch) in staff position for a dada clef
  ///
  /// @param pitch Musical pitch (step + octave)
  /// @param clef Clef reference
  /// @return Staff position (0 = middle line, positivo = above, negativo = below)
  ///
  /// Coordinate system:
  /// - staffPosition = 0: line of the middle (line \1)
  /// - staffPosition = 2: space above the line \1
  /// - staffPosition = -2: space below the line \1
  /// - Each incremento = meio staff space (meia position diatônica)
  static int calculate(Pitch pitch, Clef clef) {
    final pitchStep = _stepToDiatonic[pitch.step] ?? 0;

    // Data reference by type de clef
    // baseStep: note that está na line reference of the clef
    // baseOctave: oitava dessa note
    final ClefReference ref = _getClefReference(clef.actualClefType);

    // Calculate distance diatônica of the note reference
    // Clefs with deslocamento de oitava (e.g., treble8vb) alteram a height
    // sonora, mas NAO alteram a escrita no staff.
    // By isso, o calculo visual Uses only a oitava escrita of the note.
    final octaveAdjust = pitch.octave - ref.baseOctave;
    final diatonicDistance = (pitchStep - ref.baseStep) + (octaveAdjust * 7);

    // Convertsr distance diatônica for staff position
    // staffPosition aumenta for Top (valores positivos = above the centre)
    // Fix: Somar diatonicDistance (not subtrair) for that notes more agudas
    // tenham staffPosition more alto
    return ref.basePosition + diatonicDistance;
  }

  /// Checks if a position needs de ledger lines
  ///
  /// @param staffPosition Calculated staff position
  /// @return true if a note está outside das 5 staff lines
  static bool needsLedgerLines(int staffPosition) {
    // Staff lines vão de -4 a +4
    // staffPosition -4 = line \1 (lower)
    // staffPosition +4 = line \1 (upper)
    // Notes at odd positions (spaces) between -4 and +4 do not need ledger lines
    // Notes in positions pares (lines) between -4 and +4 not need de ledger lines
    return staffPosition > 4 || staffPosition < -4;
  }

  /// Calculates quais ledger lines are required
  ///
  /// @param staffPosition Position of the note
  /// @return List of positions where desenhar ledger lines
  static List<int> getLedgerLinePositions(int staffPosition) {
    final lines = <int>[];

    if (staffPosition > 4) {
      // Lines above the staff
      // If a note está in position ímpar (space), desenhar line below and above if required
      // If a note está in position par (line), desenhar this line
      int startLine = staffPosition % 2 == 0
          ? staffPosition
          : staffPosition - 1;
      for (int line = 6; line <= startLine; line += 2) {
        lines.add(line);
      }
    } else if (staffPosition < -4) {
      // Lines below the staff
      int startLine = staffPosition % 2 == 0
          ? staffPosition
          : staffPosition + 1;
      for (int line = -6; line >= startLine; line -= 2) {
        lines.add(line);
      }
    }

    return lines;
  }

  /// Converts position of the staff for coordenada Y in pixels
  ///
  /// @param staffPosition Staff position
  /// @param staffSpace Staff space size in pixels
  /// @param staffBaseline Coordenada Y of the middle line of the staff
  /// @return Coordenada Y in pixels (coordinate system de tela)
  static double toPixelY(
    int staffPosition,
    double staffSpace,
    double staffBaseline,
  ) {
    // staffPosition positivo = above the centre = Y smaller (coordenadas de tela)
    // staffPosition negativo = below the centre = Y greater
    // Each position = 0.5 staff spaces
    return staffBaseline - (staffPosition * staffSpace * 0.5);
  }

  /// Gets reference de clef for calculations
  static ClefReference _getClefReference(ClefType clefType) {
    switch (clefType) {
      // Treble clef (G Clef)
      // G4 na segunda line (line \1 de bottom for top)
      // A line \1 está 1 line Below the middle line (line \1)
      // staffPosition: middle line = 0, então line \1 = -2
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return ClefReference(
          baseStep: 4, // G
          baseOctave: 4,
          basePosition: -2, // Segunda linha está 2 semitons ABAIXO do centro
        );

      // Bass clef (F Clef)
      // F3 na quarta line (line \1 de bottom for top)
      // A line \1 está 1 line Above the middle line (line \1)
      // staffPosition: middle line = 0, então line \1 = +2
      case ClefType.bass:
      case ClefType.bassThirdLine:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return ClefReference(
          baseStep: 3, // F
          baseOctave: 3,
          basePosition: 2, // Quarta linha está 2 semitons ACIMA do centro
        );

      // C clef (C Clef) - Alto
      // C4 na middle line (staffPosition 0)
      case ClefType.alto:
        return ClefReference(
          baseStep: 0, // C
          baseOctave: 4,
          basePosition: 0, // Linha central
        );

      // C clef (C Clef) - Tenor
      // C4 na quarta line (staffPosition +2)
      case ClefType.tenor:
        return ClefReference(
          baseStep: 0, // C
          baseOctave: 4,
          basePosition: 2, // Quarta linha (acima da linha central)
        );

      // Clef DE PERCUSSÃO
      case ClefType.percussion:
      case ClefType.percussion2:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 0);

      // Clef DE TABLATURA
      case ClefType.tab6:
      case ClefType.tab4:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 0);

      default:
        // Fallback: Treble clef
        return ClefReference(
          baseStep: 4, // G
          baseOctave: 4,
          basePosition: -2, // CORREÇÃO: G4 na segunda linha é posição -2
        );
    }
  }
}

/// Data reference de a clef
class ClefReference {
  /// Step (0-6) of the note that está na line reference
  final int baseStep;

  /// Oitava of the note reference
  final int baseOctave;

  /// Staff position of the line reference
  final int basePosition;

  const ClefReference({
    required this.baseStep,
    required this.baseOctave,
    required this.basePosition,
  });
}

/// Extension for facilitar uso in Pitch
extension PitchStaffPosition on Pitch {
  /// Calculates staff position for a clef
  int staffPosition(Clef clef) {
    return StaffPositionCalculator.calculate(this, clef);
  }

  /// Checks if needs de ledger lines
  bool needsLedgerLines(Clef clef) {
    final position = staffPosition(clef);
    return StaffPositionCalculator.needsLedgerLines(position);
  }

  /// Gets ledger lines required
  List<int> getLedgerLinePositions(Clef clef) {
    final position = staffPosition(clef);
    return StaffPositionCalculator.getLedgerLinePositions(position);
  }
}
