# Gregorian SOTA audit backlog (59 confirmed)

> **2.6.0 audit status (2026-06-19).** Cross-checked against the code by a
> two-pass automated audit (classify, then adversarial verify). An item is
> listed **RESOLVED** only when the adversarial pass confirmed the desired
> behavior is implemented; **PARTIAL** = implemented with caveats/gaps; the
> rest stay open. Overlay over 59 items — the per-item descriptions below
> are unchanged.

- **RESOLVED (2):**
  - **#1** — Vertical placement uses clef-absolute positioning
  - **#25** — Syllable hyphenation between neumes of same word (repeated h...
- **PARTIAL (13):**
  - **#4** — Quilisma-scandicus and quilisma-torculus precomposed glyphs
  - **#5** — Augmentum mora dot uses AuctumMora glyph
  - **#6** — Lyric/syllable anchored under first note of neume
  - **#7** — Divisiones with asymmetric spacing and virgula type
  - **#8** — Custos with variants, space reserve, and pre-clef-change
  - **#12** — Punctum-mora dot binding at neume level
  - **#13** — Climacus as precomposed glyph or proper assembly
  - **#15** — Horizontal episema as shape-specific HEpisema glyphs
  - **#17** — Quilisma and oriscus rhythmic treatment; pressus/oriscus-fle...
  - **#20** — Custos orientation and vertical seating by glyph anchor
  - **#28** — Accent-based lyric centering (explicit {..} or heuristic)
  - **#35** — Mark anchor offsets per neume sub-glyph (not uniform spread)
  - **#46** — Clef/initial spacing reserve and clef-flat glyph rendering

## 1. [HIGH/large [MODEL CHANGE]] (pitch-clef-modal) Vertical placement ignores the clef entirely (median-centred, not clef-absolute)
**Desejado:** In square notation the staff position is absolute: a c4 do-clef fixes DO on the 4th line, and every pitch is read off that anchored line by line/space. The note's vertical position must be derived from (pitch slot - clef-line slot), independent of the melody's median. This is what makes the clef line, accidentals, custos pitch, and clef changes all line up consistently.
**Como:** The parser already resolves the absolute staff slot in GabcParser._slotToPitch (clefSlot = 2*line+1, slot indices a..m). Carry the staff SLOT (or the diatonic number plus the clef anchor) through to the renderer instead of recomputing a median. Replace `ref = median` with `ref = clefAnchorDiatonic` so step 0 = clef line; then _stepY places notes absolutely. The GABC research note in doc/GREGORIAN_RESEARCH.json states 'the renderer places a note at staff-slot(letter)'.

## 2. [HIGH/large [MODEL CHANGE]] (text-structure) No word/syllable model: lyrics are an unstructured per-neume string
**Desejado:** An editor-grade lyric layer needs a syllable model: each syllable knows its word, its position in the word (begin/middle/end/single), and whether it is a melisma (one syllable sung over many neumes). This is the foundation for hyphenation, melisma extender lines, justified underlay and multi-verse alignment (cf. notationref lyric-syllabic / lyric-melisma / lyric-extender ids that GREGORIAN_RESEARCH.json flags as the chant-relevant concepts).
**Como:** Add a Syllable/Lyric value object (text, wordId, SyllablePosition enum, isMelisma, verseIndex) and either a List<Syllable> on Neume or a parallel text-underlay track keyed to neume index. In GABC the word boundary is the whitespace BETWEEN syllable(notes) tokens (the parser already splits there at gabc_parser.dart:66), and a hyphen inside the source text (e.g. 'Ky-ri-e') marks intra-word syllable breaks — both signals are currently thrown away.

## 3. [MEDIUM/small] (neume-repertoire) Distropha / tristropha / bistropha not rendered as repeated strophae
**Desejado:** Distropha = two strophae, tristropha = three, drawn as the repeated stropha (apostropha) lozenge with the correct tight spacing; the final stropha of an augmented group uses the strophicus auctus.
**Como:** In the assembly loop (gregorian_renderer.dart:243-262) honour forms[i]==NcForm.stropha -> 'Stropha' for EVERY component (currently descending/first-note logic overrides it). Use StrophaAucta / StrophaAuctaLongtail for the liquescent/augmented final stropha. Tighten cx advance for same-pitch strophae (they sit closer than puncta).

## 4. [MEDIUM/small] (neume-repertoire) Quilisma only handled in 2-note pes; quilisma-scandicus and quilisma-torculus fall to assembly
**Desejado:** Quilisma-scandicus and quilisma-pes-quadratum render as the precomposed glyphs where the quilisma is fused into the ascending group.
**Como:** Greciliae ships QuilismaPesQuadratum###(Nothing|Ascendens|Descendens) and QuilismaPesQuadratumLongqueue###Nothing for the quilisma+two-rising case, plus LeadingQuilisma# for quilisma joins. Extend the quilismaGroup case to length>=3: when forms[0] or forms[1]==quilisma and the contour is rising, build 'QuilismaPesQuadratum' + _word(up) (+ Scandicus tail for 3 rising). Also classify these: _classify currently never returns quilismaGroup, so a quilisma-bearing run is typed scandicus/salicus and the quilismaGroup case is unreachable for imports.

## 5. [MEDIUM/small] (rhythmic-signs) Mora (augmentum) dot is a hand-drawn circle, not the AuctumMora glyph, and second-dot spacing/registration is ad hoc
**Desejado:** The augmentum dot should be the font's engraved dot, always seated in the SPACE to the right of the note (never on a line), with the canonical Solesmes gap, and a second dot (double mora, e.g. final cadence) spaced one dot-width further with identical vertical registration.
**Como:** Render with the Greciliae glyph AuctumMora (codepoint 57352, bbox y 48..119) instead of drawCircle. Compute the space center from the staff grid (step rounded to the nearest space) rather than the isOdd hack, so a dot on a line-note still lands in the adjacent space consistently. Keep dot binding at the neume level per research gotchas[4] (attach to the whole neume, dots after the glyph).

