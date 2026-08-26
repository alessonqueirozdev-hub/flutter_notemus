# ADR-005: A layout decision is a value owned by the layout result, never a mutation of the model

**Status:** Accepted (implemented in 2.8.0)
**Date:** 2026-08-22
**Deciders:** package maintainer
**Partially supersedes:** [ADR-001](ADR-001-layout-never-clones-the-model.md),
which made `Note.beam` mutable and had the engine write it

## Context

ADR-001 solved a real and expensive problem. `LayoutEngine` needed to record one
decision per note — which beam group it belongs to — and `Note.beam` was
`final`, so `_processBeamsWithAnacrusis` built a **replacement `Note`** and
pushed that downstream. `Note` compares by identity, so every identity-keyed
structure built before that point stopped matching: accidental suppression
broke, the public `noteXPositions` returned nothing useful, the "deterministic"
layout signature differed between identical runs, and a `Note` instance used
twice was silently dropped.

ADR-001 chose **Option A: mutate `Note.beam` in place**, over Option B (a side
map on the engine) and Option C (a full `LayoutNote` layer). It said so
explicitly, and it explicitly rejected B:

> the map has to be threaded into `StaffRenderer`, `GroupRenderer`,
> `NoteRenderer`, `TupletRenderer` and `GrandStaffPainter`; a missed call site
> fails silently (beams simply disappear), which is exactly the failure mode
> this ADR exists to eliminate.

That reasoning was sound for the information available in 2.7.0. It was chosen
as "a deliberate, documented waypoint toward C", and it accepted one named cost:
`layout()` is no longer pure. The cost was argued to be contained because "the
computed value is a pure function of the measure's meter, so the mutation is
idempotent".

**Both halves of that containment argument turned out to be false**, and the
2.7.1 and 2.8.0 audits measured how.

### The mutation is visible through the public API

`Note.beam` is not a private layout scratch field. `MusicXMLParser` reads it and
emits `<beam>` elements; `JsonMusicExporter` reads it and writes it. So the
mutation is not contained inside the layout at all — it changes what the user's
own export produces. Measured on two bars of loose quavers, exporting the same
`Staff` object twice:

| when | MusicXML | `<beam>` tags |
|---|---|---|
| freshly built | 3 349 chars | 0 |
| after `layout()` | 3 973 chars | 16 |

The JSON export moves with it. A user calling `staffToMusicXML` got a different
file depending on whether the score had happened to be displayed first — which
is a data-fidelity bug reachable with no rendering code in sight.

The tuplet half of the same defect fired one layer later, in `TupletRenderer`
**during paint**. On a mixed fixture — a 3/4 bar of six quavers plus a bar
holding one 3:2 triplet — the two stamps are separately observable:

| when | MusicXML | `<beam>` tags |
|---|---|---|
| after the layout stamp | 3 284 chars | 6 |
| after the paint stamp | 3 399 chars | 9 |

Same object, same call, +115 characters and three more tags, bought by nothing
but having drawn the score.

### The mutation is not idempotent, and it is not even single

`layout()` runs a **measuring dry-run pass** before the real one, so that the
width it reserves and the width it draws agree by construction. The dry run
walked the same code. Measured: **32 writes of `Note.beam` for 16 notes** —
measure 0 written in full a second time before measure 1 started. "The mutation
is idempotent" was true of the value and irrelevant to the hazard: the model was
being written during a pass whose entire contract is that it is a rehearsal.

### The failure mode ADR-001 feared is real, and it fired

ADR-001 rejected Option B because "a missed call site fails silently (beams
simply disappear)". That prediction was correct and it has already come true
once, in the same wave that landed this ADR. `GrandStaffPainter` reads
`note.beam` off the model in two places — the cross-staff relocation predicate
(`grand_staff_painter.dart:227`) and the cross-staff beam-run scanner
(`:854`) — and neither was migrated to `beamOf`.

