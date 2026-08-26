// lib/src/rendering/staff_position_calculator.dart
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
  /// @param extraOctaveShift Displacement contributed by an active [OctaveMark]
  ///        bracket (8va = +1, 8vb = -1, 15ma = +2 …), resolved by
  ///        [OctaveSpanTracker]. Same sign convention as `clef.octaveShift`.
  /// @return Staff position (0 = middle line, positivo = above, negativo = below)
  ///
  /// Coordinate system — positions are HALF-space steps, so an EVEN position is
  /// a staff LINE and an ODD position is a space:
  /// - staffPosition =  0: the middle (3rd) staff line
  /// - staffPosition =  1: the space just above the middle line
  /// - staffPosition =  2: the 4th staff line
  /// - staffPosition = -1: the space just below the middle line
  /// - staffPosition = -2: the 2nd staff line
  /// - the five staff lines are therefore -4, -2, 0, +2, +4
  ///
  /// This dartdoc used to claim "staffPosition = 2: space above the middle
  /// line", which is off by one whole step: position 2 is the 4th LINE, and the
  /// space above the middle line is position 1. Nothing in the code ever
  /// followed the wrong description — `_getClefReference` places every staff
  /// line on an even `basePosition` — but the comment sent readers looking for a
  /// bug that was not there.
  static int calculate(Pitch pitch, Clef clef, {int extraOctaveShift = 0}) {
    final pitchStep = _stepToDiatonic[pitch.step] ?? 0;

    // Data reference by type de clef
    // baseStep: note that está na line reference of the clef
    // baseOctave: oitava dessa note
    final ClefReference ref = _getClefReference(clef.actualClefType);

    // Diatonic distance from the clef's reference note.
    final octaveAdjust = pitch.octave - ref.baseOctave;
    final diatonicDistance = (pitchStep - ref.baseStep) + (octaveAdjust * 7);

    // Octave-transposing clefs (8va/8vb/15ma/15mb).
    //
    // [Pitch] is the SOUNDING pitch — the same thing MusicXML `<pitch>`, MEI
    // `@pname/@oct` and MIDI all mean (ADR-003). A clef that sounds an octave
    // LOWER therefore has to PRINT a given sounding pitch an octave HIGHER on
    // the staff, which is 7 half-space positions up per octave of shift.
    //
    // This used to be skipped with the comment "alteram a altura sonora, mas
    // NÃO alteram a escrita no staff", and `MidiMapper` compensated by shifting
    // the MIDI number instead. That is a self-consistent convention on its own,
    // but it is NOT the convention the interchange formats use, so importing a
    // tenor part on a treble-8vb clef drew it an octave low and played it an
    // octave low too. It was not even applied consistently: `c8vb` baked the
    // shift into its own ClefReference (`baseOctave: 3`) and so already
    // implemented the sounding convention while every other octave clef
    // implemented the written one.
    // The 8va/8vb bracket is the SECOND instance of exactly the same rule, and
    // it lands here for exactly the same reason: an octave displacement moves
    // where a note is PRINTED, never what it sounds, so it belongs in the one
    // place that converts a sounding pitch into a staff position — not in the
    // renderers, and never in `MidiMapper`.
    //
    // Measured before this line existed: C6 printed at staffPosition 8 with no
    // mark AND at staffPosition 8 under every one of 8va/8vb/15ma/15mb/22da/22db
    // — `OctaveMark.octaveShift` had zero readers in lib/, test/ and example/,
    // so the page said "8va" while the noteheads stayed put. After: 8va -> 1,
    // 8vb -> 15, and the two axes compose (treble8va clef PLUS an 8va bracket
    // moves C6 two octaves down the page, to position -6).
    final octaveShiftPositions = (clef.octaveShift + extraOctaveShift) * 7;

    // staffPosition grows UPWARD (positive = above the middle line).
    return ref.basePosition + diatonicDistance - octaveShiftPositions;
  }

  /// Checks if a position needs de ledger lines
  ///
  /// @param staffPosition Calculated staff position
  /// @return true if drawing this note requires at least one ledger line
  ///
  /// This is the GATE in front of [getLedgerLinePositions] (both
  /// `LedgerLineRenderer.render` and `ChordRenderer._drawLedgerLines` call it
  /// first and bail out on false), so the two must answer the same question or
  /// the gate is meaningless.
  ///
  /// They did not. The old body was `staffPosition > 4 || staffPosition < -4`,
  /// which returns TRUE for +-5 while [getLedgerLinePositions] returns `[]` for
  /// +-5 — measured, both directions. +-5 is the SPACE immediately outside the
  /// staff (the staff lines are the even positions -4..+4, so +-5 sits between
  /// the outermost line and the first ledger line at +-6) and a note there needs
  /// NO ledger line at all. The disagreement drew no wrong ink — the gate passed
  /// and then an empty list was iterated — but it made the predicate lie about
  /// its own name, so `abs() > 4` is now `abs() >= 6`: exactly the positions
  /// [getLedgerLinePositions] actually produces a line for.
  static bool needsLedgerLines(int staffPosition) {
    return staffPosition >= 6 || staffPosition <= -6;
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
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return ClefReference(
          baseStep: 3, // F
          baseOctave: 3,
          basePosition: 2, // Quarta linha está 2 semitons ACIMA do centro
        );

      // Baritone F clef: F3 on the 3rd (middle) line.
      case ClefType.bassThirdLine:
        return ClefReference(baseStep: 3, baseOctave: 3, basePosition: 0);

      // C clefs (C4 on the clef line): line 1 = -4, 2 = -2, 3 = 0, 4 = +2,
      // 5 = +4 (each staff line is 2 half-space positions apart).
      case ClefType.soprano:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: -4);
      case ClefType.mezzoSoprano:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: -2);
      case ClefType.alto:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 0);
      case ClefType.tenor:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 2);
      case ClefType.baritone:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 4);
      case ClefType.c8vb:
        // C clef sounding an octave lower; same line as tenor by convention.
        //
        // The reference is plain C4, like every other C clef: the octave shift
        // is applied once, uniformly, in [calculate]. It used to be baked in
        // here as `baseOctave: 3`, which made this the ONLY clef that honoured
        // the sounding convention — leaving it would now shift c8vb twice.
        // Observable output is unchanged: a sounding C3 still lands on
        // position 2.
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 2);

      // Clef DE PERCUSSÃO
      case ClefType.percussion:
      case ClefType.percussion2:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 0);

      // Clef DE TABLATURA
      case ClefType.tab6:
      case ClefType.tab4:
        return ClefReference(baseStep: 0, baseOctave: 4, basePosition: 0);
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
///
/// Every member forwards [extraOctaveShift] to
/// [StaffPositionCalculator.calculate] so that a caller working through the
/// extension gets the same 8va/8vb displacement as one calling the calculator
/// directly — otherwise the ledger lines would be computed for the undisplaced
/// position and drift away from the notehead.
extension PitchStaffPosition on Pitch {
  /// Calculates staff position for a clef
  int staffPosition(Clef clef, {int extraOctaveShift = 0}) {
    return StaffPositionCalculator.calculate(
      this,
      clef,
      extraOctaveShift: extraOctaveShift,
    );
  }

  /// Checks if needs de ledger lines
  bool needsLedgerLines(Clef clef, {int extraOctaveShift = 0}) {
    final position = staffPosition(clef, extraOctaveShift: extraOctaveShift);
    return StaffPositionCalculator.needsLedgerLines(position);
  }

  /// Gets ledger lines required
  List<int> getLedgerLinePositions(Clef clef, {int extraOctaveShift = 0}) {
    final position = staffPosition(clef, extraOctaveShift: extraOctaveShift);
    return StaffPositionCalculator.getLedgerLinePositions(position);
  }
}
