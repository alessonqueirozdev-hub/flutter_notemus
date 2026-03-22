// example/lib/examples/grace_notes_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget que demonstra a renderização de apojaturas e notas de ornamento
class GraceNotesExample extends StatelessWidget {
  const GraceNotesExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Apojaturas e Notas de Graça'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Apojaturas Simples',
              description: 'Apojaturas de diferentes durações.',
              elements: [
                Clef(clefType: ClefType.treble),
                // Apogiatura simples
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.eighth), // Grace note
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                // Apogiatura longa
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter), // Grace note
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                ),
              ],
            ),
            _buildSection(
              title: 'Acciaccaturas',
              description: 'Notas de graça cortadas (acciaccaturas).',
              elements: [
                Clef(clefType: ClefType.treble),
                // Acciaccatura simples
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.sixteenth), // Grace note cortada
                  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                // Acciaccatura dupla
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.sixteenth),
                  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.sixteenth),
                  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ),
            _buildSection(
              title: 'Apojaturas Superiores',
              description: 'Apojaturas que se resolvem descendo.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ),
            _buildSection(
              title: 'Apojaturas Inferiores',
              description: 'Apojaturas que se resolvem subindo.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.appoggiaturaDown)],
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.appoggiaturaDown)],
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ),
            _buildSection(
              title: 'Grupos de Apojaturas',
              description: 'Múltiplas notas de graça em sequência.',
              elements: [
                Clef(clefType: ClefType.treble),
                // Grupo de 3 apojaturas
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
                  duration: const Duration(DurationType.quarter),
                ),
                // Pausa
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Apojaturas com Alterações',
              description: 'Apojaturas com acidentes cromáticos.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4, alter: 1.0, accidentalType: AccidentalType.sharp),
                  duration: const Duration(DurationType.eighth),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4, alter: -1.0, accidentalType: AccidentalType.flat),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ),
            _buildSection(
              title: 'Schleifers',
              description: 'Ornamentos que deslizam até a nota principal.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  ornaments: [Ornament(type: OrnamentType.schleifer)],
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  ornaments: [Ornament(type: OrnamentType.schleifer)],
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  ornaments: [Ornament(type: OrnamentType.schleifer)],
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Apojaturas em Acordes',
              description: 'Notas de graça aplicadas a acordes.',
              elements: [
                Clef(clefType: ClefType.treble),
                // Acciaccatura antes de acorde
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.sixteenth),
                  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
                ),
                Chord(
                  notes: [
                    Note(
                      pitch: const Pitch(step: 'C', octave: 4),
                      duration: const Duration(DurationType.quarter),
                    ),
                    Note(
                      pitch: const Pitch(step: 'E', octave: 4),
                      duration: const Duration(DurationType.quarter),
                    ),
                    Note(
                      pitch: const Pitch(step: 'G', octave: 4),
                      duration: const Duration(DurationType.quarter),
                    ),
                  ],
                  duration: const Duration(DurationType.quarter),
                ),
                Rest(duration: const Duration(DurationType.half)),
              ],
            ),
            _buildSection(
              title: 'Apojaturas com Ligaduras',
              description: 'Apojaturas conectadas à nota principal por ligadura.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.eighth),
                  slur: SlurType.start,
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  slur: SlurType.end,
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
                  slur: SlurType.start,
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
