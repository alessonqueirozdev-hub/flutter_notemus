# Open Issues Backlog

This file mirrors the current GitHub backlog for pending work in `flutter_notemus`.

GitHub issues remain the source of truth:
https://github.com/alessonqueirozdev-hub/flutter_notemus/issues

> **Reconciled with the code on 2026-08-22** (after the remediation waves that
> followed `doc/AUDITORIA_FORENSE_2026-08-21.md`). Each "current state" below was
> re-checked against the source; where a state changed, the line says what
> changed and where. Where nothing changed, the line stays as blunt as it was.

## Playback, audio, and export

1. Native audio backend parity for non-Android platforms
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1
   - Current state: **unchanged — one platform of six has a real engine.**
     Android is the only implementation
     (`android/src/main/cpp/native_audio_engine.cpp`, ~600 lines, plus the
     Kotlin plugin). iOS and macOS are 32-line `MethodChannel` shims whose
     `nativeInitialize`/`nativeIsReady` answer `false` and whose every transport
     method answers `nil`
     (`ios/Classes/FlutterNotemusPlugin.swift`,
     `macos/Classes/FlutterNotemusPlugin.swift`); Windows (64 lines) and Linux
     (84 lines) are the same shape. Nothing in the 2.7.0 remediation touched
     any of them.
   - Note on the Android engine itself: it is oscillator synthesis
     (sine/triangle/saw/square). A SoundFont can be handed to the API but is
     never loaded.

2. PDF export
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/2
   - Current state: **no longer a placeholder.** The exporter used to draw five
     empty staff lines behind a `// TODO: Implement actual music rendering`.
     It now lays the staff out with the same `LayoutEngine` the on-screen widget
     uses and rasterises the real notation into the page
     (`lib/src/export/score_rasterizer.dart`, driven from
     `lib/src/export/pdf_exporter.dart:291-331`).
   - Remaining limits, stated so this does not become the next overclaim: the
     page holds a **raster** image, not vector notation, so text is not
     selectable and zoom is resolution-bound; and rasterisation needs a live
     Flutter engine (a running app or `flutter_test`), so a caller in a plain
     Dart VM gets the staff **skipped with an explicit warning**, not silently
     empty pages (`pdf_exporter.dart:328-336`). Vector PDF output would need the
     single draw-op back-end described in §23 of the forensic audit.

3. Web playback shim is still a no-op
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/15
   - Current state: **unchanged.** `lib/flutter_notemus_web.dart` (44 lines)
     returns `false` from the readiness probe and `null` from everything else.
     Playback calls resolve without producing audio. This is the same stub as
     issue #1 above, on the sixth platform.

4. Production-ready MIDI and audio workflow
   - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/20
   - Current state: MIDI **generation** advanced in 2.7.0 — per-voice tracks and
     channels, solo/mute by voice and by staff, ornament expansion, grace notes
     that steal time, and octave-transposing clefs applied to the sounding pitch
     (`lib/src/midi/midi_mapper.dart`, `midi_models.dart`). The end-to-end
     playback/session API is still not consolidated, and it cannot be while five
     of six platforms are stubs (#1/#15). Region playback (a measure range) has
     no API yet.

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
    - Current state (2.6.0): largely addressed — public `GrandStaff` (one
      `StaffGroup`) and `ScoreView` (a whole `Score`) widgets now render
      multi-staff systems (grand staff, SATB, full score, cross-staff beaming,
      multi-system wrapping), and the example gallery uses them
      (`GrandStaffExample`). The legacy local multi-staff demo was retired.

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
    - Current state: still open, but the **blocking precondition is now met.**
      The forensic audit named the blocker precisely: the layout replaced the
      caller's `Note` objects with clones, so no element had a stable identity
      from model to screen and there was nothing to select. The layout no longer
      clones (`Note.beam` is written in place), and
      `test/invariants/engraving_invariants_test.dart` group L3 pins that down.
      Cursor, note entry, undo/redo and clipboard remain unimplemented.

17. Implement score hit-testing and interactive selection APIs
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/18
    - Current state: **first cut landed.** `ScoreHitTester`
      (`lib/src/interaction/score_hit_tester.dart`) does point hit-testing with a
      tolerance and a type ranking, rectangle selection, and selection by
      measure, system, voice and onset range — the last of these only being
      expressible because `PositionedElement` now carries `onset` and
      `measureIndex`. Not yet wired to gestures in the public widget, and there
      is no visual selection feedback.

18. Support real-time interactive score state and live playback feedback
    - Issue: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/19

## Alternative notation systems

19. Jianpu (numbered notation) rendering — GB/T 46845-2025 conformance epic
    - Epic: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/24
    - Request: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/21
    - Current state: **work in progress / experimental.** A `JianpuRenderer` /
      `JianpuScore` parallel to the SMuFL staff path now exists (reusing the
      notation-agnostic music model) and basic rendering is shown in the example
      gallery, but coverage is partial and the API may still change — not yet
      production-ready. Tracked section-by-section against GB/T 46845-2025 in
      epic #24 (phased: §6 MVP, §5 structure, §7 auxiliary). The SMuFL staff
      path stays untouched.

## Update policy

- Every pending feature or bug must have a GitHub issue.
- Update this file whenever an issue is opened, closed, or renumbered in the roadmap.
- If an issue is resolved in code, close the GitHub issue and update this file in the same commit.
