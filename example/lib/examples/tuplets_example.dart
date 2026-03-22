// example/lib/examples/tuplets_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget que demonstra a renderização de quiálteras (tuplets)
class TupletsExample extends StatelessWidget {
  const TupletsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Quiálteras (Tuplets)'),
        backgroundColor: Colors.indigo.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Tercina Simples (3:2)',
              description: 'Três colcheias no lugar de duas - a quiáltera mais comum.',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 3,
                  normalNotes: 2,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'C', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'D', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'E', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                  ],
                  showBracket: true,
                  showNumber: true,
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Quinta (5:4)',
              description: 'Cinco semicolcheias no lugar de quatro.',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 5,
                  normalNotes: 4,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'F', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'A', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'B', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'C', octave: 5),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                  ],
                  showBracket: true,
                  showNumber: true,
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Sextina (6:4)',
              description: 'Seis semicolcheias no lugar de quatro.',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 6,
                  normalNotes: 4,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'C', octave: 5),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'B', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'A', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'F', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'E', octave: 4),
                      duration: const Duration(DurationType.sixteenth),
                    ),
                  ],
                  showBracket: true,
                  showNumber: true,
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Septina (7:4)',
              description: 'Sete fusas no lugar de quatro.',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 7,
                  normalNotes: 4,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'D', octave: 4),
                      duration: const Duration(DurationType.thirtySecond),
                    ),
                    Note(
                      pitch: const Pitch(step: 'E', octave: 4),
                      duration: const Duration(DurationType.thirtySecond),
                    ),
                    Note(
                      pitch: const Pitch(step: 'F', octave: 4),
                      duration: const Duration(DurationType.thirtySecond),
                    ),
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.thirtySecond),
                    ),
                    Note(
                      pitch: const Pitch(step: 'A', octave: 4),
                      duration: const Duration(DurationType.thirtySecond),
                    ),
                    Note(
                      pitch: const Pitch(step: 'B', octave: 4),
                      duration: const Duration(DurationType.thirtySecond),
                    ),
                    Note(
                      pitch: const Pitch(step: 'C', octave: 5),
                      duration: const Duration(DurationType.thirtySecond),
                    ),
                  ],
                  showBracket: true,
                  showNumber: true,
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Tercina com Pausas',
              description: 'Tercina incluindo pausas no agrupamento.',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 3,
                  normalNotes: 2,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                    Rest(duration: const Duration(DurationType.eighth)),
                    Note(
                      pitch: const Pitch(step: 'B', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                  ],
                  showBracket: true,
                  showNumber: true,
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Tercina Sem Suporte',
              description: 'Tercina mostrando apenas o número, sem linha de suporte.',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 3,
                  normalNotes: 2,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'E', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'F', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                  ],
                  showBracket: false,
                  showNumber: true,
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Duína (2:3)',
              description: 'Duas colcheias no lugar de três - quiáltera invertida.',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 2,
                  normalNotes: 3,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'A', octave: 4),
                      duration: const Duration(DurationType.eighth),
                    ),
                    Note(
                      pitch: const Pitch(step: 'C', octave: 5),
                      duration: const Duration(DurationType.eighth),
                    ),
                  ],
                  showBracket: true,
                  showNumber: true,
                ),
                Rest(duration: const Duration(DurationType.half)),
              ],
            ),
            _buildSection(
              title: 'Quiáltera de Semínimas',
              description: 'Tercina de semínimas (durações mais longas).',
              elements: [
                Clef(clefType: ClefType.treble),
                Tuplet(
                  actualNotes: 3,
                  normalNotes: 2,
                  elements: [
                    Note(
                      pitch: const Pitch(step: 'F', octave: 4),
                      duration: const Duration(DurationType.quarter),
                    ),
                    Note(
                      pitch: const Pitch(step: 'A', octave: 4),
                      duration: const Duration(DurationType.quarter),
                    ),
                    Note(
                      pitch: const Pitch(step: 'C', octave: 5),
                      duration: const Duration(DurationType.quarter),
                    ),
                  ],
                  showBracket: true,
                  showNumber: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
