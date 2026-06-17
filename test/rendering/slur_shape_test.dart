// Regression for V1: a multi-note slur must render as a single, continuous,
// non-self-intersecting arc. The old control-point math ignored the computed
// arch height and derived tangents from the chord angle, so steep (ascending /
// descending) slurs folded back on themselves and drew as two disjoint humps.

import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/src/layout/slur_calculator.dart';

void main() {
  const staffSpace = 12.0;
  final calc = SlurCalculator();

  /// Samples the curve densely and returns the points.
  List<Offset> sample(CubicBezierCurve c, {int n = 60}) =>
      [for (var i = 0; i <= n; i++) c.pointAt(i / n)];

  void assertContinuousArc(
    CubicBezierCurve curve,
    Offset start,
    Offset end, {
    required bool placement,
  }) {
    final pts = sample(curve);

    // 1. X is monotonically non-decreasing (no fold-back / loop).
    for (var i = 1; i < pts.length; i++) {
      expect(
        pts[i].dx,
        greaterThanOrEqualTo(pts[i - 1].dx - 0.01),
        reason: 'slur folds back in X at sample $i',
      );
    }

    // 2. The arch bulges to the correct side: for placement=true (above) the
    //    apex is meaningfully ABOVE (smaller y) both endpoints.
    final apexY = pts.map((p) => p.dy).reduce(placement ? min : max);
    final refY = placement ? min(start.dy, end.dy) : max(start.dy, end.dy);
    final bulge = (refY - apexY).abs();
    expect(
      bulge,
      greaterThan(staffSpace * 0.4),
      reason: 'slur arch too shallow / on the wrong side',
    );

    // 3. Endpoints honor the input X (calculateSlur shifts Y by a small
    //    notehead offset, so only X is asserted exactly).
    expect((pts.first.dx - start.dx).abs(), lessThan(0.5));
    expect((pts.last.dx - end.dx).abs(), lessThan(0.5));
  }

  test('ascending slur above is one continuous upward arc (V1)', () {
    const start = Offset(100, 200); // lower-left
    const end = Offset(220, 150); // higher-right (smaller y)
    final curve = calc.calculateSlur(
      startPoint: start,
      endPoint: end,
      placement: true,
      staffSpace: staffSpace,
    );
    assertContinuousArc(curve, start, end, placement: true);
  });

  test('descending slur above is one continuous upward arc (V1)', () {
    const start = Offset(100, 150);
    const end = Offset(240, 210);
    final curve = calc.calculateSlur(
      startPoint: start,
      endPoint: end,
      placement: true,
      staffSpace: staffSpace,
    );
    assertContinuousArc(curve, start, end, placement: true);
  });

  test('flat slur below is one continuous downward arc (V1)', () {
    const start = Offset(100, 180);
    const end = Offset(260, 182);
    final curve = calc.calculateSlur(
      startPoint: start,
      endPoint: end,
      placement: false,
      staffSpace: staffSpace,
    );
    assertContinuousArc(curve, start, end, placement: false);
  });
}
