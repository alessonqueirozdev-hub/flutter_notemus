// example/lib/examples/beams_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Um widget de página que demonstra a renderização de barras de ligação (beams).
class BeamsExample extends StatelessWidget {
  const BeamsExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Grupo de Colcheias (Eighth notes) - 1 barra
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

    // Grupo de Semicolcheias (Sixteenth notes) - 2 barras
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

    // Grupo de Fusas (Thirty-second notes) - 3 barras
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

    // Grupo de Semifusas (Sixty-fourth notes) - 4 barras
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
        title: const Text('Família de Símbolos: Barras de Ligação'),
        backgroundColor: Colors.brown.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Colcheias (1 Barra)',
              description: 'Grupos de colcheias ligadas por uma única barra.',
              elements: eighthNoteBeams,
            ),
            _buildSection(
              title: 'Semicolcheias (2 Barras)',
              description: 'Grupo de semicolcheias ligadas por duas barras.',
              elements: sixteenthNoteBeams,
            ),
            _buildSection(
              title: 'Fusas (3 Barras)',
              description: 'Grupo de fusas ligadas por três barras.',
              elements: thirtySecondNoteBeams,
            ),
            _buildSection(
              title: 'Semifusas (4 Barras)',
              description: 'Grupo de semifusas ligadas por quatro barras.',
              elements: sixtyFourthNoteBeams,
            ),
            _buildSection(
              title: 'Grupos Mistos',
              description:
                  'Um grupo misto. A renderização de barras parciais é uma funcionalidade avançada.',
              elements: mixedBeams,
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
