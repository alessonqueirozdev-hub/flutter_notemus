// example/lib/examples/complete_advanced_elements.dart
// Demonstração completa de elementos avançados: acordes, tuplets, dinâmicas, etc.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class CompleteAdvancedElementsExample extends StatelessWidget {
  const CompleteAdvancedElementsExample({super.key});

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
              'Elementos Avançados Completos',
              'Acordes, Quiálteras, Ligaduras e Dinâmicas',
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Acordes Complexos',
              'Tríades, tétrades e cluster chords',
              _createComplexChords(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Quiálteras (Tuplets)',
              'Tercinas, quintinas, sextinas',
              _createTuplets(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Ligaduras de Expressão (Slurs)',
              'Frasagem e articulação',
              _createSlurs(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Ligaduras de Prolongamento (Ties)',
              'Notas sustentadas',
              _createTies(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Dinâmicas Completas',
              'De pppp a ffff, crescendo e diminuendo',
              _createDynamics(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Indicações de Tempo',
              'Andamentos e metrônomo',
              _createTempoMarkings(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Sinais de Repetição',
              'Segno, Coda, D.C., D.S.',
              _createRepeats(),
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
            color: Colors.teal,
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

  Widget _createComplexChords() {
    final staff = Staff();

    // Compasso 1: Tríades
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    // Acorde Maior (C-E-G)
    measure1.add(Chord(
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
    ));

    // Acorde menor (D-F-A)
    measure1.add(Chord(
      notes: [
        Note(
          pitch: const Pitch(step: 'D', octave: 4),
          duration: const Duration(DurationType.quarter),
        ),
        Note(
          pitch: const Pitch(step: 'F', octave: 4),
          duration: const Duration(DurationType.quarter),
        ),
        Note(
          pitch: const Pitch(step: 'A', octave: 4),
          duration: const Duration(DurationType.quarter),
        ),
      ],
      duration: const Duration(DurationType.quarter),
    ));

    // Tétrade (G7: G-B-D-F)
    measure1.add(Chord(
      notes: [
        Note(
          pitch: const Pitch(step: 'G', octave: 3),
          duration: const Duration(DurationType.quarter),
        ),
        Note(
          pitch: const Pitch(step: 'B', octave: 3),
          duration: const Duration(DurationType.quarter),
        ),
        Note(
          pitch: const Pitch(step: 'D', octave: 4),
          duration: const Duration(DurationType.quarter),
        ),
        Note(
          pitch: const Pitch(step: 'F', octave: 4),
          duration: const Duration(DurationType.quarter),
        ),
      ],
      duration: const Duration(DurationType.quarter),
    ));

    // Cluster chord (C-D-E)
    measure1.add(Chord(
      notes: [
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
        Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
      ],
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.marcato],
    ));

    staff.add(measure1);

    return SizedBox(
      height: 220,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createTuplets() {
    final staff = Staff();

    // Compasso 1: Tercinas
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    // Tercina de colcheias
    measure1.add(Tuplet(
      actualNotes: 3,
      normalNotes: 2,
      elements: [
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.eighth),
        ),
        Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const Duration(DurationType.eighth),
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 5),
          duration: const Duration(DurationType.eighth),
        ),
      ],
      showBracket: true,
      showNumber: true,
    ));

    // Tercina de semicolcheias
    measure1.add(Tuplet(
      actualNotes: 3,
      normalNotes: 2,
      elements: [
        Note(
          pitch: const Pitch(step: 'F', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
        Note(
          pitch: const Pitch(step: 'G', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
        Note(
          pitch: const Pitch(step: 'A', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
      ],
      showBracket: true,
      showNumber: true,
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'B', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Compasso 2: Quintinas
    final measure2 = Measure();

    measure2.add(Tuplet(
      actualNotes: 5,
      normalNotes: 4,
      elements: [
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
        Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
        Note(
          pitch: const Pitch(step: 'F', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
        Note(
          pitch: const Pitch(step: 'G', octave: 5),
          duration: const Duration(DurationType.sixteenth),
        ),
      ],
      showBracket: true,
      showNumber: true,
    ));

    measure2.add(Rest(duration: const Duration(DurationType.half)));

    staff.add(measure1);
    staff.add(measure2);

    return SizedBox(
      height: 220,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createSlurs() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Frase com slur
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      slur: SlurType.start,
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.quarter),
      slur: SlurType.end,
    ));

    staff.add(measure);

    return SizedBox(
      height: 200,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createTies() {
    final staff = Staff();

    // Compasso 1
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
      tie: TieType.start,
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
      tie: TieType.end,
    ));

    // Compasso 2
    final measure2 = Measure();

    measure2.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
      tie: TieType.start,
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
      tie: TieType.end,
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    staff.add(measure1);
    staff.add(measure2);

    return SizedBox(
      height: 200,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createDynamics() {
    final staff = Staff();

    // Compasso 1: Dinâmicas básicas
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.piano),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'D', octave: 4),
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.mezzoPiano),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.mezzoForte),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.forte),
    ));

    // Compasso 2: Dinâmicas extremas
    final measure2 = Measure();

    measure2.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.pianissimo),
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.fortissimo),
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.sforzando),
    ));

    measure2.add(Rest(duration: const Duration(DurationType.quarter)));

    // Compasso 3: Crescendo e Diminuendo
    final measure3 = Measure();

    measure3.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.whole),
    ));

    // Adicionar crescendo (hairpin)
    measure3.add(Dynamic(
      type: DynamicType.crescendo,
      isHairpin: true,
      length: 150,
    ));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);

    return SizedBox(
      height: 240,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createTempoMarkings() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Adicionar indicação de tempo
    measure.add(TempoMark(
      text: 'Allegro',
      beatUnit: DurationType.quarter,
      bpm: 120,
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

    return SizedBox(
      height: 220,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createRepeats() {
    final staff = Staff();

    // Compasso 1
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    measure1.add(RepeatMark(type: RepeatType.segno));

    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    // Compasso 2
    final measure2 = Measure();

    measure2.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure2.add(RepeatMark(type: RepeatType.coda));

    measure2.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    staff.add(measure1);
    staff.add(measure2);

    return SizedBox(
      height: 220,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }
}
