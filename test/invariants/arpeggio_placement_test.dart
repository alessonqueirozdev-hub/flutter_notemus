// test/invariants/arpeggio_placement_test.dart
//
// Two things were wrong with the arpeggio sign, and the first was a rule the
// code invented and attributed to a page that does not say it:
//
//     // Per engraving convention (Gould "Behind Bars" p.137):
//     // Arpeggios always appear on the side of the noteheads opposite the
//     // stem
//
// An arpeggio sign is written to the LEFT of the chord, always. It tells the
// player to roll the chord, so it is read before the notes and written before
// them; the stem has nothing to do with it. A stem-down chord had its sign
// drawn to the RIGHT, detached from the music it belongs to.
//
// The second was geometry. The sign is a horizontal glyph rotated -90 degrees,
// and under that rotation the `centerHorizontally` / `centerVertically` flags
// act on swapped axes — so the glyph's own WIDTH was left uncentred along the
// canvas x. Measured at `staffSpace = 26`: the caller asked for x = 239.1 and
// the ink arrived centred on 278.5, a residual of 39.4 px against a glyph
// 1.300 staff spaces wide. With a 0.03 staff-space "clearance" on top of that,
// the sign was drawn straight through the noteheads.
//
// This asserts the property, not the pixels: the sign's ink must finish before
// the chord's ink begins.

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

  Staff build({required bool arp}) {
    Note n(String s, int o) => Note(
        pitch: Pitch(step: s, octave: o),
        duration: const MusicDuration(DurationType.half));
    return Staff(measures: [
      Measure()
        ..elements.addAll([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          Chord(
            notes: [n('C', 5), n('E', 5), n('G', 5)],
            duration: const MusicDuration(DurationType.half),
            ornaments: arp ? [Ornament(type: OrnamentType.arpeggio)] : const [],
          ),
        ])
    ]);
  }

  test('the arpeggio sign clears the noteheads', () async {
    final withArp = await rasterise(build(arp: true), metadata,
        width: 500, staffSpace: 26);
    final without = await rasterise(build(arp: false), metadata,
        width: 500, staffSpace: 26);

    // Columns where only the arpeggio version has ink = the sign.
    final signCols = <int>[];
    final chordCols = <int>[];
    for (var x = 0; x < withArp.width; x++) {
      var onlyArp = false, plain = false;
      for (var y = 0; y < withArp.height; y++) {
        final a = withArp.dark(x, y);
        final b = without.dark(x, y);
        if (a && !b) onlyArp = true;
        if (b) plain = true;
      }
      if (onlyArp) signCols.add(x);
      if (plain) chordCols.add(x);
    }
    // Restrict the "chord" columns to the notehead band (right of the meter).
    final heads = chordCols.where((x) => x > 200).toList();
    // ignore: avoid_print
    print('sign columns  ${signCols.isEmpty ? "none" : "${signCols.first}..${signCols.last}"}');
    // ignore: avoid_print
    print('chord columns ${heads.isEmpty ? "none" : "${heads.first}..${heads.last}"}');
    expect(signCols, isNotEmpty);
    expect(signCols.last, lessThan(heads.first),
        reason: 'the arpeggio sign must finish before the leftmost notehead '
            'ink starts; sign ends at ${signCols.last}, chord starts at '
            '${heads.first}');
  });
}
