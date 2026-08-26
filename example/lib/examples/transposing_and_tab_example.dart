import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Written pitch and sounding pitch are not the same thing.
///
/// Two places in this package where that distinction is load-bearing, and
/// where getting it wrong is silent: transposing instruments, and tablature.
/// Both used to be modelled and neither reached the thing that consumes it.
class TransposingAndTabExample extends StatelessWidget {
  const TransposingAndTabExample({super.key});

  static const _accent = Color(0xFF9333EA);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Transposing Instruments and Tablature',
      subtitle:
          'A clarinet part and a guitar tab, and what each one means as '
          'opposed to what each one looks like.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'ADR-003: a Pitch is the SOUNDING pitch',
          description:
              'This is the invariant that keeps the two ideas apart. A Pitch in '
              'the model is what you hear. An octave-transposing clef changes '
              'where a note is DRAWN and nothing else — so a treble-8vb tenor '
              'part and a treble part with the same Pitch objects sound '
              'identical and look an octave apart. A transposing INSTRUMENT is '
              'the opposite case: it is declared on the Staff and applied when '
              'the score is sounded, not when it is drawn.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'The same written notes on three instruments',
          description:
              'Identical Pitch objects, identical engraving. The declared '
              'Transposition changes only what comes out of MidiMapper — which '
              'is exactly right, because a clarinettist reads the same dots '
              'whatever key the instrument is in.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScorePreviewFrame(
                staff: _phrase(),
                accentColor: _accent,
                minHeight: 200,
                staffSpace: 16,
              ),
              const SizedBox(height: 14),
              ShowcaseCodeBlock(text: _soundingTable()),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'The octave clef moves the ink, not the meaning',
          description:
              'A tenor part on a treble-8vb clef. Every Pitch below is the same '
              'object as in the plain treble line above it; only the clef '
              'differs, and the notes move down a full octave on the page. If '
              'the model had stored written pitch instead, importing this from '
              'MEI would have transposed the music twice.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScorePreviewFrame(
                staff: _phrase(clef: ClefType.treble),
                accentColor: _accent,
                minHeight: 190,
                staffSpace: 16,
              ),
              const SizedBox(height: 10),
              ScorePreviewFrame(
                staff: _phrase(clef: ClefType.treble8vb),
                accentColor: _accent,
                minHeight: 190,
                staffSpace: 16,
              ),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'Tablature — fret and string, not staff position',
          description:
              'A tab staff has six lines and its numbers mean fret on string. '
              'Note.tabFret and Note.tabString carry that, and Note.isTabNote '
              'distinguishes it — which is why a MEI tab note with no @oct is '
              'tolerated with a warning while a CMN note without one is '
              'rejected outright: on a tab staff the octave is genuinely '
              'redundant.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _tab(),
            accentColor: _accent,
            minHeight: 220,
            staffSpace: 16,
          ),
        ),
        const ExampleSectionCard(
          title: 'Declaring it',
          description:
              'Transposition is written to obtain the SOUNDING pitch from the '
              'written one, which is why a B-flat instrument carries negative '
              'numbers.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: '// B-flat clarinet: written C sounds B-flat.\n'
                'Staff(\n'
                "  name: 'Clarinet in B-flat',\n"
                '  transposition: Transposition(diatonic: -1, chromatic: -2),\n'
                '  measures: [...],\n'
                ');\n'
                '\n'
                '// E-flat alto saxophone: written C sounds E-flat a major\n'
                '// sixth below.\n'
                'Transposition(diatonic: -5, chromatic: -9);\n'
                '\n'
                '// Tenor saxophone: a major ninth below, so the octave is\n'
                '// carried separately rather than folded into chromatic.\n'
                'Transposition(diatonic: -1, chromatic: -2, octaveChange: -1);\n'
                '\n'
                '// A tablature note.\n'
                'Note(\n'
                "  pitch: Pitch(step: 'E', octave: 4),\n"
                '  duration: MusicDuration(DurationType.quarter),\n'
                '  tabString: 4,\n'
                '  tabFret: 2,\n'
                ');',
          ),
        ),
      ],
    );
  }

  static Staff _phrase({ClefType clef = ClefType.treble}) {
    Note n(String step, int octave, {DurationType d = DurationType.quarter}) =>
        Note(
          pitch: Pitch(step: step, octave: octave),
          duration: MusicDuration(d),
        );

    final measure = Measure()
      ..elements.addAll([
        Clef(clefType: clef),
        TimeSignature(numerator: 4, denominator: 4),
        n('C', 5),
        n('D', 5),
        n('E', 5),
        n('G', 5),
      ]);
    return Staff(measures: [measure]);
  }

  /// Runs the written phrase through the mapper once per instrument and prints
  /// the first four MIDI numbers each produced.
  static String _soundingTable() {
    final instruments = <String, Transposition?>{
      'Concert pitch (flute)': null,
      'Clarinet in B-flat': const Transposition(diatonic: -1, chromatic: -2),
      'Alto saxophone in E-flat':
          const Transposition(diatonic: -5, chromatic: -9),
      'Tenor saxophone in B-flat':
          const Transposition(diatonic: -1, chromatic: -2, octaveChange: -1),
    };

    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' //
    ];
    String label(int midi) => '${names[midi % 12]}${(midi ~/ 12) - 1}';

    final lines = <String>[
      'written:  C5  D5  E5  G5',
      '',
      'instrument                    sounds',
      '──────────────────────────────────────────────────',
    ];
    instruments.forEach((name, transposition) {
      final staff = Staff(
        measures: _phrase().measures,
        transposition: transposition,
      );
      final sequence = MidiMapper.fromStaff(staff);
      final pitches = <int>[];
      for (final track in sequence.tracks) {
        for (final event in track.events) {
          final note = event.note;
          if (event.type == MidiEventType.noteOn &&
              note != null &&
              pitches.length < 4) {
            pitches.add(note);
          }
        }
      }
      lines.add('${name.padRight(30)}${pitches.map(label).join('  ')}');
    });
    return lines.join('\n');
  }

  static Staff _tab() {
    Note fret(int string, int fretNumber, String step, int octave,
            {DurationType d = DurationType.quarter}) =>
        Note(
          pitch: Pitch(step: step, octave: octave),
          duration: MusicDuration(d),
          tabString: string,
          tabFret: fretNumber,
        );

    final measure = Measure()
      ..elements.addAll([
        Clef(clefType: ClefType.tab6),
        TimeSignature(numerator: 4, denominator: 4),
        fret(6, 0, 'E', 2),
        fret(5, 2, 'B', 2),
        fret(4, 2, 'E', 3),
        fret(3, 1, 'G', 3, d: DurationType.quarter),
      ]);
    return Staff(measures: [measure], lineCount: 6);
  }
}
