// example/lib/examples/complete_clefs_demo.dart
// Demonstração completa de todas as claves suportadas

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
              'Demonstração Completa de Claves',
              'Todas as claves implementadas com escalas e armaduras',
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Clave de Sol (G Clef)',
              'Tessitura aguda - Violino, Flauta, Oboé',
              _createTrebleClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Clave de Fá (F Clef)',
              'Tessitura grave - Violoncelo, Contrabaixo, Fagote',
              _createBassClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Clave de Dó Alto (C Clef - Alto)',
              'Tessitura média - Viola',
              _createAltoClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Clave de Dó Tenor (C Clef - Tenor)',
              'Tessitura médio-grave - Trombone, Violoncelo agudo',
              _createTenorClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Claves com Oitavas',
              'Transposições de oitava',
              _createOctaveClefExample(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Comparação de Alturas',
              'Mesma nota em diferentes claves',
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

    // Compasso 1: Clave + Armadura (2 sustenidos) + Fórmula
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(KeySignature(2)); // Ré Maior
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    // Escala de Ré Maior ascendente
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

    // Compasso 2: Continuação da escala
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

    // Compasso 1: Clave de Fá + Armadura (3 bemóis) + Fórmula
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

    // Compasso 2
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

    // Compasso 3
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

    // Compasso 1: Clave de Dó (Alto) + Armadura + Fórmula
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.alto));
    measure1.add(KeySignature(1)); // Sol Maior
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    // Escala de Sol Maior na tessitura de viola
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

    // Compasso 2
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

    // Compasso 1: Clave de Dó (Tenor) + Armadura + Fórmula
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.tenor));
    measure1.add(KeySignature(-2)); // Si♭ Maior
    measure1.add(TimeSignature(numerator: 6, denominator: 8));

    // Padrão melódico em 6/8
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

    // Comparação de claves com oitavas
    // Compasso 1: Sol normal
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));
    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.whole),
    ));

    // Compasso 2: Sol 8va (uma oitava acima)
    final measure2 = Measure();
    measure2.add(Clef(clefType: ClefType.treble8va));
    measure2.add(Note(
      pitch: const Pitch(step: 'C', octave: 6),
      duration: const Duration(DurationType.whole),
    ));

    // Compasso 3: Sol 8vb (uma oitava abaixo)
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
          'Nota Dó Central (C4) em cada clave:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        _createComparisonStaff(ClefType.treble, 'Clave de Sol'),
        const SizedBox(height: 8),
        _createComparisonStaff(ClefType.bass, 'Clave de Fá'),
        const SizedBox(height: 8),
        _createComparisonStaff(ClefType.alto, 'Clave de Dó (Alto)'),
        const SizedBox(height: 8),
        _createComparisonStaff(ClefType.tenor, 'Clave de Dó (Tenor)'),
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
