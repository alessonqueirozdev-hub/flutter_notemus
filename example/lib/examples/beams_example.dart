// example/lib/examples/beams_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// A page widget that demonstrates the rendering of beams.
class BeamsExample extends StatelessWidget {
  const BeamsExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Grupo de Eighth Notes (Eighth notes) - 1 barra
    final List<MusicalElement> eighthNoteBeams = [
      Clef(clefType: ClefType.treble),
      Note(
          pitch: const Pitch(step: 'G', octave: 4),
          duration: const Duration(DurationType.eighth),
          beam: BeamType.start),
      Note(
          pitch: const Pitch(step: 'A', octave: 4),
          duration: const Duration(DurationType.eighth)),
      Note(
          pitch: const Pitch(step: 'B', octave: 4),
          duration: const Duration(DurationType.eighth)),
      Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.eighth),
          beam: BeamType.end),
    ];

    // Group of sixteenth notes - 2 beams
    final List<MusicalElement> sixteenthNoteBeams = [
      Clef(clefType: ClefType.treble),
      Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.sixteenth),
          beam: BeamType.start),
      Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const Duration(DurationType.sixteenth)),
      Note(
          pitch: const Pitch(step: 'E', octave: 5),
          duration: const Duration(DurationType.sixteenth)),
      Note(
          pitch: const Pitch(step: 'F', octave: 5),
          duration: const Duration(DurationType.sixteenth),
          beam: BeamType.end),
    ];

    // Group of thirty-second notes - 3 beams
    final List<MusicalElement> thirtySecondNoteBeams = [
      Clef(clefType: ClefType.treble),
      Note(
          pitch: const Pitch(step: 'F', octave: 4),
          duration: const Duration(DurationType.thirtySecond),
          beam: BeamType.start),
      Note(
          pitch: const Pitch(step: 'G', octave: 4),
          duration: const Duration(DurationType.thirtySecond)),
      Note(
          pitch: const Pitch(step: 'A', octave: 4),
          duration: const Duration(DurationType.thirtySecond)),
      Note(
          pitch: const Pitch(step: 'B', octave: 4),
          duration: const Duration(DurationType.thirtySecond),
          beam: BeamType.end),
    ];

    // Grupo de Sixty-fourth Notes (64th notes) - 4 barras
    final List<MusicalElement> sixtyFourthNoteBeams = [
      Clef(clefType: ClefType.treble),
      Note(
          pitch: const Pitch(step: 'A', octave: 4),
          duration: const Duration(DurationType.sixtyFourth),
          beam: BeamType.start),
      Note(
          pitch: const Pitch(step: 'B', octave: 4),
          duration: const Duration(DurationType.sixtyFourth)),
      Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.sixtyFourth)),
      Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const Duration(DurationType.sixtyFourth),
          beam: BeamType.end),
    ];

    // Grupo Misto
    final List<MusicalElement> mixedBeams = [
      Clef(clefType: ClefType.treble),
      Note(
          pitch: const Pitch(step: 'F', octave: 4),
          duration: const Duration(DurationType.eighth),
          beam: BeamType.start),
      Note(
          pitch: const Pitch(step: 'G', octave: 4),
          duration: const Duration(DurationType.sixteenth)),
      Note(
          pitch: const Pitch(step: 'A', octave: 4),
          duration: const Duration(DurationType.sixteenth),
          beam: BeamType.end),
      Note(
          pitch: const Pitch(step: 'B', octave: 4),
          duration: const Duration(DurationType.eighth)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Beams'),
        backgroundColor: Colors.brown.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Eighth Notes (1 Beam)',
              description: 'Groups of eighth notes connected by a single beam.',
              elements: eighthNoteBeams,
            ),
            _buildSection(
              title: 'Sixteenth Notes (2 Beams)',
              description: 'Group of sixteenth notes connected by two beams.',
              elements: sixteenthNoteBeams,
            ),
            _buildSection(
              title: 'Thirty-second Notes (3 Beams)',
              description: 'A group of thirty-second notes connected by three beams.',
              elements: thirtySecondNoteBeams,
            ),
            _buildSection(
              title: 'Sixty-fourth Notes (4 Beams)',
              description: 'Group of sixty-fourth notes connected by four beams.',
              elements: sixtyFourthNoteBeams,
            ),
            _buildSection(
              title: 'Mixed Groups',
              description:
                  'A mixed group. Partial beam rendering is an advanced feature.',
              elements: mixedBeams,
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
