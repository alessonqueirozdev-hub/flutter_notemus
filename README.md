# Flutter Notemus

[![pub.dev](https://img.shields.io/pub/v/flutter_notemus.svg)](https://pub.dev/packages/flutter_notemus)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.8.1+-blue.svg)](https://dart.dev/)
[![SMuFL](https://img.shields.io/badge/SMuFL-1.40-green.svg)](https://w3c.github.io/smufl/latest/)
[![MEI](https://img.shields.io/badge/MEI-v5%20CMN-green.svg)](https://music-encoding.org/guidelines/v5/content/index.html)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Professional music notation rendering for Flutter with SMuFL-compliant engraving, Bravura glyph support, a first-party notation-to-MIDI pipeline, and a **broad MEI v5 data model with CMN import/export** (see the [conformance section](#mei-v5-conformance) for what is imported/rendered vs. modeled).

---

## Project Links

- GitHub repository: https://github.com/alessonqueirozdev-hub/flutter_notemus
- pub.dev package: https://pub.dev/packages/flutter_notemus
- GitHub Pages (site/build): https://alessonqueirozdev-hub.github.io/flutter_notemus/
- Issue tracker: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues

---

## Table of Contents

- [Current Status](#current-status)
- [MEI v5 Conformance](#mei-v5-conformance)
- [Open Pending Work](#open-pending-work)
- [Highlights](#highlights)
- [Installation](#installation)
- [Required Initialization](#required-initialization)
- [Quick Start](#quick-start)
- [API Guide](#api-guide)
  - [MusicScore Widget](#musicscore-widget)
  - [Pitch and Notes](#pitch-and-notes)
  - [Durations](#durations)
  - [Rests](#rests)
  - [Measures and Staff](#measures-and-staff)
  - [Clefs](#clefs)
  - [Key Signatures](#key-signatures)
  - [Time Signatures](#time-signatures)
  - [Barlines](#barlines)
  - [Chords](#chords)
  - [Ties and Slurs](#ties-and-slurs)
  - [Articulations](#articulations)
  - [Dynamics](#dynamics)
  - [Ornaments](#ornaments)
  - [Tempo Marks](#tempo-marks)
  - [Grace Notes](#grace-notes)
  - [Tuplets](#tuplets)
  - [Beams](#beams)
  - [Octave Markings](#octave-markings)
  - [Volta Brackets](#volta-brackets)
  - [Polyphony and Multi-Voice](#polyphony-and-multi-voice)
  - [Grand Staff, Choir, and Full Scores](#grand-staff-choir-and-full-scores)
  - [Gregorian Chant (Greciliae)](#gregorian-chant-greciliae)
  - [Repeats](#repeats)
  - [Playing Techniques](#playing-techniques)
  - [Breath and Caesura](#breath-and-caesura)
  - [Import from JSON, MusicXML, and MEI](#import-from-json-musicxml-and-mei)
  - [MIDI Mapping and Export](#midi-mapping-and-export)
  - [Themes and Styling](#themes-and-styling)
- [Reference JSON Format](#reference-json-format)
- [Architecture](#architecture)
- [Development Checklist](#development-checklist)
- [License](#license)

---

## MEI v5 Conformance

flutter_notemus ships a **notation-agnostic data model that covers the breadth of MEI v5 concepts** — from CMN through tablature, mensural, neume, harmonic analysis and figured bass — defined in the [MEI v5 Guidelines](https://music-encoding.org/guidelines/v5/content/index.html).

**Important — what is actually imported/rendered vs. modeled.** MEI *import* and *rendering* focus on **Common Music Notation (CMN)**, which is well supported. Several advanced MEI modules exist in the data model (you can construct them in Dart) but are **not yet wired to the MEI parser/renderer** — they are marked *Model only* below. The table reflects what is genuinely imported and/or rendered, not just representable. (An adversarial audit found ~58% of catalogued items fully wired; the rest are model-only or partial.)

### Coverage by MEI v5 module

Legend: ✅ modeled **and** imported/rendered · ◐ partial (see note) · ○ *model only* (classes exist; no MEI import/render yet).

| MEI v5 Module | Status | Notes |
|---|---|---|
| **CMN — Pitch & Duration** | ✅ | `Pitch`, `Duration`, `DurationType` (maxima → 2048th) |
| **CMN — Events** | ✅ | `Note`, `Rest`, `Chord`, `Space`, `MeasureSpace` |
| **CMN — Measure & Staff** | ✅ | `Measure` (`@n`), `Staff` (configurable `lineCount`), `xml:id` |
| **CMN — Clef / Key / Meter** | ◐ | `Clef` (20 types) ✅; `KeyMode` and additive meter exist in the model but are **not parsed from MEI** yet |
| **CMN — Articulation** | ✅ | `ArticulationType` (17 types) |
| **CMN — Dynamics** | ◐ | `DynamicType` has 36 types; 9 are rendered, plus hairpins |
| **CMN — Ornaments** | ◐ | `OrnamentType` has 43 types; 33 mapped to glyphs |
| **CMN — Slur / Tie / Beam** | ✅ | `SlurType`, `TieType`, `BeamType`, `SlurEvent` (nested/numbered) |
| **CMN — Tuplets** | ✅ | `Tuplet`, `TupletBracket`, nested tuplets |
| **CMN — Polyphony** | ✅ | `Voice`, `MultiVoiceMeasure`, `StemDirection` |
| **CMN — Score structure** | ✅ | `Score`, `StaffGroup`, `ScoreDefinition` (`<scoreDef>`) |
| **CMN — Navigation** | ✅ | `RepeatMark`, `VoltaBracket`, `BarlineType` (15 types) |
| **Lyrics & Text** | ◐ | `Syllable`/`SyllableType` imported & rendered; `Verse` grouping not populated by the parser yet |
| **Metadata (meiHead / FRBR)** | ○ | `MeiHeader` & FRBR classes exist; **not parsed from MEI** |
| **Harmonic Analysis** | ○ | `HarmonicLabel`, `ScaleDegree`, `ChordTable` exist; **not parsed/rendered** |
| **Figured Bass** | ○ | `FiguredBass`, `FigureElement` exist; **not parsed/rendered** |
| **Microtonality** | ✅ | `AccidentalType` (sagittal, koma, quarter-tone) — modeled & rendered |
| **Solmization** | ✅ | `Pitch.fromSolmization()`, `Pitch.solmizationName` |
| **Tablature** | ◐ | `Note.tabFret/tabString` modeled & rendered; MEI `@tab.*` **import not implemented** |
| **Mensural Notation** | ○ | `MensuralNote`, `Ligature`, `Mensur` exist; **no MEI import/render** |
| **Neume Notation** | ◐ | rendered via **GABC/Gregorian**; MEI `<neume>` import not implemented |

### Key MEI v5 features

> These snippets show the **Dart model API** (constructing objects). For modules
> marked *Model only* / ◐ above (figured bass, mensural, full `meiHead`, MEI
> `<neume>`), the objects are constructible but are **not yet imported from MEI
> XML or rendered** — see the status table.

```dart
// xml:id on any element (MEI cross-referencing)
final note = Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter))
  ..xmlId = 'note-1';

// Explicit measure number (MEI <measure @n>)
final measure = Measure(number: 5);

// Configurable staff lines (MEI staffDef @lines)
final percStaff = Staff(lineCount: 1);      // percussion
final tabStaff  = Staff(lineCount: 6);      // guitar tab

// KeyMode (MEI @mode)
KeySignature(2, mode: KeyMode.dorian)

// Free-time measure (senza misura)
TimeSignature.free()

// Additive meter (3+2+2)/8
TimeSignature.additive(groups: [3, 2, 2], denominator: 8)

// Lyrics with syllabification (MEI <syl>)
Verse(number: 1, syllables: [
  Syllable(text: 'A-', type: SyllableType.initial),
  Syllable(text: 've', type: SyllableType.terminal),
])

// Figured bass (MEI <fb>/<f>)
FiguredBass(figures: [
  FigureElement(numeral: '6'),
  FigureElement(numeral: '4', accidental: FigureAccidental.sharp),
])

// Tablature (MEI @tab.fret @tab.string)
Note(
  pitch: Pitch(step: 'E', octave: 4),
  duration: Duration(DurationType.quarter),
  tabString: 1, tabFret: 0,  // open first string
)

// Mensural notation
MensuralNote(pitchName: 'G', octave: 3, duration: MensuralDuration.semibreve)
Mensur(tempus: 3, prolatio: 2)   // Tempus perfectum, prolatio minor

// Neume (Gregorian chant)
Neume(type: NeumeType.pes, components: [
  NeumeComponent(pitchName: 'F', octave: 3, form: NcForm.punctum),
  NeumeComponent(pitchName: 'G', octave: 3, form: NcForm.virga),
])

// MEI header (meiHead) — model API; not yet parsed from MEI XML
Score(
  staffGroups: [...],
  meiHeader: MeiHeader(
    fileDescription: FileDescription(
      title: 'Ave Maria',
      contributors: [Contributor(name: 'Schubert', role: ResponsibilityRole.composer)],
    ),
    encodingDescription: EncodingDescription(
      meiVersion: '5',
      applications: ['flutter_notemus'],
    ),
  ),
  scoreDefinition: ScoreDefinition(
    clef: Clef(clefType: ClefType.treble),
    keySignature: KeySignature(0),
    timeSignature: TimeSignature(numerator: 4, denominator: 4),
  ),
)

// Pitch class (MEI pclass) and solmization
Pitch(step: 'C', octave: 4).pitchClass        // → 0
Pitch(step: 'A', octave: 4).pitchClass        // → 9
Pitch.fromSolmization('sol', octave: 4)       // → G4
Pitch(step: 'G', octave: 4).solmizationName  // → 'sol'

// All MEI dur values including breve, long, maxima, and 256–2048
const Duration(DurationType.breve)
const Duration(DurationType.long)
const Duration(DurationType.maxima)
const Duration(DurationType.twoHundredFiftySixth)
DurationType.fromMeiValue('2048')  // → DurationType.twoThousandFortyEighth
```

For a full conformance audit see [`doc/MEI_V5_AUDIT.md`](doc/MEI_V5_AUDIT.md).

---

## Current Status

- Current package release target: `2.6.0`
- Previous pub.dev baseline: `2.5.1`
- Core notation rendering is production-ready; **multi-staff / grand-staff and
  cross-staff beaming** are now supported alongside single-staff `MusicScore`.
- MIDI mapping and `.mid` export are available in the package (CMN and chant).
- Android native audio backend is active; other native targets are configured and tracked as pending.

### What's New in 2.6.0

The library is no longer single-staff. This release adds a full multi-staff /
score renderer, cross-staff beaming, a sweep of Behind-Bars CMN corrections,
deeper MusicXML/MEI import, and Gregorian render-fidelity work — and also
consolidates the earlier engraving/typographic correctness pass that had not
yet reached pub.dev. Everything is backward-compatible — existing `MusicScore`
usage is unchanged. See the [CHANGELOG](CHANGELOG.md#260---2026-06-19) for the
full list.

- **Grand staff, choir, and full scores** — new [`GrandStaff`](#grand-staff-choir-and-full-scores)
  and `ScoreView` widgets render a `StaffGroup`/`Score` on a shared horizontal
  grid: piano grand staff, SATB, and multi-section systems, with SMuFL
  brace/bracket glyphs, system-spanning barlines, **multi-system wrapping**
  (clef/key restated per system), and **cross-staff beaming**.
- **MusicXML import → scores** — each part becomes a braced/bracketed
  `StaffGroup`; `<part-group>` section brackets and mid-beam `<staff>` changes
  (auto cross-staff) are honored.
- **CMN engraving** — chord-stem direction fix, Gould square-root /
  inter-onset spacing, mid-system clef/key/time changes, cue-size clef changes,
  cautionary/editorial accidentals, nested slurs, additive meters, tuplet
  ratios, sloped tuplet brackets, chord articulations, cross-voice notehead
  displacement, and more.
- **Gregorian chant** — episema/mora rendered with Greciliae glyphs
  (shape-specific episema), asymmetric divisio breathing, climacus/strophae
  tucking, custos length by leap.
- **Earlier engraving/typography pass** (also shipping here) — SMuFL `brace`
  glyph for staff-group braces, robust `repeatBoth` barlines, chord lyrics via
  the public `NoteRenderer.renderSyllables`, SMuFL-anchored stem/flag
  attachment, and `Chord`/`Tuplet`-aware spacing — closing issues
  [#3](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/3),
  [#4](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/4),
  [#5](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/5),
  [#8](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/8),
  [#9](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/9), and
  [#12](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/12).

### What's New in 2.5.1

- Stem-safe slur and tie routing now keeps curves on the notehead side for regular notes, grace notes, and chord ties.
- Arpeggio, tuplet, and octave-mark engraving were retuned for tighter alignment, clearer brackets, stronger contrast, and vertically centered score previews.
- The example gallery was refreshed with a Cupertino shell, restored non-redundant public demos, dedicated scroll controllers, white score canvases, and new lyrics/text coverage (`LyricsTextExample`).
- `ScorePreviewFrame` no longer forces a fixed bounded height on `MusicScore`; scores now render at their natural height, eliminating adaptive scale-down, clipped elements, and text overlap in example cards.
- Layout rendering preserves voice context during horizontal justification, while beaming retains the note metadata consumed by downstream renderers and parsers.
- `MusicScorePainter.shouldRepaint` uses a deterministic layout signature, backed by expanded regression coverage for spacing, grouping, articulation helpers, tuplets, SMuFL positioning, chord grouping, and example smoke tests.
- CI pipeline (`.github/workflows/ci.yml`) added — runs `flutter analyze`, `flutter test`, and `flutter pub publish --dry-run` on every push and pull request.
- All source comments and documentation strings migrated to English throughout the entire codebase (library, tests, and examples) — Issue #11 closed.
- Duplicate stem X-offset constants in `BeamRenderer` extracted into a single `_stemXOffset()` helper.

---

## Open Pending Work

All pending work is tracked as GitHub issues, with the local index mirrored in [`doc/OPEN_ISSUES.md`](doc/OPEN_ISSUES.md).

- Audio, export, and playback roadmap: [#1](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1), [#2](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/2), [#15](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/15), [#20](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/20)
- Engraving and layout follow-up: [#14](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/14) (inter-note hyphen centering — needs post-layout pass)
- Content and text rendering follow-up: [#13](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/13) (melisma extension lines — needs post-layout pass)
- Editor and interactivity roadmap: [#16](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/16), [#17](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/17), [#18](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/18), [#19](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/19)
- Remaining example/system integration work: [#7](https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/7)

---

## Highlights

### Core notation

- Notes from whole through 1024th durations
- Rests for all supported durations
- Accidentals (natural, sharp, flat, double sharp, double flat)
- Automatic ledger lines

### Clefs

- Treble, bass, alto, tenor, percussion, tablature
- Octave-transposing clef variants (8va, 8vb, 15ma, 15mb)

### Rhythm and layout

- Proportional rhythmic spacing
- Auto and manual beaming
- Tuplet support
- Collision-aware layout
- Multi-measure and multi-system rendering

### Symbols and expression

- Dynamics and hairpins
- Articulations
- Ornaments
- Tempo marks and text
- Ties and slurs
- Volta brackets, repeat symbols, and structural barlines
- Octave markings

### Multi-staff and polyphony

- Multiple voices in a single staff (`MultiVoiceMeasure`)
- Multi-staff score support (`Score`, `StaffGroup`)
- `GrandStaff` / `ScoreView` widgets rendering a group on a shared horizontal grid
- Grand staff scenarios (piano) with SMuFL `brace` and system-spanning barline
- SATB-style aligned staff rendering with `bracket` glyphs
- **Cross-staff beaming** (`Note.crossStaffMove`) — beams that cross between staves
- **Multi-system wrapping** with clef/key restated at each system start

### Gregorian chant (square notation)

- Greciliae font (SIL OFL) precomposed neumes — not geometry-built from CMN glyphs
- Punctum, virga, podatus/clivis, torculus/porrectus, scandicus/climacus, quilisma
- Liquescence, compound neumes, repeated notes, special neumes
- Episema and *mora* (augmentation dot) rendered with shape-specific Greciliae glyphs
- Divisio (minima/minor/maior/finalis) with asymmetric breathing space
- Custos (line-end guide) sized by the leap to the next system
- GABC import and `ChantScore` playback mapping

### Import and interoperability

- JSON parser
- MusicXML parser (`score-partwise` and `score-timewise`)
- MEI parser
- Unified normalization to the same internal model

### MIDI pipeline

- Notation-to-MIDI mapping from `Staff` and `Score`
- Repeat and volta expansion for playback timeline
- Tuplet/polyphony/tie-aware event generation
- Metronome track generation
- Standard MIDI file export (`MidiFileWriter`)

---

## Installation

Add dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_notemus: ^2.6.0
```

Install packages:

```bash
flutter pub get
```

---

## Required Initialization

Load Bravura and SMuFL metadata before rendering any score:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader('Bravura');
  loader.addFont(
    rootBundle.load('packages/flutter_notemus/assets/smufl/Bravura.otf'),
  );
  await loader.load();

  await SmuflMetadata().load();

  runApp(const MyApp());
}
```

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class SimpleScorePage extends StatelessWidget {
  const SimpleScorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 6),
      duration: const Duration(DurationType.quarter),
    ));

    staff.add(measure);

    return Scaffold(
      body: SizedBox(
        height: 180,
        child: MusicScore(staff: staff),
      ),
    );
  }
}
```

---

## API Guide

### MusicScore Widget

```dart
MusicScore(
  staff: staff,
  staffSpace: 12.0,
  theme: const MusicScoreTheme(),
)
```

### Pitch and Notes

```dart
Note(
  pitch: const Pitch(step: 'G', octave: 4),
  duration: const Duration(DurationType.quarter),
  articulations: [ArticulationType.staccato],
  tie: TieType.start,
  slur: SlurType.start,
  beam: BeamType.start,
)
```

Accidentals are encoded directly in `Pitch`:

```dart
const Pitch(step: 'F', octave: 5, alter: 1.0);   // sharp
const Pitch(step: 'B', octave: 4, alter: -1.0);  // flat
const Pitch(step: 'C', octave: 5, alter: 2.0);   // double sharp
const Pitch(step: 'D', octave: 4, alter: -2.0);  // double flat
```

### Durations

```dart
const Duration(DurationType.whole);
const Duration(DurationType.half);
const Duration(DurationType.quarter);
const Duration(DurationType.eighth);
const Duration(DurationType.sixteenth);
const Duration(DurationType.thirtySecond);
const Duration(DurationType.sixtyFourth);
const Duration(DurationType.oneHundredTwentyEighth);
```

Dotted durations:

```dart
const Duration(DurationType.quarter, dots: 1);
const Duration(DurationType.half, dots: 2);
```

### Rests

```dart
Rest(duration: const Duration(DurationType.whole));
Rest(duration: const Duration(DurationType.half));
Rest(duration: const Duration(DurationType.eighth));
```

### Measures and Staff

```dart
final staff = Staff();
final measure = Measure();

measure.add(Clef(clefType: ClefType.treble));
measure.add(TimeSignature(numerator: 3, denominator: 4));
measure.add(Note(
  pitch: const Pitch(step: 'C', octave: 5),
  duration: const Duration(DurationType.quarter),
));

staff.add(measure);
```

### Clefs

```dart
Clef(clefType: ClefType.treble);
Clef(clefType: ClefType.treble8vb);
Clef(clefType: ClefType.bass);
Clef(clefType: ClefType.alto);
Clef(clefType: ClefType.tenor);
Clef(clefType: ClefType.percussion);
Clef(clefType: ClefType.tab6);
```

### Key Signatures

```dart
KeySignature(0);   // C major / A minor
KeySignature(2);   // D major (2 sharps)
KeySignature(-3);  // E-flat major (3 flats)
```

### Time Signatures

```dart
TimeSignature(numerator: 4, denominator: 4);
TimeSignature(numerator: 3, denominator: 4);
TimeSignature(numerator: 6, denominator: 8);
```

### Barlines

```dart
Barline(type: BarlineType.single);
Barline(type: BarlineType.double);
Barline(type: BarlineType.final_);
Barline(type: BarlineType.repeatForward);
Barline(type: BarlineType.repeatBackward);
Barline(type: BarlineType.repeatBoth);
```

### Chords

```dart
Chord(
  notes: [
    Note(pitch: const Pitch(step: 'C', octave: 4), duration: const Duration(DurationType.half)),
    Note(pitch: const Pitch(step: 'E', octave: 4), duration: const Duration(DurationType.half)),
    Note(pitch: const Pitch(step: 'G', octave: 4), duration: const Duration(DurationType.half)),
  ],
  duration: const Duration(DurationType.half),
);
```

### Ties and Slurs

```dart
Note(
  pitch: const Pitch(step: 'C', octave: 5),
  duration: const Duration(DurationType.half),
  tie: TieType.start,
);

Note(
  pitch: const Pitch(step: 'D', octave: 5),
  duration: const Duration(DurationType.quarter),
  slur: SlurType.start,
);
```

### Articulations

```dart
Note(
  pitch: const Pitch(step: 'G', octave: 4),
  duration: const Duration(DurationType.quarter),
  articulations: [
    ArticulationType.staccato,
    ArticulationType.accent,
    ArticulationType.tenuto,
    ArticulationType.marcato,
  ],
);
```

### Dynamics

```dart
Dynamic(type: DynamicType.piano);
Dynamic(type: DynamicType.mezzoForte);
Dynamic(type: DynamicType.forte);
Dynamic(type: DynamicType.crescendo);
Dynamic(type: DynamicType.diminuendo);
```

### Ornaments

```dart
Ornament(type: OrnamentType.trill);
Ornament(type: OrnamentType.mordent);
Ornament(type: OrnamentType.turn);
Ornament(type: OrnamentType.fermata);
```

### Tempo Marks

```dart
TempoMark(
  bpm: 120,
  beatUnit: DurationType.quarter,
  text: 'Allegro',
);
```

### Grace Notes

```dart
GraceNote(
  pitch: const Pitch(step: 'D', octave: 5),
  type: GraceNoteType.acciaccatura,
);
```

### Tuplets

```dart
Tuplet(
  actualNotes: 3,
  normalNotes: 2,
  elements: [
    Note(pitch: const Pitch(step: 'C', octave: 5), duration: const Duration(DurationType.eighth)),
    Note(pitch: const Pitch(step: 'D', octave: 5), duration: const Duration(DurationType.eighth)),
    Note(pitch: const Pitch(step: 'E', octave: 5), duration: const Duration(DurationType.eighth)),
  ],
);
```

### Beams

```dart
Note(
  pitch: const Pitch(step: 'E', octave: 5),
  duration: const Duration(DurationType.eighth),
  beam: BeamType.start,
);
```

### Octave Markings

```dart
OctaveMark(type: OctaveType.ottava);
OctaveMark(type: OctaveType.ottavaBassa);
OctaveMark(type: OctaveType.quindicesima);
OctaveMark(type: OctaveType.quindicesimaBassa);
```

### Volta Brackets

```dart
VoltaBracket(number: 1, length: 220);
VoltaBracket(number: 2, length: 180, hasOpenEnd: true);
```

### Polyphony and Multi-Voice

```dart
final measure = MultiVoiceMeasure();

final voice1 = Voice.voice1();
voice1.add(Clef(clefType: ClefType.treble));
voice1.add(TimeSignature(numerator: 4, denominator: 4));
voice1.add(Note(
  pitch: const Pitch(step: 'E', octave: 5),
  duration: const Duration(DurationType.quarter),
));

final voice2 = Voice.voice2();
voice2.add(Note(
  pitch: const Pitch(step: 'C', octave: 4),
  duration: const Duration(DurationType.half),
));

measure.addVoice(voice1);
measure.addVoice(voice2);
```

### Grand Staff, Choir, and Full Scores

`MusicScore` renders a single `Staff`. To render several staves **vertically
stacked and aligned on a shared horizontal grid** — a piano grand staff, an
SATB choir, or a full multi-section score — use the `GrandStaff` widget (one
`StaffGroup`) or `ScoreView` (a whole `Score`).

A `StaffGroup` is a list of staves plus the connector drawn at the left edge:

| `BracketType` | Glyph | Typical use |
| --- | --- | --- |
| `brace`   | `{` (SMuFL `brace`) | Keyboard — piano, organ, harp |
| `bracket` | `[` (SMuFL `bracketTop`/`bracketBottom`) | Choir (SATB), orchestral sections |
| `line`    | `\|` | Multiple desks of the same instrument (Vln I & II) |
| `none`    | — | Independent staves |

```dart
// Piano grand staff: two staves joined by a brace, barlines connected,
// system-spanning start barline drawn automatically.
GrandStaff(
  group: StaffGroup.piano(trebleStaff, bassStaff),
);

// or explicitly:
GrandStaff(
  group: StaffGroup(
    staves: [soprano, alto, tenor, bass],
    bracket: BracketType.bracket, // choir
    name: 'Choir',
  ),
);
```

There are convenience factories for common ensembles: `StaffGroup.piano`,
`.organ`, `.harp`, `.choir`, `.strings`, `.woodwinds`, `.brass`, `.percussion`,
and `.multipleInstruments`.

**Full scores.** A `Score` holds multiple `StaffGroup`s. `ScoreView` lays every
group out on a single unified grid (a true multi-section system):

```dart
final score = Score(staffGroups: [choir, piano]);
ScoreView(score: score);
```

**Multi-system wrapping.** When the music is wider than the available width,
`GrandStaff`/`ScoreView` break into stacked systems automatically, **restating
the clef and key signature at the start of every system** and keeping all staves
aligned on the same break points (ragged-right, Behind-Bars style).

**Cross-staff beaming.** In keyboard music a beamed group can cross between the
two staves. A note keeps its *home* staff (for voicing, beaming, and spacing)
but its notehead is drawn on another staff via `Note.crossStaffMove`:

```dart
Note(
  pitch: const Pitch(step: 'C', octave: 4),
  duration: const Duration(DurationType.eighth),
  beam: BeamType.begin,
  crossStaffMove: -1, // draw this notehead one staff up; beam crosses the gap
);
```

`0` = home staff, `-1` = one staff up, `+1` = one staff down. The grand-staff
renderer routes the beam and stems across the staff gap to the displaced
noteheads. Cross-staff beams are also produced automatically on MusicXML import
when a `<staff>` change occurs mid-beam (see
[Import](#import-from-json-musicxml-and-mei)).

### Gregorian Chant (Greciliae)

The library renders Gregorian **square notation** with the Greciliae font (SIL
OFL) — precomposed neume glyphs, *not* shapes assembled from common-music
noteheads. Use the `ChantScore` widget. The fastest path is GABC (the Gregorio
project's plain-text chant format):

```dart
ChantScore.fromGabc(
  '(c4) Ký(h)ri(h)e(hgh) *(,) e(hg)lé(hi)i(h)son.(g) (::)',
);
```

`(c4)` is the clef (do/fa on a staff line), letters are pitches, `(,)`/`(::)`
are divisiones (breath marks / final), and modifiers encode episema, *mora*,
quilisma, liquescence, and compound neumes.

You can also build chant element-by-element with `Neume` / `NeumeDivision` and
render with an explicit clef:

```dart
ChantScore(
  clef: const ChantClef(type: ChantClefType.doClef, line: 4),
  elements: [
    Neume(/* components: punctum, podatus, clivis, … */),
    NeumeDivision(type: NeumeDivisionType.minor),
  ],
);
```

Rendering covers: punctum, virga, podatus/clivis, torculus/porrectus,
scandicus/climacus, quilisma, liquescence, compound and repeated neumes,
shape-specific horizontal episema and *mora* glyphs, asymmetric divisio
breathing space, climacus/strophae tucking, and a custos (end-of-line guide)
sized by the leap to the next system. Chant can be sent to MIDI with
`ChantMidiMapper` (see [MIDI](#midi-mapping-and-export)).

### Repeats

```dart
Barline(type: BarlineType.repeatForward);
Barline(type: BarlineType.repeatBackward);
Barline(type: BarlineType.repeatBoth);
```

### Playing Techniques

```dart
PlayingTechnique(type: TechniqueType.pizzicato);
PlayingTechnique(type: TechniqueType.colLegno);
PlayingTechnique(type: TechniqueType.sulTasto);
PlayingTechnique(type: TechniqueType.sulPonticello);
```

### Breath and Caesura

```dart
Breath();
Breath(type: BreathType.caesura);
Breath(type: BreathType.shortBreath);
```

### Import from JSON, MusicXML, and MEI

```dart
final jsonStaff = JsonMusicParser.parseStaff(jsonString);
final musicXmlStaff = MusicXMLParser.parseMusicXML(musicXmlString);
final meiStaff = MEIParser.parseMEI(meiString);

final autoDetected = NotationParser.parseStaff(sourceString);
```

### MIDI Mapping and Export

```dart
import 'dart:io';
import 'package:flutter_notemus/midi.dart';

Future<void> exportMidi(Staff staff) async {
  final sequence = MidiMapper.fromStaff(
    staff,
    options: const MidiGenerationOptions(
      ticksPerQuarter: 960,
      defaultBpm: 120,
      includeMetronome: true,
    ),
  );

  final bytes = MidiFileWriter.write(sequence);
  await File('score.mid').writeAsBytes(bytes, flush: true);
}
```

Native integration APIs:

- `MidiNativeAudioBackend`
- `MethodChannelMidiNativeAudioBackend`
- `MidiNativeSequenceBridge`

### Themes and Styling

```dart
MusicScore(
  staff: staff,
  theme: const MusicScoreTheme(
    staffLineColor: Colors.black,
    noteheadColor: Colors.black,
    stemColor: Colors.black,
    clefColor: Colors.black,
    barlineColor: Colors.black,
    dynamicColor: Colors.black,
    tieColor: Colors.black,
    slurColor: Colors.black,
    textColor: Colors.black,
  ),
)
```

---

## Reference JSON Format

```json
{
  "measures": [
    {
      "clef": "treble",
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "keySignature": 0,
      "elements": [
        { "type": "note", "step": "C", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "E", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "G", "octave": 5, "duration": "quarter" },
        { "type": "rest", "duration": "quarter" }
      ]
    }
  ]
}
```

---

## Architecture

```text
flutter_notemus/
├── lib/
│   ├── flutter_notemus.dart        # Public entry point
│   ├── midi.dart                   # Public MIDI entry point
│   ├── core/                       # Music model
│   └── src/
│       ├── midi/                   # MIDI mapping/export/native bridge
│       ├── layout/                 # Layout and spacing
│       ├── rendering/              # Renderers and positioning
│       ├── smufl/                  # Metadata and glyph references
│       ├── parsers/                # JSON, MusicXML, MEI parsers
│       └── theme/                  # Theme and style system
├── assets/smufl/                   # Bravura + metadata
├── android/ios/macos/linux/windows # Plugin/native targets
└── example/                        # Demo application
```

Rendering flow:

```text
Staff/Score -> LayoutEngine -> PositionedElements -> StaffRenderer -> Canvas
```

---

## Development Checklist

Typical local validation:

```bash
dart analyze
flutter test
flutter pub publish --dry-run
```

---

## License

- Project code: Apache License 2.0 (`LICENSE`)
- Third-party assets and references: `THIRD_PARTY_LICENSES.md`
