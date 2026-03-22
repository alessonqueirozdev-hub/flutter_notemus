// test/rendering/smufl_positioning_engine_test.dart
// Tests for SMuFL positioning engine

import 'package:test/test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter/material.dart';

void main() {
  late SMuFLPositioningEngine engine;
  late SmuflMetadata metadata;

  setUp(() {
    metadata = SmuflMetadata.instance;
    engine = SMuFLPositioningEngine(metadata: metadata);
  });

  group('SMuFLPositioningEngine - Stem Anchors', () {
    test('Get stem up anchor for noteheadBlack', () {
      final anchor = engine.getStemUpAnchor('noteheadBlack');

      expect(anchor, isNotNull);
      expect(anchor, isA<Offset>());
    });

    test('Get stem down anchor for noteheadBlack', () {
      final anchor = engine.getStemDownAnchor('noteheadBlack');

      expect(anchor, isNotNull);
      expect(anchor, isA<Offset>());
    });

    test('Stem up anchor is on right side', () {
      final anchor = engine.getStemUpAnchor('noteheadBlack');

      // Stem up anchor should be on right side (positive X)
      expect(anchor.dx, greaterThan(0));
    });

    test('Stem down anchor is on left side', () {
      final anchor = engine.getStemDownAnchor('noteheadBlack');

      // Stem down anchor should be on left side (negative X or zero)
      expect(anchor.dx, lessThanOrEqualTo(0));
    });

    test('Get stem anchors for noteheadHalf', () {
      final upAnchor = engine.getStemUpAnchor('noteheadHalf');
      final downAnchor = engine.getStemDownAnchor('noteheadHalf');

      expect(upAnchor, isNotNull);
      expect(downAnchor, isNotNull);
    });

    test('Get stem anchors for noteheadWhole', () {
      final upAnchor = engine.getStemUpAnchor('noteheadWhole');
      final downAnchor = engine.getStemDownAnchor('noteheadWhole');

      // Whole notes don't have stems, but anchors should exist
      expect(upAnchor, isNotNull);
      expect(downAnchor, isNotNull);
    });
  });

  group('SMuFLPositioningEngine - Flag Anchors', () {
    test('Get flag up anchor for flag8thUp', () {
      final anchor = engine.getFlagAnchor('flag8thUp');

      expect(anchor, isNotNull);
      expect(anchor, isA<Offset>());
    });

    test('Get flag down anchor for flag8thDown', () {
      final anchor = engine.getFlagAnchor('flag8thDown');

      expect(anchor, isNotNull);
      expect(anchor, isA<Offset>());
    });

    test('Flag anchors for all eighth note flags', () {
      final flags = ['flag8thUp', 'flag8thDown'];

      for (final flag in flags) {
        final anchor = engine.getFlagAnchor(flag);
        expect(anchor, isNotNull, reason: '$flag should have anchor');
      }
    });

    test('Flag anchors for sixteenth note flags', () {
      final flags = ['flag16thUp', 'flag16thDown'];

      for (final flag in flags) {
        final anchor = engine.getFlagAnchor(flag);
        expect(anchor, isNotNull, reason: '$flag should have anchor');
      }
    });
  });

  group('SMuFLPositioningEngine - Stem Length Calculation', () {
    test('Calculate stem length for note on staff', () {
      final length = engine.calculateStemLength(
        staffPosition: 0, // Middle line
        stemUp: true,
        beamCount: 0,
      );

      // Standard stem length is 3.5 staff spaces
      expect(length, greaterThanOrEqualTo(3.0));
      expect(length, lessThanOrEqualTo(4.0));
    });

    test('Stem length for beamed notes', () {
      final unbeamed = engine.calculateStemLength(
        staffPosition: 0,
        stemUp: true,
        beamCount: 0,
      );

      final beamed = engine.calculateStemLength(
        staffPosition: 0,
        stemUp: true,
        beamCount: 2,
        isBeamed: true,
      );

      // Beamed notes might have different stem length
      expect(beamed, greaterThan(0));
    });

    test('Stem length adjusts for extreme positions', () {
      // Note far from middle line
      final extremePos = engine.calculateStemLength(
        staffPosition: 8, // Very high
        stemUp: false, // Stem down
        beamCount: 0,
      );

      // Middle position
      final middlePos = engine.calculateStemLength(
        staffPosition: 0,
        stemUp: false,
        beamCount: 0,
      );

      // Extreme positions might have longer stems
      expect(extremePos, greaterThanOrEqualTo(middlePos));
    });

    test('Stem length with multiple beams', () {
      final singleBeam = engine.calculateStemLength(
        staffPosition: 0,
        stemUp: true,
        beamCount: 1,
        isBeamed: true,
      );

      final doubleBeam = engine.calculateStemLength(
        staffPosition: 0,
        stemUp: true,
        beamCount: 2,
        isBeamed: true,
      );

      // More beams might require longer stems
      expect(doubleBeam, greaterThanOrEqualTo(singleBeam));
    });
  });

  group('SMuFLPositioningEngine - Chord Stem Length', () {
    test('Calculate chord stem length for two-note chord', () {
      final positions = [0, 2]; // Two positions

      final length = engine.calculateChordStemLength(
        noteStaffPositions: positions,
        stemUp: true,
        beamCount: 0,
      );

      expect(length, greaterThan(0));
      expect(length, greaterThanOrEqualTo(3.5)); // Minimum stem length
    });

    test('Chord stem length for wide chord', () {
      final positions = [-4, 4]; // Wide spread (octave+)

      final length = engine.calculateChordStemLength(
        noteStaffPositions: positions,
        stemUp: true,
        beamCount: 0,
      );

      // Stem must span all notes
      expect(length, greaterThan(4.0));
    });

    test('Chord stem length for three-note chord', () {
      final positions = [0, 2, 4]; // Triad

      final length = engine.calculateChordStemLength(
        noteStaffPositions: positions,
        stemUp: true,
        beamCount: 0,
      );

      expect(length, greaterThanOrEqualTo(3.5));
    });

    test('Chord stem direction affects length calculation', () {
      final positions = [0, 2, 4];

      final stemUpLength = engine.calculateChordStemLength(
        noteStaffPositions: positions,
        stemUp: true,
        beamCount: 0,
      );

      final stemDownLength = engine.calculateChordStemLength(
        noteStaffPositions: positions,
        stemUp: false,
        beamCount: 0,
      );

      // Both should be positive and similar
      expect(stemUpLength, greaterThan(0));
      expect(stemDownLength, greaterThan(0));
    });
  });

  group('SMuFLPositioningEngine - Beam Thickness', () {
    test('Get beam thickness', () {
      final thickness = engine.getBeamThickness();

      // Beam thickness is typically 0.5 staff spaces
      expect(thickness, greaterThan(0));
      expect(thickness, closeTo(0.5, 0.1));
    });
  });

  group('SMuFLPositioningEngine - Fallback Values', () {
    test('Unknown glyph returns default stem up anchor', () {
      final anchor = engine.getStemUpAnchor('unknownGlyph12345');

      // Should return fallback value
      expect(anchor, isNotNull);
      expect(anchor, isA<Offset>());
    });

    test('Unknown glyph returns default stem down anchor', () {
      final anchor = engine.getStemDownAnchor('unknownGlyph12345');

      // Should return fallback value
      expect(anchor, isNotNull);
      expect(anchor, isA<Offset>());
    });

    test('Unknown flag returns default anchor', () {
      final anchor = engine.getFlagAnchor('unknownFlag12345');

      // Should return fallback value
      expect(anchor, isNotNull);
      expect(anchor, isA<Offset>());
    });
  });

  group('SMuFLPositioningEngine - Consistency', () {
    test('Stem anchors are consistent for same glyph', () {
      final anchor1 = engine.getStemUpAnchor('noteheadBlack');
      final anchor2 = engine.getStemUpAnchor('noteheadBlack');

      expect(anchor1.dx, equals(anchor2.dx));
      expect(anchor1.dy, equals(anchor2.dy));
    });

    test('Flag anchors are consistent for same glyph', () {
      final anchor1 = engine.getFlagAnchor('flag8thUp');
      final anchor2 = engine.getFlagAnchor('flag8thUp');

      expect(anchor1.dx, equals(anchor2.dx));
      expect(anchor1.dy, equals(anchor2.dy));
    });
  });

  group('SMuFLPositioningEngine - Integration', () {
    test('Stem and flag anchors work together', () {
      // Get stem up anchor
      final stemAnchor = engine.getStemUpAnchor('noteheadBlack');

      // Get flag anchor
      final flagAnchor = engine.getFlagAnchor('flag8thUp');

      // Both should be valid offsets
      expect(stemAnchor, isNotNull);
      expect(flagAnchor, isNotNull);
    });

    test('Stem length calculation uses reasonable values', () {
      final positions = [-4, -2, 0, 2, 4]; // Various staff positions

      for (final pos in positions) {
        final length = engine.calculateStemLength(
          staffPosition: pos,
          stemUp: true,
          beamCount: 0,
        );

        // All stem lengths should be reasonable (2-6 staff spaces)
        expect(length, greaterThan(2.0));
        expect(length, lessThan(6.0));
      }
    });
  });
}
