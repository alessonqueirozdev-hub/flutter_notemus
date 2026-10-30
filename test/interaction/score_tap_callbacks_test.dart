// test/interaction/score_tap_callbacks_test.dart
//
// `onNoteTap` / `onMeasureTap` on MusicScore, GrandStaff and ScoreView.
// Ported from @zamvar's fork (`codex/note-tap`) and rebuilt on
// ScoreHitTester, so a tap resolves against the same boxes the 2.8 hit-test
// fixes measured and returns the caller's own Note.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;

Note _q(String step, int octave) => Note(
      pitch: Pitch(step: step, octave: octave),
      duration: const MusicDuration(DurationType.quarter),
    );

Note _w(String step, int octave) => Note(
      pitch: Pitch(step: step, octave: octave),
      duration: const MusicDuration(DurationType.whole),
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 800, height: 400, child: child),
        ),
      ),
    );

/// Lets the widget's SMuFL metadata future complete and the score lay out.
/// Polls for the painted canvas rather than waiting a fixed time, which was
/// not enough under a loaded full-suite run.
Future<void> _settle(WidgetTester tester) async {
  final canvas = find.byWidgetPredicate((w) =>
      w is CustomPaint &&
      (w.painter is MusicScorePainter || w.painter is GrandStaffPainter));
  for (var i = 0; i < 100 && canvas.evaluate().isEmpty; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicScore', () {
    final notes = [_q('C', 5), _q('E', 5), _q('G', 5), _q('B', 4)];
    Staff staff() => Staff(measures: [
          Measure()
            ..add(Clef(clefType: ClefType.treble))
            ..add(TimeSignature(numerator: 4, denominator: 4))
            ..elements.addAll(notes),
          Measure()..add(_w('D', 5)),
        ]);

    /// Where [note] is on screen, read from the layout the widget actually
    /// painted (MusicScore picks its own staff space and centres the canvas
    /// vertically, so a separately built engine would not match).
    Future<Offset> screenPointOf(
        WidgetTester tester, Staff staff, Note note) async {
      final canvas = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MusicScorePainter);
      final painter =
          tester.widget<CustomPaint>(canvas).painter! as MusicScorePainter;
      final engine = painter.layoutEngine!;
      return tester.getTopLeft(canvas) +
          Offset(engine.noteXPositions[note]! + 3,
              engine.noteYPositions[note]! + painter.topInset);
    }

    testWidgets('reports the tapped note itself, with its bar', (t) async {
      final s = staff();
      final taps = <ScoreNoteTap>[];
      await t.pumpWidget(_host(MusicScore(
        staff: s,
        enableResponsiveLayout: false,
        preventVerticalOverflow: false,
        onNoteTap: taps.add,
      )));
      await _settle(t);

      await t.tapAt(await screenPointOf(t, s, notes[2]));
      expect(taps, hasLength(1));
      expect(identical(taps.single.note, notes[2]), isTrue);
      expect(taps.single.measureIndex, 0);
      expect(taps.single.staffIndex, 0);
    });

    testWidgets('a tap far from any note reports no note', (t) async {
      final taps = <ScoreNoteTap>[];
      await t.pumpWidget(_host(MusicScore(
        staff: staff(),
        enableResponsiveLayout: false,
        preventVerticalOverflow: false,
        onNoteTap: taps.add,
      )));
      await _settle(t);
      await t.tapAt(const Offset(790, 395));
      expect(taps, isEmpty);
    });

    testWidgets('onMeasureTap reports the bar index and its number',
        (t) async {
      final s = staff();
      final bars = <ScoreMeasureTap>[];
      await t.pumpWidget(_host(MusicScore(
        staff: s,
        enableResponsiveLayout: false,
        preventVerticalOverflow: false,
        onMeasureTap: bars.add,
      )));
      await _settle(t);

      await t.tapAt(await screenPointOf(t, s, s.measures[1].elements.single
          as Note));
      expect(bars.single.measureIndex, 1);
      expect(bars.single.measureNumber, 2);
    });

    testWidgets('a pickup is bar 0 to onMeasureTap', (t) async {
      final s = staff()..measures.first.isImplicit = true;
      final bars = <ScoreMeasureTap>[];
      await t.pumpWidget(_host(MusicScore(
        staff: s,
        enableResponsiveLayout: false,
        preventVerticalOverflow: false,
        onMeasureTap: bars.add,
      )));
      await _settle(t);
      await t.tapAt(await screenPointOf(t, s, notes[0]));
      expect(bars.single.measureIndex, 0);
      expect(bars.single.measureNumber, 0);
    });

    testWidgets('without callbacks there is no tap detector', (t) async {
      await t.pumpWidget(_host(MusicScore(staff: staff())));
      await _settle(t);
      expect(
          find.descendant(
              of: find.byType(MusicScore),
              matching: find.byType(GestureDetector)),
          findsNothing);
    });
  });

  group('GrandStaff', () {
    final treble = _w('G', 5);
    final bass = _w('C', 3);
    StaffGroup group() => StaffGroup(bracket: BracketType.brace, staves: [
          Staff(measures: [
            Measure()
              ..add(Clef(clefType: ClefType.treble))
              ..add(TimeSignature(numerator: 4, denominator: 4))
              ..add(treble),
            Measure()..add(_w('A', 5)),
          ]),
          Staff(measures: [
            Measure()
              ..add(Clef(clefType: ClefType.bass))
              ..add(TimeSignature(numerator: 4, denominator: 4))
              ..add(bass),
            Measure()..add(_w('D', 3)),
          ]),
        ]);

    GrandStaffPainter painterOf(WidgetTester t) => t
        .widget<CustomPaint>(find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is GrandStaffPainter))
        .painter! as GrandStaffPainter;

    testWidgets('a tap on either staff reports that staff\'s note', (t) async {
      await t.pumpWidget(_host(GrandStaff(group: group(), onNoteTap: (_) {})));
      await _settle(t);
      final painter = painterOf(t);

      // Sweep a vertical line through the first notes of both staves.
      final x = painter
              .alignedSystem(0)[0]
              .firstWhere((p) => identical(p.element, treble))
              .position
              .dx +
          12 * 2.2 + // brace gutter
          3;
      final found = <(Note, int, double)>[];
      for (var y = 0.0; y < painter.totalHeight; y += 2) {
        final tap = painter.noteTapAt(Offset(x, y));
        if (tap != null) found.add((tap.note, tap.staffIndex, y));
      }
      final trebleYs = [
        for (final f in found)
          if (identical(f.$1, treble)) f.$3
      ];
      final bassYs = [
        for (final f in found)
          if (identical(f.$1, bass)) f.$3
      ];
      expect(trebleYs, isNotEmpty);
      expect(bassYs, isNotEmpty);
      expect(found.where((f) => identical(f.$1, treble)).map((f) => f.$2),
          everyElement(0));
      expect(found.where((f) => identical(f.$1, bass)).map((f) => f.$2),
          everyElement(1));
      // The treble note is hit above the bass note, never below it.
      expect(trebleYs.reduce((a, b) => a > b ? a : b),
          lessThan(bassYs.reduce((a, b) => a < b ? a : b)));
    });

    testWidgets('onMeasureTap and onNoteTap fire through the widget',
        (t) async {
      final notes = <ScoreNoteTap>[];
      final bars = <ScoreMeasureTap>[];
      await t.pumpWidget(_host(GrandStaff(
        group: group(),
        onNoteTap: notes.add,
        onMeasureTap: bars.add,
      )));
      await _settle(t);
      final painter = painterOf(t);
      final canvas = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is GrandStaffPainter);
      final origin = t.getTopLeft(canvas);

      // Find a canvas point on the bass note of bar 1, then tap it for real.
      final x = painter
              .alignedSystem(0)[1]
              .firstWhere((p) => identical(p.element, bass))
              .position
              .dx +
          12 * 2.2 +
          3;
      Offset? point;
      for (var y = 0.0; y < painter.totalHeight && point == null; y += 2) {
        final tap = painter.noteTapAt(Offset(x, y));
        if (tap != null && identical(tap.note, bass)) point = Offset(x, y);
      }
      expect(point, isNotNull);
      await t.tapAt(origin + point!);

      expect(identical(notes.single.note, bass), isTrue);
      expect(notes.single.staffIndex, 1);
      expect(bars.single.measureIndex, 0);
      expect(bars.single.measureNumber, 1);
      expect(bars.single.staffIndex, 1);
    });

    testWidgets('ScoreView passes the callbacks through', (t) async {
      final score = Score(staffGroups: [group()]);
      await t.pumpWidget(_host(ScoreView(
        score: score,
        onNoteTap: (_) {},
      )));
      await _settle(t);
      final grand = t.widget<GrandStaff>(find.byType(GrandStaff));
      expect(grand.onNoteTap, isNotNull);
    });
  });
}
