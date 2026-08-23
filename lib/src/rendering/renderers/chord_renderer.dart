import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../accidental_resolver.dart';
import '../staff_position_calculator.dart';
import 'base_glyph_renderer.dart';
import 'note_renderer.dart';
import 'primitives/accidental_renderer.dart';
import 'primitives/dot_renderer.dart';

/// Everything about a chord's HORIZONTAL geometry, resolved once so the layout
/// engine and [ChordRenderer] cannot disagree about it.
///
/// This class exists because they did. Measured before it:
///
/// * a chord with 2, 3, 4 **or** 5 accidentals reported
///   `LayoutEngine.elementLeftExtent = 25.82 px` — one column's worth — while
///   [ChordRenderer] packed the accidentals into as many columns as they
///   needed and drew each one further left by the previous column's width, so
///   a five-accidental stack overran its reservation and collided with the
///   previous note;
/// * `C5-D5-E5` (two seconds, therefore a displaced notehead) and `C5-E5-G5`
///   (no seconds, no displacement) both reserved exactly 14.16 px and gave all
///   three notes the SAME `noteXPositions`, while the renderer offset the
///   second-cluster noteheads by a full notehead width at draw time.
///
/// Both numbers now come from [ChordRenderer.resolveGeometry], which is the
/// single implementation of the Behind Bars (Gould p.68-69 seconds, p.79-80
/// accidental columns) packing. Everything is expressed in pixels RELATIVE TO
/// THE CHORD'S ORIGIN — the X the layout gives the chord — so a caller only
/// ever adds `basePosition.dx`.
class ChordGeometry {
  /// The chord's notes sorted top -> bottom (descending staff position); every
  /// other list in this class is parallel to it.
  final List<Note> notesTopToBottom;

  /// Printed staff position of each note (0 = middle line), already including
  /// any 8va/8vb displacement.
  final List<int> staffPositions;

  /// Horizontal displacement of each notehead from the chord origin, in px:
  /// 0 for a note in the main column, `±` one notehead width for the members
  /// of a cluster of seconds.
  final List<double> clusterOffsets;

  /// Stem direction resolved for the whole chord.
  final bool stemUp;

  /// Left X of each accidental column, relative to the chord origin, indexed
  /// by column number (0 = closest to the noteheads). Empty when no accidental
  /// displays.
  final List<double> accidentalColumnLeftX;

  /// Column assigned to each accidental, keyed by the note's index in
  /// [notesTopToBottom]. Notes whose accidental is suppressed are absent.
  final Map<int, int> accidentalColumnOfNote;

  /// Total width of the accidental block, in px — every used column plus one
  /// gap each, the last of which separates column 0 from the leftmost
  /// notehead. 0 when nothing displays.
  final double accidentalBlockWidth;

  /// How far the chord reaches to the LEFT of its origin: the accidental block
  /// plus whatever a stem-down cluster pushed past the origin.
  final double leftExtent;

  /// How far the chord reaches to the RIGHT of its origin: the rightmost
  /// notehead's right edge plus its augmentation dots.
  final double rightExtent;

  const ChordGeometry({
    required this.notesTopToBottom,
    required this.staffPositions,
    required this.clusterOffsets,
    required this.stemUp,
    required this.accidentalColumnLeftX,
    required this.accidentalColumnOfNote,
    required this.accidentalBlockWidth,
    required this.leftExtent,
    required this.rightExtent,
  });

  /// Total horizontal advance of the chord, in px.
  double get width => leftExtent + rightExtent;

