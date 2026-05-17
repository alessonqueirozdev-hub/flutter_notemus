# Open Issues Backlog

This file mirrors the current GitHub backlog for pending work in `flutter_notemus`.

GitHub issues remain the source of truth:
https://github.com/alessonqueirozdev-hub/flutter_notemus/issues

## Playback, audio, and export

1. Native audio backend parity for non-Android platforms
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1
   - Current state: iOS, macOS, Linux, and Windows still need real playback engines.

2. PDF export still uses placeholder score pages
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/2
   - Current state: metadata export is real, notation engraving export is not.

3. Web playback shim is still a no-op
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/15
   - Current state: playback calls resolve without producing real audio behavior.

4. Production-ready MIDI and audio workflow
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/20
   - Current state: end-to-end playback/export/session API still needs consolidation across platforms.

## Engraving and layout follow-up

5. Slur/tie inter-note lyric hyphen centering still needs a second layout pass
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/14
   - Current state: hyphen is glued to the syllable; centering between
     consecutive syllable X positions requires a post-layout pass.

Resolved in 2.6.0 (closed): #3 (SMuFL brace glyph workflow), #4 (stem/flag
engraving-default parameterization), #5 (robust `repeatBoth` fallback),
#8 (tuplet ratios in `MeasureValidator` — verified + tested; dead TODO removed),
#9 (`SpacingResult` `Chord`/`Tuplet` width & shortest-duration).

## Examples, text, and content quality

11. `multi_staff_example` still depends on missing `MultiStaffRenderer` support
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/7

12. Melisma extension lines still need multi-note context
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/13
    - Current state: a fixed 1-SS stub is drawn; the full extension to the
      next note's onset requires a post-layout pass (shared with #14).

Resolved in 2.6.0 (closed): #12 (`Chord` now renders `Note.syllables` via the
shared `NoteRenderer.renderSyllables`).

## Styling, editing, and interactivity roadmap

15. Expose comprehensive theming and styling controls across engraving primitives
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/16

16. Add editable score model and notation editing workflows
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/17

17. Implement score hit-testing and interactive selection APIs
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/18

18. Support real-time interactive score state and live playback feedback
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/19

## Update policy

- Every pending feature or bug must have a GitHub issue.
- Update this file whenever an issue is opened, closed, or renumbered in the roadmap.
- If an issue is resolved in code, close the GitHub issue and update this file in the same commit.
