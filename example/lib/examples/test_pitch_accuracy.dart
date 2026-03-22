// example/lib/examples/test_pitch_accuracy.dart
// TESTE DE PRECISÃO DE ALTURAS DAS NOTAS

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget de teste para verificar se as notas estão nas alturas corretas
class TestPitchAccuracy extends StatelessWidget {
  const TestPitchAccuracy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TESTE: Precisão de Alturas'),
        backgroundColor: Colors.red.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTestSection(
              title: 'CLAVE DE SOL - Escala Diatônica',
              description: 'G4 DEVE estar na 2ª linha (de baixo para cima)',
              elements: [
                Clef(clefType: ClefType.treble),
                // Começar com G4 que deve estar na 2ª linha
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'B', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'C', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'D', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'E', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'F', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'G', octave: 5),
                    duration: const Duration(DurationType.whole)),
                // Adicionar nota que precisa de linha suplementar
                Note(
                    pitch: const Pitch(step: 'A', octave: 5),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildReferenceGuide(),
            _buildTestSection(
              title: 'CLAVE DE FÁ - Nota de Referência',
              description: 'F3 DEVE estar na 4ª linha',
              elements: [
                Clef(clefType: ClefType.bass),
                // Começar com F3 que deve estar na 4ª linha
                Note(
                    pitch: const Pitch(step: 'F', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'G', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'A', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'B', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
                // Adicionar nota que precisa de linha suplementar inferior
                Note(
                    pitch: const Pitch(step: 'C', octave: 3),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildTestSection(
              title: 'CLAVE DE DÓ (ALTO) - Nota de Referência',
              description: 'C4 DEVE estar na 3ª linha (meio)',
              elements: [
                Clef(clefType: ClefType.alto),
                // Começar com C4 que deve estar na linha central
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'D', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'E', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'F', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.whole)),
                // Adicionar nota que precisa de linha suplementar superior
                Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
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
                color: Colors.red,
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
                border: Border.all(color: Colors.red, width: 2),
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
      color: Colors.yellow.shade100,
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📏 GUIA DE REFERÊNCIA - CLAVE DE SOL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Posições esperadas (de baixo para cima):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...[
              'Linha 1: E4',
              'Espaço 1: F4',
              'Linha 2: G4 ⭐ (NOTA DE REFERÊNCIA DA CLAVE)',
              'Espaço 2: A4',
              'Linha 3: B4 (meio da pauta)',
              'Espaço 3: C5',
              'Linha 4: D5',
              'Espaço 4: E5',
              'Linha 5: F5',
            ].map((text) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      color: text.contains('⭐')
                          ? Colors.red.shade700
                          : Colors.black87,
                      fontWeight: text.contains('⭐')
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
