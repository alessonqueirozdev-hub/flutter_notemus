import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

class TupletsExample extends StatelessWidget {
  const TupletsExample({super.key});

  static const _accent = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Tuplets and Irregular Groupings',
      subtitle:
          'A smaller public gallery focused on clean tuplet spacing, readable numbers, and brackets that stay out of the note and beam field.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'Triplet (3:2)',
          description:
              'Three eighth notes grouped in the time of two, with a bracket and number that sit above the stem field instead of colliding with it.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Tuplet.triplet(
                elements: [
                  Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.eighth),
                  ),
                  Note(
                    pitch: const Pitch(step: 'D', octave: 4),
                    duration: const Duration(DurationType.eighth),
                  ),
                  Note(
                    pitch: const Pitch(step: 'E', octave: 4),
                    duration: const Duration(DurationType.eighth),
                  ),
                ],
                bracketConfig: const TupletBracket(show: true),
                numberConfig: const TupletNumber(),
              ),
              Rest(duration: const Duration(DurationType.half)),
            ]),
            accentColor: _accent,
            minHeight: 210,
          ),
        ),
        ExampleSectionCard(
          title: 'Quintuplet (5:4)',
          description:
              'Five sixteenth notes sharing one grouping. This section helps validate that the bracket and number keep a safe clearance over multiple beams.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Tuplet.quintuplet(
                elements: [
                  Note(
                    pitch: const Pitch(step: 'F', octave: 4),
                    duration: const Duration(DurationType.sixteenth),
                  ),
                  Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.sixteenth),
                  ),
                  Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.sixteenth),
                  ),
                  Note(
                    pitch: const Pitch(step: 'B', octave: 4),
                    duration: const Duration(DurationType.sixteenth),
                  ),
                  Note(
                    pitch: const Pitch(step: 'C', octave: 5),
                    duration: const Duration(DurationType.sixteenth),
                  ),
                ],
                bracketConfig: const TupletBracket(show: true),
                numberConfig: const TupletNumber(),
              ),
              Rest(duration: const Duration(DurationType.quarter)),
            ]),
            accentColor: _accent,
            minHeight: 220,
          ),
        ),
        ExampleSectionCard(
          title: 'Tuplets with Rests',
          description:
              'A mixed grouping verifies that the bracket spans the whole rhythmic idea, even when one subdivision is silent.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Tuplet.triplet(
                elements: [
                  Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.eighth),
                  ),
                  Rest(duration: const Duration(DurationType.eighth)),
                  Note(
                    pitch: const Pitch(step: 'B', octave: 4),
                    duration: const Duration(DurationType.eighth),
                  ),
                ],
                bracketConfig: const TupletBracket(show: true),
                numberConfig: const TupletNumber(),
              ),
              Rest(duration: const Duration(DurationType.half)),
            ]),
            accentColor: _accent,
            minHeight: 205,
          ),
        ),
        ExampleSectionCard(
          title: 'Duplet (2:3)',
          description:
              'The inverted ratio remains legible with the bracket lifted away from the noteheads, which is especially important in narrow public examples.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Tuplet.duplet(
                elements: [
                  Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.eighth),
                  ),
                  Note(
                    pitch: const Pitch(step: 'C', octave: 5),
                    duration: const Duration(DurationType.eighth),
                  ),
                ],
                bracketConfig: const TupletBracket(show: true),
                numberConfig: const TupletNumber(),
              ),
              Rest(duration: const Duration(DurationType.half)),
            ]),
            accentColor: _accent,
            minHeight: 205,
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
}
