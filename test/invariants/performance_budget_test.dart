// Performance budgets.
//
// The 2.6.0 audit measured layout at ~82 ms for 800 measures (linear, fine) and
// paint at ~26 ms with viewport culling (over the 16.7 ms frame budget). The
// 2.7.0 remediation added work in both places:
//
//   * measure width is now obtained by DRY-RUNNING the layout, which doubles
//     the per-measure work;
//   * the painter caches its system grouping and its renderers instead of
//     rebuilding them every frame;
//   * the widget memoizes the whole layout per (staff, width, staffSpace).
//
// These are deliberately loose ceilings — they exist to catch an ORDER-OF-
// MAGNITUDE regression (an accidental O(n^2)), not to police a few
// milliseconds on someone else's machine. If one of them fails, measure before
// relaxing it.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Staff buildStaff(int measures, {int notesPerMeasure = 4}) {
  final rnd = math.Random(7);
  final list = <Measure>[];
  for (var i = 0; i < measures; i++) {
    final m = Measure();
    if (i == 0) {
      m.elements.add(Clef(clefType: ClefType.treble));
      m.elements.add(KeySignature(2));
      m.elements.add(TimeSignature(numerator: 4, denominator: 4));
    }
    for (var j = 0; j < notesPerMeasure; j++) {
      m.elements.add(Note(
        pitch: Pitch(
            step: 'CDEFGAB'[rnd.nextInt(7)], octave: 4 + rnd.nextInt(2)),
        duration: const Duration(DurationType.quarter),
      ));
    }
    list.add(m);
  }
  return Staff(measures: list);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  int layoutMillis(int measures) {
    final staff = buildStaff(measures);
    // Warm up: the first run pays for JIT and for the lazily-built accidental
    // map, which would otherwise be charged to the smallest sample.
    LayoutEngine(staff,
            availableWidth: 1000, staffSpace: 12, metadata: metadata)
        .layout();
    final sw = Stopwatch()..start();
    LayoutEngine(staff,
            availableWidth: 1000, staffSpace: 12, metadata: metadata)
        .layout();
    sw.stop();
    return sw.elapsedMilliseconds;
  }

  test('layout stays LINEAR in the number of measures', () {
    final small = layoutMillis(200);
    final large = layoutMillis(1600);

    // 8x the input must not cost more than ~24x the time. Linear would be 8x;
    // the headroom absorbs timer noise on a small baseline. Quadratic would be
    // 64x and fails loudly.
    final budget = math.max(small, 1) * 24;
    expect(large, lessThan(budget),
        reason: '200 measures took ${small}ms, 1600 took ${large}ms. '
            'A super-linear jump here means the dry-run measurement, the '
            'justification pass or the note-position re-sync went quadratic.');
  });

  test('a large score lays out in a usable time', () {
    final ms = layoutMillis(1000);
    expect(ms, lessThan(4000),
        reason: '1000 measures took ${ms}ms. The dry-run width measurement '
            'roughly doubles the per-measure work; the widget compensates by '
            'memoizing, but the raw engine must stay usable.');
  });

  testWidgets('paint cost does not grow with score size (culling works)',
      (tester) async {
    int paintMillis(int measures) {
      final engine = LayoutEngine(
        buildStaff(measures),
        availableWidth: 800,
        staffSpace: 12,
        metadata: metadata,
      );
      final result = engine.layoutWithSignature();
      final hCtrl = ScrollController();
      final vCtrl = ScrollController();
      final painter = MusicScorePainter(
        positionedElements: result.elements,
        positionedElementsSignature: result.signature,
        metadata: metadata,
        theme: const MusicScoreTheme(),
        staffSpace: 12,
        layoutEngine: engine,
        viewportSize: const Size(800, 600),
        horizontalController: hCtrl,
        verticalController: vCtrl,
      );

      // Warm-up paint, then measure a steady-state frame.
      for (var i = 0; i < 2; i++) {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(800, 100000));
        recorder.endRecording();
      }
      final sw = Stopwatch()..start();
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(800, 100000));
      sw.stop();
      recorder.endRecording();
      hCtrl.dispose();
      vCtrl.dispose();
      return sw.elapsedMilliseconds;
    }

    final small = paintMillis(50);
    final large = paintMillis(800);

    // Culling means only the visible systems are drawn, so painting 16x the
    // music must not cost 16x the time.
    //
    // The ceiling is `max(6x the small sample, 60ms)`: the small sample is a
    // handful of milliseconds, so a pure ratio would flake on timer noise,
    // while a 16x regression would land near 200ms and still fail loudly.
    final ceiling = math.max(math.max(small, 2) * 6, 60);
    expect(large, lessThan(ceiling),
        reason: '50 measures painted in ${small}ms, 800 in ${large}ms '
            '(ceiling ${ceiling}ms). If these scale together, the per-frame '
            'system grouping or the per-frame renderer construction came back.');
  });

  testWidgets('rebuilding the widget reuses the cached layout', (tester) async {
    final staff = buildStaff(400);
    var buildCount = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          buildCount++;
          return SizedBox(
            width: 800,
            height: 600,
            child: MusicScore(
              staff: staff,
              staffSpace: 12,
              enableResponsiveLayout: false,
              preventVerticalOverflow: false,
            ),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(buildCount, greaterThan(0));

    // Rebuild the subtree several times; with memoization this must be cheap,
    // because the engine is not re-run for the same (staff, width, staffSpace).
    final sw = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(2000),
        reason: 'five rebuilds took ${sw.elapsedMilliseconds}ms. The layout '
            'used to run inside LayoutBuilder on every build (twice, with the '
            'adaptive pass), at ~82ms per pass for 800 measures.');
  });
}
