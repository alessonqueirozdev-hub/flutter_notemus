# Flutter Notemus

[![pub.dev](https://img.shields.io/pub/v/flutter_notemus.svg)](https://pub.dev/packages/flutter_notemus)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.8.1+-blue.svg)](https://dart.dev/)
[![SMuFL](https://img.shields.io/badge/SMuFL-1.40-green.svg)](https://w3c.github.io/smufl/latest/)
[![MEI](https://img.shields.io/badge/MEI-v5%20100%25-brightgreen.svg)](https://music-encoding.org/guidelines/v5/content/index.html)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Professional music notation rendering for Flutter with SMuFL-compliant engraving, Bravura glyph support, first-party notation-to-MIDI pipeline, and **full MEI v5 conformance**.

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

flutter_notemus implements **100% of the MEI v5 (Music Encoding Initiative) specification**, covering all repertoires and analytical features defined in the [MEI v5 Guidelines](https://music-encoding.org/guidelines/v5/content/index.html).

### Coverage by MEI v5 module

| MEI v5 Module | Coverage | Key classes |
|---|---|---|
| **CMN — Pitch & Duration** | ✅ 100% | `Pitch`, `Duration`, `DurationType` (maxima → 2048th) |
| **CMN — Events** | ✅ 100% | `Note`, `Rest`, `Chord`, `Space`, `MeasureSpace` |
| **CMN — Measure & Staff** | ✅ 100% | `Measure` (with `@n`), `Staff` (configurable `lineCount`), `xml:id` on all elements |
| **CMN — Clef / Key / Meter** | ✅ 100% | `Clef` (20 types), `KeySignature` (with `KeyMode`), `TimeSignature` (free + additive) |
| **CMN — Articulation** | ✅ 100% | `ArticulationType` (17 types), `Articulation` |
| **CMN — Dynamics** | ✅ 100% | `Dynamic`, `DynamicType` (44 types, hairpin) |
| **CMN — Ornaments** | ✅ 100% | `Ornament`, `OrnamentType` (60+ types) |
| **CMN — Slur / Tie / Beam** | ✅ 100% | `SlurType`, `TieType`, `BeamType`, `AdvancedSlur` |
| **CMN — Tuplets** | ✅ 100% | `Tuplet`, `TupletBracket`, nested tuplets |
| **CMN — Polyphony** | ✅ 100% | `Voice`, `MultiVoiceMeasure`, `StemDirection` |
| **CMN — Score structure** | ✅ 100% | `Score`, `StaffGroup`, `ScoreDefinition` (`<scoreDef>`) |
| **CMN — Navigation** | ✅ 100% | `RepeatMark`, `VoltaBracket`, `BarlineType` (12 types) |
| **Lyrics & Text** | ✅ 100% | `MusicText`, `Verse`, `Syllable`, `SyllableType` (MEI `<syl>`) |
| **Metadata (meiHead)** | ✅ 100% | `MeiHeader`, `FileDescription`, `EncodingDescription`, `WorkList`, `ManifestationList`, `RevisionDescription` |
| **Harmonic Analysis** | ✅ 100% | `HarmonicLabel`, `MelodicInterval`, `HarmonicInterval`, `ScaleDegree`, `ChordTable` |
| **Figured Bass** | ✅ 100% | `FiguredBass`, `FigureElement` (MEI `<fb>/<f>`) |
| **Microtonality** | ✅ 100% | `AccidentalType` (sagittal, koma, quarter-tone), `Pitch.pitchClass` |
| **Solmization** | ✅ 100% | `Pitch.fromSolmization()`, `Pitch.solmizationName` |
| **Tablature** | ✅ 100% | `TabNote`, `TabGrp`, `TabDurSym`, `TabTuning`, `Note.tabFret/tabString` |
| **Mensural Notation** | ✅ 100% | `MensuralNote`, `Ligature`, `Mensur`, `ProportMark`, `MensuralRest` |
| **Neume Notation** | ✅ 100% | `Neume`, `NeumeComponent`, `NeumeType`, `NeumeDivision` |

### Key MEI v5 features

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

// Full MEI header (meiHead)
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

For a full conformance audit see [`docs/MEI_V5_AUDIT.md`](docs/MEI_V5_AUDIT.md).

---

## Current Status

- Current package release target: `2.2.1`
- Previous pub.dev baseline before the new generation: `0.1.0`
- Core notation rendering is production-ready.
- MIDI mapping and `.mid` export are available in the package.
- Android native audio backend is active; other native targets are configured and tracked as pending.

---

## Open Pending Work

All pending work is tracked as GitHub issues:

- Native audio backend parity (iOS/macOS/Linux/Windows): https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1
- Real notation engraving for PDF export: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/2
- SMuFL brace workflow for staff groups: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/3
- Stem/flag primitive parameterization via engraving defaults: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/4
- Robust fallback for `repeatBoth`: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/5

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
- Grand staff scenarios (piano)
- SATB-style aligned staff rendering

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
  flutter_notemus: ^2.2.1
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
