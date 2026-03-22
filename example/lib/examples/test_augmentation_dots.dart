// example/lib/examples/test_augmentation_dots.dart
// TESTE DE POSICIONAMENTO DE PONTOS DE AUMENTO

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget de teste para verificar se os pontos de aumento estão posicionados corretamente
class TestAugmentationDots extends StatelessWidget {
  const TestAugmentationDots({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TESTE: Pontos de Aumento'),
        backgroundColor: Colors.purple.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTestSection(
              title: 'Notas em LINHAS com Pontos',
              description: 'Pontos devem estar no ESPAÇO acima da linha',
              elements: [
                Clef(clefType: ClefType.treble),
                // G4 está na linha 2 (staffPos = -2)
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half, dots: 1),
                ),
                // B4 está na linha 3 central (staffPos = 0)
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.half, dots: 2),
                ),
                // D5 está na linha 4 (staffPos = 2)
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
                // F5 está na linha 5 superior (staffPos = 4)
                Note(
                  pitch: const Pitch(step: 'F', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
              ],
            ),
            _buildTestSection(
              title: 'Notas em ESPAÇOS com Pontos',
              description: 'Pontos devem estar no MESMO espaço da nota',
              elements: [
                Clef(clefType: ClefType.treble),
                // F4 está no espaço 1 (abaixo da linha 2, staffPos = -3)
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.half, dots: 1),
                ),
                // A4 está no espaço 2 (abaixo da linha 3, staffPos = -1)
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.half, dots: 2),
                ),
                // C5 está no espaço 3 (acima da linha 3, staffPos = 1)
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
                // E5 está no espaço 4 (abaixo da linha 5, staffPos = 3)
                Note(
                  pitch: const Pitch(step: 'E', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
              ],
            ),
            _buildTestSection(
              title: 'Clave de Fá - Notas em Linhas',
              description: 'Pontos devem estar no espaço acima',
              elements: [
                Clef(clefType: ClefType.bass),
                // F3 está na linha 4 (onde fica o símbolo da clave, staffPos = 2)
                Note(
                  pitch: const Pitch(step: 'F', octave: 3),
                  duration: const Duration(DurationType.half, dots: 1),
                ),
                // A3 está na linha 5 SUPERIOR (staffPos = 4, COM linha suplementar!)
                Note(
                  pitch: const Pitch(step: 'A', octave: 3),
                  duration: const Duration(DurationType.half, dots: 2),
                ),
                // C4 está ACIMA do pentagrama com linha suplementar (staffPos = 6)
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
              ],
            ),
            _buildReferenceGuide(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection({
    required String title,
    required String description,
    required List<MusicalElement> elements,
  }) {
    final staff = Staff();
    final measure = Measure();
    for (final element in elements) {
      measure.add(element);
    }
    staff.add(measure);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.purple, width: 2),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: MusicScore(staff: staff),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceGuide() {
    return Card(
      elevation: 4.0,
      color: Colors.purple.shade50,
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📏 REGRAS DE POSICIONAMENTO',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pontos de Aumento:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...[
              '✓ Se a nota está em uma LINHA: ponto vai no ESPAÇO acima',
              '✓ Se a nota está em um ESPAÇO: ponto vai no MESMO espaço',
              '✓ Múltiplos pontos: espaçamento horizontal de 0.7 staff spaces',
              '✓ Distância da nota: ~1.2 staff spaces à direita',
            ].map((text) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
