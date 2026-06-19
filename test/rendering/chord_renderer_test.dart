import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/chord_renderer.dart';

void main() {
  group('ChordRenderer.resolveStemDirection', () {
    Chord chordOf(List<int> octaves) => Chord(
          notes: [
            for (final o in octaves)
              Note(
                pitch: Pitch(step: 'C', octave: o),
                duration: const Duration(DurationType.half),
              ),
          ],
          duration: const Duration(DurationType.half),
        );

    test('low chord (furthest note below middle) gets stem up', () {
      // C4/E4/G4 in treble: positions [-7, -5, -3], furthest = -7 (below).
      final stemUp = ChordRenderer.resolveStemDirection(
        chord: chordOf(const [4]),
        positions: const [-7, -5, -3],
      );
      expect(stemUp, isTrue);
    });

    test('high chord (furthest note above middle) gets stem down', () {
      // A4/C5/E5 in treble: positions [-1, 1, 3], furthest = 3 (above).
      final stemUp = ChordRenderer.resolveStemDirection(
        chord: chordOf(const [4]),
        positions: const [-1, 1, 3],
      );
      expect(stemUp, isFalse);
    });

    test('a note exactly on the middle line resolves to stem down', () {
      final stemUp = ChordRenderer.resolveStemDirection(
        chord: chordOf(const [4]),
        positions: const [0],
      );
      expect(stemUp, isFalse);
    });
  });

  group('ChordRenderer.calculateClusterOffsets', () {
    test('moves the upper head to the opposite side for upward seconds', () {
      final offsets = ChordRenderer.calculateClusterOffsets(
        positions: const [4, 3],
        stemUp: true,
        clusterOffset: 10,
      );

      expect(offsets, orderedEquals(const [10.0, 0.0]));
    });

    test('moves the upper head to the opposite side for downward seconds', () {
      final offsets = ChordRenderer.calculateClusterOffsets(
        positions: const [4, 3],
        stemUp: false,
        clusterOffset: 10,
      );

      expect(offsets, orderedEquals(const [0.0, -10.0]));
    });

    test('keeps isolated notes centered while alternating clusters', () {
      final offsets = ChordRenderer.calculateClusterOffsets(
        positions: const [7, 6, 3],
        stemUp: true,
        clusterOffset: 12,
      );

      expect(offsets, orderedEquals(const [12.0, 0.0, 0.0]));
    });
  });
}
