// lib/src/layout/tuplet_grid.dart

import 'dart:math' as math;

import '../../core/core.dart';

/// Horizontal placement of the children of a [Tuplet], as offsets in pixels
/// from the tuplet's own origin.
///
/// Why this exists
/// ---------------
/// A tuplet used to be laid out on a FLAT grid of `2.5` staff spaces per child,
/// in two independent places: `LayoutEngine._registerTupletNotes` (which fed
/// the position maps, beams and hit-testing) and `TupletRenderer` (which drew).
/// Two implementations of one geometry is the shape of finding F-12, and the
/// geometry itself was wrong: measured, a quarter and an eighth inside the same
/// triplet both received exactly 30.00 px, and so did an eighth followed by two
/// sixteenths. Inside a tuplet the notes still have relative durations, and a
/// quarter-plus-eighth triplet is one of the most common figures in the
/// repertoire.
///
/// The offsets are now duration-proportional and BOTH callers read them from
/// here.
///
/// The law is deliberately FIXED to Gould's square root rather than delegating
/// to the configured `SpacingModel`. The renderer has no spacing engine, so a
/// delegating grid would compute one curve in the layout and another in the
/// renderer for any app that selected a non-default model — which is the very
/// divergence this class exists to remove. Tuplet-internal spacing is therefore
/// model-independent by construction; the tuplet's placement in the outer flow
/// still follows the configured model.
class TupletGrid {
  /// Minimum slot width, in staff spaces.
  ///
  /// Just above a black notehead (1.18 staff spaces in Bravura), so adjacent
  /// heads always clear each other. A larger floor flattens the very values the
  /// proportional grid exists to distinguish: at 2.0 an eighth and a sixteenth
  /// both bottomed out at the same width.
  static const double minimumSlotSpaces = 1.4;

  /// Slot width, in staff spaces, of a child whose duration is a quarter note.
  ///
  /// Kept equal to the historical flat grid so a triplet of equal quarters is
  /// laid out exactly as before and the corpus goldens that contain one do not
  /// move for no reason.
  static const double quarterSlotSpaces = 2.5;

  /// Offsets, in pixels from the tuplet origin, of each direct child of
  /// [tuplet] — plus a final entry holding the tuplet's total width.
  ///
  /// `offsets.length == tuplet.elements.length + 1`.
  static List<double> offsets(Tuplet tuplet, double staffSpace) {
    final result = <double>[0.0];
    var x = 0.0;
    for (final child in tuplet.elements) {
      x += slotWidth(child, staffSpace);
      result.add(x);
    }
    return result;
  }

  /// Width one child occupies inside the grid, in pixels.
  ///
  /// A nested [Tuplet] contributes its OWN content width rather than a single
  /// slot, so an inner triplet widens its parent instead of being squeezed into
  /// one position.
  static double slotWidth(MusicalElement child, double staffSpace) {
    if (child is Tuplet) {
      var total = 0.0;
      for (final inner in child.elements) {
        total += slotWidth(inner, staffSpace);
      }
      return total == 0 ? minimumSlotSpaces * staffSpace : total;
    }

    final duration = _durationOf(child);
    if (duration == null) return quarterSlotSpaces * staffSpace;

    // The tuplet's own ratio is deliberately NOT applied: the ratio scales the
    // whole group's musical value, and the group already occupies its scaled
    // width in the parent flow. What matters here is the children's duration
    // relative to EACH OTHER.
    final width = quarterSlotSpaces * _squareRootFactor(duration) * staffSpace;
    final floor = minimumSlotSpaces * staffSpace;
    return width < floor ? floor : width;
  }

  /// Total width of [tuplet] in pixels.
  static double totalWidth(Tuplet tuplet, double staffSpace) =>
      offsets(tuplet, staffSpace).last;

  static Duration? _durationOf(MusicalElement element) {
    if (element is Note) return element.duration;
    if (element is Rest) return element.duration;
    if (element is Chord) return element.duration;
    return null;
  }

  /// Gould's square-root law, normalised to the quarter note.
  ///
  /// Identical to what `SpacingModel.squareRoot` computes (`sqrt(t)` with
  /// `t = duration / quarter`), which is the package default.
  static double _squareRootFactor(Duration duration) {
    final absolute = duration.absoluteValue;
    if (absolute <= 0) return 1.0;
    return math.sqrt(absolute / DurationType.quarter.value);
  }
}
