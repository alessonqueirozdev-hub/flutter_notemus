// Regression for V3: chord accidental column packing.
// ChordRenderer.assignAccidentalColumns must place accidentals top-to-bottom in
// the rightmost column that clears every accidental already in that column by
// the required vertical clearance, so accidentals never vertically overlap
// within a column and the layout stays as compact as physically possible.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/src/rendering/renderers/chord_renderer.dart';

void main() {
  // A sharp/flat is ~2.7 staff spaces tall -> ~5.4 half-spaces; +0.5 gap.
  const sharpClearance = 5.9;

  /// Verifies no two accidentals sharing a column are closer than their clearance.
  void assertNoOverlap(List<int> positions, List<double> clearances) {
    final cols = ChordRenderer.assignAccidentalColumns(positions, clearances);
    for (var a = 0; a < positions.length; a++) {
      for (var b = a + 1; b < positions.length; b++) {
        if (cols[a] == cols[b]) {
          final gap = (positions[a] - positions[b]).abs();
          final need = clearances[a] < clearances[b] ? clearances[a] : clearances[b];
          expect(gap, greaterThanOrEqualTo(need),
              reason: 'accidentals $a and $b share column ${cols[a]} but overlap');
        }
      }
    }
  }

  test('single accidental uses column 0', () {
    expect(ChordRenderer.assignAccidentalColumns([0], [sharpClearance]), [0]);
  });

  test('stacked thirds never overlap within a column (V3)', () {
    // D#4,F#4,Ab4,C#5 -> staff positions -5,-3,-1,+1 (top to bottom: +1,-1,-3,-5).
    final positions = [1, -1, -3, -5];
    final clearances = List.filled(4, sharpClearance);
    assertNoOverlap(positions, clearances);
  });

  test('far-apart accidentals (>= clearance) can share column 0', () {
    // Two accidentals a tenth apart (positions 5 and -5 -> gap 10 >= 5.9).
    final cols = ChordRenderer.assignAccidentalColumns([5, -5], [sharpClearance, sharpClearance]);
    expect(cols, [0, 0]);
  });

  test('columns are greedily minimal (no gaps in column usage)', () {
    final positions = [4, 2, 0, -2, -4];
    final clearances = List.filled(5, sharpClearance);
    final cols = ChordRenderer.assignAccidentalColumns(positions, clearances);
    // Used columns must be a contiguous range starting at 0.
    final used = cols.toSet().toList()..sort();
    for (var i = 0; i < used.length; i++) {
      expect(used[i], i, reason: 'column usage has a gap: $used');
    }
    assertNoOverlap(positions, clearances);
  });
}
