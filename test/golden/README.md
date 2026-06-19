# Golden engraving harness

Headless rendering harness + visual regression suite for the engraving quality
sprint. It renders the real public `MusicScore` widget to PNG and compares
against committed baselines, so it doubles as:

- **figure generator** for the paper's evaluation section, and
- **regression guard** for every engraving fix (Phase 4).

## Files

| File | Role |
|---|---|
| `corpus.dart` | The test corpus — `CorpusCase` builders, simple → complex. |
| `_harness.dart` | Loads Bravura + SMuFL metadata, pumps a case deterministically. |
| `corpus_golden_test.dart` | One golden test per corpus case. |
| `goldens/*.png` | Committed baseline images. |

## Usage

```bash
# Generate / refresh all baseline PNGs (also produces the paper figures):
flutter test --update-goldens test/golden/corpus_golden_test.dart

# Regression check against committed baselines:
flutter test test/golden/corpus_golden_test.dart

# A single case:
flutter test test/golden/corpus_golden_test.dart --plain-name s02_ode_to_joy --update-goldens
```

## Notes / gotchas (learned the hard way)

- **Never `pumpAndSettle`** here. `MusicScore` shows a `CircularProgressIndicator`
  (an infinite animation) while its metadata `FutureBuilder` resolves, so
  `pumpAndSettle` hangs until timeout. The harness uses explicit `pump()`s.
- **Two font family names.** Renderers reference Bravura as both `'Bravura'` and
  the package-qualified `packages/flutter_notemus/Bravura`. The harness registers
  both; otherwise clefs / key signatures / time signatures render as `.notdef`
  boxes under `flutter test`.
- **Platform sensitivity.** Skia rasterization differs across OS / engine
  versions, so committed goldens are pinned to the platform that generated them.
  CI must run goldens on that same platform.
