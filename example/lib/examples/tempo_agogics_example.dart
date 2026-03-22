// example/lib/examples/tempo_agogics_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget que demonstra a renderização de indicações de tempo e agógica
class TempoAgogicsExample extends StatelessWidget {
  const TempoAgogicsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Tempo e Agógica'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Indicações de Tempo (BPM)',
              description: 'Marcações metrônomo com indicação de velocidade.',
              elements: [
                Clef(clefType: ClefType.treble),
                TempoMark(
                  beatUnit: DurationType.quarter,
                  bpm: 120,
                  text: 'Allegro',
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
              ],
            ),
            _buildSection(
              title: 'Diferentes Unidades de Tempo',
              description: 'Variações de unidade métrica para o metrônomo.',
              elements: [
                Clef(clefType: ClefType.treble),
                TempoMark(
                  beatUnit: DurationType.half,
                  bpm: 60,
                  text: 'Andante',
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.half),
                ),
              ],
            ),
            _buildSection(
              title: 'Indicações Textuais de Tempo',
              description: 'Marcações de caráter sem indicação numérica.',
              elements: [
                Clef(clefType: ClefType.treble),
                MusicText(
                  text: 'Largo',
                  type: TextType.tempo,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.whole),
                ),
              ],
            ),
            _buildSection(
              title: 'Indicações de Expressão',
              description: 'Marcações de caráter expressivo e interpretativo.',
              elements: [
                Clef(clefType: ClefType.treble),
                MusicText(
                  text: 'dolce',
                  type: TextType.expression,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'espressivo',
                  type: TextType.expression,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'cantabile',
                  type: TextType.expression,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Mudanças de Tempo',
              description: 'Indicações de variação de tempo durante a música.',
              elements: [
                Clef(clefType: ClefType.treble),
                MusicText(
                  text: 'accel.',
                  type: TextType.tempo,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.eighth),
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 5),
                  duration: const Duration(DurationType.eighth),
                ),
                MusicText(
                  text: 'rit.',
                  type: TextType.tempo,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 5),
                  duration: const Duration(DurationType.half),
                ),
              ],
            ),
            _buildSection(
              title: 'Respirações e Pausas',
              description: 'Indicações de respiração e interrupção.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Breath(type: BreathType.comma),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Breath(type: BreathType.tick),
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.quarter),
                ),
                Breath(type: BreathType.upbow),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Caesuras',
              description: 'Diferentes tipos de caesuras e interrupções.',
              elements: [
                Clef(clefType: ClefType.treble),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Caesura(type: BreathType.shortCaesura),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Caesura(type: BreathType.longCaesura),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Caesura(type: BreathType.caesura),
                Rest(duration: const Duration(DurationType.quarter)),
              ],
            ),
            _buildSection(
              title: 'Indicações de Metrônomo Complexas',
              description: 'Equações e faixas de tempo.',
              elements: [
                Clef(clefType: ClefType.treble),
                TempoMark(
                  bpm: 120,
                  beatUnit: DurationType.quarter,
                  text: '♩ = ♪',
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                TempoMark(
                  bpm: 126,
                  beatUnit: DurationType.quarter,
                  text: '♩ = 120-132',
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ),
            _buildSection(
              title: 'Instruções de Performance',
              description: 'Textos específicos para interpretação.',
              elements: [
                Clef(clefType: ClefType.treble),
                MusicText(
                  text: 'con fuoco',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'legato',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                MusicText(
                  text: 'staccato',
                  type: TextType.instruction,
                  placement: TextPlacement.above,
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  articulations: [ArticulationType.staccato],
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
