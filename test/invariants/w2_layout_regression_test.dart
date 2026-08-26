// test/invariants/w2_layout_regression_test.dart
//
// Regression tests for the 2.7.1 wave-2 layout remediation: musical time,
// reserved widths, canvas headroom, and the wave-1 octave-bracket regression.
//
// Every expectation below quotes the number that was MEASURED before the fix.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/chord_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  Staff staffOf(List<Measure> measures) => Staff()..measures.addAll(measures);

  LayoutEngine engineOf(Staff staff) => LayoutEngine(
        staff,
        availableWidth: 900,
        staffSpace: 12,
        metadata: metadata,
      );

  Note quarter(String step, int octave, {double alter = 0.0, int? voice}) =>
      Note(
        pitch: Pitch(step: step, octave: octave, alter: alter),
        duration: const Duration(DurationType.quarter),
        voice: voice,
      );

  group('D-2: an octave bracket is a property of the STAFF, not of a voice',
      () {
    // Measured before the fix, on a two-voice bar whose voices both hold a C5:
    //   mark in voice 1 -> voice 1 +1, voice 2 +1
    //   mark in voice 2 -> voice 1  0, voice 2 +1
    // i.e. the same marking meant two different things depending on which
    // voice the author typed it in. MusicXML anchors <octave-shift> to a
    // <staff> and MEI's <octave> applies to every layer when @layer is absent,
    // so the staff-wide reading is the correct one.
    ({int voice1, int voice2}) shiftsWithMarkIn(int voiceNumber) {
      final mark =
          OctaveMark(type: OctaveType.va8, startMeasure: 0, endMeasure: 0);
      final n1 = Note(
        pitch: const Pitch(step: 'C', octave: 5, alter: 0.0),
        duration: const Duration(DurationType.whole),
        voice: 1,
      );
      final n2 = Note(
        pitch: const Pitch(step: 'C', octave: 5, alter: 0.0),
        duration: const Duration(DurationType.whole),
        voice: 2,
      );
      final measure = MultiVoiceMeasure.twoVoices(
        voice1Elements: voiceNumber == 1 ? [mark, n1] : [n1],
        voice2Elements: voiceNumber == 2 ? [mark, n2] : [n2],
      );
      measure.elements.addAll([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
      ]);
      final engine = engineOf(staffOf([measure]));
      engine.layout();
      return (
        voice1: engine.noteOctaveShifts[n1] ?? 0,
        voice2: engine.noteOctaveShifts[n2] ?? 0,
      );
    }

    test('the marking means the same thing whichever voice carries it', () {
      final fromVoice1 = shiftsWithMarkIn(1);
      final fromVoice2 = shiftsWithMarkIn(2);
      expect(fromVoice1.voice1, 1);
      expect(fromVoice1.voice2, 1);
      // This is the half that measured 0 before.
      expect(fromVoice2.voice1, 1);
      expect(fromVoice2.voice2, 1);
      expect(fromVoice1, fromVoice2);
    });

    test('a monophonic bar still activates the bracket where it is written',
        () {
      final before = quarter('C', 5);
      final after = quarter('C', 5);
      final measure = Measure()
        ..elements.addAll([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          before,
          OctaveMark(type: OctaveType.va8, startMeasure: 0, endMeasure: 0),
          after,
          quarter('C', 5),
          quarter('C', 5),
        ]);
      final engine = engineOf(staffOf([measure]));
      engine.layout();
      expect(engine.noteOctaveShifts[before] ?? 0, 0);
      expect(engine.noteOctaveShifts[after], 1);
      // C5 is staff position 1 in treble; displaced down an octave it is -6.
      expect(engine.noteStaffPositions[before], 1);
      expect(engine.noteStaffPositions[after], -6);
    });

    test('a bracket opened mid-bar in voice 2 leaves voice 1 alone BEFORE it',
        () {
      final early = quarter('C', 5, voice: 1);
      final late = quarter('C', 5, voice: 1);
      final measure = MultiVoiceMeasure.twoVoices(
        voice1Elements: [
          early,
          quarter('C', 5, voice: 1),
          late,
          quarter('C', 5, voice: 1),
        ],
        voice2Elements: [
          quarter('E', 4, voice: 2),
          quarter('E', 4, voice: 2),
          OctaveMark(type: OctaveType.va8, startMeasure: 0, endMeasure: 0),
          quarter('E', 4, voice: 2),
          quarter('E', 4, voice: 2),
        ],
      );
      measure.elements.addAll([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
      ]);
      final engine = engineOf(staffOf([measure]));
      engine.layout();
      expect(engine.noteOctaveShifts[early] ?? 0, 0,
          reason: 'the third beat is where the bracket starts');
      expect(engine.noteOctaveShifts[late], 1,
          reason: 'voice 1 must follow a bracket written in voice 2');
    });
  });

  group('M-04: a grace note consumes no musical time', () {
    Measure barWithGraceNotes(List<Note> real, List<Note> graces) {
      final measure = Measure();
      measure.elements.addAll([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        real[0],
        graces[0],
        real[1],
        graces[1],
        real[2],
        real[3],
      ]);
      return measure;
    }

    List<Note> fourQuarters() => [for (var i = 0; i < 4; i++) quarter('C', 4)];

    List<Note> twoGraces() => [
          for (var i = 0; i < 2; i++)
            Note(
              pitch: const Pitch(step: 'D', octave: 4, alter: 0.0),
              duration: const Duration(DurationType.eighth),
              isGraceNote: true,
            ),
        ];

    test('Measure.currentMusicalValue ignores them (was 1.1875)', () {
      final measure = barWithGraceNotes(fourQuarters(), twoGraces());
      expect(measure.currentMusicalValue, closeTo(1.0, 1e-9));
      expect(measure.isValidlyFilled, isTrue);
    });

    test('the four real notes land on the beat (was 0/0.1875/0.4375/0.6875)',
        () {
      final real = fourQuarters();
      final engine = engineOf(staffOf([barWithGraceNotes(real, twoGraces())]));
      final positioned = engine.layout();
      final onsets = [
        for (final note in real)
          positioned.firstWhere((p) => identical(p.element, note)).onset,
      ];
      expect(onsets, [0.0, 0.25, 0.5, 0.75]);
    });

    test('a grace note shares the onset of the note it ornaments', () {
      final real = fourQuarters();
      final graces = twoGraces();
      final engine = engineOf(staffOf([barWithGraceNotes(real, graces)]));
      final positioned = engine.layout();
      double onsetOf(Note note) =>
          positioned.firstWhere((p) => identical(p.element, note)).onset;
      expect(onsetOf(graces[0]), onsetOf(real[1]));
      expect(onsetOf(graces[1]), onsetOf(real[2]));
    });

    test('a grace note still occupies horizontal width', () {
      final grace = twoGraces().first;
      final engine = engineOf(staffOf([
        Measure()
          ..elements.addAll([Clef(clefType: ClefType.treble), grace])
      ]));
      engine.layout();
      expect(engine.elementWidth(grace), greaterThan(0.0));
    });

    test('two staves stay onset-aligned when only one carries grace notes', () {
      List<double> realOnsetsOf({required bool withGrace}) {
        final real = fourQuarters();
        final measure = withGrace
            ? barWithGraceNotes(real, twoGraces())
            : (Measure()
              ..elements.addAll([
                Clef(clefType: ClefType.treble),
                TimeSignature(numerator: 4, denominator: 4),
                ...real,
              ]));
        final positioned = engineOf(staffOf([measure])).layout();
        return [
          for (final note in real)
            positioned.firstWhere((p) => identical(p.element, note)).onset,
        ];
      }

      expect(realOnsetsOf(withGrace: true), realOnsetsOf(withGrace: false));
    });
  });

  group('M-16/M-17: the layout reserves what ChordRenderer draws', () {
    Chord chordOf(List<(String, int)> pitches, {double alter = 0.0}) => Chord(
          notes: [
            for (final p in pitches)
              Note(
                pitch: Pitch(step: p.$1, octave: p.$2, alter: alter),
                duration: const Duration(DurationType.quarter),
              ),
          ],
          duration: const Duration(DurationType.quarter),
        );

    double leftExtentOf(Chord chord) {
      final engine = engineOf(staffOf([
        Measure()..elements.addAll([Clef(clefType: ClefType.treble), chord])
      ]));
      engine.layout();
      return engine.elementLeftExtent(chord);
    }

    test('the reservation grows with the number of accidental COLUMNS', () {
      // Measured before: 25.82 px for 2, 3, 4 AND 5 accidentals — one column,
      // whatever the renderer packed.
      final two = leftExtentOf(chordOf([('C', 4), ('E', 4)], alter: -1.0));
      final three =
          leftExtentOf(chordOf([('C', 4), ('E', 4), ('G', 4)], alter: -1.0));
      expect(three, greaterThan(two));
      // Greedy first-fit reuses column 0 as soon as the vertical clearance
      // allows, so 4 and 5 flats in thirds still need only 3 columns.
      final four = leftExtentOf(
          chordOf([('C', 4), ('E', 4), ('G', 4), ('B', 4)], alter: -1.0));
      expect(four, closeTo(three, 1e-6));
    });

    test('it is byte-for-byte the renderer geometry, not an approximation', () {
      final chord =
          chordOf([('C', 4), ('E', 4), ('G', 4), ('B', 4)], alter: -1.0);
      final engine = engineOf(staffOf([
        Measure()..elements.addAll([Clef(clefType: ClefType.treble), chord])
      ]));
      engine.layout();
      final drawn = ChordRenderer.resolveGeometry(
        chord: chord,
        clef: Clef(clefType: ClefType.treble),
        metadata: metadata,
        staffSpace: 12,
      );
      expect(engine.elementLeftExtent(chord), closeTo(drawn.leftExtent, 1e-9));
      expect(engine.elementWidth(chord), closeTo(drawn.width, 1e-9));
    });

    test('a cluster of seconds displaces the noteheads it draws displaced', () {
      // Measured before: C5-D5-E5 and C5-E5-G5 both reserved 14.16 px and gave
      // all three notes the same X, while the renderer offset the middle note
      // of the cluster by a full notehead width.
      final seconds = chordOf([('C', 5), ('D', 5), ('E', 5)]);
      final thirds = chordOf([('C', 5), ('E', 5), ('G', 5)]);

      final withSeconds = engineOf(staffOf([
        Measure()..elements.addAll([Clef(clefType: ClefType.treble), seconds])
      ]));
      withSeconds.layout();
      final withThirds = engineOf(staffOf([
        Measure()..elements.addAll([Clef(clefType: ClefType.treble), thirds])
      ]));
      withThirds.layout();

      final secondXs = [
        for (final n in seconds.notes) withSeconds.noteXPositions[n]!
      ];
      final thirdXs = [
        for (final n in thirds.notes) withThirds.noteXPositions[n]!
      ];

      expect(thirdXs.toSet().length, 1, reason: 'no seconds, no displacement');
      expect(secondXs.toSet().length, 2, reason: 'D5 is pushed off the column');
      expect(withSeconds.elementLeftExtent(seconds),
          greaterThan(withThirds.elementLeftExtent(thirds)));
      expect(withSeconds.elementWidth(seconds),
          greaterThan(withThirds.elementWidth(thirds)));
    });
  });

  group('M-23: a tuplet bracket and its numeral are counted in the headroom',
      () {
    Tuplet tripletOn(String step, int octave) => Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          elements: [
            for (var i = 0; i < 3; i++)
              Note(
                pitch: Pitch(step: step, octave: octave, alter: 0.0),
                duration: const Duration(DurationType.eighth),
              ),
          ],
        );

    test('a stem-up bracket on the middle line overflows the default block',
        () {
      // Measured before: contentTopOverflow == 0.00 for ANY tuplet, so the
      // bracket and the "3" were clipped out of the raster and the PDF.
      final tuplet = tripletOn('B', 4);
      final engine = engineOf(staffOf([
        Measure()
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            tuplet,
          ])
      ]));
      final positioned = engine.layout();
      expect(engine.contentTopOverflow(positioned), greaterThan(20.0));
    });

    test('a bracket that fits demands no headroom', () {
      final tuplet = tripletOn('C', 4);
      final engine = engineOf(staffOf([
        Measure()
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            tuplet,
          ])
      ]));
      final positioned = engine.layout();
      expect(engine.contentTopOverflow(positioned), 0.0);
    });
  });

  group('M-37: a mid-measure clef breaks the rhythmic chain', () {
    test('the note after the clef is not charged a phantom note-to-note gap',
        () {
      final before = quarter('C', 4);
      final after = quarter('D', 4);
      final engine = engineOf(staffOf([
        Measure()
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            before,
            Clef(clefType: ClefType.bass),
            after,
          ])
      ]));
      final positioned = engine.layout();
      double xOf(MusicalElement e) =>
          positioned.firstWhere((p) => identical(p.element, e)).position.dx;
      // Measured: 100.92 px before the fix, 58.92 px after — the 42.00 px
      // removed was a duration-proportional gap charged against the note on
      // the OTHER side of the clef.
      expect(xOf(after) - xOf(before), closeTo(58.92, 0.5));
    });
  });

  group('M-39: a tuplet reserves its first child accidental', () {
    test('a triplet opening on a double flat is not flush against its left',
        () {
      final tuplet = Tuplet(
        actualNotes: 3,
        normalNotes: 2,
        elements: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4, alter: -2.0),
            duration: const Duration(DurationType.eighth),
          ),
          Note(
            pitch: const Pitch(step: 'D', octave: 4, alter: 0.0),
            duration: const Duration(DurationType.eighth),
          ),
          Note(
            pitch: const Pitch(step: 'E', octave: 4, alter: 0.0),
            duration: const Duration(DurationType.eighth),
          ),
        ],
      );
      final engine = engineOf(staffOf([
        Measure()..elements.addAll([Clef(clefType: ClefType.treble), tuplet])
      ]));
      engine.layout();
      // Measured before: 0.00. After: the same 23.42 px a bare note carrying
      // `accidentalDoubleFlat` reserves.
      expect(engine.elementLeftExtent(tuplet), closeTo(23.42, 0.05));
      expect(
        engine.elementLeftExtent(tuplet),
        closeTo(engine.elementLeftExtent(tuplet.elements.first), 1e-9),
      );
    });
  });

  group('M-34: contentWidth does not double-count a left-hanging accidental',
      () {
    test('an accidental behind the last note is not reported in front of it',
        () {
      final last = quarter('C', 4, alter: -2.0);
      final engine = engineOf(staffOf([
        Measure()
          ..elements.addAll([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            quarter('D', 4),
            quarter('E', 4),
            quarter('F', 4),
            last,
          ])
      ]));
      final positioned = engine.layout();
      final upToLast = positioned.sublist(
        0,
        positioned.indexWhere((p) => identical(p.element, last)) + 1,
      );
      final noteX =
          positioned.firstWhere((p) => identical(p.element, last)).position.dx;
      final trueRight =
          noteX + engine.elementWidth(last) - engine.elementLeftExtent(last);
      // Measured: 356.20 px reported for a right edge of 332.77 px — the
      // 23.42 px accidental counted twice, once behind and once in front.
      expect(engine.contentWidth(upToLast), closeTo(trueRight + 6.0, 1e-6));
    });
  });

  group('M-47: a rest reserves the advance of the glyph it draws', () {
    double widthOf(DurationType type) {
      final rest = Rest(duration: Duration(type));
      final engine = engineOf(staffOf([
        Measure()..elements.addAll([Clef(clefType: ClefType.treble), rest])
      ]));
      engine.layout();
      return engine.elementWidth(rest);
    }

    test('the reservation varies with duration (was a flat 18.00 px)', () {
      // Bravura advances at staffSpace 12: restWhole 1.132 -> 13.584,
      // restQuarter 1.08 -> 12.960, rest8th 1.0 -> 12.000, rest16th 1.28 ->
      // 15.360. The old constant was 1.5 staff spaces = 18.00 px for all.
      expect(widthOf(DurationType.whole), closeTo(13.584, 1e-3));
      expect(widthOf(DurationType.quarter), closeTo(12.960, 1e-3));
      expect(widthOf(DurationType.eighth), closeTo(12.000, 1e-3));
      expect(widthOf(DurationType.sixteenth), closeTo(15.360, 1e-3));
      expect(
        {
          widthOf(DurationType.whole),
          widthOf(DurationType.quarter),
          widthOf(DurationType.eighth),
        }.length,
        3,
        reason: 'three durations, three different reservations',
      );
    });

    test('a dotted rest reserves room for its dots', () {
      final plain = widthOf(DurationType.quarter);
      final dotted = Rest(
        duration: const Duration(DurationType.quarter, dots: 1),
      );
      final engine = engineOf(staffOf([
        Measure()..elements.addAll([Clef(clefType: ClefType.treble), dotted])
      ]));
      engine.layout();
      expect(engine.elementWidth(dotted), greaterThan(plain));
    });
  });
}
