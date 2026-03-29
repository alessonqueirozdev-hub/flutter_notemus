import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/renderers/group_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GroupRenderer renderer;

  setUpAll(() async {
    final metadata = SmuflMetadata();
    await metadata.load();
    renderer = GroupRenderer(
      coordinates: StaffCoordinateSystem(
        staffSpace: 12,
        staffBaseline: Offset(0, 120),
      ),
      metadata: metadata,
      theme: const MusicScoreTheme(),
      glyphSize: 48,
      staffLineThickness: 1,
      stemThickness: 1,
    );
  });

  group('GroupRenderer identifyTieGroups', () {
    test('captures tied chord spans when ties live in chord notes', () {
      final elements = [
        PositionedElement(
          Chord(
            notes: [
              Note(
                pitch: const Pitch(step: 'C', octave: 4),
                duration: const Duration(DurationType.quarter),
                tie: TieType.start,
              ),
              Note(
                pitch: const Pitch(step: 'E', octave: 4),
                duration: const Duration(DurationType.quarter),
                tie: TieType.start,
              ),
            ],
            duration: const Duration(DurationType.quarter),
          ),
          const Offset(40, 120),
        ),
        PositionedElement(
          Chord(
            notes: [
              Note(
                pitch: const Pitch(step: 'C', octave: 4),
                duration: const Duration(DurationType.quarter),
                tie: TieType.end,
              ),
              Note(
                pitch: const Pitch(step: 'E', octave: 4),
                duration: const Duration(DurationType.quarter),
                tie: TieType.end,
              ),
            ],
            duration: const Duration(DurationType.quarter),
          ),
          const Offset(96, 120),
        ),
      ];

      final groups = renderer.identifyTieGroups(elements);

      expect(groups, hasLength(1));
      expect(groups.values.single, orderedEquals(const [0, 1]));
    });
  });

  group('GroupRenderer identifySlurGroups', () {
    test('captures slur spans across note and chord elements', () {
      final elements = [
        PositionedElement(
          Chord(
            notes: [
              Note(
                pitch: const Pitch(step: 'F', octave: 4),
                duration: const Duration(DurationType.quarter),
                slur: SlurType.start,
              ),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            ],
            duration: const Duration(DurationType.quarter),
          ),
          const Offset(40, 120),
        ),
        PositionedElement(
          Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.quarter),
          ),
          const Offset(88, 108),
        ),
        PositionedElement(
          Chord(
            notes: [
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
                slur: SlurType.end,
              ),
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: const Duration(DurationType.quarter),
              ),
            ],
            duration: const Duration(DurationType.quarter),
          ),
          const Offset(136, 120),
        ),
      ];

      final groups = renderer.identifySlurGroups(elements);

      expect(groups, hasLength(1));
      expect(groups.values.single, orderedEquals(const [0, 1, 2]));
    });
  });
}
