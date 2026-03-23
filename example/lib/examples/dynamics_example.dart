// example/lib/examples/dynamics_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget that demonstrates the rendering of musical dynamics
class DynamicsExample extends StatelessWidget {
  const DynamicsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Dynamics'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Basic Dynamics',
              description: 'The main musical intensity markings.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.piano),
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.mezzoForte),
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.forte),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Pianissimo Dynamics',
              description: 'Pianissimo gradations - from softest to extreme.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.pp),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.ppp),
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.pppp),
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.ppppp),
                ),
              ],
            ),
            _buildSection(
              title: 'Fortissimo Dynamics',
              description: 'Fortissimo gradations - from intense to extreme.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.ff),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.fff),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.ffff),
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.fffff),
                ),
              ],
            ),
            _buildSection(
              title: 'Dynamics Especiais',
              description: 'Sforzando, rinforzando, and other special markings.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.sforzando),
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.sforzandoFF),
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.sforzandoPiano),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.rinforzando),
                ),
              ],
            ),
            _buildSection(
              title: 'Dynamics Combinadas',
              description: 'Combinations such as fortepiano and other variants.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.fortePiano),
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.sforzandoPianissimo),
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.mezzoPiano),
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.mezzoForte),
                ),
              ],
            ),
            _buildSection(
              title: 'Crescendo e Diminuendo',
              description: 'Gradual intensity-change markings (hairpins).',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(
                    type: DynamicType.crescendo,
                    isHairpin: true,
                    length: 80.0,
                  ),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(
                    type: DynamicType.diminuendo,
                    isHairpin: true,
                    length: 80.0,
                  ),
                ),
              ],
            ),
            _buildSection(
              title: 'Dynamics Extremas',
              description: 'Dynamic markings at the extreme end of the sound palette.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.pppppp),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(type: DynamicType.niente),
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.half),
                  dynamicElement: Dynamic(type: DynamicType.ffffff),
                ),
              ],
            ),
            _buildSection(
              title: 'Dynamics Personalizadas',
              description: 'Custom dynamic markings.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(
                    type: DynamicType.custom,
                    customText: 'dolce',
                  ),
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(
                    type: DynamicType.custom,
                    customText: 'espressivo',
                  ),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  dynamicElement: Dynamic(
                    type: DynamicType.custom,
                    customText: 'sotto voce',
                  ),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
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
