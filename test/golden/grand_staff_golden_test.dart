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

  Note nDur(String step, int octave, DurationType d, {BeamType? beam}) => Note(
        pitch: Pitch(step: step, octave: octave),
        duration: fn.Duration(d),
        beam: beam,
      );

  testWidgets('grand staff with different rhythms — barlines still align',
      (tester) async {
    const size = Size(760, 320);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final treble = Staff(measures: [
      Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(nDur('C', 5, DurationType.eighth, beam: BeamType.start))
        ..add(nDur('D', 5, DurationType.eighth, beam: BeamType.inner))
        ..add(nDur('E', 5, DurationType.eighth, beam: BeamType.inner))
        ..add(nDur('F', 5, DurationType.eighth, beam: BeamType.end))
        ..add(nDur('G', 5, DurationType.quarter))
        ..add(nDur('E', 5, DurationType.quarter)),
    ]);
    final bass = Staff(measures: [
      Measure()
        ..add(Clef(clefType: ClefType.bass))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(nDur('C', 3, DurationType.half))
        ..add(nDur('G', 2, DurationType.half)),
    ]);

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
                    staffGroup: StaffGroup(
                      staves: [treble, bass],
                      bracket: BracketType.brace,
                    ),
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
      matchesGoldenFile('goldens/grand_staff_diff_rhythm.png'),
    );
  });

  testWidgets('multi-group score — unified grid, per-group brackets',
      (tester) async {
    const size = Size(760, 620);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Staff line(ClefType clef, List<({String s, int o})> ps) {
      final m = Measure()
        ..add(Clef(clefType: clef))
        ..add(TimeSignature(numerator: 4, denominator: 4));
      for (final p in ps) {
        m.add(n(p.s, p.o));
      }
      return Staff(measures: [m]);
    }

    // A bracketed two-voice section over a braced piano — all on one grid.
    final voices = StaffGroup(
      staves: [
        line(ClefType.treble, [(s: 'G', o: 5), (s: 'A', o: 5), (s: 'G', o: 5), (s: 'F', o: 5)]),
        line(ClefType.treble, [(s: 'C', o: 5), (s: 'C', o: 5), (s: 'B', o: 4), (s: 'A', o: 4)]),
      ],
      bracket: BracketType.bracket,
    );
    final piano = StaffGroup(
      staves: [
        line(ClefType.treble, [(s: 'E', o: 4), (s: 'F', o: 4), (s: 'G', o: 4), (s: 'A', o: 4)]),
        line(ClefType.bass, [(s: 'C', o: 3), (s: 'G', o: 2), (s: 'C', o: 3), (s: 'E', o: 3)]),
      ],
      bracket: BracketType.brace,
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
                    groups: [voices, piano],
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
      matchesGoldenFile('goldens/grand_staff_multigroup.png'),
    );
  });

  testWidgets('multi-system grand staff — wraps into stacked systems',
      (tester) async {
    const size = Size(620, 560);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Eight measures of four quarters each: too wide for one line at 620px,
    // so the grand staff must wrap into several stacked systems.
    Staff hand(ClefType clef, int baseOct) {
      final measures = <Measure>[];
      for (var mi = 0; mi < 8; mi++) {
        final m = Measure();
        if (mi == 0) {
          m
            ..add(Clef(clefType: clef))
            ..add(TimeSignature(numerator: 4, denominator: 4));
        }
        for (final step in ['C', 'D', 'E', 'F']) {
          m.add(n(step, baseOct));
        }
        measures.add(m);
      }
      return Staff(measures: measures);
    }

    final group = StaffGroup(
      staves: [hand(ClefType.treble, 5), hand(ClefType.bass, 3)],
      bracket: BracketType.brace,
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
                    staffSpace: 11.0,
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
      matchesGoldenFile('goldens/grand_staff_multisystem.png'),
    );
  });

  testWidgets('SATB choir — four staves under one bracket', (tester) async {
    const size = Size(760, 520);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Staff voice(ClefType clef, List<({String s, int o})> ps) {
      final m = Measure()
        ..add(Clef(clefType: clef))
        ..add(TimeSignature(numerator: 4, denominator: 4));
      for (final p in ps) {
        m.add(n(p.s, p.o));
      }
      return Staff(measures: [m]);
    }

    final group = StaffGroup(
      staves: [
        voice(ClefType.treble, [(s: 'G', o: 5), (s: 'A', o: 5), (s: 'G', o: 5), (s: 'F', o: 5)]),
        voice(ClefType.treble, [(s: 'C', o: 5), (s: 'C', o: 5), (s: 'B', o: 4), (s: 'A', o: 4)]),
        voice(ClefType.bass, [(s: 'E', o: 4), (s: 'F', o: 4), (s: 'D', o: 4), (s: 'C', o: 4)]),
        voice(ClefType.bass, [(s: 'C', o: 3), (s: 'F', o: 3), (s: 'G', o: 3), (s: 'C', o: 3)]),
      ],
      bracket: BracketType.bracket,
      name: 'Choir',
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
      matchesGoldenFile('goldens/grand_staff_satb.png'),
    );
  });

  testWidgets('cross-staff beam — eighths crossing treble to bass',
      (tester) async {
    const size = Size(760, 320);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Note e8(String s, int o, {BeamType? beam, int cross = 0}) => Note(
          pitch: Pitch(step: s, octave: o),
          duration: const fn.Duration(DurationType.eighth),
          beam: beam,
          crossStaffMove: cross,
        );

    // Treble voice: a descending run beamed across into the bass staff.
    final treble = Staff(measures: [
      Measure()
        ..add(Clef(clefType: ClefType.treble))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(e8('C', 5, beam: BeamType.start))
        ..add(e8('A', 4, beam: BeamType.inner))
        ..add(e8('A', 3, beam: BeamType.inner, cross: 1))
        ..add(e8('F', 3, beam: BeamType.end, cross: 1))
        ..add(nDur('G', 4, DurationType.half)),
    ]);
    final bass = Staff(measures: [
      Measure()
        ..add(Clef(clefType: ClefType.bass))
        ..add(TimeSignature(numerator: 4, denominator: 4))
        ..add(nDur('C', 3, DurationType.whole)),
    ]);

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
                    staffGroup: StaffGroup(
                      staves: [treble, bass],
                      bracket: BracketType.brace,
                    ),
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
      matchesGoldenFile('goldens/grand_staff_cross_beam.png'),
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

  testWidgets('imported cross-staff beam renders across the staves',
      (tester) async {
    const size = Size(760, 320);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String e8(String s, int o, String beam, int staff) =>
        '<note><pitch><step>$s</step><octave>$o</octave></pitch>'
        '<duration>1</duration><type>eighth</type><voice>1</voice>'
        '<beam number="1">$beam</beam><staff>$staff</staff></note>';
    final xml = '<score-partwise version="4.0"><part-list>'
        '<score-part id="P1"><part-name>Piano</part-name></score-part>'
        '</part-list><part id="P1"><measure number="1">'
        '<attributes><divisions>1</divisions><staves>2</staves>'
        '<clef number="1"><sign>G</sign><line>2</line></clef>'
        '<clef number="2"><sign>F</sign><line>4</line></clef></attributes>'
        '${e8('C', 5, 'begin', 1)}${e8('A', 4, 'continue', 1)}'
        '${e8('A', 3, 'continue', 2)}${e8('F', 3, 'end', 2)}'
        '<note><pitch><step>G</step><octave>4</octave></pitch>'
        '<duration>2</duration><type>half</type><voice>1</voice>'
        '<staff>1</staff></note>'
        '<backup><duration>4</duration></backup>'
        '<note><pitch><step>C</step><octave>3</octave></pitch>'
        '<duration>4</duration><type>whole</type><voice>2</voice>'
        '<staff>2</staff></note>'
        '</measure></part></score-partwise>';
    final score = MusicXMLParser.scoreFromMusicXML(xml);

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
                    groups: score.staffGroups,
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
      matchesGoldenFile('goldens/grand_staff_imported_crossbeam.png'),
    );
  });

  testWidgets('ScoreView renders an imported piano Score end-to-end',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(760, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const xml = '<score-partwise version="4.0"><part-list>'
        '<score-part id="P1"><part-name>Piano</part-name></score-part>'
        '</part-list><part id="P1"><measure number="1">'
        '<attributes><divisions>1</divisions><staves>2</staves>'
        '<clef number="1"><sign>G</sign><line>2</line></clef>'
        '<clef number="2"><sign>F</sign><line>4</line></clef></attributes>'
        '<note><pitch><step>E</step><octave>5</octave></pitch>'
        '<duration>1</duration><type>quarter</type><staff>1</staff></note>'
        '<note><pitch><step>C</step><octave>3</octave></pitch>'
        '<duration>1</duration><type>quarter</type><staff>2</staff></note>'
        '</measure></part></score-partwise>';
    final score = MusicXMLParser.scoreFromMusicXML(xml);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ScoreView(score: score))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
