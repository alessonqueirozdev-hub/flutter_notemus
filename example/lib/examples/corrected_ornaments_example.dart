import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Exemplo demonstrando posicionamento correto dos ornamentos
/// seguindo regras tipográficas profissionais de notação musical
class CorrectedOrnamentsExample extends StatelessWidget {
  const CorrectedOrnamentsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ornamentos: Posicionamento Tipográfico Correto'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Posicionamento Tipográfico Correto',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Demonstra a implementação das regras tipográficas profissionais para ornamentos musicais.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _buildExampleSection(
              'REGRA CORRETA: Ornamentos SEMPRE Acima',
              'TODOS os ornamentos ficam ACIMA, independente da direção da haste',
              _createSingleVoiceStaff(),
            ),

            _buildExampleSection(
              'Vozes Duplas - Soprano e Contralto',
              'Soprano: ornamentos acima (externa superior) | Contralto: ornamentos abaixo (externa inferior)',
              _createDoubleVoiceStaff(),
            ),

            _buildExampleSection(
              'Notas Extremas - Região Alta',
              'Notas na região alta do pentagrama com ornamentos corretos',
              _createHighRegionStaff(),
            ),

            _buildExampleSection(
              'Notas Extremas - Região Baixa',
              'Notas na região baixa do pentagrama com ornamentos corretos',
              _createLowRegionStaff(),
            ),

            _buildExampleSection(
              'Fermatas Especiais',
              'Fermatas acima e abaixo conforme especificação tipográfica',
              _createFermataStaff(),
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

  /// Voz única - todos os ornamentos devem ficar acima
  Staff _createSingleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // DEMONSTRAÇÃO DA REGRA CORRETA:
    // TODAS as notas têm ornamentos ACIMA, independente da direção da haste

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4), // Haste para CIMA → ornamento ACIMA ✓
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4), // Haste para CIMA → ornamento ACIMA ✓
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4), // Haste para BAIXO → ornamento ACIMA ✓
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5), // Haste para BAIXO → ornamento ACIMA ✓
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.shortTrill)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Vozes duplas - soprano acima, contralto abaixo
  Staff _createDoubleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Voz 1 - Soprano (ornamentos acima)
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 1, // Soprano
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 1, // Soprano
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    // Voz 2 - Contralto (ornamentos abaixo)
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 2, // Contralto
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 2, // Contralto
      ornaments: [Ornament(type: OrnamentType.invertedMordent)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Notas na região alta
  Staff _createHighRegionStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas altas - ornamentos devem ficar acima (externa superior)
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // 5ª linha
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5), // Acima da pauta
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 6), // Muito acima da pauta
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Notas na região baixa
  Staff _createLowRegionStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.bass));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Notas baixas - ornamentos devem ficar acima (externa superior)
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

  /// Fermatas especiais
  Staff _createFermataStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Fermata padrão (sempre acima)
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermata)],
    ));

    // Fermata explicitamente abaixo
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermataBelow)],
    ));

    staff.add(measure);
    return staff;
  }
}
