// test/invariants/stem_direction_agreement_test.dart
//
// There were THREE copies of the stem-direction rule in this package and they
// disagreed at exactly one value — the middle line, which is the most common
// position on the staff:
//
//     note_renderer.dart      staffPosition < 0    (DRAWS the stem)
//     ornament_renderer.dart  staffPosition <= 0   (grace-slur side)
//     slur_renderer.dart      staffPosition <= 0   (slur side)
//
// So a B4 in treble clef had its stem drawn DOWNWARD while the slur logic
// believed it pointed up, and the mini-slur of an appoggiatura was placed
// below the notehead, straight across the stem it was meant to avoid.
// Reported from the "Upward and Downward Appoggiaturas" page, where the D5 in
// the same bar — also stem-down, but above the middle line — got it right and
// the B4 did not.
//
// This is a grep guard, not a behaviour test: the behaviour is already pinned
// by the goldens, and what must never come back is a SECOND copy of the rule.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  test('the middle line takes a downward stem', () {
    // Gould: a note ON the middle line takes a downward stem, so the test is
    // strict rather than inclusive.
    expect(StaffPositionCalculator.stemUpFor(-1), isTrue);
    expect(StaffPositionCalculator.stemUpFor(0), isFalse,
        reason: 'the middle line is stem DOWN');
    expect(StaffPositionCalculator.stemUpFor(1), isFalse);
  });

  test('nothing in lib/ re-derives the rule from a staff position', () {
    final offenders = <String>[];
    final pattern = RegExp(r'staffPosition\s*(<=|<|>=|>)\s*0');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The one place the rule is allowed to exist.
      if (entity.path.replaceAll(r'\', '/').endsWith(
          'lib/src/rendering/staff_position_calculator.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (!pattern.hasMatch(line)) continue;
        // `smufl_positioning_engine` tests position AND an already-resolved
        // stemUp together; it is asking a different question (which side of
        // the notehead the stem attaches to), not deciding the direction.
        if (line.contains('stemUp &&') || line.contains('!stemUp &&')) continue;
        offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'stem direction is decided in ONE place, '
            'StaffPositionCalculator.stemUpFor. These re-derive it:\n'
            '${offenders.join('\n')}');
  });
}
