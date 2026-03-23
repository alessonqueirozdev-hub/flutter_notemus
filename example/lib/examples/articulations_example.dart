// example/lib/examples/articulations_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// A page widget that demonstrates the rendering of articulation signals.
class ArticulationsExample extends StatelessWidget {
  const ArticulationsExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Notes with stem UP (joint DOWN)
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

    // Notes with stem DOWN (joint UP)
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
        title: const Text('Symbol Family: Articulations'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Articulations (Stems Down)',
              description:
                  'Displays staccato, accent, tenuto and Marcato on notes with stem down. The articulation must appear ABOVE the note head.',
              elements: stemsDownElements,
            ),
            _buildSection(
              title: 'Articulations (Stems Up)',
              description:
                  'Displays the same articulations on stem-up notes. The articulation should appear BELOW the note head.',
              elements: stemsUpElements,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a test section.
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
