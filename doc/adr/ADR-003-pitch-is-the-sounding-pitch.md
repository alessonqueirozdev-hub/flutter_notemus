# ADR-003: `Pitch` is clef-invariant; the clef prints it, the instrument transposes it

**Status:** Accepted (implemented in 2.7.1)
**Date:** 2026-08-22
**Deciders:** package maintainer
**Supersedes:** the implicit "`Pitch.octave` is the written octave" convention of 1.x–2.7.0
**Amended 2.7.1 (wording only, decision unchanged):** the original title and
Decision said "`Pitch` is the sounding pitch", which is imprecise — it is only
true on the clef axis. Measured on the shipped code: a B-flat clarinet part
(`Transposition(diatonic: -1, chromatic: -2)`) importing `<pitch>C4</pitch>`
yields `Pitch` = C4 and `Pitch.midiNumber` = 60, and **plays MIDI 58**. So
`Pitch` is *not* the sounding pitch of a transposing instrument. The code is
right; the wording was not. §Decision and §Consequences below are restated
precisely. No behaviour, option or action item changed. The "To revisit" note on
`<double/>` was also corrected against measurement (see there).

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

**`Pitch` is invariant to the octave-transposing CLEF — the clef only changes
where the pitch is PRINTED — and the INSTRUMENT's transposition is applied only
at the MIDI boundary.**

Equivalently, and in the sense MusicXML `<pitch>`, MEI `@pname`/`@oct` and MIDI
note numbers mean it: `Pitch` is the *written* pitch of the part, read through
the clef exactly as the interchange formats write it, and no clef arithmetic is
ever performed on it. For a concert-pitch instrument that written pitch *is* the
sounding pitch; for a transposing instrument it is not, and the difference
(`Staff.transposition.semitones`) is added once, in `MidiMapper`, on the way
out. Measured: B-flat clarinet, `<pitch>C4</pitch>` → `Pitch` C4,
`Pitch.midiNumber` 60, emitted MIDI note 58.

Two consequences follow, and each belongs to exactly one component:

1. **An octave-transposing clef affects only where a note is PRINTED.**
   `StaffPositionCalculator.calculate` subtracts `clef.octaveShift * 7` half-space
   positions. `MidiMapper` no longer looks at the clef at all.
2. **An instrument's transposition affects only how a note SOUNDS.**
   It becomes a first-class property of the model — `Staff.transposition`, of the
   new `Transposition` type — and `MidiMapper` adds `transposition.semitones` at
   the MIDI boundary and nowhere else. The notated pitch is never rewritten,
   because the notated pitch is what the engine draws; `Pitch.midiNumber` is
   therefore the pitch *before* that offset, not the pitch you hear.

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
- MusicXML/MEI import and export need no pitch arithmetic on the clef axis: the
  round trip is the identity there.
- `MidiMapper` no longer tracks clefs at all. (2.7.1 also deleted the vestigial
  `_activeClef` field it still wrote — measured 1 write, 0 reads — along with the
  `// ignore: unused_field` that was hiding it.)
- Transposing instruments play back correctly for the first time.

**Sharper**
- `Pitch.midiNumber` is the note number of the *written* pitch. It equals the
  sounding note only when `Staff.transposition` is null or concert pitch; for a
  transposing part the sounding number is
  `pitch.midiNumber + staff.transposition!.semitones`. Callers that want "the
  note the listener hears" must go through `MidiMapper`, not through
  `Pitch.midiNumber`.

**Harder**
- A `Staff` built in code with an octave clef must now be spelled with sounding
  pitches. `test/rendering/treble8vb_staff_position_test.dart` was re-baselined,
  and both of its former assertions were pinning the defect.

**To revisit**
- `Transposition.diatonic` is carried but not yet used: respelling a transposed
  part (concert-pitch view) needs it, and that feature does not exist.
- ~~`<transpose><double/>` is recorded and warned about, not sounded.~~
  **Corrected 2.7.1 — this described neither the code nor the intent.** It IS
  sounded and NO warning is emitted. Measured: a part with `diatonic: -5`,
  `chromatic: -9`, `octave-change: -1` and `<double/>` gives
  `Transposition.semitones == -33` (the −12 of the doubling included) and plays
  C4 as MIDI 27, with `MidiSequence.warnings == []`. That is the intended
  behaviour: MusicXML says a doubled part sounds in *both* octaves, and a
  single-voice MIDI rendering has to pick one, so it picks the doubling octave.
- MusicXML 4.0's `<double above="yes"/>` (the doubling is an octave UP) now has
  a model axis, `Transposition.doubledAbove`. Measured on the same declaration:
  `semitones == -9`, C4 plays MIDI 51 — a 24-semitone swing from the `above="no"`
  case, which before 2.7.1 was unrepresentable and silently sounded two octaves
  low. The MusicXML parser does not yet read the attribute (it always passes
  `doubledAbove: false`); wiring it is action item 8.

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
8. [ ] `_musicXmlTranspose` in `lib/src/parsers/parser_support.dart` must read
       `<double above="yes"/>` and pass it through `MusicXmlTransposition` into
       `Transposition.doubledAbove` (the model axis exists as of 2.7.1).
