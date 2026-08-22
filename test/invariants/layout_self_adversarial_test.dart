// Adversarial tests against the 2.7.0 remediation itself.
//
// Three of the fixes carry their own risk, and this file exists to attack them
// rather than to celebrate them:
//
//  1. ADR-001 made `Note.beam` mutable, so `layout()` now has a visible side
//     effect on the caller's model. Is that side effect idempotent? Does it
//     respect `autoBeaming: false`? Does laying the same staff out at two
//     widths leave it in a consistent state?
//  2. Measure width is measured by DRY-RUNNING the layout into a throwaway
//     cursor. That dry run calls the same code that writes the note-position
//     maps and stamps beams. Does it leak?
//  3. A bar that does not fit is COMPRESSED. Does the compression leak into the
//     next bar, does justification undo it, and does the collision floor hold?

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Note _n(String step, int octave, [DurationType d = DurationType.quarter]) =>
    Note(pitch: Pitch(step: step, octave: octave), duration: Duration(d));

Measure _bar(List<MusicalElement> elements) {
  final m = Measure();
  for (final e in elements) {
    m.elements.add(e);
  }
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  LayoutEngine engineFor(Staff s, {double width = 900}) =>
      LayoutEngine(s, availableWidth: width, staffSpace: 12, metadata: metadata);

  group('ADR-001 risk — the layout mutates Note.beam', () {
    test('the mutation is idempotent across repeated layouts', () {
      final notes = [
        for (var i = 0; i < 6; i++) _n('C', 5, DurationType.eighth),
      ];
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 6, denominator: 8),
          ...notes,
        ])
      ]);

      engineFor(staff).layout();
      final first = notes.map((n) => n.beam).toList();
      engineFor(staff).layout();
      engineFor(staff).layout();
      expect(notes.map((n) => n.beam).toList(), first);
    });

    test('two different widths leave the same beams', () {
      final notes = [
        for (var i = 0; i < 8; i++) _n('C', 5, DurationType.eighth),
      ];
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          ...notes,
        ])
      ]);
      engineFor(staff, width: 2000).layout();
      final wide = notes.map((n) => n.beam).toList();
      engineFor(staff, width: 300).layout();
      expect(notes.map((n) => n.beam).toList(), wide,
          reason: 'beam grouping depends on the meter, not on the line width; '
              'if it did not, sharing a Staff between two MusicScore widgets of '
              'different widths would corrupt one of them.');
    });

    test('autoBeaming: false leaves the author beams untouched', () {
      final notes = [
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.eighth),
          beam: BeamType.start,
        ),
        Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const Duration(DurationType.eighth),
          beam: BeamType.end,
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 5),
          duration: const Duration(DurationType.eighth),
        ),
        Note(
          pitch: const Pitch(step: 'F', octave: 5),
          duration: const Duration(DurationType.eighth),
        ),
      ];
      final measure = Measure(autoBeaming: false);
      measure.elements.add(Clef(clefType: ClefType.treble));
      measure.elements.add(TimeSignature(numerator: 2, denominator: 4));
      for (final n in notes) {
        measure.elements.add(n);
      }

      engineFor(Staff(measures: [measure])).layout();
      expect(notes.map((n) => n.beam).toList(),
          [BeamType.start, BeamType.end, null, null],
          reason: 'the engine must not overwrite explicit beams when the author '
              'turned auto-beaming off.');
    });
  });

  group('dry-run risk — measuring a measure must not leak', () {
    test('note positions are the real ones, not the probe ones', () {
      final notes = [for (var i = 0; i < 4; i++) _n('C', 5)];
      final engine = engineFor(Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), ...notes])
      ]));
      final positioned = engine.layout();

      for (final note in notes) {
        final mapped = engine.noteXPositions[note];
        final drawn = positioned
            .firstWhere((p) => identical(p.element, note))
            .position
            .dx;
        expect(mapped, isNotNull);
        expect(mapped, closeTo(drawn, 1e-6),
            reason: 'the throwaway measuring cursor starts at x=0; if its '
                'writes survived, the map would hold probe coordinates.');
      }
    });

    test('tuplet inner notes are not left at probe coordinates', () {
      final inner = [
        _n('C', 5, DurationType.eighth),
        _n('D', 5, DurationType.eighth),
        _n('E', 5, DurationType.eighth),
      ];
      final tuplet =
          Tuplet(elements: inner, actualNotes: 3, normalNotes: 2);
      final engine = engineFor(Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), tuplet])
      ]));
      final positioned = engine.layout();
      final tupletX = positioned
          .firstWhere((p) => identical(p.element, tuplet))
          .position
          .dx;

      expect(engine.noteXPositions[inner.first], closeTo(tupletX, 1e-6));
      for (final note in inner) {
        expect(engine.noteXPositions[note]!, greaterThanOrEqualTo(tupletX));
      }
    });

    test('measuring twice gives the same answer', () {
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          for (var i = 0; i < 5; i++) _n('C', 5, DurationType.eighth),
        ])
      ]);
      final a = engineFor(staff).layout().map((p) => p.position.dx).toList();
      final b = engineFor(staff).layout().map((p) => p.position.dx).toList();
      expect(a, b);
    });
  });

  group('compression risk', () {
    Measure dense(int n) => _bar([
          for (var i = 0; i < n; i++) _n('C', 5, DurationType.sixteenth),
        ]);

    test('compression does not leak into the following bar', () {
      final normalBar = _bar([for (var i = 0; i < 4; i++) _n('G', 4)]);
      final staff = Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), ...dense(24).elements]),
        normalBar,
      ]);
      final engine = engineFor(staff, width: 420);
      final positioned = engine.layout();

      // Reference: the same normal bar laid out on its own, uncompressed.
      final refStaff = Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), ...normalBar.elements]),
      ]);
      final ref = engineFor(refStaff, width: 100000)
          .layout()
          .where((p) => p.element is Note)
          .toList();
      final refGap = ref[1].position.dx - ref[0].position.dx;

      final bar2 = positioned
          .where((p) => p.element is Note && p.measureIndex == 1)
          .toList();
      expect(bar2.length, 4);
      final gap = bar2[1].position.dx - bar2[0].position.dx;
      expect(gap, closeTo(refGap, refGap * 0.35),
          reason: 'the compression applied to bar 1 must be reset before bar 2.');
    });

    test('the collision floor holds under maximum compression', () {
      final staff = Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), ...dense(48).elements]),
      ]);
      final notes = engineFor(staff, width: 300)
          .layout()
          .where((p) => p.element is Note)
          .toList();
      final head = metadata.getGlyphWidth('noteheadBlack') * 12.0;
      for (var i = 1; i < notes.length; i++) {
        final gap = notes[i].position.dx - notes[i - 1].position.dx;
        expect(gap, greaterThan(head * 0.8),
            reason: 'compression must stop before the noteheads merge.');
      }
    });

    test('justification never re-inflates a compressed system past the line',
        () {
      final staff = Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), ...dense(20).elements]),
        _bar([for (var i = 0; i < 4; i++) _n('G', 4)]),
        _bar([for (var i = 0; i < 4; i++) _n('A', 4)]),
      ]);
      const width = 520.0;
      final engine = engineFor(staff, width: width);
      final positioned = engine.layout();
      for (final system in positioned.map((p) => p.system).toSet()) {
        final maxX = positioned
            .where((p) => p.system == system)
            .map((p) => p.position.dx)
            .reduce(math.max);
        // A compressed system may still overflow (and is then scrollable), but
        // justification must never PUSH a system further right than the margin.
        final systemNeeded = engine.contentWidth(
          positioned.where((p) => p.system == system).toList(),
        );
        expect(maxX, lessThanOrEqualTo(systemNeeded));
      }
    });
  });

  group('onset precision risk', () {
    test('nested tuplet onsets stay distinct and ordered', () {
      final inner = Tuplet(
        elements: [
          _n('C', 5, DurationType.sixteenth),
          _n('D', 5, DurationType.sixteenth),
          _n('E', 5, DurationType.sixteenth),
        ],
        actualNotes: 3,
        normalNotes: 2,
        isNested: true,
      );
      final outer = Tuplet(
        elements: [
          _n('G', 4, DurationType.eighth),
          inner,
          _n('B', 4, DurationType.eighth),
        ],
        actualNotes: 5,
        normalNotes: 4,
      );
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          outer,
          _n('C', 5),
        ])
      ]);
      final positioned = engineFor(staff, width: 1200).layout();
      final onsets = positioned
          .where((p) => p.element is Note || p.element is Tuplet)
          .map((p) => p.onset)
          .toList();
      for (final o in onsets) {
        expect(o.isFinite, isTrue);
      }
      // The note after the tuplet must start strictly later than the tuplet.
      final tupletOnset = positioned
          .firstWhere((p) => identical(p.element, outer))
          .onset;
      final afterOnset = positioned
          .lastWhere((p) => p.element is Note && p.measureIndex == 0)
          .onset;
      expect(afterOnset, greaterThan(tupletOnset));
    });

    test('a 1/2048 note still advances the onset', () {
      final a = _n('C', 5, DurationType.twoThousandFortyEighth);
      final b = _n('D', 5, DurationType.twoThousandFortyEighth);
      final positioned = engineFor(Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), a, b])
      ])).layout();
      final onsets = positioned
          .where((p) => p.element is Note)
          .map((p) => p.onset)
          .toList();
      expect(onsets[1], greaterThan(onsets[0]));
    });
  });
}
