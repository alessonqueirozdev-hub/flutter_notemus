// test/layout/inherited_meter_beaming_test.dart
//
// Regression for #47 (fixed in #49, reported and fixed by @ArtSilver).
//
// Only the bar that CARRIES a TimeSignature beamed against it. Every later bar
// read `Measure.timeSignature` straight off the model, got null, and fell back
// to 4/4 — so two bars of 6/8 eighths beamed 3+3 and then 4+2. The meter a bar
// inherits lives in `LayoutEngine.inheritedTimeSignatures`, and beaming has to
// read it through `timeSignatureOf` like every other consumer.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  Note eighth() => Note(
        pitch: const Pitch(step: 'A', octave: 4),
        duration: const MusicDuration(DurationType.eighth),
      );

  /// One bar per entry of [eighthsPerBar]; [meters] maps a bar index to the
  /// meter that bar declares. Every other bar declares none.
  Staff build(List<int> eighthsPerBar, Map<int, TimeSignature> meters) {
    final staff = Staff();
    for (int i = 0; i < eighthsPerBar.length; i++) {
      final m = Measure();
      if (i == 0) m.add(Clef(clefType: ClefType.treble));
      final ts = meters[i];
      if (ts != null) m.add(ts);
      for (int n = 0; n < eighthsPerBar[i]; n++) {
        m.add(eighth());
      }
      staff.add(m);
    }
    return staff;
  }

  /// Beam group sizes per bar, as the engine resolved them.
  List<List<int>> groupsPerBar(Staff staff) {
    final engine = LayoutEngine(staff,
        availableWidth: 4000, staffSpace: 12, metadata: metadata);
    engine.layout();
    return [
      for (final m in staff.measures)
        () {
          final sizes = <int>[];
          int run = 0;
          for (final e in m.elements.whereType<Note>()) {
            switch (engine.beamOf(e)) {
              case BeamType.start:
                run = 1;
              case BeamType.inner:
                run++;
              case BeamType.end:
                sizes.add(run + 1);
                run = 0;
              default:
                break;
            }
          }
          return sizes;
        }(),
    ];
  }

  TimeSignature ts(int n, int d) => TimeSignature(numerator: n, denominator: d);

  test('#47: every bar of 6/8 beams 3+3, not only the first', () {
    expect(groupsPerBar(build([6, 6, 6], {0: ts(6, 8)})), [
      [3, 3],
      [3, 3],
      [3, 3],
    ]);
  });

  test('other compound meters hold their grouping in inherited bars', () {
    expect(groupsPerBar(build([9, 9], {0: ts(9, 8)})), [
      [3, 3, 3],
      [3, 3, 3],
    ]);
    expect(groupsPerBar(build([12, 12], {0: ts(12, 8)})), [
      [3, 3, 3, 3],
      [3, 3, 3, 3],
    ]);
  });

  test('a meter change mid-staff is inherited from the new meter', () {
    expect(
      groupsPerBar(build([6, 6, 6, 6], {0: ts(6, 8), 2: ts(3, 4)})),
      [
        [3, 3],
        [3, 3],
        [2, 2, 2],
        [2, 2, 2],
      ],
    );
  });
}
