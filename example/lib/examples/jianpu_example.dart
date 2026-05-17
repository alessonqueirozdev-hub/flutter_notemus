import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Jianpu (numbered notation) demo — GB/T 46845-2025 MVP (epic #24).
///
/// Uses [JianpuScore] (sibling of `MusicScore`) to render the same
/// notation-agnostic music model as numbered notation.
class JianpuExample extends StatelessWidget {
  const JianpuExample({super.key});

  static const _accent = Color(0xFFB91C1C);
  static const _jianpuTheme = JianpuTheme(
    color: Color(0xFF111827),
    numeralSize: 24,
  );

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Jianpu (Numbered Notation)',
      subtitle:
          'Numbered notation per GB/T 46845-2025 (MVP): movable-do numerals, '
          'octave dots, accidentals, duration lines/dashes/dots, rests, ties, '
          'and the 1=key header. The SMuFL staff path is untouched.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'C major melody (1=C)',
          description:
              'Diatonic numerals 1–7 with an eighth-note pair (减时线 '
              'underline), a half note (增时线 dash) and a rest (0).',
          accentColor: _accent,
          child: _frame(
            _staff(0, 4, 4, [
              [
                _n('C', 4, DurationType.quarter),
                _n('D', 4, DurationType.quarter),
                _n('E', 4, DurationType.eighth),
                _n('F', 4, DurationType.eighth),
                _n('G', 4, DurationType.quarter),
              ],
              [
                _n('A', 4, DurationType.quarter),
                Rest(duration: const Duration(DurationType.quarter)),
                _n('E', 4, DurationType.half),
              ],
            ]),
          ),
        ),
        ExampleSectionCard(
          title: 'Key 1=G, octave dot and tie',
          description:
              'A two-sharp key signature renders as 1=G; a high D shows an '
              'upper octave dot, and the opening pair is tied.',
          accentColor: _accent,
          child: _frame(
            _staff(1, 4, 4, [
              [
                _n('G', 4, DurationType.quarter, tie: TieType.start),
                _n('G', 4, DurationType.quarter, tie: TieType.end),
                _n('A', 4, DurationType.eighth),
                _n('B', 4, DurationType.eighth),
                _n('D', 5, DurationType.quarter),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  static Note _n(
    String step,
    int octave,
    DurationType type, {
    TieType? tie,
  }) =>
      Note(
        pitch: Pitch(step: step, octave: octave),
        duration: Duration(type),
        tie: tie,
      );

  Widget _frame(Staff staff) => Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: JianpuScore(staff: staff, theme: _jianpuTheme),
      );

  Staff _staff(
    int fifths,
    int numerator,
    int denominator,
    List<List<MusicalElement>> measures,
  ) {
    final staff = Staff();
    for (var i = 0; i < measures.length; i++) {
      final measure = Measure();
      if (i == 0) {
        measure.add(KeySignature(fifths));
        measure.add(
          TimeSignature(numerator: numerator, denominator: denominator),
        );
      }
      for (final element in measures[i]) {
        measure.add(element);
      }
      staff.add(measure);
    }
    return staff;
  }
}
