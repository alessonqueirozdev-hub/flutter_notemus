// lib/src/rendering/text_font.dart
//
// One canonical text-font fallback chain for every non-SMuFL string the engine
// draws: measure numbers, lyrics, tempo and expression marks, instrument names,
// tuplet numerals, rehearsal marks, repeat texts, Gregorian syllables and
// Jianpu numerals.
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
// through [MusicTextFallback.withMusicTextFallback] first. The only exempt
// sites are the SMuFL/Greciliae GLYPH painters, which name
// `SmuflMetadata.font.fontFamily` (or `'Greciliae'` with
// `package: 'flutter_notemus'`) and must NOT be diverted to a text face.
//
// THE PACKAGE SHIPS NO TEXT FACE — read this before filing a `.notdef` bug
// --------------------------------------------------------------------------
// `pubspec.yaml` declares exactly two families, and both are music fonts:
// `Bravura` (SMuFL) and `Greciliae` (chant). None of the four names in
// [kMusicTextFontFallback] is bundled, so resolving them is entirely the HOST's
// job. Measured on 2.7.1 by rasterising one score four ways and varying only
// which text face was registered before the render:
//
//   registered faces                    | `.notdef` boxes in the CMN PNG
//   ------------------------------------+-------------------------------
//   Bravura + Greciliae only            | 16
//   ... + a real face named 'Academico' |  0
//   ... + a real face named 'serif'     | 16  (byte-identical MD5 to row 1)
//
// The third row is the important one: the terminal generic `'serif'` at the end
// of the chain is NOT a resolution guarantee. Flutter's engine matches the
// fallback entries against registered family NAMES, and on a host with no
// system font manager (headless test binaries, most CI images, Flutter Web
// before its font manifest loads) registering something literally called
// `serif` still did not satisfy the lookup — the MD5 of the PNG was unchanged.
//
// Consequence, stated plainly for the public API dartdocs that point here:
// **text rendering depends on the host providing one of the faces named in
// [kMusicTextFontFallback], or on the app injecting its own via
// [MusicTextFont.use] / `MusicScoreTheme.textFontFamily`.** On a host that
// provides neither, every string this package draws comes out as `.notdef`
// boxes. Bundling an OFL text face (Academico and Edwin are both OFL) was
// considered and rejected for 2.7.1: no such file exists in `assets/`, and
// fabricating or downloading one is out of scope for a remediation sprint. The
// escape hatch below is the supported answer and is proven by measurement — see
// the table in [MusicTextFont].

import 'package:flutter/widgets.dart';

/// Text faces named by `engravingDefaults.textFontFamily` in the SMuFL
/// reference metadata, ending in the generic `serif` so the platform always has
/// something to resolve.
///
/// **None of these is shipped by this package** — see the file header. The
/// trailing `'serif'` is a courtesy for hosts with a real font manager; it was
/// measured NOT to resolve in a headless Flutter test binary.
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

