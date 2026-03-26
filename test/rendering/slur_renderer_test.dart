import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/grace_note_geometry.dart';
import 'package:flutter_notemus/src/rendering/renderers/slur_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  late SlurRenderer renderer;
  const staffSpace = 12.0;
  const notePos = Offset(100, 200);
  final clef = Clef(clefType: ClefType.treble);

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    renderer = SlurRenderer(staffSpace: staffSpace, metadata: metadata);
  });

  group('SlurRenderer endpoint geometry', () {
    test(
      'anchors ordinary slur starts near the right edge of the notehead',
      () {
        final note = Note(
          pitch: const Pitch(step: 'C', octave: 4),
          duration: const Duration(DurationType.quarter),
        );
        final bbox = metadata.getGlyphBoundingBox(
          note.duration.type.glyphName,
        )!;
        final expectedRightEdge = notePos.dx + (bbox.bBoxNeX * staffSpace);
        final edgeInset = (bbox.width * staffSpace * 0.16).clamp(
          0.0,
          staffSpace * 0.14,
        );

        final endpoint = renderer.calculateSlurEndpointForTesting(
          notePos,
          note,
          clef,
          isStart: true,
          above: false,
        );

        expect(endpoint.dx, closeTo(expectedRightEdge - edgeInset, 0.001));
        expect(endpoint.dx, greaterThan(notePos.dx));
      },
    );

    test('anchors grace slur starts from the grace-note geometry', () {
      final note = Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
      );
      final expected = graceSlurStartPointForNote(
        note: note,
        notePos: notePos,
        above: true,
        staffSpace: staffSpace,
        glyphSize: staffSpace * 4.0,
        metadata: metadata,
      );

      final endpoint = renderer.calculateSlurEndpointForTesting(
        notePos,
        note,
        clef,
        isStart: true,
        above: true,
      );

      expect(endpoint, expected);
      expect(endpoint.dx, lessThan(notePos.dx));
    });

    test('uses duration-specific notehead geometry for tie endpoints', () {
      final startNote = Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.whole),
      );
      final endNote = Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.whole),
      );
      final endPos = const Offset(160, 200);
      final bbox = metadata.getGlyphBoundingBox(
        startNote.duration.type.glyphName,
      )!;
      final edgePadding = staffSpace * 0.08;
      final expectedStartX =
          notePos.dx + (bbox.bBoxNeX * staffSpace) - edgePadding;
      final expectedEndX =
          endPos.dx + (bbox.bBoxSwX * staffSpace) + edgePadding;

      final (startPoint, endPoint) = renderer.calculateTieEndpointsForTesting(
        notePos,
        startNote,
        endPos,
        endNote,
        tieAbove: false,
      );

      expect(startPoint.dx, closeTo(expectedStartX, 0.001));
      expect(endPoint.dx, closeTo(expectedEndX, 0.001));
    });
  });
}
