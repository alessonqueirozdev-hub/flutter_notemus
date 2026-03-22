// example/lib/examples/polyphony_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

/// Example demonstrating polyphonic notation (multiple voices)
///
/// Shows:
/// 1. Two-voice texture (melody + accompaniment)
/// 2. Bach-style counterpoint
/// 3. Guitar fingerstyle
/// 4. Piano texture with independent hands
class PolyphonyExample {
  /// Create a simple two-voice measure
  ///
  /// Voice 1 (top): Melody with quarter notes, stems up
  /// Voice 2 (bottom): Accompaniment with half notes, stems down
  static MultiVoiceMeasure createSimpleTwoVoice() {
    // Voice 1: Melody (stems up)
    final voice1 = Voice.voice1();
    voice1.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Voice 2: Accompaniment (stems down, offset right)
    final voice2 = Voice.voice2();
    voice2.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.half),
    ));
    voice2.add(Note(
      pitch: const Pitch(step: 'G', octave: 3),
      duration: const Duration(DurationType.half),
    ));

    final measure = MultiVoiceMeasure();
    measure.addVoice(voice1);
    measure.addVoice(voice2);

    return measure;
  }

  /// Create Bach-style counterpoint
  ///
  /// Two independent melodic lines with equal importance
  static MultiVoiceMeasure createCounterpoint() {
    // Voice 1: Upper line
    final voice1 = Voice.voice1(name: 'Upper Voice');
    voice1.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Voice 2: Lower line (contrary motion)
    final voice2 = Voice.voice2(name: 'Lower Voice');
    voice2.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    voice2.add(Note(
      pitch: const Pitch(step: 'B', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    voice2.add(Note(
      pitch: const Pitch(step: 'A', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    voice2.add(Note(
      pitch: const Pitch(step: 'G', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));

    return MultiVoiceMeasure.twoVoices(
      voice1Elements: voice1.elements,
      voice2Elements: voice2.elements,
    );
  }

  /// Create guitar fingerstyle pattern
  ///
  /// Voice 1: Melody on high strings
  /// Voice 2: Bass notes
  static MultiVoiceMeasure createGuitarFingerstyle() {
    // Voice 1: Melody (high strings)
    final voice1 = Voice.voice1(name: 'Melody');
    voice1.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));

    // Voice 2: Bass (low strings, held notes)
    final voice2 = Voice.voice2(name: 'Bass');
    voice2.add(Note(
      pitch: const Pitch(step: 'C', octave: 3),
      duration: const Duration(DurationType.half),
    ));
    voice2.add(Note(
      pitch: const Pitch(step: 'G', octave: 2),
      duration: const Duration(DurationType.half),
    ));

    final measure = MultiVoiceMeasure();
    measure.addVoice(voice1);
    measure.addVoice(voice2);

    return measure;
  }

  /// Create piano texture with chords in voice 2
  static MultiVoiceMeasure createPianoTexture() {
    // Voice 1: Melody
    final voice1 = Voice.voice1(name: 'Melody');
    voice1.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    voice1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    // Voice 2: Chord accompaniment
    final voice2 = Voice.voice2(name: 'Chords');
    voice2.add(Chord(
      notes: [
        Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 4),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'G', octave: 4),
          duration: const Duration(DurationType.whole),
        ),
      ],
      duration: const Duration(DurationType.whole),
    ));

    final measure = MultiVoiceMeasure();
    measure.addVoice(voice1);
    measure.addVoice(voice2);

    return measure;
  }
}

/// Flutter widget demonstrating polyphony
class PolyphonyExampleWidget extends StatelessWidget {
  const PolyphonyExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polyphony Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Polyphonic Notation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Multiple independent voices on one staff',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Example 1: Simple Two-Voice
          _buildExampleCard(
            context,
            title: 'Simple Two-Voice',
            description: 'Melody (voice 1) + accompaniment (voice 2)',
            measure: PolyphonyExample.createSimpleTwoVoice(),
          ),

          // Example 2: Counterpoint
          _buildExampleCard(
            context,
            title: 'Bach-Style Counterpoint',
            description: 'Two equal independent voices',
            measure: PolyphonyExample.createCounterpoint(),
          ),

          // Example 3: Guitar Fingerstyle
          _buildExampleCard(
            context,
            title: 'Guitar Fingerstyle',
            description: 'Melody on high strings + bass notes',
            measure: PolyphonyExample.createGuitarFingerstyle(),
          ),

          // Example 4: Piano Texture
          _buildExampleCard(
            context,
            title: 'Piano Texture',
            description: 'Melody + chord accompaniment',
            measure: PolyphonyExample.createPianoTexture(),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Voice conventions
          const Text(
            'Voice Conventions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildConventionItem('Voice 1', 'Stems up, no horizontal offset'),
          _buildConventionItem(
              'Voice 2', 'Stems down, offset 0.6 staff spaces right'),
          _buildConventionItem('Voice 3+', 'Alternating or position-based'),
        ],
      ),
    );
  }

  Widget _buildExampleCard(
    BuildContext context, {
    required String title,
    required String description,
    required MultiVoiceMeasure measure,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Voice information
            ...measure.sortedVoices.map((voice) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      voice.getStemDirection() == StemDirection.up
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${voice.name ?? 'Voice ${voice.number}'}: ${voice.notes.length} notes',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            Text(
              'Polyphonic: ${measure.isPolyphonic ? 'Yes' : 'No'} (${measure.voiceCount} voices)',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),

            // TODO: Add actual music rendering when renderer is complete
          ],
        ),
      ),
    );
  }

  Widget _buildConventionItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
