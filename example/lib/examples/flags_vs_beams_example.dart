import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class FlagsVsBeamsExample extends StatelessWidget {
  const FlagsVsBeamsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemplo: Flags vs Beams'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Controle de Beaming vs Flags',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildExampleSection(
              'Beaming Automático (Padrão)',
              'As notas são automaticamente agrupadas baseado na fórmula de compasso.',
              _createAutomaticBeamingStaff(),
            ),

            _buildExampleSection(
              'Flags Individuais',
              'Todas as notas usam bandeirolas (flags) individuais.',
              _createFlagsOnlyStaff(),
            ),

            _buildExampleSection(
              'Beaming Conservador',
              'Apenas grupos óbvios de 2 notas consecutivas.',
              _createConservativeBeamingStaff(),
            ),

            _buildExampleSection(
              'Forçar Beam em Todas',
              'Agrupa todas as notas possíveis em um único beam.',
              _createForceBeamAllStaff(),
            ),

            _buildExampleSection(
              'Beaming Manual',
              'Grupos personalizados: [0,1,2] e [4,5] (nota 3 com flag individual).',
              _createManualBeamingStaff(),
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

  Staff _createAutomaticBeamingStaff() {
    final staff = Staff();

    // Compasso com beaming automático (padrão)
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.automatic,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Colcheias que serão agrupadas automaticamente
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.eighth)));

    staff.add(measure);
    return staff;
  }

  Staff _createFlagsOnlyStaff() {
    final staff = Staff();

    // Compasso forçando flags individuais
    final measure = Measure(
      autoBeaming: false, // Desabilita beaming
      beamingMode: BeamingMode.forceFlags,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Mesmas colcheias, mas com flags individuais
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.eighth)));

    staff.add(measure);
    return staff;
  }

  Staff _createConservativeBeamingStaff() {
    final staff = Staff();

    // Compasso com beaming conservador
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.conservative,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Mistura de colcheias e semicolcheias
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.sixteenth)));
    measure.add(Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.sixteenth)));
    measure.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.sixteenth)));
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.sixteenth)));

    staff.add(measure);
    return staff;
  }

  Staff _createForceBeamAllStaff() {
    final staff = Staff();

    // Compasso forçando beam em todas as notas
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.forceBeamAll,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Todas as colcheias em um único beam
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.eighth)));
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.eighth)));

    staff.add(measure);
    return staff;
  }

  Staff _createManualBeamingStaff() {
    final staff = Staff();

    // Compasso com beaming manual personalizado
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.manual,
      // Definir grupos manuais:
      // - Grupo 1: notas 0, 1, 2 (primeiras 3 colcheias)
      // - Grupo 2: notas 4, 5 (quinta e sexta colcheias)
      // - Nota 3 fica com flag individual
      // - Notas 6, 7 ficam com flags individuais
      manualBeamGroups: [
        [0, 1, 2], // Primeiro grupo: 3 notas
        [4, 5],    // Segundo grupo: 2 notas
      ],
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // 8 colcheias - agrupamento definido pelos índices acima
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.eighth))); // 0
    measure.add(Note(pitch: const Pitch(step: 'D', octave: 4), duration: const Duration(DurationType.eighth))); // 1
    measure.add(Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.eighth))); // 2
    measure.add(Note(pitch: const Pitch(step: 'F', octave: 4), duration: const Duration(DurationType.eighth))); // 3 - flag individual
    measure.add(Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.eighth))); // 4
    measure.add(Note(pitch: const Pitch(step: 'A', octave: 4), duration: const Duration(DurationType.eighth))); // 5
    measure.add(Note(pitch: const Pitch(step: 'B', octave: 4), duration: const Duration(DurationType.eighth))); // 6 - flag individual
    measure.add(Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.eighth))); // 7 - flag individual

    staff.add(measure);
    return staff;
  }
}
