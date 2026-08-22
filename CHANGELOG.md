# Changelog

All notable changes to Flutter Notemus are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [2.7.0] - 2026-08-21

**Audit-remediation release.** An adversarial forensic audit of 2.6.0
(`doc/AUDITORIA_FORENSE_2026-08-21.md`) executed the engine against 40+ probe
cases and catalogued 42 findings, eight of them P1. This release fixes them.
Several are **corrections of previously wrong output**, so scores will render
differently — deliberately: **39 of the 52 existing goldens** were re-baselined
on purpose (plus one new case for rehearsal marks, 53 in total). The reasons
are listed under *Engraving* below.

Two decisions were structural enough to get their own records:
[ADR-001](doc/adr/ADR-001-layout-never-clones-the-model.md) (the layout never
clones model objects) and
[ADR-002](doc/adr/ADR-002-shared-musical-time-grid.md) (multi-staff alignment
runs on a shared musical time grid).

### Fixed — engraving correctness

- **Compound meters beamed wrongly (F-03).** 3/8, 6/8, 9/8 and 12/8 grouped the
  beat-completing note into the *next* group and left the last note of the bar
  orphaned with a flag: 6/8 produced `2 + 3 + 1` instead of `3 + 3`. The three
  duplicated grouping paths (`_groupSimpleTime`, `_groupCompoundTime`,
  `_groupIrregularTime`) are now one subdivision-driven walker keyed on where a
  note *starts*, so a fix cannot be applied to one path and forgotten in its
  twin — which is exactly how this bug survived: the simple-meter path had
  already been corrected.
- **A mid-measure clef change moved every note in its bar (F-01).** System
  elements were hoisted to the head of the measure, so the cursor had already
  adopted the *last* clef of the bar before any note was placed. In
  `[treble, C4, bass, C4]` both C4s were drawn at the bass position — a twelfth
  off for the first. Clef, key and meter changes now stay in document order and
  render at cue size.
- **Beamed notes lost the Behind Bars accidental rule (F-02).** Four F♯ eighths
  printed four sharps; the same four as quarters printed one. The engine was
  rebuilding beamed notes, which broke every identity-keyed map. It no longer
  clones anything (ADR-001).
- **Rhythmic spacing inverted outside quarter…64th (F-11).** The factor table
  covered 7 of 15 duration types and fell back to `1.0`, so a breve was spaced
  like a quarter — *narrower than a whole note* — and a 128th took 2.3× the
  space of a 64th. Spacing is now computed as `sqrt(duration / quarter)` over
  all 15 types, and includes augmentation dots.
- **Grand-staff hands did not line up (F-04).** Four quarters against two halves
  put beat 3 **38.1 px apart** (>3 staff spaces). Staves are aligned on musical
  onsets carried by every positioned element (ADR-002).
- **Stems inside beam groups fell below the minimum (F-14).** The beam was
  placed from the average of the first and last note only; E4+F5 as eighths gave
  the F5 a **1.75 staff-space** stem (minimum 2.5, standard 3.5). Beam geometry
  now fits the slope, then shifts the whole line until every stem in the group
  clears the minimum.
- **Lyrics claimed no horizontal space (F-15).** A 15-character syllable
  produced exactly the same spacing as no lyric at all, so long syllables simply
  overlapped the next note. Syllable width is now reserved on both sides.
- **Courtesy and editorial accidentals were discarded (F-16).** A note marked
  cautionary whose alteration was already in force resolved to *hide*. They are
  now always shown — and, for the first time, actually **drawn** with SMuFL
  parentheses/brackets.
- **Double-flat width was unreachable dead code (F-27).** Branch order made
  `accidentalDoubleFlat` match the plain-flat test, reserving 1.18 instead of
  Bravura's 1.652, so double flats collided with the previous note. Naturals
  were hardcoded at 0.92 against a real 0.672. Accidental widths now come
  straight from the loaded metadata.
- **Justification stretched the clef/key block (F-13)** and left any system
  under 70% fill ragged *in the middle of the piece*. Only the region from the
  first rhythmic event is elastic now, and every system but the last is
  justified.
