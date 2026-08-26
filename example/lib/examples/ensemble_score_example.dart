import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// A whole `Score` — several `StaffGroup`s at once — drawn by `ScoreView`.
///
/// The gallery had a grand-staff page (one group, two staves) but nothing for
/// the case that actually needs a Score: a choir bracketed above a piano
/// brace, where the two groups have different staff counts, different meters
/// of activity, and one shared horizontal grid.
///
/// This is also what issue #7 asked for under the name "MultiStaffRenderer".
/// It exists as `ScoreView`; what was missing was anywhere to see it.
class EnsembleScoreExample extends StatelessWidget {
  const EnsembleScoreExample({super.key});

  static const _accent = Color(0xFF1D4ED8);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Ensemble Scores',
      subtitle:
          'ScoreView stacks every StaffGroup in a Score on one shared onset '
          'grid, with real braces, brackets, part names and system-spanning '
          'barlines.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'One grid, not several staves that happen to line up',
          description:
              'ADR-002: every element carries an onset measured in whole notes '
              'from the start of the staff, and two events with the same onset '
              'must land on the same X whatever their individual spacing needs. '
              'That is what makes a quaver in the soprano sit above the third '
              'triplet quaver in the piano rather than near it.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'SATB — one bracketed group of four',
          description:
              'A bracket, four staves, connected barlines, and a part name '
              'beside each staff. The names survive a MusicXML and MEI round '
              'trip; before 2.7.0 group-abbreviation was dropped on export and '
              'BracketType.none came back as a bracket.',
          accentColor: _accent,
          child: _ScoreFrame(score: _satb(), minHeight: 340),
        ),
        ExampleSectionCard(
          title: 'Choir over piano — two groups, different shapes',
          description:
              'A four-staff bracket above a two-staff brace. The groups have '
              'different staff counts and different rhythms; the barlines still '
              'meet, because the grid is a property of the Score and not of any '
              'one group.',
          accentColor: _accent,
          child: _ScoreFrame(score: _choirAndPiano(), minHeight: 460),
        ),
        ExampleSectionCard(
          title: 'A piano brace on its own',
          description:
              'The common case, kept here for comparison: BracketType.brace, '
              'two staves, and the left hand written against a triplet in the '
              'right so the alignment has something to prove.',
          accentColor: _accent,
          child: _ScoreFrame(score: _piano(), minHeight: 260),
        ),
        const ExampleSectionCard(
          title: 'Building one',
          description:
              'A Score is a list of StaffGroups; a StaffGroup is a list of '
              'Staves plus how they are joined.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: 'final score = Score(\n'
                "  title: 'Anthem',\n"
                '  staffGroups: [\n'
                '    StaffGroup(\n'
                "      name: 'Choir',\n"
                "      abbreviation: 'Ch.',\n"
                '      bracket: BracketType.bracket,\n'
                '      connectBarlines: true,\n'
                '      staves: [soprano, alto, tenor, bass],\n'
                '    ),\n'
                '    StaffGroup(\n'
                '      bracket: BracketType.brace,\n'
                '      staves: [rightHand, leftHand],\n'
                '    ),\n'
                '  ],\n'
                ');\n'
                '\n'
                'ScoreView(score: score, staffSpace: 13);',
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- scores --

  static Note _n(String step, int octave,
          {DurationType d = DurationType.quarter, int dots = 0}) =>
      Note(
        pitch: Pitch(step: step, octave: octave),
        duration: MusicDuration(d, dots: dots),
      );

  static Staff _line(
    ClefType clef,
    List<MusicalElement> notes, {
    String? name,
    String? abbreviation,
  }) {
    final measure = Measure()
      ..elements.addAll([
        Clef(clefType: clef),
        TimeSignature(numerator: 4, denominator: 4),
        ...notes,
      ]);
    return Staff(
      measures: [measure],
      name: name,
      abbreviation: abbreviation,
    );
  }

  static Score _satb() => Score(
        title: 'SATB',
        staffGroups: [
          StaffGroup(
            name: 'Choir',
            abbreviation: 'Ch.',
            bracket: BracketType.bracket,
            connectBarlines: true,
            staves: [
              _line(ClefType.treble,
                  [_n('G', 5), _n('F', 5), _n('E', 5), _n('D', 5)],
                  name: 'Soprano', abbreviation: 'S.'),
              _line(ClefType.treble,
                  [_n('C', 5), _n('C', 5), _n('B', 4), _n('B', 4)],
                  name: 'Alto', abbreviation: 'A.'),
              _line(ClefType.bass,
                  [_n('E', 4), _n('A', 3), _n('G', 3), _n('G', 3)],
                  name: 'Tenor', abbreviation: 'T.'),
              _line(ClefType.bass,
                  [_n('C', 3), _n('F', 3), _n('G', 3), _n('G', 2)],
                  name: 'Bass', abbreviation: 'B.'),
            ],
          ),
        ],
      );

  static Score _piano() => Score(
        title: 'Piano',
        staffGroups: [
          StaffGroup(
            bracket: BracketType.brace,
            connectBarlines: true,
            staves: [
              _line(ClefType.treble, [
                Tuplet(actualNotes: 3, normalNotes: 2, elements: [
                  _n('C', 5, d: DurationType.eighth),
                  _n('E', 5, d: DurationType.eighth),
                  _n('G', 5, d: DurationType.eighth),
                ]),
                _n('C', 6, d: DurationType.half, dots: 1),
              ], name: 'Piano', abbreviation: 'Pno.'),
              _line(ClefType.bass, [
                _n('C', 3, d: DurationType.half),
                _n('G', 2, d: DurationType.half),
              ]),
            ],
          ),
        ],
      );

  static Score _choirAndPiano() {
    final satb = _satb().staffGroups.first;
    final piano = _piano().staffGroups.first;
    return Score(
      title: 'Choir and Piano',
      composer: 'flutter_notemus',
      staffGroups: [satb, piano],
    );
  }
}

/// `ScorePreviewFrame` takes a single `Staff`; a whole `Score` needs
/// `ScoreView`, so this is its sibling with the same framing.
class _ScoreFrame extends StatelessWidget {
  final Score score;
  final double minHeight;

  const _ScoreFrame({required this.score, required this.minHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ScoreView(score: score, staffSpace: 13),
    );
  }
}
