// test/interaction/paged_score_test.dart
//
// PagedScoreView: the systems GrandStaff lays out, cut into paper pages on
// system boundaries. Ported from @zamvar's fork (`codex/note-tap`); here each
// page is a clipped band of the one shared GrandStaffPainter.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;

Note _w(String step, int octave) => Note(
      pitch: Pitch(step: step, octave: octave),
      duration: const MusicDuration(DurationType.whole),
    );

/// A two-staff piano group of [bars] whole-note bars: enough systems to fill
/// several pages.
StaffGroup _piano(int bars) => StaffGroup(bracket: BracketType.brace, staves: [
      Staff(measures: [
        for (var i = 0; i < bars; i++)
          Measure()
            ..elements.addAll([
              if (i == 0) Clef(clefType: ClefType.treble),
              if (i == 0) TimeSignature(numerator: 4, denominator: 4),
              _w(i.isEven ? 'E' : 'G', 5),
            ]),
      ]),
      Staff(measures: [
        for (var i = 0; i < bars; i++)
          Measure()
            ..elements.addAll([
              if (i == 0) Clef(clefType: ClefType.bass),
              if (i == 0) TimeSignature(numerator: 4, denominator: 4),
              _w('C', 3),
            ]),
      ]),
    ]);

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 600, height: 850, child: child),
      ),
    );