- **Cross-voice collisions were matched on rounded pixels (F-30).** Voices
  aligned by interpolation landed on 123.4 and 123.6, rounded to different keys,
  and the collision went unresolved. Grouping is by musical onset.
- **Chords and nested tuplets inside a tuplet were not drawn at all.** Neither
  had a branch in the tuplet renderer's loop — silent loss of music, found while
  fixing F-25.

### Fixed — data loss

- **Reusing one `Note` instance dropped notes (F-08).** Three identical
  instances in a bar rendered as one. The de-duplication set is gone.
- **`TupletRenderer` rebuilt tuplet notes** with a copy constructor that omitted
  `syllables`, `isGraceNote`, `alternatePitch`, `tabFret`, `tabString`,
  `accidentalParenthesis`, `slurs`, `crossStaffMove`, `tremoloStrokes` and
  `xmlId` — lyrics and tab numbers vanished for any note inside a tuplet.
- **MusicXML `<divisions>`/`<duration>` were ignored on import (F-06).** A whole
  note written as `<duration>16</duration>` with `divisions=4` and no `<type>`
  imported as a **quarter**. Duration now derives from divisions when `<type>`
  is absent, undoing `<time-modification>` first.
- **MusicXML `<backup>`/`<forward>` were no-ops (F-07).** Two voices without
  explicit `<voice>` tags collapsed end-to-end: a 4/4 bar reached the model
  carrying 2.0 of value. A `<forward>` gap shifted every following onset.
- **MEI read only the first `<section>` (F-17).** The rest of the piece
  disappeared without a warning.
- **MusicXML export dropped** dynamics, tremolo, `voice` in single-voice
  measures, explicit `Measure.number`, cautionary accidentals, cross-staff
  routing, playing techniques, chord-level dynamics/articulations/ornaments,
  `<sound tempo>` and non-5-line staves. All are now emitted.

### Fixed — robustness and security

- **Invalid input crashed with an internal error (F-10).** `<step>H</step>`
  reached the model and blew up later as
  `_TypeError: Null check operator used on a null value`, while the layout
  silently drew it as a C. Parsers now reject invalid steps and out-of-range
  octaves with a `FormatException` naming the element; `Pitch` validates in
  debug and throws a descriptive `StateError` instead of a null-check crash.
  A new fuzz suite pins the contract.
- **A dense bar was clipped and unreachable (F-05).** 32 sixteenths on a 400 px
  line reached x = 1222 px inside a canvas pinned to the viewport, wrapped in a
  horizontal scroll view that could never scroll. Measures are compressed to fit
  (down to a collision floor), and whatever still overflows now sizes a genuinely
  scrollable canvas. `LayoutEngine.contentWidth` / `overflowsAvailableWidth`
  report it.
- **Scores past 1000 systems went blank (F-22).** The painter clamped visible
  systems to `0..999`; a 4000-measure score produced 4000 systems.

### Fixed — API and determinism

- **The layout signature was not deterministic (F-02b).** The same `Staff` laid
  out three times produced three different signatures, so `shouldRepaint` was
  permanently true and viewport culling saved nothing. It is structural now.
- **`noteXPositions` returned `null` for beamed notes** — the documented public
  API was unusable for its stated purpose.
- **`PitchUtils.intervalInSemitones` double-counted the alteration (F-19):**
  C4→C♯4 returned 2.0, C4→E♭4 returned 2.0.
- **`Pitch.fromString('C-1')` silently returned C1** (MIDI 24 instead of 0).
- **`Pitch ==` compared raw `alter`**, so two spellings of F♯4 were unequal.
  **`Duration` had no `==`/`hashCode`** at all.
- **`Measure.add` rejected legitimate polyphony (F-09).** Capacity summed every
  voice together, while the package's own parsers bypassed the check entirely.
  It is voice-aware; `MultiVoiceMeasure` overrides the inherited accessors that
  used to report nonsense for it.
- **`MeasureValidator` failed every polyphonic bar** and its result was thrown
  away; it is voice-aware and now reports actionable problems.