## 6. [MEDIUM/small] (layout-spacing) Lyric/syllable not aligned under the first note of its neume
**Desejado:** Solesmes/Gregorio align the syllable so its centering vowel sits under the FIRST note of the neume (Liber Usualis convention; GABC `{}` manual centering point). For a torculus/climacus the text should begin near the first punctum, not float under the middle of a wide glyph.
**Como:** Anchor lyric x to the first component's center, not the box center. Use compX[0] from _emitNeume (currently discarded) — store the first-note center-x on _NeumeBox and pass it as the lyric anchor. Better: implement GABC `{...}` centering-point parsing in gabc_parser (_cleanText currently strips `{}` via `replaceAll(RegExp(r'[*{}]'),'')`) and center the marked substring; left-align the rest. Default centering should be on the syllable's first vowel, left-aligned to the first-note x.

## 7. [MEDIUM/small [MODEL CHANGE]] (layout-spacing) Divisiones get symmetric equal spacing instead of asymmetric breathing space
**Desejado:** Solesmes spacing puts a clear, slightly larger breath space around bars proportional to the bar weight (virgula < minima < minor < maior < finalis), typically more space after the bar than before, and the finalis hugs the end of the line.
**Como:** Give divisio-specific left/right glue scaled by NeumeDivisionType weight (virgula/minima small, maior/finalis large). Add the missing virgula type and render with Greciliae glyphs that have stable bboxes if desired (`VirgulaTwo` adv 143; DivisioMinima/Minor/Maior families exist but with near-zero advance, so geometric bars remain reasonable). Also add the currently-missing virgula (backtick) as its own lighter type rather than mapping `` ` `` to minima (gabc_parser.dart:162-164).

## 8. [MEDIUM/small] (layout-spacing) Custos placement is naive: fixed offset, single length variant, no reserved space, no pre-clef-change custos
**Desejado:** Gregorio reserves space for the custos at the right margin, picks an up/down + length variant by how far the next pitch is from the staff, and also emits a custos before a mid-score clef change. The custos sits just inside the final staff line, after a small gap from the last neume.
**Como:** Reserve rightPad width for the custos in the wrap/justify pass so it never collides with the last neume. Select among the six Greciliae custos glyphs by direction and reach: CustosUp/Down × Short/Medium/Long (present in font) based on |custosStep|. Add custos emission before clef-change tokens (parser already detects clef changes at gabc_parser.dart:70-84 but discards the prior context).

## 9. [MEDIUM/small] (text-structure) Asterisk (*) and dagger (†) structural cues are deleted
**Desejado:** The asterisk (schola/choir change, mid-verse) and the dagger (cross/flex breath cue) are meaningful performance marks that MUST appear in the lyric line of a chant book, typically as a spaced '*' and '†', often aligned with a divisio.
**Como:** Preserve '*' and the text-layer '+' (dagger) as literal lyric glyphs (render '†' U+2020 for the dagger). Keep them as their own zero-music lyric tokens so they sit between syllables; do not feed them into _slotToPitch. Pure text render, no Greciliae glyph required.

## 10. [MEDIUM/small [MODEL CHANGE]] (gabc-coverage) Repeated-note neumes: distropha/tristropha (ss/sss) and repeated puncta render as generic 'custom'
**Desejado:** Distropha (ss) and tristropha (sss) are recognized repeated-strophae groups with their characteristic tight horizontal spacing; bistropha/tristropha aucta (last note lengthened) supported.
**Como:** Add NeumeType.distropha/tristropha (or a repeatedStrophae type) to neume.dart and detect equal-pitch all-stropha runs in _classify. Greciliae has 'Stropha','StrophaAucta','StrophaAuctaLongtail' (no precomposed di/tri glyph — assemble from repeated 'Stropha' with reduced advance). Tighten the per-note advance for repeated-pitch strophae in _emitNeume.

## 11. [MEDIUM/small [MODEL CHANGE]] (gabc-coverage) Manual custos (z0, pitched letter+) not parsed
**Desejado:** Support an explicit custos token (letter+ for a pitched custos, z0 to suppress/force a custos at a clef change) so authored GABC custodes round-trip.
**Como:** Detect a trailing '+' after a pitch in _buildNeume → emit a custos element at that pitch; detect 'z0' as a control token. The font already has 'CustosUpShort/Medium/Long' and 'CustosDownShort/Medium/Long' to pick reach by distance.

## 12. [MEDIUM/small] (gabc-coverage) Punctum-mora dot binding: dot is bound per-note, not per-neume
**Desejado:** Mora dots placed at the neume level with correct vertical seating (dot in the space, nudged for line-notes) and correct horizontal order, matching Gregorio's (fe..) convention.
**Como:** This is partially handled (the renderer already raises a dot into the space for line notes via mk.step.isOdd). Improve by collecting all morae of a neume and laying them after the whole glyph for fused neumes rather than per-component center. Greciliae has 'AuctumMora' / 'PunctumInclinatumAuctus' for the engraved augmentum if you prefer a glyph over the drawn dot.

## 13. [MEDIUM/medium] (neume-repertoire) Climacus rendered as crude Virga+diamond assembly; never uses precomposed Greciliae climacus/ancus glyphs
**Desejado:** A climacus is a single engraved unit: a clivis-like head (virga or punctum) followed by inclinata that are kerned/tucked under the head with the correct descending stagger and a slight overlap, exactly as Solesmes/Gregorio engrave it. Liquescent (diminished) climacus = ancus.
**Como:** For the liquescent/diminished climacus, map to the precomposed Ancus family: AncusTwoTwoDeminutus / AncusLongqueueTwoTwoDeminutus (ambitus words from _word()). For the ordinary climacus there is intentionally NO single Greciliae glyph (Gregorio also assembles it), so keep assembly but: (1) use VirgaReversa or Punctum as the head per source shape rather than always 'Virga'; (2) use the directional inclinatum glyphs DescendensPunctumInclinatum for the body but PunctumInclinatumAuctus for an augmented final inclinatum, and StansPunctumInclinatum where the run levels off; (3) compute the descending vertical stagger from steps[] and overlap the boxes (current cx += w*0.98 spaces them as separate notes, which reads as detached puncta, not a climacus).

## 14. [MEDIUM/medium [MODEL CHANGE]] (neume-repertoire) Note-to-note fusion (ligature line) glyphs (PunctumLineBL/TR/BR, VirgaBaseLineBL) never used for assembled runs
**Desejado:** Assembled/fused runs (and GABC intra-neume fusion via '@' / '!') connect notes with the proper ligature line so they read as one neume.
**Como:** When a GABC fusion operator joins components, select the line-bearing punctum variant by join direction: PunctumLineTR (line to upper-right, ascending join), PunctumLineBR (descending), PunctumLineBL, and VirgaBaseLineBL for a virga base join. Requires the parser to record fusion intent (currently '@' and soft fusion are dropped per the file header note 'Complex fusions (@) not yet handled').

## 15. [MEDIUM/medium] (rhythmic-signs) Horizontal episema drawn as a generic geometric bar instead of the shape-specific HEpisema glyphs
**Desejado:** Solesmes/Gregorio render the horizontal episema as a thickened bar whose LENGTH and VERTICAL position match the specific notehead it sits on (punctum vs virga vs quilisma vs inclinatum vs oriscus), and which may sit above OR below depending on the note's staff position and neighbouring episemata; consecutive episemata on adjacent notes fuse into one continuous bar.
**Como:** Greciliae ships per-shape episema glyphs: HEpisemaPunctum (E160-area), HEpisemaVirga, HEpisemaQuilisma, HEpisemaInclinatum, HEpisemaInclinatumDeminutus, HEpisemaAscendensOriscus, HEpisemaStropha, HEpisemaHighPes, HEpisemaFlexusDeminutus, plus directional LineTL/TR/BL/BR variants and a generic HEpisemaBarStandard for fusion. Render the episema by picking the HEpisema* glyph that matches the component's NcForm/role and overprinting it on the note (anchor via centerYUnits), instead of drawing a line. Use HEpisemaBarStandard scaled to span the run when adjacent components both carry episema.

## 16. [MEDIUM/medium [MODEL CHANGE]] (rhythmic-signs) Episema cannot be placed below the note; no above/below model field, so high-staff notes get a colliding episema
**Desejado:** GregorioTeX places the horizontal episema below the note when the note is high on the staff or when the neume shape requires it (e.g. the lower note of a clivis, the bottom of a porrectus), to avoid colliding with the staff line above and to follow Solesmes convention. The placement side must be derivable per component.
**Como:** Add an `EpisemaPlacement {auto, above, below}` field (or `episemaBelow` bool) to NeumeComponent; default `auto` chooses below when steps[i] is in the upper third of the staff or for the geometrically-lower component of the neume. Greciliae provides the directional bar glyphs (HEpisemaPunctumLineBL/BR for below-attached) to render the below case cleanly.

## 17. [MEDIUM/medium] (rhythmic-signs) Quilisma and oriscus are flagged but their characteristic rhythmic/expressive treatment is partial; pressus/oriscus-flexus not modeled
**Desejado:** Pressus (oriscus fused to a same-pitch note), oriscus-flexus, and the salicus (with its mandatory ictus on the oriscus) should select the correct precomposed glyph and carry their expressive mark.
**Como:** Use the Greciliae FlexusOriscus*, PesAscendensOriscus*/PesDescendensOriscus*, and AscendensOriscusScapus* families for these shapes; in _classify require an ictus on the oriscus to confirm a salicus and auto-attach a _MarkType.ictus to the oriscus component when emitting it (research gotchas[7]).

## 18. [MEDIUM/medium] (rhythmic-signs) Episema length does not extend across a multi-note slur/fusion (no fused/long episema)
**Desejado:** When two or more consecutive notes carry an episema (or a GABC long-episema marker), Solesmes engraves a single continuous horizontal bar spanning them.
**Como:** After building marks, coalesce runs of adjacent episema marks (same step band, contiguous compX) into one bar; render with HEpisemaBarStandard / HEpisemaBarStandardReduced scaled to the run width rather than emitting N separate short bars.

## 19. [MEDIUM/medium [MODEL CHANGE]] (pitch-clef-modal) Inline accidental scope is not modelled at all in rendering (no word/divisio reset)
**Desejado:** A chant accidental governs that pitch for the rest of the WORD or until the next bar (whichever comes first), then reverts — GABC/Solesmes rule. The renderer must apply the alteration to following same-pitch notes (for any cautionary printing / playback consistency) and reset it at both word and divisio boundaries.
**Como:** Preserve word boundaries in the element stream (add a lightweight word-break marker or group neumes per word) so both render and chant_midi_mapper can reset accidentals at word ends, not just at NeumeDivision. Then run the same alter-map state machine in the renderer. Note GABC also has soft accidentals (X/Y, ##) that print only conditionally — parser currently maps only x/y/# (gabc_parser.dart:252-256).

## 20. [MEDIUM/medium] (pitch-clef-modal) Custos orientation/vertical seating uses note anchor with asymmetric glyph bboxes
**Desejado:** The custos's pointer must sit exactly on the staff slot of the next system's first pitch, with up/down chosen by whether that pitch is high or low on the staff, and vertically registered by the glyph's own anchor (pointer tip), like Gregorio.
**Como:** Register custos by a per-glyph anchor (use the bbox data already in greciliae_glyphnames.json via GreciliaeFont.centerYUnits, or a custom pointer-tip anchor) instead of the shared _firstNoteAnchor; pick orientation from absolute staff position once vertical placement is clef-absolute. Long variants (CustosUpLong/DownLong, cp 57361/57358) exist for larger leaps.

## 21. [MEDIUM/medium [MODEL CHANGE]] (layout-spacing) Uniform neume-to-neume spacing — not proportional to glyph content or melodic context
**Desejado:** GregorioTeX spaces neumes by a contextual table: tighter glue between notes of the same syllable, wider between syllables/words, and adjustments for neume type and the pitch gap between the previous neume's last note and the next neume's first note (so a wide melodic leap gets more air). Notes within one syllable (a melisma) cluster; word boundaries open up.
**Como:** Replace the flat gap with a spacing function gap(prev,next) keyed on: (a) same-syllable vs new-syllable boundary (need a per-neume `wordBoundary`/`syllableStart` flag — the parser already knows this since `_parseSyllable` flushes per syllable), (b) Gregorio's interneumatic vs intersyllabic vs interword classes (cf. GREGORIAN_RESEARCH spacing tokens !, /!, /0 intra-neume vs /, // inter-neume — currently all collapse to flushSegment with no width distinction). Carry the GABC space class onto the element so the layout can emit small/medium glue.

## 22. [MEDIUM/medium [MODEL CHANGE]] (layout-spacing) No melisma grouping: many neumes on one syllable are not kept together
**Desejado:** A melisma (one syllable, many neumes) should render as a tightly-spaced run that stays visually grouped, ideally not split across a system break, with the syllable left-aligned under the first neume and any GABC melisma extender handled. This is the chant analogue of CMN melisma (PROGRESS #13).
**Como:** Group consecutive neumes sharing a syllable into a melisma unit (first has text, followers have null). Tag followers with a `melismaContinuation` marker, give them intra-melisma (tight) glue, and prefer line-breaks at syllable/word/divisio boundaries rather than mid-melisma. The model fields exist implicitly (syllable==null on continuations); make it explicit with a `bool melismaStart`/group id on Neume.

## 23. [MEDIUM/medium [MODEL CHANGE]] (layout-spacing) System line-breaking ignores divisiones and word boundaries (breaks mid-word)
**Desejado:** Solesmes/Gregorio break lines at musical phrase boundaries: preferentially at a divisio (bar) or at least at a word/syllable boundary, never mid-neume-group/mid-melisma. Lines are balanced so each system is reasonably full.
**Como:** Implement a Knuth-Plass-style or greedy-with-penalties break that only allows breaks at divisiones and word/syllable boundaries (penalize/forbid breaks inside a melisma run identified above). Carry breakpoint candidates (divisio elements + first-neume-of-syllable) and choose the last legal candidate before overflow. Requires the wordBoundary/melisma metadata from the spacing/melisma gaps above.

## 24. [MEDIUM/medium [MODEL CHANGE]] (layout-spacing) GABC intra-neume vs inter-neume space tokens are all collapsed to one break with no width
**Desejado:** Per GREGORIAN_RESEARCH, ! keeps notes in the same neume but breaks the ligature with zero added space; /! tiny; /0 half; / small neumatic cut; // medium — each a different glue width that the layout must honor. This is the source data the proportional-spacing engine needs.
**Como:** Parse the space tokens into an explicit glue class and attach it to the following neume (or emit a lightweight Spacing element). Distinguish `//` from `/` by lookahead (the switch at gabc_parser.dart:165 currently has no `//` case). Map classes to widths: zeroBreak=0, tiny≈0.15sp, half≈0.4sp, small≈0.6sp, medium≈1.0sp, consumed by the gap() function.

