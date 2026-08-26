# ADR-001: The layout engine never clones or replaces model objects

**Status:** Accepted (implemented in 2.7.0)
**Date:** 2026-08-21
**Deciders:** package maintainer
**Supersedes:** the implicit "layout may rebuild elements" behaviour of 1.x–2.6.0

## Context

`LayoutEngine` needs to record one layout decision on each note: which beam
group it belongs to. `Note.beam` was `final`, so `_processBeamsWithAnacrusis`
built a **replacement `Note`** carrying the resolved `BeamType` and pushed that
into the positioned-element list instead of the caller's object.

`Note` has no `==`/`hashCode` override, so it compares by identity. Every
identity-keyed structure built *before* that point therefore stopped matching.
The 2.6.0 forensic audit measured four distinct, user-visible failures from this
single cause:

| Symptom | Measured |
|---|---|
| Behind Bars accidental suppression does not apply to beamed notes | four F♯ eighths printed four sharps; the same four as quarters printed one |
| `LayoutEngine.noteXPositions` — a documented public API — returns `null` | map held 2 entries, neither of them the caller's notes |
| "Deterministic" layout signature differs between identical runs | same `Staff`, three runs → `400447158 / 480065883 / 172987804`; `shouldRepaint` therefore always true, defeating viewport culling |
| The same `Note` instance used twice is silently dropped | 3 instances added → 1 rendered |

There is also a fifth, structural cost: with no stable identity from model to
screen there can be no hit-testing, no selection, no undo — i.e. **no editor**.
The audit scored "readiness for a professional editor" 2/10 and named this as
the blocker.

The same pattern existed a second time in `TupletRenderer._applyAutomaticBeams`,
whose copy constructor also silently dropped `syllables`, `isGraceNote`,
`alternatePitch`, `tabFret`, `tabString`, `accidentalParenthesis`, `slurs`,
`crossStaffMove`, `tremoloStrokes` and `xmlId` — so lyrics and tab numbers
vanished for any note inside a tuplet.

**Forces**

- The music model is meant to be immutable-ish and is public API.
- The layout must record decisions somewhere.
- 594 tests and 52 goldens existed and had to keep passing.
- An editor is on the roadmap and depends on identity.

## Decision

**The layout pass may write layout decisions onto model objects in place, but it
may never construct a replacement for one.** `Note.beam` becomes mutable and is
stamped in place; `_processBeamsWithAnacrusis` returns the caller's own list.

Additionally, `PositionedElement.computeSignature` becomes **structural**
(`structuralHash` over pitch/duration/beam/etc.) rather than mixing in
`element.hashCode`, so the signature is reproducible even if a caller rebuilds
its model.

## Options Considered

### Option A: mutate `Note.beam` in place (chosen)

| Dimension | Assessment |
|---|---|
| Complexity | Low — two files, ~40 lines |
| Risk to existing behaviour | Low — every reader of `note.beam` keeps working unchanged |
| Editor enablement | Full — identity survives end to end |
| Purity | Compromised — `layout()` has a visible side effect on the model |

**Pros:** fixes all four symptoms at once; zero renderer churn; `Note` already
carried mutable state (`xmlId`, the `BoundingBoxSupport` mixin), so this is
consistent; auto-beaming already *overrode* the author's beam, so no information
is lost that was not already being discarded.
**Cons:** `layout()` mutates its input, which must be documented; concurrent
layouts of one `Staff` at two widths would race on `beam` (they would compute
the same value, since grouping depends only on meter, but it is a smell).

### Option B: side map `Map<Note, BeamType?>` on the engine

| Dimension | Assessment |
|---|---|
| Complexity | Medium — engine plus 5 renderer files must consult the map |
| Risk | Medium — any renderer that keeps reading `note.beam` silently stops drawing beams |
| Purity | Good — no model mutation |

**Pros:** the model stays untouched; a clean step toward Option C.
**Cons:** the map has to be threaded into `StaffRenderer`, `GroupRenderer`,
`NoteRenderer`, `TupletRenderer` and `GrandStaffPainter`; a missed call site
fails silently (beams simply disappear), which is exactly the failure mode this
ADR exists to eliminate.

### Option C: full `LayoutNote { Note source; BeamType beam; double x, y; }`

| Dimension | Assessment |
|---|---|
| Complexity | High — new layer, every renderer re-typed |
| Risk | High — 52 goldens, 594 tests |
| Purity | Best — clean MUSIC / LAYOUT / RENDER separation |

**Pros:** the architecturally correct end state; makes the model genuinely
immutable; removes `BoundingBoxSupport` from `Note`.
**Cons:** a multi-week refactor that would have blocked every other fix in this
sprint; `PositionedElement.element` must stay a `MusicalElement` for the
renderers, so the wrapper has to be unwrapped at the boundary anyway.

## Trade-off Analysis

A and C both restore identity; B does not restore it, it works around its
absence. The decisive question was therefore **A now, or C now**.

C is where this codebase should end up, but the audit produced eight other P1
findings whose fixes all touch the layout engine. Doing C first would have
serialised the entire sprint behind a refactor with the highest regression risk
in the repository — and C's benefit over A is *purity*, while A already buys
100% of the user-visible correctness and 100% of the editor enablement.

A is therefore chosen as a deliberate, documented waypoint toward C. The one
thing A gives up — a side-effect-free `layout()` — is contained by documenting
it on `Note.beam` itself and by the fact that the computed value is a pure
function of the measure's meter, so the mutation is idempotent.

## Consequences

**Easier**
- Accidental resolution, note positions, hit-testing and selection all key off
  the caller's own objects. `ScoreHitTester` shipped in the same release
  precisely because this became possible.
- The layout signature is stable, so `shouldRepaint` can finally return `false`.
- One rule to enforce in review, stated in one sentence.

**Harder**
- `layout()` is no longer pure. Callers who want their `Note.beam` left alone
  must set `Measure.autoBeaming = false`.
- Laying one `Staff` out from two threads/isolates concurrently is not safe.

**To revisit**
- Migrate to Option C when the editor layer lands; `LayoutNote.source` is the
  planned bridge. `PositionedElement` already carries `onset` and
  `measureIndex`, which is half of that structure.

## Action Items

1. [x] `Note.beam` mutable; `_processBeamsWithAnacrusis` stamps in place
2. [x] `TupletRenderer._applyAutomaticBeams` stamps in place (stops dropping
       lyrics/tab/cautionary data)
3. [x] `PositionedElement.computeSignature` made structural
4. [x] Invariants L2/L3/L4 in `test/invariants/engraving_invariants_test.dart`
5. [x] `ScoreHitTester` + `test/interaction/score_hit_tester_test.dart` prove
       identity end to end
6. [ ] Option C (`LayoutNote`) when the editing layer starts
