// Hit-testing and selection over a laid-out score.
//
// This is the first piece of editor infrastructure the engine can honestly
// offer. It only became possible once the layout stopped REPLACING the caller's
// `Note` objects with clones: hit-testing is worthless if the element you get
// back is not the element you hold in your model, because you cannot then edit,
// highlight or delete it.
//
// Everything here is derived from `PositionedElement`, which now carries the
// element itself, its absolute position, its system, its measure index, its
// voice and its musical onset — i.e. all four axes a score editor selects on:
// by point, by region, by structural unit (measure / system / voice) and by
// time (for playing just a selection).

import 'package:flutter/material.dart' show Offset, Rect;

import '../../core/core.dart';
import '../layout/layout_engine.dart';

/// One element found under a point or inside a region.
class ScoreHit {
  /// The element from the caller's own model (identity preserved).
  final MusicalElement element;

  /// Top-left anchor the layout gave this element.
  final Offset position;

  /// Box used for the test, in the same coordinate space as [position].
  final Rect bounds;

  /// System (wrapped line) the element belongs to.
  final int system;

  /// Measure index within the staff, or -1 when unknown.
  final int measureIndex;

  /// Voice number in polyphonic contexts, or null.
  final int? voiceNumber;

  /// Musical onset in whole notes from the start of the staff.
  final double onset;

  /// Distance from the tested point to [bounds] (0 when inside).
  final double distance;

  const ScoreHit({
    required this.element,
    required this.position,
    required this.bounds,
    required this.system,
    required this.measureIndex,
    required this.voiceNumber,
    required this.onset,
    required this.distance,
  });

  @override
  String toString() => 'ScoreHit(${element.runtimeType} '
      'bar $measureIndex, onset $onset, d=${distance.toStringAsFixed(1)})';
}

/// A contiguous musical span, e.g. what a click-drag selected.
///
/// Feed [startOnset]/[endOnset] to the MIDI mapper to play only the selection.
class ScoreSelection {
  final List<ScoreHit> hits;
  final double startOnset;
  final double endOnset;
  final int firstMeasure;
  final int lastMeasure;

  const ScoreSelection({
    required this.hits,
    required this.startOnset,
    required this.endOnset,
    required this.firstMeasure,
    required this.lastMeasure,
  });

  bool get isEmpty => hits.isEmpty;

  /// Elements of the selection that carry sound.
  Iterable<MusicalElement> get soundingElements => hits
      .map((h) => h.element)
      .where((e) => e is Note || e is Chord || e is Tuplet);
}

/// Point / region / structural selection over a laid-out staff.
///
/// ```dart
/// final engine = LayoutEngine(staff, availableWidth: w, metadata: meta);
/// final elements = engine.layout();
/// final tester = ScoreHitTester(
///   elements: elements, staffSpace: 12, engine: engine);
///
/// final hit = tester.hitTest(localPosition);
/// if (hit != null) highlight(hit.element);
/// ```
class ScoreHitTester {
  /// The laid-out elements to test against.
  final List<PositionedElement> elements;

  /// Staff space used for the layout (drives the default box heights).
  final double staffSpace;

  /// Optional engine, used for exact element widths. Without it, widths fall
  /// back to a notehead-sized box, which is enough for coarse picking but will
  /// not match wide glyphs such as clefs or whole rests.
  final LayoutEngine? engine;

  ScoreHitTester({
    required this.elements,
    required this.staffSpace,
    this.engine,
  });

  /// Standard stem length, in staff spaces (Behind Bars p.13).
  static const double _stemLengthSpaces = 3.5;

  /// Extra reach of a flag past the end of the stem, in staff spaces.
  static const double _flagReachSpaces = 0.6;

  /// Half-height of a notehead, in staff spaces.
  static const double _noteheadHalfSpaces = 0.7;

