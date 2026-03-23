import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Example demonstrating correct placement of ornaments
/// following professional typographic rules for music notation
class CorrectedOrnamentsExample extends StatelessWidget {
  const CorrectedOrnamentsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ornaments: Correct Typographic Positioning'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Correct Typographic Positioning',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Demonstrates the implementation of professional typographic rules for musical ornaments.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _buildExampleSection(
              'CORRECT RULE: Ornaments ALWAYS Above',
              'ALL ornaments are UP, regardless of stem direction',
              _createSingleVoiceStaff(),
            ),

            _buildExampleSection(
              'Double Voices - Soprano and Alto',
              'Soprano: ornaments above (top exterior) | Alto: ornaments below (lower exterior)',
              _createDoubleVoiceStaff(),
            ),

            _buildExampleSection(
              'Extreme Notes - Upper Region',
              'Notes in the upper region of the pentagram with correct ornaments',
              _createHighRegionStaff(),
            ),

            _buildExampleSection(
              'Extreme Notes - Lower Region',
              'Notes in the lower region of the pentagram with correct ornaments',
              _createLowRegionStaff(),
            ),

            _buildExampleSection(
              'Special Fermatas',
              'Fermatas above and below according to typographic specification',
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

  /// Single voice - all ornaments must be above
  Staff _createSingleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // DEMONSTRATION OF THE CORRECT RULE:
    // ALL notes have ABOVE ornaments, regardless of stem direction

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

  /// Double voices - soprano above, alto below
  Staff _createDoubleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Voice 1 - Soprano (ornaments above)
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

    // Voice 2 - Alto (ornaments below)
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 2, // Alto
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 2, // Alto
      ornaments: [Ornament(type: OrnamentType.invertedMordent)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Notes in the high register
  Staff _createHighRegionStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // High notes - ornaments should be above (upper outer)
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // 5ª linha
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5), // Above the staff
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

  /// Notes in the low register
  Staff _createLowRegionStaff() {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.bass));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Low notes - ornaments should be above (upper outer)
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
      pitch: const Pitch(step: 'G', octave: 2), // Low register
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

    // Standard Fermata (always above)
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermata)],
    ));

    // Fermata explicitly below
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermataBelow)],
    ));

    staff.add(measure);
    return staff;
  }
}
