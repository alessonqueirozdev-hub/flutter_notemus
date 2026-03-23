// example/lib/examples/slurs_ties_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget that demonstrates the rendering of bandages (slurs and ties)
class SlursTiesExample extends StatelessWidget {
  const SlursTiesExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Ligatures'),
        backgroundColor: Colors.cyan.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Value Bonds (Ties)',
              description: 'Ligatures that connect notes of the same pitch.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  tie: TieType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  tie: TieType.end,
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                  tie: TieType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  tie: TieType.end,
                ),
              ],
            ),
            _buildSection(
              title: 'Expression Ligatures (Slurs)',
              description: 'Ligatures that connect notes of different pitches.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.end,
                ),
              ],
            ),
            _buildSection(
              title: 'Slurs Curtos',
              description: 'Expression slurs between two notes.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.end,
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.end,
                ),
              ],
            ),
            _buildSection(
              title: 'Slurs Longos',
              description: 'Expression ligatures over extended sentences.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.eighth),
                  slur: SlurType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.eighth),
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 5),
                  duration: const Duration(DurationType.eighth),
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 5),
                  duration: const Duration(DurationType.eighth),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 5),
                  duration: const Duration(DurationType.eighth),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 5),
                  duration: const Duration(DurationType.eighth),
                  slur: SlurType.end,
                ),
              ],
            ),
            _buildSection(
              title: 'Ties in Chords',
              description: 'Value ligatures applied to chords.',
              elements: [
                Clef(clefType: ClefType.treble),
                Chord(
                  notes: [
                    Note(
                      pitch: const Pitch(step: 'C', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      tie: TieType.start,
                    ),
                    Note(
                      pitch: const Pitch(step: 'E', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      tie: TieType.start,
                    ),
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      tie: TieType.start,
                    ),
                  ],
                  duration: const Duration(DurationType.quarter),
                ),
                Chord(
                  notes: [
                    Note(
                      pitch: const Pitch(step: 'C', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      tie: TieType.end,
                    ),
                    Note(
                      pitch: const Pitch(step: 'E', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      tie: TieType.end,
                    ),
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      tie: TieType.end,
                    ),
                  ],
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ),
            _buildSection(
              title: 'Slurs in Chords',
              description: 'Expression ligatures connecting chords.',
              elements: [
                Clef(clefType: ClefType.treble),
                Chord(
                  notes: [
                    Note(
                      pitch: const Pitch(step: 'F', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      slur: SlurType.start,
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
                  duration: const Duration(DurationType.quarter),
                ),
                Chord(
                  notes: [
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.quarter),
                      slur: SlurType.end,
                    ),
                    Note(
                      pitch: const Pitch(step: 'B', octave: 4),
                      duration: const Duration(DurationType.quarter),
                    ),
                    Note(
                      pitch: const Pitch(step: 'D', octave: 5),
                      duration: const Duration(DurationType.quarter),
                    ),
                  ],
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ),
            _buildSection(
              title: 'Advanced Ligatures',
              description: 'Ligatures with specific directions.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.start, // ✅ Slur como propriedade da nota
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.end, // ✅ Slur como propriedade da nota
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Slurs with Downward Direction',
              description: 'Forced downward bandages.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'E', octave: 5),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.start, // ✅ Slur como propriedade da nota
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 5),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.end, // ✅ Slur como propriedade da nota
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Slurs Aninhados',
              description: 'Multiple overlapping ligatures.',
              elements: [
                Clef(clefType: ClefType.treble),
                // Slur longo (externo)
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.end,
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
              height: 160, // ✅ Increased from 120 to 160 (more vertical space)
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0), // ✅ Mais padding horizontal
                child: MusicScore(
                  staff: staff,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
