// example/lib/examples/clefs_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Um widget de página que demonstra a renderização de todas as claves disponíveis.
class ClefsExample extends StatelessWidget {
  const ClefsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Claves'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildClefSection(
              title: 'Clave de Sol',
              description:
                  'A espiral central da clave de Sol (G-clef) define a posição da nota Sol (G4) na segunda linha da pauta.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
              title: 'Clave de Fá',
              description:
                  'Os dois pontos da clave de Fá (F-clef) envolvem a quarta linha da pauta, definindo-a como a posição da nota Fá (F3).',
              elements: [
                Clef(clefType: ClefType.bass),
                Note(
                    pitch: const Pitch(step: 'F', octave: 3),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
              title: 'Clave de Dó (Contralto)',
              description:
                  'O centro da clave de Dó (C-clef) na terceira linha define esta como a posição do Dó central (C4). É comumente usada para a viola.',
              elements: [
                Clef(clefType: ClefType.alto),
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
              title: 'Clave de Dó (Tenor)',
              description:
                  'Quando na quarta linha, a clave de Dó define esta como a posição do Dó central (C4). É usada para instrumentos como o violoncelo e o trombone em registros agudos.',
              elements: [
                Clef(clefType: ClefType.tenor),
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
              title: 'Claves de Oitava (8va e 8vb)',
              description:
                  'Estas claves indicam que a música deve ser tocada uma oitava acima (8va) ou abaixo (8vb) do que está escrito.',
              elements: [
                Clef(clefType: ClefType.treble8va),
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.quarter)),
                Clef(clefType: ClefType.treble8vb),
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.quarter)),
                Clef(clefType: ClefType.bass8va),
                Note(
                    pitch: const Pitch(step: 'F', octave: 3),
                    duration: const Duration(DurationType.quarter)),
                Clef(clefType: ClefType.bass8vb),
                Note(
                    pitch: const Pitch(step: 'F', octave: 3),
                    duration: const Duration(DurationType.quarter)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói uma seção de teste para um tipo de clave.
  Widget _buildClefSection({
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