Measured on four quavers in the right hand with the middle two sent to the left
hand, after `GrandStaffPainter.alignedSystem(0)`:

```
modelBeams  = [null, null, null, null]
engineBeams = [start, end, start, end]
```

The painter therefore classifies every note as unbeamed and finds zero
cross-staff beam runs, exactly as ADR-001 warned. This is written into the ADR
rather than smoothed over, because it is the *evidence* for action item 7: a
convention that lives in prose fails silently, and it needs a build-time guard,
not a promise.

What made B affordable anyway is that the risk is **enumerable**. The read sites
are `grep`-able by one name, the tuplet renderer already took its beams from a
plan object rather than from the model, and `StaffRenderer`, `GroupRenderer` and
`NoteRenderer` were migrated in the same change. Option A's cost, by contrast,
is not enumerable at all: it is every export any user has ever taken after
displaying a score.

**Forces**

- `Note.beam` is public, exported API and is read by the MusicXML and JSON
  exporters. Anything the layout writes there is user-visible data.
- `BeamingMode.manual` and hand-authored scores need `Note.beam` to keep
  working as an **input**, so it cannot simply be made private or removed.
- 919 tests and 53 goldens existed and had to keep passing.
- Option C (`LayoutNote`) is still the end state and is still a multi-week
  refactor.

## Decision

**A layout decision is a value owned by the layout result. The layout pass may
not write it back onto the model.**

Concretely, for beams:

- `LayoutEngine.beams` — `Map<Note, BeamType>`, identity-keyed, ordinary groups.
- `LayoutEngine.tupletBeams` — the same for notes inside a `Tuplet`.
- `LayoutEngine.beamOf(note)` — **the only supported read.** It returns the
  engine's decision when it made one and falls back to the author's
  `Note.beam` hint when it did not. Every renderer must go through it;
  `note.beam` alone carries the author hint and nothing else. The two
  `GrandStaffPainter` sites that were not migrated in the landing wave now are
  (action item 5), and `beamOf` consults both maps as of the 2.8.0 sign-off
  (action item 3).

`Note.beam` stays mutable and stays part of the public API, but its meaning
narrows from "input hint, overwritten by the engine" to **"input hint, full
stop"**. That is the load-bearing half of ADR-001 that survives: identity is
still preserved end to end, because nothing is cloned; what stops is the write.

## Options Considered

### Option A: keep ADR-001 — the engine stamps `Note.beam` in place

| Dimension | Assessment |
|---|---|
| Complexity | Zero — it is the status quo |
| Export fidelity | **Broken** — 0 → 16 `<beam>` tags from a `layout()` call |
| Purity of `layout()` | None; and the dry run writes too (32 writes / 16 notes) |
| Editor enablement | Full (identity is preserved) |
| Risk of regression | Zero |

**Pros:** costs nothing; every existing reader of `note.beam` keeps working.
**Cons:** the defect this ADR exists to fix. Also blocks any future in which two
widths of the same `Staff` are laid out concurrently, because they would race on
a field the exporters read.

### Option B: value maps on the engine, read through one accessor (chosen)

| Dimension | Assessment |
|---|---|
| Complexity | Low–medium — two maps, one accessor, the renderers' read sites |
| Export fidelity | **Exact** — exports byte-identical before/after layout and paint |
| Purity of `layout()` | Restored for beams |
| Editor enablement | Full (identity preserved; the maps are identity-keyed) |
| Risk of regression | **Realised** — two unmigrated reads in `GrandStaffPainter` |

**Pros:** fixes the user-visible data bug with no new layer and no model change;
the maps are `Map.identity()`, so they inherit exactly the identity guarantee
ADR-001 bought; `beamOf` reduces the "missed call site" risk to one grep-able
name; it is a strict step toward Option C rather than a detour.
**Cons:** the engine now carries per-note state that a renderer must be given
access to, so `LayoutEngine` is threaded further into the render path; a caller
who reads `note.beam` directly (including code outside this repo) now sees only
their own hint, which is a **behaviour change** and is why this is called out at
the top of the 2.8.0 changelog. And the silent-failure risk is not theoretical:
it has already cost two sites in `GrandStaffPainter` and six invariant tests
that assert on `note.beam` rather than on `beamOf`.

