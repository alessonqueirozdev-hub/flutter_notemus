# Gregorian (neume / plainchant) notation — implementation epic

**Goal:** bring `flutter_notemus` to editor-grade Gregorian chant support — render,
edit, and play square notation — usable inside full score editors.

**Why this is feasible natively:** the bundled Bravura font ships **67 SMuFL
`chant*` glyphs** — the complete component set (punctum, virga, quilisma,
oriscus, strophicus, podatus, ascending connecting lines 2nd–6th, descending
fused ligaturas 2nd–5th, do/fa clefs, 4-line staff, custos, divisiones, episema,
ictus, augmentum). Neumes are **assembled** from these components (as Gregorio
does), not drawn from precomposed neume glyphs.

**Honesty note:** Verovio already renders neume/chant. We are not parity-leading
there; the product goal is native Flutter/Canvas chant + editing + playback.
Reference standards used (see `doc/GREGORIAN_RESEARCH.json` for the full notes):
- **Gregorio / GABC** — https://gregorio-project.github.io/ (input format + neume rules)
- **SMuFL plainchant** — assembly recipes (geometric: baseline registration, no anchors)
- **music21 / chant21** — external validation (melodic/text only; NOT glyph shapes)
- **notationref** — feature-support JSON (no chant taxonomy yet → propose a PR)

---

## Architecture

A parallel notation path, like the Jianpu renderer (reuses the notation-agnostic
model, does not touch the SMuFL/CMN staff path):

- `lib/src/rendering/gregorian/gregorian_renderer.dart` — `GregorianTheme`,
  `ChantClef`, `GregorianLayout` (build), `GregorianPainter` (assembles chant
  glyphs by geometric/baseline registration).
- `lib/src/rendering/gregorian/chant_score.dart` — public `ChantScore` widget
  (loads Bravura like `MusicScore`).
- Model: reuses `lib/core/neume.dart` (`Neume`, `NeumeComponent`, `NcForm`,
  `NeumeType`, `NeumeDivision`).

### Key geometry rules (grounded in research)
- One diatonic **step = half** the inter-line gap (~0.51 sp). Off-by-2× is the
  classic bug.
- Glyphs are placed by their **SMuFL baseline origin** (no anchors on chant
  glyphs); registration via `computeDistanceToActualBaseline`.
- Ascending joins = thin **connecting lines** between two separately-drawn notes
  (registered at the bottom note). Descending pairs = **one fused ligatura**
  glyph (registered at the top note) — not two notes + a line.
- Overprint glyphs (`chantPodatusUpper`, `chantDeminutum*`) have advance 0 /
  negative-x bbox: keep the partner's X, translate only vertically.
- Chant has **no absolute pitch**; the do/fa clef only fixes where DO/FA sit.

---

## Phased roadmap

### Tier A — square-notation rendering MVP  ✅ (foundation landed)
- [x] 4-line chant staff (tiled `chantStaff`), do/fa clef, divisiones, syllables.
- [x] Single notes: punctum, virga, quilisma; ascending joins (pes/scandicus via
      connecting lines); descending puncta inclinata (climacus).
- [x] `ChantScore` widget + first golden (`chant_kyrie_tierA`).
- **Tier A simplifications to refine (Tier A+):** clef is a visual anchor
      (absolute pitch deferred); clivis should use the **fused** `chantLigaturaDesc`
      glyph (currently drawn as diamonds); torculus/porrectus not yet
      special-cased; single-line layout (no width wrapping / end-of-line custos);
      connecting-line X registration is approximate.

### Tier A+ — engraving correctness
- [x] Type-aware neume engine (per `NeumeType`): **fused clivis ligatura**, pes
      (stacked + connecting line), scandicus, climacus, torculus, porrectus;
      graceful fallback for unknown/compound forms.
- [x] Rhythmic/expressive marks: horizontal **episema**, **ictus** (vertical
      episema), **mora** (augmentum) dots — model fields + render.
- [x] **Multi-line wrapping** with per-system clef repetition + **end-of-line
      custos** showing the next system's first pitch.
- [ ] Liquescence (cephalicus/epiphonus via deminutum; auctum/asc/desc) — model
      has `isLiquescent`; needs glyph selection (deminutum/auctum) per neume.
- [ ] Refine geometry: fused-ligatura vertical registration, connecting-line X,
      torculus/porrectus apex/valley joins, clef vertical fit.
- [ ] Accidentals (movable Bb): flat/natural local-until-divisio; clef-flat.
- [ ] accentus/circulus/semicirculus marks; bivirga/trivirga spacing.

### Tier B — GABC import (Gregorio format)
- [ ] Parse the GABC header (`field: value;` … `%%`), then `syllable(notes)` stream.
- [ ] Pitch letters a–m = staff slots (relative to clef); clefs c1–4 / f1–4.
- [ ] Note shapes (v virga, w quilisma, o oriscus, s strophae, UPPER inclinatum),
      spaces (`!`, `/`, `//`), divisiones (`,` `;` `:` `::`), accidentals (x y #),
      liquescence (`~ < >`), marks (`. _ '`).

### Tier C — playback + editor support
- [ ] Anchor absolute pitch via the clef (mode/tonic) for chant→MIDI playback.
- [ ] Hit-testing + editable chant model (shares the editor roadmap, #16–#19).

### Validation & documentation
- [ ] `tool/validate_musicxml.py` (music21): export CMN via the existing
      `MusicXMLParser.staffToMusicXML` → assert pitches/durations/meter. (music21
      validates melody/text only — NOT neume glyphs; chant shapes stay on goldens.)
- [ ] Optional `chant21` spike for GABC melodic validation (isolated venv).
- [ ] `flutter_notemus.json` for notationref (start from `empty.json`, mark
      supported→1/partial→2). Propose a "Chant/neumes" taxonomy PR upstream.

### Tracking
This epic and the existing OPEN_ISSUES neume entry (#26 / MEI neume) cover the
same work; update both as tiers land. Goldens live under `test/golden/goldens/`.