  /// Box a given element occupies, derived from what is actually DRAWN.
  ///
  /// The box used to be an independent estimate and it was wrong in three ways
  /// a user could feel:
  ///
  /// * it was `elementWidth` wide starting at `x`, but `elementWidth` INCLUDES
  ///   the accidental, which is drawn to the LEFT of the notehead — so the box
  ///   was about an accidental too wide on the right and an accidental short on
  ///   the left, and clicking an accidental selected nothing;
  /// * it was one notehead tall, so the STEM and the flag were outside it;
  /// * for a [Chord] it was centred on `position.dy`, which for a chord is the
  ///   STAFF BASELINE and not the noteheads. A C6-E6-G6 chord got a box drawn
  ///   around the staff while its noteheads sat far above: clicking exactly on
  ///   a notehead returned null.
  ///
  /// Everything below now comes from the same numbers the renderers use —
  /// `LayoutEngine.noteYPositions` for where a notehead really is,
  /// `noteStaffPositions` for stem direction, and the engine's own left/right
  /// extents for the horizontal span.
  Rect boundsOf(PositionedElement positioned) {
    final element = positioned.element;
    final x = positioned.position.dx;
    final air = staffSpace * 0.2;

    if (element is Note) {
      final span = _horizontalSpan(element, x);
      final y = engine?.noteYPositions[element] ?? positioned.position.dy;
      final vertical = _verticalSpan(
        highestNoteY: y,
        lowestNoteY: y,
        stemUp: _stemPointsUp([element]),
        duration: element.duration.type,
        hasBeamOrFlag: element.duration.type.value <= 0.125,
      );
      return Rect.fromLTRB(span.left, vertical.top, span.right, vertical.bottom);
    }

    if (element is Chord) {
      final span = _horizontalSpan(element, x);
      var highest = double.infinity;
      var lowest = double.negativeInfinity;
      for (final note in element.notes) {
        final y = engine?.noteYPositions[note];
        if (y == null) continue;
        if (y < highest) highest = y;
        if (y > lowest) lowest = y;
      }
      if (!highest.isFinite || !lowest.isFinite) {
        // No geometry registered (a chord laid out with no clef in force):
        // fall back to the staff, which is the only thing we know.
        highest = positioned.staffBaselineY - staffSpace * 2;
        lowest = positioned.staffBaselineY + staffSpace * 2;
      }
      final vertical = _verticalSpan(
        highestNoteY: highest,
        lowestNoteY: lowest,
        stemUp: _stemPointsUp(element.notes),
        duration: element.duration.type,
        hasBeamOrFlag: element.duration.type.value <= 0.125,
      );
      return Rect.fromLTRB(span.left, vertical.top, span.right, vertical.bottom);
    }

    final width = engine?.elementWidth(element) ?? staffSpace * 1.2;
    if (element is Rest) {
      return Rect.fromLTWH(
        x - air,
        positioned.position.dy - staffSpace * 2,
        width + air * 2,
        staffSpace * 4,
      );
    }

    // Clefs, key/time signatures, barlines, brackets: full staff height plus a
    // little air above and below, measured from the staff this element sits on.
    return Rect.fromLTWH(
      x - air,
      positioned.position.dy - staffSpace * 3,
      width + air * 2,
      staffSpace * 6,
    );
  }

  /// Horizontal reach of a note or chord: the accidental hangs to the LEFT of
  /// the origin, the notehead and its dots to the right.
  ({double left, double right}) _horizontalSpan(
    MusicalElement element,
    double x,
  ) {
    final air = staffSpace * 0.2;
    final total = engine?.elementWidth(element) ?? staffSpace * 1.2;
    final left = engine?.elementLeftExtent(element) ?? 0.0;
    return (left: x - left - air, right: x + (total - left) + air);
  }

  /// Stem direction under Behind Bars' rule: the note furthest from the middle
  /// line decides, and the middle line itself takes a downward stem.
  bool _stemPointsUp(List<Note> notes) {
    final positions = engine?.noteStaffPositions;
    if (positions == null) return true;
    var furthest = 0;
    var seen = false;
    for (final note in notes) {
      final p = positions[note];
      if (p == null) continue;
      if (!seen || p.abs() > furthest.abs()) {
        furthest = p;
        seen = true;
      }
    }
    return seen ? furthest < 0 : true;
  }

  ({double top, double bottom}) _verticalSpan({
    required double highestNoteY,
    required double lowestNoteY,
    required bool stemUp,
    required DurationType duration,
    required bool hasBeamOrFlag,
  }) {
    var top = highestNoteY - staffSpace * _noteheadHalfSpaces;
    var bottom = lowestNoteY + staffSpace * _noteheadHalfSpaces;

    // A whole note or breve carries no stem.
    if (duration.value >= 1.0) return (top: top, bottom: bottom);

    final reach =
        staffSpace * (_stemLengthSpaces + (hasBeamOrFlag ? _flagReachSpaces : 0));
    if (stemUp) {
      top = highestNoteY - reach;
    } else {
      bottom = lowestNoteY + reach;
    }
    return (top: top, bottom: bottom);
  }

