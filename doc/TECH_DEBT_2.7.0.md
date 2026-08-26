# Technical debt inventory — flutter_notemus 2.7.0

**Date:** 2026-08-21 · **Baseline:** the 2.6.0 forensic audit
([`AUDITORIA_FORENSE_2026-08-21.md`](AUDITORIA_FORENSE_2026-08-21.md), 42 findings)

Scored as `Priority = (Impact + Risk) × (6 − Effort)`, each 1–5, effort inverted
so cheap fixes float up. **Impact** = how much it slows work down. **Risk** =
what happens if it is never fixed.

Everything here is what the sprint did **not** finish. What it did finish is in
the [CHANGELOG](../CHANGELOG.md#270---2026-08-21); what is deliberately
model-only is in [`MODEL_ONLY.md`](MODEL_ONLY.md).

---

## 1. Architecture debt

### A1 — The layout still mutates the model (`Note.beam`) · **Priority 21**
`Impact 3 · Risk 4 · Effort 4`

[ADR-001](adr/ADR-001-layout-never-clones-the-model.md) chose in-place mutation
over a full `LayoutNote` layer, on purpose: it bought 100% of the user-visible
correctness and 100% of the editor enablement for ~5% of the cost, and unblocked
eight other P1 fixes that all touch the layout engine.

The residue is real: `layout()` is not pure, and laying one `Staff` out from two
isolates concurrently is unsafe. Guarded today by
`test/invariants/layout_self_adversarial_test.dart`, which proves the mutation
is idempotent and width-independent.

**Fix:** `LayoutNote { final Note source; BeamType? beam; double x, y; }`, with
`PositionedElement` unwrapping at the render boundary. Do it when the editing
layer starts — that is the consumer that makes the abstraction pay for itself.
**Business case:** blocks nothing today; blocks multi-isolate layout of very
large scores, and a truly immutable public model.

### A2 — No global spacing solver (`TimeGrid` is only an anchor list) · **Priority 16**
`Impact 3 · Risk 3 · Effort 4`

[ADR-002](adr/ADR-002-shared-musical-time-grid.md) put every staff on a shared
onset grid and takes the **max** requirement at each instant. That is exact
where two staves actually sound together — the whole user-visible complaint —
but between two onsets each staff still keeps its own proportional spacing, and
justification is an affine stretch of the elastic region rather than a solved
distribution.

**Fix:** promote the anchor list to a first-class `TimeGrid` consumed by the
single-staff engine too, then replace the max rule with the spring-and-rod model
(what Verovio/LilyPond do). The now-wired `IntelligentSpacingEngine` is the
natural home.
**Business case:** the difference between "correct" and "optimal" spacing. Worth
doing before claiming parity with reference engines; not before.

### A3 — Four disconnected layout pipelines · **Priority 12**
`Impact 3 · Risk 3 · Effort 5`

CMN single-staff, CMN grand-staff, Gregorian and Jianpu each have their own
layout. Gregorian and Jianpu never produce a `PositionedElement`, so they get
none of the shared machinery — no hit-testing, no selection, no collision
detection, no skyline.

**Fix:** make Gregorian and Jianpu emit `PositionedElement`s. Chant would then
inherit selection and playback-from-click for free.
**Business case:** Gregorian is the project's stated primary goal; it currently
cannot be edited or clicked because it sits outside the pipeline.

### A4 — `MultiVoiceMeasure extends Measure` · **Priority 12**
`Impact 2 · Risk 2 · Effort 4`

Storage lives in `_voicesByNumber`, not in `elements`. 2.7.0 overrode the
inherited accessors so they stop returning nonsense, and added `allElements` as
the one correct way to iterate — but the LSP violation and the seven
`is MultiVoiceMeasure` checks remain.

**Fix:** `Measure { List<Voice> voices }`, single voice as `voices.length == 1`.

---

## 2. Code debt

### C1 — ~2,000 lines of unwired code · **Priority 24**
`Impact 2 · Risk 2 · Effort 1`

Down from ~2,800: `TupletValidator`, `LruCache`, `MeasureValidator` and the
`IntelligentSpacingEngine` are now on the production path. What is left is
inventoried and annotated in [`MODEL_ONLY.md`](MODEL_ONLY.md), and every dead
file now carries a header saying so.

Four **deletion candidates** with duplicate names elsewhere in the tree —
`src/music_model/tablature.dart` (385), `src/layout/beam_grouping.dart` (246,
still contains the note-cloning code ADR-001 forbids),
`src/layout/bounding_box_adapter.dart` (306), `src/rendering/slur_calculator.dart`
(242) — were deliberately **not** deleted: that is the owner's call.

**Fix:** delete the four, or state in `MODEL_ONLY.md` why they stay.
**Business case:** cheapest item on this list. Two `SlurCalculator`s and two
`TabNote`s is a trap for whoever fixes the next slur bug in the wrong file.

### C2 — ~300 literal `X.X * staffSpace` constants · **Priority 15**
`Impact 3 · Risk 2 · Effort 3`

`EngravingRules` (504 lines) exists and is meant to be the central table, but
most renderers still read SMuFL metadata directly or use a local literal.
2.7.0 removed the worst offenders (accidental widths now come from the metadata;
`stemLength` no longer pretends to be an engraving default; `barlineSeparation`
was renamed so it stops colliding with the SMuFL key of the same name).

**Fix:** route every renderer through `EngravingRules`, fed from the loaded
metadata. Then a font swap changes one object.

### C3 — Onset is a `double` · **Priority 14**
`Impact 2 · Risk 3 · Effort 3`

Musical time is rational. The code already carries `tolerance = 0.0001` and
`+ 0.0001` nudges, and the onset grid quantises with `(onset * 1024).round()`.
Nested tuplets (a third of a fifth) and 1/2048 durations are where this bites;
`layout_self_adversarial_test.dart` pins the current behaviour but cannot make
`double` exact.

**Fix:** a small `Rational` for durations and onsets.

### C4 — Half-translated comments and dartdoc · **Priority 12**
`Impact 2 · Risk 1 · Effort 1`

A historical mass find/replace left ~370 non-words (`notetion`, `Definesss`,
`paUses`, `calculateTeste`) plus double-encoded mojibake. 2.7.0 swept `lib/`
(this text was being published to pub.dev). `test/` and `example/` still carry
some, and many comments remain half-Portuguese/half-English.

**Fix:** pick one language for comments and finish the pass.

---

## 3. Test debt

### T1 — Goldens record behaviour, not correctness · **Priority 20**
`Impact 3 · Risk 5 · Effort 4`

37 of 55 goldens were re-baselined in this sprint. A re-baselined golden proves
nothing about correctness — it only pins the current output. The audit found
`grand_staff_golden_test.dart` (560 lines) passing green with a 38 px
misalignment recorded inside it.

Mitigated by `test/invariants/` (75 property tests) which assert *rules*, not
pictures. That is the right direction, but the goldens still need human eyes.

**Fix:** a documented visual review of the 37 changed goldens by someone who
reads music, once. Then treat goldens strictly as regression detectors.
**Business case:** highest **risk** score in this document. A wrong golden makes
every future audit start from a false premise.

### T2 — The new tests were written by the same pass that made the fixes · **Priority 15**
`Impact 2 · Risk 4 · Effort 3`

`test/invariants/`, `test/interaction/`, `test/fuzz/`, `test/gregorian/` all
landed with their own fixes. A test written by the author of a fix tends to
cover exactly the case that was fixed.

Partly mitigated: several suites were written specifically to attack the
remediation (`layout_self_adversarial_test.dart`, `interop_gaps_test.dart`
probes neighbouring cases the agent did not test).

**Fix:** the independent re-audit — [`REAUDIT_SUPERPROMPT.md`](REAUDIT_SUPERPROMPT.md)
Part B exists for exactly this, and asks the auditor to read each assertion and
ask what it does *not* test.

### T3 — No performance regression gate in CI · **Priority 12**
`Impact 2 · Risk 2 · Effort 2`

`performance_budget_test.dart` catches order-of-magnitude regressions, with
loose ceilings so it does not flake on other machines. Current measurements:
layout linear at 17 ms → 138 ms for 50 → 1600 measures; paint flat at 12–14 ms
regardless of score size.

**Fix:** record the numbers per commit rather than only asserting a ceiling.

### T4 — No cross-platform test execution · **Priority 10**
`Impact 2 · Risk 3 · Effort 3`

Everything runs on one platform. Goldens are explicitly platform-pinned. The
audit could not verify iOS/macOS/Linux/Web behaviour at all.

---

## 4. Documentation debt

### D1 — Doc↔code divergence has no automated guard · **Priority 20**
`Impact 3 · Risk 2 · Effort 1`

This was the audit's highest-leverage class of finding: `MAGIC_NUMBERS_REFERENCE.md`
documented constants that had been deleted; the backlog marked item #2 RESOLVED
while it was broken for beamed notes; the README's conformance table drifted.

2.7.0 fixed the documents and added the rule that *an item may only be marked
RESOLVED when a test exists that would fail if the regression returned*.

**Fix:** make it mechanical — a CI check that every `RESOLVED` in the backlog
names a test file, and that no doc references a symbol absent from `lib/`.
**Business case:** cheap, and it is the only item that prevents this whole
category from silently returning.

### D2 — GitHub issues are mirrored by hand · **Priority 9**
`Impact 2 · Risk 1 · Effort 2`

`doc/OPEN_ISSUES.md` is a manual mirror and drifts.

---

## 5. Dependency debt

### P1 — 19 packages behind, `xml` a major version behind · **Priority 12**
`Impact 2 · Risk 2 · Effort 2`

`pubspec.yaml` allows `xml >=6.5.0 <8.0.0` but resolution pins 6.6.1 while 7.0.1
exists. No known CVE; the audit found no XXE and no entity-expansion DoS, so
this is hygiene, not exposure.

**Fix:** find the transitive constraint holding `xml` back; schedule a bump with
the fuzz suite as the safety net.

---

## 6. Platform / infrastructure debt

### I1 — Playback exists on one platform of six · **Priority 16**
`Impact 2 · Risk 2 · Effort 5`

Android has a real engine (608 lines of C++ + 350 of Kotlin). iOS, macOS,
Windows, Linux and Web are stubs returning `false`. Honestly documented in the
README and `OPEN_ISSUES.md` — this is a known gap, not a hidden one.

**Fix:** iOS/macOS via AVAudioEngine is the highest-value next target.
**Business case:** MIDI *export* works everywhere; only real-time playback is
Android-only. Frame it that way to users.

### I2 — No isolates · **Priority 12**
`Impact 2 · Risk 2 · Effort 3`

Parsing, layout and MIDI generation all run on the UI thread. Measured cost is
fine for normal scores (138 ms for 1600 measures) but an orchestral MusicXML
import will jank.

---

## Phased plan (alongside feature work)

**Now — cheap, high leverage (≈1 day)**
1. D1 — CI guard for doc↔code divergence
2. C1 — decide the four deletion candidates
3. T3 — record perf numbers per commit

**Next — after the independent re-audit (≈1 week)**
4. T1 — human visual review of the 37 changed goldens
5. T2 — act on whatever the re-audit finds
6. C4 — finish the comment-language pass
7. P1 — `xml` 7.x

**Then — the structural pair, in this order**
8. A2 — extract `TimeGrid`, feed the single-staff engine from it
9. A2 — replace the max rule with the spring solver; C2 falls out of it
10. A1 — `LayoutNote`, when the editing layer starts
11. A4 — `Measure { voices }` alongside A1

**Opportunistic**
12. A3 — Gregorian onto `PositionedElement` (unlocks chant selection)
13. I1 — iOS/macOS playback
14. C3 — `Rational` time
15. I2 — isolates for import and layout of large scores

---

## What changed since the audit

| Category | 2.6.0 | 2.7.0 |
|---|---|---|
| Architecture | identity destroyed mid-pipeline; no shared time axis | identity preserved; onset grid in place; two ADRs record the waypoints |
| Code | ~2,800 lines unwired, ambiguous | ~2,000, inventoried and annotated; four deletion candidates named |
| Test | 594 green over a dead spacing engine, zero invariants, zero fuzzing | 708 green, 75 invariants, fuzz + selection + calibration suites |
| Documentation | stale magic-number doc, a false RESOLVED, drifting tables | reconciled, with the rule that RESOLVED requires a test |
| Dependency | 19 behind | unchanged |
| Infrastructure | 1 of 6 platforms, no isolates | unchanged, honestly documented |

The debt that remains is now **named, scored and located**. The debt that was
dangerous — the kind that silently produced wrong music — is the part that got
paid.
