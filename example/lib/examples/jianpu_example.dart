import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Jianpu (numbered notation) demo — GB/T 46845-2025 (epic #24).
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
          'Numbered notation per GB/T 46845-2025: movable-do numerals, octave '
          'dots, diatonic accidentals, beat-grouped underlines, augmentation '
          'dashes/dots, lyrics, ties, tuplets, repeats and the 1=key header. '
          'The SMuFL staff path is untouched.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'A song with lyrics (1=C)',
          description:
              '“Twinkle, Twinkle” — numerals 1–7, half notes as 增时线 dashes, '
              'and a syllable centered under each numeral.',
          accentColor: _accent,
          child: _frame(
            _staff(0, 4, 4, [
              [_l('C', 4, 'q', 'Twin'), _l('C', 4, 'q', 'kle'),
                _l('G', 4, 'q', 'twin'), _l('G', 4, 'q', 'kle')],
              [_l('A', 4, 'q', 'lit'), _l('A', 4, 'q', 'tle'),
                _l('G', 4, 'h', 'star')],
              [_l('F', 4, 'q', 'How'), _l('F', 4, 'q', 'I'),
                _l('E', 4, 'q', 'won'), _l('E', 4, 'q', 'der')],
              [_l('D', 4, 'q', 'what'), _l('D', 4, 'q', 'you'),
                _l('C', 4, 'h', 'are')],
            ]),
          ),
        ),
        ExampleSectionCard(
          title: 'Beamed eighths, tie & repeat (1=G)',
          description:
              'Two-sharp key renders as 1=G. Eighths in the same beat share a '
              'continuous 减时线 underline; the opening pair is tied; the '
              'phrase is wrapped in repeat barlines.',
          accentColor: _accent,
          child: _frame(
            _staffRaw(1, 4, 4, [
              [
                Barline(type: BarlineType.repeatForward),
                _n('G', 4, 'q', tie: TieType.start),
                _n('G', 4, 'q', tie: TieType.end),
                _n('A', 4, 'e'), _n('B', 4, 'e'),
                _n('A', 4, 'e'), _n('G', 4, 'e'),
                Barline(type: BarlineType.repeatBackward),
              ],
            ]),
          ),
        ),
        ExampleSectionCard(
          title: 'Triplet (连音符) and octave dots',
          description:
              'A 3:2 eighth-note triplet draws a bracket with the ratio number; '
              'the high D shows an upper octave dot.',
          accentColor: _accent,
          child: _frame(
            _staffRaw(0, 4, 4, [
              [
                Tuplet.triplet(
                  elements: [
                    _n('C', 5, 'e'),
                    _n('D', 5, 'e'),
                    _n('E', 5, 'e'),
                  ],
                ),
                _n('G', 4, 'q'),
                _n('E', 4, 'h'),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  static Duration _d(String t) => switch (t) {
        'h' => const Duration(DurationType.half),
        'e' => const Duration(DurationType.eighth),
        _ => const Duration(DurationType.quarter),
      };

  static Note _n(String step, int octave, String t, {TieType? tie}) => Note(
        pitch: Pitch(step: step, octave: octave),
        duration: _d(t),
        tie: tie,
      );

  static Note _l(String step, int octave, String t, String syllable) => Note(
        pitch: Pitch(step: step, octave: octave),
        duration: _d(t),
        syllables: [Syllable(text: syllable, type: SyllableType.single)],
      );

  Widget _frame(Staff staff) => Container(
        height: 230,
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
    List<List<Note>> measures,
  ) =>
      _staffRaw(
        fifths,
        numerator,
        denominator,
        measures.map((m) => m.cast<MusicalElement>()).toList(),
      );

  Staff _staffRaw(
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
