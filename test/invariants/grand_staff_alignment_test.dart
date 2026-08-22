// L7 end to end — the shared time grid across a grand staff.
//
// The audit's single most damaging engraving finding: `GrandStaffPainter` ran an
// INDEPENDENT `LayoutEngine` per staff and then patched the result by remapping
// between barline anchors. Inside a bar the staves therefore disagreed. With
// four quarters in the treble against two halves in the bass, beat 3 landed
// 38.1 px apart — more than three staff spaces — which is the first thing any
// pianist would notice and the first thing an engraver would reject.
//
// Alignment now runs on MUSICAL ONSETS carried by every PositionedElement, so
// this file asserts the property directly rather than freezing a picture of it.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/grand_staff_painter.dart';

Note _n(String step, int octave, [DurationType d = DurationType.quarter]) =>
    Note(pitch: Pitch(step: step, octave: octave), duration: Duration(d));

Measure _bar(List<MusicalElement> elements) {
  final m = Measure();
  for (final e in elements) {
    m.elements.add(e);
  }
  return m;
}

/// X of the left-most element at [onset] on one staff, or null.
double? _xAt(List<PositionedElement> elements, double onset) {
  double? x;
  for (final pe in elements) {
    final isMusic = pe.element is Note ||
        pe.element is Chord ||
        pe.element is Rest ||
        pe.element is Tuplet;
    if (!isMusic) continue;
    if ((pe.onset - onset).abs() > 1e-6) continue;
    if (x == null || pe.position.dx < x) x = pe.position.dx;
  }
  return x;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  GrandStaffPainter painterFor(List<Staff> staves, {double width = 700}) =>
      GrandStaffPainter(
        staffGroup: StaffGroup(staves: staves, bracket: BracketType.brace),
        staffSpace: 12,
        metadata: metadata,
        theme: const MusicScoreTheme(),
        availableWidth: width,
      );

  test('four quarters against two halves agree on every beat', () {
    final treble = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        _n('C', 5), _n('D', 5), _n('E', 5), _n('F', 5),
      ])
    ]);
    final bass = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.bass),
        TimeSignature(numerator: 4, denominator: 4),
        _n('C', 3, DurationType.half),
        _n('G', 3, DurationType.half),
      ])
    ]);

    final painter = painterFor([treble, bass]);
    final system = painter.alignedSystem(0);
    expect(system, hasLength(2));

    // Beat 1 and beat 3 exist on both staves and must share an X.
    for (final onset in [0.0, 0.5]) {
      final top = _xAt(system[0], onset);
      final bottom = _xAt(system[1], onset);
      expect(top, isNotNull, reason: 'treble has an event at onset $onset');
      expect(bottom, isNotNull, reason: 'bass has an event at onset $onset');
      expect((top! - bottom!).abs(), lessThan(0.5),
          reason: 'onset $onset must be one vertical column across the system; '
              'it used to drift by 38 px.');
    }
  });

  test('eighths against a whole note keep the downbeat aligned', () {
    final treble = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        for (var i = 0; i < 8; i++)
          _n('CDEFGAB'[i % 7], 5, DurationType.eighth),
      ])
    ]);
    final bass = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.bass),
        TimeSignature(numerator: 4, denominator: 4),
        _n('C', 3, DurationType.whole),
      ])
    ]);

    final system = painterFor([treble, bass]).alignedSystem(0);
    final top = _xAt(system[0], 0.0);
    final bottom = _xAt(system[1], 0.0);
    expect((top! - bottom!).abs(), lessThan(0.5));
  });

  test('three staves stay on one grid', () {
    Staff line(String step, int octave, int count, DurationType d,
            ClefType clef) =>
        Staff(measures: [
          _bar([
            Clef(clefType: clef),
            TimeSignature(numerator: 4, denominator: 4),
            for (var i = 0; i < count; i++) _n(step, octave, d),
          ])
        ]);

    final system = painterFor([
      line('C', 5, 4, DurationType.quarter, ClefType.treble),
      line('E', 4, 2, DurationType.half, ClefType.treble),
      line('C', 3, 8, DurationType.eighth, ClefType.bass),
    ]).alignedSystem(0);

    expect(system, hasLength(3));
    for (final onset in [0.0, 0.5]) {
      final xs = [
        for (final staff in system)
          if (_xAt(staff, onset) != null) _xAt(staff, onset)!,
      ];
      expect(xs.length, 3, reason: 'all three staves sound at onset $onset');
      final spread = xs.reduce((a, b) => a > b ? a : b) -
          xs.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThan(0.5));
    }
  });

  test('the grid never reorders a staff events', () {
    final treble = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        for (var i = 0; i < 8; i++)
          _n('CDEFGAB'[i % 7], 5, DurationType.eighth),
      ])
    ]);
    final bass = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.bass),
        TimeSignature(numerator: 4, denominator: 4),
        _n('C', 3, DurationType.half),
        _n('G', 3, DurationType.half),
      ])
    ]);

    for (final staff in painterFor([treble, bass]).alignedSystem(0)) {
      final music = staff
          .where((p) => p.element is Note || p.element is Rest)
          .toList();
      for (var i = 1; i < music.length; i++) {
        expect(music[i].position.dx,
            greaterThanOrEqualTo(music[i - 1].position.dx - 1e-6),
            reason: 'the piecewise remap must stay monotonic');
      }
    }
  });
}
