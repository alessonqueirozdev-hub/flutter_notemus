// example/lib/examples/chords_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Um widget de página que demonstra a renderização de acordes.
class ChordsExample extends StatelessWidget {
  const ChordsExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Acordes de 3 notas (Tríades)
    final List<MusicalElement> triadElements = [
      Clef(clefType: ClefType.treble),
      Chord(
        notes: [
          Note(
              pitch: const Pitch(step: 'C', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'E', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'G', octave: 4),
              duration: const Duration(DurationType.quarter)),
        ],
        duration: const Duration(DurationType.quarter),
      ),
      Chord(
        notes: [
          Note(
              pitch: const Pitch(step: 'A', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.quarter)),
        ],
        duration: const Duration(DurationType.quarter),
      ),
    ];

    // Acordes de 4 notas (Tétrades)
    final List<MusicalElement> tetradElements = [
      Clef(clefType: ClefType.treble),
      Chord(
        notes: [
          Note(
              pitch: const Pitch(step: 'C', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'E', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'G', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'B', octave: 4),
              duration: const Duration(DurationType.quarter)),
        ],
        duration: const Duration(DurationType.quarter),
      ),
      Chord(
        notes: [
          Note(
              pitch: const Pitch(step: 'G', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'B', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'F', octave: 5),
              duration: const Duration(DurationType.quarter)),
        ],
        duration: const Duration(DurationType.quarter),
      ),
    ];

    // Acordes com 5 notas e com segundas (para testar colisões)
    final List<MusicalElement> complexChordElements = [
      Clef(clefType: ClefType.treble),
      Chord(
        notes: [
          Note(
              pitch: const Pitch(step: 'C', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'E', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'G', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'B', octave: 4),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter)),
        ],
        duration: const Duration(DurationType.quarter),
      ),
      Chord(
        notes: [
          Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter)),
          Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.quarter)),
        ],
        duration: const Duration(DurationType.quarter),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Acordes'),
        backgroundColor: Colors.indigo.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Acordes de 3 Notas (Tríades)',
              description:
                  'Exibe acordes básicos de 3 notas. Verifique se a haste tem o tamanho correto (fator 4.5).',
              elements: triadElements,
            ),
            _buildSection(
              title: 'Acordes de 4 Notas (Tétrades)',
              description:
                  'Exibe acordes com 4 notas. A haste deve ser visivelmente mais longa (fator 5.5).',
              elements: tetradElements,
            ),
            _buildSection(
              title: 'Acordes Complexos',
              description:
                  'Exibe acordes com 5 notas (haste ainda mais longa, fator 6.5) e acordes com segundas para testar o deslocamento horizontal das cabeças de nota.',
              elements: complexChordElements,
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
