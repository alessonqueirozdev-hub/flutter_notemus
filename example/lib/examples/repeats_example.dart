// example/lib/examples/repeats_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget que demonstra a renderização de sinais de repetição
class RepeatsExample extends StatelessWidget {
  const RepeatsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Repetições'),
        backgroundColor: Colors.indigo.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Barras de Repetição Básicas',
              description: 'Início e fim de seções repetidas.',
              elements: [
                Clef(clefType: ClefType.treble),
                Barline(
                  type: BarlineType.repeatForward,
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
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
                ),
                Barline(
                  type: BarlineType.repeatBackward,
                ),
              ],
            ),
            _buildSection(
              title: 'Segno e Coda',
              description: 'Símbolos de navegação musical.',
              elements: [
                Clef(clefType: ClefType.treble),
                RepeatMark(type: RepeatType.segno),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                RepeatMark(type: RepeatType.coda),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Segno e Coda Quadrados',
              description: 'Variações dos símbolos de navegação.',
              elements: [
                Clef(clefType: ClefType.treble),
                RepeatMark(type: RepeatType.segnoSquare),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                RepeatMark(type: RepeatType.codaSquare),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Instruções de Repetição',
              description: 'Dal Segno, Da Capo e Fine.',
              elements: [
                Clef(clefType: ClefType.treble),
                MusicText(
                  text: 'D.C.',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'D.S.',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'Fine',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Repetições de Compassos',
              description: 'Símbolos para repetir compassos específicos.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
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
                ),
                RepeatMark(type: RepeatType.repeat1Bar),
              ],
            ),
            _buildSection(
              title: 'Repetições Múltiplas de Compassos',
              description: 'Símbolos para repetir múltiplos compassos.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.half),
                ),
                RepeatMark(type: RepeatType.repeat2Bars),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.whole),
                ),
                RepeatMark(type: RepeatType.repeat4Bars),
              ],
            ),
            _buildSection(
              title: 'Simile e Porcentagem',
              description: 'Símbolos de repetição de padrões.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
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
                ),
                RepeatMark(type: RepeatType.simile),
                RepeatMark(type: RepeatType.percentRepeat),
              ],
            ),
            _buildSection(
              title: 'Instruções Complexas',
              description: 'Combinações de instruções de repetição.',
              elements: [
                Clef(clefType: ClefType.treble),
                MusicText(
                  text: 'D.C. al Coda',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'D.S. al Fine',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'To Coda',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Marcas de Ensaio',
              description: 'Letras e números para referência.',
              elements: [
                Clef(clefType: ClefType.treble),
                Barline(
                  type: BarlineType.single,
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.quarter),
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
