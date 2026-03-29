import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Stable beaming showcase aligned with the same rendering structure used by
/// the main Beams example.
class BeamingShowcase extends StatelessWidget {
  const BeamingShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Beaming Showcase'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beaming Showcase',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Examples aligned with the stable beam structure used by the main beam demo.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildExampleSection(
              title: 'Primary Beams',
              description: 'Four eighth notes connected by one beam.',
              elements: _primaryBeams(),
            ),
            const SizedBox(height: 24),
            _buildExampleSection(
              title: 'Secondary Beams',
              description: 'Four sixteenth notes connected by two beams.',
              elements: _secondaryBeams(),
            ),
            const SizedBox(height: 24),
            _buildExampleSection(
              title: 'Tertiary Beams',
              description: 'Four thirty-second notes connected by three beams.',
              elements: _tertiaryBeams(),
            ),
            const SizedBox(height: 24),
            _buildExampleSection(
              title: 'Sixty-fourth Beams',
              description: 'Four sixty-fourth notes connected by four beams.',
              elements: _sixtyFourthBeams(),
            ),
            const SizedBox(height: 24),
            _buildExampleSection(
              title: 'Mixed Stable Group',
              description:
                  'Explicit grouping for a mixed rhythmic pattern without a special advanced path.',
              elements: _mixedBeams(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleSection({
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
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: MusicScore(
                staff: staff,
                staffSpace: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MusicalElement> _primaryBeams() {
    return [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.eighth),
        beam: BeamType.start,
      ),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.eighth),
      ),
      Note(
        pitch: const Pitch(step: 'B', octave: 4),
        duration: const Duration(DurationType.eighth),
      ),
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.eighth),
        beam: BeamType.end,
      ),
    ];
  }

  List<MusicalElement> _secondaryBeams() {
    return [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.sixteenth),
        beam: BeamType.start,
      ),
      Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const Duration(DurationType.sixteenth),
      ),
      Note(
        pitch: const Pitch(step: 'E', octave: 5),
        duration: const Duration(DurationType.sixteenth),
      ),
      Note(
        pitch: const Pitch(step: 'F', octave: 5),
        duration: const Duration(DurationType.sixteenth),
        beam: BeamType.end,
      ),
    ];
  }

  List<MusicalElement> _tertiaryBeams() {
    return [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'F', octave: 4),
        duration: const Duration(DurationType.thirtySecond),
        beam: BeamType.start,
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
        beam: BeamType.end,
      ),
    ];
  }

  List<MusicalElement> _sixtyFourthBeams() {
    return [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.sixtyFourth),
        beam: BeamType.start,
      ),
      Note(
        pitch: const Pitch(step: 'B', octave: 4),
        duration: const Duration(DurationType.sixtyFourth),
      ),
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.sixtyFourth),
      ),
      Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const Duration(DurationType.sixtyFourth),
        beam: BeamType.end,
      ),
    ];
  }

  List<MusicalElement> _mixedBeams() {
    return [
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'F', octave: 4),
        duration: const Duration(DurationType.eighth),
        beam: BeamType.start,
      ),
      Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.sixteenth),
      ),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.sixteenth),
        beam: BeamType.end,
      ),
      Note(
        pitch: const Pitch(step: 'B', octave: 4),
        duration: const Duration(DurationType.eighth),
      ),
    ];
  }
}