## 25. [MEDIUM/medium [MODEL CHANGE]] (text-structure) No syllable hyphenation between neumes of the same word
**Desejado:** Solesmes/Gregorio engraving draws a hyphen between syllables of the same word, and when two syllables are far apart it draws a centered (or repeated) hyphen so the eye keeps the word together; a syllable immediately followed by another of the same word that touches gets a hard hyphen. The last syllable of a word gets none.
**Como:** With the syllable-position model above, in the layout pass compute the gap between syllable boxes that share a wordId; if the next syllable belongs to the same word, draw a short hyphen at lyric baseline midway between the two syllable boxes (GregorioTeX uses a centered hyphen; for wide gaps repeat). This is pure Canvas (drawText '-') — no Greciliae glyph needed; reuse the _lyric TextPainter for metrics.

## 26. [MEDIUM/medium [MODEL CHANGE]] (text-structure) No melisma extender line / lyric centering for one syllable over many neumes
**Desejado:** On a melisma the syllable text should be centered under (or left-aligned to the start of) the whole melismatic run, and the last syllable of a word that ends on a melisma draws an extender/underscore line under the remaining neumes (GregorioTeX 'translation/centering' + the protrusion rule). The accent/center of the syllable aligns under the first note per GREGORIAN_RESEARCH.json text-layer note.
**Como:** Group consecutive neumes with no new syllable into one melisma span (track span start/end x in _NeumeBox layout). Center the syllable under the span; if the word ends here and the span is long, draw a thin baseline rule from end-of-text to the last neume. Needs the isMelisma/span info from the syllable-model change.

