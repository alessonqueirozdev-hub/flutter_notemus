// example/lib/examples/tempo_agogics_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget that demonstrates the rendering of time and agogical indications
class TempoAgogicsExample extends StatelessWidget {
  const TempoAgogicsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Tempo and Agogics'),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Tempo Markings (BPM)',
              description: 'Metronome markings with speed indication.',
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
              title: 'Different Beat Units',
              description: 'Beat-unit variations for the metronome.',
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
              title: 'Textual Tempo Markings',
              description: 'Character markings without numeric indication.',
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
              title: 'Expression Markings',
              description: 'Expressive and interpretive character markings.',
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
              title: 'Tempo Changes',
              description: 'Tempo-change indications during the piece.',
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
              title: 'Breaths and Pauses',
              description: 'Breathing and pause indications.',
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
              description: 'Different types of caesuras and interruptions.',
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
              title: 'Complex Metronome Markings',
              description: 'Equations and tempo ranges.',
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
              title: 'Performance Instructions',
              description: 'Specific interpretation texts.',
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
