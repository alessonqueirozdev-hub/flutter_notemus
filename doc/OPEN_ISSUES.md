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

5. Staff group brace still uses a custom path instead of SMuFL brace workflow
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/3

6. Stem and flag primitives still need full engraving-default parameterization
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/4

7. `repeatBoth` still needs a robust fallback independent of a combined glyph
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/5

8. `MeasureValidator` must apply tuplet ratios when validating beat capacity
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/8

9. `SpacingResult` still needs width calculation for `Chord` and `Tuplet`
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/9

10. Slur/tie inter-note lyric hyphen centering still needs a second layout pass
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/14

## Examples, text, and content quality

11. `multi_staff_example` still depends on missing `MultiStaffRenderer` support
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/7

13. `Chord` elements still do not render `Note.syllables`
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/12

14. Melisma extension lines still need multi-note context
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/13

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
