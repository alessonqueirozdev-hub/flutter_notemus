// Regression coverage for issue #3:
// Staff-group brace prefers the SMuFL `brace` glyph and degrades gracefully to
// a custom path when SMuFL metadata is unavailable.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/bracket_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  group('SMuFL brace glyph (issue #3)', () {
    test('the brace glyph is present with a usable bounding box', () {
      expect(metadata.hasGlyph('brace'), isTrue);
      expect(metadata.getCodepoint('brace'), isNotEmpty);
      final bbox = metadata.getGlyphBoundingBox('brace');
      expect(bbox, isNotNull);
      expect(bbox!.height, greaterThan(0));
    });

    test('renders a brace group with metadata (glyph path)', () {
      final renderer = BracketRenderer(
        coordinates: StaffCoordinateSystem(
          staffSpace: 12,
          staffBaseline: Offset(0, 120),
        ),
        theme: const MusicScoreTheme(),
        metadata: metadata,
      );
      final group = StaffGroup(
        staves: [Staff()],
        bracket: BracketType.brace,
        name: 'Piano',
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      expect(
        () => renderer.render(canvas, group, 100, 340, 40),
        returnsNormally,
      );
      recorder.endRecording();
    });

    test('renders a brace group without metadata (fallback path)', () {
      final renderer = BracketRenderer(
        coordinates: StaffCoordinateSystem(
          staffSpace: 12,
          staffBaseline: Offset(0, 120),
        ),
        theme: const MusicScoreTheme(),
      );
      final group = StaffGroup(
        staves: [Staff()],
        bracket: BracketType.brace,
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      expect(
        () => renderer.render(canvas, group, 100, 340, 40),
        returnsNormally,
      );
      recorder.endRecording();
    });
  });
}
