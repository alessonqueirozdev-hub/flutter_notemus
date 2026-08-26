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
// ---------------------------------------------------------------------------
// Why every assertion here is a RELATION and never a pixel total
// ---------------------------------------------------------------------------
//
// This file used to assert literal ink counts measured on Windows — 1832 for a
// beamed triplet, 1960 with a bracket, 1859 for a triplet of quarters. All of
// them passed on Windows and ALL of them failed the first time CI ran this
// suite on another operating system:
//
//     macOS   every case +226 px    (1832 -> 2058, 1859 -> 2085, 1960 -> 2186)
//     Ubuntu  every case  -98 px    (1832 -> 1734, 1859 -> 1756, 1960 -> 1862)
//
// A CONSTANT offset per platform, identical across every case. That is not the
// bracket changing: it is the clef, the meter and the tuplet numeral — the
// glyph and text runs — rasterising with different hinting and anti-aliasing.
// The engraving decision under test was correct on all three platforms the
// whole time; only the absolute totals were unportable, in exactly the way
// `matchesGoldenFile` is (see `dart_test.yaml`).
//
// So each test below measures the SAME figure twice, differing only in the
// bracket decision, and asserts the relation between the two. Whatever the host
// does to a clef it does to both sides, and the difference is the bracket.
// The Windows deltas are recorded in comments as documentation, never asserted.

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

  // Three figures, each built fresh per call because a `Tuplet` takes ownership
  // of the elements it is handed.
  List<MusicalElement> beamedEighths() => [n('C', 5), n('E', 5), n('G', 5)];

  List<MusicalElement> withRest() => [
        n('C', 5),
        Rest(duration: Duration(DurationType.eighth)),
        n('G', 5),
      ];

  List<MusicalElement> quarters() => [
        n('C', 5, d: DurationType.quarter),
        n('E', 5, d: DurationType.quarter),
        n('G', 5, d: DurationType.quarter),
      ];

  /// Ink for one figure under one bracket decision.
  ///
  /// [suppress] uses the deprecated author override, which is the only way to
  /// force NO bracket onto a figure the rule would bracket — that makes it the
  /// control measurement for "this figure, minus the bracket".
  Future<int> ink(
    List<MusicalElement> Function() figure, {
    TupletBracket? config,
    bool suppress = false,
  }) =>
      inkOf(staffOf(Tuplet(
        actualNotes: 3,
        normalNotes: 2,
        elements: figure(),
        bracketConfig: config,
        // ignore: deprecated_member_use_from_same_package
        showBracket: !suppress,
      )));

  group('Behind Bars p.201: a beamed group shows its numeral, not a bracket',
      () {
    test('a triplet of three beamed eighths draws no bracket', () async {
      // The measurement that matters: the DEFAULT rendering of a fully beamed
      // triplet must land on exactly the same page as the same triplet with the
      // bracket explicitly suppressed — i.e. the rule declined to draw it.
      //
      // Before the renderer asked the rule, the default drew the bracket
      // unconditionally: 1960 against 1832 on Windows, a 128 px difference that
      // is the bracket line and its two hooks.
      final byRule = await ink(beamedEighths);
      final suppressed = await ink(beamedEighths, suppress: true);
      expect(byRule, suppressed,
          reason: 'a beam already delimits the group, so the rule must decline '
              'the bracket and match the explicitly-suppressed rendering. '
              'byRule=$byRule suppressed=$suppressed');

      // And it is genuinely absent rather than drawn somewhere invisible:
      // forcing it on adds ink to this very figure. Without this second half
      // the test above would also pass if the bracket had stopped drawing
      // altogether.
      final forced = await ink(beamedEighths,
          config: const TupletBracket(alwaysShow: true));
      expect(forced, greaterThan(byRule),
          reason: 'forcing the bracket must add ink; if it does not, the first '
              'assertion is measuring nothing. forced=$forced byRule=$byRule');
    });

    test('a triplet containing a rest keeps its bracket', () async {
      // Nothing spans the group, so the bracket is the only thing that says how
      // far it reaches. This is also the case that breaks if the rule is handed
      // `Tuplet.notes` instead of `Tuplet.elements`: the rest becomes invisible
      // and the two beamed notes look like a fully beamed group.
      final byRule = await ink(withRest);
      final suppressed = await ink(withRest, suppress: true);
      expect(byRule, greaterThan(suppressed),
          reason: 'the bracket must be drawn: a tuplet containing a rest has '
              'nothing else to delimit the group. byRule=$byRule '
              'suppressed=$suppressed');
    });

    test('a triplet of quarters keeps its bracket', () async {
      // Quarters cannot be beamed at all, so there is nothing to delimit the
      // group but the bracket.
      final byRule = await ink(quarters);
      final suppressed = await ink(quarters, suppress: true);
      expect(byRule, greaterThan(suppressed),
          reason: 'quarters cannot be beamed, so the bracket is the only '
              'delimiter. byRule=$byRule suppressed=$suppressed');
    });
  });

  group('the author still wins', () {
    test('the deprecated showBracket: false suppresses', () async {
      // The same two numbers as the quarters test above, asserted from the
      // author-override side: this is the escape hatch, and it has to work
      // against a figure the RULE wants to bracket.
      final byRule = await ink(quarters);
      final suppressed = await ink(quarters, suppress: true);
      expect(suppressed, lessThan(byRule),
          reason: 'showBracket: false must remove the bracket the rule wanted. '
              'suppressed=$suppressed byRule=$byRule');
    });

    test('bracketConfig show: false suppresses — it used to be ignored',
        () async {
      // Measured before this wave: IDENTICAL to the default in every case. The
      // documented configuration object had no effect on the drawing at all,
      // because the renderer never consulted it.
      //
      // Asserted on QUARTERS, not on beamed eighths: on a beamed group the rule
      // already declines the bracket, so `show: false` matching the default
      // would prove nothing at all. On quarters the rule WANTS a bracket, so
      // the config has to overrule it.
      final byRule = await ink(quarters);
      final off = await ink(quarters, config: const TupletBracket(show: false));
      expect(off, lessThan(byRule),
          reason: 'bracketConfig(show: false) must overrule a rule that wants '
              'the bracket. off=$off byRule=$byRule');

      // And it must land on the same page as the deprecated override, not
      // merely somewhere smaller.
      final suppressed = await ink(quarters, suppress: true);
      expect(off, suppressed,
          reason: 'the two suppression routes must produce the same drawing. '
              'off=$off suppressed=$suppressed');
    });

    test('bracketConfig alwaysShow: true forces the bracket over a beam',
        () async {
      final byRule = await ink(beamedEighths);
      final forced = await ink(beamedEighths,
          config: const TupletBracket(alwaysShow: true));
      expect(forced, greaterThan(byRule),
          reason: 'alwaysShow must beat the p.201 rule. forced=$forced '
              'byRule=$byRule');
    });

    test('BracketSide.notehead forces the bracket over a beam', () async {
      final byRule = await ink(beamedEighths);
      final forced = await ink(beamedEighths,
          config: const TupletBracket(side: BracketSide.notehead));
      expect(forced, greaterThan(byRule),
          reason: 'asking for the bracket on the notehead side is asking for a '
              'bracket. forced=$forced byRule=$byRule');
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
      final tuplet =
          Tuplet(actualNotes: 3, normalNotes: 2, elements: withRest());
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
