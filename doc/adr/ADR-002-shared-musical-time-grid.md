# ADR-002: Multi-staff alignment runs on a shared musical time grid

**Status:** Accepted (implemented in 2.7.0)
**Date:** 2026-08-21
**Deciders:** package maintainer
**Related:** ADR-001 (identity), `doc/AUDITORIA_FORENSE_2026-08-21.md` §12 (F-04)

## Context

`GrandStaffPainter` rendered a `StaffGroup` by running an **independent
`LayoutEngine` per staff**, then reconciling the results in `_alignStaves`,
which took as anchors only *the first musical element* and *each barline X* and
remapped every staff piecewise-linearly onto the widest of those.

Inside a bar the staves were therefore never reconciled at all: each kept its
own duration-proportional spacing. The audit measured the consequence on the
most ordinary keyboard texture there is — four quarters in the right hand
against two halves in the left, 4/4, 600 px:

```
treble note Xs : 116.2  172.4  228.5  284.7
bass   note Xs : 116.8         190.4
beat 1 : Δ =  0.6 px   OK
beat 3 : Δ = 38.1 px   >3 staff spaces apart
```

Vertical coincidence of simultaneous events is not a refinement of music
engraving; it is the definition of a system. Every reference engine
(Verovio, LilyPond, Dorico) resolves horizontal space over a **single ordered
list of musical instants for the whole system**, then gives every staff the same
column for the same instant.

Two further defects shared the same root cause:

- Voices 2+ inside one staff were positioned by **linear interpolation** over
  voice 1's timeline — plausible only because there was no grid to consult.
- `_resolveCrossVoiceCollisions` grouped simultaneous notes by
  `position.dx.round()`. Interpolated voices land on 123.4 and 123.6, which
  round to different integers, so collisions between voices routinely went
  unresolved.

**Constraints**

- `PositionedElement` is public API; adding a field is additive, changing the
  pipeline is not.
- 52 goldens, including three grand-staff ones, had to be re-baselined
  intentionally rather than accidentally.
- The single-staff path (`MusicScore`) must not regress: it is the common case.

## Decision

**Every `PositionedElement` carries `onset`: its musical position in whole notes
from the start of the staff.** Alignment across staves is then defined on
onsets, not on pixels or barlines:

1. each staff contributes an ordered `(onset → x)` anchor list;
2. the shared grid takes, for every onset present on any staff, the **maximum**
   x any staff needs there (so nothing is squeezed);
3. each staff is remapped piecewise-linearly from its own anchors onto the
   shared ones.

Because the shared value is a max of monotonic functions it is itself monotonic,
so the remap can never reorder a staff's events — that property is asserted in
the tests rather than assumed.

`PositionedElement` also gained `measureIndex`, which the same pass needs and
which measure numbering and selection-by-bar consume.

## Options Considered

### Option A: onset-anchored piecewise remap (chosen)

| Dimension | Assessment |
|---|---|
| Complexity | Medium — one new field, one rewritten method (~110 lines) |
| Correctness | Exact at every shared onset |
| Risk to single staff | None — the single-staff path never calls the aligner |
| Distance from state of the art | One step away: no global optimisation, but a genuine shared time axis |

**Pros:** reuses the existing per-staff layout unchanged, so all the spacing
work from this sprint applies; the anchor machinery already existed and only its
*key* changed (barline → onset); `onset` is independently useful (selection,
playback of a selection, cross-staff beams).
**Cons:** between two shared onsets a staff still keeps its own proportional
spacing — correct, but not globally optimal; the max rule can leave a little
extra air on the sparser staff.

### Option B: keep independent layouts, align on a denser anchor set (every beat)

| Dimension | Assessment |
|---|---|
| Complexity | Low |
| Correctness | Approximate — wrong for any rhythm off the beat grid (triplets, syncopation, tuplets) |

**Pros:** smallest possible change.
**Cons:** it is the same architecture with a finer sampling rate; it fails
exactly on the music that needs it most. Rejected.

### Option C: full spring-and-rod model over the whole system

| Dimension | Assessment |
|---|---|
| Complexity | High — a real constraint solver with iteration to convergence |
| Correctness | Best; what Verovio/LilyPond do |
| Risk | High — replaces the entire spacing pipeline |

**Pros:** globally optimal spacing, natural home for the (now wired)
`IntelligentSpacingEngine`, and the correct answer for justification too.
**Cons:** a rewrite, not a fix. Would have to land before any of the eight other
P1 findings could be verified, and would re-baseline every golden twice.

## Trade-off Analysis

B is not a different design, it is the same defect at a smaller amplitude, so
the real choice was A vs C.

C is the destination. A reaches **exact** alignment at every instant where two
staves actually sound together — which is the entire user-visible complaint —
for roughly 5% of C's cost and with the single-staff path untouched. What A does
*not* buy is optimal distribution of the leftover space between onsets, which no
audit finding and no user report has ever mentioned.

Crucially, A is not a dead end: it introduces the *time axis* that C requires.
`TimeGrid` in the recommended architecture is A's anchor list promoted to a
first-class object; going from A to C means replacing step 2 (max) with a
solver, not rebuilding the pipeline.

## Consequences

**Easier**
- Grand staff, SATB and full scores align correctly — verified by
  `test/invariants/grand_staff_alignment_test.dart`, which asserts the property
  for 2 and 3 staves and for eighths against a whole note.
- Cross-voice collision detection now groups by onset, so it stops missing
  collisions caused by sub-pixel drift.
- Playing back a selection, selecting by bar, and placing a caret from a pointer
  position all become one-liners (`ScoreHitTester.selectTimeRange`, `timeAt`).
- Cross-staff beams read the aligned Xs, so they follow the re-aligned heads.

**Harder**
- Every code path that constructs a `PositionedElement` must now propagate
  `onset` and `measureIndex`; forgetting either silently degrades alignment
  rather than failing loudly. Mitigated by the `L7` invariant asserting that
  every positioned element carries a finite onset.
- The sparser staff can receive slightly more trailing air than an optimal
  solver would give it.

**To revisit**
- Promote the anchor list to a real `TimeGrid` object shared by the single-staff
  engine as well, then replace the max rule with the spring model (Option C).
  That is also what would let justification stretch the elastic region properly
  instead of applying an affine stretch.

## Action Items

1. [x] `PositionedElement.onset` + `measureIndex`, propagated through the engine,
       the multi-voice path, barlines and system restatements
2. [x] `GrandStaffPainter._alignStaves` rewritten on onsets
3. [x] `_resolveCrossVoiceCollisions` regrouped by onset
4. [x] `GrandStaffPainter.alignedSystem()` exposed `@visibleForTesting`
5. [x] `test/invariants/grand_staff_alignment_test.dart` (4 property tests)
6. [x] Grand-staff goldens re-baselined deliberately
7. [ ] Extract `TimeGrid`; feed the single-staff engine from it too
8. [ ] Replace the max rule with the spring-and-rod solver (Option C)
