// Regression coverage for issue #9:
// SpacingResult must account for Chord and Tuplet elements when computing the
// shortest sounding duration and coarse advance widths.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/layout/spacing/spacing_result.dart';

void main() {
  group('SystemData.getShortestNoteDuration (issue #9)', () {
    test('considers chord duration', () {
      final measure = Measure();
      measure.add(
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
      );
      measure.add(
        Chord(
          notes: [
            Note(
              pitch: const Pitch(step: 'C', octave: 4),
              duration: const Duration(DurationType.eighth),
            ),
            Note(
              pitch: const Pitch(step: 'E', octave: 4),
              duration: const Duration(DurationType.eighth),
            ),
          ],
          duration: const Duration(DurationType.eighth),
        ),
      );

      final system = SystemData(
        measures: [measure],
        staffCount: 1,
        targetWidth: 100,
      );

      // Eighth chord (0.125) is shorter than the quarter note (0.25).
      expect(system.getShortestNoteDuration(), closeTo(0.125, 1e-9));
    });

    test('applies the tuplet ratio to internal notes', () {
      final measure = Measure();
      measure.add(
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
      );
      measure.add(
        Tuplet.triplet(
          elements: [
            Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
            Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
            Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
          ],
        ),
      );

      final system = SystemData(
        measures: [measure],
        staffCount: 1,
        targetWidth: 100,
      );

      // An eighth inside a 3:2 triplet sounds as 1/8 * 2/3 = 1/12.
      expect(system.getShortestNoteDuration(), closeTo(0.125 * 2 / 3, 1e-9));
    });
  });

  group('TimeSlice advance-width estimate (issue #9)', () {
    test('estimates per element kind including chord and tuplet', () {
      final plainNote = Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
      );
      final accidentalNote = Note(
        pitch: const Pitch(step: 'F', octave: 5, alter: 1.0),
        duration: const Duration(DurationType.quarter),
      );
      final rest = Rest(duration: const Duration(DurationType.quarter));
      final chord = Chord(
        notes: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
          Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        ],
        duration: const Duration(DurationType.quarter),
      );
      final tuplet = Tuplet.triplet(
        elements: [
          Note(
            pitch: const Pitch(step: 'C', octave: 5),
            duration: const Duration(DurationType.eighth),
          ),
          Note(
            pitch: const Pitch(step: 'D', octave: 5),
            duration: const Duration(DurationType.eighth),
          ),
          Note(
            pitch: const Pitch(step: 'E', octave: 5),
            duration: const Duration(DurationType.eighth),
          ),
        ],
      );

      expect(
        TimeSlice.estimateAdvanceWidthInStaffSpaces(plainNote),
        closeTo(1.18, 1e-9),
      );
      expect(
        TimeSlice.estimateAdvanceWidthInStaffSpaces(accidentalNote),
        greaterThan(TimeSlice.estimateAdvanceWidthInStaffSpaces(plainNote)),
      );
      expect(
        TimeSlice.estimateAdvanceWidthInStaffSpaces(rest),
        closeTo(1.0, 1e-9),
      );
      expect(
        TimeSlice.estimateAdvanceWidthInStaffSpaces(chord),
        closeTo(1.18, 1e-9),
      );
      // Tuplet width is the sum of its three eighth-note children.
      expect(
        TimeSlice.estimateAdvanceWidthInStaffSpaces(tuplet),
        closeTo(3 * 1.18, 1e-9),
      );
    });

    test('getMaxWidth sums per-element estimates and takes the max staff', () {
      final note = Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
      );
      final chord = Chord(
        notes: [
          Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
        ],
        duration: const Duration(DurationType.quarter),
      );

      final slice = TimeSlice(
        time: 0,
        symbolsByStaff: {
          0: [note],
          1: [note, chord],
        },
      );

      // Staff 1 (note + chord) is wider than staff 0 (single note).
      expect(slice.getMaxWidth(), closeTo(1.18 + 1.18, 1e-9));
      expect(slice.getMaxWidth(), greaterThan(0.0));
    });
  });
}
