// example/lib/examples/test_pitch_accuracy.dart
// NOTE PITCH ACCURACY TEST

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Test widget to verify whether notes are at the correct pitches
class TestPitchAccuracy extends StatelessWidget {
  const TestPitchAccuracy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TEST: Pitch Accuracy'),
        backgroundColor: Colors.red.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTestSection(
              title: 'TREBLE CLEF - Diatonic Scale',
              description: 'G4 MUST be on the 2nd line (from bottom to top)',
              elements: [
                Clef(clefType: ClefType.treble),
                // Start with G4 which must be on the 2nd line
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'B', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'C', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'D', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'E', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'F', octave: 5),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'G', octave: 5),
                    duration: const Duration(DurationType.whole)),
                // Add note that needs additional line
                Note(
                    pitch: const Pitch(step: 'A', octave: 5),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildReferenceGuide(),
            _buildTestSection(
              title: 'BASS CLEF - Reference Note',
              description: 'F3 MUST be on the 4th line',
              elements: [
                Clef(clefType: ClefType.bass),
                // Start with F3 which should be on the 4th line
                Note(
                    pitch: const Pitch(step: 'F', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'G', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'A', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'B', octave: 3),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
                // Add note that needs supplementary bottom line
                Note(
                    pitch: const Pitch(step: 'C', octave: 3),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
            _buildTestSection(
              title: 'C CLEF (ALTO) - Reference Note',
              description: 'C4 MUST be on the 3rd line (middle)',
              elements: [
                Clef(clefType: ClefType.alto),
                // Start with C4 which should be on the center line
                Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'D', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'E', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'F', octave: 4),
                    duration: const Duration(DurationType.whole)),
                Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.whole)),
                // Add note that needs top supplementary line
                Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.whole)),
              ],
            ),
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
                color: Colors.red,
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
                border: Border.all(color: Colors.red, width: 2),
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
      color: Colors.yellow.shade100,
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📏 REFERENCE GUIDE - TREBLE CLEF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Expected positions (bottom to top):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...[
              'Line 1: E4',
              'Space 1: F4',
              'Line 2: G4 ⭐ (CLAVE REFERENCE NOTE)',
              'Space 2: A4',
              'Line 3: B4 (middle of the staff)',
              'Space 3: C5',
              'Row 4: D5',
              'Space 4: E5',
              'Line 5: F5',
            ].map((text) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      color: text.contains('⭐')
                          ? Colors.red.shade700
                          : Colors.black87,
                      fontWeight: text.contains('⭐')
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