- **Octave-transposing clefs were ignored by playback (F-24).** The written/
  sounding convention is documented and applied.

### Fixed — found by the review of this very release

The remediation was itself reviewed adversarially before shipping. These were
found in the new code:

- **The PDF exporter reintroduced the clipping it was supposed to fix.**
  `ScoreRasterizer` sized every page as an exact multiple of a system band, so a
  high ledger-line note or a boxed rehearsal mark was cut off the top of page 1 —
  the on-screen fix had not been mirrored.
- **`Tuplet.totalDuration` read only the first note** and multiplied by
  `actualNotes`. A 3:2 triplet of eighth + quarter + eighth was measured as three
  eighths, and a triplet made only of rests or chords returned **0.0** — so every
  musical onset after it shifted, taking cross-staff alignment and
  selection-by-time with it.
- **`IntelligentSpacingEngine` was still not on the production path.** It had
  gained the API and was still only *constructed*. It is now what
  `_calculateRhythmicSpacing` calls, which also switched the optical compensator
  on — that is why more goldens moved than the engraving fixes alone explain.
- **The grand staff mutated the caller's `Measure.number`** to keep bar
  numbering across a system split, which also numbered an anacrusis as bar 1.
  Replaced by `LayoutEngine.measureNumberOffset`.
- **`ChantClefChange` was returned by the public GABC parser but not exported**,
  so callers could not name the type.
- **Anything above or below the staff was clipped** — the canvas reserved a flat
  margin regardless of content. A C9 in treble clef sat at y = −114 on a canvas
  192 px tall. `LayoutEngine.contentTopOverflow` / `contentBottomOverflow` now
  measure the real reach, and the painter, the widget, the grand staff and the
  PDF all reserve it.

### Added

- **Rehearsal marks are engraved.** `TextType.rehearsal` had been imported from
  MusicXML since 2.x and fell through the default branch of every text switch —
  modelled, never drawn. They now render upright, bold and boxed (SMuFL
  `textEnclosureThickness`), above everything else on the staff.
- **`ScoreHitTester`** — hit-testing and selection by point, region, measure,
  system, voice and time range, plus `timeAt()` for placing a caret. This was
  the capability the audit scored 2/10 and named as blocked; it became possible
  only because the layout stopped replacing model objects.
- **Measure numbers** are rendered at the start of every system
  (`MusicScoreTheme.showMeasureNumbers`, `measureNumberTextStyle`).
  `Measure.number` had existed in the model since 2.x and nothing ever drew it.
- **Per-voice playback control** — `MidiGenerationOptions.separateTracksPerVoice`,
  `mutedVoices`, `soloVoices`, `mutedStaves`, `soloStaves`. Both voices of a bar
  previously shared one track and one channel, so nothing could be soloed.
- **Real PDF export** — the exporter rasterizes the actual engraving instead of
  emitting placeholder pages (`// TODO: Implement actual music rendering`).
- **A different SMuFL font can be loaded** — `SmuflFontDescriptor` and
  `SmuflMetadata.forFont()`; no renderer names Bravura literally any more.
- **`PositionedElement.onset` and `.measureIndex`** — the shared musical time
  coordinate, and the bar an element belongs to.
- **`LayoutEngine.contentWidth`, `overflowsAvailableWidth`, `measureNumbers`,
  `elementWidth`.**
- **Layout memoization** — the engine no longer re-runs on every widget build
  (it ran up to twice per build, ~82 ms per pass at 800 measures).
- **`TextPainter` caching** in the glyph renderer.
- **MEI import gaps closed** — `@mode` → `KeyMode`, additive meters
  (`meter.count="3+2+2"`, `<meterSigGrp>`), `@tab.fret`/`@tab.string`,
  `<meiHead>` via the new `MEIParser.scoreFromMei`, and `<ending>` →
  `VoltaBracket`.
- **MusicXML import gaps closed** — `<transpose>`, `<unpitched>` (percussion
  notes were being discarded silently), `<sound tempo>` and
  `<staff-details><staff-lines>`.

### Performance

