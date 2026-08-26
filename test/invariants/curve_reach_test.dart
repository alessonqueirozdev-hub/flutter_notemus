// test/invariants/curve_reach_test.dart
//
// A slur is drawn BETWEEN two notes and is not a positioned element, so it
// never appeared in the list `LayoutEngine.contentTopOverflow` walks. The
// canvas was therefore sized as if the arc were not there, and the apex was
// cut off by the top edge: measured at `staffSpace = 12` on a seven-note
// rising phrase under one slur, a 219 px canvas with 12 px of ink hard against
// row 0.
//
// This asserts the property that matters and not a pixel total: NO INK ON THE
// BOUNDARY ROWS. A clipped curve always leaves ink there, and the assertion
// stays true at any staff space and on any platform.

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

  test('a long slur no longer touches the canvas edge', () async {
    Note n(String s, int o, {SlurType? slur}) => Note(
        pitch: Pitch(step: s, octave: o),
        duration: const MusicDuration(DurationType.eighth),
        slur: slur);
    final staff = Staff(measures: [
      Measure()
        ..elements.addAll([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          n('B', 4, slur: SlurType.start),
          n('D', 5), n('E', 5), n('G', 5), n('A', 5), n('C', 6),
          n('E', 6, slur: SlurType.end),
        ])
    ]);
    final image = await rasterise(staff, metadata, width: 900, staffSpace: 12);
    var topRow = 0, bottomRow = 0, inkTop = image.height;
    for (var x = 0; x < image.width; x++) {
      if (image.dark(x, 0)) topRow++;
      if (image.dark(x, image.height - 1)) bottomRow++;
    }
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (image.dark(x, y)) { if (y < inkTop) inkTop = y; break; }
      }
    }
    // ignore: avoid_print
    print('canvas=${image.width}x${image.height} inkTop=$inkTop '
        'topRowInk=$topRow bottomRowInk=$bottomRow');
    expect(topRow, 0, reason: 'ink on the first row means the arc was clipped');
    expect(bottomRow, 0);
    expect(inkTop, greaterThan(0));
  });
}
