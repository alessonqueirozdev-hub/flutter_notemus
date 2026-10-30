// test/interaction/playhead_test.dart
//
// The playback cursor of MusicScore / GrandStaff. Ported from @zamvar's fork
// (`codex/note-tap`): the line glides between a bar's rhythmic events, so it
// reaches each note as that note starts to sound. Here it is driven by
// PlaybackPlan, the transport that also produces the sound.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;
import 'package:flutter_notemus/src/playback/playhead.dart';

Note _q(String step, int octave) => Note(
      pitch: Pitch(step: step, octave: octave),
      duration: const MusicDuration(DurationType.quarter),
    );

Note _h(String step, int octave) => Note(
      pitch: Pitch(step: step, octave: octave),
      duration: const MusicDuration(DurationType.half),
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 900, height: 500, child: child),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester, Finder canvas) async {
  for (var i = 0; i < 100 && canvas.evaluate().isEmpty; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

PositionedElement _at(MusicalElement e, double x, double onset) =>
    PositionedElement(e, Offset(x, 0), onset: onset, measureIndex: 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('playheadX', () {
    // A 4/4 bar whose four quarters the layout spaced unevenly.
    final bar = [
      _at(Clef(clefType: ClefType.treble), 0, 0),
      _at(_q('C', 5), 40, 0),
      _at(_q('D', 5), 100, 0.25),
      _at(_q('E', 5), 130, 0.5),
      _at(_q('F', 5), 200, 0.75),
      _at(Barline(), 260, 1.0),
    ];
    double? x(double offset) => playheadX(bar,
        offset: offset, measureLength: 1.0, closingX: closingBarlineX(bar, 0));

    test('reaches each note exactly at its onset', () {
      expect(x(0), 40);
      expect(x(0.25), 100);
      expect(x(0.5), 130);
      expect(x(0.75), 200);
    });

    test('is linear between notes, and runs to the barline after the last',
        () {
      expect(x(0.125), closeTo(70, 1e-9));
      expect(x(0.875), closeTo(230, 1e-9));
      expect(x(1.0), 260);
    });

    test('a bar with nothing rhythmic has no cursor', () {
      expect(
          playheadX([_at(Clef(clefType: ClefType.treble), 0, 0)],
              offset: 0, measureLength: 1),
          isNull);
    });
  });

  group('MusicScore', () {
    final notes = [_q('C', 5), _q('E', 5), _h('G', 5)];
    Staff staff() => Staff(measures: [
          Measure()
            ..add(Clef(clefType: ClefType.treble))
            ..add(TimeSignature(numerator: 4, denominator: 4))
            ..elements.addAll(notes),
          Measure()..add(_q('A', 5))..add(_q('B', 5))..add(_h('C', 6)),
        ]);
    final cursor = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is MusicScorePlayheadPainter);
    final score = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is MusicScorePainter);

    testWidgets('the cursor stands on each note as PlaybackPlan reaches it',
        (t) async {
      final s = staff();
      final plan = PlaybackPlan.fromStaff(s);
      final position = ValueNotifier<PlaybackPosition?>(null);
      await t.pumpWidget(_host(MusicScore(
        staff: s,
        enableResponsiveLayout: false,
        preventVerticalOverflow: false,
        playbackPosition: position,
      )));
      await _settle(t, score);
      final painter =
          t.widget<CustomPaint>(cursor).painter! as MusicScorePlayheadPainter;
      final laidOut =
          (t.widget<CustomPaint>(score).painter! as MusicScorePainter)
              .positionedElements;

      expect(painter.placement(), isNull, reason: 'no position, no cursor');
      for (final span in plan.sequence.noteSpans) {
        position.value = plan.positionAt(plan.timeAtTick(span.startTick));
        final at = painter.placement();
        expect(at, isNotNull);
        final layoutX = laidOut
            .firstWhere((e) => identical(e.element, span.note))
            .position
            .dx;
        expect(at!.x, closeTo(layoutX, 0.5),
            reason: '${span.note.pitch.step}${span.note.pitch.octave}');
      }
    });

    testWidgets('a tick repaints the cursor layer, not the score', (t) async {
      final position = ValueNotifier<PlaybackPosition?>(null);
      await t.pumpWidget(_host(MusicScore(
        staff: staff(),
        enableResponsiveLayout: false,
        preventVerticalOverflow: false,
        playbackPosition: position,
      )));
      await _settle(t, score);
      final scoreBox = t.renderObject<RenderCustomPaint>(score);
      final cursorBox = t.renderObject<RenderCustomPaint>(cursor);
      final plan = PlaybackPlan.fromStaff(staff());
      position.value = plan.positionAt(const Duration(milliseconds: 600));
      expect(cursorBox.debugNeedsPaint, isTrue);
      expect(scoreBox.debugNeedsPaint, isFalse);
      await t.pump();
    });

    testWidgets('without a position there is no cursor layer', (t) async {
      await t.pumpWidget(_host(MusicScore(staff: staff())));
      await _settle(t, score);
      expect(cursor, findsNothing);
    });
  });

  group('GrandStaff', () {
    testWidgets('the cursor spans the system and lands on each staff\'s notes',
        (t) async {
      final treble = [_h('E', 5), _h('G', 5)];
      final bass = [_q('C', 3), _q('E', 3), _q('G', 3), _q('C', 3)];
      final group = StaffGroup(bracket: BracketType.brace, staves: [
        Staff(measures: [
          Measure()
            ..add(Clef(clefType: ClefType.treble))
            ..add(TimeSignature(numerator: 4, denominator: 4))
            ..elements.addAll(treble),
        ]),
        Staff(measures: [
          Measure()
            ..add(Clef(clefType: ClefType.bass))
            ..add(TimeSignature(numerator: 4, denominator: 4))
            ..elements.addAll(bass),
        ]),
      ]);
      final position = ValueNotifier<PlaybackPosition?>(null);
      await t.pumpWidget(_host(GrandStaff(group: group, playbackPosition: position)));
      final canvas = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is GrandStaffPainter);
      await _settle(t, canvas);
      final painter =
          t.widget<CustomPaint>(canvas).painter! as GrandStaffPainter;
      final plan = PlaybackPlan.fromScore(Score(staffGroups: [group]));
      final system = painter.alignedSystem(0);

      // Every bass quarter, including beats 2 and 4 where the treble rests
      // on a held half note: the shared grid puts the cursor on the bass note.
      for (var i = 0; i < bass.length; i++) {
        final at = painter.playheadAt(
            plan.positionAt(Duration(milliseconds: 500 * i))!)!;
        final noteX = system[1]
            .firstWhere((p) => identical(p.element, bass[i]))
            .position
            .dx;
        expect(at.x, closeTo(noteX + 12 * 2.2, 0.5), reason: 'beat ${i + 1}');
        // From above the top staff to below the bottom one.
        expect(at.top, lessThan(painter.contentTopInset + 12 * 3));
        expect(at.bottom,
            greaterThan(painter.contentTopInset + painter.staffGap + 12 * 7));
      }
    });
  });
}
