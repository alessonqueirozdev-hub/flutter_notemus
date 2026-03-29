import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/src/rendering/renderers/chord_renderer.dart';

void main() {
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
