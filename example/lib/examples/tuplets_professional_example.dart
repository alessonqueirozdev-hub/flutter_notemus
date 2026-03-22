// example/lib/examples/tuplets_professional_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// 🎼 EXEMPLO PROFISSIONAL DE QUIÁLTERAS
/// Baseado em Behind Bars (Elaine Gould)
class TupletsProfessionalExample extends StatelessWidget {
  const TupletsProfessionalExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 Quiálteras Profissionais'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          const SizedBox(height: 24),
          
          _categoryTitle('TEMPO SIMPLES (4/4)'),
          _categoryDesc('Numerador > Denominador (contraentes)'),
          
          _example(1, 'Tercina (3:2)', '3 colcheias no lugar de 2', _triplet()),
          _example(2, 'Quintina (5:4)', '5 semicolcheias no lugar de 4', _quintuplet()),
          _example(3, 'Sextina (6:4)', '6 semicolcheias no lugar de 4', _sextuplet()),
          _example(4, 'Septina (7:4)', '7 semicolcheias no lugar de 4', _septuplet()),
          
          const SizedBox(height: 32),
          _categoryTitle('TEMPO COMPOSTO (6/8)'),
          _categoryDesc('Dupleto (2:3) - quiáltera expansiva'),
          
          _example(5, 'Dupleto (2:3)', '2 colcheias no lugar de 3', _duplet()),
          _example(6, 'Quadrupleto (4:6)', '4 no lugar de 6', _quadruplet()),
          
          const SizedBox(height: 32),
          _categoryTitle('CASOS ESPECIAIS'),
          
          _example(7, 'Irracional (7:5)', 'SEMPRE razão completa!', _irrational(), true),
          _example(8, 'Sem Colchete', 'Quando notas são beamed', _noBracket()),
          _example(9, 'Com Pausas', 'Colchete obrigatório', _withRests()),
          _example(10, 'Semínimas', 'Durações mais longas', _quarters()),
          _example(11, 'Nontupleto (9:8)', '9 fusas no lugar de 8', _nonuplet()),
          
          const SizedBox(height: 24),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Card(
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.music_note, color: Colors.deepPurple.shade700, size: 32),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Quiálteras Profissionais', 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Implementação baseada em "Behind Bars" de Elaine Gould. '
              'Demonstra todas as regras de notação profissional.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTitle(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade700,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _categoryDesc(String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 8),
      child: Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    );
  }

  Widget _example(int num, String title, String desc, Staff staff, [bool highlight = false]) {
    return Card(
      elevation: highlight ? 4 : 2,
      color: highlight ? Colors.amber.shade50 : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: highlight ? Colors.amber.shade700 : Colors.deepPurple,
                  radius: 16,
                  child: Text('$num', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
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

  Widget _footer() {
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '📚 Referências: Behind Bars (Gould), SMuFL, Dorico, Flutter Notemus',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ),
    );
  }

  // === EXEMPLOS ===

  Staff _triplet() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet.triplet(
      elements: [
        Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.eighth)),
        Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.eighth)),
        Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.eighth)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
      bracketConfig: const TupletBracket(show: true, thickness: 0.125),
      numberConfig: const TupletNumber(showAsRatio: false),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _quintuplet() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet.quintuplet(
      elements: [
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.sixteenth)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _sextuplet() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet.sextuplet(
      elements: [
        Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.sixteenth)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _septuplet() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet.septuplet(
      elements: [
        Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.sixteenth)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _duplet() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 6, denominator: 8));
    measure.add(Tuplet.duplet(
      elements: [
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.eighth)),
        Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.eighth)),
      ],
      timeSignature: TimeSignature(numerator: 6, denominator: 8),
      numberConfig: const TupletNumber(showAsRatio: true),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter, dots: 1)));
    staff.add(measure);
    return staff;
  }

  Staff _quadruplet() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 6, denominator: 8));
    measure.add(Tuplet(
      actualNotes: 4,
      normalNotes: 6,
      elements: [
        Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.sixteenth)),
      ],
      timeSignature: TimeSignature(numerator: 6, denominator: 8),
      numberConfig: const TupletNumber(showAsRatio: true),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _irrational() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet(
      actualNotes: 7,
      normalNotes: 5,
      elements: [
        Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.sixteenth)),
        Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.sixteenth)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
      numberConfig: const TupletNumber(showAsRatio: true, fontSize: 1.3),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _noBracket() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet.triplet(
      elements: [
        Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.eighth)),
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.eighth)),
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
      bracketConfig: const TupletBracket(show: false),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _withRests() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet.triplet(
      elements: [
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth)),
        Rest(duration: const Duration(DurationType.eighth)),
        Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.eighth)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
      bracketConfig: const TupletBracket(show: true),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }

  Staff _quarters() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet.triplet(
      elements: [
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.quarter)),
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.quarter)),
        Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.quarter)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
    ));
    staff.add(measure);
    return staff;
  }

  Staff _nonuplet() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Tuplet(
      actualNotes: 9,
      normalNotes: 8,
      elements: [
        Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.thirtySecond)),
        Note(pitch: const Pitch(step: 'D', octave: 5), duration: const Duration(DurationType.thirtySecond)),
      ],
      timeSignature: TimeSignature(numerator: 4, denominator: 4),
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    staff.add(measure);
    return staff;
  }
}
