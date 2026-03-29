import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

class ArticulationsExample extends StatelessWidget {
  const ArticulationsExample({super.key});

  static const _accent = Color(0xFF0EA5E9);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Articulations',
      subtitle:
          'A concise articulation gallery centered on stem-aware placement and readable contrast inside the public showcase.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'Stem-Down Notes',
          description:
              'Staccato, accent, tenuto, and marcato remain above the notehead when the stems point downward.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.staccato],
              ),
              Note(
                pitch: const Pitch(step: 'D', octave: 5),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.accent],
              ),
              Note(
                pitch: const Pitch(step: 'E', octave: 5),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.tenuto],
              ),
              Note(
                pitch: const Pitch(step: 'F', octave: 5),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.marcato],
              ),
            ]),
            accentColor: _accent,
            minHeight: 205,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Stem-Up Notes',
          description:
              'The same articulation family flips below the notehead when the stem rises, keeping the note field clean.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.staccato],
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.accent],
              ),
              Note(
                pitch: const Pitch(step: 'F', octave: 4),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.tenuto],
              ),
              Note(
                pitch: const Pitch(step: 'E', octave: 4),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.marcato],
              ),
            ]),
            accentColor: _accent,
            minHeight: 205,
            staffSpace: 16.5,
          ),
        ),
        ExampleSectionCard(
          title: 'Mixed Accent Phrase',
          description:
              'A short phrase with varied accents makes it easier to compare spacing and articulation hierarchy in one glance.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.eighth),
                articulations: const [ArticulationType.staccatissimo],
              ),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.eighth),
                articulations: const [ArticulationType.accent],
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.tenuto],
              ),
              Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.quarter),
                articulations: const [ArticulationType.marcato],
              ),
              Rest(duration: const Duration(DurationType.quarter)),
            ]),
            accentColor: _accent,
            minHeight: 220,
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
}
