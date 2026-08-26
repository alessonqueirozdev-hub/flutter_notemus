# Changelog

All notable changes to Flutter Notemus are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

## [2.7.0] - 2026-08-26

The first release published to pub.dev since 2.6.0. **Three internal milestones
were tagged in git between them and never published**; they are folded in below,
newest first, with their original headings kept as subsections so nothing about
what changed when is lost.

Read it as one release if you are upgrading from 2.6.0 — that is the only jump
this file describes. Read the subsections if you want to know which audit found
what.

One naming note, so the engineering record and the published record can be
reconciled: the documents in `doc/` — the forensic audits, the reconciliation,
and ADR-005 — call the newest milestone **2.8.0**, because that is the number it
carried while it was being built. Same code, same measurements, same commits;
only the published version number differs, and it differs because pub.dev had
never seen 2.7.0.


### Milestone: the reconciled 2.7.1 audit — 50 findings, plus 3 at sign-off  *(tagged in git as 2.8.0 while in development; never published)*

A second adversarial re-audit of 2.7.1 — again by executing the engine, not by
reading it — was reconciled into a single defect list and remediated in five
waves. Everything below was MEASURED before and after; where a number is a
count, it is the count the probe printed, and a final documentation pass
re-probed every claim on this page against the integrated tree before it was
allowed to stand.

The fifth wave exists because four of the findings had been *diagnosed* in a
report by an earlier wave and never *applied* — including the worst of them,
cross-staff beams silently not being drawn, which two independent waves each
wrote the correct patch for into a notes field that nothing executes. Every one
of those four is closed here, and each has a test in
`test/invariants/w5_leftovers_test.dart` that fails with the broken number
rather than with an anonymous mismatch.

This is a PATCH release by version number and a BREAKING one by output: beam
band thickness, tuplet spacing, tuplet bracket thickness and grand-staff
pagination all change what a correct score looks like, so the pixel goldens
those changes move are re-recorded in this release. No public API was removed. One behaviour change is worth calling
out at the top: **`LayoutEngine.layout()` no longer writes `Note.beam`**. Read
the effective beam through `LayoutEngine.beamOf(note)`; `Note.beam` is now an
INPUT hint only. See
[ADR-005](doc/adr/ADR-005-layout-decisions-are-values.md).

#### Beaming

- **`LayoutEngine.beamOf(note)` now consults `tupletBeams` as well as `beams`.**
  It did not, which meant the method documented as *the only supported read*
  returned `null` for exactly the notes `tupletBeams` exists to describe.
  Measured on a 3:2 triplet of eighths after `layout()`: `beams[first]` `null`,
  `tupletBeams[first]` `BeamType.start`, `beamOf(first)` **`null`**. Nothing
  looked broken only because `TupletRenderer` reads `tupletBeams` directly;
  every other caller got the wrong answer, and the visible consequence was that
  `TupletBracket.shouldShow(notes, beamOf: engine.beamOf)` returned `true` — a
  bracket printed over a fully beamed triplet, against Behind Bars p.201, from
  the very API added this release to prevent that. The two maps are disjoint by
  construction (`beams` walks measure/voice elements, `tupletBeams` walks only
  `Tuplet` children), so no note outside a tuplet changes answer; the full suite
  and all 53 goldens are unchanged. Found and fixed at the closing sign-off,
  after two earlier passes had each written the one-line patch into a report
  without applying it.
- **A beam decision is a VALUE the layout publishes, not a mutation of your
  model.** `LayoutEngine.layout()` used to write the answer onto the caller's
  own [Note] objects (`note.beam = ...`), and `TupletRenderer` used to write it
  again DURING PAINT. Two consequences were measured. First, the export a user
  got depended on whether the score had been displayed: the same `Staff` of two
  bars of loose quavers exported **3 349 characters with 0 `<beam>` tags before
  and 3 973 characters with 16 `<beam>` tags after**, and on a mixed fixture
  (a 3/4 bar of six quavers plus a bar holding one triplet) the two stamps land
  separately — **3 284 characters / 6 `<beam>` tags after the layout stamp,
  3 399 / 9 after the paint stamp**. Second, the layout's own measuring dry-run
  wrote every note twice: **32 writes for 16 notes**. The decision is now
  published as `LayoutEngine.beams` and `LayoutEngine.tupletBeams` and read
  through `LayoutEngine.beamOf(note)`; `Note.beam` is an INPUT hint only, which
  is what `BeamingMode.manual` needs. Measured after: MusicXML and JSON exports
  are byte-identical before and after `layout()` AND before and after
  `ScoreRasterizer.renderStaffToPng` (3 349 / 3 349 / 3 349 characters,
  0 / 0 / 0 `<beam>` tags), the model's `Note.beam` values are untouched, and
  `PositionedElement.computeSignature` returns the same 278 109 605 from two
  independent engines. This partially supersedes
  [ADR-001](doc/adr/ADR-001-layout-never-clones-the-model.md), which made
  `Note.beam` mutable on purpose; see
  [ADR-005](doc/adr/ADR-005-layout-decisions-are-values.md).
- **Each beam level beyond the first pays for the gap under it.**
  `stemExtensionPerBeam` was the literal `0.5` behind the comment "Calculated
  based on beamSpacing" — a calculation never performed. 0.5 is `beamThickness`
  alone; the marginal cost of one more level is `beamThickness + beamSpacing`,
  which Bravura puts at `0.5 + 0.25 = 0.75`, and which is what
  `BeamRenderer._calculateLevelOffset` has actually been stacking with since
  2.7.1. Measured at `staffSpace = 12`: a 32nd (3 levels) added
  `2 x 0.5 = 1.00` staff space of stem while its beam stack reached
  `2 x 0.75 = 1.50` below the primary — the innermost beam hung **0.50 staff
  spaces (6.00 px) past the end of the stem it is drawn from**.
