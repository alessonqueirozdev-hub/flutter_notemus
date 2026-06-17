// Headless golden-rendering harness for the engraving quality sprint.
//
// Responsibilities:
//   * load the Bravura SMuFL font + metadata once per test run, so real glyphs
//     rasterize under `flutter test` (otherwise text renders as boxes);
//   * pump a [CorpusCase] into the real public [MusicScore] widget at a fixed
//     size with deterministic layout (no responsive/adaptive scaling), wrapped
//     in a keyed [RepaintBoundary] for `matchesGoldenFile`.
//
// Generate / refresh PNGs:   flutter test --update-goldens test/golden
// Check against committed:    flutter test test/golden

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the music `Duration` so `const Duration(milliseconds: …)` resolves to
// the dart:core time Duration used by tester.pump().
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;

import 'corpus.dart';

/// Key identifying the capture boundary used by [matchesGoldenFile].
const ValueKey<String> kGoldenBoundaryKey = ValueKey('golden-boundary');

bool _fontsLoaded = false;

/// Family name under which a real text font is registered (when available), so
/// lyrics, tempo marks, and word-based dynamics render as text instead of
/// `flutter test`'s Ahem boxes. Applied via [ThemeData.fontFamily] in [pumpCase].
const String kTextFontFamily = 'Roboto';

/// Candidate text fonts across platforms (best-effort, first match wins).
const List<String> _textFontCandidates = [
  r'C:\Windows\Fonts\arial.ttf',
  r'C:\Windows\Fonts\segoeui.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  '/Library/Fonts/Arial.ttf',
  '/System/Library/Fonts/Supplemental/Arial.ttf',
];

bool textFontAvailable = false;

/// Loads Bravura (from the package asset on disk), a best-effort text font, and
/// SMuFL metadata exactly once. Safe to call from every `setUpAll`.
Future<void> loadNotemusFonts() async {
  if (!_fontsLoaded) {
    final file = File('assets/smufl/Bravura.otf');
    if (!file.existsSync()) {
      throw StateError('Bravura.otf not found at ${file.path}');
    }
    final bytes = await file.readAsBytes();
    // The renderers reference the font under TWO different family names:
    //   * base_glyph_renderer.dart -> 'Bravura' (noteheads, accidentals, rests…)
    //   * bar_element_renderer.dart -> package-qualified
    //     'packages/flutter_notemus/Bravura' (clef, key sig, time sig).
    // Package fonts are not auto-registered under `flutter test`, so register
    // both names or clefs/time signatures render as .notdef boxes.
    for (final family in const ['Bravura', 'packages/flutter_notemus/Bravura']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }

    // Best-effort real text font (for lyrics / tempo / word dynamics). Without
    // it those render as Ahem boxes under `flutter test`. Degrades gracefully.
    // Registered under the theme family AND every name in the renderers'
    // `smuflTextFontFallback` chain (Academico, Century Schoolbook, Edwin,
    // serif), since text styles resolve via that fallback rather than the theme.
    for (final path in _textFontCandidates) {
      final f = File(path);
      if (f.existsSync()) {
        final tb = await f.readAsBytes();
        for (final family in const [
          kTextFontFamily,
          'Academico',
          'Century Schoolbook',
          'Edwin',
          'serif',
        ]) {
          final loader = FontLoader(family)
            ..addFont(Future.value(ByteData.view(tb.buffer)));
          await loader.load();
        }
        textFontAvailable = true;
        break;
      }
    }

    _fontsLoaded = true;
  }
  await SmuflMetadata().load();
}

/// Pumps [c] into a deterministic, fixed-size widget tree and returns the
/// [Finder] for the capture boundary.
Future<Finder> pumpCase(WidgetTester tester, CorpusCase c) async {
  await tester.binding.setSurfaceSize(c.size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: textFontAvailable ? ThemeData(fontFamily: kTextFontFamily) : null,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: kGoldenBoundaryKey,
            child: Container(
              width: c.size.width,
              height: c.size.height,
              color: Colors.white,
              child: MusicScore(
                staff: c.build(),
                staffSpace: c.staffSpace,
                // Deterministic layout: disable responsive + adaptive scaling
                // so the golden is stable across surface sizes.
                enableResponsiveLayout: false,
                preventVerticalOverflow: false,
                theme: const MusicScoreTheme(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // NOTE: never pumpAndSettle here — MusicScore briefly shows a
  // CircularProgressIndicator (infinite animation) while its FutureBuilder
  // resolves SMuFL metadata, which makes pumpAndSettle hang. Metadata is
  // already loaded in setUpAll, so a couple of explicit pumps transition the
  // FutureBuilder to its `done` state and lay out the score.
  await tester.pump(); // resolve the (already-complete) metadata future
  await tester.pump(const Duration(milliseconds: 50)); // flush layout
  return find.byKey(kGoldenBoundaryKey);
}
