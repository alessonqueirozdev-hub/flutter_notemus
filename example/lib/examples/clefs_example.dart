// example/lib/examples/clefs_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// A page widget that demonstrates the rendering of all available clefs.
class ClefsExample extends StatelessWidget {
  const ClefsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Clefs'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildClefSection(
              title: 'Treble clef',
              description:
                  'The central spiral of the G-clef defines the position of the G note (G4) on the second line of the staff.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
              title: 'Bass clef',
              description:
                  'The two dots of the bass clef (F-clef) surround the fourth line of the staff, defining it as the position of the F note (F3).',
              elements: [
                Clef(clefType: ClefType.bass),
                Note(
                    pitch: const Pitch(step: 'F', octave: 3),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
            title: 'C Clef (Alto)',
              description:
                  'The center of the C clef (C-clef) on the third line defines this as the position of middle C (C4). It is commonly used for the viola.',
              elements: [
                Clef(clefType: ClefType.alto),
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
              title: 'Clef of C (Tenor)',
              description:
                  'When in the fourth line, the C clef defines this as the position of middle C (C4). It is used for instruments such as the cello and trombone in high registers.',
              elements: [
                Clef(clefType: ClefType.tenor),
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildClefSection(
              title: 'Octave Clefs (8va and 8vb)',
              description:
                  'These keys indicate that the music should be played an octave higher (8va) or lower (8vb) than what is written.',
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

  /// Builds a test section for a clef type.
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
