import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import '../widgets/showcase_shell.dart';

/// Notation to a Standard MIDI File, with the bytes shown.
///
/// The gallery had a per-voice playback page but nothing for the FILE side:
/// `MidiMapper` turns a `Staff` into a `MidiSequence`, and `MidiFileWriter`
/// turns that into the bytes of a `.mid`. This page runs both and prints what
/// came out, because "it exports MIDI" is the kind of claim worth showing
/// rather than asserting.
class MidiExportExample extends StatelessWidget {
  const MidiExportExample({super.key});

  static const _accent = Color(0xFFB91C1C);

  @override
  Widget build(BuildContext context) {
    final staff = _phrase();
    final sequence = MidiMapper.fromStaff(staff, trackName: 'Melody');
    final bytes = MidiFileWriter.write(sequence);

    final transposed = Staff(
      measures: _phrase().measures,
      transposition: const Transposition(diatonic: -1, chromatic: -2),
    );
    final transposedSeq = MidiMapper.fromStaff(transposed);

    return ExampleShowcasePage(
      title: 'MIDI Export',
      subtitle:
          'A Staff becomes a MidiSequence becomes the bytes of a Standard MIDI '
          'File. Every number on this page was produced by running the code '
          'that renders the staff above it.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'Two steps, deliberately separate',
          description:
              'MidiMapper.fromStaff resolves notation into timed events — it '
              'is where ties are joined, tuplets are given their real duration, '
              'grace notes are placed and a transposing part is moved to its '
              'sounding pitch. MidiFileWriter.write then serialises that to '
              'bytes. Keeping them apart means you can feed the sequence to a '
              'synthesiser without ever writing a file.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'The source phrase',
          description:
              'A tie, a triplet and a dotted figure — the three things that '
              'make notated duration differ from written duration.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: staff,
            accentColor: _accent,
            minHeight: 210,
            staffSpace: 15,
          ),
        ),
        ExampleSectionCard(
          title: 'What the mapper produced',
          description:
              'Ticks are relative to the sequence division. A tied pair appears '
              'as ONE note of the joined length, not two — which is the whole '
              'reason a mapper exists instead of a per-note loop.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _summarise(sequence)),
        ),
        ExampleSectionCard(
          title: 'The file header, byte for byte',
          description:
              'A Standard MIDI File opens with the ASCII chunk id MThd, a '
              '4-byte length of 6, then format, track count and division. '
              'Reading the first sixteen bytes is the cheapest way to know the '
              'writer produced a real file rather than a plausible-looking one.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(text: _hexDump(bytes, 32)),
        ),
        ExampleSectionCard(
          title: 'A transposing part sounds where it should',
          description:
              'The same written phrase on a B-flat instrument: Transposition('
              'diatonic -1, chromatic -2). The written notes do not move on the '
              'page; the MIDI numbers do. Before this reached playback, an '
              'imported clarinet part sounded a whole tone sharp.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: 'written (concert)  ${_firstPitches(sequence)}\n'
                'sounding (B-flat)  ${_firstPitches(transposedSeq)}',
          ),
        ),
        const ExampleSectionCard(
          title: 'Writing it to disk',
          description:
              'MidiFileWriter.write returns a Uint8List, so where you put it is '
              'your choice — a file, an HTTP body, a synthesiser. This page '
              'does not offer a download because the gallery runs in a sandbox '
              'that blocks page-initiated saves.',
          accentColor: _accent,
          child: ShowcaseCodeBlock(
            text: "import 'package:flutter_notemus/midi.dart';\n"
                '\n'
                'final sequence = MidiMapper.fromStaff(staff);\n'
                'final bytes = MidiFileWriter.write(sequence);\n'
                "await File('phrase.mid').writeAsBytes(bytes);",
          ),
        ),
      ],
    );
  }

  static Staff _phrase() {
    Note n(String step, int octave, DurationType d,
            {int dots = 0, TieType? tie}) =>
        Note(
          pitch: Pitch(step: step, octave: octave),
          duration: MusicDuration(d, dots: dots),
          tie: tie,
        );

    final bar1 = Measure()
      ..elements.addAll([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        n('C', 5, DurationType.half, tie: TieType.start),
        n('C', 5, DurationType.half, tie: TieType.end),
      ]);

    final bar2 = Measure()
      ..elements.addAll([
        Tuplet(actualNotes: 3, normalNotes: 2, elements: [
          n('E', 5, DurationType.quarter),
          n('F', 5, DurationType.quarter),
          n('G', 5, DurationType.quarter),
        ]),
        n('A', 5, DurationType.quarter, dots: 1),
        n('G', 5, DurationType.eighth),
      ]);

    return Staff()..measures.addAll([bar1, bar2]);
  }

  static String _summarise(MidiSequence sequence) {
    final lines = <String>[
      'division   ${sequence.ticksPerQuarter} ticks per quarter note',
      'tracks     ${sequence.tracks.length}',
    ];
    for (final track in sequence.tracks) {
      lines.add('');
      lines.add('track "${track.name}"  ${track.events.length} events');
      var shown = 0;
      for (final event in track.events) {
        final label = _eventLabel(event);
        if (label == null) continue;
        lines.add('  tick ${event.tick.toString().padLeft(5)}  $label');
        if (++shown >= 12) {
          lines.add('  …');
          break;
        }
      }
    }
    return lines.join('\n');
  }

  static String? _eventLabel(MidiEvent event) {
    final note = event.note;
    if (note == null) return null;
    switch (event.type) {
      case MidiEventType.noteOn:
        return 'note on   ${_noteName(note)} ($note)  vel ${event.velocity}';
      case MidiEventType.noteOff:
        return 'note off  ${_noteName(note)} ($note)';
      default:
        return null;
    }
  }

  static String _firstPitches(MidiSequence sequence) {
    final numbers = <int>[];
    for (final track in sequence.tracks) {
      for (final event in track.events) {
        final note = event.note;
        if (event.type == MidiEventType.noteOn &&
            note != null &&
            numbers.length < 5) {
          numbers.add(note);
        }
      }
    }
    return numbers.map((n) => '${_noteName(n)} ($n)').join('  ');
  }

  static const _names = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B' //
  ];

  static String _noteName(int midi) =>
      '${_names[midi % 12]}${(midi ~/ 12) - 1}';

  static String _hexDump(List<int> bytes, int count) {
    final take = bytes.take(count).toList();
    final buffer = StringBuffer();
    for (var offset = 0; offset < take.length; offset += 8) {
      final row = take.skip(offset).take(8).toList();
      final hex =
          row.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final ascii = row
          .map((b) => b >= 0x20 && b < 0x7F ? String.fromCharCode(b) : '.')
          .join();
      buffer.writeln('${offset.toString().padLeft(4, '0')}  '
          '${hex.padRight(23)}  $ascii');
    }
    buffer.writeln('');
    buffer.write('${bytes.length} bytes total');
    return buffer.toString();
  }
}
