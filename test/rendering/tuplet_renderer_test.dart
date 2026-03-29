import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/articulation_renderer.dart';
import 'package:flutter_notemus/src/rendering/renderers/note_renderer.dart';
import 'package:flutter_notemus/src/rendering/renderers/ornament_renderer.dart';
import 'package:flutter_notemus/src/rendering/renderers/rest_renderer.dart';
import 'package:flutter_notemus/src/rendering/renderers/tuplet_renderer.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  late TupletRenderer renderer;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();

    const staffSpace = 12.0;
    const glyphSize = staffSpace * 4.0;
    const theme = MusicScoreTheme();
    final coordinates = StaffCoordinateSystem(
      staffSpace: staffSpace,
      staffBaseline: const Offset(0, 200),
    );
    final positioningEngine = SMuFLPositioningEngine(metadataLoader: metadata);
    final ornamentRenderer = OrnamentRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      staffLineThickness: 1.0,
    );
    final articulationRenderer = ArticulationRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
    );
    final noteRenderer = NoteRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      staffLineThickness: 1.0,
      stemThickness: 1.0,
      articulationRenderer: articulationRenderer,
      ornamentRenderer: ornamentRenderer,
      positioningEngine: positioningEngine,
    );
    final restRenderer = RestRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      ornamentRenderer: ornamentRenderer,
    );

    renderer = TupletRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
      noteRenderer: noteRenderer,
      restRenderer: restRenderer,
      positioningEngine: positioningEngine,
    );
  });

  test(
    'keeps an eighth rest centered between tupletted eighth-note centers',
    () {
      final tripletElements = <MusicalElement>[
        Note(
          pitch: const Pitch(step: 'G', octave: 4),
          duration: const Duration(DurationType.eighth),
        ),
        Rest(duration: const Duration(DurationType.eighth)),
        Note(
          pitch: const Pitch(step: 'B', octave: 4),
          duration: const Duration(DurationType.eighth),
        ),
      ];

      final slotCenterOffset = renderer.calculateTupletSlotCenterOffset(
        tripletElements,
      );
      const firstSlotX = 100.0;
      const middleSlotX = 130.0;
      const lastSlotX = 160.0;

      final middleRestAnchor = renderer.resolveTupletElementAnchorX(
        element: tripletElements[1],
        slotX: middleSlotX,
        slotCenterOffset: slotCenterOffset,
      );

      final firstNoteCenter = firstSlotX + slotCenterOffset;
      final lastNoteCenter = lastSlotX + slotCenterOffset;

      expect(
        middleRestAnchor,
        closeTo((firstNoteCenter + lastNoteCenter) / 2, 0.001),
      );
    },
  );
}
