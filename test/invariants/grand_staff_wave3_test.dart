// test/invariants/grand_staff_wave3_test.dart
//
// Grand-staff invariants that the 2.7.1 forensic re-audit measured as broken:
//
//  * M-01 — a mid-measure clef change written INSIDE a voice must be visible to
//    the system restatement, so every wrapped system opens with the clef that
//    is really in force.
//  * M-22 — `crossStaffMove` must be honoured for UNBEAMED notes too, must be
//    reported by `alignedSystem()` on the staff the note is printed on, and
//    must read the destination staff's clef AT THAT POINT.
//  * M-28 — an over-wide system must be reachable: the widget has to scroll.
//  * F2  — a grace note must not drag the shared onset anchor to the left.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Note _n(
  String step,
  int octave,
  DurationType type, {
  int voice = 1,
  int crossStaffMove = 0,
  bool isGraceNote = false,
  BeamType? beam,
}) =>
    Note(
      pitch: Pitch(step: step, octave: octave, alter: 0.0),
      duration: Duration(type),
      voice: voice,
      crossStaffMove: crossStaffMove,
      isGraceNote: isGraceNote,
      beam: beam,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  GrandStaffPainter painterFor(
    List<Staff> staves, {
    double availableWidth = 600,
  }) =>
      GrandStaffPainter(
        staffGroup: StaffGroup(staves: staves, bracket: BracketType.brace),
        staffSpace: 12,
        metadata: metadata,
        theme: const MusicScoreTheme(),
        availableWidth: availableWidth,
      );

  /// Every clef printed on staff [staffIndex] of system [system], as
  /// `type@x`, in the order the reader meets them.
  List<String> clefsOf(GrandStaffPainter p, int system, int staffIndex) => [
        for (final pe in p.alignedSystem(system)[staffIndex])
          if (pe.element case final Clef clef)
            '${clef.clefType.name}@${pe.position.dx.round()}',
      ];

  group('M-01 mid-voice clef change drives the system restatement', () {
    // Ten polyphonic bars, one per system at 400 px, with a bass clef written
    // in the MIDDLE of voice 1 of bar 3 (index 2).
    List<Staff> tenBars() {
      final measures = <Measure>[];
      for (var i = 0; i < 10; i++) {
        final measure = MultiVoiceMeasure.twoVoices(
          voice1Elements: [
            _n('C', 5, DurationType.quarter),
            _n('D', 5, DurationType.quarter),
            if (i == 2) Clef(clefType: ClefType.bass),
            _n('E', 5, DurationType.quarter),
            _n('F', 5, DurationType.quarter),
          ],
          voice2Elements: [
            _n('C', 4, DurationType.half, voice: 2),
            _n('E', 4, DurationType.half, voice: 2),
          ],
        );
        if (i == 0) {
          measure.elements.insert(0, TimeSignature(numerator: 4, denominator: 4));
          measure.elements.insert(0, Clef(clefType: ClefType.treble));
        }
        measure.elements.add(Barline());
        measures.add(measure);
      }
      final bottom = <Measure>[
        for (var i = 0; i < 10; i++)
          Measure()
            ..elements.addAll(<MusicalElement>[
              if (i == 0) Clef(clefType: ClefType.bass),
              _n('C', 3, DurationType.half),
              _n('G', 3, DurationType.half),
              Barline(),
            ]),
      ];
      return [Staff(measures: measures), Staff(measures: bottom)];
    }

    test('every system after the change restates BASS, not treble', () {
      final painter = painterFor(tenBars(), availableWidth: 400);
      expect(painter.systemCount, 10);

      // Before the change: treble.
      expect(clefsOf(painter, 0, 0), ['treble@30']);
      expect(clefsOf(painter, 1, 0), ['treble@30']);

      // The bar that CARRIES the change still opens with the old clef and then
      // changes mid-bar. The old code printed no head clef here at all,
      // because it suppressed the restatement on "the bar has a clef".
      final onChange = clefsOf(painter, 2, 0);
      expect(onChange.first, 'treble@30');
      expect(onChange.length, 2);
      expect(onChange[1], startsWith('bass@'));

      // After the change every system must restate BASS. Measured before the
      // fix: 'treble@30' on systems 3..9 — a twelfth of silent error on every
      // note of those bars.
      for (var system = 3; system < painter.systemCount; system++) {
        expect(clefsOf(painter, system, 0), ['bass@30'],
            reason: 'system $system restated the wrong clef');
      }
    });
  });

  test('M-01 a key signature written inside a voice is restated too', () {
    final measures = <Measure>[];
    for (var i = 0; i < 4; i++) {
      final measure = MultiVoiceMeasure.twoVoices(
        voice1Elements: [
          _n('C', 5, DurationType.half),
          if (i == 1) KeySignature(-3),
          _n('E', 5, DurationType.half),
        ],
        voice2Elements: [_n('C', 4, DurationType.whole, voice: 2)],
      );
      if (i == 0) {
        measure.elements.insert(0, TimeSignature(numerator: 4, denominator: 4));
        measure.elements.insert(0, Clef(clefType: ClefType.treble));
      }
      measure.elements.add(Barline());
      measures.add(measure);
    }
    final painter = painterFor(
      [
        Staff(measures: measures),
        Staff(measures: [
          for (var i = 0; i < 4; i++)
            Measure()
              ..elements.addAll(<MusicalElement>[
                if (i == 0) Clef(clefType: ClefType.bass),
                _n('C', 3, DurationType.whole),
                Barline(),
              ]),
        ]),
      ],
      availableWidth: 320,
    );

    // Systems that begin after the mid-voice key change must restate it.
    var sawRestatedKey = false;
    for (var system = 2; system < painter.systemCount; system++) {
      final head = painter.alignedSystem(system)[0];
      for (final pe in head) {
        if (pe.element case final KeySignature key) {
          expect(key.count, -3);
          sawRestatedKey = true;
          break;
        }
      }
    }
    expect(sawRestatedKey, isTrue,
        reason: 'no wrapped system restated the mid-voice key signature');
  });

  group('M-22 crossStaffMove', () {
    Staff bottomWhole() => Staff(measures: [
          Measure()
            ..elements.addAll(<MusicalElement>[
              Clef(clefType: ClefType.bass),
              TimeSignature(numerator: 4, denominator: 4),
              _n('C', 3, DurationType.whole),
              Barline(),
            ]),
        ]);

    ({int staff, Offset at})? findCross(GrandStaffPainter p) {
      final system = p.alignedSystem(0);
      for (var s = 0; s < system.length; s++) {
        for (final pe in system[s]) {
          if (pe.element case final Note note when note.crossStaffMove != 0) {
            return (staff: s, at: pe.position);
          }
        }
      }
      return null;
    }

    test('an UNBEAMED cross-staff note lands on the destination staff', () {
      final top = Staff(measures: [
        Measure()
          ..elements.addAll(<MusicalElement>[
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            _n('C', 5, DurationType.quarter),
            _n('D', 4, DurationType.quarter, crossStaffMove: 1),
            _n('E', 5, DurationType.quarter),
            _n('F', 5, DurationType.quarter),
            Barline(),
          ]),
      ]);
      final found = findCross(painterFor([top, bottomWhole()]));
      expect(found, isNotNull);
      // Measured before the fix: staff 0 at dy 90.0 — the note stayed on its
      // home staff because only BEAMED groups were collected.
      expect(found!.staff, 1);
      // D4 read in bass clef is 7 staff positions above the middle line:
      // baseline 60 - 7 * 12/2 = 18.
      expect(found.at.dy, closeTo(18.0, 0.01));
    });

    test('a BEAMED cross-staff note is reported on the destination staff', () {
      final top = Staff(measures: [
        Measure(autoBeaming: false)
          ..elements.addAll(<MusicalElement>[
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            _n('C', 5, DurationType.eighth, beam: BeamType.start),
            _n('D', 4, DurationType.eighth,
                crossStaffMove: 1, beam: BeamType.end),
            _n('E', 5, DurationType.half),
            _n('F', 5, DurationType.quarter),
            Barline(),
          ]),
      ]);
      final found = findCross(painterFor([top, bottomWhole()]));
      expect(found, isNotNull);
      // The paint pass always drew this one on staff 1; `alignedSystem` — and
      // therefore every hit test built from it — still said staff 0.
      expect(found!.staff, 1);
      expect(found.at.dy, closeTo(18.0, 0.01));
    });

    test('the destination clef is the one in force AT THAT POINT', () {
      final top = Staff(measures: [
        Measure()
          ..elements.addAll(<MusicalElement>[
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            _n('C', 5, DurationType.quarter),
            _n('C', 4, DurationType.quarter, crossStaffMove: 1),
            _n('C', 4, DurationType.quarter, crossStaffMove: 1),
            _n('C', 5, DurationType.quarter),
            Barline(),
          ]),
      ]);
      final bottom = Staff(measures: [
        Measure()
          ..elements.addAll(<MusicalElement>[
            Clef(clefType: ClefType.bass),
            TimeSignature(numerator: 4, denominator: 4),
            _n('C', 3, DurationType.quarter),
            _n('C', 3, DurationType.quarter),
            Clef(clefType: ClefType.treble),
            _n('C', 4, DurationType.quarter),
            _n('C', 4, DurationType.quarter),
            Barline(),
          ]),
      ]);

      final system = painterFor([top, bottom]).alignedSystem(0);
      final clefChangeX = [
        for (final pe in system[1])
          if (pe.element case final Clef clef when clef.clefType == ClefType.treble)
            pe.position.dx,
      ].single;

      final crossNotes = [
        for (final pe in system[1])
          if (pe.element case final Note note when note.crossStaffMove != 0) pe,
      ];
      expect(crossNotes.length, 2);

      for (final pe in crossNotes) {
        final beforeChange = pe.position.dx < clefChangeX;
        // C4 sits 6 positions ABOVE the bass middle line (dy 60 - 36 = 24) and
        // 6 positions BELOW the treble middle line (dy 60 + 36 = 96). The old
        // `_clefOf` returned the destination staff's FIRST clef, so both notes
        // came out at 24.
        expect(pe.position.dy, closeTo(beforeChange ? 24.0 : 96.0, 0.01),
            reason: 'cross-staff note at x=${pe.position.dx} read the wrong '
                'destination clef (change at x=$clefChangeX)');
      }
    });
  });

  test('F2 a grace note does not drag the shared onset anchor', () {
    final top = Staff(measures: [
      Measure()
        ..elements.addAll(<MusicalElement>[
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          _n('C', 5, DurationType.quarter),
          _n('B', 4, DurationType.eighth, isGraceNote: true),
          _n('D', 5, DurationType.quarter),
          _n('E', 5, DurationType.quarter),
          _n('F', 5, DurationType.quarter),
          Barline(),
        ]),
    ]);
    final bottom = Staff(measures: [
      Measure()
        ..elements.addAll(<MusicalElement>[
          Clef(clefType: ClefType.bass),
          TimeSignature(numerator: 4, denominator: 4),
          for (final step in ['C', 'D', 'E', 'F'])
            _n(step, 3, DurationType.quarter),
          Barline(),
        ]),
    ]);

    final system = painterFor([top, bottom]).alignedSystem(0);
    Map<String, double> realNoteX(List<PositionedElement> elements) {
      final byOnset = <String, double>{};
      for (final pe in elements) {
        if (pe.element case final Note note when !note.isGraceNote) {
          byOnset.putIfAbsent(pe.onset.toStringAsFixed(3), () => pe.position.dx);
        }
      }
      return byOnset;
    }

    final top0 = realNoteX(system[0]);
    final bottom0 = realNoteX(system[1]);
    expect(bottom0.keys, isNotEmpty);
    for (final onset in bottom0.keys) {
      // Measured before the fix: onset 0.250 sat at 216.31 on the ornamented
      // staff against 172.99 on the plain one — 43.32 px apart, because the
      // grace note (same onset, printed to the left) became the anchor.
      expect(top0[onset], isNotNull, reason: 'onset $onset missing on top staff');
      expect((top0[onset]! - bottom0[onset]!).abs(), lessThan(0.5),
          reason: 'onset $onset is not aligned across the staves');
    }
  });

  group('M-28 an over-wide system is reachable', () {
    Staff wideStaff(int noteCount) {
      final elements = <MusicalElement>[Clef(clefType: ClefType.treble)];
      for (var i = 0; i < noteCount; i++) {
        elements.add(_n('C', 5, DurationType.thirtySecond));
      }
      elements.add(Barline());
      return Staff(measures: [Measure()..elements.addAll(elements)]);
    }

    Staff shortStaff() => Staff(measures: [
          Measure()
            ..elements.addAll(<MusicalElement>[
              Clef(clefType: ClefType.bass),
              _n('C', 3, DurationType.whole),
              Barline(),
            ]),
        ]);

    test('contentWidth reaches the rightmost element the painter draws', () {
      final painter = painterFor(
        [wideStaff(200), shortStaff()],
        availableWidth: 300,
      );
      var rightmost = 0.0;
      for (var system = 0; system < painter.systemCount; system++) {
        for (final staff in painter.alignedSystem(system)) {
          for (final pe in staff) {
            if (pe.position.dx > rightmost) rightmost = pe.position.dx;
          }
        }
      }
      expect(rightmost, greaterThan(300));
      expect(painter.contentWidth, greaterThan(rightmost));
    });

    testWidgets('GrandStaff scrolls to the whole system', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: GrandStaff(
              group: StaffGroup(
                staves: [wideStaff(200), shortStaff()],
                bracket: BracketType.brace,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Measured before the fix: ZERO scrollables, a `CustomPaint` pinned at
      // 300.0 px, and content reaching x = 57,436.2 px on the 2000-note case.
      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsOneWidget);
      final position = tester.state<ScrollableState>(scrollables).position;
      expect(position.axis, Axis.horizontal);

      final canvas = tester.widget<CustomPaint>(
        find.descendant(of: scrollables, matching: find.byType(CustomPaint)).first,
      );
      // The last pixel of music must be scrollable into the 300 px viewport.
      expect(position.maxScrollExtent + 300.0, greaterThanOrEqualTo(canvas.size.width - 0.5));
      expect(position.maxScrollExtent, greaterThan(1000));
    });
  });
}