  /// Nearest element to [point], or null when nothing is within [tolerance]
  /// (in pixels) of it.
  ///
  /// Notes and chords win ties against staff furniture at the same distance,
  /// which is what a user pointing at a chord expects.
  ScoreHit? hitTest(Offset point, {double tolerance = 0.0}) {
    ScoreHit? best;
    for (final positioned in elements) {
      final rect = boundsOf(positioned);
      final d = _distanceTo(rect, point);
      if (d > tolerance) continue;
      final hit = _hitFrom(positioned, rect, d);
      if (best == null ||
          d < best.distance ||
          (d == best.distance && _rank(hit) > _rank(best))) {
        best = hit;
      }
    }
    return best;
  }

  /// Every element whose box intersects [rect] — a marquee selection.
  List<ScoreHit> elementsInRect(Rect rect) {
    final result = <ScoreHit>[];
    for (final positioned in elements) {
      final bounds = boundsOf(positioned);
      if (bounds.overlaps(rect)) {
        result.add(_hitFrom(positioned, bounds, 0));
      }
    }
    return result;
  }

  /// Everything in one measure.
  List<ScoreHit> selectMeasure(int measureIndex) => _select(
      (p) => p.measureIndex == measureIndex);

  /// Everything on one wrapped system.
  List<ScoreHit> selectSystem(int system) => _select((p) => p.system == system);

  /// Everything belonging to one voice (null-voiced elements count as voice 1).
  List<ScoreHit> selectVoice(int voiceNumber) =>
      _select((p) => (p.voiceNumber ?? 1) == voiceNumber);

  /// Everything sounding in `[startOnset, endOnset)`, in whole notes.
  List<ScoreHit> selectTimeRange(double startOnset, double endOnset) =>
      _select((p) => p.onset >= startOnset - 1e-9 && p.onset < endOnset - 1e-9);

  /// Musical position under [point]: which bar, and how far into the piece.
  ///
  /// Returns null when the point is nowhere near the music. Use it to place a
  /// caret, or to start playback from where the user clicked.
  ({int measureIndex, double onset})? timeAt(Offset point) {
    final hit = hitTest(point, tolerance: staffSpace * 4);
    if (hit == null) return null;
    return (measureIndex: hit.measureIndex, onset: hit.onset);
  }

  /// Builds a [ScoreSelection] from a drag rectangle, ready to be highlighted
  /// or played back on its own.
  ScoreSelection selectionFromRect(Rect rect) {
    final hits = elementsInRect(rect);
    if (hits.isEmpty) {
      return const ScoreSelection(
        hits: [],
        startOnset: 0,
        endOnset: 0,
        firstMeasure: -1,
        lastMeasure: -1,
      );
    }
    var minOnset = double.infinity;
    var maxOnset = double.negativeInfinity;
    var firstMeasure = 1 << 30;
    var lastMeasure = -1;
    for (final h in hits) {
      if (h.onset < minOnset) minOnset = h.onset;
      if (h.onset > maxOnset) maxOnset = h.onset;
      if (h.measureIndex >= 0) {
        if (h.measureIndex < firstMeasure) firstMeasure = h.measureIndex;
        if (h.measureIndex > lastMeasure) lastMeasure = h.measureIndex;
      }
    }
    return ScoreSelection(
      hits: hits,
      startOnset: minOnset,
      endOnset: maxOnset,
      firstMeasure: firstMeasure == 1 << 30 ? -1 : firstMeasure,
      lastMeasure: lastMeasure,
    );
  }

  List<ScoreHit> _select(bool Function(PositionedElement) test) {
    final result = <ScoreHit>[];
    for (final positioned in elements) {
      if (!test(positioned)) continue;
      result.add(_hitFrom(positioned, boundsOf(positioned), 0));
    }
    return result;
  }

  ScoreHit _hitFrom(PositionedElement positioned, Rect bounds, double d) =>
      ScoreHit(
        element: positioned.element,
        position: positioned.position,
        bounds: bounds,
        system: positioned.system,
        measureIndex: positioned.measureIndex,
        voiceNumber: positioned.voiceNumber,
        onset: positioned.onset,
        distance: d,
      );

  static int _rank(ScoreHit hit) {
    final e = hit.element;
    if (e is Note || e is Chord) return 3;
    if (e is Rest) return 2;
    if (e is Tuplet) return 2;
    return 1;
  }

  static double _distanceTo(Rect rect, Offset point) {
    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : (point.dx > rect.right ? point.dx - rect.right : 0.0);
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : (point.dy > rect.bottom ? point.dy - rect.bottom : 0.0);
    if (dx == 0 && dy == 0) return 0;
    return dx > dy ? dx : dy;
  }
}
