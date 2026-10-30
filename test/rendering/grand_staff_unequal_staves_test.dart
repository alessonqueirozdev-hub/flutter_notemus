// test/rendering/grand_staff_unequal_staves_test.dart
//
// A system carries its bar numbers on from the bar before it, looked up per
// staff. When one staff is shorter than the score, a system that starts past
// its last bar had no number to look up, and the painter threw while being
// constructed (review on #51).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Measure _bar(List<MusicalElement> elements) => Measure()..elements.addAll(elements);

Note _whole(String step, int octave) => Note(
      pitch: Pitch(step: step, octave: octave),
      duration: const MusicDuration(DurationType.whole),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  test('a staff shorter than the score does not break later systems', () {
    final long = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        _whole('C', 5),
      ]),
      for (var i = 0; i < 23; i++) _bar([_whole('D', 5)]),
    ]);
    final short = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.bass),
        TimeSignature(numerator: 4, denominator: 4),
        _whole('C', 3),
      ]),
      _bar([_whole('D', 3)]),
    ]);

    final painter = GrandStaffPainter(
      staffGroup: StaffGroup(staves: [long, short], bracket: BracketType.brace),
      staffSpace: 12,
      metadata: metadata,
      theme: const MusicScoreTheme(),
      availableWidth: 400,
    );
    expect(painter.systemCount, greaterThan(1));
  });
}
