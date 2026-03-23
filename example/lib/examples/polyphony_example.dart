// example/lib/examples/polyphony_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

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

  Staff _buildTwoVoiceStaff() {
    final staff = Staff();
    final measure = MultiVoiceMeasure();

    final voice1 = Voice.voice1();
    voice1.add(Clef(clefType: ClefType.treble));
    voice1.add(TimeSignature(numerator: 4, denominator: 4));
    voice1.add(Note(pitch: const Pitch(step: 'E', octave: 5), duration: const Duration(DurationType.quarter)));
    voice1.add(Note(pitch: const Pitch(step: 'D', octave: 5), duration: const Duration(DurationType.quarter)));
    voice1.add(Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.quarter)));
    voice1.add(Note(pitch: const Pitch(step: 'D', octave: 5), duration: const Duration(DurationType.quarter)));

    final voice2 = Voice.voice2();
    voice2.add(Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.half)));
    voice2.add(Note(pitch: const Pitch(step: 'G', octave: 3), duration: const Duration(DurationType.half)));

    measure.addVoice(voice1);
    measure.addVoice(voice2);
    staff.add(measure);
    return staff;
  }

  Staff _buildCounterpointStaff() {
    final staff = Staff();
    final measure = MultiVoiceMeasure();

    final voice1 = Voice.voice1();
    voice1.add(Clef(clefType: ClefType.treble));
    voice1.add(TimeSignature(numerator: 4, denominator: 4));
    voice1.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.quarter)));
    voice1.add(Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.quarter)));
    voice1.add(Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.quarter)));
    voice1.add(Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.quarter)));

    final voice2 = Voice.voice2();
    voice2.add(Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.quarter)));
    voice2.add(Note(pitch: const Pitch(step: 'B', octave: 3), duration: const Duration(DurationType.quarter)));
    voice2.add(Note(pitch: const Pitch(step: 'A', octave: 3), duration: const Duration(DurationType.quarter)));
    voice2.add(Note(pitch: const Pitch(step: 'G', octave: 3), duration: const Duration(DurationType.quarter)));

    measure.addVoice(voice1);
    measure.addVoice(voice2);
    staff.add(measure);
    return staff;
  }

  Staff _buildGuitarStaff() {
    final staff = Staff();
    final measure = MultiVoiceMeasure();

    final voice1 = Voice.voice1();
    voice1.add(Clef(clefType: ClefType.treble));
    voice1.add(TimeSignature(numerator: 4, denominator: 4));
    voice1.add(Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.eighth), beam: BeamType.start));
    voice1.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth), beam: BeamType.inner));
    voice1.add(Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.eighth), beam: BeamType.inner));
    voice1.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth), beam: BeamType.end));

    final voice2 = Voice.voice2();
    voice2.add(Note(pitch: const Pitch(step: 'C', octave: 3), duration: const Duration(DurationType.half)));
    voice2.add(Note(pitch: const Pitch(step: 'G', octave: 2), duration: const Duration(DurationType.half)));

    measure.addVoice(voice1);
    measure.addVoice(voice2);
    staff.add(measure);
    return staff;
  }

  Widget _buildSection({required String title, required String description, required Staff staff}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: MusicScore(staff: staff),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, color: Colors.purple.shade700),
                      const SizedBox(width: 8),
                      Text('Sobre Polifonia', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800, fontSize: 16)),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Polyphony is the technique of writing multiple independent voices on the same staff. Voice 1 has upward stems; voice 2, down.', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Duas Vozes — Melodia + Acompanhamento',
              description: 'Voice 1 (stems above): melody in eighth notes. Voice 2 (stems below): accompaniment in half notes.',
              staff: _buildTwoVoiceStaff(),
            ),
            _buildSection(
              title: 'Contraponto ao Estilo Bach',
              description: 'Duas vozes independentes em movimento contrário.',
              staff: _buildCounterpointStaff(),
            ),
            _buildSection(
              title: 'Guitarra Fingerstyle',
              description: 'Melodia em colcheias (voz 1) + baixo em mínimas (voz 2).',
              staff: _buildGuitarStaff(),
            ),
          ],
        ),
      ),
    );
  }
}