/// Runtime escape hatch letting an embedding app name the text face this
/// package should use for every non-SMuFL string.
///
/// Why this exists: [kMusicTextFontFallback] names four faces the package does
/// not ship (file header), so on a host that provides none of them the engine
/// draws `.notdef` boxes — and the headless export path (`ScoreRasterizer` →
/// `PdfExporter`) has no `Theme` ancestor to rescue it. An app that bundles its
/// own text face has no other way to tell the engine about it, because the
/// chain is compiled into the library.
///
/// Call it once, before the first render:
///
/// ```dart
/// // family declared in the APP's pubspec
/// MusicTextFont.use('Merriweather');
/// // or a family shipped by another package
/// MusicTextFont.use('Academico', package: 'my_fonts');
/// ```
///
/// Proven by measurement (`probe/w3_text_notdef_test.dart` + Pillow component
/// analysis). The Gregorian lyric path and the Jianpu numeral path were each
/// rasterised with only Bravura and Greciliae registered, then again with one
/// real text face registered under a different NAME each time. `.notdef` runs
/// are maximal ≥95%-filled components at least 8px on both axes — the
/// box-drawing face a headless Flutter binary substitutes merges adjacent
/// unresolved characters into one solid rectangle, so the filled AREA is quoted
/// beside the run count. A resolved face never produced a sizeable component
/// above 0.607 fill.
///
///   variant                                  | gregorian PNG  | jianpu PNG
///   -----------------------------------------+----------------+---------------
///   BEFORE, nothing registered               | 2 runs/2235 px | 10 runs/11399
///   BEFORE, 'serif' registered               | 2 runs/2235 px | 10 runs/11399
///   BEFORE, 'Academico' registered           | 2 runs/2235 px | 10 runs/11399
///   AFTER,  nothing registered               | 2 runs/2235 px | 10 runs/11399
///   AFTER,  'serif' registered               | 2 runs/2235 px | 10 runs/11399
///   AFTER,  'Academico' registered           | 0 runs/0 px    | 0 runs/0 px
///   AFTER,  'AppSerif' + MusicTextFont.use   | 0 runs/0 px    | 0 runs/0 px
///
/// Three things are proven at once. (1) The first three rows are BYTE-IDENTICAL
/// PNGs (md5 `2e19abe01d08` / `46f9a7d51cab`): before the 2.7.1 fix these two
/// paths bypassed the chain, so registering the very face the package names
/// changed nothing. (2) The `'serif'` rows never move, before or after — the
/// terminal generic is not a resolution guarantee. (3) The last row is this
/// escape hatch under test: a face whose name appears NOWHERE in this library
/// still wins the lookup once injected, and produces a PNG byte-identical to the
/// 'Academico' row.
///
/// Note also that the "nothing registered" rows are identical before and after
/// the fix: routing through the chain is a strict no-op on a host that resolves
/// none of its names, which is why no golden moved.
///
/// This is deliberately process-global rather than a widget-tree inherited
/// value: the headless path has no tree, and a `PdfExporter` call from a
/// background isolate entry point must resolve the same face as the on-screen
/// widget. [MusicScoreTheme.installTextFont] is the theme-shaped front door to
/// the same switch.
class MusicTextFont {
  MusicTextFont._();

  static String? _family;

  /// The injected primary family, already package-qualified when [use] was
  /// given a `package`. Null means "no injection; use
  /// [kMusicTextFontFallback] as-is".
  static String? get family => _family;

  /// Installs [family] as the primary text face for the whole package.
  ///
  /// Pass null (or the empty string) to clear the injection.
  ///
  /// [package] is resolved here rather than through `TextStyle(package: ...)`
  /// on purpose: that constructor argument rewrites `fontFamily` AND every
  /// entry of `fontFamilyFallback`, which would turn the built-in chain into
  /// the nonsense `packages/x/Academico … packages/x/serif`. Qualifying only
  /// the injected name keeps the fallbacks intact.
  static void use(String? family, {String? package}) {
    if (family == null || family.isEmpty) {
      _family = null;
      return;
    }
    _family = (package == null || package.isEmpty)
        ? family
        : 'packages/$package/$family';
  }

  /// Clears any injected family, restoring the built-in chain. Mainly for
  /// tests, which must not leak a family across cases.
  static void reset() => _family = null;

  /// The effective chain: the injected family (when any) ahead of
  /// [kMusicTextFontFallback].
  static List<String> get chain => _family == null
      ? kMusicTextFontFallback
      : <String>[_family!, ...kMusicTextFontFallback];
}

/// Adds [MusicTextFont.chain] to a text style unless the caller already
/// supplied their own fallback chain.
extension MusicTextFallback on TextStyle {
  /// Returns this style with the package's text fallback chain attached.
  ///
  /// A caller-supplied family or fallback chain always wins: a theme that names
  /// its own faces is making a deliberate choice and must not be overridden.
  /// That is also why [MusicTextFont.family] is consulted only when the style
  /// names no family of its own — the injection is a floor, not a ceiling.
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
    final packageChain = MusicTextFont.chain;

    if (family != null && family.isNotEmpty) {
      // A named face already wins the lookup; just give it somewhere to go.
      return hasChain ? this : copyWith(fontFamilyFallback: packageChain);
    }

    // No primary face: promote the head of the chain (the caller's own, when
    // they supplied one) so the lookup starts at a real text face instead of
    // the platform default.
    final resolved = hasChain ? chain : packageChain;
    return copyWith(
      fontFamily: resolved.first,
      fontFamilyFallback: resolved.sublist(1),
    );
  }
}
