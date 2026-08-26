# Open work

**GitHub Issues is the source of truth**, and as of 2026-08-26 it actually is —
which it was not before. This file used to mirror the backlog issue by issue,
with a measured "current state" under each one. That mirror drifted: it was
still describing melisma extension lines, lyric hyphen centering, PDF
placeholder pages and score hit-testing as open work months after each of them
shipped.

A tracker and its mirror will always drift, and the mirror is the copy that
nobody re-reads. So the measurements moved into the issues themselves, where
the person deciding whether to pick the work up will actually see them, and
this file stopped being a second backlog.

https://github.com/alessonqueirozdev-hub/flutter_notemus/issues

## How the tracker is organised

Issues carry a domain label, not just `bug` / `enhancement`:

| Label | What it covers |
|---|---|
| `engraving` | Glyph placement, spacing, beams, stems, ties — how the notation looks on the page |
| `interop` | MusicXML, MEI and JSON import/export |
| `playback` | MIDI mapping, native audio backends, transport |
| `performance` | Layout and render cost, threading, large scores |
| `gregorian` | Square notation, neumes, Greciliae |
| `jianpu` | Numbered notation (简谱), GB/T 46845-2025 |
| `editor` | Hit-testing, selection, editing, live playhead |
| `api` | Public surface, naming, deprecations |
| `breaking-change` | Removes or changes public API; lands in a major release |
| `packaging` | pub.dev release, assets, archive contents, CI |

## Where the measurements live

Every finding this project has acted on was measured before and after, and the
numbers are kept in three places, none of which is a backlog:

- **`CHANGELOG.md`** — what changed in each release, with the before → after
  measurement inline. This is the one a consumer reads.
- **`doc/AUDITORIA_*.md`** — the forensic audits themselves, in full, including
  the findings that were **retracted** as wrong.
- **`doc/AUDITORIA_RECONCILIADA_2026-08-23.md`** — the reconciliation of two
  independent adversarial audits of 2.7.1 into one master list of 50, with the
  cross-coverage statistics and the four published headline numbers that do not
  reproduce.

## Standing rule

Nothing leaves the open list until a pass that **did not write the fix**
re-measures it. Four times in this project's history a shipped document
asserted that a delivered fix was still broken, and once the reverse — a
document asserted a fix that two waves had diagnosed and neither had applied.
The executable guards in `test/invariants/` exist because of that second case:
they fail the build rather than the prose.