- **The beam subdivision table covers the meters that had no entry at all.**
  With one beat per denominator unit, a bar whose figure is worth exactly one
  unit puts exactly one note in every beat and a beam needs two, so the grouper
  returned nothing. Exhaustively measured before the fix, ZERO beams came out of
  quavers in 1/8, 2/8, 4/8, 10/8, 13/8, 14/8, 16/8, 2/16, 4/16, 8/16, 10/16,
  14/16 and 16/16, and semiquavers in 1/16, 2/16, 4/16, 5/16, 7/16, 8/16, 10/16,
  11/16, 13/16, 14/16 and 16/16 — plus 6/16 and 12/16, where a compound beat of
  three semiquavers is shorter than the quaver it had to hold and caught only
  two of the bar's three. Re-measured afterwards, and again independently in the
  documentation pass, over the full grid of numerators 2, 3, 4, 5, 6, 7, 8, 9
  and 12 against denominators 2, 4, 8 and 16, each bar filled with eighths,
  sixteenths or thirty-seconds: **108 combinations, 107 of which hold two or
  more notes, and exactly 1 of those 107 comes out unbeamed**. That one is 3/16
  holding two quavers — a bar that OVERFLOWS its own meter (0.25 against
  0.1875), so there is no beat left for the second quaver to be grouped into.
  The remaining combination, 2/16 filled with quavers, is a bar of ONE note,
  where a beam is impossible by definition.
  (An earlier draft of this entry read "106 combinations, 0 of 89, 17
  single-note bars". Those three numbers do not reproduce on this tree; they are
  replaced by the ones above, which two independent probes agree on.)
- **x/2 is not a compound meter.** The compound branch fired on any meter whose
  beat divided into three, and in x/2 that beat is a dotted BREVE. Measured: 6/2
  filled with quavers produced two beams of TWELVE notes, 9/2 three of twelve,
  12/2 four and 15/2 five. The compound beat is now capped at a dotted minim
  (0.75 whole notes), which is the limit Behind Bars p. 160 implies.
- **A trailing beat too short to stand is folded into the one before it.**
  Measured on 13/8: `[2,2,2,2,2,2]` plus one orphan quaver becomes
  `[2,2,2,2,2,3]`.
- **Beam band and gap thicknesses come from the SMuFL metadata.** Measured at
  `staffSpace = 40` by counting dark pixel runs down the middle of a two-level
  group: the hardcoded 0.40/0.60 pair gave a 16 px band and a 24 px gap for a
  56 px stack (1.40 SS); the metadata's 0.50/0.25 gives 20 px and 10 px for
  50 px (1.25 SS). The old numbers were not "lighter" — the stack the eye reads
  and the stems have to span was 10.7% taller, and 16.7% taller at three levels.

#### Engraving and layout

- **A tuplet's internal spacing no longer depends on the configured spacing
  model.** `TupletGrid` took an optional `IntelligentSpacingEngine`: the layout
  passed one and the renderer, which holds none, fell back to the built-in
  square root. Identical for the default `SpacingModel.squareRoot`, and
  divergent for every other model — which is the exact class of defect
  `TupletGrid` exists to remove. Measured across all four models, the tuplet's
  children sat at identical X positions in all four while the same durations
  written as plain notes moved by ratios of 1.250 / 1.137 / 1.027 / 1.278.
  Tuplet-internal spacing is now Gould's square root by construction; the
  tuplet's placement in the outer flow still follows the configured model.
