# Changelog

All notable changes to Flutter Notemus are documented in this file.

The format is based on Keep a Changelog and this project follows Semantic Versioning.

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
