import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

class GraceNotesExample extends StatelessWidget {
  const GraceNotesExample({super.key});

  static const _accent = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Grace Notes and Appoggiaturas',
      subtitle:
          'Compact showcases focused on the final grace-note geometry in v2.5.1: short slurs, cleaner stem avoidance, accidentals, and chord resolutions.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'Upward and Downward Appoggiaturas',
          description:
              'The mini-slur now follows the grace-note stem direction and attaches to the notehead surface instead of drifting across the stem.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: const Duration(DurationType.eighth),
                ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
              ),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
              Note(
                pitch: const Pitch(step: 'F', octave: 4),
                duration: const Duration(DurationType.eighth),
                ornaments: [Ornament(type: OrnamentType.appoggiaturaDown)],
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
              Note(
                pitch: const Pitch(step: 'D', octave: 5),
                duration: const Duration(DurationType.eighth),
                ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
              ),
              Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.quarter),
              ),
            ]),
            accentColor: _accent,
            minHeight: 225,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Acciaccaturas with Chromatic Lead-In',
          description:
              'Short crushed notes stay compact and the accidental keeps a tighter, SMuFL-aware distance from the tiny grace note.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(
                  step: 'D',
                  octave: 5,
                  alter: -1,
                  accidentalType: AccidentalType.flat,
                ),
                duration: const Duration(DurationType.sixteenth),
                ornaments: [Ornament(type: OrnamentType.acciaccatura)],
              ),
              Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.quarter),
              ),
              Note(
                pitch: const Pitch(
                  step: 'F',
                  octave: 4,
                  alter: 1,
                  accidentalType: AccidentalType.sharp,
                ),
                duration: const Duration(DurationType.sixteenth),
                ornaments: [Ornament(type: OrnamentType.acciaccatura)],
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: const Duration(DurationType.sixteenth),
                ornaments: [Ornament(type: OrnamentType.acciaccatura)],
              ),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            ]),
            accentColor: _accent,
            minHeight: 225,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Grace Notes Resolving into Chords',
          description:
              'Chord entries keep the grace connection anchored to the leading notehead, while the arpeggio sign stays visually aligned with the chord cluster.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
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
                ornaments: [
                  Ornament(type: OrnamentType.acciaccatura),
                  Ornament(type: OrnamentType.arpeggio),
                ],
              ),
              Chord(
                notes: [
                  Note(
                    pitch: const Pitch(step: 'D', octave: 4),
                    duration: const Duration(DurationType.quarter),
                  ),
                  Note(
                    pitch: const Pitch(step: 'F', octave: 4),
                    duration: const Duration(DurationType.quarter),
                  ),
                  Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.quarter),
                  ),
                ],
                duration: const Duration(DurationType.quarter),
              ),
              Rest(duration: const Duration(DurationType.half)),
            ]),
            accentColor: _accent,
            minHeight: 240,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Phrase Context',
          description:
              'A short phrase that mixes grace-note entrances and regular note values, giving a more realistic reading of spacing and ornament balance.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaffWithMeasures([
              [
                Clef(clefType: ClefType.treble),
                TimeSignature(numerator: 4, denominator: 4),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.appoggiaturaDown)],
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.sixteenth),
                  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
              ],
              [
                Note(
                  pitch: const Pitch(step: 'C', octave: 5),
                  duration: const Duration(DurationType.eighth),
                  ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
                ),
                Note(
                  pitch: const Pitch(step: 'B', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                ),
              ],
            ]),
            accentColor: _accent,
            minHeight: 245,
            staffSpace: 16.5,
          ),
        ),
      ],
    );
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

  Staff _buildStaffWithMeasures(List<List<MusicalElement>> measures) {
    final staff = Staff();
    for (final elements in measures) {
      final measure = Measure();
      for (final element in elements) {
        measure.add(element);
      }
      staff.add(measure);
    }
    return staff;
  }
}
