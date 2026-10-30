// lib/src/interaction/score_taps.dart
//
// What `MusicScore.onNoteTap` / `onMeasureTap` and their `GrandStaff`
// counterparts report. Both widgets resolve a tap through [ScoreHitTester], so
// a tap lands on the same boxes the 2.8 hit-testing fixes measured — the stem
// tip, the whole flag, the full width of a rest — and hands back the caller's
// own [Note], not a copy.
//
// The callbacks are ported from @zamvar's fork (`codex/note-tap`), which
// resolved taps with geometry of its own inside `GrandStaffPainter`; here they
// are rebuilt on the shared hit tester.

import 'dart:ui' show Offset;

import '../../core/core.dart';
import '../layout/layout_engine.dart';
import 'score_hit_tester.dart';

/// A tap on a rendered note.
class ScoreNoteTap {
  /// The tapped note — the very object in the caller's [Staff]. A tap on a
  /// chord reports the chord note whose notehead is nearest the tap.
  final Note note;

  /// Zero-based index of the bar in its [Staff].
  final int measureIndex;

  /// Index of the staff, top to bottom across all groups; always 0 in
  /// `MusicScore`.
  final int staffIndex;

  /// Tap position in the score canvas's local coordinates.
  final Offset localPosition;

  /// Tap position on screen, for placing a popup next to the note.
  final Offset globalPosition;

  const ScoreNoteTap({
    required this.note,
    required this.measureIndex,
    required this.staffIndex,
    required this.localPosition,
    required this.globalPosition,
  });

  @override
  String toString() => 'ScoreNoteTap(${note.pitch.step}${note.pitch.octave}, '
      'bar index $measureIndex, staff $staffIndex)';
}

/// A tap inside the horizontal span of a rendered bar.
class ScoreMeasureTap {
  /// Zero-based index of the bar in its [Staff]. Unique even where display
  /// numbers repeat (an uncounted bar shares the previous bar's number).
  final int measureIndex;

  /// The number the bar is printed with: [Measure.number] when the source
  /// gave one, otherwise counted as `Measure.displayNumbers` does.
  final int measureNumber;

  /// Index of the staff the tap was nearest, top to bottom; always 0 in
  /// `MusicScore`.
  final int staffIndex;

  /// Tap position in the score canvas's local coordinates.
  final Offset localPosition;

  /// Tap position on screen.
  final Offset globalPosition;

  const ScoreMeasureTap({
    required this.measureIndex,
    required this.measureNumber,
    required this.staffIndex,
    required this.localPosition,
    required this.globalPosition,
  });

  @override
  String toString() =>
      'ScoreMeasureTap(bar $measureNumber, index $measureIndex, '
      'staff $staffIndex)';
}

/// The [Note] a [hit] stands for: the note itself; for a chord, the chord
/// note whose notehead is nearest [point] vertically; for a tuplet (which the
/// layout positions as ONE element, keeping its notes' geometry apart), the
/// inner note whose notehead is nearest [point]. Null for any other element
/// (a rest, a clef, a dynamic) or a tuplet of rests.
Note? noteForHit(ScoreHit hit, LayoutEngine engine, Offset point) {
  final element = hit.element;
  if (element is Note) return element;
  if (element is Chord) return _nearestNote(element.notes, engine, point);
  if (element is Tuplet) {
    return _nearestNote(_notesOf(element.elements), engine, point);
  }
  return null;
}

/// Every note inside [elements], descending into chords and nested tuplets.
List<Note> _notesOf(List<MusicalElement> elements) => [
      for (final e in elements)
        if (e is Note)
          e
        else if (e is Chord)
          ...e.notes
        else if (e is Tuplet)
          ..._notesOf(e.elements),
    ];

/// The note of [notes] nearest [point]: by x first, so a tap picks the column
/// it is on, then by y within that column (a chord). Notes the layout gave no
/// position fall back to the first one.
Note? _nearestNote(List<Note> notes, LayoutEngine engine, Offset point) {
  if (notes.isEmpty) return null;
  final xs = engine.noteXPositions; // fresh unmodifiable copies per call
  final ys = engine.noteYPositions;
  Note best = notes.first;
  var bestDx = double.infinity;
  var bestDy = double.infinity;
  for (final note in notes) {
    final x = xs[note];
    final y = ys[note];
    if (x == null || y == null) continue;
    final dx = (x - point.dx).abs();
    final dy = (y - point.dy).abs();
    // Noteheads of one chord share an x; anything within a pixel of the best
    // column counts as the same column.
    final sameColumn = (dx - bestDx).abs() < 1.0;
    if (dx < bestDx - 1.0 || (sameColumn && dy < bestDy)) {
      best = note;
      bestDx = dx;
      bestDy = dy;
    }
  }
  return best;
}

/// The system (wrapped line) under [y]: the one whose elements' vertical
/// span contains it, else the one whose span is nearest. Null for no
/// elements.
///
/// Wrapped systems reuse the same horizontal range, so a bar lookup by x alone
/// across a whole staff picks a bar from whichever system starts latest.
int? systemAtY(Iterable<PositionedElement> elements, double y) {
  final top = <int, double>{};
  final bottom = <int, double>{};
  for (final positioned in elements) {
    final system = positioned.system;
    final dy = positioned.position.dy;
    if (dy < (top[system] ?? double.infinity)) top[system] = dy;
    if (dy > (bottom[system] ?? double.negativeInfinity)) bottom[system] = dy;
  }
  int? best;
  var bestDistance = double.infinity;
  top.forEach((system, t) {
    final b = bottom[system]!;
    final distance = y < t ? t - y : (y > b ? y - b : 0.0);
    if (distance < bestDistance) {
      best = system;
      bestDistance = distance;
    }
  });
  return best;
}

/// Index of the bar whose horizontal span contains [x]: the last bar whose
/// first element starts at or before [x], or null before the first bar or,
/// given [engine], past the right edge of the music (an opaque canvas wider
/// than the score used to hand every tap in the blank space after it to the
/// last bar).
///
/// [elements] are one staff's (or one system's) positioned elements; a bar
/// spans from its leftmost element to the leftmost element of the next one,
/// and the last bar to the painted right edge of its rightmost element.
int? measureIndexAtX(
  Iterable<PositionedElement> elements,
  double x, {
  LayoutEngine? engine,
}) {
  final starts = <int, double>{};
  var right = double.negativeInfinity;
  for (final positioned in elements) {
    if (engine != null) {
      final edge = positioned.position.dx +
          engine.elementPaintedRightExtent(positioned.element);
      if (edge > right) right = edge;
    }
    final index = positioned.measureIndex;
    if (index < 0) continue;
    final dx = positioned.position.dx;
    final known = starts[index];
    if (known == null || dx < known) starts[index] = dx;
  }
  if (engine != null && x > right) return null;
  int? best;
  var bestStart = double.negativeInfinity;
  starts.forEach((index, start) {
    if (start <= x && start > bestStart) {
      best = index;
      bestStart = start;
    }
  });
  return best;
}
