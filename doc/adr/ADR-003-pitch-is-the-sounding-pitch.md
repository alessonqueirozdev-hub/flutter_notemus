# ADR-003: `Pitch` is the sounding pitch; the clef prints it, the instrument transposes it

**Status:** Accepted (implemented in 2.7.1)
**Date:** 2026-08-22
**Deciders:** package maintainer
**Supersedes:** the implicit "`Pitch.octave` is the written octave" convention of 1.x–2.7.0

## Context

Two different things can be called "the pitch of a note", and 2.7.0 used both,
in different files, without saying so.

`MidiMapper`'s dartdoc declared one convention:

> Octave-transposing clefs (8va/8vb/15ma/15mb): `Pitch.octave` is the WRITTEN
> octave; the active `Clef`'s `octaveShift` is applied to obtain the SOUNDING
> pitch.

`StaffPositionCalculator` declared the same one in a comment — *"clefs with an
octave displacement alter the sounding height but NOT the writing on the staff,
so the visual calculation uses only the written octave"* — and therefore did
**not** apply the shift when placing a notehead.

That pair is self-consistent. It is also **not the convention the interchange
formats use**. MusicXML `<pitch>`, MEI `@pname`/`@oct` and MIDI note numbers all
mean the pitch as it *sounds* through the clef. The importer stored `<pitch>`
verbatim, so a tenor part written on a treble-8vb clef was read as if its
`<pitch>` were the written note.

Measured on 2.7.0, importing `<pitch>C4</pitch>` under
`<clef-octave-change>-1</clef-octave-change>`:

| | result | correct |
|---|---|---|
| staff position | −6 (identical to plain treble) | +1 (third space) |
| MIDI | 48 | 60 |

An octave wrong on the page **and** an octave wrong in playback, on the same
note, for opposite reasons.

The convention was not even applied uniformly inside the package. `c8vb` baked
its octave into its own `ClefReference` (`baseOctave: 3` where every other C clef
uses 4), so that one clef already implemented the sounding convention while all
the others implemented the written one. Whichever convention we chose, something
was already broken.

Separately, `<transpose>` — the *instrument's* written-to-sounding offset, which
is a different axis entirely — was parsed into a loose
`Score.metadata['transpositions']` map. `applyMusicXmlTransposition` existed to
consume it and was never called from `lib/`, `test/` or `example/`. A B-flat
clarinet part played back a major second high with the correct number sitting
inertly beside it.

## Decision

**`Pitch` is the sounding pitch, in the sense MusicXML, MEI and MIDI mean it.**

Two consequences follow, and each belongs to exactly one component:

1. **An octave-transposing clef affects only where a note is PRINTED.**
   `StaffPositionCalculator.calculate` subtracts `clef.octaveShift * 7` half-space
   positions. `MidiMapper` no longer looks at the clef at all.
2. **An instrument's transposition affects only how a note SOUNDS.**
   It becomes a first-class property of the model — `Staff.transposition`, of the
   new `Transposition` type — and `MidiMapper` adds `transposition.semitones`.
   The notated pitch is never rewritten, because the notated pitch is what the
   engine draws.

The importer therefore does no pitch arithmetic in either direction: it stores
`<pitch>` verbatim and records `<transpose>` on the staff. The exporter is
symmetric.

## Options considered

### Option A — keep "`Pitch` is the written pitch", convert on import

| Dimension | Assessment |
|---|---|
| Complexity | Low: one conversion in `_musicXmlPitch`, one inverse on export |
| Blast radius | Small; no rendering or MIDI change for hand-authored scores |
| Correctness | Fixes the import bug |

**Pros:** smallest diff; no behavioural change for existing users.
**Cons:** `Pitch.midiNumber` keeps meaning something other than the pitch that
sounds, which is a permanent trap in a public API; the clef octave has to be
threaded through the parser as parser state; `c8vb` stays inconsistent and has to
be fixed anyway; every future import/export path has to remember to convert.

### Option B — "`Pitch` is the sounding pitch" (chosen)

| Dimension | Assessment |
|---|---|
| Complexity | Medium: one change in the position calculator, one in the MIDI mapper |
| Blast radius | Breaking for hand-authored scores that use an octave clef |
| Correctness | Fixes import, export, rendering and playback together |

**Pros:** one meaning for `Pitch` everywhere; import and export become the
identity for the clef axis; the shift is applied in exactly one place
(`StaffPositionCalculator`), which every renderer already goes through; removes
the `c8vb` special case instead of preserving it.
**Cons:** a score built in code with an octave clef and pitches spelled for the
old convention will move by an octave on screen.

## Trade-off analysis

Option A is cheaper today and more expensive forever: it leaves a public `Pitch`
whose `midiNumber` is not the note you hear, and it puts the burden of
remembering that on every future contributor and every future import path.

Option B costs one breaking change in a pre-1.0 package whose current behaviour
is already internally inconsistent (`c8vb`). Anyone relying on the old
convention was relying on something that only held for five of the six
octave-clef types.

The deciding argument is where the knowledge lives. Under Option B, "an 8vb clef
prints an octave higher" is stated once, in the component that does the
printing, and "a B-flat clarinet sounds a tone lower" is stated once, in the
component that makes the sound. Neither fact has to be known anywhere else.

## Consequences

**Easier**
- `Pitch.midiNumber` is the pitch that sounds (before instrument transposition).
- MusicXML/MEI import and export need no pitch arithmetic.
- `MidiMapper` no longer tracks clefs for pitch purposes.
- Transposing instruments play back correctly for the first time.

**Harder**
- A `Staff` built in code with an octave clef must now be spelled with sounding
  pitches. `test/rendering/treble8vb_staff_position_test.dart` was re-baselined,
  and both of its former assertions were pinning the defect.

**To revisit**
- `Transposition.diatonic` is carried but not yet used: respelling a transposed
  part (concert-pitch view) needs it, and that feature does not exist.
- `<transpose><double/>` is recorded and warned about, not sounded.

## Action items

1. [x] `StaffPositionCalculator.calculate` applies `clef.octaveShift * 7`.
2. [x] `c8vb`'s `ClefReference` reset to `baseOctave: 4` (it must not shift twice).
3. [x] `MidiMapper` stops applying the clef shift; applies `Staff.transposition`.
4. [x] `Staff.transposition` + the `Transposition` value type in `lib/core/staff.dart`.
5. [x] MusicXML import records `<transpose>`; export emits it.
6. [x] `test/rendering/treble8vb_staff_position_test.dart` re-baselined, with a
       regression guard for the `c8vb` double-shift.
7. [ ] Concert-pitch view (`Score.toConcertPitch()`), using `Transposition.diatonic`
       for correct respelling.
