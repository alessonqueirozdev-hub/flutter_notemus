// test/staff_position_calculator_test.dart
// TESTES DE VALIDAÇÃO: Sistema de Coordenadas SMuFL
//
// Estes testes validam a correção crítica do sistema de coordenadas
// documentada em CORRECOES_CRITICAS_APLICADAS.md

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('StaffPositionCalculator - Clave de Sol (Treble Clef)', () {
    final trebleClef = Clef(clefType: ClefType.treble);

    test('G4 deve estar na 2ª linha (staffPosition = -2)', () {
      final pitch = Pitch(step: 'G', octave: 4);
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);
      
      expect(position, equals(-2),
        reason: 'G4 é a nota de referência da clave de Sol, deve estar na 2ª linha');
    });

    test('C5 (Dó central) deve estar acima da pauta (staffPosition > 4)', () {
      final pitch = Pitch(step: 'C', octave: 5);
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);
      
      expect(position, greaterThan(4),
        reason: 'C5 está acima das 5 linhas do pentagrama em clave de Sol');
    });

    test('E4 deve estar na 1ª linha (staffPosition = -4)', () {
      final pitch = Pitch(step: 'E', octave: 4);
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);
      
      expect(position, equals(-4),
        reason: 'E4 é a nota mais grave dentro do pentagrama em clave de Sol');
    });

    test('F5 deve estar na 5ª linha (staffPosition = 4)', () {
      final pitch = Pitch(step: 'F', octave: 5);
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);
      
      expect(position, equals(4),
        reason: 'F5 é a nota mais aguda dentro do pentagrama em clave de Sol');
    });

    test('Escala ascendente C4-C5 deve ter posições monotonicamente crescentes', () {
      final scale = [
        Pitch(step: 'C', octave: 4),
        Pitch(step: 'D', octave: 4),
        Pitch(step: 'E', octave: 4),
        Pitch(step: 'F', octave: 4),
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'A', octave: 4),
        Pitch(step: 'B', octave: 4),
        Pitch(step: 'C', octave: 5),
      ];

      final positions = scale
        .map((p) => StaffPositionCalculator.calculate(p, trebleClef))
        .toList();

      for (int i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]),
          reason: 'Nota ${scale[i].step}${scale[i].octave} deve estar acima de '
                  '${scale[i-1].step}${scale[i-1].octave}');
      }
    });

    test('Notas em linhas suplementares inferiores devem ter staffPosition < -4', () {
      final pitch = Pitch(step: 'C', octave: 4); // Dó abaixo da pauta
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);
      
      expect(position, lessThan(-4),
        reason: 'C4 está abaixo do pentagrama e precisa de linhas suplementares');
    });

    test('Notas em linhas suplementares superiores devem ter staffPosition > 4', () {
      final pitch = Pitch(step: 'A', octave: 5); // Lá acima da pauta
      final position = StaffPositionCalculator.calculate(pitch, trebleClef);
      
      expect(position, greaterThan(4),
        reason: 'A5 está acima do pentagrama e precisa de linhas suplementares');
    });
  });

  group('StaffPositionCalculator - Clave de Fá (Bass Clef)', () {
    final bassClef = Clef(clefType: ClefType.bass);

    test('F3 deve estar na 4ª linha (staffPosition = 2)', () {
      final pitch = Pitch(step: 'F', octave: 3);
      final position = StaffPositionCalculator.calculate(pitch, bassClef);
      
      expect(position, equals(2),
        reason: 'F3 é a nota de referência da clave de Fá, deve estar na 4ª linha');
    });

    test('G2 deve estar na 1ª linha (staffPosition = -4)', () {
      final pitch = Pitch(step: 'G', octave: 2);
      final position = StaffPositionCalculator.calculate(pitch, bassClef);
      
      expect(position, equals(-4),
        reason: 'G2 é a nota mais grave dentro do pentagrama em clave de Fá');
    });

    test('A3 deve estar na 5ª linha (staffPosition = 4)', () {
      final pitch = Pitch(step: 'A', octave: 3);
      final position = StaffPositionCalculator.calculate(pitch, bassClef);
      
      expect(position, equals(4),
        reason: 'A3 é a nota mais aguda dentro do pentagrama em clave de Fá');
    });

    test('Escala ascendente G2-G3 deve ter posições crescentes', () {
      final scale = [
        Pitch(step: 'G', octave: 2),
        Pitch(step: 'A', octave: 2),
        Pitch(step: 'B', octave: 2),
        Pitch(step: 'C', octave: 3),
        Pitch(step: 'D', octave: 3),
        Pitch(step: 'E', octave: 3),
        Pitch(step: 'F', octave: 3),
        Pitch(step: 'G', octave: 3),
      ];

      final positions = scale
        .map((p) => StaffPositionCalculator.calculate(p, bassClef))
        .toList();

      for (int i = 1; i < positions.length; i++) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
    });
  });

  group('StaffPositionCalculator - Clave de Dó (C Clefs)', () {
    test('C4 em clave de Alto deve estar no centro (staffPosition = 0)', () {
      final altoClef = Clef(clefType: ClefType.alto);
      final pitch = Pitch(step: 'C', octave: 4);
      final position = StaffPositionCalculator.calculate(pitch, altoClef);
      
      expect(position, equals(0),
        reason: 'C4 é a nota de referência da clave de Alto, na linha central');
    });

    test('C4 em clave de Tenor deve estar na 4ª linha (staffPosition = 2)', () {
      final tenorClef = Clef(clefType: ClefType.tenor);
      final pitch = Pitch(step: 'C', octave: 4);
      final position = StaffPositionCalculator.calculate(pitch, tenorClef);
      
      expect(position, equals(2),
        reason: 'C4 é a nota de referência da clave de Tenor, na 4ª linha');
    });
  });

  group('StaffPositionCalculator - Linhas Suplementares', () {
    test('needsLedgerLines deve retornar false para notas dentro do pentagrama', () {
      expect(StaffPositionCalculator.needsLedgerLines(0), isFalse);
      expect(StaffPositionCalculator.needsLedgerLines(2), isFalse);
      expect(StaffPositionCalculator.needsLedgerLines(-2), isFalse);
      expect(StaffPositionCalculator.needsLedgerLines(4), isFalse);
      expect(StaffPositionCalculator.needsLedgerLines(-4), isFalse);
    });

    test('needsLedgerLines deve retornar true para notas fora do pentagrama', () {
      expect(StaffPositionCalculator.needsLedgerLines(5), isTrue);
      expect(StaffPositionCalculator.needsLedgerLines(6), isTrue);
      expect(StaffPositionCalculator.needsLedgerLines(-5), isTrue);
      expect(StaffPositionCalculator.needsLedgerLines(-6), isTrue);
    });

    test('getLedgerLinePositions deve calcular linhas corretamente acima', () {
      final lines = StaffPositionCalculator.getLedgerLinePositions(8);
      expect(lines, equals([6, 8]));
    });

    test('getLedgerLinePositions deve calcular linhas corretamente abaixo', () {
      final lines = StaffPositionCalculator.getLedgerLinePositions(-8);
      expect(lines, equals([-6, -8]));
    });

    test('getLedgerLinePositions deve incluir linha da própria nota se par', () {
      final lines = StaffPositionCalculator.getLedgerLinePositions(6);
      expect(lines.contains(6), isTrue);
    });

    test('getLedgerLinePositions deve retornar vazio para notas no pentagrama', () {
      final lines = StaffPositionCalculator.getLedgerLinePositions(2);
      expect(lines, isEmpty);
    });
  });

  group('StaffPositionCalculator - Conversão para Pixels', () {
    test('toPixelY deve calcular Y correto para staffPosition positivo', () {
      final staffSpace = 10.0;
      final staffBaseline = 100.0;
      
      // staffPosition = 2 (1 staff space acima do centro)
      final y = StaffPositionCalculator.toPixelY(2, staffSpace, staffBaseline);
      
      expect(y, equals(90.0),
        reason: 'staffPosition positivo deve resultar em Y menor (acima)');
    });

    test('toPixelY deve calcular Y correto para staffPosition negativo', () {
      final staffSpace = 10.0;
      final staffBaseline = 100.0;
      
      // staffPosition = -2 (1 staff space abaixo do centro)
      final y = StaffPositionCalculator.toPixelY(-2, staffSpace, staffBaseline);
      
      expect(y, equals(110.0),
        reason: 'staffPosition negativo deve resultar em Y maior (abaixo)');
    });

    test('toPixelY deve retornar baseline para staffPosition = 0', () {
      final staffSpace = 10.0;
      final staffBaseline = 100.0;
      
      final y = StaffPositionCalculator.toPixelY(0, staffSpace, staffBaseline);
      
      expect(y, equals(100.0),
        reason: 'staffPosition zero deve estar exatamente no baseline');
    });
  });

  group('StaffPositionCalculator - Extensão Pitch', () {
    test('Extensão staffPosition deve funcionar', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final pitch = Pitch(step: 'G', octave: 4);
      
      final position = pitch.staffPosition(trebleClef);
      
      expect(position, equals(-2));
    });

    test('Extensão needsLedgerLines deve funcionar', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final pitch = Pitch(step: 'C', octave: 5);
      
      final needs = pitch.needsLedgerLines(trebleClef);
      
      expect(needs, isTrue);
    });

    test('Extensão getLedgerLinePositions deve funcionar', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      final pitch = Pitch(step: 'C', octave: 5);
      
      final lines = pitch.getLedgerLinePositions(trebleClef);
      
      expect(lines, isNotEmpty);
    });
  });

  group('StaffPositionCalculator - Validação da Correção de Outubro', () {
    // TESTE CRÍTICO: Valida que a "correção emergencial" de 01/10/2025
    // (documentada em CORRECOES_CRITICAS_APLICADAS.md) está correta
    
    test('VALIDAÇÃO: Fórmula não deve inverter posições (soma, não subtração)', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      
      // Se a fórmula estivesse usando subtração (bug original),
      // notas mais agudas teriam staffPosition MENOR
      final c4 = Pitch(step: 'C', octave: 4).staffPosition(trebleClef);
      final c5 = Pitch(step: 'C', octave: 5).staffPosition(trebleClef);
      
      expect(c5, greaterThan(c4),
        reason: 'CRÍTICO: C5 DEVE estar acima de C4. '
                'Se este teste falhar, o sistema de coordenadas está invertido!');
    });

    test('VALIDAÇÃO: Direção das hastes deve ser consistente com staffPosition', () {
      final trebleClef = Clef(clefType: ClefType.treble);
      
      // Em clave de Sol, notas abaixo do centro têm haste para cima
      // staffPosition negativo = abaixo do centro = haste up
      final e4Pos = Pitch(step: 'E', octave: 4).staffPosition(trebleClef);
      expect(e4Pos, lessThan(0),
        reason: 'E4 deve estar abaixo do centro (staffPosition < 0) = haste up');
      
      // Notas acima do centro têm haste para baixo
      // staffPosition positivo = acima do centro = haste down
      final b4Pos = Pitch(step: 'B', octave: 4).staffPosition(trebleClef);
      expect(b4Pos, greaterThan(0),
        reason: 'B4 deve estar acima do centro (staffPosition > 0) = haste down');
    });
  });
}