Measured on the same machine, before and after:

| | 2.6.0 | 2.7.0 |
|---|---|---|
| layout, 800 measures | ~82 ms | ~87 ms |
| layout, 1600 measures | — | ~138 ms (still linear) |
| paint, 50 measures | ~24 ms | ~12 ms |
| paint, 800 measures | ~26 ms | ~12 ms (flat) |

Layout absorbed the dry-run width measurement without changing shape. Paint
stopped scaling with score size — it used to rebuild the system grouping and
every renderer on each frame — and now fits inside the 16.7 ms frame budget.

### Changed

- `Voice.getHorizontalOffset` follows Behind Bars: voices pair by stem direction
  (1 and 3 share the stem-up column, 2 and 4 the stem-down one) instead of
  stacking 0.6 staff spaces per voice, which put voice 4 a full 1.8 SS to the
  right of voice 1.
- `LayoutEngine.barlineSeparation` → `barlineTrailingSpace`. The old name
  collided with SMuFL's `barlineSeparation` (0.4), which means something else
  entirely; the alias remains, deprecated.
- The Gregorian renderer derives its vertical metrics from the shipped
  `greciliae.ttf` instead of a hardcoded 147 units per diatonic step. The font
  actually uses ~157.5, a 7.1% error that accumulated with the ambitus.
- Mass find/replace damage in comments and public dartdoc (`notetion`,
  `Definesss`, `paUses`, `calculateTeste`, plus double-encoded mojibake) was
  swept from `lib/` — this text was being published to pub.dev.

### Testing

- **New invariant suites** (`test/invariants/`) encoding the properties the
  audit found unguarded: nothing drawn past the line, every model note reaches
  the layout, geometry keyed on the caller's objects, deterministic signatures,
  minimum stem length, monotonic spacing across all 15 duration types, shared
  onsets across staves, no notehead overlap, round-trip fidelity, and MIDI
  timeline duration.
- **`test/interaction/`** — selection and hit-testing, including that a hit
  returns the caller's own object.
- **`test/gregorian/`** — Greciliae calibration checked against the shipped font.
- **`test/fuzz/`** — malformed MusicXML/MEI/JSON must fail with a domain
  exception, never a `TypeError`, never a hang.
- `test/spacing_test.dart` no longer tests an engine that never ran.

## [2.6.0] - 2026-06-19

A large engraving release: **multi-staff / grand-staff rendering** (the library
is no longer single-staff), **cross-staff beaming**, a sweep of Behind-Bars CMN
corrections, deeper MusicXML/MEI import, and Gregorian chant render-fidelity
work. All additions are backward-compatible (new widgets, model fields, and
parser paths); existing single-staff `MusicScore` usage is unchanged.

### Added — multi-staff & score rendering

- `GrandStaff` widget and `GrandStaffPainter`: render a `StaffGroup` (piano
  grand staff, SATB choir, N-staff systems) on a shared horizontal grid, with
  the SMuFL `brace` and `bracketTop`/`bracketBottom` glyphs, a system-start
  barline joining the staves, continuous per-measure system barlines, and
  vertically-aligned noteheads.
- `ScoreView` widget: render a whole `Score` (multiple `StaffGroup`s) on one
  unified grid — a full multi-section/orchestral system.
- **Multi-system wrapping** for the grand staff: long groups wrap into stacked
  systems with shared break points and the clef + key restated each system.
- **Cross-staff beaming**: a beamed voice can straddle two staves
  (`Note.crossStaffMove`); the beam is drawn between the staves with stems
  reaching it.
- MusicXML import → `Score`: each part becomes a `StaffGroup` (multi-staff
  parts are braced as a grand staff); `<part-group>`/`<group-symbol>` spans are
  imported as section brackets; a beam that changes `<staff>` mid-group is kept
  on its home staff with an automatic cross-staff move.

### Added — common-music notation

- Cautionary (parenthesised) and editorial (bracketed) accidentals
  (`Note.accidentalParenthesis`), imported and exported via MusicXML.
