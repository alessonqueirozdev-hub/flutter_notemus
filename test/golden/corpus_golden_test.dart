// Golden regression suite over the engraving corpus.
//
// First run (generate figures + baselines):
//   flutter test --update-goldens test/golden/corpus_golden_test.dart
// Subsequent runs (regression check):
//   flutter test test/golden/corpus_golden_test.dart
//
// NOTE on platform sensitivity: Skia rasterization differs across OS/engine
// versions, so committed goldens are pinned to the platform that generated
// them. CI must run goldens on that same platform (documented in PROGRESS.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_harness.dart';
import 'corpus.dart';

void main() {
  setUpAll(loadNotemusFonts);

  for (final c in corpus) {
    testWidgets('golden ${c.id} — ${c.title}', (tester) async {
      final finder = await pumpCase(tester, c);
      await expectLater(finder, matchesGoldenFile('goldens/${c.id}.png'));
    });
  }
}