## 27. [MEDIUM/medium [MODEL CHANGE]] (text-structure) No translation line under the lyrics
**Desejado:** GregorioTeX supports a vernacular translation line set in a distinct (usually italic) style below the Latin underlay, segment-aligned to the chant. Editor-grade books routinely show Latin + translation.
**Como:** Add a translation track (List of {text, anchorNeumeIndex}) parsed from GABC bracket-translation syntax '[...]' appended to a syllable, rendered as an extra italic band below the last verse using the same x anchoring as _lyric. Reuse styled-run rendering from the markup gap.

## 28. [MEDIUM/medium [MODEL CHANGE]] (text-structure) Accent-based lyric centering is not implemented (text is box-centered)
**Desejado:** GABC/Gregorio align the syllable so its CENTER (the accented vowel, or the {..} marker) sits under the neume's first note, with text protruding left/right of the note as needed — not naive box-centering. This is explicit in GREGORIAN_RESEARCH.json: 'the first vowel/center of the syllable aligns under the neume's center'.
**Como:** Compute the syllable's center offset: honor an explicit {..} index if present, else apply a Latin-accent heuristic (last stressed vowel) to find the center character; lay the text so that character's x equals the neume's first-note x (compX[0]+startX). Replace the box-midpoint call at gregorian_renderer.dart:591.

