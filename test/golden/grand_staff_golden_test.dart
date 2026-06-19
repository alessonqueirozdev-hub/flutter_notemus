// Golden coverage for multi-staff (grand-staff) rendering: a StaffGroup laid
// out as a vertically-stacked, horizontally-aligned system with a brace and
// connecting barlines.
//
// Generate / refresh:  flutter test --update-goldens test/golden/grand_staff_golden_test.dart
// Check:               flutter test test/golden/grand_staff_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;
import 'package:flutter_notemus/flutter_notemus.dart' as fn show Duration;
import 'package:flutter_notemus/src/rendering/grand_staff_painter.dart';

import '_harness.dart';

void main() {
  setUpAll(loadNotemusFonts);

  fn.Duration q() => const fn.Duration(DurationType.quarter);

  Note n(String step, int octave) =>
      Note(pitch: Pitch(step: step, octave: octave), duration: q());

  Staff trebleStaff() => Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(n('C', 5))
          ..add(n('D', 5))
          ..add(n('E', 5))
          ..add(n('F', 5)),
        Measure()
          ..add(n('E', 5))
          ..add(n('D', 5))
          ..add(n('C', 5))
          ..add(n('C', 5)),
      ]);

  Staff bassStaff() => Staff(measures: [
        Measure()
          ..add(Clef(clefType: ClefType.bass))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(n('C', 3))
          ..add(n('B', 2))
          ..add(n('A', 2))
          ..add(n('G', 2)),
        Measure()
          ..add(n('C', 3))
          ..add(n('G', 2))
          ..add(n('C', 3))
          ..add(n('C', 3)),
      ]);

  testWidgets('grand staff (piano) — brace, aligned barlines, two staves',
      (tester) async {
    const size = Size(760, 320);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final group = StaffGroup(
      staves: [trebleStaff(), bassStaff()],
      bracket: BracketType.brace,
      name: 'Piano',
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: kGoldenBoundaryKey,
              child: Container(
                width: size.width,
                height: size.height,
                color: Colors.white,
                child: CustomPaint(
                  size: size,
                  painter: GrandStaffPainter(
                    staffGroup: group,
                    staffSpace: 12.0,
                    metadata: SmuflMetadata(),
                    theme: const MusicScoreTheme(),
                    availableWidth: size.width,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(kGoldenBoundaryKey),
      matchesGoldenFile('goldens/grand_staff_piano.png'),
    );
  });

  testWidgets('public GrandStaff widget renders a StaffGroup', (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrandStaff(
            group: StaffGroup(
              staves: [trebleStaff(), bassStaff()],
              bracket: BracketType.brace,
            ),
            staffSpace: 12.0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
