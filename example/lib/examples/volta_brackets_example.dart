// example/lib/examples/volta_brackets_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Demonstrates round brackets (first and second round)
class VoltaBracketsExample extends StatelessWidget {
  const VoltaBracketsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volta Brackets (1ª e 2ª Vez)'),
        backgroundColor: Colors.deepOrange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfo(),
            const SizedBox(height: 16),
            _buildSection(
              title: '1ª e 2ª Volta — Finale Fechada',
              description:
                  'First ending (1.) with closed end: the bracket has a vertical line '
                  'vertical no início, no topo e no final. A 2ª volta '
                  'substitui a 1ª na repetição.',
              score: _buildFirstAndSecond(),
            ),
            _buildSection(
              title: '1ª Volta — Final Aberto',
              description:
                  'Press back with hasOpenEnd: true — no vertical line'
                  'no final. Indica que a música continua diretamente '
                  'for repetition without pause.',
              score: _buildOpenEnd(),
            ),
            _buildSection(
              title: 'Três Voltas (1., 2., 3.)',
              description:
                  'Três finais alternativos. Cada repetição usa um '
                  'colchete diferente. Comum em danças e formas estróficas.',
              score: _buildThreeVoltas(),
            ),
            _buildSection(
              title: 'Rótulo Personalizado (1.-3. e 4.)',
              description:
                  'VoltaBracket with custom label. The first ending '
                  '"1.-3." é tocada nas 3 primeiras repetições; '
                  '"4." apenas na última.',
              score: _buildCustomLabel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Card(
      color: Colors.deepOrange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.deepOrange.shade700),
                const SizedBox(width: 8),
                Text(
                  'About Volta Brackets',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Volta brackets (ending brackets) indicate '
              'finais alternativos para seções repetidas. Na primeira vez, '
              'toca-se a passagem sob o colchete "1."; na repetição, '
              'you skip to bracket "2." (or "3.", etc.). '
              'Geralmente aparecem em conjunto com barras de repetição.',
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
              height: 130,
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

  Widget _buildFirstAndSecond() {
    final staff = Staff();

    // Corpo da música (repetido)
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));
    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // 1ª volta (fechada)
    final measure2 = Measure();
    measure2.add(VoltaBracket(number: 1, length: 120.0, hasOpenEnd: false));
    measure2.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure2.add(Barline(type: BarlineType.repeatBackward));

    // 2ª volta (fechada)
    final measure3 = Measure();
    measure3.add(VoltaBracket(number: 2, length: 120.0, hasOpenEnd: false));
    measure3.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure3.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.whole),
    ));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);
    return MusicScore(staff: staff);
  }

  Widget _buildOpenEnd() {
    final staff = Staff();

    // Corpo com barra de repetição
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 3, denominator: 4));
    measure1.add(Barline(type: BarlineType.repeatForward));
    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));

    // 1ª volta com final ABERTO
    final measure2 = Measure();
    measure2.add(VoltaBracket(number: 1, length: 120.0, hasOpenEnd: true));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
    ));
    measure2.add(Barline(type: BarlineType.repeatBackward));

    // 2ª volta
    final measure3 = Measure();
    measure3.add(VoltaBracket(number: 2, length: 120.0, hasOpenEnd: false));
    measure3.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.whole),
    ));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);
    return MusicScore(staff: staff);
  }

  Widget _buildThreeVoltas() {
    final staff = Staff();

    // Corpo
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 2, denominator: 4));
    measure1.add(Barline(type: BarlineType.repeatForward));
    measure1.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // 1ª volta
    final measure2 = Measure();
    measure2.add(VoltaBracket(number: 1, length: 80.0, hasOpenEnd: false));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure2.add(Barline(type: BarlineType.repeatBackward));

    // 2ª volta
    final measure3 = Measure();
    measure3.add(VoltaBracket(number: 2, length: 80.0, hasOpenEnd: false));
    measure3.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure3.add(Barline(type: BarlineType.repeatBackward));

    // 3ª volta
    final measure4 = Measure();
    measure4.add(VoltaBracket(number: 3, length: 80.0, hasOpenEnd: false));
    measure4.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);
    staff.add(measure4);
    return MusicScore(staff: staff);
  }

  Widget _buildCustomLabel() {
    final staff = Staff();

    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));
    measure1.add(Barline(type: BarlineType.repeatForward));
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
      duration: const Duration(DurationType.quarter),
    ));
    measure1.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Volta 1-3 (label personalizado)
    final measure2 = Measure();
    measure2.add(VoltaBracket(
      number: 1,
      length: 130.0,
      hasOpenEnd: false,
      label: '1.-3.',
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    measure2.add(Barline(type: BarlineType.repeatBackward));

    // Volta 4 (final definitivo)
    final measure3 = Measure();
    measure3.add(VoltaBracket(
      number: 4,
      length: 130.0,
      hasOpenEnd: false,
      label: '4.',
    ));
    measure3.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.whole),
    ));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);
    return MusicScore(staff: staff);
  }
}