## 29. [MEDIUM/medium] (text-structure) Headers (title, mode, annotation, commentary) are parsed but never rendered
**Desejado:** A chant book shows the piece title (often centered above), the mode/annotation in the top-left over the clef (e.g. 'VIII', '* III a'), and commentary/source bottom-aligned. These are standard structural furniture of an editor-grade page.
**Como:** Thread result.headers into GregorianLayout/GregorianPainter; render 'name'/'office-part' as a heading, 'annotation' (1-2 lines) above the first system's clef area, 'commentary'/'mode' as configured. Pure text; reserve top margin in totalHeight().

## 30. [MEDIUM/medium [MODEL CHANGE]] (gabc-coverage) Virgula (`) mis-mapped to divisio minima; rich Greciliae divisio glyphs unused
**Desejado:** Virgula is its own division (small tick at top of staff), distinct from divisio minima. Divisiones should ideally use the engraved Greciliae glyphs for authenticity (dotted maior, dominican bar, etc.).
**Como:** Add NeumeDivisionType.virgula and map '`' to it. The font HAS the glyphs: 'VirgulaTwo'..'VirgulaSix', 'DivisioMinimaTwo'..'Six', 'DivisioMinorTwo'..'Five', 'DivisioMaiorTwo'..'Five' (and dotted/backing variants, 'DivisioDominican'). Note: there is genuinely NO 'DivisioFinalis'/'DivisioMaxima' glyph (confirmed absent) — finalis must stay geometric (double maior). The Two..Six suffix selects staff height, so pick by staff context.

## 31. [MEDIUM/medium [MODEL CHANGE]] (gabc-coverage) Intra- vs inter-neume spaces collapsed: '!', '/', '//', '/0', '/!' all behave identically
**Desejado:** '!' = zero-width ligature break (notes stay tight, no added gap); '/' = small neumatic cut; '//' = larger cut; '/0','/!' = tiny intra-neume spaces; '/[n]' = scaled space. The horizontal gap should reflect the token.
**Como:** Carry a space-width hint between segments instead of a boolean flush. Emit segment-break records with a width class (zero/tiny/small/medium/scaled) that GregorianLayout.build consumes when computing 'gap' between _NeumeBox items (currently a single 'gap = sp*0.85'). Parse the optional digit after '/' for the scale factor.

## 32. [MEDIUM/medium [MODEL CHANGE]] (gabc-coverage) Pes quadratum (q) and note-fusion (@) operators ignored
**Desejado:** 'q' produces a pes quadratum (square-topped pes, second note to the right of the connecting bar); '@' forces fusion of adjacent notes into one ligature glyph.
**Como:** Recognize 'q' as a pes-quadratum modifier and select Greciliae 'PesQuadratumTwoNothing'/'PesQuadratumTwoAscendens'/... (full ambitus set present, incl. Longqueue and InitioDebilis variants). Treat '@' as a fusion flag that forces neighboring components into a single _neumeGlyphName lookup.

## 33. [MEDIUM/medium] (gabc-coverage) Rendering headers (initial-style drop cap, annotations, mode) ignored
**Desejado:** Editor-grade engraving renders the large drop-cap initial, the annotation (e.g. 'VIII' mode / incipit) above the staff, and respects the {} manual syllable-centering point.
**Como:** Have GregorianLayout consume headers (annotation/mode/initial-style) and reserve a drop-cap box on the first system; preserve the {} centering offset through _cleanText into the lyric placement (currently lyrics are simply centered on the neume box). No font glyph needed for the initial (text), but neume centering should honor the marked vowel.

## 34. [MEDIUM/large [MODEL CHANGE]] (neume-repertoire) Pressus not modeled or rendered (no NeumeType, no glyph selection) despite full Greciliae support
**Desejado:** Render the pressus (and pressus maior) as the fused oriscus engraving: two same-pitch elements drawn as an oriscus joined to the following punctum/clivis with the heavy fused stroke, per GregorioTeX.
**Como:** Greciliae ships the building blocks: FlexusOriscus###Nothing (oriscus then descending note = the core pressus motion), PesQuassus###Nothing (oriscus-fused ascending), and the standalone AscendensOriscus/DescendensOriscus. Add NeumeType.pressus (or reuse oriscusGroup) and a _neumeGlyphName case: when two adjacent components share a pitch and the second is NcForm.oriscus (GABC 'oo'/repeated o), emit FlexusOriscus for the descending exit. Detect in _classify by same-pitch-with-oriscus per the research gotcha ('pressus = repeated/fused same-pitch via oriscus+note').

