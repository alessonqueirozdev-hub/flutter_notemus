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
        title: const Text('TESTE: Augmentation Dots'),
        backgroundColor: Colors.purple.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTestSection(
              title: 'Notes in LINES with Dots',
              description: 'Points must be in the SPACE above the line',
              elements: [
                Clef(clefType: ClefType.treble),
                // G4 is on line 2 (staffPos = -2)
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half, dots: 1),
                ),
                // B4 is on center line 3 (staffPos = 0)
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.half, dots: 2),
                ),
                // D5 is on line 4 (staffPos = 2)
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
                // F5 is in the top 5 row (staffPos = 4)
                Note(
                  pitch: const Pitch(step: 'F', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
              ],
            ),
            _buildTestSection(
              title: 'Notes in SPACES with Points',
              description: 'Points must be in the SAME space as the note',
              elements: [
                Clef(clefType: ClefType.treble),
                // F4 is in space 1 (below line 2, staffPos = -3)
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.half, dots: 1),
                ),
                // A4 is in space 2 (below line 3, staffPos = -1)
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.half, dots: 2),
                ),
                // C5 is in space 3 (above line 3, staffPos = 1)
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
                // E5 is in space 4 (below line 5, staffPos = 3)
                Note(
                  pitch: const Pitch(step: 'E', octave: 5),
                  duration: const Duration(DurationType.quarter, dots: 1),
                ),
              ],
            ),
            _buildTestSection(
              title: 'Bass Clef - Notes in Lines',
              description: 'Dots must be in the space above',
              elements: [
                Clef(clefType: ClefType.bass),
                // F3 is on line 4 (where the clef symbol is, staffPos = 2)
                Note(
                  pitch: const Pitch(step: 'F', octave: 3),
                  duration: const Duration(DurationType.half, dots: 1),
                ),
                // A3 is on TOP 5 line (staffPos = 4, WITH supplementary line!)
                Note(
                  pitch: const Pitch(step: 'A', octave: 3),
                  duration: const Duration(DurationType.half, dots: 2),
                ),
                // C4 is ABOVE the staff with supplementary line (staffPos = 6)
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
              'Augmentation Dots:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...[
              '✓ If the note is on a LINE: point goes in the SPACE above',
              '✓ If the note is in a SPACE: point goes in the SAME space',
              '✓ Múltiplos pontos: espaçamento horizontal de 0.7 staff spaces',
              '✓ Note distance: ~1.2 staff spaces on the right',
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
