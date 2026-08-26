@Tags(['golden'])
// Pixel goldens are NOT portable across platforms: font rasterisation, hinting
// and anti-aliasing differ between operating systems, so an image recorded on
// one and checked on another fails for reasons that have nothing to do with the
// engraving. They are therefore tagged and run only on the platform they were
// recorded on (see .github/workflows/ci.yml and dart_test.yaml).
library;

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