### Option C: a full `LayoutNote { Note source; BeamType beam; double x, y; }`

| Dimension | Assessment |
|---|---|
| Complexity | High — new layer, every renderer re-typed |
| Export fidelity | Exact |
| Purity of `layout()` | Best — model is genuinely immutable |
| Editor enablement | Full, and cleanest |
| Risk of regression | High — 53 goldens, 919 tests, every renderer |

**Pros:** the architecturally correct end state; removes `BoundingBoxSupport`
from `Note`; makes "layout decisions are values" structural instead of a
convention.
**Cons:** unchanged from ADR-001 — a multi-week refactor that would have
serialised this entire remediation behind the riskiest change in the repository.
`PositionedElement.element` must stay a `MusicalElement` for the renderers, so
the wrapper still has to be unwrapped at the boundary.

## Trade-off Analysis

The decisive fact is that ADR-001 mis-classified the field. It treated
`Note.beam` as a layout scratch slot that happened to live on a model object.
It is not: it is **serialised state**, read by two exporters, and the number
that proves it is 0 → 16 `<beam>` tags from a call whose documented job is to
compute positions. Once the mutation is understood as an export-fidelity bug
rather than a purity blemish, "A is contained by documenting it" stops being an
option — you cannot document your way out of a file that changes depending on
whether it was displayed.

That leaves B and C, and the argument between them is the same one ADR-001 had,
with one input changed: B's cost has fallen. ADR-001 priced B at "five renderer
files must consult the map, and a missed call site fails silently". Measured in
2.8.0, the actual landing was two maps plus one accessor, because the tuplet
path already routed through a plan object and the remaining read sites are
enumerable by grep. C's cost has not fallen at all.

So B is chosen for the same reason A was chosen in 2.7.0 — it buys 100% of the
user-visible correctness for a fraction of C's risk — but with the ordering
corrected: B is now the waypoint toward C, and A is retired.

The honest residue: B is a convention, not a structure. Nothing in the type
system stops a future contributor from writing `note.beam = ...` inside the
engine again, and nothing stops a renderer from READING `note.beam` and quietly
drawing no beam — which is precisely what happened to `GrandStaffPainter` in the
landing wave. That is what action items 5 and 6 below existed for.

Since wave 5 the residue is smaller but not gone. `test/invariants/adr005_guard_test.dart`
now makes the convention *executable*: it fails the build on a `.beam` write
inside the layout or the renderers, and on any read of the field that is not on
an explicit, commented allow-list. That converts "a reviewer might notice" into
"CI names the file and line and tells you to use `beamOf`". What it still cannot
do is make the *right* thing convenient — a contributor who wants the beam of a
note must still know that `beamOf` exists and that the map is identity-keyed.
Only Option C makes that structural, which is why item 9 stays open.

## Consequences

**Easier**

- `staffToMusicXML` and `staffToJson` are pure functions of the model again.
  Measured: 3 349 / 3 349 / 3 349 characters and 0 / 0 / 0 `<beam>` tags across
  fresh, post-`layout()` and post-`renderStaffToPng`.
- The measuring dry run is genuinely a rehearsal — it leaves no trace on the
  caller's objects, so the 32-writes-for-16-notes class of surprise is gone.
- The layout signature stays reproducible: two independent engines over the same
  music return `278 109 605` from `PositionedElement.computeSignature`.
- Laying one `Staff` out at two widths concurrently is no longer obviously
  unsafe for beams (ADR-001 listed that as a known hazard).
- The migration path to Option C is now mechanical: `beams` and `tupletBeams`
  are exactly the fields a `LayoutNote` would carry.

