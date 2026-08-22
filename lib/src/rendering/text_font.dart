// lib/src/rendering/text_font.dart
//
// One canonical text-font fallback chain for every non-SMuFL string the engine
// draws: measure numbers, lyrics, tempo and expression marks, instrument names,
// tuplet numerals, rehearsal marks, repeat texts.
//
// Why this file exists
// --------------------
// Only `SymbolAndTextRenderer` used to carry the chain. Every other text site
// built a bare `TextStyle`, so the family was whatever the enclosing
// `DefaultTextStyle`/`Theme` happened to supply. Inside the widget tree an app
// theme usually supplies one and the text looks right; in the HEADLESS path
// (`ScoreRasterizer`, and therefore `PdfExporter`) there is no theme ancestor
// and the text degraded to `.notdef` boxes.
//
// The 2.7.0 goldens did not catch it because `test/golden/_harness.dart`
// injects `ThemeData.fontFamily = 'Roboto'` — a family the library never asks
// for. The test passed for a reason unrelated to the code under test.
//
// Rule: every `TextStyle` handed to a `TextPainter` in this package must pass
// through [MusicTextFallback.withMusicTextFallback] first.

import 'package:flutter/widgets.dart';

/// Text faces named by `engravingDefaults.textFontFamily` in the SMuFL
/// reference metadata, ending in the generic `serif` so the platform always has
/// something to resolve.
///
/// These are *text* faces and have nothing to do with the music font, which is
/// never named literally anywhere in this package (see `BaseGlyphRenderer`,
/// "Font independence") and always comes from `SmuflMetadata.font`.
const List<String> kMusicTextFontFallback = <String>[
  'Academico',
  'Century Schoolbook',
  'Edwin',
  'serif',
];

/// Adds [kMusicTextFontFallback] to a text style unless the caller already
/// supplied their own fallback chain.
extension MusicTextFallback on TextStyle {
  /// Returns this style with the package's text fallback chain attached.
  ///
  /// A caller-supplied family or fallback chain always wins: a theme that names
  /// its own faces is making a deliberate choice and must not be overridden.
  ///
  /// IMPORTANT — why the PRIMARY family is set and not just the fallback:
  /// `fontFamilyFallback` is only consulted when the primary family cannot
  /// supply the glyph. Leaving `fontFamily` null means the platform default is
  /// the primary, and a default that CAN draw the glyph (the box-drawing test
  /// face `flutter_test` installs, for instance) satisfies the lookup, so the
  /// chain is never reached. Measured: a measure number rasterised through
  /// `ScoreRasterizer` came out as a solid `.notdef` box even with the fallback
  /// list attached. Naming the first text face as the primary is what actually
  /// fixes it, in the widget path and the headless path alike.
  TextStyle withMusicTextFallback() {
    final family = fontFamily;
    final chain = fontFamilyFallback;
    final hasChain = chain != null && chain.isNotEmpty;

    if (family != null && family.isNotEmpty) {
      // A named face already wins the lookup; just give it somewhere to go.
      return hasChain ? this : copyWith(fontFamilyFallback: kMusicTextFontFallback);
    }

    // No primary face: promote the head of the chain (the caller's own, when
    // they supplied one) so the lookup starts at a real text face instead of
    // the platform default.
    final resolved = hasChain ? chain : kMusicTextFontFallback;
    return copyWith(
      fontFamily: resolved.first,
      fontFamilyFallback: resolved.sublist(1),
    );
  }
}
