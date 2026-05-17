// Regression coverage for issue #5:
// repeatBoth must render robustly — via the combined repeatLeftRight glyph
// when available, or composed from repeatRight + repeatLeft otherwise.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/barline_renderer.dart';
import 'package:flutter_notemus/src/rendering/renderers/glyph_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  late BarlineRenderer renderer;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    renderer = BarlineRenderer(
      coordinates: StaffCoordinateSystem(
        staffSpace: 12,
        staffBaseline: Offset(0, 120),
      ),
      metadata: metadata,
      theme: const MusicScoreTheme(),
      glyphRenderer: GlyphRenderer(metadata: metadata),
      glyphSize: 48,
    );
  });

  group('repeatBoth fallback data dependencies (issue #5)', () {
    test('the composing glyphs exist with usable metrics', () {
      // Even if the combined glyph were missing, the fallback can compose.
      expect(metadata.hasGlyph('repeatRight'), isTrue);
      expect(metadata.hasGlyph('repeatLeft'), isTrue);
      expect(metadata.getCodepoint('repeatRight'), isNotEmpty);
      expect(metadata.getCodepoint('repeatLeft'), isNotEmpty);
      expect(
        metadata.getGlyphAdvanceWidth('repeatRight'),
        isNotNull,
      );
      expect(
        metadata.getGlyphAdvanceWidth('repeatRight')!,
        greaterThan(0),
      );
    });
  });

  group('barline rendering smoke (issue #5)', () {
    test('every barline type renders without throwing', () {
      for (final type in BarlineType.values) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        expect(
          () => renderer.render(
            canvas,
            Barline(type: type),
            const Offset(50, 50),
          ),
          returnsNormally,
          reason: 'BarlineType.$type should render',
        );
        recorder.endRecording();
      }
    });

    test('repeatBoth renders without throwing', () {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      expect(
        () => renderer.render(
          canvas,
          Barline(type: BarlineType.repeatBoth),
          const Offset(80, 40),
        ),
        returnsNormally,
      );
      recorder.endRecording();
    });
  });
}