**Harder**

- **Behaviour change for downstream readers.** Code that called `layout()` and
  then read `note.beam` to learn the engine's answer now reads only its own
  hint. The fix is one call: `engine.beamOf(note)`. Measured cost inside this
  repository alone: two unmigrated reads in `GrandStaffPainter` and six failing
  assertions in `test/invariants/engraving_invariants_test.dart` (group
  "F-03 — compound meters beam in threes"), all of which read `note.beam`
  directly.
- A renderer needs the `LayoutEngine` (or the maps) in hand where it previously
  needed only the `Note`. That is more plumbing through the render path.
- The rule is enforced by a build guard
  (`test/invariants/adr005_guard_test.dart`) and by the regression tests, not
  by the type system, because `Note.beam` must stay writable for
  `BeamingMode.manual`. The guard is a text scan over `lib/`, so it inherits
  that technique's limits: it knows the field's NAME, not its type, which is
  why it carries eight of its own tests and why the allow-list has to record a
  reason rather than just a path.
- Two sources of truth exist by construction — the map and the hint — and
  `beamOf` is the only place their precedence is stated.

**To revisit**

- Migrate to Option C when the editor layer lands. `LayoutNote.source` remains
  the planned bridge, and `PositionedElement` already carries `onset` and
  `measureIndex`.
- Other layout decisions still written onto the model come under this ADR
  automatically — the rule is about the *category*, not about beams. One has
  since been found, measured and fixed: `Measure.inheritedTimeSignature`, which
  `layout()` wrote and `Measure.add` reads to decide whether to throw. See
  action item 8.

## Action Items

Status re-checked against the tree at 2.8.0 wave 5. Every `[x]` below was
verified by reading the code, not by trusting an earlier report — which is the
lesson of item 7.

1. [x] `LayoutEngine.tupletBeams` — tuplet beam membership published as a value;
       `TupletRenderer` no longer stamps during paint
2. [x] `LayoutEngine.beams` — ordinary beam groups published the same way;
       `_processBeamsWithAnacrusis` no longer writes `Note.beam`
3. [x] `LayoutEngine.beamOf(note)` exists, carries the documented author-hint
       fallback, and consults BOTH engine maps. It did not until the 2.8.0
       sign-off: it read `beams` and the hint and **never consulted
       `tupletBeams`** (`beamOf(note) => beams[note] ?? note.beam`), so for a
       note inside a tuplet — the only notes `tupletBeams` is about — "the only
       supported read" answered `null` while the engine held an answer.
       Measured on a 3:2 triplet of eighths after `layout()`, BEFORE the fix:

       ```
       engine.beams[first]         -> null
       engine.tupletBeams[first]   -> BeamType.start
       engine.beamOf(first)        -> null            <- wrong
       ```

       and the consequence one layer up, which is what made it a real defect
       rather than a wart:

       ```
       TupletBracket().shouldShow(notes, beamOf: engine.beamOf) -> true
       ```

       — a bracket over a fully beamed triplet, against Behind Bars p.201, from
       the API that exists to prevent exactly that. Nothing looked broken only
       because the tuplet path reads `tupletBeams` directly; every OTHER caller
       — `TupletBracket.shouldShow`, `ScoreHitTester`, any user code — got the
       wrong answer.

       **This finding was correctly diagnosed by the wave that added the
       parameter, written into its report as a one-line patch, and not
       applied** — the same failure mode as the cross-staff-beam incident in
       item 5. It was applied at sign-off:

       ```dart
       BeamType? beamOf(Note note) => beams[note] ?? tupletBeams[note] ?? note.beam;
       ```

       The two maps are disjoint by construction (`_resolveOrdinaryBeams` walks
       measure/voice elements, `_resolveTupletBeams` walks only `Tuplet`
       children), so the order between them is arbitrary and no note outside a
       tuplet changes answer. Verified: `beamOf` now returns
       `[start, inner, end]` on that triplet, `shouldShow(..., beamOf:
       engine.beamOf)` returns `false`, and the full suite plus all 53 goldens
       are unchanged.