- **A tuplet's minimum slot is 1.9 staff spaces, not 1.4.** Measured at
  `staffSpace = 12` on the corpus case `m04m_tuplet_ratio` (5:4, five stepwise
  sixteenths): every step came out at 16.800 px and the real ink gap between
  adjacent noteheads was 2 px = 0.167 SS, under the package's own
  `SpacingPreferences.normal.minGap` of 0.25 SS. Re-measured after the fix on
  the same raster: the step is 22.800 px = 1.9000 SS and **the real ink gap is
  9 px = 0.750 SS**, three times the package's own minimum — not the 11 px that
  an earlier draft of this entry and the dartdoc in `tuplet_grid.dart` both
  claimed. (9 px is the gap on the widest notehead row, where the black ink is
  13-14 px across; the slot arithmetic reserves a nominal 0.72 SS = 8.64 px and
  the glyph's side bearing supplies the rest.) The old floor was also flat over
  two thirds of its domain — ten of the fifteen `DurationType`s all received
  exactly 1.4.
- **The tuplet bracket is drawn at bracket weight, not stem weight.** It used
  the literal `staffSpace * 0.12`, which is the value of `stemThickness` — the
  wrong entry of the wrong table, and a literal, so it did not even follow the
  font's own stem. Measured on a raster at `staffSpace = 48`: the horizontal
  bracket line was **6 opaque rows = 0.1250 staff spaces against the 0.16 the
  font declares, 22% too thin**. It now reads
  `engravingDefaults.tupletBracketThickness`, which is the weight of a thin
  barline (Behind Bars p. 201).
- **A wrapped system restates the clef the bar is actually in, on a single
  staff too.** The head test was `measure.elements.any((e) => e is Clef)`,
  which answers "yes" for a bar whose ONLY clef is a mid-measure CHANGE and so
  suppressed the restatement, and it read `elements` rather than `allElements`,
  so a clef living in a voice was invisible to it. Measured on twelve bars at
  300 px with bar 1 carrying a bass clef AFTER its first note:
  `sys1 clefs=[bass@56]` — **the system opened with no clef at all at x = 30**;
  on a ten-bar staff whose bar 3 changes to bass mid-voice, systems 3 through 9
  restated **treble** while bass was in force, i.e. every note from bar 4 on was
  drawn a twelfth wrong. The single-staff path now applies the same
  `_statesAtHead` rule `GrandStaffPainter` applies, so the two cannot diverge.
- **Tuplet children follow their tuplet when a grand staff aligns its hands.**
  `_alignStaves` remapped X for `Note` and `Chord` only. A `Tuplet` is
  positioned as ONE element and its children live on a grid anchored on it, so
  on a grand staff they kept their pre-alignment coordinates — and beams,
  hit-testing and the public position API all read those coordinates.
- **A chord's accidental block reports one width to the layout and the
  renderer.** Measured before the shared, metadata-only geometry existed: a
  chord with 2, 3, 4 **or** 5 accidentals reported
  `LayoutEngine.elementLeftExtent = 25.82 px` — one column's worth — while
  `ChordRenderer` packed them into as many columns as they needed. Measured
  after, at `staffSpace = 12` on stacked sharps: **29.18 / 43.78 / 58.37 /
  58.37 px** for 2 / 3 / 4 / 5 accidentals. The last two are equal because the
  fifth accidental fits into a column an earlier one already opened — that is
  the renderer's own packing, and the layout now reports it instead of guessing
  one column for every case.
- **Two tuplets in the same bar keep their proportion to each other.** The
  legibility floor of the tuplet grid — the scale that lifts the narrowest slot
  up to `TupletGrid.minimumSlotSpaces` — was computed per GROUP, so every group
  independently bottomed out on the same floor and no two of them could be told
  apart. Measured at `staffSpace = 12` on one 4/4 bar holding a 3:2 triplet of
  quavers beside a 3:2 triplet of semiquavers: **1.9000 SS per slot for both,
  ratio 1.0000**, where the quavers should be sqrt(2) = 1.4142 wider per note.
  The scale is now computed once per MEASURE — `LayoutEngine.tupletContextFloor`
  publishes the denominator and `TupletRenderer` reads it, the same
  layout-decisions-are-values shape as `tupletBeams` (ADR-005), so the two
  cannot draw different grids. Measured after: **2.6870 SS and 1.9000 SS, ratio
  1.4142**. The floor is untouched where it matters — the narrowest group in the
  bar still sits exactly on it, and the rasterised ink gap between adjacent
  noteheads is unchanged at **9 px = 0.750 SS**, three times the package's own
  `SpacingPreferences.normal.minGap`. A bar holding exactly one tuplet has a
  context equal to that tuplet, so its geometry is bit-identical to 2.7.1 and no
  corpus golden moved.
  The per-slot alternative (`max(raw, minimumSlotSpaces)`, preserving ratios
  above the floor) was measured and rejected: both raw slots, 1.7678 and 1.2500,
  are BELOW the 1.9 floor, so both clamp to 1.9 and the ratio stays 1.0000.
- **An over-full measure is now reported instead of silently overflowing.**
  `LayoutEngine` gained a `List<String> warnings` — the same shape
  `MidiConversionResult`, `PdfExporter` and the parsers use — and records, per
  measure, that the spacing compression bottomed out at
  `minimumSpacingScale` (0.35) and the bar STILL does not fit, naming the
  measure and the overflow factor. Measured on 40 whole notes written into one
  4/4 bar at 900 px: **43 elements on ONE system reaching x = 1 829.2 px, 2.03x
  the line**, previously produced with no diagnostic at all beyond a boolean
  `overflowsAvailableWidth` for the whole staff. This is a DIAGNOSTIC only: the
  geometry is byte-for-byte what it was, asserted by
  `PositionedElement.computeSignature` equality between an engine that records
  the warning and one that does not.

#### Interaction

- **The hit box of a note covers its flag and its ledger lines.** MEASURED at
  `staffSpace = 12`, treble: a lone eighth on C4 has its stem 13.44 px right of
  the note origin and `flag8thUp` is 12.67 px wide from there, so the flag
  occupied x 95.32 .. 107.99 while the box ended at 99.20 — a click on the outer
  two thirds of the flag returned null. C6 and A3 quarter notes carry 23.76 px
  ledger lines (14.16 px notehead + 2 x 4.80 px extension) centred on the head,
  2.43 px past each side of the box, so a click on either END of a ledger line
  returned null while the middle worked.
- **The box top matches the stem the renderer actually draws.** MEASURED at
  staff position -20, `staffSpace` 12: the stem is 10.000 staff spaces, not 3.5,
  because Behind Bars p. 47 makes it reach the middle line. A separate 2e-14 px
  floating-point mismatch at staff position -6 (box top 51.98400000000001
  against a drawn tip of 51.98399999999999) made a click exactly on the tip
  miss; the boundary now carries air.

#### Interoperability

- **The MusicXML exporter writes `Chord.duration`.** `_buildChordXml` emitted
  the duration of each INNER `Note` and never looked at the chord's own, while
  `Measure.musicalValueOf`, `LayoutEngine` and `MidiMapper` all read
  `Chord.duration`. Measured round trips of `currentMusicalValue`: a dotted
  quarter chord over plain-quarter inner notes went 0.375 -> 0.25, a
  double-dotted half over halves 0.875 -> 0.5, and a whole over eighths
  1.0 -> 0.125. The emitted XML for the dotted chord carried `<divisions>480`,
  `<duration>480</duration>` twice and ZERO `<dot/>`. All three now round-trip
  exactly, and the dotted chord exports `<duration>720</duration>` and one
  `<dot/>` per tone.
- **A nested tuplet is no longer dropped on export.** The exporter's leaf filter
  kept `Note`, `Rest` and `Chord` and silently discarded any nested `Tuplet`.
  Measured on a 4/4 bar holding 3:2 of [quarter, quarter, 3:2 of three eighths]:
  the bar went 0.5 -> 0.3333 and the inner group's three notes vanished. Leaves
  now carry the PRODUCT ratio, which is what MusicXML requires, and the bar
  round-trips 0.5 -> 0.5. Known loss: only the outer bracket is written
  (`number="2"` is not emitted), so re-importing gives two sibling `Tuplet`s
  rather than one nested pair.
- **`<backup>` matches the notes that were written.** The nested-tuplet factor
  was not multiplied through, so a two-voice bar whose upper voice held the
  figure above emitted `<backup><duration>1120</duration>` while the notes it
  had actually written summed to 640. It now emits 961, which is exactly the sum
  of the five `<duration>` values written.
- **MusicXML tuplets survive the round trip.** `<notations><tuplet>` is written
  alongside `<time-modification>`, and the importer opens and closes a group
  from the ratio even when the bracket is absent. Measured on a 4/4 bar of a 3:2
  triplet plus a quarter: 0.5 -> 0.625 with the group dissolved into four loose
  notes before, 0.5 -> 0.5 with the `Tuplet` returning as a `Tuplet` after.
- **The parsers report what they could not read.** Measured before the channel
  existed: `grep -rin "warn" lib/src/parsers/` returned 0 hits across 5 935
  lines, and `<divisions>0</divisions>` silently turned a
  `<duration>4</duration>` quarter into a whole note. `parseMusicXML`,
  `scoreFromMusicXML`, `parseMEI` and `parseMeiScore` now take an optional
  `warnings` list. Re-measured in the documentation pass on nine malformed
  documents that ALL used to import in silence: a zero `<divisions>` and a
  non-positive `<duration>` now raise warnings (3 and 1 message respectively,
  each naming the measure and the value substituted), and **three of the nine
  are rejected outright** with a `FormatException` instead of importing as
  something plausible — `<pitch>` with no `<octave>`, an unknown `<step>`, and a
  document that is not a score at all. **Coverage is not total: four of the nine
  are still absorbed in silence** — an unknown `<clef><sign>`, an unknown
  `<type>`, a non-numeric `<alter>` and a missing `<part-list>`.
- **MEI `<staffGrp>` labels reach the model.** Measured:
  `<staffGrp symbol="brace"><label>Piano</label><labelAbbr>Pno.</labelAbbr>`
  produced `StaffGroup.name = null` and `abbreviation = null`, so an imported
  piano system lost its instrument label while the MusicXML import of the same
  music kept it.
- **The JSON round trip keeps the staff's own fields.** `staffToJson` wrote them
  but `parseStaff` read only `measures`. Measured on a B-flat instrument:
  `parseStaff(staffToJson(s))` returned `name = null`, `abbreviation = null`,
  `lineCount = 5` regardless of the source, and `transposition = null`. The JSON
  importer also duplicated a polyphonic bar's opening block into voice 1, so the
  layout drew it twice — measured `Clef@30.0, Key@68.2, Time@99.4, Clef@147.4,
  Key@227.6, Time@300.7`.

#### Export and widgets

- **`GrandStaff` scrolls horizontally.** Measured before: one bar of 2 000
  thirty-second notes at a 300 px viewport laid out to x = 57 436.2 px inside a
  `CustomPaint` pinned at 300.0 px with ZERO scrollables in the tree — 99.5% of
  the bar unreachable. The canvas is now sized from the painter's content width,
  the multi-staff analogue of what `MusicScore` has always done. Measured after,
  on 200 thirty-seconds in the same 300 px viewport: **1 `Scrollable`,
  `AxisDirection.right`, `maxScrollExtent 5525.76`**, which plus the 300 px
  viewport is 5825.76 — exactly `GrandStaffPainter.contentWidth`. 100% of the
  music is reachable.
- **PDF export of a grand staff pages instead of cropping.** Measured on a
  40-bar two-staff piano score: the group wraps into 14 systems at
  963.78 x 3552 logical px; at A4 the image wanted 1776 pt of height and got
  706.5 pt, so **39.8% of the music reached the PDF** and eight and a half
  systems were dropped in silence. Measured after, on the same score:
  **3 music pages of 5 / 5 / 4 systems = 14 of 14**, every system present
  exactly once, the largest page raster 1928 x 2520 px against the 8192 px cap,
  237 157 bytes of PDF carrying 4 page objects (title page + 3), and
  `PdfExporter.warnings` empty.
- **The grand-staff rasterizer sizes its canvas from the music and caps its
  resolution.** Measured, a single bar of sixteen sixteenths requested at 200
  logical px placed its last element at x = 679.99 (content edge 718.39 with the
  26.4 px brace pad) against a 200 px canvas — 518 px of music cut off. And a
  60-bar two-staff group produced a 2 000 x 10 128 px image at `pixelRatio` 2;
  the audit measured 15 168 px (~97 MB of RGBA, 3 570 ms) on a 30-system group
  and projected 151 248 px for a 600-bar score, past every mobile texture limit.
  The guard is a resolution cap, not a crop.

- **The text-font escape hatch is reachable from the package root.** Every
  non-SMuFL string the engine draws now goes through one fallback chain
  (`kMusicTextFontFallback`: `Academico, Century Schoolbook, Edwin, serif`), and
  **the package ships none of those four** — `assets/` holds `Bravura.otf` and
  `greciliae.ttf`, and `pubspec.yaml` declares exactly those two families, both
  music fonts. Measured on 2.7.1 by rasterising one score four ways and varying
  only the registered text face: Bravura + Greciliae alone gave **16 `.notdef` boxes**, a
  real face named `Academico` gave **0**, and a real face named `serif` gave 16
  again with a PNG byte-identical to the first — the terminal generic is not a
  resolution guarantee. `MusicTextFont.use(family)` and
  `MusicScoreTheme(textFontFamily: ...)` are the supported answer and are now
  exported from `package:flutter_notemus/flutter_notemus.dart` rather than only
  reachable through a convenience re-export inside `music_score_theme.dart`.
- **...and that escape hatch now actually reaches the painter.** It was inert
  for tempo marks, expression text, word dynamics and repeat instructions: TEN
  sites in `symbol_and_text_renderer.dart` attached `fontFamilyFallback`
  themselves before calling `withMusicTextFallback()`, and the extension's
  contract is that a caller-supplied chain always wins — so supplying it up
  front made the injection point unreachable by construction. Measured before:
  the same score rasterised to **76 120 px of ink BOTH with and without**
  `MusicTextFont.use`. Those ten sites no longer pre-supply the chain. Measured
  after at `staffSpace = 12` in a 900 px viewport: **14 942 px of ink and 2
  `.notdef` boxes with no text face registered, 6 886 px and 0 boxes with one
  injected**. The chain-wins rule itself is unchanged and still correct — a
  theme that names its own faces is left alone, and the same score built with
  such a theme measures 14 079 px and 5 boxes either way. Guarded structurally
  as well: `w5_leftovers_test.dart` fails if any executable line of that file
  sets `fontFamilyFallback` again.
- **`ScoreRasterizer.renderStaffToImage` no longer crops the top of the music.**
  It sized the canvas with `LayoutEngine.calculateTotalHeight`, which already
  adds `contentTopOverflow`, but passed `topLogicalY: 0` — so the extra headroom
  was appended to the BOTTOM of the image and everything above logical y = 0 was
  still cut off. Measured on a 5:4 tuplet on C6-G6 at `staffSpace = 12` in a
  900 px viewport: `contentTopOverflow` correctly reported **38.40 px**, the
  image was correctly sized **900x231** — and row 0 carried **74 px of ink**
  (the E6 ledger lines of the last three notes) while the G6 notehead and its
  own ledger line were off the canvas entirely. `renderStaffPages` (and so
  `renderStaffToPng` and `PdfExporter`) never had the bug, because it passes
  `bandHeight * first - extraTop`; the two paths now agree to the pixel.
  Measured after: **0 px of ink on row 0 and on the last row**, for the C6-G6
  case and for a C3-G3 one, and identical total ink from the single-image and
  the paginated path.

#### Tooling and documentation

- **`dart analyze` is clean from the repo root, not only from `lib`.** The
  throwaway `probe/` measurement scripts are git-ignored but were still
  analysed: measured 470 problems at the root against 0 in `lib`, which broke
  any CI gate running the root form. `probe/**` is excluded; measured after, 0
  problems at the root.
- **`MidiMapper` no longer carries a field nothing reads.** Measured: 1 write, 0
  reads in `lib/` and `test/`, kept alive by an `// ignore: unused_field`.
- **The README no longer advertises delivered work as broken, and the section
  that did now holds only measured BOUNDARIES.** "Known defects, measured and
  still open" is renamed "Known limitations, measured and still open" because
  nothing in it is a defect any more. It held five entries across 2.7.0 and
  2.7.1, and a sixth added during 2.8.0's own documentation pass: no beams in 26 meter/figure combinations,
  MusicXML tuplets not surviving a round trip, silent acceptance of malformed
  MusicXML, `GrandStaff` with no horizontal scroll, and a single-page clipped
  grand-staff PDF, and cross-staff beams not being drawn. Three were fixed and
  removed in an earlier wave; two were still printed as CURRENT defects while
  the engine had already stopped having them — the third consecutive release in
  which the README asserted that delivered work was broken — and the sixth was
  fixed after the README bullet describing it was written. All were re-probed by
  a pass that did not write the fix (1 `Scrollable`, `maxScrollExtent 5525.76`,
  100% reachable; 3 pages, 14 of 14 systems, no warnings; auto-beamed and
  hand-beamed cross-staff groups rendering to the same 10 395 px of ink) and
  deleted. **Twelve documentation claims about a defect being open or closed
  were re-probed against the integrated tree for this release. Five were
  confirmed still true and seven statements were corrected** — the README
  sentence pointing at the cross-staff bug and the README bullet describing it,
  the two CHANGELOG "Known issues" entries (cross-staff beams and the
  `Note.beam` dartdoc), the README paragraph that presented the text-font escape
  hatch as working when it was inert on prose, a comment in
  `remediation_2_7_1_gaps_test.dart` that recorded the same inertness as
  permanent, and the performance regression, which the re-audit measured at
  1.19x-2.89x and which is closed (see "Performance against 2.7.1"). The five
  confirmed: the package ships no text face, four kinds of malformed MusicXML
  still import in silence, the `m04m_tuplet_ratio` step is still 22.800 px =
  1.9000 SS, `GrandStaff` still scrolls to 100% of its content, and a
  grand-staff PDF is still 14 of 14 systems over 3 pages. The paragraph claiming a grand-staff PDF is "one image
  on one page" and that "a 40-bar piano piece loses roughly 60% of its music"
  was rewritten; the half of it that IS still true — the text fallback chain
  asks for `Academico, Century Schoolbook, Edwin, serif` while `assets/` holds
  only `Bravura.otf` and `greciliae.ttf` and `pubspec.yaml` declares exactly
  those two families — survives, and now points at the `MusicTextFont` escape
  hatch.
- **Every `dart` code fence in the README compiles.** All 41 were extracted and
  analysed against the integrated tree. Three were wrong as printed: the
  Required-Initialization snippet called `runApp` and
  `WidgetsFlutterBinding.ensureInitialized()` without importing
  `package:flutter/material.dart`; the MIDI-export snippet declared a `Staff`
  parameter while importing only `package:flutter_notemus/midi.dart`, which does
  not export `Staff`; and the chant snippet called `Neume()` with both of its
  required arguments replaced by a comment. Measured after: **41 of 41 analyse
  with zero errors**, the only residue being the reader's own `MyApp`.
- **The numbers in this section were audited against fresh probes.** Four
  entries carried a figure that did not reproduce, or were missing their
  "after" half entirely; each is corrected in place above and says so where the
  correction changes a published number.
- **`AccidentalRenderer.decoratedWidthSpaces` delegates instead of
  duplicating.** The layout needs the same arithmetic with no renderer instance
  in hand, so a metadata-only static was added and the instance method became a
  second copy. Verified over all 235 `accidental*` glyphs in `glyphnames.json`
  times the three `AccidentalParenthesis` values, plus `noteheadBlack`, `gClef`
  and an unknown name to exercise the fallback: 714 of 714 combinations returned
  bit-identical doubles, 0 disagreements, before the two were collapsed into one.

#### Closed since the first draft of this entry

Two items were published in an earlier draft of this section as OPEN. Both were
fixed inside this release and both were re-verified by a pass that did not write
the fix, which is the only way an entry is allowed to leave the list.

- **Cross-staff beams ARE drawn on a `GrandStaff`.** `GrandStaffPainter` read
  `Note.beam` off the model in two places — the cross-staff relocation predicate
  and `_crossStaffGroups` — instead of asking `LayoutEngine.beamOf`, so after
  the beams-as-values change the model read `[null, null, null, null]` where the
  engine's answer was `[start, end, start, end]`, every note was classified as
  unbeamed, and zero cross-staff beam runs were found. Both sites now go through
  `LayoutEngine.beamOf`. Verified by DIFFERENCE, which is the measurement the
  old code could not pass: four quavers with the middle two sent to the other
  hand were rendered twice, once auto-beamed (model `Note.beam` all null) and
  once with the beams written by hand into the model. The two rasters agree —
  **10 395 px of ink each, the same beam runs at rows 69-74 spanning x
  161-274** — where the auto-beamed one used to draw no cross-staff beam at all.
  This was the single worst defect of the programme: it was correctly diagnosed
  by two independent audit waves, each of which wrote the patch into a report,
  and neither applied it.
- **`Note.beam`'s dartdoc describes the current contract.**
  `lib/core/note.dart` now says the field is an INPUT hint, that the layout
  never writes here since 2.8.0, and that `LayoutEngine.beamOf(note)` is the
  only supported read.

#### Closed at sign-off

The closing sign-off found these two open and they were fixed before release.
Both are the same ADR-005 category as the beam field — the engine reaching into
something it does not own.

- **A fully beamed tuplet no longer prints a bracket.** Gould, *Behind Bars*
  p.201: when a beam already delimits the group, only the number is shown.
  `TupletBracket.shouldShow` implemented the rule and was repaired this release
  to read the layout's beam decision — but it had **zero callers in `lib/`,
  `example/` or `test/`**. `TupletRenderer` decided with the deprecated
  `tuplet.showBracket` field, default `true`, and `_drawTupletBracket` drew
  unconditionally. Measured at `staffSpace 12`, width 600, full-raster dark
  pixels: a beamed triplet of eighths went 1960 -> 1832 px (the bracket line and
  its two hooks gone, the numeral kept); a triplet containing a rest stayed at
  1542 and one of quarters at 1859, both keeping their bracket; an explicit
  `showBracket: false` still suppresses. A second, unreported defect fell out of
  the same missing call site: a `bracketConfig` of `TupletBracket(show: false)`
  had been producing output byte-identical to the default, i.e. the documented
  configuration object did nothing. `m04_triplets` and `m04m_tuplet_ratio` were
  re-recorded; no other golden moved.
- **`LayoutEngine.layout()` no longer writes `Measure.inheritedTimeSignature`
  onto the caller's model**, which was flipping a public API from accepting to
  throwing. Two-bar staff whose second bar declares no meter of its own:

  | | `m2.inheritedTimeSignature` | `m2.add(fifth quarter)` |
  |---|---|---|
  | before, fresh | `null` | ACCEPTED |
  | before, after `layout()` | `TimeSignature(4/4)` | throws `MeasureCapacityException` |
  | now, fresh / after `layout()` / after paint | `null` | ACCEPTED in all three |

  Whether `Measure.add` accepted a note depended on whether the score happened
  to have been laid out. The derived meter is a value now
  (`LayoutEngine.inheritedTimeSignatures` / `timeSignatureOf`), read by the
  engine and by `MeasureValidator`; validation is unaffected — an over-full bar
  inheriting its meter from an earlier bar is still detected, and a wrapped
  grand staff whose meter is declared only in bar 1 still validates its later
  systems. `Measure.inheritedTimeSignature` survives as a field a caller may set
  deliberately to opt into preventive validation. Zero pixels moved.

#### One more, found while closing

- **Every note reserved a black notehead's width, whatever its duration.**
  `_getElementWidthSimple` used `noteheadBlackWidth` for all fifteen
  `DurationType`s. Bravura's `noteheadBlack` advance is 1.18 staff spaces but
  `noteheadWhole` is 1.688 and `noteDoubleWhole` wider still, so a semibreve and
  a breve were reserved a crotchet's room and painted past it. Measured at
  `staffSpace = 48`: reservation 56.6 px for both, against 81.0 px and 125.8 px
  of glyph. It now reads
  `metadata.getGlyphAdvanceWidth(duration.type.glyphName)`. The structural
  invariant that budgets painted ink against reserved advance had these two
  cases carrying 27.0 px and 71.0 px of allowance; both now pass at 3.0 px,
  which is anti-aliasing. No golden moved — a long note normally receives far
  more proportional space than its glyph needs, which is why this survived: it
  only bites under compression, and at the two places that read the advance
  rather than the spacing (the hit-test box and the raster's content width).
  The FLAG half of the same finding is still open: a stem-up eighth paints
  0.93 staff spaces past its reservation, and fixing it properly means
  separating "advance for spacing" from "painted extent" rather than changing a
  constant.

#### Closed after the sign-off report

Three things the closing report listed as open, closed with the same protocol.

- **Every note reserved a black notehead's width, whatever its duration.**
  Bravura gives `noteheadBlack` an advance of 1.18 staff spaces, `noteheadWhole`
  1.688 and `noteDoubleWhole` wider still; `_getElementWidthSimple` used the
  first for all fifteen `DurationType`s. Measured at `staffSpace = 48`: a whole
  note painted 81 px into a 56.6 px reservation and a breve 125 px. It now reads
  `metadata.getGlyphAdvanceWidth(duration.type.glyphName)`.

- **A flag painted outside every box built from the element's advance.** A
  stem-up eighth paints 0.93 staff spaces past its advance, because `flag8thUp`
  alone advances 1.056 staff spaces past the stem. That is not a spacing defect —
  a flag hangs over the following gap on purpose (Gould) — it is two consumers
  asking `elementWidth` a question it does not answer. New
  `LayoutEngine.elementPaintedRightExtent` separates *how far the cursor moves*
  from *how far the ink reaches*, and the two consumers that want ink use it:
  `ScoreHitTester` (a flag was unclickable) and the raster/PDF content width (a
  flag could be clipped at the page edge). Zero pixels moved — spacing is
  untouched by design.

- **A rest's reservation was in the wrong place.** Rests are drawn CENTRED on
  their origin (`GlyphDrawOptions.restDefault`) while everything else is drawn
  from its origin rightwards, and the layout reserved `[x, x + advance]`. The
  painted WIDTH always matched to within a pixel — 52.0 against 51.9 for a
  quarter rest — but the BAND sat half a glyph to the left of it. Two measured
  consequences: under compression a rest's ink runs back into the preceding
  note, and **clicking the left edge of a rest missed on every duration tested**
  (whole, half, quarter, eighth, 64th), while the right half of its selection box
  was empty staff — 7.8 px of unclickable ink and 12.6 px of dead zone for a 64th
  rest. `_leftExtent` now returns half the advance for a `Rest`, so reservation
  and ink coincide, and the hit box follows the ink.

  Five goldens moved and were re-recorded: `m10_rests`, `c01_mixed_phrase`,
  `c02_chromatic_chords`, `m04d_within_measure_accidentals`, `m12_melisma`. The
  change is a uniform half-glyph shift of every rest into the space that was
  already reserved for it. The objective check is the structural invariant that
  budgets painted ink against the reservation: all **seven** cases that used to
  carry an allowance — whole, breve, stem-up eighth, stem-up 32nd, whole rest,
  quarter rest, 64th rest — went from 27.0 / 71.0 / 47.0 / 47.0 / 29.0 / 28.0 /
  43.0 px to **3.0 px each**, which is anti-aliasing.

- **`MusicDuration` is now the canonical name** for the rhythmic duration type.
  The package exported it only as `Duration`, which shadows `dart:core.Duration`
  for anyone importing the barrel — so `Future.delayed(Duration(seconds: 1))`
  does not compile in a file that imports this package. Both names work;
  `Duration` remains as a legacy alias so nothing breaks, and is scheduled to
  stop being exported in 3.0. There is deliberately no deprecation annotation
  yet: it would fire at every one of the several hundred call sites inside this
  package and in every app using it, before there is a major version to land the
  removal in. The escape hatch is executed, not just documented —
  `test/core/music_duration_alias_test.dart` is written the way a consumer has to
  write it, with `hide Duration` on the package import.

#### Known limitations in this release

Not defects — measured boundaries. Each was re-probed against the integrated
tree for this entry.

- **The package ships no text face.** `pubspec.yaml` declares exactly two
  families and both are music fonts (`Bravura`, `Greciliae`); `assets/smufl/`
  holds `Bravura.otf` and no text font. On a host supplying none of
  `Academico, Century Schoolbook, Edwin, serif` every string is a `.notdef`
  box, and the terminal generic `serif` was measured NOT to rescue it (a
  headless binary with a face registered literally as `serif` produced a
  byte-identical PNG). `MusicTextFont.use` is the supported answer and, as of
  this release, reaches every string the package draws.
- **Four kinds of malformed MusicXML import in silence.** Re-probed over seven
  documents: **2 rejected** with a `FormatException` (a `<pitch>` with no
  `<octave>`, an unknown `<step>`), **2 warned** (a zero `<divisions>`, a
  non-positive `<duration>`), **3 silent** (an unknown `<clef><sign>`, an
  unknown `<type>`, a non-numeric `<alter>`); a missing `<part-list>` is the
  fourth silent case.
- **A single measure can be wider than the viewport.** Compression stops at
  `LayoutEngine.minimumSpacingScale` (0.35) because past it the noteheads
  collide. Measured: 40 whole notes in one 4/4 bar at 900 px reach
  x = 1 829.2 px, **2.03x** the line. No music is lost — both widgets scroll —
  and the engine now names the bar in `LayoutEngine.warnings`.
- **Advanced MEI modules are model-only**: figured bass, mensural notation and
  MEI `<neume>` are constructible in Dart but neither imported from MEI XML nor
  rendered.
- **Tuplet-internal spacing ignores the configured `SpacingModel`**, by design,
  so that `TupletRenderer` and `LayoutEngine` cannot draw different grids.
  Measured across all four models: a tuplet's child X positions are identical in
  all four, while the same durations as plain notes move by 1.250 / 1.137 /
  1.027 / 1.278.

#### Performance against 2.7.1

The pre-release re-audit measured this release **1.19x-2.89x slower than 2.7.1 at
1 600-12 800 bars**, from the extra work the correctness fixes added. That
regression was closed inside this release and is NOT shipping.

The closing sign-off re-measured it independently against 2.7.1 checked out in a
sibling worktree — same machine, same probe (`8` eighths per bar,
`availableWidth 1200`, `staffSpace 12`), warm-up of 5x200 bars plus a throwaway,
7 samples per size, min and median reported. Element counts are identical on
both sides at every size (3 735 / 7 468 / 14 935 / 29 868 / 59 735 / 119 468),
so the two are laying out the same score. Three alternating rounds were run
(tree, 2.7.1, tree, 2.7.1, tree, 2.7.1); the table gives the MEDIAN of the three
per-size ratios, because a single round on this machine is not a stable
statistic:

| bars | 2.7.1 min | 2.8.0 min | ratio (median of 3 rounds) |
|---:|---:|---:|---:|
| 400 | 35.1-42.0 ms | 41.4-61.9 ms | 1.23x |
| 800 | 41.6-73.0 ms | 53.3-84.3 ms | 1.28x |
| 1 600 | 118.3-152.7 ms | 124.5-151.8 ms | 1.09x |
| 3 200 | 248.6-309.7 ms | 250.3-307.2 ms | 0.99x |
| 6 400 | 542.3-666.7 ms | 646.4-659.2 ms | 1.06x |
| 12 800 | 1 156-1 439 ms | 1 214-1 484 ms | 1.03x |

**Read this as parity, not as a win.** At the sizes where the regression was
reported — 1 600 to 12 800 bars — the release is within ±10% of 2.7.1
(1.09 / 0.99 / 1.06 / 1.03), so the 1.19x-2.89x regression is gone; it has not
been turned into a speedup. At 400 and 800 bars the totals are 40-85 ms and one
young-generation GC moves them more than the code does: the per-size ratio
ranged 0.80x-1.52x across the three rounds, which is noise, not a measurement.
An earlier draft of this entry quoted 0.78x / 0.65x / 0.69x at
1 600 / 3 200 / 6 400 from a single pair of runs; that did not reproduce and has
been replaced by the numbers above.

Absolute milliseconds here are **not** comparable to figures measured in any
other session — the same unchanged tree was observed at 313 ms and 2 792 ms for
6 400 bars an hour apart on this machine. Only same-session ratios mean
anything. The shape that matters — cost per bar not growing with the number of
bars — is pinned by `test/invariants/remediation_2_7_1_test.dart` (N-04) and
`test/invariants/performance_budget_test.dart`; note that N-04's ceiling is a
single ratio and has been seen to flake under concurrent load.

### Milestone: remediation of the 2.7.0 forensic re-audit — 30 findings  *(tagged in git as 2.7.1; never published)*

An independent adversarial RE-AUDIT of 2.7.0 verified the 38 remediation claims
by executing the engine, confirmed 25 of them outright and 13 partially, and
catalogued 30 findings the 792 green tests of 2.7.0 did not catch. This release
fixes them. The re-audit is committed as `doc/AUDITORIA_FORENSE_2026-08-22.md`
so these claims can be checked the same way.

Several fixes change what a correct score looks like, so 16 goldens were
re-baselined. Every one of those changes is a visible improvement and each is
shown before/after in the audit document.

#### Engraving

- **A measure now opens clef, key signature, meter — whatever order the source
  used.** MusicXML's `<attributes>` has a fixed content model that puts `<clef>`
  LAST, so 2.7.0's "system elements keep document order" fix meant every
  imported score drew its key signature and meter in front of its clef
  (measured: `KeySignature@30.0, TimeSignature@69.6, Clef@105.6`). The opening
  block is a convention; only the body keeps document order. See ADR-004.
- **Beam slant follows the interval again.** `maximumBeamSlant` was 0.5 ("was
  1.0, too steep!") and pairs were separately clamped to 0.25 to match "the
  stable beam showcase examples" — a number calibrated against this package's
  own screenshots. Measured: an ascending 2nd, an ascending 6th and a
  TWO-OCTAVE leap all produced exactly 0.25 staff spaces. Replaced by Gould's
  interval table (unison 0, 2nd 0.25, 3rd 0.5, 4th/5th 1.0, 6th/7th 1.25,
  octave or wider 1.5).
- **4/4 groups semiquavers by the crotchet.** Sixteen sixteenths came out as two
  beams of eight; 3/4 was already correct at four-per-beat, which was the tell.
  The half-bar amalgamation is a quaver licence, not a general rule.
- **5/4 beam subdivisions cover the bar.** The table entry was `[0.5, 0.5]`,
  summing to 1.0 against a bar worth 1.25, so the fifth crotchet fell through
  and produced a stray trailing group (measured: `4-4-2` for ten quavers).
- **An accidental claims the space BEFORE its note.** The full element width —
  accidental included — was charged to the advance AFTER the note, with a flat
  0.15 staff spaces in front. Measured on `C4, E4-sharp, G4, B4`: the gap before
  the sharp grew 6.30 px, the gap after it 15.55 px. Element extent is now split
  into a left and a right half.
- **The collision floor asks the metadata.** It added a flat `staffSpace * 0.6`
  for an accidental; `accidentalDoubleFlat` is 1.652 staff spaces wide. Measured:
  32 compressed sixteenths carrying double flats drove 7.08 px into the previous
  notehead. The same test now leaves 16.34 px of clearance.
- **A tuplet spaces its children by duration.** The layout and the renderer laid
  them on a flat 2.5-staff-space grid, separately: a quarter and an eighth in one
  triplet both got exactly 30.00 px. One shared `TupletGrid` now drives both.
- **Beam levels inside a tuplet are per note.** The count came from
  `notes.first`, so an eighth followed by two sixteenths lost its secondary beam
  entirely — the same figure outside a tuplet was already correct.
- **Beams get geometry without an explicit meter.** `_analyzeBeamGroups`
  returned early when a measure declared no `TimeSignature`, leaving stamped
  beams with no stem lengths, no slope and no secondary segments. The README's
  own quick-start snippet takes that path.
- **A cross-voice unison shares one notehead position** (Behind Bars p.44)
  instead of being displaced by a full head width, which reads as a second.
- **A cross-system slur no longer draws through the clef.** Its lead-in started
  at the system's left edge, which is the restated clef's own X.
- **Lyric width is measured, not counted.** It was
  `text.length * staffSpace * 0.85 * 0.5`, so "WWWWW" and "iiiii" reserved the
  same room and an ideograph reserved a third of what it needs.

#### Data loss and robustness

- **`MultiVoiceMeasure.elements` reach the layout.** `_layoutMultiVoiceMeasure`
  read only the voices, so a clef, key, meter or dynamic written to the measure
  was silently dropped — and with no active clef every note in the bar landed on
  the staff baseline (measured: a C6 and a C4 both at y = 60.0) with the position
  maps empty. Imported polyphony escaped it only because the parsers wrote every
  system element twice; that compensating duplication is removed with it.
- **A wrapped system no longer throws.** `_systemStaff` copied the first bar of
  each system with `Measure.add`, which validates capacity — and importers
  legitimately produce over-full bars, as the dartdoc on `Measure.elements` says.
  The painter's constructor raised `MeasureCapacityException` and took the widget
  tree down with it.
- **A wrapped system keeps its configuration.** The rebuild used a fresh
  `Measure()`, losing `autoBeaming`, `beamingMode`, `manualBeamGroups` and
  `number`; for a `MultiVoiceMeasure` it walked `elements` only and dropped every
  voice.
- **`<pitch>` with no `<octave>` fails loudly.** It was the one malformed-input
  case that still dropped the note in silence.

#### Interoperability

- **`Pitch` is the sounding pitch** (ADR-003). MusicXML `<pitch>`, MEI
  `@pname`/`@oct` and MIDI all mean it that way; the package meant something
  else, and not even consistently — `c8vb` already implemented the sounding
  convention while every other octave clef implemented the written one. Measured
  before: an imported `<pitch>C4` under `clef-octave-change="-1"` was drawn at
  the plain-treble C4 position AND played as MIDI 48.
- **`<transpose>` reaches playback.** It was parsed into `Score.metadata` and
  `applyMusicXmlTransposition` was never called from `lib/`, `test/` or
  `example/`. It is now `Staff.transposition`, applied by `MidiMapper` and
  emitted on export: a B-flat clarinet's written C4 sounds B-flat 3.
- **`MusicXMLParser.scoreToMusicXML`.** There was no score-level exporter, only
  `staffToMusicXML`, which emits one anonymous part called "Music". Part list,
  `<part-group>`, group names, part names, abbreviations and transpositions now
  round-trip.
- **`<part-name>`, `<part-abbreviation>` and `<group-name>` are imported** into
  the new `Staff.name`, `Staff.abbreviation` and the existing `StaffGroup.name`.
- **A JSON exporter exists.** `JsonMusicParser` could only parse, so a JSON round
  trip was not lossy — it was impossible. Import also dropped `syllables` and
  `crossStaffMove`.
- **MEI `clef.shape="TAB"`** produces a tablature clef instead of no clef at all.

#### Rendering and export

- **Text uses the package's own font stack.** Measure numbers, and every other
  text site, built a bare `TextStyle` with no family and no fallback chain, so in
  the headless path (`ScoreRasterizer`, and therefore PDF export) they rendered
  as `.notdef` boxes. The goldens hid it because the harness injects a font the
  library never asks for.
- **PDF exports a grand staff as a grand staff.** `_addMusicPages` rasterised
  each staff separately, so a piano part came out as two independent one-line
  staves: no brace, no system barlines, hands not aligned. It now reuses
  `GrandStaffPainter`, the painter the widget draws with.
- **Hit-testing is derived from the drawing.** The box was one notehead tall and
  `elementWidth` wide starting at the origin, so the stem and the flag fell
  outside it, the accidental (drawn to the LEFT) fell outside it, and a chord's
  box was centred on the staff baseline rather than on its noteheads: clicking
  exactly on the notehead of a chord above the staff returned null. The new
  `PositionedElement.staffBaselineY` removes the ambiguity that caused it, and
  `PositionedElement.movedTo` stops the post-layout passes from losing fields.

#### Performance

- **Layout is linear again.** `_justifyHorizontally` scanned the whole element
  list once per system — O(systems x elements), and the system count grows with
  the score. Measured before and after on the same machine:

  | bars | 2.7.0 | 2.7.1 |
  |---:|---:|---:|
  | 800 | 143 ms | 92 ms |
  | 1 600 | 262 ms | 169 ms |
  | 3 200 | 1 156 ms | 171 ms |
  | 6 400 | 5 991 ms | 313 ms |

- The onset grid resolves 1/8192 of a whole note instead of 1/1024, so 2048th
  notes no longer collapse onto shared grid keys (measured: sixteen distinct
  onsets produced nine keys).
- The measure-width dry run no longer writes tuplet geometry into the engine's
  position maps.

#### Testing

792 to 821 tests. `test/invariants/remediation_2_7_1_test.dart` pins every
finding above together with the number measured before the fix, so a regression
is recognisable rather than merely red. Two existing tests were re-baselined
because they asserted the defect: both cases in
`treble8vb_staff_position_test.dart`, and the MEI-layers case in
`notation_parser_test.dart`.

#### Corrections to the re-audit itself

Verifying the claims also corrected two of the re-audit's own findings, which are
withdrawn: MEI additive meter (`meter.count="3+2+2"`) **is** preserved —
`TimeSignature.isAdditive` is true with groups `[3, 2, 2]` — and the tuplet
bracket **is** collinear, both halves interpolating one line.

---

### Milestone: remediation of the 2.6.0 forensic audit — 42 findings  *(tagged in git as 2.7.0; never published)*

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

#### Fixed — engraving correctness

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

#### Fixed — data loss

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

#### Fixed — robustness and security

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

#### Fixed — API and determinism

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

#### Fixed — found by the review of this very release

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

#### Added

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

#### Performance

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

#### Changed

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

#### Testing

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
