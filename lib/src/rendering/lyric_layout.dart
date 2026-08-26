// lib/src/rendering/lyric_layout.dart
//
// Where the lyric line goes.
//
// This lived as the same three-line formula copy-pasted into THREE places —
// `NoteRenderer._renderSyllables`, `StaffRenderer._renderLyricHyphens` and
// `StaffRenderer._renderMelismaLines` — which is one decision with three
// chances to drift. It is one function now, and it stopped being a constant.

import '../layout/layout_engine.dart';
import '../../core/core.dart';

/// Vertical placement of sung text under a staff.
class LyricLayout {
  /// The old, fixed answer: 1.5 staff spaces below the bottom staff line,
  /// whatever the music does.
  ///
  /// Kept as the fallback for callers that have no system to measure, and as
  /// the FLOOR for the measured answer so ordinary scores do not move.
  static double fallbackFirstLineY({
    required double staffBaselineY,
    required double staffSpace,
  }) =>
      staffBaselineY + 2 * staffSpace + staffSpace * 1.5;

  /// The first lyric line for [system], measured against what is actually in
  /// it.
  ///
  /// The fixed offset put the text 1.5 staff spaces under the bottom line and
  /// knew nothing about how far the music descended. A C4 in treble clef sits
  /// one ledger line below the staff and its notehead lands exactly there, so
  /// the first syllable of a phrase was printed THROUGH the note it belongs
  /// to — reported on the "Single Verse with Syllabification" page, where
  /// "Glo" is overlapped by its own notehead and ledger line.
  ///
  /// Lyrics sit below everything (Gould), and at ONE height across a system:
  /// text that stepped up and down with its notes would stop reading as a line
  /// of words. So this takes the lowest notehead in the system, clears its
  /// bottom edge, and never rises above the old fixed line — an ordinary score
  /// with nothing below the staff keeps the placement it had.
  static double firstLineY({
    required List<PositionedElement> elements,
    required int system,
    required double staffBaselineY,
    required double staffSpace,
  }) {
    final floor = fallbackFirstLineY(
      staffBaselineY: staffBaselineY,
      staffSpace: staffSpace,
    );

    var lowestInk = double.negativeInfinity;
    for (final positioned in elements) {
      if (positioned.system != system) continue;
      final element = positioned.element;
      if (element is! Note && element is! Chord && element is! Rest) continue;
      // Bottom edge of the notehead. `noteheadBlack` is about 1.18 staff
      // spaces wide and 0.5 tall in Bravura, so half of it plus the ledger
      // line that carries it is comfortably inside 0.6.
      final bottom = positioned.position.dy + staffSpace * 0.6;
      if (bottom > lowestInk) lowestInk = bottom;
    }
    if (lowestInk == double.negativeInfinity) return floor;

    final measured = lowestInk + staffSpace * 1.0;
    return measured > floor ? measured : floor;
  }
}