4. [x] The behaviour change called out at the top of the 2.8.0 changelog
5. [x] The two `GrandStaffPainter` reads and the invariant assertions now route
       through `_StaffLayout.engine.beamOf`
       (`grand_staff_painter.dart` `_shouldRelocate` and `_crossStaffGroups`,
       `test/invariants/engraving_invariants_test.dart:596`).
       **This is the incident the guard in item 7 exists for and it is worth
       recording in full.** While it was live, the painter read `note.beam` off
       the model, the engine no longer wrote there, so `_crossStaffGroups`
       returned ZERO runs and **no cross-staff beam was drawn anywhere in the
       package**. Measured on four quavers in the right hand with the middle
       two sent to the left hand, after `GrandStaffPainter.alignedSystem(0)`:

       ```
       modelBeams  = [null, null, null, null]
       engineBeams = [start, end, start, end]
       ```

       and on the raster:

       | quantity | broken | fixed |
       |---|---|---|
       | total ink | 15 840 px | 14 457 px |
       | longest horizontal run across the inter-staff gap | 41 px | 115 px |

       The ink went UP while the drawing got worse — every note printed a loose
       flag where a beam belonged. It was invisible to 963 tests and 53
       goldens; TWO independent audit waves diagnosed it correctly and each
       wrote the exact patch into a report, and nobody applied it, so it
       survived four waves to the final audit.
6. [x] `Note.beam`'s dartdoc restated as an INPUT-ONLY hint pointing at
       `beamOf` (`lib/core/note.dart:45-62`)
7. [x] **The repository guard: `test/invariants/adr005_guard_test.dart`.**
       It walks `lib/`, strips comments and string literals, and fails on
       (a) any `.beam` assignment inside `lib/src/layout/` or
       `lib/src/rendering/`, and (b) any read of the model's beam field that is
       not on an explicit, commented allow-list. The allow-list names the file,
       the SHAPE of the sanctioned expression and the reason it is legitimate,
       so adding a reader is an edit a reviewer sees. The failure message names
       `file:line` and says to use `beamOf` instead. The scanner is itself
       covered by eight tests on synthetic sources, because a scanner that
       silently matches nothing passes every other test in the file.
       Verified in both directions: green on the tree, and red — naming the
       exact `file:line` — when a bare read or a `note.beam = ...` write is
       reintroduced.
