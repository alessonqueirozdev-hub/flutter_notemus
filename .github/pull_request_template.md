<!--
Thank you for the contribution.

The bar in this repository is "here is the number, before and after" — not
"it looks right". See CONTRIBUTING.md for why.
-->

## What this changes

<!-- One or two sentences. What was wrong, what is right now. -->

## The measurement

<!--
Numbers, with units and the conditions they were taken under (staffSpace, canvas
width, which font). Delete this section only if the change genuinely cannot be
measured — a typo fix, a comment — and say so.

Example:
  before: gap 26.90 px at staffSpace 12, accidentalDoubleFlat is 19.82 px wide,
          so it drove 7.08 px into the previous notehead
  after:  38.57 px, clearance +12.74 px
-->

## How it was verified

- [ ] `flutter test` is green
- [ ] `dart analyze` is clean at the repo root
- [ ] `flutter analyze` is clean in `example/`
- [ ] A test fails before this change and passes after it

<!--
If you changed engraved output, the goldens will move. Fill this in:
-->
## Goldens

- [ ] No golden moved
- [ ] Goldens moved — listed below, each compared **zoomed at 4x or more** against
      the committed image, with what moved and why, and judged as an engraver

| golden | what moved | why | better / equal / worse |
|---|---|---|---|
|  |  |  |  |

<!--
A golden you judge WORSE stays red. A red golden is honest; a green one that
freezes a defect is not.
-->

## Architectural rules

- [ ] The layout does not replace or mutate the caller's model objects
      (ADR-001, ADR-005 — `test/invariants/adr005_guard_test.dart` enforces this)
- [ ] Every `TextStyle` handed to a `TextPainter` goes through
      `withMusicTextFallback`, or is a SMuFL glyph painter on the allow-list
- [ ] Engraving constants come from `bravura_metadata.json`, not from a literal

## Related issues

<!-- Closes #… -->
