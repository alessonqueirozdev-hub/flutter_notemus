# ADR-004: A measure's opening block is engraved by convention; everything after the first note keeps document order

**Status:** Accepted (implemented in 2.7.1)
**Date:** 2026-08-22
**Deciders:** package maintainer
**Refines:** ADR-001's F-01 fix ("system elements stay in document order")

## Context

2.7.0 fixed finding F-01 by making `LayoutEngine._layoutMeasureCursor` preserve
the document order of system elements. The engine had been hoisting **every**
clef, key and meter to the head of the bar, which moved a genuine mid-measure
clef change to the barline and — because the cursor tracks the active clef in
the order it receives elements — positioned every note in the bar with the
*last* clef of the bar. `[treble, C4, bass, C4]` drew both C4s at the bass-clef
position, a twelfth off for the first one.

The fix was right for mid-measure changes and wrong for the head of the bar,
because MusicXML's `<attributes>` element has a **fixed content model**:

```
divisions, key, time, staves, part-symbol, instruments, clef, staff-details,
transpose, …
```

The clef comes *last*. A faithful parser therefore hands the engine
`key, time, clef`, and 2.7.0 drew it exactly that way. Measured on a 3-flat
4/4 import:

```
KeySignature@30.0   TimeSignature@69.6   Clef@105.6
```

Every score imported from MusicXML — that is, every real-world score — opened
with its key signature in front of its clef. It is visible in any screenshot.

The same shape had a second instance: `_layoutMultiVoiceMeasure` never read
`measure.elements` at all, so a polyphonic bar's opening block was reached only
because the parsers wrote every system element **twice**, once into
`measure.elements` and once into voice 1.

## Decision

The two regions of a bar obey different rules, and the rule is **positional**,
not textual:

* **The opening block** — the leading run of system elements, before the first
  rhythmic event — is a *convention*. It is emitted **clef → key signature →
  meter**, whatever order the source declared. Source order carries no musical
  information here.
* **The body** — everything from the first rhythmic event on — is a *sequence of
  events in time*. Its order **is** its meaning and is never touched. This is
  ADR-001's F-01 invariant, now enforced by construction rather than by comment.

`LayoutEngine.canonicalOpeningBlock` is the single place that knows the
convention, and both layout paths (single-voice and multi-voice) call it. The
sort is stable, so two elements of the same kind keep their written order.

Correspondingly, the parsers hoist **only the leading run** of system elements
into `measure.elements` and leave mid-measure changes with the voice that
carries them — so the duplication that used to compensate for the layout's blind
spot could be removed at the same time. The two had to move together: undoing
either alone draws the opening block twice or not at all.

## Options considered

### Option A — sort the opening block in the layout (chosen)

**Pros:** one place knows the convention; imports and hand-authored scores get
the same treatment; parsers stay faithful to their source.
**Cons:** the layout reorders elements it was handed, which is surprising unless
the split is made explicit — hence this ADR and the dartdoc on the helper.

### Option B — sort in each importer

**Pros:** the layout stays a pure consumer of order.
**Cons:** every importer, present and future, has to remember; a hand-authored
`Measure` that happened to be built key-first would still be drawn wrong; the
convention would be stated three times (MusicXML, MEI, JSON) instead of once.

### Option C — require callers to supply canonical order

**Pros:** no engine change.
**Cons:** pushes an engraving convention onto the caller, and the caller most
likely to get it "wrong" is a spec-conformant MusicXML file.

## Consequences

**Easier**
- Imported scores open correctly, which is the visible half of the fix.
- `StaffRenderer`, which tracks the active clef as it walks positioned elements
  in order, now sees the clef before the key signature and so places the key
  accidentals against the right clef.
- The parser duplication is gone; `measure.elements` is the single home of a
  polyphonic bar's opening block.

**Harder**
- A caller who deliberately wanted a meter drawn before a clef at the head of a
  bar cannot express it. No engraving convention asks for that.

**To revisit**
- The convention currently ranks only clef, key and meter. If `_isSystemElement`
  grows (a `<staff-details>` equivalent, say), its rank has to be decided here.

## Action items

1. [x] `LayoutEngine.canonicalOpeningBlock`, stable, documented.
2. [x] `_layoutMeasureCursor` uses it for the leading run only.
3. [x] `_layoutMultiVoiceMeasure` emits `measure.elements` as the opening block
       through the same helper.
4. [x] Both parsers hoist only the leading run and stop duplicating.
5. [x] `test/parsers/notation_parser_test.dart` re-baselined — it was asserting
       the duplication.
6. [x] Regression tests in `test/invariants/remediation_2_7_1_test.dart`.
