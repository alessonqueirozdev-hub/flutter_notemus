// example/lib/examples/grand_staff_example.dart
//
// Showcases the multi-staff rendering added in 2.7.0: the public [GrandStaff]
// and [ScoreView] widgets, brace/bracket connectors, system-spanning barlines,
// and cross-staff beaming (Note.crossStaffMove).

import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Catalog entry: grand staff, choir, full score, and cross-staff beaming.
class GrandStaffExample extends StatelessWidget {
  const GrandStaffExample({super.key});

  static const _accent = Color(0xFF7C2D12);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Grand Staff & Scores',
      subtitle:
          'Multiple staves on a shared horizontal grid: piano grand staff, '
          'SATB choir, a full multi-section score, and cross-staff beaming.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'New in 2.7.0',
          description:
              'GrandStaff renders one StaffGroup; ScoreView renders a whole '
              'Score. Both align every staff on one grid, draw the SMuFL '
              'brace/bracket, connect barlines across staves, wrap into '
              'systems, and route beams across the staff gap.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Piano grand staff (brace)',
          description:
              'StaffGroup.piano(treble, bass) — two staves joined by a curly '
              'brace, with a system-spanning start barline and connected '
              'barlines.',
          accentColor: _accent,
          child: _GrandStaffFrame(
            child: GrandStaff(group: _pianoGroup()),
          ),
        ),
        ExampleSectionCard(
          title: 'Cross-staff beaming',
          description:
              'A single beamed run that crosses between the two staves. Each '
              'note keeps its home staff for voicing/beaming/spacing, but '
              'Note.crossStaffMove draws the notehead on the other staff and '
              'the beam follows.',
          accentColor: _accent,
          child: _GrandStaffFrame(
            child: GrandStaff(group: _crossStaffGroup()),
          ),
        ),
        ExampleSectionCard(
          title: 'SATB choir (bracket)',
          description:
              'StaffGroup.choir(...) — four vocal staves connected by a square '
              'bracket and aligned on a shared grid.',
          accentColor: _accent,
          child: _GrandStaffFrame(
            child: GrandStaff(group: _choirGroup()),
          ),
        ),
        ExampleSectionCard(
          title: 'Full score (ScoreView)',
          description:
              'A Score with two groups (choir + piano) rendered on one unified '
              'system. Each group keeps its own bracket/brace.',
          accentColor: _accent,
          child: _GrandStaffFrame(
            child: ScoreView(
              score: Score(staffGroups: [_choirGroup(), _pianoGroup()]),
            ),
          ),
        ),
      ],
    );
  }

  // --- Score builders -------------------------------------------------------

  static Staff _staff({
    required String clef,
    required List<MusicalElement> body,
    int fifths = 0,
  }) {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(type: clef));
    measure.add(KeySignature(fifths));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    for (final element in body) {
      measure.add(element);
    }
    staff.add(measure);
    return staff;
  }

  static Note _n(
    String step,
    int octave,
    DurationType dur, {
    BeamType? beam,
    int crossStaffMove = 0,
  }) {
    return Note(
      pitch: Pitch(step: step, octave: octave),
      duration: Duration(dur),
      beam: beam,
      crossStaffMove: crossStaffMove,
    );
  }

  static StaffGroup _pianoGroup() {
    final treble = _staff(
      clef: 'treble',
      body: [
        _n('C', 5, DurationType.quarter),
        _n('D', 5, DurationType.quarter),
        _n('E', 5, DurationType.quarter),
        _n('F', 5, DurationType.quarter),
      ],
    );
    final bass = _staff(
      clef: 'bass',
      body: [
        Chord(
          notes: [
            _n('C', 3, DurationType.whole),
            _n('E', 3, DurationType.whole),
            _n('G', 3, DurationType.whole),
          ],
          duration: const Duration(DurationType.whole),
        ),
      ],
    );
    return StaffGroup.piano(treble, bass);
  }

  static StaffGroup _crossStaffGroup() {
    // Empty top staff; the run lives on the bass staff and climbs up, with the
    // upper half displaced onto the treble staff via crossStaffMove: -1.
    final treble = _staff(
      clef: 'treble',
      body: [Rest(duration: const Duration(DurationType.whole))],
    );
    final bass = _staff(
      clef: 'bass',
      body: [
        _n('C', 3, DurationType.eighth, beam: BeamType.start),
        _n('E', 3, DurationType.eighth, beam: BeamType.inner),
        _n('G', 3, DurationType.eighth, beam: BeamType.inner),
        _n('C', 4, DurationType.eighth, beam: BeamType.inner),
        _n('E', 4, DurationType.eighth, beam: BeamType.inner, crossStaffMove: -1),
        _n('G', 4, DurationType.eighth, beam: BeamType.inner, crossStaffMove: -1),
        _n('C', 5, DurationType.eighth, beam: BeamType.inner, crossStaffMove: -1),
        _n('E', 5, DurationType.eighth, beam: BeamType.end, crossStaffMove: -1),
      ],
    );
    return StaffGroup.piano(treble, bass);
  }

  static StaffGroup _choirGroup() {
    List<MusicalElement> line(String a, String b, String c, String d, int oct) {
      return [
        _n(a, oct, DurationType.quarter),
        _n(b, oct, DurationType.quarter),
        _n(c, oct, DurationType.quarter),
        _n(d, oct, DurationType.quarter),
      ];
    }

    final soprano = _staff(clef: 'treble', body: line('G', 'A', 'G', 'E', 5));
    final alto = _staff(clef: 'treble', body: line('E', 'E', 'D', 'C', 5));
    final tenor = _staff(clef: 'treble', body: line('C', 'C', 'B', 'G', 4));
    final bass = _staff(clef: 'bass', body: line('C', 'A', 'G', 'C', 3));
    return StaffGroup.choir(soprano, alto, tenor, bass);
  }
}

/// A white framed canvas that lets a [GrandStaff]/[ScoreView] size itself to its
/// natural (multi-system) height.
class _GrandStaffFrame extends StatelessWidget {
  final Widget child;

  const _GrandStaffFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7DDE5)),
        color: const Color(0xFFFFFFFF),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}
