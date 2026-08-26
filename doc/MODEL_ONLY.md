# Model-only subsystems — what exists, what actually runs

> Generated during the 2.7.0 audit-remediation sprint (2026-08-21) and kept as
> the single source of truth for "is this thing wired?".
>
> The 2.6.0 forensic audit found ~2,800 lines of classes that compile, are
> exported, are sometimes even tested — and are never reached from any
> production code path. That is not a crime by itself; **leaving it ambiguous
> is**, because it turns a green test suite into false confidence and makes the
> README impossible to keep honest.
>
> Every entry below is one of three things, and never anything in between:
>
> | Status | Meaning |
> |---|---|
> | **WIRED** | on the production path: constructing a score exercises it |
> | **TOOLING** | deliberately off the render path; analysis / debugging / future use, and documented as such in its own dartdoc |
> | **MODEL ONLY** | data model you can construct in Dart; nothing parses it, nothing draws it |

## Verification

Re-run this check before editing the table — it is the same one the audit used:

```bash
for s in ClassName; do grep -rl "\b$s\b" --include="*.dart" lib | wc -l; done
```

A class referenced by **only its own file** is unwired.

---

## WIRED in 2.7.0 (was dead in 2.6.0)

| Class | File | Where it runs now |
|---|---|---|
| `TupletValidator` | `src/layout/tuplet_validator.dart` | folded into `MeasureValidator`, so a bar containing tuplets is measured with its real `actual:normal` ratio |
| `LruCache` | `src/utils/lru_cache.dart` | `BaseGlyphRenderer` caches `TextPainter`s per (glyph, size, colour) instead of building one per glyph per frame |
| `MeasureValidator` | `src/layout/measure_validator.dart` | called by `LayoutEngine` per measure, now voice-aware (it used to sum every voice together and fail every polyphonic bar) |
| `IntelligentSpacingEngine` | `src/layout/spacing/spacing_engine.dart` | owns the square-root spacing law the layout applies |
| `OpticalCompensator` | `src/layout/spacing/optical_compensation.dart` | exposed through the spacing engine's optical adjustment |
| `SkyBottomLineCalculator` | `src/layout/skyline_calculator.dart` | already wired in 2.6.0 — slur collision avoidance |
| `MeiHeader`, `FileDescription`, `WorkList`, `Contributor` | `core/mei_header.dart` | **imported** since 2.7.0: `MEIParser.scoreFromMei` reads `<meiHead>` into `Score.meiHeader`, and `MEIParser.headerFromMei` returns it alone. Measured on a `<fileDesc><titleStmt>` carrying `<title>Ave Maria</title><composer>Franz Schubert</composer>`: `fileDescription.title == 'Ave Maria'` and one `Contributor('Franz Schubert', ResponsibilityRole.composer)`. It is **never written back** — there is no MEI serializer in the package, so a header survives an import and is lost on any export. |

## TOOLING — real code, deliberately off the render path

| Class | File | Why it is not on the path |
|---|---|---|
| `SpacingResult` | `src/layout/spacing/spacing_result.dart` | analysis output (per-element widths, shortest duration, detected collisions). Useful for tests and diagnostics; the renderer needs only the scalar spacing. |
| `CollisionDetector` (`src/layout/collision_detector.dart`) | | public geometry helper, exported for consumers building their own layout passes |
| `BoundingBox` / `BoundingBoxSupport` | `src/layout/bounding_box.dart` | hierarchical box storage on elements, filled opportunistically; not yet the source of truth for collisions |
| `EngravingRules` | `src/engraving/engraving_rules.dart` | central table of Behind Bars constants; the renderers still read most values straight from SMuFL metadata |

## MODEL ONLY — constructible, not parsed, not drawn

These are honest MEI-coverage data models. They are **not** claimed as features
anywhere in the README, and this table is what that claim is checked against.

| Area | Classes | File |
|---|---|---|
| Figured bass | `FiguredBass`, `FigureElement` | `core/figured_bass.dart` |
| Harmonic analysis | `HarmonicLabel`, `ScaleDegree`, `ChordTable`, `IntervalMeasure` | `core/harmonic_analysis.dart` |
| Mensural notation | `MensuralNote`, `MensuralRest`, `Ligature`, `Mensur` | `core/mensural.dart` |
| Tablature (MEI shape) | `TabString`, `TabTuning`, `TabDurSym`, `TabNote`, `TabGrp` | `core/tablature.dart` |
| Animation | `AnimationConfig`, `ElementAnimationState` | `src/animation/animation_config.dart` |
| Adaptive theming | `AdaptiveMusicScoreTheme` | `src/theme/adaptive_theme.dart` |

> Note: `Note.tabFret` / `Note.tabString` **are** rendered — the tablature
> *model* above is the richer MEI shape, which the MEI parser does not read yet.

## Deletion candidates (not removed — flagged for the owner)

Removing code is the owner's call, so nothing here was deleted. These are the
files with **zero** references outside themselves and a duplicate elsewhere in
the tree, i.e. the ones that cost maintenance without buying coverage:

| File | Lines | Why it is a candidate |
|---|---|---|
| `src/music_model/tablature.dart` | 385 | a **second, shadowed** tablature model; `TabNote` here collides by name with the exported `core/tablature.dart` and nothing imports it |
| `src/layout/beam_grouping.dart` | 246 | superseded by `src/layout/beam_grouper.dart`; still contains the old note-cloning code the audit flagged |
| `src/layout/bounding_box_adapter.dart` | 306 | adapter between two bounding-box representations, neither of which is on the path |
| `src/rendering/slur_calculator.dart` vs `src/layout/slur_calculator.dart` | 242 + 476 | two classes with the same name in two directories; only one is used |

## Rule going forward

When you add a class here, put it in one of the three buckets **in this file and
in its own dartdoc**, on the same commit. A class whose dartdoc does not say
where it runs is a future audit finding.
