// example/lib/examples/octave_marks_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Demonstrates octave markings: 8va, 8vb, 15ma, 15mb
class OctaveMarksExample extends StatelessWidget {
  const OctaveMarksExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Octave markings'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfo(),
            const SizedBox(height: 16),
            _buildSection(
              title: '8va — An Octave Higher',
              description:
                  'Indicates that notes should be played one octave higher'
                  'higher than written. Saves acute supplementary lines.',
              score: _build8va(),
            ),
            _buildSection(
              title: '8vb — One Octave Below',
              description:
                  'Indicates that notes should be played one octave higher'
                  'lower than written. Appears below the agenda.',
              score: _build8vb(),
            ),
            _buildSection(
              title: '15ma — Two Octaves Up',
              description:
                  'Indicates that notes should be played two octaves higher'
                  'altas do que escrito.',
              score: _build15ma(),
            ),
            _buildSection(
              title: '15mb — Two Octaves Below',
              description:
                  'Indicates that notes should be played two octaves higher'
                  'baixas do que escrito.',
              score: _build15mb(),
            ),
            _buildSection(
              title: 'Combinação: 8va + 8vb',
              description:
                  'Combined use of markings above and below the staff in'
                  'same musical passage.',
              score: _buildCombined(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  'About Octave Markings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Octave markings (ottava) are used to indicate that'
              'a passage must be performed in a different octave'
              'from notation, avoiding excessive use of ledger lines. '
              'The dashed line indicates the affected section and the bracket'
              'vertical marks the end of the transposition.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget score,
  }) {
    return Card(
      elevation: 2,
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
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: score,
            ),
          ],
        ),
      ),
    );
  }

  Widget _build8va() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas agudas com 8va
    measure.add(OctaveMark(
      type: OctaveType.va8,
      startMeasure: 0,
      endMeasure: 0,
      length: 160.0,
      showBracket: true,
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 6),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure);
    return MusicScore(staff: staff);
  }

  Widget _build8vb() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.bass));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas graves com 8vb
    measure.add(OctaveMark(
      type: OctaveType.vb8,
      startMeasure: 0,
      endMeasure: 0,
      length: 160.0,
      showBracket: true,
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 2),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure);
    return MusicScore(staff: staff);
  }

  Widget _build15ma() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    measure.add(OctaveMark(
      type: OctaveType.va15,
      startMeasure: 0,
      endMeasure: 0,
      length: 160.0,
      showBracket: true,
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure);
    return MusicScore(staff: staff);
  }

  Widget _build15mb() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.bass));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    measure.add(OctaveMark(
      type: OctaveType.vb15,
      startMeasure: 0,
      endMeasure: 0,
      length: 160.0,
      showBracket: true,
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 2),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 2),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 2),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure);
    return MusicScore(staff: staff);
  }

  Widget _buildCombined() {
    final staff = Staff();

    // Measure 1: 8va
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));
    measure1.add(OctaveMark(
      type: OctaveType.va8,
      startMeasure: 0,
      endMeasure: 0,
      length: 120.0,
      showBracket: true,
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    // Bar 2: normal notes
    final measure2 = Measure();
    measure2.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    staff.add(measure1);
    staff.add(measure2);
    return MusicScore(staff: staff);
  }
}
