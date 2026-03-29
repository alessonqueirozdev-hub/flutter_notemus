import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

class OrnamentsExample extends StatelessWidget {
  const OrnamentsExample({super.key});

  static const _accent = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Ornaments and Expressive Signs',
      subtitle:
          'A cleaner ornament gallery covering the core public cases: upper placement, polyphonic distribution, grace-note entry, fermatas, and arpeggiated chords.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'Single-Voice Placement',
          description:
              'In a single line, trills, mordents, and turns remain clearly above the staff, independent of stem direction.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _singleVoiceStaff(),
            accentColor: _accent,
            minHeight: 220,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Polyphonic Placement',
          description:
              'When two voices share a staff, the ornament follows the outside voice so the page stays readable for both layers.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _polyphonicStaff(),
            accentColor: _accent,
            minHeight: 220,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Grace Notes and Fermatas',
          description:
              'This pass checks that compact grace entries and fermatas coexist without vertical crowding inside the same measure.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _graceAndFermataStaff(),
            accentColor: _accent,
            minHeight: 235,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Arpeggios and Glissandi',
          description:
              'Arpeggio signs stay visually attached to the chord cluster while slide-style ornaments continue to read as directional connections.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _arpeggioAndGlissStaff(),
            accentColor: _accent,
            minHeight: 235,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Jazz and Modern Effects',
          description:
              'Scoop, fall, doit, and plop remain available in the public gallery without duplicating older internal demo sections.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _jazzEffectsStaff(),
            accentColor: _accent,
            minHeight: 220,
            staffSpace: 16.5,
          ),
        ),
      ],
    );
  }

  Staff _singleVoiceStaff() {
    return _buildStaff([
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.trill)],
      ),
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.mordent)],
      ),
      Note(
        pitch: const Pitch(step: 'D', octave: 3),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.turn)],
      ),
      Note(
        pitch: const Pitch(step: 'A', octave: 5),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.shortTrill)],
      ),
    ]);
  }

  Staff _polyphonicStaff() {
    return _buildStaff([
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.quarter),
        voice: 1,
        ornaments: [Ornament(type: OrnamentType.trill)],
      ),
      Note(
        pitch: const Pitch(step: 'F', octave: 4),
        duration: const Duration(DurationType.quarter),
        voice: 2,
        ornaments: [Ornament(type: OrnamentType.mordent)],
      ),
      Note(
        pitch: const Pitch(step: 'B', octave: 4),
        duration: const Duration(DurationType.quarter),
        voice: 1,
        ornaments: [Ornament(type: OrnamentType.turnInverted)],
      ),
      Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
        voice: 2,
        ornaments: [Ornament(type: OrnamentType.mordentLowerPrefix)],
      ),
    ]);
  }

  Staff _graceAndFermataStaff() {
    return _buildStaff([
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const Duration(DurationType.eighth),
        ornaments: [Ornament(type: OrnamentType.acciaccatura)],
      ),
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
      Note(
        pitch: const Pitch(step: 'F', octave: 5),
        duration: const Duration(DurationType.eighth),
        ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
      ),
      Note(
        pitch: const Pitch(step: 'E', octave: 5),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.fermata)],
      ),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.half),
        ornaments: [Ornament(type: OrnamentType.fermataBelow)],
      ),
    ]);
  }

  Staff _arpeggioAndGlissStaff() {
    return _buildStaff([
      Clef(clefType: ClefType.treble),
      Chord(
        notes: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
          Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        ],
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.arpeggio)],
      ),
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.glissando)],
      ),
      Note(
        pitch: const Pitch(step: 'G', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
      Rest(duration: const Duration(DurationType.quarter)),
    ]);
  }

  Staff _jazzEffectsStaff() {
    return _buildStaff([
      Clef(clefType: ClefType.treble),
      Note(
        pitch: const Pitch(step: 'C', octave: 4),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.scoop)],
      ),
      Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.fall)],
      ),
      Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.doit)],
      ),
      Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.plop)],
      ),
    ]);
  }

  Staff _buildStaff(List<MusicalElement> elements) {
    final staff = Staff();
    final measure = Measure();
    for (final element in elements) {
      measure.add(element);
    }
    staff.add(measure);
    return staff;
  }
}