- Nested / overlapping slurs with numbered identity (`SlurEvent`,
  `Note.slurs`), matched by number and arched concentrically; MusicXML
  `<slur number=>` import.
- Additive meters (e.g. `3+2+2`) rendered with `timeSigPlus`; free-time
  (senza misura) draws no glyph.
- Tuplet ratios (`a:b`) and multi-digit tuplet numbers; sloped tuplet brackets.
- Chord-level articulations; ledger lines from SMuFL metadata; heavy-light /
  heavy-heavy barlines with the correct glyphs.

### Changed — engraving (Behind Bars)

- Chord stem direction corrected (was inverted).
- Inter-note spacing now uses the Gould square-root law keyed to the previous
  note's duration (inter-onset), with augmentation-dot and cancellation-natural
  widths reserved; rests use ~0.8× spacing.
- Mid-system clef/key/time changes now render (and clef changes draw at cue
  size); the last/underfull system is no longer stretched.
- Cross-voice second/unison noteheads are displaced so they no longer overlap;
  chord ties fan outward; a lone full-measure rest is centred; marcato always
  sits above the note.
- Hairpins span to the next dynamic/barline.

### Changed — Gregorian chant

- Horizontal episema and augmentum (mora) dot rendered with the Greciliae
  `HEpisema*` / `AuctumMora` glyphs (shape-specific episema for virga/quilisma);
  asymmetric breathing space around divisiones; climacus inclinata and repeated
  same-pitch strophae tucked into single neumes; custos length by leap distance.

### Fixed

- Brace/bracket no longer overlaps the staff; the orchestral bracket uses the
  Bravura serif glyphs instead of drawn tips; beam-processing no longer drops
  newly added note fields.

### Added — engraving & typography correctness pass (Issues #3, #4, #5, #8, #9, #12)

This release also consolidates the earlier engraving/typographic correctness
work that had not yet been published to pub.dev:

