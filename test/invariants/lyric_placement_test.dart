// test/invariants/lyric_placement_test.dart
//
// The lyric line used to sit a FIXED 1.5 staff spaces below the bottom staff
// line, knowing nothing about how far the music descended. A C4 in treble clef
// is one ledger line below the staff, and its notehead lands exactly there — so
// the first syllable of a phrase was printed THROUGH the note it belongs to.
// Reported from the "Single Verse with Syllabification" page, where "Glo" is
// overlapped by its own notehead and ledger line.
//
// Measured at `staffSpace = 15` with the lowest note at dy 120: the fixed line
// fell at 127.5 against a notehead bottom edge of 129 — 1.5 px INSIDE the note.
// The measured line falls at 144, clearing it by 15 px.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

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

  test('a syllable under a low note does not sit inside the notehead', () async {
    Note sung(String step, int octave, String text) => Note(
          pitch: Pitch(step: step, octave: octave),
          duration: const MusicDuration(DurationType.quarter),
          syllables: [Syllable(text: text)],
        );
    // C4 in treble clef: one ledger line below the staff — exactly where the
    // fixed lyric offset used to put the text.
    final staff = Staff(measures: [
      Measure()
        ..elements.addAll([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          sung('C', 4, 'Glo'),
          sung('E', 4, 'ri'),
          sung('G', 4, 'a'),
          sung('C', 5, 'in'),
        ])
    ]);

    const ss = 15.0;
    final engine = LayoutEngine(staff, availableWidth: 700,
        staffSpace: ss, metadata: metadata);
    final els = engine.layout();
    final noteY = els
        .where((e) => e.element is Note)
        .map((e) => e.position.dy)
        .reduce((a, b) => a > b ? a : b);
    // The layout puts the first system's baseline at
    // `firstBaselineSpaces * staffSpace`, which is the same origin the note
    // positions above are in. Mixing that with a zero baseline compares two
    // different coordinate spaces and produces a nonsense clearance.
    final baselineY = LayoutEngine.firstBaselineSpaces * ss;
    final line = LyricLayout.firstLineY(
      elements: els, system: 0,
      staffBaselineY: baselineY, staffSpace: ss,
    );
    final fallback = LyricLayout.fallbackFirstLineY(
      staffBaselineY: baselineY, staffSpace: ss,
    );
    // ignore: avoid_print
    print('lowest note dy=$noteY  fallbackLine=$fallback  measuredLine=$line');
    // ignore: avoid_print
    print('clearance below the lowest notehead: '
        '${(line - (noteY + ss * 0.6)).toStringAsFixed(1)} px '
        '(was ${(fallback - (noteY + ss * 0.6)).toStringAsFixed(1)} px)');
    expect(line, greaterThan(noteY + ss * 0.6),
        reason: 'the lyric line must clear the lowest notehead');
  });
}
