// example/lib/examples/ornaments_example.dart
// ARQUIVO UNIFICADO E CORRIGIDO

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget that demonstrates the rendering of all musical ornaments,
/// seguindo as regras tipográficas profissionais.
/// This file is the single source of truth for ornament examples.
class OrnamentsExample extends StatelessWidget {
  const OrnamentsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Ornament Guide'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              'SMuFL Ornaments Guide',
              'Demonstration of the correct positioning of ornaments according to professional notation rules.',
            ),
            _buildSection(
              title: 'Core Rule: Single-Voice Positioning',
              description:
                  'In single-voice music, ornaments such as trills and mordants are ALWAYS positioned ABOVE the staff, regardless of the direction of the note stem.',
              staff: _createSingleVoiceStaff(),
            ),
            _buildSection(
              title: 'Polyphony Rule: Multiple Voices',
              description:
              'In staves with multiple voices, ornaments are positioned on the outside: above for the upper voice (soprano) and below for the lower voice (alto).',
              staff: _createDoubleVoiceStaff(),
            ),
            _buildSection(
              title: 'Trilos (Trills)',
              description:
                  'Simple trills and chromatic changes. The positioning is always above in a single voice.',
              staff: _createTrillsStaff(),
            ),
            _buildSection(
              title: 'Mordentes (Mordents)',
              description:
                  'Upper and lower mordents. Positioning follows the same rule as trills.',
              staff: _createMordentsStaff(),
            ),
            _buildSection(
              title: 'Grupetos (Turns)',
              description: 'Simple, inverted, and cut turns.',
              staff: _createTurnsStaff(),
            ),
            _buildSection(
              title: 'Grace Notes e Acciaccaturas (Grace Notes)',
              description:
                  'Ornamental notes that precede the main note. The ligature for the main note is essential.',
              staff: _createGraceNotesStaff(),
            ),
            _buildSection(
              title: 'Fermatas',
              description:
                  'The default fermata is always above. Specific versions like "fermataBelow" are used for explicit bottom positioning.',
              staff: _createFermatasStaff(),
            ),
            _buildSection(
              title: 'Arpeggios and Glissandi',
              description:
                  'Arpeggios are positioned to the left of the chord. Glissandos are represented by lines between notes.',
              staff: _createArpeggiosAndGlissandosStaff(),
            ),
            _buildSection(
              title: 'Articulation Effects (Jazz/Modern)',
              description:
                  'Scoop, Fall, Doit and Plop, common in jazz notation.',
              staff: _createJazzEffectsStaff(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the page header.
  Widget _buildHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  /// Builds an example section with title, description, and score.
  Widget _buildSection({
    required String title,
    required String description,
    required Staff staff,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: MusicScore(
                staff: staff,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Example of the fundamental rule for single voice.
  Staff _createSingleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Note with stem UP -> Ornament UP
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));
    // Note with stem DOWN -> Ornament UP
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));
    // Very low note (stem UP) -> Ornament UP
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 3),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));
    // Very high note (stem DOWN) -> Ornament UP
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.shortTrill)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Example of the rule for multiple voices.
  Staff _createDoubleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 2, denominator: 4));

    // Voice 1 (Soprano) - Rods UP, Ornaments UP
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 1,
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    // Voice 2 (Alto) - Stems DOWN, Ornaments DOWN
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 2,
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Example focused on Trilos.
  Staff _createTrillsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trillSharp)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trillFlat)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.shortTrill)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Example focused on Jaws.
  Staff _createMordentsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.invertedMordent)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordentUpperPrefix)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordentLowerPrefix)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Example focused on Groups.
  Staff _createTurnsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turnInverted)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turnSlash)],
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));

    staff.add(measure);
    return staff;
  }

  /// Example focused on Grace Notes.
  Staff _createGraceNotesStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Acciaccatura (com corte)
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.eighth),
      ornaments: [Ornament(type: OrnamentType.acciaccatura)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Appoggiatura (sem corte)
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.eighth),
      ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    staff.add(measure);
    return staff;
  }

  /// Example focused on Fermatas.
  Staff _createFermatasStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Standard Fermata above
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermata)],
    ));

    // Explicit Fermata below
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermataBelow)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Example focused on Arpeggios and Glissandos.
  Staff _createArpeggiosAndGlissandosStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Arpejo
    measure.add(Chord(
      notes: [
        Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter)),
        Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter)),
        Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.quarter)),
      ],
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.arpeggio)],
    ));

    // Glissando (requires two notes to draw the line)
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.glissando)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure.add(Rest(duration: const Duration(DurationType.quarter)));

    staff.add(measure);
    return staff;
  }

  /// Example focused on jazz and modern music effects.
  Staff _createJazzEffectsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.scoop)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.fall)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.doit)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.plop)],
    ));

    staff.add(measure);
    return staff;
  }
}