## 35. [MEDIUM/large] (rhythmic-signs) Mora/episema/ictus attach to a uniformly-spread component x within a precomposed glyph — wrong note for many neumes
**Desejado:** A mark must sit exactly over/under the component it modifies. In GregorioTeX each precomposed neume has known per-component anchor offsets; the episema on the 2nd of a torculus, the mora on the porrectus' last note, and the ictus on the salicus' oriscus all register on the true sub-glyph x.
**Como:** Build a per-neume anchor table mapping (NeumeType, ambitus-word combo) -> list of component x-fractions, derived from Greciliae glyph metrics or hard-coded from GregorioTeX gtex offsets. For shapes that cannot be reliably sub-anchored, decompose into component glyphs (Punctum/Virga/PunctumInclinatum + connecting Linea) so each note has a real x. Replace the (i+0.5)/n heuristic with this table.

## 36. [MEDIUM/large [MODEL CHANGE]] (pitch-clef-modal) Mid-line clef changes are parsed then silently dropped (renderer draws only the first clef)
**Desejado:** A clef written in a new (clef) group mid-score must render an in-line clef-change glyph at that horizontal position and re-anchor all following pitches to the new clef line, exactly like Gregorio. Common in long chants that shift tessitura.
**Como:** Add a ClefChange element (e.g. `class NeumeClef extends MusicalElement { final ChantClef clef; }`) to neume.dart; emit it from the parser where a clef token is seen after the first. In the layout, treat it as an inline item (like _Divisio) that updates the active clef anchor for subsequent boxes, and draw it with the smaller change glyphs CClefChange / FClefChange (present in greciliae_glyphnames.json, cp 57355 / 57402) rather than the full CClef/FClef.

## 37. [MEDIUM/large [MODEL CHANGE]] (text-structure) GABC text markup <i> <b> <sp> <v> and {} centering are stripped, not rendered
**Desejado:** Editor-grade rendering must keep styled runs (italic/bold/small-caps/underline/color) and honor <sp> special characters (e.g. <sp>R/</sp> response sign, <sp>ae</sp> ligature, <sp>'oe'</sp>) and the {..} manual centering point that overrides automatic accent centering. <v>..</v> passes raw TeX/markup through verbatim.
**Como:** Parse the text layer into styled runs instead of a flat String (List<TextRun{text, italic, bold, smallCaps, ...}>), render with a TextSpan tree in _lyric. Map <sp> tokens to substitutions: 'ae'/'oe' to ligature codepoints, 'R/' and 'V/' to the response/versicle signs (Greciliae has no Rbar/Vbar glyph — draw the barred R/V geometrically or use Unicode ℟ U+211F / ℣ U+2123). Honor {..} as the centering anchor x for the syllable.

## 38. [MEDIUM/large [MODEL CHANGE]] (text-structure) No multiple text lines / verses (psalm verses, multi-stanza)
**Desejado:** Chant books stack several aligned text lines under one melody (multiple psalm verses, or verse + Latin variant) and, separately, psalm-tone verses pointed under one formula. Each verse needs its own underlay row, vertically stacked, sharing the neume x-positions.
**Como:** Add verseIndex to the syllable model; in GregorianLayout reserve N lyric bands (rowHeight += verseCount * lyricLeading) and in paint() loop verses, drawing each at lyricTop + v*leading. GABC itself is single-verse, so also expose an API to supply extra verse text lines aligned to neume indices.

## 39. [LOW/small] (neume-repertoire) Oriscus direction ignored: standalone/leading oriscus always uses AscendensOriscus
**Desejado:** An oriscus leans toward the next note: ascending context uses the ascending oriscus, descending context the descending oriscus; a liquescent oriscus uses the diminished form.
**Como:** Pick by the following component's pitch relative to this one: next-higher -> AscendensOriscus, next-lower -> DescendensOriscus (both exist in the font), and OriscusDeminutus for the liquescent/diminished standalone oriscus. _singleGlyph currently only sees the form, not neighbours; pass the contour (or compute in _emitNeume where steps[] is available).

## 40. [LOW/small] (neume-repertoire) Bivirga/trivirga classified but spacing not tuned; no virga strata or pressus-from-virga
**Desejado:** Repeated virgae sit closer together as a recognizable bivirga/trivirga unit; virga strata (virga + oriscus at same/upper pitch) uses the oriscus-fused engraving.
**Como:** Reduce inter-virga advance for bivirga/trivirga; for virga strata reuse PesQuassus###Nothing (oriscus-topped) or AscendensOriscus over the virga. No precomposed bi/trivirga glyph exists (Gregorio repeats Virga too) so spacing is the only fix here.

