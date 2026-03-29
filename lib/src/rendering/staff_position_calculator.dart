// lib/src/rendering/staff_position_calculateTestor.dart
// Cálculo unificado de position na staff
//
// This class centraliza TODA a lógica de conversão de heights (pitches)
// for positions no staff, eliminando inconsistências entre Renderers.
//
// Based on:
// - Especificação MusicXML (pitch/octave system)
// - Prática musical tradded
// - Validado contra Verovio e OpenSheetMusicDisplay

import '../../core/core.dart'; // 🆕 Tipos do core

/// Calculatora unificada de staff positions
///
/// This class é a ÚNICA fonte de verdade for conversão Pitch → StaffPosition
/// Garante consistência absoluta entre all os Renderers.
class StaffPositionCalculator {
  /// Mapeamento de steps (C, D, E, F, G, A, B) for positions diatônicas
  /// C=0, D=1, E=2, F=3, G=4, A=5, B=6
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
  /// @return Staff position (0 = linha central, positivo = acima, negativo = abaixo)
  ///
  /// Coordinate system:
  /// - staffPosition = 0: linha of the meio (linha 3)
  /// - staffPosition = 2: space acima of the linha 2
  /// - staffPosition = -2: space abaixo of the linha 4
  /// - Each incremento = meio staff space (meia position diatônica)
  static int calculate(Pitch pitch, Clef clef) {
    final pitchStep = _stepToDiatonic[pitch.step] ?? 0;

    // Dados reference por type de clef
    // baseStep: note that está na linha reference of the clef
    // baseOctave: oitava dessa note
    final ClefReference ref = _getClefReference(clef.actualClefType);

    // Calculatestesr distância diatônica of the note reference
    // Clefs with deslocamento de oitava (ex.: treble8vb) alteram a height
    // sonora, mas NAO alteram a escrita no staff.
    // Por isso, o calculo visual Uses apenas a oitava escrita of the note.
    final octaveAdjust = pitch.octave - ref.baseOctave;
    final diatonicDistance = (pitchStep - ref.baseStep) + (octaveAdjust * 7);

    // Convertsr distância diatônica for staff position
    // staffPosition aumenta for CIMA (valores positivos = acima of the centro)
    // Fix: Somar diatonicDistance (not subtrair) for that notes mais agudas
    // tenham staffPosition mais alto
    return ref.basePosition + diatonicDistance;
  }

  /// Checks se a position precisa de linhas suplementares
  ///
  /// @param staffPosition Calculated staff position
  /// @return true se a note está fora das 5 linhas of the staff
  static bool needsLedgerLines(int staffPosition) {
    // Linhas of the staff vão de -4 a +4
    // staffPosition -4 = linha 5 (inferior)
    // staffPosition +4 = linha 1 (superior)
    // Notes at odd positions (spaces) between -4 and +4 do not need ledger lines
    // Notes in positions pares (linhas) entre -4 e +4 not precisam de linhas suplementares
    return staffPosition > 4 || staffPosition < -4;
  }

  /// Calculatestes quais linhas suplementares are necessárias
  ///
  /// @param staffPosition Position of the note
  /// @return List of positions where desenhar linhas suplementares
  static List<int> getLedgerLinePositions(int staffPosition) {
    final lines = <int>[];

    if (staffPosition > 4) {
      // Linhas acima of the staff
      // Se a note está in position ímpar (space), desenhar linha abaixo e acima se necessário
      // Se a note está in position par (linha), desenhar this linha
      int startLine = staffPosition % 2 == 0
          ? staffPosition
          : staffPosition - 1;
      for (int line = 6; line <= startLine; line += 2) {
        lines.add(line);
      }
    } else if (staffPosition < -4) {
      // Linhas abaixo of the staff
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
  /// @param staffBaseline Coordenada Y of the linha central of the staff
  /// @return Coordenada Y in pixels (coordinate system de tela)
  static double toPixelY(
    int staffPosition,
    double staffSpace,
    double staffBaseline,
  ) {
    // staffPosition positivo = acima of the centro = Y smaller (coordenadas de tela)
    // staffPosition negativo = abaixo of the centro = Y greater
    // Each position = 0.5 staff spaces
    return staffBaseline - (staffPosition * staffSpace * 0.5);
  }

  /// Gets reference de clef for cálculos
  static ClefReference _getClefReference(ClefType clefType) {
    switch (clefType) {
      // Treble clef (G Clef)
      // G4 na segunda linha (linha 2 de baixo for cima)
      // A linha 2 está 1 linha ABAIXO of the linha central (linha 3)
      // staffPosition: linha central = 0, então linha 2 = -2
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
      // F3 na quarta linha (linha 4 de baixo for cima)
      // A linha 4 está 1 linha ACIMA of the linha central (linha 3)
      // staffPosition: linha central = 0, então linha 4 = +2
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
      // C4 na linha central (staffPosition 0)
      case ClefType.alto:
        return ClefReference(
          baseStep: 0, // C
          baseOctave: 4,
          basePosition: 0, // Linha central
        );

      // C clef (C Clef) - Tenor
      // C4 na quarta linha (staffPosition +2)
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

/// Dados reference de a clef
class ClefReference {
  /// Step (0-6) of the note that está na linha reference
  final int baseStep;

  /// Oitava of the note reference
  final int baseOctave;

  /// Staff position of the linha reference
  final int basePosition;

  const ClefReference({
    required this.baseStep,
    required this.baseOctave,
    required this.basePosition,
  });
}

/// Extensão for facilitar uso in Pitch
extension PitchStaffPosition on Pitch {
  /// Calculatestes staff position for a clef
  int staffPosition(Clef clef) {
    return StaffPositionCalculator.calculate(this, clef);
  }

  /// Checks se precisa de linhas suplementares
  bool needsLedgerLines(Clef clef) {
    final position = staffPosition(clef);
    return StaffPositionCalculator.needsLedgerLines(position);
  }

  /// Gets linhas suplementares necessárias
  List<int> getLedgerLinePositions(Clef clef) {
    final position = staffPosition(clef);
    return StaffPositionCalculator.getLedgerLinePositions(position);
  }
}
