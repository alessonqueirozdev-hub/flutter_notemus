import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class ProfessionalOrnamentsExample extends StatelessWidget {
  const ProfessionalOrnamentsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ornamentos: Posicionamento Profissional SMuFL'),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Posicionamento Dinâmico de Ornamentos',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Demonstra o posicionamento inteligente baseado em diretrizes SMuFL e padrões profissionais.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _buildExampleSection(
              'Posicionamento Baseado em Haste',
              'Ornamentos posicionados no lado oposto da haste (padrão profissional)',
              _createStemBasedPositioningStaff(),
            ),

            _buildExampleSection(
              'Notas Altas - Ornamentos Embaixo',
              'Notas na região alta automaticamente posicionam ornamentos embaixo',
              _createHighNotesStaff(),
            ),

            _buildExampleSection(
              'Notas Baixas - Ornamentos Acima',
              'Notas na região baixa sempre posicionam ornamentos acima',
              _createLowNotesStaff(),
            ),

            _buildExampleSection(
              'Arpejos - Posicionamento Lateral',
              'Arpejos posicionados à esquerda com altura variável',
              _createArpeggioStaff(),
            ),

            _buildExampleSection(
              'Glissandos - Linhas Dinâmicas',
              'Glissandos renderizados como linhas onduladas',
              _createGlissandoStaff(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleSection(String title, String description, Staff staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: MusicScore(
            staff: staff,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Staff _createStemBasedPositioningStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas na região central - ornamentos no lado oposto da haste
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4), // Haste para cima, trill embaixo
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)], // Sem forçar posição
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4), // Haste para cima, mordente embaixo
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4), // Haste para baixo, trill acima
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5), // Haste para baixo, turn acima
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    staff.add(measure);
    return staff;
  }

  Staff _createHighNotesStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas altas - ornamentos automaticamente embaixo
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // Acima da 5ª linha
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5), // Muito alta
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 6), // Extremamente alta
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    staff.add(measure);
    return staff;
  }

  Staff _createLowNotesStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.bass));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas baixas - ornamentos sempre acima
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 2), // Muito baixa
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 2), // Baixa
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 2), // Região baixa
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    staff.add(measure);
    return staff;
  }

  Staff _createArpeggioStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas com arpejos - posicionamento lateral
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.arpeggio)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.arpeggio)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.arpeggio)],
    ));

    staff.add(measure);
    return staff;
  }

  Staff _createGlissandoStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas com glissandos - linhas onduladas
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.glissando)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.portamento)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.glissando)],
    ));

    staff.add(measure);
    return staff;
  }
}
