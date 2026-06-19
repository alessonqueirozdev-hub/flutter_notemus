// Regression for V4: simple-meter beam grouping.
// A full bar of eighths used to beam as ONE group because the break only fired
// when a single note spanned two beats. Now 4/4 beams eighths across the
// half-bar (groups of 4) and other simple meters beam by the beat.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/layout/beam_grouper.dart';

void main() {
  List<Note> eighths(int n) => List.generate(
        n,
        (_) => Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.eighth),
        ),
      );

  List<int> groupSizes(List<BeamGroup> g) => g.map((x) => x.notes.length).toList();

  test('8 eighths in 4/4 -> two groups of 4 (half-bar)', () {
    final g = BeamGrouper.groupNotesForBeaming(
      eighths(8),
      TimeSignature(numerator: 4, denominator: 4),
    );
    expect(groupSizes(g), [4, 4]);
  });

  test('4 eighths in 4/4 -> one group of 4', () {
    final g = BeamGrouper.groupNotesForBeaming(
      eighths(4),
      TimeSignature(numerator: 4, denominator: 4),
    );
    expect(groupSizes(g), [4]);
  });

  test('6 eighths in 3/4 -> three groups of 2 (by beat)', () {
    final g = BeamGrouper.groupNotesForBeaming(
      eighths(6),
      TimeSignature(numerator: 3, denominator: 4),
    );
    expect(groupSizes(g), [2, 2, 2]);
  });

  test('4 eighths in 2/4 -> two groups of 2 (by beat)', () {
    final g = BeamGrouper.groupNotesForBeaming(
      eighths(4),
      TimeSignature(numerator: 2, denominator: 4),
    );
    expect(groupSizes(g), [2, 2]);
  });
}
