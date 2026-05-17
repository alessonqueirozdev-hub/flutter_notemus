// Smoke coverage for JianpuScore / JianpuLayout (issue #24 MVP).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/jianpu/jianpu_renderer.dart';

Staff _demoStaff() {
  final staff = Staff();
  final measure = Measure();
  measure.add(KeySignature(0));
  measure.add(TimeSignature(numerator: 4, denominator: 4));
  // A valid 4/4 bar (0.25 + 0.125 + 0.125 + 0.5 = 1.0): exercises a tie,
  // an eighth (underline), a rest, a high note (octave dot) and a half
  // note (augmentation dash).
  measure.add(
    Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
      tie: TieType.start,
    ),
  );
  measure.add(
    Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.eighth),
    ),
  );
  measure.add(Rest(duration: const Duration(DurationType.eighth)));
  measure.add(
    Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.half),
    ),
  );
  staff.add(measure);
  return staff;
}

void main() {
  test('JianpuLayout.build produces rows and a 1=C header mapper', () {
    final layout = JianpuLayout.build(_demoStaff(), 600, const JianpuTheme());
    expect(layout.rowCount, greaterThan(0));
    expect(layout.mapper.tonicName, 'C');
    expect(layout.timeSignature, isNotNull);
    expect(layout.totalHeight(), greaterThan(0));
  });

  testWidgets('JianpuScore renders without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: JianpuScore(staff: _demoStaff()),
          ),
        ),
      ),
    );
    expect(find.byType(JianpuScore), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
