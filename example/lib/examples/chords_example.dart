// example/lib/examples/chords_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// A page widget that demonstrates chord rendering.
class ChordsExample extends StatelessWidget {
  const ChordsExample({super.key});

  @override
  Widget build(BuildContext context) {
    // 3-Note Chords (Triads)
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

    // 4 note chords (Tetrades)
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

    // Chords with 5 notes and with seconds (to test collisions)
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
        title: const Text('Symbol Family: Chords'),
        backgroundColor: Colors.indigo.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: '3-Note Chords (Triads)',
              description:
                  'Displays basic 3-note chords. Check that the rod is the correct size (factor 4.5).',
              elements: triadElements,
            ),
            _buildSection(
              title: '4-Note Chords (Tetrads)',
              description:
                  'Displays 4-note chords. The stem should be noticeably longer (factor 5.5).',
              elements: tetradElements,
            ),
            _buildSection(
              title: 'Complex Chords',
              description:
                  'Displays chords with 5 notes (even longer stem, factor 6.5) and chords with seconds to test the horizontal displacement of the note heads.',
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
