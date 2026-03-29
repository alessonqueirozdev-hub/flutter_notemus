import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  late SMuFLPositioningEngine engine;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    engine = SMuFLPositioningEngine(metadataLoader: metadata);
  });

  group('SMuFLPositioningEngine.calculateAccidentalPosition', () {
    test('uses notehead cutOutNW to move the accidental closer', () {
      final basePosition = engine.calculateAccidentalPosition(
        accidentalGlyph: 'accidentalSharp',
        noteheadGlyph: 'missingNotehead',
        staffPosition: 0,
      );
      final positioned = engine.calculateAccidentalPosition(
        accidentalGlyph: 'accidentalSharp',
        noteheadGlyph: 'noteheadBlack',
        staffPosition: 0,
      );
      final cutOutNW = metadata.getGlyphAnchor('noteheadBlack', 'cutOutNW');

      expect(cutOutNW, isNotNull);
      expect(cutOutNW!.dx, greaterThan(0));
      expect(positioned.dx, closeTo(basePosition.dx + cutOutNW.dx, 0.0001));
      expect(positioned.dx, greaterThan(basePosition.dx));
      expect(positioned.dy, 0);
    });

    test('falls back to base spacing when the notehead has no cut-out', () {
      final accidentalWidth = metadata.getGlyphWidth('accidentalSharp');
      final positioned = engine.calculateAccidentalPosition(
        accidentalGlyph: 'accidentalSharp',
        noteheadGlyph: 'missingNotehead',
        staffPosition: 0,
      );

      expect(
        positioned.dx,
        closeTo(-(accidentalWidth + engine.accidentalToNoteheadDistance), 0.0001),
      );
      expect(positioned.dy, 0);
    });

    test('falls back to a default accidental width when metadata is missing', () {
      final positioned = engine.calculateAccidentalPosition(
        accidentalGlyph: 'missingAccidental',
        noteheadGlyph: 'missingNotehead',
        staffPosition: 0,
      );

      expect(
        positioned.dx,
        closeTo(-(1.0 + engine.accidentalToNoteheadDistance), 0.0001),
      );
      expect(positioned.dy, 0);
    });
  });

  group('SMuFLPositioningEngine.calculateStemStartY', () {
    test('extends upward stems slightly into the notehead', () {
      const noteY = 100.0;
      const staffSpace = 12.0;

      final attachment = engine.calculateStemAttachmentOffset(
        noteheadGlyphName: 'noteheadBlack',
        stemUp: true,
        staffSpace: staffSpace,
      );
      final stemStartY = engine.calculateStemStartY(
        noteY: noteY,
        noteheadGlyphName: 'noteheadBlack',
        stemUp: true,
        staffSpace: staffSpace,
      );

      expect(
        stemStartY,
        closeTo(
          noteY + attachment.dy + ((engine.stemThickness * staffSpace) * 0.5),
          0.0001,
        ),
      );
      expect(stemStartY, greaterThan(noteY + attachment.dy));
    });

    test('extends downward stems slightly into the notehead', () {
      const noteY = 100.0;
      const staffSpace = 12.0;

      final attachment = engine.calculateStemAttachmentOffset(
        noteheadGlyphName: 'noteheadBlack',
        stemUp: false,
        staffSpace: staffSpace,
      );
      final stemStartY = engine.calculateStemStartY(
        noteY: noteY,
        noteheadGlyphName: 'noteheadBlack',
        stemUp: false,
        staffSpace: staffSpace,
      );

      expect(
        stemStartY,
        closeTo(
          noteY - ((engine.stemThickness * staffSpace) * 0.5) + attachment.dy,
          0.0001,
        ),
      );
      expect(stemStartY, lessThan(noteY + attachment.dy));
    });
  });
}
