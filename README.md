# Flutter Notemus

[![pub.dev](https://img.shields.io/pub/v/flutter_notemus.svg)](https://pub.dev/packages/flutter_notemus)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Professional music notation rendering for Flutter with SMuFL + Bravura.

## Current release target

- Package version in this repository: `2.0.1`
- Main repository: https://github.com/alessonqueirozdev-hub/flutter_notemus
- pub.dev page: https://pub.dev/packages/flutter_notemus

## What this package provides

- High quality notation rendering on Flutter `Canvas`
- Core notation model (`Staff`, `Measure`, `Note`, `Chord`, `Rest`, etc.)
- Layout engine with rhythmic spacing and collision handling
- Multi-voice support (`MultiVoiceMeasure`)
- Grand-staff and multi-staff scenarios
- Importers: JSON, MusicXML, MEI
- MIDI pipeline:
  - notation-to-MIDI mapping
  - repeat and volta expansion
  - metronome timeline generation
  - `.mid` file export
  - native audio backend contract and bridge

## Installation

Add dependency:

```yaml
dependencies:
  flutter_notemus: ^2.0.1
```

Then run:

```bash
flutter pub get
```

## Required initialization

Load Bravura font and SMuFL metadata before rendering:

```dart
import 'package:flutter/material.dart';
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

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class DemoScore extends StatelessWidget {
  const DemoScore({super.key});

  @override
  Widget build(BuildContext context) {
    final staff = Staff(
      measures: [
        Measure()
          ..add(Clef(clefType: ClefType.treble))
          ..add(TimeSignature(numerator: 4, denominator: 4))
          ..add(Note(
            pitch: const Pitch(step: 'C', octave: 5),
            duration: const Duration(DurationType.quarter),
          ))
          ..add(Note(
            pitch: const Pitch(step: 'D', octave: 5),
            duration: const Duration(DurationType.quarter),
          ))
          ..add(Note(
            pitch: const Pitch(step: 'E', octave: 5),
            duration: const Duration(DurationType.quarter),
          ))
          ..add(Note(
            pitch: const Pitch(step: 'F', octave: 5),
            duration: const Duration(DurationType.quarter),
          )),
      ],
    );

    return MusicScore(staff: staff, staffSpace: 12);
  }
}
```

## MIDI quick example

```dart
import 'dart:io';
import 'package:flutter_notemus/flutter_notemus.dart';

Future<void> exportMidi(Staff staff) async {
  final sequence = MidiMapper.fromStaff(staff);
  final bytes = MidiFileWriter.write(sequence);
  await File('score.mid').writeAsBytes(bytes, flush: true);
}
```

## Feature status

Implemented and production-ready:

- Core notation model and rendering pipeline
- Notes, rests, chords, ties, slurs, tuplets, beams
- Clefs, key signatures, time signatures, barlines
- Dynamics, articulations, ornaments, octave marks, volta brackets
- Multi-voice layout and rendering
- MIDI mapping and MIDI file export

Partially implemented or pending:

- Cross-platform native audio parity (Android complete, others stub): https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/1
- Real PDF engraving export (current output is placeholder): https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/2
- SMuFL brace glyph workflow in staff groups: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/3
- Primitive stem/flag parameterization by engraving defaults: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/4
- Robust fallback for `repeatBoth` when combined glyph is unavailable: https://github.com/alessonqueirozdev-hub/flutter_notemus/issues/5

Detailed backlog document:

- `docs/OPEN_ISSUES.md`

## API references

Primary entry points:

- `MusicScore`
- `LayoutEngine`
- `StaffRenderer`
- `NotationParser`
- `MidiMapper`
- `MidiFileWriter`
- `MethodChannelMidiNativeAudioBackend`
- `MidiNativeSequenceBridge`

Public exports:

- `lib/flutter_notemus.dart`
- `lib/midi.dart`

## Development and quality

Common local checks:

```bash
dart analyze
flutter test
flutter pub publish --dry-run
```

## Publishing to pub.dev

Recommended flow:

```bash
flutter pub get
flutter test
flutter pub publish --dry-run
flutter pub publish
```

## License

- Project code: Apache-2.0 (`LICENSE`)
- Bravura font: SIL Open Font License 1.1
- SMuFL specification: W3C Music Notation Community Group