## 41. [LOW/small] (rhythmic-signs) Vertical episema (ictus) drawn as a plain stroke instead of the Greciliae VEpisema glyph
**Desejado:** The ictus (vertical episema) is a short thick vertical tick with the typographic weight and shape of the Solesmes mark, registered precisely under (or over) the note center.
**Como:** Use the font glyph VEpisema (codepoint 57441) for the standard ictus and VEpisema.circumflexus (57442) for the circumflex variant, overprinting at the note center x and seating its bbox (the glyph's y bbox is -18..91 font units) just below the notehead. Falls back to the current line only if font.has fails.

## 42. [LOW/small [MODEL CHANGE]] (rhythmic-signs) GABC episema/ictus directional suffixes (_0/_1, '0/'1) are dropped, so editor round-trips lose placement intent
**Desejado:** GABC encodes placement: `'` ictus default, `'0` below, `'1` above; `_` episema, with `_0`.._5 selecting the episema position/length. State-of-the-art import preserves these so the engraver and a later GABC export agree with Gregorio.
**Como:** In the modifier scanner, after matching '_' or "'", peek the next char: if it is a digit, consume it and map to the placement field — "'1" -> ictusAbove=true, "'0" -> below; `_0`.._5 -> episema placement/offset. Wire ictusAbove (already on NeumeComponent) and the new episema-placement field through.

## 43. [LOW/small] (pitch-clef-modal) Standalone accidental glyph placed without horizontal padding from the governed note
**Desejado:** An accidental should hug the note it governs (small fixed kern), not float at a generic neume gap, matching Gregorio engraving where the sign sits immediately left of its note.
**Como:** Give accidental-sign boxes a reduced trailing gap (or merge the sign into the following neume's box as a left-attached glyph) in GregorianLayout.build's spacing loop (around gregorian_renderer.dart:363-375). Minor but visible at editor grade.

## 44. [LOW/small] (layout-spacing) Justification distributes slack by item count, not by spacing proportions
**Desejado:** Justification should scale the existing (content-proportional, context-weighted) glue, so tight intra-melisma gaps stay tight and inter-word/divisio gaps absorb most of the stretch — preserving the rhythm of the line rather than evenly fattening every gap.
**Como:** Once gap() returns per-boundary base widths (see proportional-spacing gap), justify by distributing (avail - sumGlyphs) proportionally to each gap's base width / stretchability, not (avail-sumW)/items.length. Give divisio gaps and interword gaps higher stretch weight than intra-neume gaps.

## 45. [LOW/small] (layout-spacing) Precomposed multi-note neume treats stacked/oblique glyphs as if notes spread horizontally across the advance
**Desejado:** Mark (episema/ictus/mora) and lyric anchors must land on the true sub-glyph note centers. A pes has both notes at ~the same x; a torculus has three distinct x's matching the glyph art; a porrectus first two notes share the oblique start.
**Como:** Maintain a small per-NeumeType table of fractional sub-glyph x-offsets (e.g. pes -> [0.5,0.5]; torculus -> [0.1,0.5,0.9]; porrectus -> [0.15,0.15,0.85]) calibrated against the Greciliae glyph art, instead of the uniform (i+0.5)/n spread. This fixes mora/episema/ictus placement and feeds the first-note lyric anchor.

## 46. [LOW/small] (layout-spacing) No clef/initial spacing reserve, and notesStartX is a fixed constant regardless of clef width or clef-flat
**Desejado:** The note start should be derived from the actual clef advance plus a small gap, and reserve room for a clef-flat (key-signature B-flat) when clef.flat is set, matching Gregorio's clef-to-first-note spacing.
**Como:** Compute notesStartX = clefX + font.advanceUnits(clef.glyphName)*scale + gap, and when clef.flat add the `Flat` glyph advance (Greciliae `Flat`, present) after the clef and include it in the reserve. Also render the clef-flat glyph (currently unrendered) just after the clef in paint().

## 47. [LOW/small] (gabc-coverage) Soft/parenthesized accidentals (X soft-flat, Y soft-natural, ## soft-sharp) unhandled
**Desejado:** Gregorio prints soft accidentals only conditionally (soft flat shown only if no flat already in force on that pitch, etc.). At minimum the parser should recognize X/Y/## as accidentals and render the parenthesized/cautionary glyph.
**Como:** Add cases for 'X','Y' and a two-char '#''#' lookahead in _buildNeume. Greciliae ships the exact cautionary glyphs: 'FlatParen','NaturalParen','SharpParen' (and *ParenHole) — map soft accidentals to these in _accidentalGlyph (gregorian_renderer.dart). Tie display to the accidental-state map from the persistence gap.

## 48. [LOW/small [MODEL CHANGE]] (gabc-coverage) Virga reversa (V) and oriscus scapus (O / o0 / o1) not distinguished from plain virga/oriscus
**Desejado:** V → virga reversa (stem on the left), distinct glyph; O → oriscus scapus (oriscus with a stem); o0/o1 force descending/ascending oriscus orientation.
**Como:** Add NcForm.virgaReversa and NcForm.oriscusScapus (and an orientation flag) to neume.dart, set them in _buildNeume, and map in _singleGlyph to the existing Greciliae glyphs 'VirgaReversa', 'AscendensOriscusScapus'/'DescendensOriscusScapus', and 'AscendensOriscus'/'DescendensOriscus' for o0/o1.

## 49. [LOW/small [MODEL CHANGE]] (gabc-coverage) Ancient performance signs (accentus, circulus, semicirculus) and quilisma-orientation not parseable
**Desejado:** Parse and render the rarer Solesmes/early-notation signs where present in source GABC.
**Como:** Lower priority for typical Liber Usualis chant. Greciliae provides 'Accentus','AccentusReversus','Circulus','Semicirculus','SemicirculusReversus' if these are added to the model as component marks.

## 50. [LOW/medium] (neume-repertoire) Salicus flexus, scandicus flexus, climacus resupinus have enum values but no glyph mapping
**Desejado:** Render these 4-note compounds as the single precomposed Greciliae glyphs that exist for every ambitus combination.
**Como:** Greciliae has full families: SalicusFlexus###(Nothing|Deminutus|Ascendens|Descendens) (3 ambitus words), and Scandicus### covers scandicus; scandicus flexus has no dedicated 'ScandicusFlexus' family so map it to SalicusFlexus only when an oriscus is present, otherwise assemble Scandicus + a flexus tail. For climacus resupinus there is no precomposed family (assemble climacus body + final Pes). Add the salicusFlexus case using up(0,1)/up(1,2)/dn(2,3) -> _word() triple like the existing porrectusFlexus case at lines 175-180.

## 51. [LOW/medium] (neume-repertoire) Trigon not modeled or rendered
**Desejado:** Render the trigon as its distinct three-note figure (two stacked puncta over a lower punctum), not as a climacus.
**Como:** Greciliae has no single 'Trigon' glyph, so engrave it from two Punctum (or PunctumInclinatum) at the upper pitch plus a lower Punctum with the trigon's characteristic spacing. Detect in _classify: 3 notes where steps[0]==steps[1] and steps[2] < steps[1]. Add a dedicated assembly branch rather than letting it fall into the climacus diamond path.

## 52. [LOW/medium [MODEL CHANGE]] (neume-repertoire) Liquescence selects only the diminished (deminutus) variant; augmentum (auctus) and ascending/descending liquescents unused
**Desejado:** Distinguish diminished liquescence (deminutus/cephalicus/epiphonus) from augmented liquescence (auctus, the larger 'opening' liquescent) and from the ascending vs descending liquescent variants, choosing the matching precomposed glyph.
**Como:** Greciliae exposes the full set: per-neume Ascendens / Descendens / Deminutus suffixes (e.g. Flexus#Ascendens vs Flexus#Deminutus, Pes#Deminutus, Torculus##Ascendens/Descendens/Deminutus). Map GABC '>' -> Deminutus, '<' -> Auctus/Ascendens depending on contour, '~' -> Deminutus. This needs a model change: NeumeComponent currently has only isLiquescent (bool); add a liquescence enum (none/deminutus/augmentumAscending/augmentumDescending) so the parser can preserve '<' vs '>' vs '~' instead of collapsing them at gabc_parser.dart:242-245.

## 53. [LOW/medium [MODEL CHANGE]] (neume-repertoire) Initio debilis (weak/diminished first note) ignored despite 766 Greciliae glyphs
**Desejado:** A neume marked initio debilis renders with the small/weak first note using the precomposed InitioDebilis glyph.
**Como:** Greciliae has Pes#InitioDebilis, Pes#InitioDebilisDeminutus, PesQuadratum#InitioDebilis*, Torculus##InitioDebilis*, TorculusResupinus###InitioDebilis*, LeadingPunctum#InitioDebilis. Parse a leading '-' in _buildNeume into a new NeumeComponent flag (e.g. initioDebilis:bool), then in _neumeGlyphName append 'InitioDebilis' before the liquescence suffix when the first component carries it.

## 54. [LOW/medium] (neume-repertoire) Sub-glyph component anchors faked by even spread, so episema/ictus/mora land off-note on precomposed neumes
**Desejado:** Marks and per-note registration use the true sub-glyph x-offsets so an episema sits over the correct note of a torculus/porrectus and a mora dot follows the correct note.
**Como:** The glyphnames JSON already stores bbox (the loader reads list[2]/list[3] for centerY). Extend the asset/loader to expose per-neume component x-anchor offsets (Greciliae/Gregorio publish these as the glyph's internal note positions), or hard-code per-shape fractional offsets per ambitus (porrectus: first/last at bbox edges, middle under the curve). Replace the uniform (i+0.5)/n spread with these.

## 55. [LOW/medium] (pitch-clef-modal) B-flat key (clef-flat) has no effect on accidental state or note rendering on the staff
**Desejado:** With a clef-flat in force, every B should be understood as B-flat for engraving/ledger/accidental-cancellation purposes; an explicit natural cancels it until the next divisio/word, after which the clef-flat resumes. This mirrors the key-signature semantics the playback layer already implements.
**Como:** Add a render-time accidental state machine parallel to chant_midi_mapper.dart:192-247: seed `alter['B'] = flat` from clef.flat, override with inline x/y/# per word, reset at NeumeDivision (and at word boundary). Use it to decide whether a B needs a printed cautionary natural/flat and to keep notation consistent with MIDI. No new glyph needed beyond Flat/Natural; consider FlatParen/NaturalParen (cp 57405) for cautionary accidentals.

## 56. [LOW/medium [MODEL CHANGE]] (pitch-clef-modal) No custos is emitted before a clef change (only at end-of-system)
**Desejado:** Whenever the clef changes mid-line, a custos showing the next note's pitch (read in the OUTGOING clef) must be drawn immediately before the new clef, so the singer can find the pitch across the clef switch — standard Gregorio/Solesmes behaviour.
**Como:** Once an inline clef-change element exists, in layout detect a clef change and inject a custos just before it using the next sounding note's step computed under the OLD clef anchor; draw with CustosUpShort/CustosDownShort (cp 57363 / 57360) as paint() already does for line-end custodes.

## 57. [LOW/medium [MODEL CHANGE]] (pitch-clef-modal) Two simultaneous clefs (c1@c4) not supported
**Desejado:** Parse and render two linked clefs for two-voice / split-staff chant, as Gregorio does.
**Como:** Extend the clef regex to optionally accept `@([cf]b?[1-4])` and model a paired clef. Lower priority than single mid-line clef changes; note it for completeness.

## 58. [LOW/medium] (text-structure) No drop/initial capital (large decorated first letter)
**Desejado:** Gregorio draws a large (often 2-line) decorative initial capital at the start of a piece, with the rest of the first word set normally beside it and the staff/lyrics indented to clear it (the classic Liber Usualis drop cap). Editors expect at least a configurable big initial.
**Como:** Add an 'initialLetters' count (GABC 'initial-style': 0 none / 1 normal-big / 2 drop) and render the first 1+ letters at a large fontSize spanning into the lyric+staff area, reserving left inset in the layout (shift notesStartX/clefX right for the first system). No font glyph needed; large serif capital is sufficient for v1.

## 59. [LOW/large [MODEL CHANGE]] (rhythmic-signs) No support for significative (Romanian) letters — c, t, m, x, etc.
**Desejado:** Editor-grade chant shows Romanian/significative letters (celeriter c, tenete t, mediocriter m, augete a, statim s, etc.) positioned above or below the note per the manuscript, as Gregorio does. These are central to semiological editions.
**Como:** Add a `List<SignificativeLetter>` field to NeumeComponent (letter char + above/below placement). Parse the GABC `[...]` / trailing-letter syntax in the modifier loop. Greciliae has NO precomposed letter glyphs (confirmed: no roman/significative names in greciliae_glyphnames.json), so render them as styled italic text from the lyric/text font, registered above (default) or below the note, matching Gregorio's text-layer approach.
