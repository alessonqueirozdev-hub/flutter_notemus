import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

class SlursTiesExample extends StatelessWidget {
  const SlursTiesExample({super.key});

  static const _accent = Color(0xFF0F4C81);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Slurs and Ties',
      subtitle:
          'Focused phrase examples that highlight the final v2.5.1 slur endpoints, cleaner tie geometry, and chord tie rendering.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'Single-Note Ties',
          description:
              'Ties stay attached to the notehead surface and keep a stable curvature even when the notehead duration changes.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'C', octave: 4),
                duration: const Duration(DurationType.quarter),
                tie: TieType.start,
              ),
              Note(
                pitch: const Pitch(step: 'C', octave: 4),
                duration: const Duration(DurationType.quarter),
                tie: TieType.end,
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.half),
                tie: TieType.start,
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
                tie: TieType.end,
              ),
            ]),
            accentColor: _accent,
            minHeight: 205,
          ),
        ),
        ExampleSectionCard(
          title: 'Stepwise Phrase Slurs',
          description:
              'Short slurs now connect from notehead to notehead instead of collapsing onto stem anchors on the final note.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'F', octave: 4),
                duration: const Duration(DurationType.quarter),
                slur: SlurType.start,
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: const Duration(DurationType.quarter),
                slur: SlurType.end,
              ),
            ]),
            accentColor: _accent,
            minHeight: 205,
          ),
        ),
        ExampleSectionCard(
          title: 'Long Phrase Slurs',
          description:
              'Longer slurs preserve a cleaner arc without crossing the stem field in the middle of the phrase.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.eighth),
                slur: SlurType.start,
              ),
              Note(
                pitch: const Pitch(step: 'D', octave: 5),
                duration: const Duration(DurationType.eighth),
              ),
              Note(
                pitch: const Pitch(step: 'E', octave: 5),
                duration: const Duration(DurationType.eighth),
              ),
              Note(
                pitch: const Pitch(step: 'F', octave: 5),
                duration: const Duration(DurationType.eighth),
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 5),
                duration: const Duration(DurationType.eighth),
              ),
              Note(
                pitch: const Pitch(step: 'A', octave: 5),
                duration: const Duration(DurationType.eighth),
                slur: SlurType.end,
              ),
            ]),
            accentColor: _accent,
            minHeight: 210,
          ),
        ),
        ExampleSectionCard(
          title: 'Ties in Chords',
          description:
              'Chord ties are rendered per matching pitch, so stacked voices now show individual ties instead of leaving the chord connection empty.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Chord(
                notes: [
                  Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    tie: TieType.start,
                  ),
                  Note(
                    pitch: const Pitch(step: 'E', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    tie: TieType.start,
                  ),
                  Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    tie: TieType.start,
                  ),
                ],
                duration: const Duration(DurationType.quarter),
              ),
              Chord(
                notes: [
                  Note(
                    pitch: const Pitch(step: 'C', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    tie: TieType.end,
                  ),
                  Note(
                    pitch: const Pitch(step: 'E', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    tie: TieType.end,
                  ),
                  Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    tie: TieType.end,
                  ),
                ],
                duration: const Duration(DurationType.quarter),
              ),
              Rest(duration: const Duration(DurationType.half)),
            ]),
            accentColor: _accent,
            minHeight: 210,
          ),
        ),
        ExampleSectionCard(
          title: 'Chord Slurs',
          description:
              'Expression slurs can span chords as well, using the selected notehead inside each stack instead of treating the whole chord as a single anchor box.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Chord(
                notes: [
                  Note(
                    pitch: const Pitch(step: 'F', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    slur: SlurType.start,
                  ),
                  Note(
                    pitch: const Pitch(step: 'A', octave: 4),
                    duration: const Duration(DurationType.quarter),
                  ),
                  Note(
                    pitch: const Pitch(step: 'C', octave: 5),
                    duration: const Duration(DurationType.quarter),
                  ),
                ],
                duration: const Duration(DurationType.quarter),
              ),
              Chord(
                notes: [
                  Note(
                    pitch: const Pitch(step: 'G', octave: 4),
                    duration: const Duration(DurationType.quarter),
                    slur: SlurType.end,
                  ),
                  Note(
                    pitch: const Pitch(step: 'B', octave: 4),
                    duration: const Duration(DurationType.quarter),
                  ),
                  Note(
                    pitch: const Pitch(step: 'D', octave: 5),
                    duration: const Duration(DurationType.quarter),
                  ),
                ],
                duration: const Duration(DurationType.quarter),
              ),
              Rest(duration: const Duration(DurationType.half)),
            ]),
            accentColor: _accent,
            minHeight: 210,
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
