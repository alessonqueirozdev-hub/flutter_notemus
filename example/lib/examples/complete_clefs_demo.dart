// example/lib/examples/complete_clefs_demo.dart
// Full demo of all supported keys

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class CompleteClefsDemoExample extends StatelessWidget {
  const CompleteClefsDemoExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              'Complete Clef Demonstration',
              'All keys implemented with scales and signatures',
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Treble Clef (G Clef)',
              'High register - Violin, Flute, Oboe',
              _createTrebleClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Bass Clef (F Clef)',
              'Low range – Cello, Double bass, Bassoon',
              _createBassClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'High C Clef (C Clef - High)',
              'Middle register - Viola',
              _createAltoClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'C Clef Tenor (C Clef - Tenor)',
              'Middle-low register - Trombone, upper Cello',
              _createTenorClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Clefs with Octaves',
              'Octave transpositions',
              _createOctaveClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Pitch Comparison',
              'Same note in different keys',
              _createComparisonExample(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildSection(String title, String description, Widget scoreWidget) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.all(16),
              child: scoreWidget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _createTrebleClefExample() {
    final staff = Staff();

    // Bar 1: Clef + Key signature (2 sharps) + Formula
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(KeySignature(2)); // D major
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    // Escala de D major ascendente
    measure1.add(Note(
      pitch: Pitch.withAccidental(step: 'D', octave: 4, accidentalType: AccidentalType.natural),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: Pitch.withAccidental(step: 'F', octave: 4, accidentalType: AccidentalType.sharp),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));

    // Measure 2: Continuation of the scale
    final measure2 = Measure();
    measure2.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: Pitch.withAccidental(step: 'C', octave: 5, accidentalType: AccidentalType.sharp),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure1);
    staff.add(measure2);

    return SizedBox(
      height: 200,
      child: MusicScore(
        staff: staff,
        staffSpace: 12,
      ),
    );
  }

  Widget _createBassClefExample() {
    final staff = Staff();

    // Measure 1: Bass Clef + Signature (3 flats) + Formula
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.bass));
    measure1.add(KeySignature(-3)); // Mi♭ Maior
    measure1.add(TimeSignature(numerator: 3, denominator: 4));

    // Escala de Mi♭ Maior
    measure1.add(Note(
      pitch: Pitch.withAccidental(step: 'E', octave: 2, accidentalType: AccidentalType.flat),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'F', octave: 2),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 2),
      duration: const Duration(DurationType.quarter),
    ));

    // Measure 2
    final measure2 = Measure();
    measure2.add(Note(
      pitch: Pitch.withAccidental(step: 'A', octave: 2, accidentalType: AccidentalType.flat),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: Pitch.withAccidental(step: 'B', octave: 2, accidentalType: AccidentalType.flat),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));

    // Measure 3
    final measure3 = Measure();
    measure3.add(Note(
      pitch: const Pitch(step: 'D', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure3.add(Note(
      pitch: Pitch.withAccidental(step: 'E', octave: 3, accidentalType: AccidentalType.flat),
      duration: const Duration(DurationType.quarter),
    ));
    measure3.add(Rest(duration: const Duration(DurationType.quarter)));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);

    return SizedBox(
      height: 200,
      child: MusicScore(
        staff: staff,
        staffSpace: 12,
      ),
    );
  }

  Widget _createAltoClefExample() {
    final staff = Staff();

    // Measure 1: C Clef (Alto) + Key signature + Formula
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.alto));
    measure1.add(KeySignature(1)); // Sol Maior
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    // G major scale in viola register
    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'A', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'B', octave: 3),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));

    // Measure 2
    final measure2 = Measure();
    measure2.add(Note(
      pitch: const Pitch(step: 'D', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: Pitch.withAccidental(step: 'F', octave: 4, accidentalType: AccidentalType.sharp),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure1);
    staff.add(measure2);

    return SizedBox(
      height: 200,
      child: MusicScore(
        staff: staff,
        staffSpace: 12,
      ),
    );
  }

  Widget _createTenorClefExample() {
    final staff = Staff();

    // Measure 1: C Clef (Tenor) + Key signature + Formula
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.tenor));
    measure1.add(KeySignature(-2)); // Si♭ Maior
    measure1.add(TimeSignature(numerator: 6, denominator: 8));

    // Melodic pattern in 6/8
    measure1.add(Note(
      pitch: Pitch.withAccidental(step: 'B', octave: 3, accidentalType: AccidentalType.flat),
      duration: const Duration(DurationType.eighth),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'D', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));
    measure1.add(Note(
      pitch: Pitch.withAccidental(step: 'E', octave: 4, accidentalType: AccidentalType.flat),
      duration: const Duration(DurationType.eighth),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.eighth),
    ));

    staff.add(measure1);

    return SizedBox(
      height: 200,
      child: MusicScore(
        staff: staff,
        staffSpace: 12,
      ),
    );
  }

  Widget _createOctaveClefExample() {
    final staff = Staff();

    // Comparison of clefs with octaves
    // Measure 1: Normal G
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));
    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.whole),
    ));

    // Measure 2: G 8va (one octave higher)
    final measure2 = Measure();
    measure2.add(Clef(clefType: ClefType.treble8va));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 6),
      duration: const Duration(DurationType.whole),
    ));

    // Measure 3: G 8vb (one octave lower)
    final measure3 = Measure();
    measure3.add(Clef(clefType: ClefType.treble8vb));
    measure3.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.whole),
    ));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);

    return SizedBox(
      height: 200,
      child: MusicScore(
        staff: staff,
        staffSpace: 12,
      ),
    );
  }

  Widget _createComparisonExample() {
    return Column(
      children: [
        Text(
          'Note Middle C (C4) in each key:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        _createComparisonStaff(ClefType.treble, 'Treble clef'),
        const SizedBox(height: 8),
        _createComparisonStaff(ClefType.bass, 'Bass clef'),
        const SizedBox(height: 8),
        _createComparisonStaff(ClefType.alto, 'Clef of C (Alto)'),
        const SizedBox(height: 8),
        _createComparisonStaff(ClefType.tenor, 'Clef of C (Tenor)'),
      ],
    );
  }

  Widget _createComparisonStaff(ClefType clefType, String label) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: clefType));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.whole),
    ));

    staff.add(measure);

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 120,
            child: MusicScore(
              staff: staff,
              staffSpace: 10,
            ),
          ),
        ),
      ],
    );
  }
}
