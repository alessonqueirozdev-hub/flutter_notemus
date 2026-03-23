// example/lib/examples/dots_and_ledgers_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// A page widget that demonstrates the rendering of augmentation points and supplementary lines.
class DotsAndLedgersExample extends StatelessWidget {
  const DotsAndLedgersExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Elements to demonstrate augmentation dots
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

    // Elements to demonstrate supplementary lines
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
        title: const Text('Family: Supplementary Points and Lines'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Augmentation Dots',
              description:
                  'Displays notes with one and two increments. Check the distance of the dot(s) from the note head and the alignment (next to the head in spaces, above the line in lines).',
              elements: dottedNotesElements,
            ),
            _buildSection(
              title: 'Supplementary Lines (Ledger Lines)',
              description:
                  'Displays notes that require supplementary lines above and below the staff. Check the thickness and horizontal extension of the lines.',
              elements: ledgerLinesElements,
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