8. [x] Audit for the same category of write, beyond beams. **One more was
       found, and it was worse than the beam case in one respect: it changed
       whether a public API throws.** `layout_engine.dart` wrote
       `measure.inheritedTimeSignature = timeSignatureToUse` onto the caller's
       own `Measure`, and `Measure.add` (`measure.dart:128`) reads that field
       to compute the bar's capacity. Measured on a two-bar staff whose bar 1
       declares 4/4 and whose bar 2 declares nothing and already holds four
       quarters — asking it to accept a FIFTH quarter:

       | state | `m2.inheritedTimeSignature` | `m2.add(<fifth quarter>)` | `m2.elements.length` |
       |---|---|---|---|
       | fresh | `null` | accepted | 5 |
       | after `layout()` | `TimeSignature(4/4)` | **`MeasureCapacityException`** | 4 |
       | after `renderStaffToPng` | `TimeSignature(4/4)` | **`MeasureCapacityException`** | 4 |

       So whether *building* a score succeeded depended on whether it had been
       *displayed*, and the model the caller handed in came back changed.

       **Fixed as this ADR prescribes.** The derivation is now the value
       `LayoutEngine.inheritedTimeSignatures` — an identity
       `Map<Measure, TimeSignature>`, the sibling of `beams` and `tupletBeams` —
       read through `LayoutEngine.timeSignatureOf(measure)`. All three internal
       consumers were re-pointed at it: the validation call in `layout()`,
       `_centerFullMeasureRests`, and `MeasureValidator.validateStaff`. Nothing
       in `lib/` assigns to `Measure.inheritedTimeSignature` any more. After the
       fix, all three rows of the table above read `null` / accepted / 5.

       The field stays writable, like `Note.beam`, because it is part of
       `Measure`'s public constructor and a caller may legitimately opt a
       stand-alone bar into preventive validation. It is now an INPUT-ONLY hint:
       it SEEDS the engine's walk while nothing has been declared yet and is
       ignored once the staff declares a meter of its own. Its dartdoc, which
       used to say "set automatically by `LayoutEngine`", now says the opposite
       and points at `timeSignatureOf`.

       **The trap this hid, and it is the reason the item took a full wave.**
       `GrandStaffPainter._systemStaff` builds a sub-`Staff` starting at measure
       `a`, so a meter declared BEFORE `a` is not in the sub-staff and the
       sub-layout cannot re-derive it; the painter had been silently borrowing
       the value the engine stamped on the caller's bars. Simply stopping the
       write left every wrapped system from 2 on with NO meter, and
       `LayoutEngine` skips capacity validation when it has no meter — so an
       over-full bar in system 2..n would have been counted valid, invisibly.
       `_ClefKeyTracker` (which already walks the bars before `a` to carry the
       prevailing clef and key, wave 3/4) now carries the prevailing
       `TimeSignature` too and `_restated` passes it explicitly, onto a measure
       **the painter owns** rather than the caller's.

       Measured end to end, on a nine-bar grand staff at 420 px that declares
       2/4 only in bar 1 and holds a lone half rest in bar 7 (system 2). A half
       rest fills a 2/4 bar only if the layout knows the meter, and
       `_centerFullMeasureRests` centres a rest that fills its bar, so the ink
       reports the loss directly — distance from the rest to its closing
       barline:

       | | meter inherited from bar 1 | meter re-declared in bar 7 |
       |---|---|---|
       | write removed, painter not fixed | 49.584 px | 31.584 px |
       | painter fixed | 31.584 px | 31.584 px |

       An 18 px error — a full staff space and a half — in exactly the case the
       trap covers, from a change whose whole point was to move zero ink.

       Regression test: `test/invariants/w6_inherited_meter_test.dart`, seven
       tests over three groups (the throw-or-not table, a field-by-field
       `Measure` dump that must be identical across `layout()`, the input-hint
       contract, `validateStaff` on an over-full inherited bar, a stale hint
       losing to a declared meter, and the wrapped-grand-staff ink above). Both
       halves were verified RED: reintroducing the engine write fails three of
       them by name, and dropping the painter's `?? inheritedMeter` fails the
       grand-staff one with the 49.584-vs-31.584 numbers above. The full suite
       (992 tests, 53 goldens) is green and no golden moved.

       One behaviour change fell out and is deliberate: `validateStaff` used to
       call `_findTimeSignature(measure)` per bar, which let a stale
       `inheritedTimeSignature` hint on a later bar override the meter the staff
       actually declares. It now follows the engine's rule exactly — declared
       beats inherited, hints only seed — so the two cannot disagree.
9. [ ] Option C (`LayoutNote`) when the editing layer starts — carried over from
       ADR-001 action item 6, still open
10. [ ] Publish a beam decision for `Chord`. Both maps are
       `Map<Note, BeamType>` and `BeamGrouper` groups `Note`s only, so a chord
       never appears in either — yet since wave 5 `TupletBeamPlan` beams a bare
       `Chord` automatically, so a chord CAN be drawn beamed with nothing
       published about it. Today every consumer falls back to the author's
       `Chord.beam` hint (`ChordRenderer`, `ScoreHitTester._chordIsBeamed`),
       which under-reports. Bounded cost while it stands: one flag's overhang
       of extra height on the selection box of a chord inside a tuplet.
