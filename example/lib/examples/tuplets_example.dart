// example/lib/examples/tuplets_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget that demonstrates the rendering of tuplets
class TupletsExample extends StatelessWidget {
  const TupletsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Tuplets'),
        backgroundColor: Colors.indigo.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Simple Triplet (3:2)',
              description: 'Three eighth notes in the time of two - the most common tuplet.',
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
                  bracketConfig: const TupletBracket(show: true),
                  numberConfig: const TupletNumber(),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Quinta (5:4)',
              description: 'Five sixteenth notes in the space of four.',
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
                  bracketConfig: const TupletBracket(show: true),
                  numberConfig: const TupletNumber(),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Sextina (6:4)',
              description: 'Six sixteenth notes in the space of four.',
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
                  bracketConfig: const TupletBracket(show: true),
                  numberConfig: const TupletNumber(),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Septina (7:4)',
              description: 'Seven thirty-second notes in the space of four.',
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
                  bracketConfig: const TupletBracket(show: true),
                  numberConfig: const TupletNumber(),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Triplet with Rests',
              description: 'Triplet including rests in the grouping.',
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
                  bracketConfig: const TupletBracket(show: true),
                  numberConfig: const TupletNumber(),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Triplet Without Bracket',
              description: 'Triplet showing only the number, with no support line.',
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
                  bracketConfig: const TupletBracket(show: false),
                  numberConfig: const TupletNumber(),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Duplet (2:3)',
              description: 'Two eighth notes in the time of three - inverted tuplet.',
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
                  bracketConfig: const TupletBracket(show: true),
                  numberConfig: const TupletNumber(),
                ),
                Rest(duration: const Duration(DurationType.half)),
              ],
            ),
            _buildSection(
              title: 'Quarter-Note Tuplet',
              description: 'Quarter-note triplet (longer durations).',
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
                  bracketConfig: const TupletBracket(show: true),
                  numberConfig: const TupletNumber(),
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
