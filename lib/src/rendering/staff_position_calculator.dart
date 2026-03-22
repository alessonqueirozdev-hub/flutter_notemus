// lib/src/rendering/staff_position_calculator.dart
// NOVA CLASSE: Cálculo unificado de posições na pauta
//
// Esta classe centraliza TODA a lógica de conversão de alturas (pitches)
// para posições no pentagrama, eliminando inconsistências entre renderizadores.
//
// Baseado em:
// - Especificação MusicXML (pitch/octave system)
// - Prática musical tradicional
// - Validado contra Verovio e OpenSheetMusicDisplay

import '../../core/core.dart'; // 🆕 Tipos do core

/// Calculadora unificada de posições na pauta
///
/// Esta classe é a ÚNICA fonte de verdade para conversão Pitch → StaffPosition
/// Garante consistência absoluta entre todos os renderizadores.
class StaffPositionCalculator {
  /// Mapeamento de steps (C, D, E, F, G, A, B) para posições diatônicas
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

  /// Converte uma altura (Pitch) em posição na pauta para uma dada clave
  ///
  /// @param pitch Altura musical (step + octave)
  /// @param clef Clave de referência
  /// @return Posição na pauta (0 = linha central, positivo = acima, negativo = abaixo)
  ///
  /// Sistema de coordenadas:
  /// - staffPosition = 0: linha do meio (linha 3)
  /// - staffPosition = 2: espaço acima da linha 2
  /// - staffPosition = -2: espaço abaixo da linha 4
  /// - Cada incremento = meio staff space (meia posição diatônica)
  static int calculate(Pitch pitch, Clef clef) {
    final pitchStep = _stepToDiatonic[pitch.step] ?? 0;

    // Dados de referência por tipo de clave
    // baseStep: nota que está na linha de referência da clave
    // baseOctave: oitava dessa nota
    final ClefReference ref = _getClefReference(clef.actualClefType);

    // Calcular distância diatônica da nota de referência
    final octaveAdjust = pitch.octave + clef.octaveShift - ref.baseOctave;
    final diatonicDistance = (pitchStep - ref.baseStep) + (octaveAdjust * 7);

    // Converter distância diatônica para posição na pauta
    // staffPosition aumenta para CIMA (valores positivos = acima do centro)
    // CORREÇÃO: Somar diatonicDistance (não subtrair) para que notas mais agudas
    // tenham staffPosition mais alto
    return ref.basePosition + diatonicDistance;
  }

  /// Verifica se uma posição precisa de linhas suplementares
  ///
  /// @param staffPosition Posição calculada na pauta
  /// @return true se a nota está fora das 5 linhas do pentagrama
  static bool needsLedgerLines(int staffPosition) {
    // Linhas do pentagrama vão de -4 a +4
    // staffPosition -4 = linha 5 (inferior)
    // staffPosition +4 = linha 1 (superior)
    // Notas em posições ímpares (espaços) entre -4 e +4 não precisam de linhas suplementares
    // Notas em posições pares (linhas) entre -4 e +4 não precisam de linhas suplementares
    return staffPosition > 4 || staffPosition < -4;
  }

  /// Calcula quais linhas suplementares são necessárias
  ///
  /// @param staffPosition Posição da nota
  /// @return Lista de posições onde desenhar linhas suplementares
  static List<int> getLedgerLinePositions(int staffPosition) {
    final lines = <int>[];

    if (staffPosition > 4) {
      // Linhas acima do pentagrama
      // Se a nota está em posição ímpar (espaço), desenhar linha abaixo e acima se necessário
      // Se a nota está em posição par (linha), desenhar essa linha
      int startLine = staffPosition % 2 == 0 ? staffPosition : staffPosition - 1;
      for (int line = 6; line <= startLine; line += 2) {
        lines.add(line);
      }
    } else if (staffPosition < -4) {
      // Linhas abaixo do pentagrama
      int startLine = staffPosition % 2 == 0 ? staffPosition : staffPosition + 1;
      for (int line = -6; line >= startLine; line -= 2) {
        lines.add(line);
      }
    }

    return lines;
  }

  /// Converte posição da pauta para coordenada Y em pixels
  ///
  /// @param staffPosition Posição na pauta
  /// @param staffSpace Tamanho do staff space em pixels
  /// @param staffBaseline Coordenada Y da linha central da pauta
  /// @return Coordenada Y em pixels (sistema de coordenadas de tela)
  static double toPixelY(
    int staffPosition,
    double staffSpace,
    double staffBaseline,
  ) {
    // staffPosition positivo = acima do centro = Y menor (coordenadas de tela)
    // staffPosition negativo = abaixo do centro = Y maior
    // Cada posição = 0.5 staff spaces
    return staffBaseline - (staffPosition * staffSpace * 0.5);
  }

  /// Obtém referência de clave para cálculos
  static ClefReference _getClefReference(ClefType clefType) {
    switch (clefType) {
      // CLAVE DE SOL (G Clef)
      // G4 na segunda linha (linha 2 de baixo para cima)
      // A linha 2 está 1 linha ABAIXO da linha central (linha 3)
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

      // CLAVE DE FÁ (F Clef)
      // F3 na quarta linha (linha 4 de baixo para cima)
      // A linha 4 está 1 linha ACIMA da linha central (linha 3)
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

      // CLAVE DE DÓ (C Clef) - Alto
      // C4 na linha central (staffPosition 0)
      case ClefType.alto:
        return ClefReference(
          baseStep: 0, // C
          baseOctave: 4,
          basePosition: 0, // Linha central
        );

      // CLAVE DE DÓ (C Clef) - Tenor
      // C4 na quarta linha (staffPosition +2)
      case ClefType.tenor:
        return ClefReference(
          baseStep: 0, // C
          baseOctave: 4,
          basePosition: 2, // Quarta linha (acima da linha central)
        );

      // CLAVE DE PERCUSSÃO
      case ClefType.percussion:
      case ClefType.percussion2:
        return ClefReference(
          baseStep: 0,
          baseOctave: 4,
          basePosition: 0,
        );

      // CLAVE DE TABLATURA
      case ClefType.tab6:
      case ClefType.tab4:
        return ClefReference(
          baseStep: 0,
          baseOctave: 4,
          basePosition: 0,
        );

      default:
        // Fallback: Clave de Sol
        return ClefReference(
          baseStep: 4, // G
          baseOctave: 4,
          basePosition: -2, // CORREÇÃO: G4 na segunda linha é posição -2
        );
    }
  }
}

/// Dados de referência de uma clave
class ClefReference {
  /// Step (0-6) da nota que está na linha de referência
  final int baseStep;

  /// Oitava da nota de referência
  final int baseOctave;

  /// Posição na pauta da linha de referência
  final int basePosition;

  const ClefReference({
    required this.baseStep,
    required this.baseOctave,
    required this.basePosition,
  });
}

/// Extensão para facilitar uso em Pitch
extension PitchStaffPosition on Pitch {
  /// Calcula posição na pauta para uma clave
  int staffPosition(Clef clef) {
    return StaffPositionCalculator.calculate(this, clef);
  }

  /// Verifica se precisa de linhas suplementares
  bool needsLedgerLines(Clef clef) {
    final position = staffPosition(clef);
    return StaffPositionCalculator.needsLedgerLines(position);
  }

  /// Obtém linhas suplementares necessárias
  List<int> getLedgerLinePositions(Clef clef) {
    final position = staffPosition(clef);
    return StaffPositionCalculator.getLedgerLinePositions(position);
  }
}
