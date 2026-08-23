// Pins beam geometry to the SMuFL `engravingDefaults` of the loaded font.
//
// Regression guard for the 2.7.1 forensic finding M-15: `BeamRenderer`
// hardcoded `beamThickness = 0.4 * staffSpace` and `beamGap = 0.60 *
// staffSpace` while the Bravura metadata this package loads declares
// `beamThickness: 0.5` and `beamSpacing: 0.25`. The principal beam drawer
// therefore contradicted the metadata it was handed, and disagreed with the
// second beam drawer inside `TupletRenderer`, so four sixteenths outside a
// tuplet and three inside one came out of the SAME bar with visibly different
// band thickness and different gaps.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/beaming/beam_renderer.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  BeamRenderer rendererAt(double staffSpace) => BeamRenderer(
        theme: const MusicScoreTheme(),
        staffSpace: staffSpace,
        noteheadWidth: metadata.getGlyphWidth('noteheadBlack') * staffSpace,
        positioningEngine: SMuFLPositioningEngine(metadataLoader: metadata),
      );

  group('BeamRenderer geometry comes from engravingDefaults', () {
    test('beam thickness and gap equal the font metadata, not old literals',
        () {
      // The bundled font is Bravura: beamThickness 0.5, beamSpacing 0.25.
      final thicknessSpaces = metadata.getEngravingDefault('beamThickness', -1);
      final spacingSpaces = metadata.getEngravingDefault('beamSpacing', -1);
      expect(thicknessSpaces, 0.5,
          reason: 'bravura_metadata.json is the source of truth');
      expect(spacingSpaces, 0.25);

      const double staffSpace = 40.0;
      final r = rendererAt(staffSpace);

      expect(r.beamThickness, closeTo(thicknessSpaces * staffSpace, 1e-9));
      expect(r.beamGap, closeTo(spacingSpaces * staffSpace, 1e-9));

      // The literals that used to be here, pinned so a re-hardcode is loud.
      expect(r.beamThickness, isNot(closeTo(0.4 * staffSpace, 1e-9)));
      expect(r.beamGap, isNot(closeTo(0.60 * staffSpace, 1e-9)));
    });

    test('stem thickness comes from engravingDefaults.stemThickness', () {
      const double staffSpace = 40.0;
      final expected =
          metadata.getEngravingDefault('stemThickness', 0.12) * staffSpace;
      expect(rendererAt(staffSpace).stemThickness, closeTo(expected, 1e-9));
    });

    test('the stacked beam height follows the metadata at every beam count',
        () {
      // Measured at staffSpace = 40 px by counting dark pixel runs down a
      // column in the middle of a rendered two-level group:
      //   hardcoded (0.40/0.60): band 16 px, gap 24 px, stack 56 px = 1.40 SS
      //   metadata  (0.50/0.25): band 20 px, gap 10 px, stack 50 px = 1.25 SS
      // The conformant stack is SHORTER, not heavier, which is why no
      // corrective scale factor is applied on top of the metadata.
      const double staffSpace = 40.0;
      final r = rendererAt(staffSpace);

      expect(r.calculateTotalBeamHeight(0), 0);
      expect(r.calculateTotalBeamHeight(1), closeTo(20.0, 1e-9));
      expect(r.calculateTotalBeamHeight(2), closeTo(50.0, 1e-9));
      expect(r.calculateTotalBeamHeight(3), closeTo(80.0, 1e-9));
    });

    test('geometry scales linearly with staffSpace', () {
      final small = rendererAt(10.0);
      final big = rendererAt(30.0);
      expect(big.beamThickness, closeTo(small.beamThickness * 3, 1e-9));
      expect(big.beamGap, closeTo(small.beamGap * 3, 1e-9));
      expect(big.stemThickness, closeTo(small.stemThickness * 3, 1e-9));
    });
  });
}
