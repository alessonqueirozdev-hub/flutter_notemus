import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../theme/music_score_theme.dart';
import '../staff_position_calculator.dart';
import 'base_glyph_renderer.dart';
import 'note_renderer.dart';
import 'primitives/dot_renderer.dart';

class ChordRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final double staffLineThickness;
  final double stemThickness;
  final NoteRenderer noteRenderer;

  ChordRenderer({
    required super.coordinates,
    required super.metadata,
    required this.theme,
    required super.glyphSize,
    required this.staffLineThickness,
    required this.stemThickness,
    required this.noteRenderer,
  });

  static List<double> calculateClusterOffsets({
    required List<int> positions,
    required bool stemUp,
    required double clusterOffset,
  }) {
    final offsets = List<double>.filled(positions.length, 0.0);
    int runStart = 0;

    while (runStart < positions.length) {
      int runEnd = runStart;
      while (runEnd < positions.length - 1 &&
          (positions[runEnd] - positions[runEnd + 1]).abs() <= 1) {
        runEnd++;
      }

      if (runEnd > runStart) {
        // Per "Behind Bars" (Gould p.68-69):
        // Stem-UP:   upper note of each adjacent pair shifts RIGHT (+)
        // Stem-DOWN: lower note of each adjacent pair shifts LEFT  (-)
        // Positions list is sorted highest-first, so:
        //   index 0 = topmost note, index N-1 = bottommost note
        final shiftSign = stemUp ? 1.0 : -1.0;
        for (int index = runStart; index <= runEnd; index++) {
          final bool shouldShift = stemUp
              ? (runEnd - index) % 2 ==
                    1 // stem-up: shifts upper note right
              : (index - runStart) % 2 ==
                    1; // stem-down: shifts lower note left
          offsets[index] = shouldShift ? (shiftSign * clusterOffset) : 0.0;
        }
      }

      runStart = runEnd + 1;
    }

    return offsets;
  }

  static bool resolveStemDirection({
    required Chord chord,
    required List<int> positions,
    int? voiceNumber,
  }) {
    if (voiceNumber != null) {
      return voiceNumber.isOdd;
    }

    if (chord.voice != null) {
      return chord.voice!.isOdd;
    }

    final mostExtremePos = positions.reduce(
      (left, right) => left.abs() > right.abs() ? left : right,
    );
    return mostExtremePos > 0;
  }

  void render(
    Canvas canvas,
    Chord chord,
    Offset basePosition,
    Clef currentClef, {
    int? voiceNumber,
  }) {
    final sortedNotes = [...chord.notes]
      ..sort(
        (a, b) => StaffPositionCalculator.calculate(
          b.pitch,
          currentClef,
        ).compareTo(StaffPositionCalculator.calculate(a.pitch, currentClef)),
      );

    final positions = sortedNotes
        .map(
          (note) => StaffPositionCalculator.calculate(note.pitch, currentClef),
        )
        .toList();
    final stemUp = resolveStemDirection(
      chord: chord,
      positions: positions,
      voiceNumber: voiceNumber,
    );

    final noteheadGlyph = chord.duration.type.glyphName;
    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final noteheadBox = noteheadInfo?.boundingBox;
    final noteheadCenterX = noteheadBox != null
        ? ((noteheadBox.bBoxSwX + noteheadBox.bBoxNeX) / 2) *
              coordinates.staffSpace
        : (1.18 / 2) * coordinates.staffSpace;
    final noteheadCenterY = noteheadBox != null
        ? noteheadBox.centerY * coordinates.staffSpace
        : 0.0;
    final noteheadWidth = noteheadBox?.width ?? 1.18;
    final clusterOffset = noteheadWidth * coordinates.staffSpace * 1.04;
    final clusterOffsets = calculateClusterOffsets(
      positions: positions,
      stemUp: stemUp,
      clusterOffset: clusterOffset,
    );
    final noteCenters = <Offset>[];

    // ── Pre-compute accidental columns BEFORE drawing anything ──
    // All accidentals are placed to the LEFT of the leftmost notehead.
    // Each accidental gets a column: 0 = closest to notes, higher = further left.
    // Two accidentals collide vertically if within 6 staff positions (SMuFL standard).
    final accidentalColumns = <int, int>{};
    const accidentalCollisionDistance = 6;

    for (int i = 0; i < sortedNotes.length; i++) {
      if (sortedNotes[i].pitch.accidentalGlyph == null) continue;

      int column = 0;
      for (int c = 0; c < sortedNotes.length; c++) {
        bool collision = false;
        for (final entry in accidentalColumns.entries) {
          if (entry.value == c &&
              (positions[i] - positions[entry.key]).abs() <=
                  accidentalCollisionDistance) {
            collision = true;
            break;
          }
        }
        if (!collision) {
          column = c;
          break;
        }
        column = c + 1;
      }
      accidentalColumns[i] = column;
    }

    // ── Draw accidentals ──
    // All accidentals are positioned relative to basePosition.dx (the chord's
    // musical x), NOT the individual note cluster offsets. This ensures all
    // accidentals stay to the LEFT of ALL noteheads regardless of clustering.
    for (final entry in accidentalColumns.entries) {
      final i = entry.key;
      final column = entry.value;
      final note = sortedNotes[i];
      final accidentalGlyph = note.pitch.accidentalGlyph!;
      final rawWidth = metadata.getGlyphWidth(accidentalGlyph);
      final accidentalWidth = rawWidth > 0 ? rawWidth : 1.0;

      const accidentalClearance = 0.25;
      final baseOffset =
          (accidentalWidth + accidentalClearance) * coordinates.staffSpace;
      final columnSpacing =
          (accidentalWidth + accidentalClearance) * coordinates.staffSpace;

      final staffPosition = positions[i];
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );

      final accidentalX =
          basePosition.dx - baseOffset - (column * columnSpacing);

      drawGlyphWithBBox(
        canvas,
        glyphName: accidentalGlyph,
        position: Offset(accidentalX, noteY),
        color: theme.accidentalColor ?? theme.noteheadColor,
        options: const GlyphDrawOptions(trackBounds: true),
      );
    }

    // ── Draw noteheads and ledger lines ──
    for (int index = 0; index < sortedNotes.length; index++) {
      final staffPosition = positions[index];
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );
      final noteX = basePosition.dx + clusterOffsets[index];
      final noteCenter = Offset(
        noteX + noteheadCenterX,
        noteY + noteheadCenterY,
      );
      noteCenters.add(noteCenter);

      // Center ledger lines on the notehead's visual center, not its left edge.
      final ledgerCenterX = noteX + noteheadCenterX;
      _drawLedgerLines(
        canvas,
        ledgerCenterX,
        staffPosition,
        noteheadGlyph: noteheadGlyph,
      );

      drawGlyphWithBBox(
        canvas,
        glyphName: noteheadGlyph,
        position: Offset(noteX, noteY),
        color: theme.noteheadColor,
        options: GlyphDrawOptions.noteheadDefault,
      );

      _renderDots(
        canvas,
        dots: chord.duration.dots,
        noteCenter: noteCenter,
        staffPosition: staffPosition,
      );
    }

    if (chord.duration.type != DurationType.whole && positions.isNotEmpty) {
      final stemNoteIndex = stemUp ? positions.length - 1 : 0;
      final stemY = StaffPositionCalculator.toPixelY(
        positions[stemNoteIndex],
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );
      final beamCount = _getBeamCount(chord.duration.type);
      final customStemLength = noteRenderer.positioningEngine
          .calculateChordStemLength(
            noteStaffPositions: positions,
            stemUp: stemUp,
            beamCount: beamCount,
          );

      final stemEnd = _renderChordStem(
        canvas,
        Offset(basePosition.dx + clusterOffsets[stemNoteIndex], stemY),
        noteheadGlyph,
        stemUp,
        customStemLength,
      );

      if (chord.duration.type.value < 0.25 && chord.beam == null) {
        noteRenderer.flagRenderer.render(
          canvas,
          stemEnd,
          chord.duration.type,
          stemUp,
        );
      }
    }

    if (noteCenters.isEmpty) return;

    final minCenterX = noteCenters
        .map((center) => center.dx)
        .reduce((left, right) => left < right ? left : right);
    final maxCenterX = noteCenters
        .map((center) => center.dx)
        .reduce((left, right) => left > right ? left : right);
    final chordCenter = Offset(
      (minCenterX + maxCenterX) * 0.5,
      basePosition.dy,
    );

    if (chord.ornaments.isNotEmpty) {
      // For arpeggio positioning: use a stable anchor at the chord's base
      // position (center of notehead at basePosition.dx) instead of the
      // leftmost cluster-shifted note center. This prevents cluster offsets
      // from displacing the arpeggio sign too far left.
      noteRenderer.ornamentRenderer.renderForChord(
        canvas,
        chord,
        chordCenter,
        positions.first,
        positions.last,
        voiceNumber: voiceNumber,
        leadingNoteCenterX: minCenterX,
        arpeggioReferenceCenterX: stemUp ? minCenterX : maxCenterX,
        stemUp: stemUp,
      );
    }

    if (chord.dynamic != null) {
      noteRenderer.symbolAndTextRenderer.renderDynamic(
        canvas,
        chord.dynamic!,
        Offset(chordCenter.dx, basePosition.dy),
      );
    }
  }

  int _getBeamCount(DurationType duration) {
    return switch (duration) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      _ => 0,
    };
  }

  void _drawLedgerLines(
    Canvas canvas,
    double noteCenterX,
    int staffPosition, {
    required String noteheadGlyph,
  }) {
    if (!theme.showLedgerLines ||
        !StaffPositionCalculator.needsLedgerLines(staffPosition)) {
      return;
    }

    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth = staffLineThickness;
    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;
    final noteWidthPixels =
        bbox?.widthInPixels(coordinates.staffSpace) ??
        (coordinates.staffSpace * 1.18);
    final extension = coordinates.staffSpace * 0.4;
    final totalWidth = noteWidthPixels + (2 * extension);
    final ledgerPositions = StaffPositionCalculator.getLedgerLinePositions(
      staffPosition,
    );

    for (final ledgerPosition in ledgerPositions) {
      final y = StaffPositionCalculator.toPixelY(
        ledgerPosition,
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );
      canvas.drawLine(
        Offset(noteCenterX - (totalWidth / 2), y),
        Offset(noteCenterX + (totalWidth / 2), y),
        paint,
      );
    }
  }

  Offset _renderChordStem(
    Canvas canvas,
    Offset notePosition,
    String noteheadGlyph,
    bool stemUp,
    double customLength,
  ) {
    final stemX = noteRenderer.positioningEngine.calculateStemX(
      noteX: notePosition.dx,
      noteheadGlyphName: noteheadGlyph,
      stemUp: stemUp,
      staffSpace: coordinates.staffSpace,
    );
    final stemStartY = noteRenderer.positioningEngine.calculateStemStartY(
      noteY: notePosition.dy,
      noteheadGlyphName: noteheadGlyph,
      stemUp: stemUp,
      staffSpace: coordinates.staffSpace,
    );
    final stemLength = customLength * coordinates.staffSpace;
    final stemEndY = stemUp ? stemStartY - stemLength : stemStartY + stemLength;

    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = stemThickness
      ..strokeCap = StrokeCap.butt;

    canvas.drawLine(
      Offset(stemX, stemStartY),
      Offset(stemX, stemEndY),
      stemPaint,
    );

    return Offset(stemX, stemEndY);
  }

  void _renderDots(
    Canvas canvas, {
    required int dots,
    required Offset noteCenter,
    required int staffPosition,
  }) {
    if (dots == 0) return;

    final dotStaffPosition = DotRenderer.resolveDotStaffPosition(staffPosition);
    final dotY = DotRenderer.calculateDotY(
      dotStaffPosition: dotStaffPosition,
      coordinates: coordinates,
    );
    final dotStartX = noteCenter.dx + (coordinates.staffSpace * 1.0);

    for (int index = 0; index < dots; index++) {
      final dotX = dotStartX + (index * coordinates.staffSpace * 0.6);
      drawGlyphWithBBox(
        canvas,
        glyphName: 'augmentationDot',
        position: Offset(dotX, dotY),
        color: theme.noteheadColor,
        options: const GlyphDrawOptions(
          centerHorizontally: true,
          trackBounds: false,
        ),
      );
    }
  }
}