final _painterFinder = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is GrandStaffPainter);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 100 && _painterFinder.evaluate().isEmpty; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GrandStaffPainter.pages', () {
    late SmuflMetadata metadata;
    setUpAll(() async {
      metadata = SmuflMetadata();
      await metadata.load();
    });

    GrandStaffPainter painter(int bars) => GrandStaffPainter(
          staffGroup: _piano(bars),
          staffSpace: 7,
          metadata: metadata,
          theme: const MusicScoreTheme(),
          availableWidth: 515,
        );

    test('pages cover every system once, in order, each within the height',
        () {
      final p = painter(80);
      const maxHeight = 762.0;
      final pages = p.pages(maxHeight: maxHeight, firstPageReserve: 40);
      expect(pages.length, greaterThan(1));
      var next = 0;
      for (final page in pages) {
        expect(page.firstSystem, next);
        expect(page.systemCount, greaterThan(0));
        next += page.systemCount;
        final reserve = page.firstSystem == 0 ? 40.0 : 0.0;
        expect(page.height + reserve, lessThanOrEqualTo(maxHeight + 1e-6));
      }
      expect(next, p.systemCount);
      // Bands tile the painter's canvas with no gap and no overlap.
      for (var i = 1; i < pages.length; i++) {
        expect(pages[i].top,
            closeTo(pages[i - 1].top + pages[i - 1].height, 1e-6));
      }
      expect(pages.last.top + pages.last.height, closeTo(p.totalHeight, 1e-6));
    });

    test('a page too short for one system still gets that system', () {
      final p = painter(8);
      final pages = p.pages(maxHeight: 10);
      expect(pages.map((x) => x.systemCount), everyElement(1));
      expect(pages.length, p.systemCount);
    });

    test('only the last system ends with the final barline', () {
      // Each system is laid out as its own sub-staff, and the engine closed
      // every sub-staff as if the piece ended there: every line of a grand
      // staff ended thin-thick.
      final p = painter(20);
      expect(p.systemCount, greaterThan(1));
      for (var system = 0; system < p.systemCount; system++) {
        final barlines = p
            .alignedSystem(system)[0]
            .where((e) => e.element is Barline)
            .map((e) => (e.element as Barline).type)
            .toList();
        expect(barlines.last,
            system == p.systemCount - 1 ? BarlineType.final_ : BarlineType.single,
            reason: 'system $system');
      }
    });

    test('shouldRepaint sees an element replaced in place, and the theme', () {
      // The groups list and the geometry stay the same; comparing only those
      // kept the old raster on screen.
      final group = _piano(4);
      final groups = [group]; // one list, as a Score holds it
      GrandStaffPainter build({MusicScoreTheme theme = const MusicScoreTheme()}) =>
          GrandStaffPainter(
            groups: groups,
            staffSpace: 7,
            metadata: metadata,
            theme: theme,
            availableWidth: 515,
          );
      final before = build();
      expect(build().shouldRepaint(before), isFalse);
      final bar = group.staves.first.measures[1];
      bar.elements[bar.elements.length - 1] = _w('A', 5);
      expect(build().shouldRepaint(before), isTrue);
      final after = build();
      expect(
          build(theme: const MusicScoreTheme(noteheadColor: Color(0xFFFF0000)))
              .shouldRepaint(after),
          isTrue);
    });

    test("the signature sees a bar's own settings changed in place", () {
      final groups = [_piano(4)];
      final before = staffGroupsSignature(groups);
      groups.first.staves.first.measures[1].autoBeaming = false;
      expect(staffGroupsSignature(groups), isNot(before));
      final noBeams = staffGroupsSignature(groups);
      groups.first.staves.first.measures[1].manualBeamGroups = [
        [0, 1],
      ];
      expect(staffGroupsSignature(groups), isNot(noBeams));
      final grouped = staffGroupsSignature(groups);
      groups.first.staves.first.measures[0].isImplicit = true;
      expect(staffGroupsSignature(groups), isNot(grouped));
    });

    test('pageOfSystem and systemOfMeasure find where a bar is printed', () {
      final p = painter(80);
      final pages = p.pages(maxHeight: 762);
      final lastBar = 79;
      final system = p.systemOfMeasure(lastBar)!;
      expect(system, p.systemCount - 1);
      expect(pageOfSystem(pages, system), pages.length - 1);
      expect(p.systemOfMeasure(500), isNull);
    });
  });

  group('PagedScoreView', () {
    testWidgets('a long score becomes several pages; the first has the title',
        (t) async {
      final controller = PagedScoreController();
      await t.pumpWidget(_host(PagedScoreView(
        score: Score(
          title: 'Chorale',
          composer: 'Anon.',
          staffGroups: [_piano(80)],
        ),
        controller: controller,
      )));
      await _settle(t);
      expect(controller.pageCount, greaterThan(1));
      expect(controller.currentPage, 0);
      expect(find.text('Chorale'), findsOneWidget);
      expect(find.text('Anon.'), findsOneWidget);

      controller.nextPage();
      await t.pumpAndSettle();
      expect(controller.currentPage, 1);
      controller.dispose();
    });

    testWidgets('a bar tap on page 2 reports a bar printed on page 2',
        (t) async {
      final controller = PagedScoreController();
      final bars = <ScoreMeasureTap>[];
      await t.pumpWidget(_host(PagedScoreView(
        score: Score(staffGroups: [_piano(80)]),
        controller: controller,
        onMeasureTap: bars.add,
      )));
      await _settle(t);
      controller.jumpToPage(1);
      await t.pumpAndSettle();

      final painter =
          t.widget<CustomPaint>(_painterFinder.first).painter! as GrandStaffPainter;
      final pages = painter.pages(maxHeight: 842 - 80);
      await t.tapAt(t.getCenter(find.byType(PageView)));
      expect(bars, isNotEmpty);
      final system = painter.systemOfMeasure(bars.last.measureIndex)!;
      expect(pageOfSystem(pages, system), 1);
      controller.dispose();
    });

    testWidgets('a score edited in place is laid out again', (t) async {
      // Keyed on the Score instance alone, the old pages survived the edit.
      final controller = PagedScoreController();
      final group = _piano(80);
      final score = Score(staffGroups: [group]);
      Widget view() => _host(PagedScoreView(score: score, controller: controller));
      await t.pumpWidget(view());
      await _settle(t);
      final before = controller.pageCount;
      expect(before, greaterThan(1));

      for (final staff in group.staves) {
        staff.measures.removeRange(4, staff.measures.length);
      }
      await t.pumpWidget(view());
      await t.pumpAndSettle();
      expect(controller.pageCount, 1);
      controller.dispose();
    });

    testWidgets('a position set before the pages exist is still followed',
        (t) async {
      // The listener fired while there was no painter; nothing retried it.
      final controller = PagedScoreController();
      final score = Score(staffGroups: [_piano(80)]);
      final position = ValueNotifier<PlaybackPosition?>(
          PlaybackPlan.fromScore(score)
              .positionAt(const Duration(seconds: 158)));
      await t.pumpWidget(_host(PagedScoreView(
        score: score,
        controller: controller,
        playbackPosition: position,
      )));
      await _settle(t);
      expect(controller.currentPage, controller.pageCount - 1);
      controller.dispose();
    });

    testWidgets('a replacement controller learns the page count', (t) async {
      final first = PagedScoreController();
      final second = PagedScoreController();
      final score = Score(staffGroups: [_piano(80)]);
      await t.pumpWidget(_host(PagedScoreView(score: score, controller: first)));
      await _settle(t);
      final pages = first.pageCount;
      expect(pages, greaterThan(1));

      await t.pumpWidget(_host(PagedScoreView(score: score, controller: second)));
      await t.pumpAndSettle();
      expect(second.pageCount, pages);
      second.nextPage();
      await t.pumpAndSettle();
      expect(second.currentPage, 1);
      first.dispose();
      second.dispose();
    });

    testWidgets('a replacement notifier holding a position is followed',
        (t) async {
      // A listener hears the next change only; a paused player never sends
      // one.
      final controller = PagedScoreController();
      final score = Score(staffGroups: [_piano(80)]);
      final idle = ValueNotifier<PlaybackPosition?>(null);
      await t.pumpWidget(_host(PagedScoreView(
        score: score,
        controller: controller,
        playbackPosition: idle,
      )));
      await _settle(t);
      expect(controller.currentPage, 0);

      final paused = ValueNotifier<PlaybackPosition?>(PlaybackPlan.fromScore(score)
          .positionAt(const Duration(seconds: 158)));
      await t.pumpWidget(_host(PagedScoreView(
        score: score,
        controller: controller,
        playbackPosition: paused,
      )));
      await t.pumpAndSettle();
      expect(controller.currentPage, controller.pageCount - 1);
      controller.dispose();
    });

    testWidgets('turning followPlayback on goes to the paused cursor',
        (t) async {
      final controller = PagedScoreController();
      final score = Score(staffGroups: [_piano(80)]);
      final paused = ValueNotifier<PlaybackPosition?>(PlaybackPlan.fromScore(score)
          .positionAt(const Duration(seconds: 158)));
      Widget view(bool follow) => _host(PagedScoreView(
            score: score,
            controller: controller,
            playbackPosition: paused,
            followPlayback: follow,
          ));
      await t.pumpWidget(view(false));
      await _settle(t);
      expect(controller.currentPage, 0);
      await t.pumpWidget(view(true));
      await t.pumpAndSettle();
      expect(controller.currentPage, controller.pageCount - 1);
      controller.dispose();
    });

    testWidgets('the page turns to follow the playback cursor', (t) async {
      final controller = PagedScoreController();
      final position = ValueNotifier<PlaybackPosition?>(null);
      final score = Score(staffGroups: [_piano(80)]);
      await t.pumpWidget(_host(PagedScoreView(
        score: score,
        controller: controller,
        playbackPosition: position,
      )));
      await _settle(t);
      final plan = PlaybackPlan.fromScore(score);
      // The last bar: 79 whole notes in at 120 bpm.
      position.value = plan.positionAt(const Duration(seconds: 158));
      await t.pumpAndSettle();
      expect(position.value!.measureIndex, 79);
      expect(controller.currentPage, controller.pageCount - 1);
      controller.dispose();
    });
  });
}
