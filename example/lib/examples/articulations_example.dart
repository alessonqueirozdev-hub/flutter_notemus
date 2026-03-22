// example/lib/examples/articulations_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Um widget de página que demonstra a renderização dos sinais de articulação.
class ArticulationsExample extends StatelessWidget {
  const ArticulationsExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Notas com haste para CIMA (articulação ABAIXO)
    final List<MusicalElement> stemsUpElements = [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.staccato],
      ),
      Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.accent],
      ),
      Note(
        pitch: const Pitch(step: 'F', octave: 4),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.tenuto],
      ),
      Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.marcato],
      ),
    ];

    // Notas com haste para BAIXO (articulação ACIMA)
    final List<MusicalElement> stemsDownElements = [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.staccato],
      ),
      Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.accent],
      ),
      Note(
        pitch: const Pitch(step: 'E', octave: 5),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.tenuto],
      ),
      Note(
        pitch: const Pitch(step: 'F', octave: 5),
        duration: const Duration(DurationType.quarter),
        articulations: const [ArticulationType.marcato],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Articulações'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Articulações (Hastes para Baixo)',
              description:
                  'Exibe staccato, accent, tenuto e marcato em notas com haste para baixo. A articulação deve aparecer ACIMA da cabeça da nota.',
              elements: stemsDownElements,
            ),
            _buildSection(
              title: 'Articulações (Hastes para Cima)',
              description:
                  'Exibe as mesmas articulações em notas com haste para cima. A articulação deve aparecer ABAIXO da cabeça da nota.',
              elements: stemsUpElements,
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói uma seção de teste.
  Widget _buildSection({
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: MusicScore(
                staff: staff,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
