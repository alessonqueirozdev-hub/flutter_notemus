// test/invariants/shared_grid_spacing_test.dart
//
// The shared onset grid used to be built from the widest ABSOLUTE X any staff
// wanted at each instant. That is only correct when every staff has an anchor
// at every onset; when it does not, `_xAtOnset` interpolates, and the
// interpolation ate the spacing.
//
// Measured on an SATB choir beside a piano: four quarters alone space at
// 61 / 61 / 60 px, and the same four beside a piano triplet collapsed to
// 118 / 28 / 35 while the system stayed exactly as wide (182 -> 181 px)
// despite gaining three columns. A whole crotchet of music was left with 3 px
// to live in, because the choir's beat 2 had been pulled right to meet the
// triplet while beat 3 stayed where it was.
//
// The grid is built from STEPS now — the widest room any staff needs BETWEEN
// two consecutive onsets, accumulated — so extra room for a dense passage
// widens the system instead of being taken out of the beats after it.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  Note n(String s, int o, {DurationType d = DurationType.quarter}) =>
      Note(pitch: Pitch(step: s, octave: o), duration: MusicDuration(d));

  Staff line(ClefType clef, List<MusicalElement> body) => Staff(measures: [
        Measure()
          ..elements.addAll([
            Clef(clefType: clef),
            TimeSignature(numerator: 4, denominator: 4),
            ...body,
          ])
      ]);

  void report(String label, List<StaffGroup> groups) {
    final painter = GrandStaffPainter(
      groups: groups,
      staffSpace: 13,
      metadata: metadata,
      availableWidth: 900,
      theme: const MusicScoreTheme(),
    );
    final aligned = painter.alignedSystem(0);
    for (var i = 0; i < aligned.length; i++) {
      final xs = aligned[i]
          .where((e) => e.element is Note)
          .map((e) => e.position.dx.round())
          .toList();
      final gaps = <int>[];
      for (var j = 1; j < xs.length; j++) {
        gaps.add(xs[j] - xs[j - 1]);
      }
      // ignore: avoid_print
      print('$label staff$i xs=$xs gaps=$gaps');
    }
  }

  test('a dense passage on one staff does not squeeze the others', () {
    final satb = StaffGroup(bracket: BracketType.bracket, staves: [
      line(ClefType.treble, [n('G', 5), n('F', 5), n('E', 5), n('D', 5)]),
      line(ClefType.treble, [n('C', 5), n('C', 5), n('B', 4), n('B', 4)]),
    ]);
    report('choir only ', [satb]);

    final piano = StaffGroup(bracket: BracketType.brace, staves: [
      line(ClefType.treble, [
        Tuplet(actualNotes: 3, normalNotes: 2, elements: [
          n('C', 5, d: DurationType.eighth),
          n('E', 5, d: DurationType.eighth),
          n('G', 5, d: DurationType.eighth),
        ]),
        n('C', 6, d: DurationType.half),
      ]),
      line(ClefType.bass, [n('C', 3, d: DurationType.half), n('G', 2, d: DurationType.half)]),
    ]);
    // The measurement that matters: the choir's own beats keep the spacing
    // they have when nothing else is on the page. Only the interval that has
    // to hold the triplet is allowed to grow.
    final alone = _gapsOf([satb], metadata);
    final withPiano = _gapsOf([satb, piano], metadata);
    report('choir+piano', [satb, piano]);

    expect(alone.length, withPiano.length);
    expect(withPiano.first, greaterThan(alone.first),
        reason: 'the interval carrying the triplet must WIDEN, not stay put');
    for (var i = 1; i < alone.length; i++) {
      expect(withPiano[i], closeTo(alone[i], 2.0),
          reason: 'beat ${i + 1} was squeezed from ${alone[i]} to '
              '${withPiano[i]} px to make room for a passage on another '
              'staff. alone=$alone withPiano=$withPiano');
    }
  });
}

/// Gaps between consecutive notes on the FIRST staff of [groups].
List<int> _gapsOf(List<StaffGroup> groups, SmuflMetadata metadata) {
  final painter = GrandStaffPainter(
    groups: groups,
    staffSpace: 13,
    metadata: metadata,
    availableWidth: 900,
    theme: const MusicScoreTheme(),
  );
  final xs = painter
      .alignedSystem(0)
      .first
      .where((e) => e.element is Note)
      .map((e) => e.position.dx.round())
      .toList();
  return [for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1]];
}
