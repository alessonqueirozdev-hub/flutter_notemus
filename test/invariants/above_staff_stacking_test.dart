// test/invariants/above_staff_stacking_test.dart
//
// Marks that float above the staff — tempo text, rehearsal letters, expression
// text — are deliberately given NO horizontal advance, so that adding a
// direction never moves the notes. That invariant is right, and it had a
// consequence nobody handled: two directions close together had nothing
// keeping them apart and were simply drawn on top of each other. Reported from
// the tempo page, where "Quarter = Eighth (metronome 120)" ran straight
// through "Range 120-132".
//
// Since they cannot move sideways, they move OUT: `LayoutEngine`
// interval-packs them into rows above the staff and reserves the height of the
// tallest stack.
//
// The second assertion here found a defect that had nothing to do with
// stacking: a SINGLE tempo mark was already being clipped. Its centre sits
// 3.95 staff spaces above the top line and the metronome note glyph beside the
// text is taller than the text, but only 5.0 staff spaces were reserved —
// measured, 1 px of ink hard against row 0.

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

  Note n(String s, int o) => Note(
      pitch: Pitch(step: s, octave: o),
      duration: const MusicDuration(DurationType.quarter));

  Staff build({required bool twoMarks}) => Staff(measures: [
        Measure()
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            TempoMark(
                beatUnit: DurationType.quarter,
                bpm: 120,
                text: 'Quarter = Eighth'),
            n('C', 4), n('D', 4), n('E', 4),
            if (twoMarks)
              TempoMark(
                  beatUnit: DurationType.quarter,
                  bpm: 126,
                  text: 'Range 120-132'),
            n('F', 4), n('G', 4), n('A', 4),
          ])
      ]);

  test('two overlapping tempo marks are stacked, not superimposed', () async {
    final engine = LayoutEngine(build(twoMarks: true),
        availableWidth: 900, staffSpace: 12, metadata: metadata);
    final els = engine.layout();
    final marks = els.where((e) => e.element is TempoMark).toList();
    expect(marks.length, 2);

    final a = marks[0], b = marks[1];
    final aRight = a.position.dx + engine.elementWidth(a.element);
    // ignore: avoid_print
    print('mark A x=${a.position.dx.toStringAsFixed(1)} '
        'right=${aRight.toStringAsFixed(1)} '
        'level=${engine.aboveStaffLevels[a.element]}');
    // ignore: avoid_print
    print('mark B x=${b.position.dx.toStringAsFixed(1)} '
        'level=${engine.aboveStaffLevels[b.element]}');

    expect(b.position.dx, lessThan(aRight),
        reason: 'the two marks must genuinely overlap horizontally, or this '
            'test is not exercising the packing');
    expect(engine.aboveStaffLevels[b.element], greaterThan(0),
        reason: 'the second mark must be lifted to a free row');

    // And the taller stack must be reserved, or the lifted mark is clipped.
    final one = LayoutEngine(build(twoMarks: false),
        availableWidth: 900, staffSpace: 12, metadata: metadata);
    final oneEls = one.layout();
    final h1 = one.calculateTotalHeight(oneEls);
    final h2 = engine.calculateTotalHeight(els);
    // ignore: avoid_print
    print('height with one mark=$h1  with two=$h2');
    expect(h2, greaterThan(h1),
        reason: 'a stacked mark needs the page to grow, or it is drawn off it');

    for (final two in [false, true]) {
      final image = await rasterise(build(twoMarks: two), metadata,
          width: 900, staffSpace: 12);
      var topRow = 0;
      var inkTop = image.height;
      for (var x = 0; x < image.width; x++) {
        if (image.dark(x, 0)) topRow++;
      }
      for (var y = 0; y < image.height; y++) {
        var found = false;
        for (var x = 0; x < image.width; x++) {
          if (image.dark(x, y)) { found = true; break; }
        }
        if (found) { inkTop = y; break; }
      }
      // ignore: avoid_print
      print('twoMarks=$two canvas=${image.width}x${image.height} '
          'inkTop=$inkTop topRowInk=$topRow');
      expect(topRow, 0,
          reason: 'ink on row 0 means the mark was clipped off the page '
              '(twoMarks=$two)');
      expect(inkTop, greaterThan(0));
    }
  });
}
