import 'dart:math' as math;

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

  /// Selects which note in a chord carries the lyric line (issue #12).
  ///
  /// A chord shows a single lyric line, so the first note that has non-empty
  /// syllables wins; returns null when no note in the chord has lyrics.
  static Note? lyricNoteFor(Chord chord) {
    for (final note in chord.notes) {
      if (note.syllables != null && note.syllables!.isNotEmpty) {
        return note;
      }
    }
    return null;
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

  /// Assigns chord accidentals to columns (0 = closest to the chord) by greedy
  /// top-to-bottom first-fit: each accidental is placed in the rightmost column
  /// where it clears every accidental already there by the corresponding entry
  /// in [clearancesHalfSpaces] (the glyph height + gap, in half staff spaces).
  ///
  /// [staffPositionsTopToBottom] and [clearancesHalfSpaces] are parallel and
  /// must be ordered top -> bottom (descending staff position). Returns the
  /// column index per input accidental. Pure/static so it can be unit-tested.
  static List<int> assignAccidentalColumns(
    List<int> staffPositionsTopToBottom,
    List<double> clearancesHalfSpaces,
  ) {
    final columns = List<int>.filled(staffPositionsTopToBottom.length, 0);
    final members = <int, List<int>>{};
    for (var i = 0; i < staffPositionsTopToBottom.length; i++) {
      final clearance = clearancesHalfSpaces[i];
      var column = 0;
      while (true) {
        final ms = members[column];
        var collides = false;
        if (ms != null) {
          for (final k in ms) {
            if ((staffPositionsTopToBottom[i] - staffPositionsTopToBottom[k])
                    .abs() <
                clearance) {
              collides = true;
              break;
            }
          }
        }
        if (!collides) break;
        column++;
      }
      columns[i] = column;
      (members[column] ??= <int>[]).add(i);
    }
    return columns;
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

    // ── Accidental column packing (Behind Bars / Gould) ──
    // sortedNotes is already top -> bottom. Each accidental is placed in the
    // rightmost column (0 = closest to the chord) where it does NOT vertically
    // overlap an accidental already in that column. Both the vertical clearance
    // and the column width come from each glyph's real SMuFL bounding box, so
    // accidentals neither overlap vertically nor horizontally (the previous
    // version used a fixed 6-half-space threshold and the advance width — which
    // is narrower than the glyph — so columns collided).
    double accWidthSpaces(String glyph) {
      final box = metadata.getGlyphInfo(glyph)?.boundingBox;
      final w = box?.width ?? metadata.getGlyphWidth(glyph);
      return w > 0 ? w : 1.0;
    }

    // Vertical clearance (in staff positions = half-spaces) needed between two
    // accidentals sharing a column: the glyph height + a small gap.
    double accClearanceHalfSpaces(String glyph) {
      final box = metadata.getGlyphInfo(glyph)?.boundingBox;
      final heightSpaces = box?.height ?? 2.7;
      return (heightSpaces * 2.0) + 0.5;
    }

    // Notes carrying an accidental, already ordered top -> bottom.
    final accIdx = <int>[
      for (int i = 0; i < sortedNotes.length; i++)
        if (sortedNotes[i].pitch.accidentalGlyph != null) i,
    ];
    final assignedColumns = assignAccidentalColumns(
      [for (final i in accIdx) positions[i]],
      [
        for (final i in accIdx)
          accClearanceHalfSpaces(sortedNotes[i].pitch.accidentalGlyph!),
      ],
    );

    final accidentalColumns = <int, int>{}; // note index -> column
    final columnMembers = <int, List<int>>{}; // column -> note indices
    final columnWidthSpaces = <int, double>{}; // column -> max glyph width (SS)

    for (int n = 0; n < accIdx.length; n++) {
      final i = accIdx[n];
      final column = assignedColumns[n];
      accidentalColumns[i] = column;
      (columnMembers[column] ??= <int>[]).add(i);
      columnWidthSpaces[column] = math.max(
        columnWidthSpaces[column] ?? 0.0,
        accWidthSpaces(sortedNotes[i].pitch.accidentalGlyph!),
      );
    }

    // Resolve each column's left X. Column 0 sits a small gap to the LEFT of the
    // leftmost notehead edge (accounts for left-shifted second-cluster notes);
    // each further column is offset left by the previous column's glyph width.
    if (accidentalColumns.isNotEmpty) {
      const columnGapSpaces = 0.22;
      final leftmostNoteDx =
          basePosition.dx + clusterOffsets.reduce(math.min);
      final maxColumn = columnMembers.keys.reduce(math.max);
      final columnLeftX = <int, double>{};
      var cursorRightEdge =
          leftmostNoteDx - columnGapSpaces * coordinates.staffSpace;
      for (int c = 0; c <= maxColumn; c++) {
        final widthPx = (columnWidthSpaces[c] ?? 1.0) * coordinates.staffSpace;
        columnLeftX[c] = cursorRightEdge - widthPx;
        cursorRightEdge =
            columnLeftX[c]! - columnGapSpaces * coordinates.staffSpace;
      }

      for (final entry in accidentalColumns.entries) {
        final i = entry.key;
        final accidentalGlyph = sortedNotes[i].pitch.accidentalGlyph!;
        final noteY = StaffPositionCalculator.toPixelY(
          positions[i],
          coordinates.staffSpace,
          coordinates.staffBaseline.dy,
        );
        drawGlyphWithBBox(
          canvas,
          glyphName: accidentalGlyph,
          position: Offset(columnLeftX[entry.value]!, noteY),
          color: theme.accidentalColor ?? theme.noteheadColor,
          options: const GlyphDrawOptions(trackBounds: true),
        );
      }
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

    // Lyric syllables for the chord (issue #12), centered under the chord and
    // reusing NoteRenderer's syllable typography.
    final lyricNote = lyricNoteFor(chord);
    if (lyricNote != null) {
      noteRenderer.renderSyllables(
        canvas,
        lyricNote.syllables!,
        chordCenter.dx,
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
