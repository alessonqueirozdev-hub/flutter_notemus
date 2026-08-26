# Flutter Notemus

[![pub.dev](https://img.shields.io/pub/v/flutter_notemus.svg)](https://pub.dev/packages/flutter_notemus)
[![CI](https://github.com/alessonqueirozdev-hub/flutter_notemus/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/alessonqueirozdev-hub/flutter_notemus/actions/workflows/ci.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.8.1+-blue.svg)](https://dart.dev/)
[![SMuFL](https://img.shields.io/badge/SMuFL-1.40-green.svg)](https://w3c.github.io/smufl/latest/)
[![MEI](https://img.shields.io/badge/MEI-v5%20CMN-green.svg)](https://music-encoding.org/guidelines/v5/content/index.html)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Professional music notation rendering for Flutter with SMuFL-compliant engraving, Bravura glyph support, a first-party notation-to-MIDI pipeline, and a **broad MEI v5 data model with CMN import/export** (see the [conformance section](#mei-v5-conformance) for what is imported/rendered vs. modeled).

---

## Project Links

- GitHub repository: https://github.com/alessonqueirozdev-hub/flutter_notemus
- pub.dev package: https://pub.dev/packages/flutter_notemus
- GitHub Pages (site/build): https://alessonqueirozdev-hub.github.io/flutter_notemus/
- Issue tracker: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues

---

## Table of Contents

- [Current Status](#current-status)
- [MEI v5 Conformance](#mei-v5-conformance)
- [Editorial and Professional Features](#editorial-and-professional-features--honest-status)
- [Open Pending Work](#open-pending-work)
- [Highlights](#highlights)
- [Installation](#installation)
- [Required Initialization](#required-initialization)
- [Quick Start](#quick-start)
- [API Guide](#api-guide)
  - [MusicScore Widget](#musicscore-widget)
  - [Pitch and Notes](#pitch-and-notes)
  - [Durations](#durations)
  - [Rests](#rests)
  - [Measures and Staff](#measures-and-staff)
  - [Clefs](#clefs)
  - [Key Signatures](#key-signatures)
  - [Time Signatures](#time-signatures)
  - [Barlines](#barlines)
  - [Chords](#chords)
  - [Ties and Slurs](#ties-and-slurs)
  - [Articulations](#articulations)
  - [Dynamics](#dynamics)
  - [Ornaments](#ornaments)
  - [Tempo Marks](#tempo-marks)
  - [Grace Notes](#grace-notes)
  - [Tuplets](#tuplets)
  - [Beams](#beams)
  - [Octave Markings](#octave-markings)
  - [Volta Brackets](#volta-brackets)
  - [Polyphony and Multi-Voice](#polyphony-and-multi-voice)
  - [Grand Staff, Choir, and Full Scores](#grand-staff-choir-and-full-scores)
  - [Gregorian Chant (Greciliae)](#gregorian-chant-greciliae)
  - [Repeats](#repeats)
  - [Playing Techniques](#playing-techniques)
  - [Breath and Caesura](#breath-and-caesura)
  - [Import from JSON, MusicXML, and MEI](#import-from-json-musicxml-and-mei)
  - [MIDI Mapping and Export](#midi-mapping-and-export)
  - [Selection and Hit-Testing](#selection-and-hit-testing)
  - [Measure Numbers](#measure-numbers)
  - [Using a Different SMuFL Font](#using-a-different-smufl-font)
  - [Themes and Styling](#themes-and-styling)
- [Reference JSON Format](#reference-json-format)
- [Architecture](#architecture)
- [Development Checklist](#development-checklist)
- [License](#license)

---

## MEI v5 Conformance

flutter_notemus ships a **notation-agnostic data model that covers the breadth of MEI v5 concepts** — from CMN through tablature, mensural, neume, harmonic analysis and figured bass — defined in the [MEI v5 Guidelines](https://music-encoding.org/guidelines/v5/content/index.html).

**Important — what is actually imported/rendered vs. modeled.** MEI *import* and *rendering* focus on **Common Music Notation (CMN)**, which is well supported. Several advanced MEI modules exist in the data model (you can construct them in Dart) but are **not yet wired to the MEI parser/renderer** — they are marked *Model only* below. The table reflects what is genuinely imported and/or rendered, not just representable. (An adversarial audit found ~58% of catalogued items fully wired; the rest are model-only or partial.)

**MEI is import-only.** There is no MEI serializer — `lib/src/parsers/` has a
reader and no writer. Nothing in this table should be read as MEI round-trip.
Export exists for **MusicXML** only. Full analysis:
[`doc/MEI_V5_AUDIT.md`](doc/MEI_V5_AUDIT.md), which separates *model only* /
*parsed* / *rendered* / *exported* / *round-trippable* per module.

### Coverage by MEI v5 module

Legend: ✅ modeled **and** imported/rendered · ◐ partial (see note) · ○ *model only* (classes exist; no MEI import/render yet).

| MEI v5 Module | Status | Notes |
|---|---|---|
| **CMN — Pitch & Duration** | ✅ | `Pitch`, `Duration`, `DurationType` (maxima → 2048th) |
| **CMN — Events** | ✅ | `Note`, `Rest`, `Chord`, `Space`, `MeasureSpace` |
| **CMN — Measure & Staff** | ✅ | `Measure` (`@n`), `Staff` (configurable `lineCount`), `xml:id` |
| **CMN — Clef / Key / Meter** | ✅ | `Clef` (20 types); `@mode` → `KeyMode` and additive meter (`meter.count="3+2+2"`, `<meterSigGrp>`) parsed since 2.7.0 |
| **CMN — Articulation** | ✅ | `ArticulationType` (17 types) |
| **CMN — Dynamics** | ◐ | `DynamicType` has 36 types; 9 are rendered, plus hairpins |
| **CMN — Ornaments** | ◐ | `OrnamentType` has 43 types; 33 mapped to glyphs |
| **CMN — Slur / Tie / Beam** | ◐ | `SlurType`, `TieType`, `BeamType`, `SlurEvent` (nested/numbered); slurs and ties split correctly across a system break since 2.7.0. **Secondary beam levels** (MusicXML `<beam number="2">`) are still collapsed to one level |
| **CMN — Tuplets** | ✅ | `Tuplet`, `TupletBracket`; nested tuplets and chords inside tuplets are **drawn** since 2.7.0 (they were skipped by every render branch before) |
| **CMN — Polyphony** | ✅ | `Voice`, `MultiVoiceMeasure`, `StemDirection`; voice-aware bar capacity, onset-based cross-voice collision and per-voice playback since 2.7.0 |
| **CMN — Score structure** | ✅ | `Score`, `StaffGroup`, `ScoreDefinition` (`<scoreDef>`) |
| **CMN — Navigation** | ✅ | `RepeatMark`, `VoltaBracket`, `BarlineType` (15 types); MEI `<ending>` → `VoltaBracket` since 2.7.0 |
| **Lyrics & Text** | ◐ | `Syllable`/`SyllableType` imported & rendered; `Verse` grouping not populated by the parser yet |
| **Metadata (meiHead / FRBR)** | ✅ | parsed since 2.7.0 via `MEIParser.scoreFromMei` (`fileDesc`, `titleStmt`, contributors, `pubStmt`, `workList`, `revisionDesc`) |
| **Harmonic Analysis** | ○ | `HarmonicLabel`, `ScaleDegree`, `ChordTable` exist; **not parsed/rendered** |
| **Figured Bass** | ○ | `FiguredBass`, `FigureElement` exist; **not parsed/rendered** |
| **Microtonality** | ✅ | `AccidentalType` (sagittal, koma, quarter-tone) — modeled & rendered |
| **Solmization** | ✅ | `Pitch.fromSolmization()`, `Pitch.solmizationName` |
| **Tablature** | ✅ | `Note.tabFret`/`tabString` modeled & rendered; MEI `@tab.fret`/`@tab.string` parsed since 2.7.0 (including inside `<chord>`). The richer MEI tablature *model* stays model-only — see [`doc/MODEL_ONLY.md`](doc/MODEL_ONLY.md) |
| **Mensural Notation** | ○ | `MensuralNote`, `Ligature`, `Mensur` exist; **no MEI import/render** |
| **Neume Notation** | ◐ | rendered via **GABC/Gregorian**; MEI `<neume>` import not implemented |

### Key MEI v5 features

> These snippets show the **Dart model API** (constructing objects). For modules
> marked *Model only* / ◐ above (figured bass, mensural, MEI `<neume>`), the
> objects are constructible but are **not yet imported from MEI XML or
> rendered** — see the status table. `meiHead` is **not** in that group: it is
> both constructible and parsed.

```dart
// xml:id on any element (MEI cross-referencing)
final note = Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter))
  ..xmlId = 'note-1';

// Explicit measure number (MEI <measure @n>)
final measure = Measure(number: 5);

// Configurable staff lines (MEI staffDef @lines)
final percStaff = Staff(lineCount: 1);      // percussion
final tabStaff  = Staff(lineCount: 6);      // guitar tab

// KeyMode (MEI @mode)
KeySignature(2, mode: KeyMode.dorian);

// Free-time measure (senza misura)
TimeSignature.free();

// Additive meter (3+2+2)/8
TimeSignature.additive(groups: [3, 2, 2], denominator: 8);

// Lyrics with syllabification (MEI <syl>)
Verse(number: 1, syllables: [
  Syllable(text: 'A-', type: SyllableType.initial),
  Syllable(text: 've', type: SyllableType.terminal),
]);

// Figured bass (MEI <fb>/<f>)
FiguredBass(figures: [
  FigureElement(numeral: '6'),
  FigureElement(numeral: '4', accidental: FigureAccidental.sharp),
]);

// Tablature (MEI @tab.fret @tab.string)
Note(
  pitch: Pitch(step: 'E', octave: 4),
  duration: Duration(DurationType.quarter),
  tabString: 1, tabFret: 0,  // open first string
);

// Mensural notation
MensuralNote(pitchName: 'G', octave: 3, duration: MensuralDuration.semibreve);
Mensur(tempus: 3, prolatio: 2);  // Tempus perfectum, prolatio minor

// Neume (Gregorian chant)
Neume(type: NeumeType.pes, components: [
  NeumeComponent(pitchName: 'F', octave: 3, form: NcForm.punctum),
  NeumeComponent(pitchName: 'G', octave: 3, form: NcForm.virga),
]);

// MEI header (meiHead) — constructible here AND parsed from MEI XML since
// 2.7.0 by MEIParser.scoreFromMei (whole score) / MEIParser.headerFromMei
// (header alone): fileDesc/titleStmt (title, subtitle, contributors), pubStmt,
// sourceDesc, encodingDesc, workList and revisionDesc. There is still no MEI
// writer, so a header is read but never written back out.
Score(
  staffGroups: [],
  meiHeader: MeiHeader(
    fileDescription: FileDescription(
      title: 'Ave Maria',
      contributors: [Contributor(name: 'Schubert', role: ResponsibilityRole.composer)],
    ),
    encodingDescription: EncodingDescription(
      meiVersion: '5',
      applications: ['flutter_notemus'],
    ),
  ),
  scoreDefinition: ScoreDefinition(
    clef: Clef(clefType: ClefType.treble),
    keySignature: KeySignature(0),
    timeSignature: TimeSignature(numerator: 4, denominator: 4),
  ),
);

// Pitch class (MEI pclass) and solmization
Pitch(step: 'C', octave: 4).pitchClass;        // → 0
Pitch(step: 'A', octave: 4).pitchClass;        // → 9
Pitch.fromSolmization('sol', octave: 4);       // → G4
Pitch(step: 'G', octave: 4).solmizationName;   // → 'sol'

// All MEI dur values including breve, long, maxima, and 256–2048
const Duration(DurationType.breve);
const Duration(DurationType.long);
const Duration(DurationType.maxima);
const Duration(DurationType.twoHundredFiftySixth);
DurationType.fromMeiValue('2048');  // → DurationType.twoThousandFortyEighth
```

For a full conformance audit see [`doc/MEI_V5_AUDIT.md`](doc/MEI_V5_AUDIT.md).

---

## Current Status

- Current release: `2.7.0`
- Previous pub.dev baseline: `2.6.0`
- **2.7.0 is an audit-remediation release, and it bundles three of them.** Three
  internal milestones were tagged in git between 2.6.0 and this release and
  never published; the [CHANGELOG](CHANGELOG.md) folds all three into the 2.7.0
  entry, newest first. Together they close **124 catalogued findings** from four
  adversarial forensic audits, each of which executed the engine rather than
  reading it: 42 against 2.6.0, 30 against the result, then **two independent
  audits of the same tree** — 42 and 20 findings, reconciled into one master
  list of 50 in
  [`doc/AUDITORIA_RECONCILIADA_2026-08-23.md`](doc/AUDITORIA_RECONCILIADA_2026-08-23.md).
  That reconciliation is worth reading on its own: **32 of the 50 findings were
  seen by only one of the two audits**, including seven of the nine blockers,
  and two were seen by neither.
- Single-staff and multi-staff CMN rendering, MIDI mapping and `.mid` export
  (CMN and chant), and Gregorian square notation are the load-bearing features.
- Android native audio backend is active; iOS, macOS, Windows, Linux and Web are
  **no-op stubs** (`nativeIsReady` returns `false`) — tracked as
  [#1](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1)/[#15](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/15).

### What's New in 2.7.0

A second adversarial re-audit — again by executing the engine — was reconciled
into one defect list and remediated in five waves, the last of which re-probed
every claim below before it was written down. Full detail and every measured
before/after is in the [CHANGELOG](CHANGELOG.md#272---2026-08-22).

- **A layout decision is a VALUE now, not a mutation of your model.**
  `LayoutEngine.beams` / `LayoutEngine.tupletBeams` publish beam membership,
  read through `LayoutEngine.beamOf(note)`; nothing writes `Note.beam` any more
  ([ADR-005](doc/adr/ADR-005-layout-decisions-are-values.md)). Measured on two
  bars of loose quavers: exporting the same `Staff` used to give **3 349
  characters and 0 `<beam>` tags before it was laid out and 3 973 characters
  with 16 `<beam>` tags after** — what a user got in their file depended on
  whether the score had been displayed. Both exports are now byte-identical
  before and after `layout()` and before and after a paint. **Read the effective
  beam through `beamOf`, not off `Note.beam`** — that is a behaviour change, and
  the two sites inside this package that had not caught up (the `GrandStaff`
  cross-staff relocation predicate and its cross-staff beam walk) now read
  `beamOf` too. Measured on four quavers with the middle two sent to the other
  hand: the automatically beamed group and the same group with the beams
  written by hand into `Note.beam` rasterise to the SAME 10 395 px of ink and
  the SAME beam runs (rows 69-74 spanning x 161-274). Before, the automatic
  case found zero cross-staff beam runs and drew no beam at all.
- **Beaming covers the meters it claimed not to.** Re-measured over the full
  grid of numerators 2, 3, 4, 5, 6, 7, 8, 9 and 12 against denominators 2, 4, 8
  and 16, filled with eighths, sixteenths and thirty-seconds: **108
  combinations, 107 of which hold two or more notes, and exactly one of those
  107 comes out unbeamed** — 3/16 holding two quavers, a bar that OVERFLOWS its
  own meter (0.25 against 0.1875), where there is no beat to group by. Before,
  26 meter/figure combinations produced no beam at all.
- **A tuplet is legible.** Its internal grid no longer depends on the configured
  spacing model, and the minimum slot went 1.4 → 1.9 staff spaces. Measured at
  `staffSpace = 12` on the corpus case `m04m_tuplet_ratio` (5:4, five stepwise
  sixteenths): the step is 22.800 px = 1.9000 SS and the real ink gap between
  adjacent noteheads **went from 2 px to 9 px (0.750 SS)**, against the
  package's own `SpacingPreferences.normal.minGap` of 0.25 SS = 3 px.
- **`GrandStaff` scrolls horizontally.** Measured on one bar of 200
  thirty-seconds in a 300 px viewport: 1 `Scrollable`, `AxisDirection.right`,
  `maxScrollExtent 5525.76` + 300 px viewport = 5825.76, which is exactly
  `GrandStaffPainter.contentWidth`. 100% of the music is reachable; it used to
  be 0.5%.
- **A note's hit box covers its flag and its ledger lines.** A click on the
  outer two thirds of an eighth's flag, or on either END of a ledger line, used
  to return `null`.
- **MusicXML tuplets survive the round trip.** The exporter writes
  `<notations><tuplet>` alongside `<time-modification>`, and the importer opens
  and closes a group from the ratio even when the bracket is missing. Measured
  on a 4/4 bar of a 3:2 triplet plus a quarter: the bar value went 0.5 → 0.625
  with the group dissolved into four loose notes, and now round-trips 0.5 → 0.5
  with the `Tuplet` coming back as a `Tuplet` (2 `<tuplet>` tags, one `Tuplet`
  and one loose note on re-import).
- **The parsers report what they could not read.** `parseMusicXML`,
  `scoreFromMusicXML`, `parseMEI` and `parseMeiScore` take an optional
  `warnings` list, so a partial import is no longer indistinguishable from a
  complete one. Measured on nine malformed documents that all used to import in
  silence: a zero `<divisions>` and a non-positive `<duration>` now raise
  warnings, and **three of the nine are rejected outright** with a
  `FormatException` — `<pitch>` with no `<octave>`, an unknown `<step>`, and a
  document that is not a score. **Coverage is not total: four of the nine are
  still absorbed in silence** — an unknown `<clef><sign>`, an unknown `<type>`,
  a non-numeric `<alter>` and a missing `<part-list>`.
- **PDF exports a grand staff as a grand staff, across as many pages as it
  needs.** The grand-staff path goes through `GrandStaffPainter`, so the brace
  and the system-spanning barlines are really there instead of two unrelated
  single staves, and the group is paginated by system instead of squeezed into
  one clipped image. Measured on a 40-bar two-staff piano score: it wraps into
  **14 systems**, which come out as **3 pages of 5 / 5 / 4 systems = 14 of 14**,
  the largest page raster is 1928 x 2520 px against the 8192 px cap, and
  `PdfExporter.warnings` is empty. 2.7.1 put the same music in one image on one
  page and clipped it to 39.8% of its height.
  One caveat is real and remains: **this package ships no text face.** The
  fallback chain asks for `Academico, Century Schoolbook, Edwin, serif` while
  `assets/` holds only `Bravura.otf` and `greciliae.ttf` and `pubspec.yaml`
  declares exactly those two families, both of them music fonts. On a host that
  supplies none of the four — which includes headless rasterisation, so PDF
  export — every string comes out as `.notdef` boxes, and the terminal `serif`
  was measured NOT to rescue it. The escape hatch is
  `MusicTextFont.use('YourFace')` or `MusicScoreTheme(textFontFamily: ...)`;
  both are exported from `package:flutter_notemus/flutter_notemus.dart`, and
  `kMusicTextFontFallback` is the chain they replace. **The hatch reaches every
  prose string, including the four kinds it used to miss.** Tempo marks,
  expression text, word dynamics and repeat instructions were built by
  `SymbolAndTextRenderer` with the fallback chain already attached, and the
  chain-wins rule then made the injection point unreachable — measured, the
  same score rasterised to identical ink with and without `MusicTextFont.use`.
  Those ten sites no longer pre-supply it. Measured after, at `staffSpace = 12`
  in a 900 px viewport: **14 942 px of ink and 2 `.notdef` boxes with no face
  registered, 6 886 px and 0 boxes with one injected.**

### Also new in 2.7.0 — from the milestone git tagged as 2.7.1

An independent adversarial **re-audit** of 2.7.0 verified its 38 remediation
claims by executing the engine — 25 confirmed outright, 13 partially, none
false — and found 30 defects the 792 green tests had not caught. All of them are
fixed here; see the [CHANGELOG](CHANGELOG.md#271---2026-08-22) and
[`doc/AUDITORIA_FORENSE_2026-08-22.md`](doc/AUDITORIA_FORENSE_2026-08-22.md).

The headline items:

- **Every imported score drew its key signature in front of its clef.**
  MusicXML's `<attributes>` puts `<clef>` last, and 2.7.0 had started honouring
  document order everywhere. The opening block is a convention
  ([ADR-004](doc/adr/ADR-004-opening-block-is-a-convention.md)).
- **`Pitch` is now the sounding pitch**, as MusicXML, MEI and MIDI mean it
  ([ADR-003](doc/adr/ADR-003-pitch-is-the-sounding-pitch.md)). An imported tenor
  part on a treble-8vb clef used to be drawn an octave low *and* played an
  octave low.
- **An 8va/8vb bracket now moves the notes under it.** `OctaveMark` was
  engraved but had no reader anywhere in the package, so a marked passage read
  an octave off the page. Measured on a C6 under a treble clef at
  `staffSpace: 12`: the printed staff position was 8 with no mark *and* 8 under
  every one of the six bracket types; it is now 1 under 8va, 15 under 8vb, −6
  under 15ma, 22 under 15mb, −13 under 22da and 29 under 22db, and the
  engraved Y of the notehead moves 12.0 → 54.0 px under 8va — 42.0 px, which is
  3.5 staff spaces, exactly one octave. `Pitch` still carries the *sounding*
  pitch ([ADR-003](doc/adr/ADR-003-pitch-is-the-sounding-pitch.md)); only where
  the note is printed changes.
- **Beam slant follows Gould's interval table.** A 2nd, a 6th and a two-octave
  leap all produced the same 0.25-staff-space slant before.
- **`MultiVoiceMeasure.elements` were silently dropped by the layout**, which
  also left every note in such a bar sitting on the staff baseline.
- **A grand staff with an over-full bar crashed the painter**; over-full bars are
  what importers produce.
- **Layout is linear again**: 6 400 bars went from 5 991 ms to 313 ms.
### What's New in 2.7.0

**Engraving corrections** (output changes on purpose; 39 of the 52 existing
goldens were re-baselined and one was added, for 53 in total):

- **Compound meters beam in threes.** 3/8, 6/8, 9/8 and 12/8 used to group the
  beat-completing note into the next group and orphan the last note of the bar.
- **A mid-measure clef change stays where it was written** and only affects the
  notes after it. Every note in such a bar used to be drawn with the *last* clef
  of the bar — a twelfth off for the first one.
- **Grand-staff hands line up.** Staves are aligned on a shared musical time
  grid ([ADR-002](doc/adr/ADR-002-shared-musical-time-grid.md)); beat 3 of a 4/4
  bar used to sit 38 px apart between the hands.
- **Rhythmic spacing is proportional across all 15 duration types.** A breve used
  to be spaced like a quarter — narrower than a whole note.
- **Every stem in a beam group clears the minimum length**, lyrics claim
  horizontal space, courtesy accidentals are drawn with parentheses/brackets,
  and accidental widths come from the SMuFL metadata.
- **Measure numbers** are engraved at the start of every system.

**New capabilities:**

- [`ScoreHitTester`](#selection-and-hit-testing) — selection and hit-testing by
  point, region, measure, system, voice and time range.
- Per-voice / per-staff playback with mute and solo.
- Real PDF export of the engraving (it used to emit placeholder pages).
- A different SMuFL font can be loaded (`SmuflFontDescriptor`).

**Correctness and robustness:**

- The layout no longer replaces your model objects
  ([ADR-001](doc/adr/ADR-001-layout-never-clones-the-model.md)), so identity —
  and therefore selection, editing and hit-testing — survives the pipeline.
- MusicXML import honours `<divisions>`/`<duration>`, `<backup>` and
  `<forward>`; MEI reads every `<section>`.
- Invalid input fails with a `FormatException` naming the element instead of
  crashing later with a null-check `TypeError`.
- New invariant, selection, Gregorian-calibration and fuzz test suites.

### What's New in 2.6.0

The library is no longer single-staff. This release adds a full multi-staff /
score renderer, cross-staff beaming, a sweep of Behind-Bars CMN corrections,
deeper MusicXML/MEI import, and Gregorian render-fidelity work — and also
consolidates the earlier engraving/typographic correctness pass that had not
yet reached pub.dev. Everything is backward-compatible — existing `MusicScore`
usage is unchanged. See the [CHANGELOG](CHANGELOG.md#260---2026-06-19) for the
full list.

- **Grand staff, choir, and full scores** — new [`GrandStaff`](#grand-staff-choir-and-full-scores)
  and `ScoreView` widgets render a `StaffGroup`/`Score` on a shared horizontal
  grid: piano grand staff, SATB, and multi-section systems, with SMuFL
  brace/bracket glyphs, system-spanning barlines, **multi-system wrapping**
  (clef/key restated per system), and **cross-staff beaming**.
- **MusicXML import → scores** — each part becomes a braced/bracketed
  `StaffGroup`; `<part-group>` section brackets and mid-beam `<staff>` changes
  (auto cross-staff) are honored.
- **CMN engraving** — chord-stem direction fix, Gould square-root /
  inter-onset spacing, mid-system clef/key/time changes, cue-size clef changes,
  cautionary/editorial accidentals, nested slurs, additive meters, tuplet
  ratios, sloped tuplet brackets, chord articulations, cross-voice notehead
  displacement, and more.
- **Gregorian chant** — episema/mora rendered with Greciliae glyphs
  (shape-specific episema), asymmetric divisio breathing, climacus/strophae
  tucking, custos length by leap.
- **Earlier engraving/typography pass** (also shipping here) — SMuFL `brace`
  glyph for staff-group braces, robust `repeatBoth` barlines, chord lyrics via
  the public `NoteRenderer.renderSyllables`, SMuFL-anchored stem/flag
  attachment, and `Chord`/`Tuplet`-aware spacing — closing issues
  [#3](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/3),
  [#4](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/4),
  [#5](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/5),
  [#8](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/8),
  [#9](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/9), and
  [#12](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/12).

### What's New in 2.5.1

- Stem-safe slur and tie routing now keeps curves on the notehead side for regular notes, grace notes, and chord ties.
- Arpeggio, tuplet, and octave-mark engraving were retuned for tighter alignment, clearer brackets, stronger contrast, and vertically centered score previews.
- The example gallery was refreshed with a Cupertino shell, restored non-redundant public demos, dedicated scroll controllers, white score canvases, and new lyrics/text coverage (`LyricsTextExample`).
- `ScorePreviewFrame` no longer forces a fixed bounded height on `MusicScore`; scores now render at their natural height, eliminating adaptive scale-down, clipped elements, and text overlap in example cards.
- Layout rendering preserves voice context during horizontal justification, while beaming retains the note metadata consumed by downstream renderers and parsers.
- `MusicScorePainter.shouldRepaint` uses a deterministic layout signature, backed by expanded regression coverage for spacing, grouping, articulation helpers, tuplets, SMuFL positioning, chord grouping, and example smoke tests.
- CI pipeline (`.github/workflows/ci.yml`) added — runs `flutter analyze`, `flutter test`, and `flutter pub publish --dry-run` on every push and pull request.
- All source comments and documentation strings migrated to English throughout the entire codebase (library, tests, and examples) — Issue #11 closed.
- Duplicate stem X-offset constants in `BeamRenderer` extracted into a single `_stemXOffset()` helper.

---

## Editorial and Professional Features — honest status

The 2.6.0 audit asked for this table explicitly, because "the class exists" and
"the feature works" had drifted apart. Statuses are verified against the code,
not against intent. `SUPPORTED` means it survives the whole path
`model → layout → render` (and, where relevant, import/export).

| Feature | Status | Note |
|---|---|---|
| Measure numbers | **SUPPORTED** | engraved at every system start; `Measure.number` honoured (2.7.0) |
| Courtesy / editorial accidentals | **SUPPORTED** | resolved *and* drawn with SMuFL parentheses/brackets (2.7.0) |
| Instrument / group names | **SUPPORTED** | `StaffGroup.name` and `Staff.name`/`abbreviation`, drawn beside the brace/bracket; imported from MusicXML `<part-name>`/`<group-name>` and exported, and from MEI `<staffGrp><label>`/`<labelAbbr>`, since 2.7.0 (measured: `Piano` / `Pno.`, both `null` before) |
| Transposing instruments | **SUPPORTED** | `Staff.transposition` is imported, applied by `MidiMapper` and exported (2.7.1). `Pitch` is the SOUNDING pitch and octave clefs are applied on the drawing side only — see [ADR-003](doc/adr/ADR-003-pitch-is-the-sounding-pitch.md). Concert-pitch RESPELLING is still missing |
| Cue notes | **NOT SUPPORTED** | `<cue/>` is not modelled; cue-*size* is used only for mid-system clef changes |
| Rehearsal marks | **SUPPORTED** | imported from MusicXML and engraved in a SMuFL box (2.7.0); the golden is `m04s_rehearsal_marks` |
| Page numbers | **NOT SUPPORTED** | there is no page model; PDF export paginates by system |
| Ossia staves | **NOT SUPPORTED** | |
| Hidden / invisible notes | **NOT SUPPORTED** | no `print-object` equivalent |
| Coloured notes | **PARTIAL** | colours are per-theme, not per-element; `Voice.color` is not consumed |
| Linked parts / part extraction | **NOT SUPPORTED** | `ScoreView` always renders every staff of the score |
| Conductor score | **SUPPORTED** | `Score` → `StaffGroup`s → `ScoreView` |
| System text | **PARTIAL** | `MusicText` renders tempo/expression/instruction; other types fall through |
| Figured bass, mensural, harmonic analysis | **MODEL ONLY** | see [`doc/MODEL_ONLY.md`](doc/MODEL_ONLY.md) |
| MEI header (`meiHead`) | **PARTIAL** | *imported* and re-verified in 2.7.0 (`MEIParser.scoreFromMei` / `headerFromMei`) (`fileDesc/titleStmt/title` round-trips into `MeiHeader.fileDescription.title`); never written back — `grep -rn 'toMei' lib/` returns 0 hits, there is no MEI serializer |

---

## Open Pending Work

All pending work is tracked as GitHub issues, with the local index mirrored in [`doc/OPEN_ISSUES.md`](doc/OPEN_ISSUES.md).

- Audio, export, and playback roadmap: [#1](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1), [#2](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/2), [#15](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/15), [#20](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/20)
- Engraving and layout follow-up: [#14](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/14) (inter-note hyphen centering — needs post-layout pass)
- Content and text rendering follow-up: [#13](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/13) (melisma extension lines — needs post-layout pass)
- Editor and interactivity roadmap: [#16](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/16), [#17](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/17), [#18](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/18), [#19](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/19)
- Remaining example/system integration work: [#7](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/7)

### Known limitations, measured and still open

Everything here was found by executing the engine, and nothing leaves this list
until a pass that did not write the fix has re-measured it. Six entries have
left it that way across 2.7.0–2.7.1 — no beams in 26 meter/figure combinations,
MusicXML tuplets not surviving a round trip, `GrandStaff` with no horizontal
scroll, a single-page clipped grand-staff PDF, cross-staff beams not being
drawn at all, and the text-font escape hatch being inert on prose. Every one of
them was re-probed for this release by a pass that did not write the fix, and
each came back clean: `1 Scrollable, AxisDirection.right, maxScrollExtent
5525.76` covering 100% of the content; `3 music pages, 14 of 14 systems,
warnings empty`; an automatically beamed cross-staff group that now rasterises
identically to the hand-beamed one (10 395 px of ink, the same beam runs) where
it used to draw nothing; and an injected text face that now moves the ink
(14 942 px → 6 886 px) where it used to change nothing at all. The bar was not
lowered; those bullets are gone because the engine stopped having them. A
seventh — silent acceptance of malformed MusicXML — left it only PARTLY, and
the residue is the second bullet below.

The closing sign-off found **two more** and both were fixed before release; they
are recorded with their measurements in `CHANGELOG.md` under *Closed at
sign-off*. Gould's rule that a fully beamed tuplet shows only its number is now
applied to rendered scores — the rule existed but `Tuplet.shouldShowBracket` had
no caller, so `TupletRenderer` decided with the deprecated `tuplet.showBracket`
and drew a bracket unconditionally (measured: a beamed triplet went from 1960 to
1832 px of ink; one containing a rest, and one of quarters, keep their bracket).
And `LayoutEngine.layout()` no longer writes `Measure.inheritedTimeSignature`
onto the caller's model, which used to flip `Measure.add` from accepting a note
to throwing `MeasureCapacityException` purely because the score had been laid
out; the derived meter is a value now and validation is unaffected.

Everything below is **not** a defect — it is a set of deliberate boundaries,
each measured:

- **This package ships no text face**, so on a host that provides none of
  `Academico, Century Schoolbook, Edwin, serif` every string is a `.notdef`
  box. `pubspec.yaml` declares exactly two families and both are music fonts
  (`Bravura`, `Greciliae`); `assets/smufl/` holds `Bravura.otf` and no text
  font at all. Measured: the terminal generic `serif` does NOT rescue it — a
  headless binary with a face literally registered as `serif` produced a
  byte-identical PNG. `MusicTextFont.use` / `MusicScoreTheme.textFontFamily` is
  the supported answer and, since this release, reaches every string the
  package draws.
- **Four kinds of malformed MusicXML are still absorbed in silence.** Re-probed
  in this release over seven documents: a zero `<divisions>` and a non-positive
  `<duration>` raise warnings, a `<pitch>` with no `<octave>` and an unknown
  `<step>` are rejected with a `FormatException`, and an unknown
  `<clef><sign>`, an unknown `<type>` and a non-numeric `<alter>` come back
  **SILENT** — 2 rejected, 2 warned, 3 silent. A missing `<part-list>` is the
  fourth silent case.
- **A single measure can still be wider than the viewport.** The engine
  compresses an over-full bar down to `LayoutEngine.minimumSpacingScale` (0.35)
  and no further, because past that the noteheads collide. Measured on 40 whole
  notes written into one 4/4 bar at 900 px: 43 elements on one system reaching
  x = 2 073.0 px, **2.30x** the line. (It was 2.03x until this release, and
  grew for a correction: a semibreve now reserves `noteheadWhole`'s real
  advance of 1.688 staff spaces instead of `noteheadBlack`'s 1.18.) No music is lost — `MusicScore` and
  `GrandStaff` both scroll horizontally — and since this release the engine
  names the bar and the factor in `LayoutEngine.warnings` instead of
  overflowing without a word. For a fixed-width medium the bar has to be
  re-barred or the staff space reduced.
- **Advanced MEI modules are model-only.** Figured bass, mensural notation and
  MEI `<neume>` are constructible in Dart but are not imported from MEI XML and
  not rendered; the compatibility table above marks each one.
- **Tuplet-internal spacing ignores the configured `SpacingModel`** by design,
  so that `TupletRenderer` (which has no spacing engine) and `LayoutEngine`
  cannot draw two different grids. Measured across all four models: the X
  positions of a tuplet's children are identical in all four, while the same
  durations written as plain notes move by ratios of 1.250 / 1.137 / 1.027 /
  1.278.

---

## Highlights

### Core notation

- Notes from whole through 1024th durations
- Rests for all supported durations
- Accidentals (natural, sharp, flat, double sharp, double flat)
- Automatic ledger lines

### Clefs

- Treble, bass, alto, tenor, percussion, tablature
- Octave-transposing clef variants (8va, 8vb, 15ma, 15mb)

### Rhythm and layout

- Proportional rhythmic spacing
- Auto and manual beaming
- Tuplet support
- Collision-aware layout
- Multi-measure and multi-system rendering

### Symbols and expression

- Dynamics and hairpins
- Articulations
- Ornaments
- Tempo marks and text
- Ties and slurs
- Volta brackets, repeat symbols, and structural barlines
- Octave markings

### Multi-staff and polyphony

- Multiple voices in a single staff (`MultiVoiceMeasure`)
- Multi-staff score support (`Score`, `StaffGroup`)
- `GrandStaff` / `ScoreView` widgets rendering a group on a shared horizontal grid
- Grand staff scenarios (piano) with SMuFL `brace` and system-spanning barline
- SATB-style aligned staff rendering with `bracket` glyphs
- **Cross-staff beaming** (`Note.crossStaffMove`) — beams that cross between staves
- **Multi-system wrapping** with clef/key restated at each system start

### Gregorian chant (square notation)

- Greciliae font (SIL OFL) precomposed neumes — not geometry-built from CMN glyphs
- Punctum, virga, podatus/clivis, torculus/porrectus, scandicus/climacus, quilisma
- Liquescence, compound neumes, repeated notes, special neumes
- Episema and *mora* (augmentation dot) rendered with shape-specific Greciliae glyphs
- Divisio (minima/minor/maior/finalis) with asymmetric breathing space
- Custos (line-end guide) sized by the leap to the next system
- GABC import and `ChantScore` playback mapping

### Import and interoperability

- JSON parser
- MusicXML parser (`score-partwise` and `score-timewise`)
- MEI parser
- Unified normalization to the same internal model

### MIDI pipeline

- Notation-to-MIDI mapping from `Staff` and `Score`
- Repeat and volta expansion for playback timeline
- Tuplet/polyphony/tie-aware event generation
- Metronome track generation
- Standard MIDI file export (`MidiFileWriter`)

---

## Installation

Add dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_notemus: ^2.6.0
```

Install packages:

```bash
flutter pub get
```

---

## Required Initialization

Load Bravura and SMuFL metadata before rendering any score:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader('Bravura');
  loader.addFont(
    rootBundle.load('packages/flutter_notemus/assets/smufl/Bravura.otf'),
  );
  await loader.load();

  await SmuflMetadata().load();

  runApp(const MyApp());
}
```

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class SimpleScorePage extends StatelessWidget {
  const SimpleScorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 6),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure);

    return Scaffold(
      body: SizedBox(
        height: 180,
        child: MusicScore(staff: staff),
      ),
    );
  }
}
```

---

## API Guide

### MusicScore Widget

```dart
MusicScore(
  staff: staff,
  staffSpace: 12.0,
  theme: const MusicScoreTheme(),
)
```

### Pitch and Notes

```dart
Note(
  pitch: const Pitch(step: 'G', octave: 4),
  duration: const Duration(DurationType.quarter),
  articulations: [ArticulationType.staccato],
  tie: TieType.start,
  slur: SlurType.start,
  beam: BeamType.start,
)
```

Accidentals are encoded directly in `Pitch`:

```dart
const Pitch(step: 'F', octave: 5, alter: 1.0);   // sharp
const Pitch(step: 'B', octave: 4, alter: -1.0);  // flat
const Pitch(step: 'C', octave: 5, alter: 2.0);   // double sharp
const Pitch(step: 'D', octave: 4, alter: -2.0);  // double flat
```

### Durations

```dart
const Duration(DurationType.whole);
const Duration(DurationType.half);
const Duration(DurationType.quarter);
const Duration(DurationType.eighth);
const Duration(DurationType.sixteenth);
const Duration(DurationType.thirtySecond);
const Duration(DurationType.sixtyFourth);
const Duration(DurationType.oneHundredTwentyEighth);
```

Dotted durations:

```dart
const Duration(DurationType.quarter, dots: 1);
const Duration(DurationType.half, dots: 2);
```

### Rests

```dart
Rest(duration: const Duration(DurationType.whole));
Rest(duration: const Duration(DurationType.half));
Rest(duration: const Duration(DurationType.eighth));
```

### Measures and Staff

```dart
final staff = Staff();
final measure = Measure();

measure.add(Clef(clefType: ClefType.treble));
measure.add(TimeSignature(numerator: 3, denominator: 4));
measure.add(Note(
  pitch: const Pitch(step: 'C', octave: 5),
  duration: const Duration(DurationType.quarter),
));

staff.add(measure);
```

### Clefs

```dart
Clef(clefType: ClefType.treble);
Clef(clefType: ClefType.treble8vb);
Clef(clefType: ClefType.bass);
Clef(clefType: ClefType.alto);
Clef(clefType: ClefType.tenor);
Clef(clefType: ClefType.percussion);
Clef(clefType: ClefType.tab6);
```

### Key Signatures

```dart
KeySignature(0);   // C major / A minor
KeySignature(2);   // D major (2 sharps)
KeySignature(-3);  // E-flat major (3 flats)
```

### Time Signatures

```dart
TimeSignature(numerator: 4, denominator: 4);
TimeSignature(numerator: 3, denominator: 4);
TimeSignature(numerator: 6, denominator: 8);
```

### Barlines

```dart
Barline(type: BarlineType.single);
Barline(type: BarlineType.double);
Barline(type: BarlineType.final_);
Barline(type: BarlineType.repeatForward);
Barline(type: BarlineType.repeatBackward);
Barline(type: BarlineType.repeatBoth);
```

### Chords

```dart
Chord(
  notes: [
    Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.half)),
    Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.half)),
    Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.half)),
  ],
  duration: const Duration(DurationType.half),
);
```

### Ties and Slurs

```dart
Note(
  pitch: const Pitch(step: 'C', octave: 5),
  duration: const Duration(DurationType.half),
  tie: TieType.start,
);

Note(
  pitch: const Pitch(step: 'D', octave: 5),
  duration: const Duration(DurationType.quarter),
  slur: SlurType.start,
);
```

### Articulations

```dart
Note(
  pitch: const Pitch(step: 'G', octave: 4),
  duration: const Duration(DurationType.quarter),
  articulations: [
    ArticulationType.staccato,
    ArticulationType.accent,
    ArticulationType.tenuto,
    ArticulationType.marcato,
  ],
);
```

### Dynamics

```dart
Dynamic(type: DynamicType.piano);
Dynamic(type: DynamicType.mezzoForte);
Dynamic(type: DynamicType.forte);
Dynamic(type: DynamicType.crescendo);
Dynamic(type: DynamicType.diminuendo);
```

### Ornaments

```dart
Ornament(type: OrnamentType.trill);
Ornament(type: OrnamentType.mordent);
Ornament(type: OrnamentType.turn);
Ornament(type: OrnamentType.fermata);
```

### Tempo Marks

```dart
TempoMark(
  bpm: 120,
  beatUnit: DurationType.quarter,
  text: 'Allegro',
);
```

### Grace Notes

```dart
// A grace note is a `Note` with `isGraceNote: true` — it is drawn small and
// contributes 0.0 to the duration the bar counts as filled. There is no
// `GraceNote` class.
Note(
  pitch: const Pitch(step: 'D', octave: 5),
  duration: const Duration(DurationType.eighth),
  isGraceNote: true,
  ornaments: [Ornament(type: OrnamentType.acciaccatura)],
);
```

### Tuplets

```dart
Tuplet(
  actualNotes: 3,
  normalNotes: 2,
  elements: [
    Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.eighth)),
    Note(pitch: const Pitch(step: 'D', octave: 5), duration: const Duration(DurationType.eighth)),
    Note(pitch: const Pitch(step: 'E', octave: 5), duration: const Duration(DurationType.eighth)),
  ],
);
```

### Beams

```dart
Note(
  pitch: const Pitch(step: 'E', octave: 5),
  duration: const Duration(DurationType.eighth),
  beam: BeamType.start,
);
```

### Octave Markings

```dart
// `startMeasure` / `endMeasure` are required: they delimit the span the
// bracket covers, and that span is what displaces the printed pitch of the
// notes inside it.
OctaveMark(type: OctaveType.va8,  startMeasure: 0, endMeasure: 1);  // 8va
OctaveMark(type: OctaveType.vb8,  startMeasure: 0, endMeasure: 1);  // 8vb
OctaveMark(type: OctaveType.va15, startMeasure: 0, endMeasure: 1);  // 15ma
OctaveMark(type: OctaveType.vb15, startMeasure: 0, endMeasure: 1);  // 15mb
OctaveMark(type: OctaveType.va22, startMeasure: 0, endMeasure: 1);  // 22da
OctaveMark(type: OctaveType.vb22, startMeasure: 0, endMeasure: 1);  // 22db
```

### Volta Brackets

```dart
VoltaBracket(number: 1, length: 220);
VoltaBracket(number: 2, length: 180, hasOpenEnd: true);
```

### Polyphony and Multi-Voice

```dart
final measure = MultiVoiceMeasure();

final voice1 = Voice.voice1();
voice1.add(Clef(clefType: ClefType.treble));
voice1.add(TimeSignature(numerator: 4, denominator: 4));
voice1.add(Note(
  pitch: const Pitch(step: 'E', octave: 5),
  duration: const Duration(DurationType.quarter),
));

final voice2 = Voice.voice2();
voice2.add(Note(
  pitch: const Pitch(step: 'C', octave: 4),
  duration: const Duration(DurationType.half),
));

measure.addVoice(voice1);
measure.addVoice(voice2);
```

### Grand Staff, Choir, and Full Scores

`MusicScore` renders a single `Staff`. To render several staves **vertically
stacked and aligned on a shared horizontal grid** — a piano grand staff, an
SATB choir, or a full multi-section score — use the `GrandStaff` widget (one
`StaffGroup`) or `ScoreView` (a whole `Score`).

A `StaffGroup` is a list of staves plus the connector drawn at the left edge:

| `BracketType` | Glyph | Typical use |
| --- | --- | --- |
| `brace`   | `{` (SMuFL `brace`) | Keyboard — piano, organ, harp |
| `bracket` | `[` (SMuFL `bracketTop`/`bracketBottom`) | Choir (SATB), orchestral sections |
| `line`    | `\|` | Multiple desks of the same instrument (Vln I & II) |
| `none`    | — | Independent staves |

```dart
// Piano grand staff: two staves joined by a brace, barlines connected,
// system-spanning start barline drawn automatically.
GrandStaff(
  group: StaffGroup.piano(trebleStaff, bassStaff),
);

// or explicitly:
GrandStaff(
  group: StaffGroup(
    staves: [soprano, alto, tenor, bass],
    bracket: BracketType.bracket, // choir
    name: 'Choir',
  ),
);
```

There are convenience factories for common ensembles: `StaffGroup.piano`,
`.organ`, `.harp`, `.choir`, `.strings`, `.woodwinds`, `.brass`, `.percussion`,
and `.multipleInstruments`.

**Full scores.** A `Score` holds multiple `StaffGroup`s. `ScoreView` lays every
group out on a single unified grid (a true multi-section system):

```dart
final score = Score(staffGroups: [choir, piano]);
ScoreView(score: score);
```

**Multi-system wrapping.** When the music is wider than the available width,
`GrandStaff`/`ScoreView` break into stacked systems automatically, **restating
the clef and key signature at the start of every system** and keeping all staves
aligned on the same break points (ragged-right, Behind-Bars style).

**Cross-staff beaming.** In keyboard music a beamed group can cross between the
two staves. A note keeps its *home* staff (for voicing, beaming, and spacing)
but its notehead is drawn on another staff via `Note.crossStaffMove`:

```dart
Note(
  pitch: const Pitch(step: 'C', octave: 4),
  duration: const Duration(DurationType.eighth),
  beam: BeamType.start,
  crossStaffMove: -1, // draw this notehead one staff up; beam crosses the gap
);
```

`0` = home staff, `-1` = one staff up, `+1` = one staff down. The grand-staff
renderer routes the beam and stems across the staff gap to the displaced
noteheads. Cross-staff beams are also produced automatically on MusicXML import
when a `<staff>` change occurs mid-beam (see
[Import](#import-from-json-musicxml-and-mei)).

### Gregorian Chant (Greciliae)

The library renders Gregorian **square notation** with the Greciliae font (SIL
OFL) — precomposed neume glyphs, *not* shapes assembled from common-music
noteheads. Use the `ChantScore` widget. The fastest path is GABC (the Gregorio
project's plain-text chant format):

```dart
ChantScore.fromGabc(
  '(c4) Ký(h)ri(h)e(hgh) *(,) e(hg)lé(hi)i(h)son.(g) (::)',
);
```

`(c4)` is the clef (do/fa on a staff line), letters are pitches, `(,)`/`(::)`
are divisiones (breath marks / final), and modifiers encode episema, *mora*,
quilisma, liquescence, and compound neumes.

You can also build chant element-by-element with `Neume` / `NeumeDivision` and
render with an explicit clef:

```dart
ChantScore(
  clef: const ChantClef(type: ChantClefType.doClef, line: 4),
  elements: [
    Neume(type: NeumeType.pes, components: [
      NeumeComponent(pitchName: 'F', octave: 3, form: NcForm.punctum),
      NeumeComponent(pitchName: 'G', octave: 3, form: NcForm.virga),
    ]),
    NeumeDivision(type: NeumeDivisionType.minor),
  ],
);
```

Rendering covers: punctum, virga, podatus/clivis, torculus/porrectus,
scandicus/climacus, quilisma, liquescence, compound and repeated neumes,
shape-specific horizontal episema and *mora* glyphs, asymmetric divisio
breathing space, climacus/strophae tucking, and a custos (end-of-line guide)
sized by the leap to the next system. Chant can be sent to MIDI with
`ChantMidiMapper` (see [MIDI](#midi-mapping-and-export)).

### Repeats

```dart
Barline(type: BarlineType.repeatForward);
Barline(type: BarlineType.repeatBackward);
Barline(type: BarlineType.repeatBoth);
```

### Playing Techniques

```dart
PlayingTechnique(type: TechniqueType.pizzicato);
PlayingTechnique(type: TechniqueType.colLegno);
PlayingTechnique(type: TechniqueType.sulTasto);
PlayingTechnique(type: TechniqueType.sulPonticello);
```

### Breath and Caesura

```dart
// `type` is required — there is no default breath mark.
Breath(type: BreathType.comma);
Breath(type: BreathType.caesura);
Breath(type: BreathType.shortCaesura);
```

### Import from JSON, MusicXML, and MEI

```dart
final jsonStaff = JsonMusicParser.parseStaff(jsonString);
final musicXmlStaff = MusicXMLParser.parseMusicXML(musicXmlString);
final meiStaff = MEIParser.parseMEI(meiString);

final autoDetected = NotationParser.parseStaff(sourceString);
```

### MIDI Mapping and Export

```dart
import 'dart:io';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/midi.dart';

Future<void> exportMidi(Staff staff) async {
  final sequence = MidiMapper.fromStaff(
    staff,
    options: const MidiGenerationOptions(
      ticksPerQuarter: 960,
      defaultBpm: 120,
      includeMetronome: true,
    ),
  );

  final bytes = MidiFileWriter.write(sequence);
  await File('score.mid').writeAsBytes(bytes, flush: true);
}
```

Native integration APIs:

- `MidiNativeAudioBackend`
- `MethodChannelMidiNativeAudioBackend`
- `MidiNativeSequenceBridge`

**Playing part of a score.** A track can be emitted per staff and, since 2.7.0,
per voice — so a single voice can be soloed or muted:

```dart
final sequence = MidiMapper.fromStaff(
  staff,
  options: const MidiGenerationOptions(
    separateTracksPerVoice: true,   // one track per (staff, voice)
    soloVoices: {2},                // hear only the inner voice
    // mutedVoices: {2},            // ...or silence it (solo wins over mute)
    // soloStaves: {0}, mutedStaves: {1},
  ),
);
```

Before 2.7.0 every voice of a staff shared one track and one channel, so neither
mute nor solo was possible.

### Selection and Hit-Testing

`ScoreHitTester` turns a laid-out score into something a user can point at. It
returns **your own model objects**, not copies — which is why editing and
highlighting work:

```dart
final engine = LayoutEngine(
  staff, availableWidth: width, staffSpace: 12, metadata: metadata);
final elements = engine.layout();

final tester = ScoreHitTester(
  elements: elements, staffSpace: 12, engine: engine);

// Point
final hit = tester.hitTest(localPosition);
if (hit != null) {
  print('${hit.element.runtimeType} in bar ${hit.measureIndex}, '
        'voice ${hit.voiceNumber}, onset ${hit.onset}');
}

// Region (marquee), with a playable time range
final selection = tester.selectionFromRect(dragRect);
print('bars ${selection.firstMeasure}..${selection.lastMeasure}, '
      'onsets ${selection.startOnset}..${selection.endOnset}');

// Structural
tester.selectMeasure(3);
tester.selectSystem(0);
tester.selectVoice(2);
tester.selectTimeRange(0.25, 0.75);

// Caret placement / play-from-here
final where = tester.timeAt(localPosition);
```

Every `PositionedElement` carries `onset` (musical time in whole notes from the
start of the staff) and `measureIndex`, which is what makes all of the above —
and cross-staff alignment — possible.

### Measure Numbers

Measure numbers are engraved at the start of every system (bar 1 is not
numbered), following Gould. `Measure.number` wins when set, otherwise the
1-based position is used:

```dart
MusicScore(
  staff: staff,
  theme: const MusicScoreTheme(
    showMeasureNumbers: true,                       // default
    measureNumberTextStyle: TextStyle(fontSize: 10),
  ),
)
```

### Using a Different SMuFL Font

Nothing in the engine is Bravura-specific: every metric comes from the SMuFL
metadata. Point the loader at another SMuFL font and register its family:

```dart
const petaluma = SmuflFontDescriptor(
  fontFamily: 'Petaluma',
  metadataAsset: 'assets/petaluma/petaluma_metadata.json',
  glyphNamesAsset: 'assets/petaluma/glyphnames.json',
);

final metadata = SmuflMetadata.forFont(petaluma);
await metadata.load();
```

`SmuflMetadata()` still returns the shared Bravura instance, so existing code is
unchanged.

### Themes and Styling

```dart
MusicScore(
  staff: staff,
  theme: const MusicScoreTheme(
    staffLineColor: Colors.black,
    noteheadColor: Colors.black,
    stemColor: Colors.black,
    clefColor: Colors.black,
    barlineColor: Colors.black,
    dynamicColor: Colors.black,
    tieColor: Colors.black,
    slurColor: Colors.black,
    textColor: Colors.black,
  ),
)
```

---

## Reference JSON Format

```json
{
  "measures": [
    {
      "clef": "treble",
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "keySignature": 0,
      "elements": [
        { "type": "note", "step": "C", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "E", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "G", "octave": 5, "duration": "quarter" },
        { "type": "rest", "duration": "quarter" }
      ]
    }
  ]
}
```

---

## Architecture

```text
flutter_notemus/
├── lib/
│   ├── flutter_notemus.dart        # Public entry point
│   ├── midi.dart                   # Public MIDI entry point
│   ├── core/                       # Music model
│   └── src/
│       ├── midi/                   # MIDI mapping/export/native bridge
│       ├── layout/                 # Layout and spacing
│       ├── rendering/              # Renderers and positioning
│       ├── smufl/                  # Metadata and glyph references
│       ├── parsers/                # JSON, MusicXML, MEI parsers
│       └── theme/                  # Theme and style system
├── assets/smufl/                   # Bravura + metadata
├── android/ios/macos/linux/windows # Plugin/native targets
└── example/                        # Demo application
```

Rendering flow:

```text
Staff/Score -> LayoutEngine -> PositionedElements -> StaffRenderer -> Canvas
```

The arrow only points right. A layout decision is a **value owned by the layout
result**, never a write back onto your model
([ADR-005](doc/adr/ADR-005-layout-decisions-are-values.md)): beam membership is
published as `LayoutEngine.beams` / `LayoutEngine.tupletBeams` and read through
`LayoutEngine.beamOf(note)`. `Note.beam` is an INPUT hint you may set yourself;
since 2.7.0 the engine never overwrites it, so `staffToMusicXML` and
`staffToJson` return the same bytes whether or not the score has been laid out
or painted.

Decision records:

| ADR | Decision |
|---|---|
| [ADR-001](doc/adr/ADR-001-layout-never-clones-the-model.md) | The layout never clones or replaces a model object |
| [ADR-002](doc/adr/ADR-002-shared-musical-time-grid.md) | Staves are aligned on a shared musical time grid |
| [ADR-003](doc/adr/ADR-003-pitch-is-the-sounding-pitch.md) | `Pitch` is the sounding pitch |
| [ADR-004](doc/adr/ADR-004-opening-block-is-a-convention.md) | A measure's opening block is a convention; the body keeps document order |
| [ADR-005](doc/adr/ADR-005-layout-decisions-are-values.md) | A layout decision is a value, never a mutation of the model (partially supersedes ADR-001) |

---

## Development Checklist

Typical local validation:

```bash
dart analyze
flutter test
flutter pub publish --dry-run
```

---

## License

- Project code: Apache License 2.0 (`LICENSE`)
- Third-party assets and references: `THIRD_PARTY_LICENSES.md`
