// Regression coverage for issue #8:
// MeasureValidator must account for tuplet ratios so that measures containing
// tuplets validate without false "measure too long/short" errors.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/layout/measure_validator.dart';

void main() {
  group('MeasureValidator with tuplets (issue #8)', () {
    test('a triplet of three eighths exactly fills a 1/4 measure', () {
      final measure = Measure();
      measure.add(TimeSignature(numerator: 1, denominator: 4));
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

      final result = MeasureValidator.validate(measure);

      expect(result.isValid, isTrue, reason: result.getSummary());
      expect(result.errors, isEmpty);
      expect(result.expectedCapacity, closeTo(0.25, 1e-9));
      expect(result.actualDuration, closeTo(0.25, 1e-9));
    });

    test('a 3:2 quarter triplet exactly fills a 2/4 measure', () {
      final measure = Measure();
      measure.add(TimeSignature(numerator: 2, denominator: 4));
      measure.add(
        Tuplet.triplet(
          elements: [
            Note(
              pitch: const Pitch(step: 'C', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
            Note(
              pitch: const Pitch(step: 'D', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
            Note(
              pitch: const Pitch(step: 'E', octave: 5),
              duration: const Duration(DurationType.quarter),
            ),
          ],
        ),
      );

      final result = MeasureValidator.validate(measure);

      expect(result.isValid, isTrue, reason: result.getSummary());
      expect(result.errors, isEmpty);
      expect(result.actualDuration, closeTo(0.5, 1e-9));
    });

    test('tuplet plus plain notes still validates a full 4/4 bar', () {
      final measure = Measure();
      measure.add(TimeSignature(numerator: 4, denominator: 4));
      measure.add(
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
      );
      measure.add(
        Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
      );
      measure.add(
        Note(
          pitch: const Pitch(step: 'E', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
      );
      // Triplet of three eighths occupies the final quarter (0.25).
      measure.add(
        Tuplet.triplet(
          elements: [
            Note(
              pitch: const Pitch(step: 'F', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
            Note(
              pitch: const Pitch(step: 'G', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
            Note(
              pitch: const Pitch(step: 'A', octave: 5),
              duration: const Duration(DurationType.eighth),
            ),
          ],
        ),
      );

      final result = MeasureValidator.validate(measure);

      expect(result.isValid, isTrue, reason: result.getSummary());
      expect(result.errors, isEmpty);
      expect(result.actualDuration, closeTo(1.0, 1e-9));
    });
  });
}
