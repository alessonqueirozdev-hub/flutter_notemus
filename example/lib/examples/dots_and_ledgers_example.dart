// example/lib/examples/dots_and_ledgers_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Um widget de página que demonstra a renderização de pontos de aumento e linhas suplementares.
class DotsAndLedgersExample extends StatelessWidget {
  const DotsAndLedgersExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Elementos para demonstrar pontos de aumento
    final List<MusicalElement> dottedNotesElements = [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.half, dots: 1),
      ),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.quarter, dots: 2),
      ),
      Note(
        pitch: const Pitch(step: 'F', octave: 4),
        duration: const Duration(DurationType.quarter, dots: 1),
      ),
    ];

    // Elementos para demonstrar linhas suplementares
    final List<MusicalElement> ledgerLinesElements = [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'A', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: const Pitch(step: 'C', octave: 6),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: const Pitch(step: 'E', octave: 6),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: const Pitch(step: 'C', octave: 4),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: const Pitch(step: 'A', octave: 3),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: const Pitch(step: 'F', octave: 3),
        duration: const Duration(DurationType.quarter),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Família: Pontos e Linhas Suplementares'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Pontos de Aumento',
              description:
                  'Exibe notas com um e dois pontos de aumento. Verifique a distância do(s) ponto(s) em relação à cabeça da nota e o alinhamento (ao lado da cabeça em espaços, acima da linha em linhas).',
              elements: dottedNotesElements,
            ),
            _buildSection(
              title: 'Linhas Suplementares (Ledger Lines)',
              description:
                  'Exibe notas que requerem linhas suplementares acima e abaixo da pauta. Verifique a espessura e a extensão horizontal das linhas.',
              elements: ledgerLinesElements,
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
