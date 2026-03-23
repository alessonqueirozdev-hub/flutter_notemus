// example/lib/examples/rhythmic_figures_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

// Estrutura de dados para organizar cada figura
class RhythmicFigure {
  final String name;
  final DurationType durationType;

  const RhythmicFigure(this.name, this.durationType);
}

/// A page widget that demonstrates the rendering of all rhythmic figures
/// in an organized way, pairing each note with its respective rest.
class RhythmicFiguresExample extends StatelessWidget {
  const RhythmicFiguresExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Organized list of figures to display
    const List<RhythmicFigure> figures = [
      RhythmicFigure('Semibreve (Whole Note)', DurationType.whole),
      RhythmicFigure('Half Note', DurationType.half),
      RhythmicFigure('Quarter Note', DurationType.quarter),
      RhythmicFigure('Eighth Note', DurationType.eighth),
      RhythmicFigure('Sixteenth Note', DurationType.sixteenth),
      RhythmicFigure('Thirty-second Note', DurationType.thirtySecond),
      RhythmicFigure('Sixty-fourth Note', DurationType.sixtyFourth),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Rhythmic Figures'),
        backgroundColor: Colors.red.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        // Maps the figure list to create one section per item
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: figures.map((figure) {
            // For each figure, create a list of elements with the note and rest
            final elements = [
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: Duration(figure.durationType),
              ),
              Rest(duration: Duration(figure.durationType)),
            ];

            return _buildSection(
              title: figure.name,
              elements: elements,
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Constructs a test section for each note/rest pair.
  Widget _buildSection({
    required String title,
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
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 100, // Reduced height for a single staff
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
