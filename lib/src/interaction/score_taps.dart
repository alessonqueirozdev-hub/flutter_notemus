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

/// The [Note] a [hit] stands for: the note itself, or, for a chord, the chord
/// note whose notehead centre is nearest [point] vertically. Null for any
/// other element (a rest, a clef, a dynamic).
Note? noteForHit(ScoreHit hit, LayoutEngine engine, Offset point) {
  final element = hit.element;
  if (element is Note) return element;
  if (element is! Chord || element.notes.isEmpty) return null;
  final ys = engine.noteYPositions; // a fresh unmodifiable copy per call
  Note best = element.notes.first;
  var bestDistance = double.infinity;
  for (final note in element.notes) {
    final y = ys[note];
    if (y == null) continue;
    final distance = (y - point.dy).abs();
    if (distance < bestDistance) {
      best = note;
      bestDistance = distance;
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
/// first element starts at or before [x]. Null before the first bar.
///
/// [elements] are one staff's (or one system's) positioned elements; a bar
/// spans from its leftmost element to the leftmost element of the next one.
int? measureIndexAtX(Iterable<PositionedElement> elements, double x) {
  final starts = <int, double>{};
  for (final positioned in elements) {
    final index = positioned.measureIndex;
    if (index < 0) continue;
    final dx = positioned.position.dx;
    final known = starts[index];
    if (known == null || dx < known) starts[index] = dx;
  }
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
