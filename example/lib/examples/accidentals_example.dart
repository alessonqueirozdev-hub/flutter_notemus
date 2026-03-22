// example/lib/examples/accidentals_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Um widget de página que demonstra a renderização dos acidentes musicais.
class AccidentalsExample extends StatelessWidget {
  const AccidentalsExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Cria uma lista de elementos musicais para demonstrar cada acidente
    final List<MusicalElement> accidentalElements = [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: Pitch.withAccidental(
            step: 'F', octave: 4, accidentalType: AccidentalType.sharp),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: Pitch.withAccidental(
            step: 'B', octave: 4, accidentalType: AccidentalType.flat),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: Pitch.withAccidental(
            step: 'G', octave: 4, accidentalType: AccidentalType.natural),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: Pitch.withAccidental(
            step: 'C', octave: 5, accidentalType: AccidentalType.doubleSharp),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: Pitch.withAccidental(
            step: 'E', octave: 4, accidentalType: AccidentalType.doubleFlat),
        duration: const Duration(DurationType.quarter),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Acidentes'),
        backgroundColor: Colors.purple.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Acidentes Musicais',
              description:
                  'Exibe os acidentes mais comuns: sustenido, bemol, bequadro, dobrado sustenido e dobrado bemol. Verifique o alinhamento de cada acidente à esquerda da cabeça da nota.',
              elements: accidentalElements,
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
