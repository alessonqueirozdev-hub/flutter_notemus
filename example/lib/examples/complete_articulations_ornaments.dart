// example/lib/examples/complete_articulations_ornaments.dart
// Demonstração completa de articulações e ornamentos

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class CompleteArticulationsOrnamentsExample extends StatelessWidget {
  const CompleteArticulationsOrnamentsExample({super.key});

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
              'Articulações e Ornamentos Completos',
              'Demonstração de todos os símbolos de expressão musical',
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Articulações Básicas',
              'Staccato, Accent, Tenuto, Marcato',
              _createBasicArticulations(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Articulações para Cordas',
              'Arco para cima/baixo, Pizzicato, Harmônicos',
              _createStringArticulations(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Ornamentos Barrocos',
              'Trinos, Mordentes, Grupetos',
              _createBaroqueOrnaments(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Ornamentos Modernos',
              'Glissando, Bends, Slides',
              _createModernOrnaments(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Fermatas e Pausas de Respiração',
              'Diferentes tipos de fermatas',
              _createFermatasAndBreaths(),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'Combinações Complexas',
              'Múltiplas articulações e ornamentos',
              _createComplexCombinations(),
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
            color: Colors.purple,
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

  Widget _createBasicArticulations() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Staccato
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.staccato],
    ));

    // Accent
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.accent],
    ));

    // Tenuto
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.tenuto],
    ));

    // Marcato
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.marcato],
    ));

    staff.add(measure);

    return SizedBox(
      height: 180,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createStringArticulations() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Arco para cima
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.upBow],
    ));

    // Arco para baixo
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.downBow],
    ));

    // Harmônicos
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.harmonics],
    ));

    // Pizzicato
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.pizzicato],
    ));

    staff.add(measure);

    return SizedBox(
      height: 180,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createBaroqueOrnaments() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(KeySignature(2));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Trino
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    // Mordente
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    // Grupeto
    measure.add(Note(
      pitch: Pitch.withAccidental(step: 'F', octave: 5, accidentalType: AccidentalType.sharp),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
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

  Widget _createModernOrnaments() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Glissando
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.glissando)],
    ));

    // Scoop
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.scoop)],
    ));

    // Fall
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.fall)],
    ));

    // Doit
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.doit)],
    ));

    staff.add(measure);

    return SizedBox(
      height: 180,
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
      ),
    );
  }

  Widget _createFermatasAndBreaths() {
    final staff = Staff();

    // Compasso 1: Fermatas
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(TimeSignature(numerator: 4, denominator: 4));

    measure1.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermata)],
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Marca de respiração
    measure1.add(Breath(type: BreathType.comma));

    measure1.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Compasso 2: Caesura
    final measure2 = Measure();
    measure2.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    measure2.add(Caesura(type: BreathType.longCaesura));

    measure2.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
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

  Widget _createComplexCombinations() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(KeySignature(3));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Nota com trino + staccato
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.staccato],
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    // Nota com acento + mordente
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.accent],
      ornaments: [Ornament(type: OrnamentType.invertedMordent)],
    ));

    // Nota com tenuto + grupeto
    measure.add(Note(
      pitch: Pitch.withAccidental(step: 'C', octave: 5, accidentalType: AccidentalType.sharp),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.tenuto],
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    // Nota com fermata + marcato
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
      articulations: [ArticulationType.marcato],
      ornaments: [Ornament(type: OrnamentType.fermata)],
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
}
