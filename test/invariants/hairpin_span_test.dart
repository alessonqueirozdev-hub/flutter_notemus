// test/invariants/hairpin_span_test.dart
//
// A hairpin attached to a NOTE — `Note(dynamicElement: ...)`, the form every
// example in this package uses — never received a musical span. `StaffRenderer`
// computed one, correctly, but only in the branch that draws a STANDALONE
// `Dynamic`; the note-attached path fell through to a fixed `staffSpace * 6`
// stub with no relationship to the music. That is why the crescendo and
// diminuendo on the dynamics page sat bunched at the left of their bars
// instead of reaching across them.
//
// Measured at `staffSpace = 12` with barlines at 172.5 and 258.7: a hairpin
// declared with an explicit `length: 90` runs to x 292, overshooting the final
// barline by 33 px; with no length it finishes at 252, half a staff space
// short of the barline, which is where Behind Bars puts it.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import '../support/ink_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    final bytes = await File('assets/smufl/Bravura.otf').readAsBytes();
    await (FontLoader('packages/flutter_notemus/Bravura')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
  });

  Staff build({double? length}) {
    Measure bar(String step, DynamicType t) => Measure()
      ..elements.add(Note(
        pitch: Pitch(step: step, octave: 4),
        duration: const MusicDuration(DurationType.whole),
        dynamicElement:
            Dynamic(type: t, isHairpin: true, length: length),
      ));
    final m1 = bar('C', DynamicType.crescendo)
      ..elements.insert(0, TimeSignature(numerator: 4, denominator: 4))
      ..elements.insert(0, Clef(clefType: ClefType.treble));
    return Staff(measures: [m1, bar('E', DynamicType.diminuendo)]);
  }

  /// Horizontal extent of ink strictly BELOW the staff, where the hairpin is
  /// the only thing drawn in this score.
  Future<List<int>> belowStaffExtent(Staff staff) async {
    final image = await rasterise(staff, metadata, width: 900, staffSpace: 12);
    // Find the bottom staff line: the lowest row that is dark across a wide
    // span. Everything under it is hairpin territory.
    var bottomLine = 0;
    for (var y = 0; y < image.height; y++) {
      var c = 0;
      for (var x = 0; x < image.width; x++) {
        if (image.dark(x, y)) c++;
      }
      if (c > image.width * 0.25) bottomLine = y;
    }
    var minX = image.width, maxX = -1, ink = 0;
    for (var y = bottomLine + 3; y < image.height; y++) {
      // Skip the clef: a treble clef's tail descends below the staff.
      for (var x = 100; x < image.width; x++) {
        if (image.dark(x, y)) {
          ink++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
        }
      }
    }
    return [minX, maxX, ink];
  }

  List<double> barlineXs(Staff staff) {
    final engine = LayoutEngine(staff,
        availableWidth: 900, staffSpace: 12, metadata: metadata);
    return engine
        .layout()
        .where((e) => e.element is Barline)
        .map((e) => e.position.dx)
        .toList();
  }

  test('a note-attached hairpin spans its bar and stops at the barline',
      () async {
    final fixed = await belowStaffExtent(build(length: 90.0));
    final musical = await belowStaffExtent(build());
    // ignore: avoid_print
    print('explicit length 90px -> x ${fixed[0]}..${fixed[1]} '
        '(${fixed[1] - fixed[0]} px wide, ${fixed[2]} px of ink)');
    // ignore: avoid_print
    print('no length (musical)  -> x ${musical[0]}..${musical[1]} '
        '(${musical[1] - musical[0]} px wide, ${musical[2]} px of ink)');
    final bars = barlineXs(build());
    // ignore: avoid_print
    print('barlines at $bars');

    final lastBar = bars.last;
    expect(musical[1], lessThan(lastBar),
        reason: 'a musical hairpin must stop before the final barline at '
            '$lastBar; it reached ${musical[1]}');
    expect(fixed[1].toDouble(), greaterThan(lastBar),
        reason: 'the fixed 90px hairpin is expected to overshoot the barline, '
            'which is the behaviour being replaced');

    // And it must REACH its barline rather than stub out at the old fixed
    // `staffSpace * 6` = 72 px. The gap the renderer leaves before a barline is
    // half a staff space, so 12 px of tolerance is generous.
    expect(musical[1], closeTo(lastBar - 6, 12),
        reason: 'the hairpin should finish just short of its barline at '
            '$lastBar, not stub out; it ended at ${musical[1]}');
  });
}
