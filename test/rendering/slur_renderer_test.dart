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

  // staffBaselineY = notePos.dy so notes AT position 0 stay at y=200
  const staffBaselineY = 200.0;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    renderer = SlurRenderer(
      staffSpace: staffSpace,
      staffBaselineY: staffBaselineY,
      metadata: metadata,
    );
  });

  group('SlurRenderer endpoint geometry', () {
    test('anchors below slurs on the stem-free side for stem-up notes', () {
      final note = Note(
        pitch: const Pitch(step: 'C', octave: 4),
        duration: const Duration(DurationType.quarter),
      );
      final bbox = metadata.getGlyphBoundingBox(note.duration.type.glyphName)!;
      final noteCenterX = notePos.dx + (bbox.centerX * staffSpace);

      final endpoint = renderer.calculateSlurEndpointForTesting(
        notePos,
        note,
        clef,
        isStart: true,
        above: false,
        stemUp: true,
      );

      expect(endpoint.dx, lessThan(noteCenterX));
    });

    test('anchors above slurs on the stem-free side for stem-down notes', () {
      final note = Note(
        pitch: const Pitch(step: 'B', octave: 4),
        duration: const Duration(DurationType.quarter),
      );
      final bbox = metadata.getGlyphBoundingBox(note.duration.type.glyphName)!;
      final noteCenterX = notePos.dx + (bbox.centerX * staffSpace);

      final endpoint = renderer.calculateSlurEndpointForTesting(
        notePos,
        note,
        clef,
        isStart: false,
        above: true,
        stemUp: false,
      );

      expect(endpoint.dx, greaterThan(noteCenterX));
    });

    test('anchors grace slur starts from the grace-note geometry', () {
      final note = Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
        ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
      );

      // SlurRenderer now computes the ACTUAL note Y from pitch before delegating
      // to graceSlurStartPointForNote, so expected must use the same note Y.
      final staffPos = StaffPositionCalculator.calculate(note.pitch, clef);
      final noteY = StaffPositionCalculator.toPixelY(
        staffPos,
        staffSpace,
        staffBaselineY,
      );
      final adjustedNotePos = Offset(notePos.dx, noteY);

      final expected = graceSlurStartPointForNote(
        note: note,
        notePos: adjustedNotePos,
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

    test('keeps tie endpoints on the stem-free side for stem-up notes', () {
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
      final startCenterX = notePos.dx + (bbox.centerX * staffSpace);
      final endCenterX = endPos.dx + (bbox.centerX * staffSpace);

      final (startPoint, endPoint) = renderer.calculateTieEndpointsForTesting(
        notePos,
        startNote,
        endPos,
        endNote,
        tieAbove: false,
        clef: clef,
        startStemUp: true,
        endStemUp: true,
      );

      expect(startPoint.dx, lessThan(startCenterX));
      expect(endPoint.dx, lessThan(endCenterX));
    });
  });
}