- SMuFL `brace` glyph workflow for staff-group braces: `BracketRenderer` renders
  the scalable `brace` glyph (vertically stretched to the group height) when
  SMuFL metadata is available, with the previous custom cubic path kept as an
  automatic fallback (Issue #3).
- Robust `repeatBoth` barline rendering: uses the combined `repeatLeftRight`
  glyph when present, otherwise composes `repeatRight` + `repeatLeft` using
  SMuFL advance metrics and the `barlineSeparation` engraving default (Issue #5).
- `NoteRenderer.renderSyllables` is now public and reused by `ChordRenderer`, so
  chords render `Note.syllables` with the same typography as single notes; new
  `ChordRenderer.lyricNoteFor` selects the chord's lyric note (Issue #12).
- Stem and flag attachment derived from the SMuFL stem anchor plus half the
  `stemThickness` engraving default, scaled by `staffSpace`; the hardcoded
  raw-pixel offset constants were removed so single-note stems use the same
  `SMuFLPositioningEngine` path as chords (Issue #4).
- `SystemData.getShortestNoteDuration` accounts for `Chord` and `Tuplet`
  (applying the tuplet ratio, recursively for nested tuplets), and
  `TimeSlice.getMaxWidth` no longer returns a constant placeholder (Issue #9).
- Removed a misleading dead `// TODO` in `MeasureValidator` referencing a
  `Duration.tuplet` field that never existed (Issue #8).
- Regression suites for spacing/duration of chords & tuplets, tuplet measure
  validation, stem/flag scaling, repeat barlines, the brace glyph, and chord
  lyrics.

### Known limitations

- **Jianpu (numbered notation) is a work in progress / experimental.** Basic
  rendering from the model is available and shown in the example gallery, but
  coverage is partial and the API may still change — it is not yet considered
  production-ready.
- Inter-note hyphen centering (Issue #14) and melisma extension lines
  (Issue #13) remain open: both require relocating syllable rendering into a
  post-layout pass, deferred to avoid regressing currently-working lyric
  rendering.

## [2.5.1] - 2026-03-29

This release finishes the pub.dev polish pass for engraving quality, showcase coverage, release documentation, and codebase hygiene.

### Added

- A curated Cupertino-based example gallery with restored public demos for grace notes, slurs/ties, lyrics/text, tuplets, octave marks, ornaments, and articulation coverage.
- New regression tests for chord slur/tie grouping, articulation helpers, tuplet rest centering, SMuFL positioning, and the example app smoke suite.
- GitHub roadmap issues for styling/theming, editable score workflows, score hit-testing, real-time interactivity, and production-ready MIDI/audio support.
- CI workflow (`.github/workflows/ci.yml`) that runs `flutter analyze`, `flutter test`, and `flutter pub publish --dry-run` on every push and pull request.

### Changed

- `MusicScorePainter.shouldRepaint` continues to use a deterministic layout signature, and `LayoutEngine.layoutWithSignature()` remains the compatibility-safe path for signature-aware layout.
- Example score previews now use a white canvas, independent scroll controllers, explicit Cupertino icon font loading, larger default typography, and vertically centered score content in bounded cards.
- Example score previews no longer shrink responsively by default, improving beam, lyric, grace-note, and octave-mark legibility in the public gallery.
- All source comments and documentation strings migrated to English throughout the entire codebase (library, tests, and examples).

### Fixed

- Slurs, ties, and grace-note ligatures now route on the stem-free side of the notehead, including chord-aware tie grouping and grace-note entry geometry.
- Tuplet brackets and numbers keep better clearance from note/beam fields, and mixed tuplets now center internal rests on the rhythmic slot instead of drifting left.
- Arpeggio signs sit closer to chord noteheads and octave-mark examples keep the ottava text, dashed span, and hook inside the preview area.
- Beaming processing preserves complete note metadata during layout, including lyric syllables and auxiliary note properties required by downstream renderers/parsers.
- Articulation placement follows the effective stem direction, which keeps tenuto/accent placement consistent even when notes are beamed or voice-driven.
- Preserved `voiceNumber` context during horizontal justification so multi-voice rendering remains consistent after system expansion.
- Stabilized spacing model behavior and adaptive expansion blend to reduce subtle density drift in existing scores.
- Resolved garbled UTF-8 characters in source comments across all affected files (Issue #11 closed).
- Extracted duplicate stem X-offset constants in `BeamRenderer` into a single `_stemXOffset()` helper, eliminating the repeated inline definition.

## [2.5.0] - 2026-03-23

### Added

- **MEI v5 100% conformance**: full coverage of Music Encoding Initiative v5 specification.
  - `Space` and `MeasureSpace` classes (MEI `<space>` and `<mSpace>`).
  - `FiguredBass` and `FigureElement` classes (MEI `<fb>/<f>`).
  - `HarmonicAnalysis`, `ChordTable`, `HarmonicLabel` classes (MEI `<harm>`, `intm`, `mfunc`, `deg`, `inth`, `pclass`).
  - `MeiHeader` with full FRBR model (Work/Expression/Manifestation/Item levels).
  - `ScoreDefinition` class (MEI `<scoreDef>`).
  - `MensuralNote`, `MensuralRest`, `Ligature`, `Mensur`, `ProportMark` (MEI Mensural repertoire).
  - `Neume`, `NeumeComponent`, `NeumeDivision` (MEI Neume notation).
  - `TabNote`, `TabGrp`, `TabTuning` with standard guitar/bass/ukulele tunings (MEI Tablature).
- `DurationType` extended with historical values (`maxima`, `long`, `breve`) and ultra-short values up to `twoThousandFortyEighth` (2048th note).
- `DurationType.meiDurValue` getter and `DurationType.fromMeiValue()` for MEI serialization.
- `Pitch.pitchClass` getter (0–11, MEI `pclass`) and `Pitch.solmizationName` / `Pitch.fromSolmization()`.
- `KeyMode` enum (major, minor, dorian, phrygian, lydian, mixolydian, aeolian, locrian, none).
- `TimeSignature.free()` and `TimeSignature.additive()` constructors for MEI `<meterSig>` variants.
- `Syllable` and `Verse` classes for MEI `<syl>` / `<verse>` lyric encoding.
- `Staff.lineCount` parameter for non-standard staves (MEI `<staffDef @lines>`).
- `Measure.number` field (MEI `<measure @n>`).
- `Note.tabFret` / `Note.tabString` fields for tablature notation.
- `MusicalElement.xmlId` field for MEI `xml:id` cross-referencing.
- MEI v5 badge and conformance section added to README.
- Audit document `doc/MEI_V5_AUDIT.md` documenting 100% coverage across 30 categories.
- GitHub issues #7, #8, #9 tracking remaining implementation work.

### Fixed

- All `avoid_print` warnings in example files replaced with `debugPrint`.
- Deprecated `Tuplet.showBracket`/`showNumber` usages replaced with `bracketConfig`/`numberConfig` in examples.
- `deprecated_member_use` (`withOpacity`) replaced with `withValues(alpha:)` in example files.
- `implementation_imports` and `unnecessary_import` warnings resolved in JSON example files.
- `prefer_const_constructors` warnings resolved across example files.
- Non-exhaustive switch expressions in `BeamAnalyzer._getDurationValue()` and `MusicXMLParser._durationTypeToString()` fixed after `DurationType` enum expansion.

## [2.2.1] - 2026-03-23

### Fixed

- Replaced `LICENSE` content with canonical Apache-2.0 text so pub.dev can recognize an OSI-approved license.
- Moved third-party license attributions to `THIRD_PARTY_LICENSES.md`.

## [2.2.0] - 2026-03-23

### Changed

- Translated example app UI texts to English across example pages and labels.
- Added web plugin support entry with `FlutterNotemusWeb`.
- Added Swift Package Manager manifests and source targets for iOS and macOS plugin integration.
- Normalized license metadata and Apache-2.0 declaration in `pubspec.yaml`.

## [2.1.0] - 2026-03-23

### Changed

- Migrated README content to English across all sections.
- Reorganized README with project links at the top.
- Kept backlog references and project links aligned with GitHub and GitHub Pages.

## [2.0.2] - 2026-03-23

### Fixed

- Restored the complete README content for GitHub and pub.dev package page.
- Added project links section with GitHub, pub.dev, and GitHub Pages URL.
- Added explicit open-pending issues section with links to tracked implementation gaps.

## [2.0.1] - 2026-03-23

### Added

- Public backlog tracking document: `doc/OPEN_ISSUES.md`
- GitHub issue backlog for pending implementation gaps:
  - #1 Native audio backend for iOS/macOS/Linux/Windows
  - #2 Real notation engraving for PDF export
  - #3 SMuFL brace integration for staff groups
  - #4 Stem/flag primitive parameterization
  - #5 `repeatBoth` robust glyph fallback

### Changed

- README fully rewritten and normalized (clean structure, setup, examples, status)
- Project status documentation now clearly separates stable features vs pending areas

## [2.0.0] - 2026-03-23

### Added

- First-party MIDI module exposed via `package:flutter_notemus/midi.dart`
- `MidiMapper.fromStaff` and `MidiMapper.fromScore`
- Repeat expansion (`repeatForward`, `repeatBackward`, `repeatBoth`) with volta filtering
- Tuplet, polyphony, and tie-aware event generation
- Metronome track generation synchronized with expanded playback timeline
- Standard MIDI file writer (`MidiFileWriter`)
- Native backend contract (`MidiNativeAudioBackend`)
- MethodChannel backend (`MethodChannelMidiNativeAudioBackend`)
- Native sequence bridge (`MidiNativeSequenceBridge`)
- PPQ sync API (`setTicksPerQuarter`)
- Android native plugin implementation (Kotlin + C++)
- Plugin channel setup for iOS, macOS, Linux, and Windows
- Unit tests for MIDI mapping and export

### Changed

- Public API includes MIDI exports via `flutter_notemus.dart` and `midi.dart`
- Native backend state documented (Android active, other platforms stubbed)

## [0.1.0] - 2025-11-04

### Added

- Initial public release on pub.dev
- SMuFL rendering pipeline with Bravura font support
- Core notation model and rendering primitives
- Basic examples and documentation
