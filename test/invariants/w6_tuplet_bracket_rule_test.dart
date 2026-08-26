// test/invariants/w6_tuplet_bracket_rule_test.dart
//
// The Behind Bars p.201 bracket rule, pinned at the level where it had been
// missing: the RENDERER.
//
// `TupletBracket.shouldShow` was written, then repaired twice (once to read the
// layout's beam decision instead of the model's, once to fold in
// `LayoutEngine.tupletBeams`) — and through all of it nothing called it.
// `Tuplet.shouldShowBracket` had zero callers in `lib/`, `example/` and
// `test/`; `TupletRenderer` gated the bracket on the DEPRECATED
// `Tuplet.showBracket`, which defaults to `true`. So the rule was correct,
// tested, and inert, and every tuplet this package ever drew was bracketed.
//
// These tests measure INK, not geometry, because ink is the thing that was
// wrong: the unit tests of `shouldShow` were green the whole time.
//
// Numbers below were measured at `staffSpace = 12`, `width = 900`, over the
// full raster (see `../support/ink_probe.dart`).

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

  Note n(String step, int octave, {DurationType d = DurationType.eighth}) =>
      Note(pitch: Pitch(step: step, octave: octave), duration: Duration(d));

  Staff staffOf(Tuplet tuplet) {
    final measure = Measure();
    measure.elements.addAll([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      tuplet,
    ]);
    return Staff()..measures.add(measure);
  }

  Future<int> inkOf(Staff staff) async {
    final image = await rasterise(staff, metadata, width: 900, staffSpace: 12);
    var count = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (image.dark(x, y)) count++;
      }
    }
    return count;
  }

  List<MusicalElement> beamedEighths() => [n('C', 5), n('E', 5), n('G', 5)];

  // The ink a fully beamed triplet draws WITHOUT a bracket: three noteheads,
  // three stems, one beam, the numeral, the clef and the meter.
  const int beamedWithoutBracket = 1832;

  // The same figure WITH the bracket: +128 px, the bracket line and its two
  // hooks. That was the unconditional default before this rule was wired in.
  const int beamedWithBracket = 1960;

  group('Behind Bars p.201: a beamed group shows its numeral, not a bracket',
      () {
    test('a triplet of three beamed eighths draws no bracket', () async {
      final ink = await inkOf(
        staffOf(Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          elements: beamedEighths(),
        )),
      );
      // Measured 1960 before the renderer asked the rule, 1832 after.
      expect(ink, beamedWithoutBracket);
    });

    test('a triplet containing a rest keeps its bracket', () async {
      // Nothing spans the group, so the bracket is the only thing that says
      // how far it reaches. This is also the case that breaks if the rule is
      // handed `Tuplet.notes` instead of `Tuplet.elements`: the rest becomes
      // invisible and the two beamed notes look like a fully beamed group.
      //
      // Asserted as a RELATION against the same tuplet with the bracket
      // explicitly suppressed, not as a literal ink total. It was `expect(ink,
      // 1542)`, and that broke the day rests started reserving the half of
      // their glyph that is drawn to the LEFT of their origin — the rest moved
      // by half a glyph, the total moved by 2 px, and a test about whether a
      // BRACKET IS DRAWN failed for a change in where a rest sits.
      List<MusicalElement> withRest() => [
            n('C', 5),
            Rest(duration: Duration(DurationType.eighth)),
            n('G', 5),
          ];
      final ink = await inkOf(
        staffOf(Tuplet(
            actualNotes: 3, normalNotes: 2, elements: withRest())),
      );
      final withoutBracket = await inkOf(
        staffOf(Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          elements: withRest(),
          // ignore: deprecated_member_use_from_same_package
          showBracket: false,
        )),
      );
      expect(ink, greaterThan(withoutBracket),
          reason: 'the bracket must be drawn: a tuplet containing a rest has '
              'nothing else to delimit the group. ink=$ink, '
              'same tuplet with the bracket suppressed=$withoutBracket');
    });

    test('a triplet of quarters keeps its bracket', () async {
      // Quarters cannot be beamed at all, so there is nothing to delimit the
      // group but the bracket.
      final ink = await inkOf(
        staffOf(Tuplet(actualNotes: 3, normalNotes: 2, elements: [
          n('C', 5, d: DurationType.quarter),
          n('E', 5, d: DurationType.quarter),
          n('G', 5, d: DurationType.quarter),
        ])),
      );
      expect(ink, 1859);
    });
  });

  group('the author still wins', () {
    test('the deprecated showBracket: false suppresses', () async {
      final ink = await inkOf(
        staffOf(Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          // ignore: deprecated_member_use
          showBracket: false,
          elements: [
            n('C', 5, d: DurationType.quarter),
            n('E', 5, d: DurationType.quarter),
            n('G', 5, d: DurationType.quarter),
          ],
        )),
      );
      // The unbeamed triplet above measures 1859 WITH its bracket.
      expect(ink, lessThan(1859));
    });

    test('bracketConfig show: false suppresses — it used to be ignored',
        () async {
      // Measured before this wave: 1960, i.e. IDENTICAL to the default. The
      // documented configuration object had no effect on the drawing at all,
      // because the renderer never consulted it.
      final ink = await inkOf(
        staffOf(Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          bracketConfig: const TupletBracket(show: false),
          elements: beamedEighths(),
        )),
      );
      expect(ink, beamedWithoutBracket);
    });

    test('bracketConfig alwaysShow: true forces the bracket over a beam',
        () async {
      final ink = await inkOf(
        staffOf(Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          bracketConfig: const TupletBracket(alwaysShow: true),
          elements: beamedEighths(),
        )),
      );
      expect(ink, beamedWithBracket);
    });

    test('BracketSide.notehead forces the bracket over a beam', () async {
      final ink = await inkOf(
        staffOf(Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          bracketConfig: const TupletBracket(side: BracketSide.notehead),
          elements: beamedEighths(),
        )),
      );
      expect(ink, beamedWithBracket);
    });
  });

  group('the model-level rule agrees with the ink', () {
    test('shouldShowBracket() is false for a beamed group, true without beams',
        () {
      final tuplet = Tuplet(
        actualNotes: 3,
        normalNotes: 2,
        elements: beamedEighths(),
      );
      expect(
        tuplet.shouldShowBracket(beamOf: (_) => BeamType.inner),
        isFalse,
        reason: 'a beam already delimits the group',
      );
      expect(
        tuplet.shouldShowBracket(beamOf: (_) => null),
        isTrue,
        reason: 'nothing delimits the group',
      );
      expect(
        tuplet.shouldShowBracket(),
        isTrue,
        reason: 'no decision given: fall back to the conservative answer',
      );
    });

    test('a rest keeps the bracket even when every note is beamed', () {
      // The regression `elements` vs `notes` guards against: with the
      // pre-filtered note list this returns false.
      final tuplet = Tuplet(actualNotes: 3, normalNotes: 2, elements: [
        n('C', 5),
        Rest(duration: Duration(DurationType.eighth)),
        n('G', 5),
      ]);
      expect(tuplet.shouldShowBracket(beamOf: (_) => BeamType.inner), isTrue);
      expect(
        const TupletBracket().shouldShow(
          tuplet.notes,
          beamOf: (_) => BeamType.inner,
        ),
        isFalse,
        reason: 'this is why the rule must be given elements, not notes',
      );
    });
  });
}
