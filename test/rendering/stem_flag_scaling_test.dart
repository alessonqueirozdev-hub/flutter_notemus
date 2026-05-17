// Regression coverage for issue #4:
// Stem/flag attachment must be derived from SMuFL engraving defaults and scale
// proportionally with staffSpace (no fixed raw-pixel nudge constants).

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';
import 'package:flutter_notemus/src/rendering/renderers/primitives/stem_renderer.dart';
import 'package:flutter_notemus/src/rendering/renderers/primitives/flag_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  late SMuFLPositioningEngine engine;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    engine = SMuFLPositioningEngine(metadataLoader: metadata);
  });

  group('stem attachment proportionality (issue #4)', () {
    test('offset scales linearly with staffSpace for an up stem', () {
      final a = engine.calculateStemAttachmentOffset(
        noteheadGlyphName: 'noteheadBlack',
        stemUp: true,
        staffSpace: 12,
      );
      final b = engine.calculateStemAttachmentOffset(
        noteheadGlyphName: 'noteheadBlack',
        stemUp: true,
        staffSpace: 24,
      );

      // Doubling staffSpace must exactly double both components: this proves
      // there is no constant pixel term left (the old 0.7/-0.8 constants).
      expect(b.dx, closeTo(a.dx * 2, 1e-9));
      expect(b.dy, closeTo(a.dy * 2, 1e-9));
    });

    test('offset scales linearly with staffSpace for a down stem', () {
      final a = engine.calculateStemAttachmentOffset(
        noteheadGlyphName: 'noteheadBlack',
        stemUp: false,
        staffSpace: 10,
      );
      final b = engine.calculateStemAttachmentOffset(
        noteheadGlyphName: 'noteheadBlack',
        stemUp: false,
        staffSpace: 30,
      );

      expect(b.dx, closeTo(a.dx * 3, 1e-9));
      expect(b.dy, closeTo(a.dy * 3, 1e-9));
    });
  });

  group('StemRenderer/FlagRenderer smoke at multiple scales (issue #4)', () {
    Offset renderStemAt(double staffSpace) {
      final coordinates = StaffCoordinateSystem(
        staffSpace: staffSpace,
        staffBaseline: Offset(0, staffSpace * 10),
      );
      final stem = StemRenderer(
        metadata: metadata,
        theme: const MusicScoreTheme(),
        coordinates: coordinates,
        glyphSize: staffSpace * 4,
        stemThickness: 0.12 * staffSpace,
        positioningEngine: engine,
      );
      final flag = FlagRenderer(
        metadata: metadata,
        theme: const MusicScoreTheme(),
        coordinates: coordinates,
        glyphSize: staffSpace * 4,
        positioningEngine: engine,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final stemEnd = stem.render(
        canvas,
        const Offset(100, 100),
        'noteheadBlack',
        0,
        true,
        1,
      );
      flag.render(canvas, stemEnd, DurationType.eighth, true);
      recorder.endRecording();
      return stemEnd;
    }

    test('renders without throwing and the stem X scales with staffSpace', () {
      final small = renderStemAt(6);
      final large = renderStemAt(48);

      expect(small.dx.isFinite, isTrue);
      expect(large.dx.isFinite, isTrue);
      // Horizontal attachment offset grows with staffSpace.
      expect((large.dx - 100).abs(), greaterThan((small.dx - 100).abs()));
    });
  });
}
