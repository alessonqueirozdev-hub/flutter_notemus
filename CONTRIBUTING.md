# Contributing to Flutter Notemus

Thank you for considering a contribution. This document is short on ceremony and
long on the two things that actually matter here: **how the project decides what
is correct**, and **what a change has to prove before it lands**.

## The one rule that explains all the others

> A claim about this engine is worth exactly as much as the measurement behind it.

Music engraving is full of rules that look right and are wrong by a quarter of a
staff space. This project has been through several adversarial audits, and every
one of them found defects that had passed review, passed the test suite, and been
frozen into a golden image. So the bar is not "it looks right" — it is "here is
the number, before and after".

That is why you will find dartdoc in this codebase that reads like a lab notebook:

```dart
/// The accidental term used to be a flat `staffSpace * 0.6`, which is smaller
/// than most accidentals and less than a third of a double flat. Measured: 32
/// sixteenths each carrying a double flat, compressed into 400 px, came out
/// 26.90 px apart — a 14.16 px notehead leaves 12.74 px of free space, and
/// `accidentalDoubleFlat` is 19.82 px wide, so it drove 7.08 px into the
/// previous notehead. The floor now asks the metadata.
```

Please write comments like that. Not on every line — only where a reader would
otherwise have to guess why a number is what it is.

## Getting set up

```bash
flutter pub get
flutter test
dart analyze
```

The suite is around 1000 tests and takes roughly two minutes. It must be green
before and after your change.

> **Gotcha:** running `flutter analyze` inside `example/` rewrites the root's
> package resolution and makes `package:pdf` unresolvable. If `dart analyze`
> suddenly reports errors in `lib/src/export/`, run `flutter pub get` at the repo
> root to restore it.

## What a pull request has to contain

1. **A test that fails before your change and passes after it.** If the defect
   cannot be expressed as a test, say so in the PR and explain why.
2. **The measurement.** Numbers, with units and the conditions they were taken
   under (`staffSpace`, canvas width, which font). "Fixed the spacing" is not a
   description; "the gap went from 26.90 px to 38.57 px at staffSpace 12" is.
3. **A green suite and a clean analyzer**, at the repo root and in `example/`.

## Engraving changes and golden images

`test/golden/` holds 53 reference images. If your change moves a pixel, several
will go red. That is expected and fine — what is *not* fine is re-recording them
without looking.

**Before running `flutter test --update-goldens`:**

- extract the committed image (`git show HEAD:test/golden/goldens/<name>.png`)
  and the produced one (`test/golden/failures/<name>_testImage.png`);
- compare them **zoomed, at 4x or more, nearest-neighbour**;
- say in the PR *what moved*, *why*, and *which change caused it*;
- judge each one as an engraver: better, equal, or worse.

**A golden you judge worse stays red.** A red golden is honest. A green one that
freezes a defect is not — and that has happened in this repository before: a
release re-recorded `m04m_tuplet_ratio` over a spacing regression that had
dropped the ink gap between adjacent noteheads from 15 px to 2 px, and the test
went green over it.

Useful references when judging: Elaine Gould, *Behind Bars*; the
[SMuFL specification](https://w3c.github.io/smufl/latest/); and this package's
own `assets/smufl/bravura_metadata.json`, which is the source of truth for every
engraving constant.

## Architectural rules the code enforces

These are not style preferences — there are tests that fail if you break them.

- **[ADR-001](doc/adr/ADR-001-layout-never-clones-the-model.md)** — the layout
  never replaces the caller's objects. Identity survives the whole pipeline,
  because an editor needs to hand back the very note you gave it.
- **[ADR-003](doc/adr/ADR-003-pitch-is-the-sounding-pitch.md)** — `Pitch` is
  invariant to the octave-transposing clef. The clef decides where a note is
  *printed*; the instrument's transposition applies only at the MIDI boundary.
- **[ADR-005](doc/adr/ADR-005-layout-decisions-are-values.md)** — layout
  decisions are **values owned by the layout result**, never mutations of the
  model. `LayoutEngine.beams` / `beamOf` publish beam membership; nothing in
  `lib/src/layout/` or `lib/src/rendering/` may write `Note.beam`.
  `test/invariants/adr005_guard_test.dart` scans `lib/` and fails, naming the
  file and line, if you do.

There is a matching guard for text rendering: every `TextStyle` handed to a
`TextPainter` must pass through `MusicTextFallback.withMusicTextFallback`, or be
on the explicit allow-list of SMuFL glyph painters in
`test/invariants/text_painter_provenance_test.dart`.

## Reporting a bug

Please use the issue templates. The single most useful thing you can include is
**the smallest score that reproduces it, written in Dart** — a `Staff` with two
or three measures beats a screenshot and a paragraph.

## Commit messages

Follow what is already in `git log`: a `type(scope): summary` first line, then a
body that states the defect, the measurement, and the fix. Long is fine. The
history is meant to be readable a year later by someone asking "why is this
number 1.9?".

## Code of Conduct

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).

## Licence

Contributions are licensed under [Apache 2.0](LICENSE), the project's licence.
