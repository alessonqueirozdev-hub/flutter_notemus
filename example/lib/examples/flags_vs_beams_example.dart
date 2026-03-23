import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class FlagsVsBeamsExample extends StatelessWidget {
  const FlagsVsBeamsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example: Flags vs Beams'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Beaming vs Flags Control',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildExampleSection(
              'Automatic Beaming (Default)',
              'Notes are automatically grouped based on the time signature.',
              _createAutomaticBeamingStaff(),
            ),

            _buildExampleSection(
              'Flags Individuais',
              'All notes use individual flags.',
              _createFlagsOnlyStaff(),
            ),

            _buildExampleSection(
              'Beaming Conservador',
              'Just obvious groups of 2 consecutive notes.',
              _createConservativeBeamingStaff(),
            ),

            _buildExampleSection(
              'Force Beam on All',
              'Groups all possible notes into a single beam.',
              _createForceBeamAllStaff(),
            ),

            _buildExampleSection(
              'Beaming Manual',
              'Custom groups: [0,1,2] and [4,5] (note 3 with individual flag).',
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

    // Compass with automatic beaming (default)
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.automatic,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Eighth notes that will be grouped automatically
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

    // Compass forcing individual flags
    final measure = Measure(
      autoBeaming: false, // Desabilita beaming
      beamingMode: BeamingMode.forceFlags,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Mesmas eighth notes, mas com flags individuais
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

    // Compass with conservative beaming
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.conservative,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Mistura de eighth notes e semieighth notes
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

    // Measure forcing beam on all notes
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.forceBeamAll,
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Todas as eighth notes em um único beam
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

    // Compass with custom manual beaming
    final measure = Measure(
      autoBeaming: true,
      beamingMode: BeamingMode.manual,
      // Definir grupos manuais:
      // - Grupo 1: notas 0, 1, 2 (primeiras 3 eighth notes)
      // - Grupo 2: notas 4, 5 (quinta e sexta eighth notes)
      // - Nota 3 fica com flag individual
      // - Notas 6, 7 ficam com flags individuais
      manualBeamGroups: [
        [0, 1, 2], // Primeiro grupo: 3 notas
        [4, 5],    // Segundo grupo: 2 notas
      ],
    );

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // 8 eighth notes - grouping defined by the indices above
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