  /// X of [note]'s notehead relative to the chord origin, or 0.0 for a note
  /// that does not belong to this chord.
  double offsetOf(Note note) {
    for (var i = 0; i < notesTopToBottom.length; i++) {
      if (identical(notesTopToBottom[i], note)) return clusterOffsets[i];
    }
    return 0.0;
  }
}

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

    // Behind Bars: stem direction follows the note furthest from the middle
    // line — if it is below the middle (negative position) the stem points up,
    // otherwise down. This mirrors the single-note rule (staffPosition < 0) and
    // resolves the middle-line case to stem-down.
    final mostExtremePos = positions.reduce(
      (left, right) => left.abs() > right.abs() ? left : right,
    );
    return mostExtremePos < 0;
  }

  /// Horizontal gap, in staff spaces, between two accidental columns and
  /// between column 0 and the leftmost notehead.
  static const double defaultColumnGapSpaces = 0.22;

  /// Assigns chord accidentals to columns (0 = closest to the chord) by greedy
  /// top-to-bottom first-fit: each accidental is placed in the rightmost column
  /// where it clears every accidental already there by the required vertical
  /// clearance, following "Behind Bars" (Gould, p. 79-80) — the highest
  /// accidental takes column 0, and every following accidental that would
  /// collide moves one column further LEFT.
  ///
  /// [clearancesHalfSpaces] carries, per accidental, the vertical space its own
  /// glyph needs (glyph height + gap, in half staff spaces). Two accidentals
  /// sharing a column must be at least the AVERAGE of their two clearances
  /// apart: each contributes half its own height to the required centre-to-
  /// centre distance. For two equal glyphs — the overwhelmingly common case —
  /// the average is that same clearance, so uniform chords are unaffected;
  /// mixed heights (a double-flat above a sharp) are no longer judged by the
  /// second glyph's clearance alone.
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
      var column = 0;
      while (true) {
        final ms = members[column];
        var collides = false;
        if (ms != null) {
          for (final k in ms) {
            final required =
                (clearancesHalfSpaces[i] + clearancesHalfSpaces[k]) * 0.5;
            if ((staffPositionsTopToBottom[i] - staffPositionsTopToBottom[k])
                    .abs() <
                required) {
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

  /// Total horizontal space, in staff spaces, reserved by a chord's accidental
  /// block: every used column's width plus one [columnGapSpaces] gap per column
  /// (the last of which separates column 0 from the leftmost notehead).
  ///
  /// [columnWidthsSpaces] is indexed by column number, so its length is exactly
  /// the number of columns actually used — the reserved width therefore grows
  /// only with the columns the packing produced.
  static double accidentalBlockWidthSpaces(
    List<double> columnWidthsSpaces, {
    double columnGapSpaces = defaultColumnGapSpaces,
  }) {
    var total = 0.0;
    for (final width in columnWidthsSpaces) {
      total += width + columnGapSpaces;
    }
    return total;
  }

  /// Effective accidental glyph of [note] after within-measure resolution:
  /// null = suppress, the natural glyph on a revert, else the note's own.
  ///
  /// F-02: chord accidentals are chosen HERE and nowhere else, so the layout's
  /// reservation and the drawing always agree about which glyphs exist.
  static String? effectiveAccidentalGlyph(
    Note note,
    Map<Note, AccidentalDisplay>? decisions,
  ) {
    switch (decisions?[note] ?? AccidentalDisplay.show) {
      case AccidentalDisplay.hide:
        return null;
      case AccidentalDisplay.natural:
        return 'accidentalNatural';
      case AccidentalDisplay.show:
        return note.pitch.accidentalGlyph;
    }
  }

  /// Width of one accidental column entry, in staff spaces, INCLUDING any
  /// cautionary parentheses or editorial brackets around it (F-16).
  ///
  /// Same rule as `AccidentalRenderer.decoratedWidthSpaces`, expressed as a
  /// pure function of the metadata so the layout engine — which has no
  /// renderer instance and no canvas — can ask for the identical number.
  /// Everything it is built from — the enclosing glyph names, the gap AND the
  /// single-glyph width lookup — comes from [AccidentalRenderer], so this is
  /// only the arithmetic that combines them.
  ///
  /// The glyph width used to be a private `widthOf` closure restating
  /// [AccidentalRenderer.glyphWidthSpacesFor] line for line — the second copy
  /// wave 2 extracted the shared helper to remove, left behind. Verified
  /// before collapsing (`probe/W4G_widthof_test.dart`): over all 235
  /// `accidental*` glyph names in `assets/smufl/glyphnames.json` plus
  /// `noteheadBlack`, `gClef`, `restQuarter`, an unknown name and the empty
  /// string — 240 glyphs bare, and the same 240 times the 3
  /// [AccidentalParenthesis] values decorated, 960 comparisons — the closure
  /// and the shared helper returned bit-identical doubles in 960/960 cases,
  /// 0 disagreements. No pixel can move.
  static double decoratedAccidentalWidthSpaces(
    SmuflMetadata metadata,
    String glyphName,
    AccidentalParenthesis paren,
  ) {
    double widthOf(String glyph) =>
        AccidentalRenderer.glyphWidthSpacesFor(metadata, glyph);

    final left = AccidentalRenderer.leftSignGlyph(paren);
    final right = AccidentalRenderer.rightSignGlyph(paren);
    if (left == null || right == null) return widthOf(glyphName);
    return widthOf(left) +
        widthOf(glyphName) +
        widthOf(right) +
        (2 * AccidentalRenderer.parenthesisGapSpaces);
  }

  /// Vertical clearance, in staff positions (= half spaces), that two
  /// accidentals sharing a column need between their centres: the glyph's own
  /// height plus a small gap.
  static double accidentalClearanceHalfSpaces(
    SmuflMetadata metadata,
    String glyph,
  ) {
    final box = metadata.getGlyphInfo(glyph)?.boundingBox;
    final heightSpaces = box?.height ?? 2.7;
    return (heightSpaces * 2.0) + 0.5;
  }

  /// Notehead width, in staff spaces, of the glyph a chord of this duration
  /// draws. Bravura's `noteheadBlack` is 1.18.
  static double noteheadWidthSpaces(
    SmuflMetadata metadata,
    DurationType durationType,
  ) =>
      metadata.getGlyphInfo(durationType.glyphName)?.boundingBox?.width ?? 1.18;

  /// Extra width, in px, that [dots] augmentation dots add to the right of a
  /// notehead.
  ///
  /// `DotRenderer` puts the first dot at the notehead CENTRE + 1.0 staff space
  /// and each further dot 0.6 further right, so the block ends about 0.7 staff
  /// spaces past the notehead's right edge.
  static double dotExtentPx(int dots, double staffSpace) =>
      dots <= 0 ? 0.0 : (0.7 + (dots - 1) * 0.6) * staffSpace;

  /// Resolves the one horizontal geometry both the layout engine and [render]
  /// use. See [ChordGeometry] for what each field means and for the
  /// measurements that motivated extracting it.
  ///
  /// [extraOctaveShift] is the 8va/8vb displacement in force (ADR-003: it
  /// changes only WHERE the chord is printed), and it matters here because the
  /// staff positions drive the stem-direction vote, the cluster detection and
  /// the accidental column packing alike.
  static ChordGeometry resolveGeometry({
    required Chord chord,
    required Clef clef,
    required SmuflMetadata metadata,
    required double staffSpace,
    int extraOctaveShift = 0,
    int? voiceNumber,
    Map<Note, AccidentalDisplay>? accidentalDecisions,
  }) {
    int posOf(Note n) => StaffPositionCalculator.calculate(
          n.pitch,
          clef,
          extraOctaveShift: extraOctaveShift,
        );

    final sortedNotes = [...chord.notes]
      ..sort((a, b) => posOf(b).compareTo(posOf(a)));
    final positions = sortedNotes.map(posOf).toList();
    final dots = dotExtentPx(chord.duration.dots, staffSpace);

    if (sortedNotes.isEmpty) {
      return ChordGeometry(
        notesTopToBottom: const <Note>[],
        staffPositions: const <int>[],
        clusterOffsets: const <double>[],
        stemUp: true,
        accidentalColumnLeftX: const <double>[],
        accidentalColumnOfNote: const <int, int>{},
        accidentalBlockWidth: 0.0,
        leftExtent: 0.0,
        rightExtent: dots,
      );
    }

    final stemUp = resolveStemDirection(
      chord: chord,
      positions: positions,
      voiceNumber: voiceNumber,
    );

    final noteheadWidthPx =
        noteheadWidthSpaces(metadata, chord.duration.type) * staffSpace;
    final clusterOffsets = calculateClusterOffsets(
      positions: positions,
      stemUp: stemUp,
      clusterOffset: noteheadWidthPx * 1.04,
    );

    // Accidentals that actually display, top -> bottom.
    final accIdx = <int>[
      for (var i = 0; i < sortedNotes.length; i++)
        if (effectiveAccidentalGlyph(sortedNotes[i], accidentalDecisions) !=
            null)
          i,
    ];
    final assignedColumns = assignAccidentalColumns(
      [for (final i in accIdx) positions[i]],
      [
        for (final i in accIdx)
          accidentalClearanceHalfSpaces(
            metadata,
            effectiveAccidentalGlyph(sortedNotes[i], accidentalDecisions)!,
          ),
      ],
    );

    final columnOfNote = <int, int>{};
    final columnWidthSpaces = <int, double>{};
    for (var n = 0; n < accIdx.length; n++) {
      final i = accIdx[n];
      final column = assignedColumns[n];
      columnOfNote[i] = column;
      columnWidthSpaces[column] = math.max(
        columnWidthSpaces[column] ?? 0.0,
        decoratedAccidentalWidthSpaces(
          metadata,
          effectiveAccidentalGlyph(sortedNotes[i], accidentalDecisions)!,
          sortedNotes[i].accidentalParenthesis,
        ),
      );
    }

    final minOffset = clusterOffsets.reduce(math.min);
    final maxOffset = clusterOffsets.reduce(math.max);

    var blockWidth = 0.0;
    final columnLeftX = <double>[];
    if (columnOfNote.isNotEmpty) {
      final maxColumn = columnOfNote.values.reduce(math.max);
      // Greedy first-fit never skips a column, so 0..maxColumn are all in use
      // and this list's length IS the number of columns used.
      final columnWidths = <double>[
        for (var c = 0; c <= maxColumn; c++) (columnWidthSpaces[c] ?? 1.0),
      ];
      blockWidth = accidentalBlockWidthSpaces(columnWidths) * staffSpace;

      // Column 0 sits one gap to the LEFT of the leftmost notehead edge (which
      // may itself be cluster-shifted); each further column is offset left by
      // the previous column's own width plus a gap.
      const gapSpaces = defaultColumnGapSpaces;
      var cursorRightEdge = minOffset - gapSpaces * staffSpace;
      for (var c = 0; c <= maxColumn; c++) {
        final widthPx = columnWidths[c] * staffSpace;
        columnLeftX.add(cursorRightEdge - widthPx);
        cursorRightEdge = columnLeftX[c] - gapSpaces * staffSpace;
      }
    }

    return ChordGeometry(
      notesTopToBottom: sortedNotes,
      staffPositions: positions,
      clusterOffsets: clusterOffsets,
      stemUp: stemUp,
      accidentalColumnLeftX: columnLeftX,
      accidentalColumnOfNote: columnOfNote,
      accidentalBlockWidth: blockWidth,
      // A stem-down cluster pushes a notehead LEFT of the origin, so the space
      // the chord needs on its left is the accidental block plus that
      // displacement. `minOffset` is <= 0 by construction.
      leftExtent: blockWidth - minOffset,
      rightExtent: maxOffset + noteheadWidthPx + dots,
    );
  }

  /// [suppressStem] and [suppressFlag] exist so a chord can PARTICIPATE IN A
  /// BEAM drawn by someone else, which it could not do before.
  ///
  /// `TupletBeamPlan._carriesBeam` (`tuplet_grid.dart:339`) still refuses to
  /// auto-beam a bare [Chord], and its own dartdoc says why: "`ChordRenderer`
  /// draws a flag whenever [Chord.beam] is null and the duration is shorter
  /// than a quarter - so auto-beaming a bare chord here would print a beam AND
  /// a flag on the same stem". That was true: this method had no way to be told
  /// not to. It now does.
  ///
  /// * [suppressFlag] drops the flag but keeps the chord's own stem - for a
  ///   caller that draws the beam but not the stems.
  /// * [suppressStem] drops BOTH (a stem with no flag would be the wrong
  ///   length: the beam decides where the stem ends, and only the caller knows
  ///   the beam line). Pair it with [chordStemAnchor], which hands the caller
  ///   the exact point the stem must start from.
  /// * [stemEndY], when given, draws the stem from that same anchor to exactly
  ///   this Y - the beam line - instead of to a computed length, and implies
  ///   [suppressFlag]. It is the one-call form for a caller that already knows
  ///   the beam geometry before the chord is drawn.
  ///
  /// None of the three touches [resolveGeometry], so the noteheads, the cluster
  /// displacement and the accidental columns are bit-identical to an ordinary
  /// render and still match what the LAYOUT reserved. A chord drawn with the
  /// default arguments produces exactly the pixels it produced before.
  void render(
    Canvas canvas,
    Chord chord,
    Offset basePosition,
    Clef currentClef, {
    int? voiceNumber,
    Map<Note, AccidentalDisplay>? accidentalDecisions,
    int extraOctaveShift = 0,
    bool suppressFlag = false,
    bool suppressStem = false,
    double? stemEndY,
  }) {
    // Everything horizontal — staff positions (8va-displaced, ADR-003), stem
    // direction, seconds/cluster offsets and the Behind Bars accidental column
    // packing — comes from [resolveGeometry], which is the SAME call the layout
    // engine makes to reserve space. Recomputing any of it here is what let the
    // drawing outgrow its reservation (M-16/M-17).
    final geometry = resolveGeometry(
      chord: chord,
      clef: currentClef,
      metadata: metadata,
      staffSpace: coordinates.staffSpace,
      extraOctaveShift: extraOctaveShift,
      voiceNumber: voiceNumber,
      accidentalDecisions: accidentalDecisions,
    );

    final sortedNotes = geometry.notesTopToBottom;
    final positions = geometry.staffPositions;
    final stemUp = geometry.stemUp;
    final clusterOffsets = geometry.clusterOffsets;

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
    final noteCenters = <Offset>[];

    final accidentalRenderer = noteRenderer.accidentalRenderer;
    final accidentalColumns = geometry.accidentalColumnOfNote;

    if (accidentalColumns.isNotEmpty) {
      // F-31: the space actually consumed by the block must equal the width
      // reserved for the columns that were used — no more, no less.
      assert(
        (geometry.accidentalColumnLeftX.last -
                (clusterOffsets.reduce(math.min) -
                    geometry.accidentalBlockWidth))
            .abs() <
            1e-3,
        'chord accidental block width does not match the columns in use',
      );

      for (final entry in accidentalColumns.entries) {
        final i = entry.key;
        final accidentalGlyph =
            effectiveAccidentalGlyph(sortedNotes[i], accidentalDecisions)!;
        final noteY = StaffPositionCalculator.toPixelY(
          positions[i],
          coordinates.staffSpace,
          coordinates.staffBaseline.dy,
        );
        // Draw through AccidentalRenderer so chord accidentals get the same
        // cautionary/editorial enclosure as single notes (F-16).
        accidentalRenderer.drawDecoratedAccidental(
          canvas,
          glyphName: accidentalGlyph,
          leftX: basePosition.dx +
              geometry.accidentalColumnLeftX[entry.value],
          y: noteY,
          color: theme.accidentalColor ?? theme.noteheadColor,
          paren: sortedNotes[i].accidentalParenthesis,
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

    if (chord.duration.type != DurationType.whole &&
        positions.isNotEmpty &&
        !suppressStem) {
      final stemNoteIndex = stemUp ? positions.length - 1 : 0;
      final stemY = StaffPositionCalculator.toPixelY(
        positions[stemNoteIndex],
        coordinates.staffSpace,
        coordinates.staffBaseline.dy,
      );
      final stemNotePosition = Offset(
        basePosition.dx + clusterOffsets[stemNoteIndex],
        stemY,
      );

      final Offset stemEnd;
      if (stemEndY != null) {
        // The caller owns the beam line, so the stem length is whatever reaches
        // it. Routed through the same [_renderChordStem] so the stem X, the
        // notehead attachment anchor and the paint are identical to the normal
        // path; only the length differs.
        final anchorY = noteRenderer.positioningEngine.calculateStemStartY(
          noteY: stemNotePosition.dy,
          noteheadGlyphName: noteheadGlyph,
          stemUp: stemUp,
          staffSpace: coordinates.staffSpace,
        );
        stemEnd = _renderChordStem(
          canvas,
          stemNotePosition,
          noteheadGlyph,
          stemUp,
          (stemUp ? anchorY - stemEndY : stemEndY - anchorY) /
              coordinates.staffSpace,
        );
      } else {
        final beamCount = _getBeamCount(chord.duration.type);
        final customStemLength = noteRenderer.positioningEngine
            .calculateChordStemLength(
              noteStaffPositions: positions,
              stemUp: stemUp,
              beamCount: beamCount,
            );

        stemEnd = _renderChordStem(
          canvas,
          stemNotePosition,
          noteheadGlyph,
          stemUp,
          customStemLength,
        );
      }

      if (chord.duration.type.value < 0.25 &&
          chord.beam == null &&
          !suppressFlag &&
          stemEndY == null) {
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

    // Chord-level articulations (Behind Bars): a single staccato/accent/tenuto/
    // marcato attaches to the outermost notehead on the side opposite the stem.
    if (chord.articulations.isNotEmpty) {
      final lowestNoteY = noteCenters
          .map((c) => c.dy)
          .reduce((a, b) => a > b ? a : b);
      final highestNoteY = noteCenters
          .map((c) => c.dy)
          .reduce((a, b) => a < b ? a : b);
      noteRenderer.articulationRenderer.render(
        canvas,
        chord.articulations,
        Offset(chordCenter.dx, stemUp ? lowestNoteY : highestNoteY),
        stemUp: stemUp,
      );
    }

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

    // Ledger lines use SMuFL legerLineThickness (0.16 SS), heavier than the
    // staff lines, with legerLineExtension (0.4 SS) — both read from metadata.
    final paint = Paint()
      ..color = theme.staffLineColor
      ..strokeWidth =
          metadata.getEngravingDefault('legerLineThickness', 0.16) *
          coordinates.staffSpace;
    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;
    final noteWidthPixels =
        bbox?.widthInPixels(coordinates.staffSpace) ??
        (coordinates.staffSpace * 1.18);
    final extension =
        metadata.getEngravingDefault('legerLineExtension', 0.4) *
        coordinates.staffSpace;
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

  /// Everything a caller drawing a BEAM needs about this chord's stem.
  ///
  /// * `x` - the stem's X.
  /// * `nearY` - where the stem starts: on the notehead the stem ATTACHES to,
  ///   which is the BOTTOM notehead when [stemUp] and the TOP one when not
  ///   (SMuFL `stemUpSE` / `stemDownNW`).
  /// * `farY` - the notehead at the OTHER extreme, the one the beam has to
  ///   clear. For a single note the two coincide; for a chord they are the
  ///   whole span apart, and confusing them is how a beam ends up drawn THROUGH
  ///   a chord: measured on a stem-down `C4-E4-G4` eighth triplet at
  ///   `staffSpace = 24`, `nearY` (G4) is 312.0 and `farY` (C4) is 360.0, and a
  ///   beam placed from `nearY` landed at y = 348 - twelve pixels ABOVE the C4
  ///   notehead it was supposed to hang below, straight through the E4.
  ///
  /// The other half of the beamed-chord API (see [render]'s [suppressStem]).
  /// A caller that draws the beam needs this BEFORE it can place the beam line,
  /// and it cannot reconstruct it from the chord's origin: the stem hangs off
  /// the top notehead for a stem-up chord and the bottom one for stem-down,
  /// either of which may be cluster-displaced by a full notehead width (Gould
  /// p.68-69), and the attachment point itself is the font's `stemUpSE` /
  /// `stemDownNW` anchor, not the notehead's bounding-box corner. Measured on
  /// `C4-E4-G4` at `staffSpace = 12` with `basePosition.dx = 100`: this returns
  /// x = 114.16, while the chord-origin x that `TupletRenderer`'s beam pass fed
  /// to `calculateStemX` for its own stems is 100.00 - 14.16 px of error, more
  /// than a whole notehead.
  ///
  /// [stemUp] is the CALLER's decision, not the chord's own: every stem in a
  /// beamed group points the same way, and that direction belongs to the group.
  /// It is deliberately NOT fed back into [resolveGeometry] - the layout
  /// reserved this chord's width from the chord's own stem vote, and overriding
  /// the vote here would make the drawing outgrow its reservation, which is the
  /// exact defect (M-16/M-17) [ChordGeometry] exists to prevent. The residual
  /// is narrow and cosmetic: a chord that contains a SECOND and whose group
  /// direction disagrees with its own vote keeps its cluster displacement
  /// mirrored. Nothing overlaps, and the stem still starts on the correct
  /// extreme notehead.
  ///
  /// Returns null for a chord with no notes.
  ({double x, double nearY, double farY})? chordStemAnchor({
    required Chord chord,
    required Offset basePosition,
    required Clef currentClef,
    required bool stemUp,
    int? voiceNumber,
    Map<Note, AccidentalDisplay>? accidentalDecisions,
    int extraOctaveShift = 0,
  }) {
    final geometry = resolveGeometry(
      chord: chord,
      clef: currentClef,
      metadata: metadata,
      staffSpace: coordinates.staffSpace,
      extraOctaveShift: extraOctaveShift,
      voiceNumber: voiceNumber,
      accidentalDecisions: accidentalDecisions,
    );
    final positions = geometry.staffPositions;
    if (positions.isEmpty) return null;

    // `positions` is sorted top -> bottom, so index 0 is the highest notehead
    // and the last index the lowest.
    final nearIndex = stemUp ? positions.length - 1 : 0;
    final farIndex = stemUp ? 0 : positions.length - 1;
    final glyph = chord.duration.type.glyphName;
    double pixelYOf(int index) => StaffPositionCalculator.toPixelY(
          positions[index],
          coordinates.staffSpace,
          coordinates.staffBaseline.dy,
        );
    return (
      x: noteRenderer.positioningEngine.calculateStemX(
        noteX: basePosition.dx + geometry.clusterOffsets[nearIndex],
        noteheadGlyphName: glyph,
        stemUp: stemUp,
        staffSpace: coordinates.staffSpace,
      ),
      nearY: noteRenderer.positioningEngine.calculateStemStartY(
        noteY: pixelYOf(nearIndex),
        noteheadGlyphName: glyph,
        stemUp: stemUp,
        staffSpace: coordinates.staffSpace,
      ),
      farY: pixelYOf(farIndex),
    );
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
