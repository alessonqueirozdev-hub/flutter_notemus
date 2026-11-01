// lib/src/widgets/playhead_layer.dart
//
// The playback cursor layer of MusicScore. It is its own CustomPainter,
// listening to the position, behind its own RepaintBoundary: a clock tick
// repaints one line, never the notation under it.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../layout/layout_engine.dart';
import '../playback/playback_plan.dart';
import '../playback/playhead.dart';

/// Paints the cursor for [position] over a single-staff layout of
/// [elements], drawn the way `MusicScorePainter` draws it: system `i`'s
/// middle line at `i * 10 + 5` staff spaces, shifted down by [topInset].
class MusicScorePlayheadPainter extends CustomPainter {
  MusicScorePlayheadPainter({
    required this.position,
    required this.elements,
    required this.staffSpace,
    required this.color,
    this.topInset = 0.0,
  }) : super(repaint: position);

  final ValueListenable<PlaybackPosition?> position;
  final List<PositionedElement> elements;
  final double staffSpace;
  final double topInset;
  final Color color;

  /// The layout's elements by bar, built once per layout.
  late final Map<int, List<PositionedElement>> _byMeasure = () {
    final map = <int, List<PositionedElement>>{};
    for (final e in elements) {
      if (e.measureIndex < 0) continue;
      (map[e.measureIndex] ??= <PositionedElement>[]).add(e);
    }
    return map;
  }();

  /// Where the cursor is for the current position: its x and the middle line
  /// of its system, or null when the position names no laid-out bar.
  ({double x, double middle})? placement() {
    final p = position.value;
    if (p == null) return null;
    final bar = _byMeasure[p.measureIndex];
    if (bar == null || bar.isEmpty) return null;
    final x = playheadX(
      bar,
      offset: p.offsetInMeasure,
      measureLength: p.measureLength,
      // This bar and the next: a bar may be closed by the NEXT bar's
      // opening barline. Not the whole staff — this runs on every tick.
      closingX: closingBarlineX(
        [...bar, ...?_byMeasure[p.measureIndex + 1]],
        p.measureIndex,
      ),
    );
    if (x == null) return null;
    final system = bar.first.system;
    return (
      x: x,
      middle: topInset + system * staffSpace * 10 + staffSpace * 5,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final at = placement();
    if (at == null) return;
    canvas.drawLine(
      Offset(at.x, at.middle - staffSpace * 3),
      Offset(at.x, at.middle + staffSpace * 3),
      Paint()
        ..color = color
        ..strokeWidth = staffSpace * 0.25 < 1.0 ? 1.0 : staffSpace * 0.25,
    );
  }

  @override
  bool shouldRepaint(MusicScorePlayheadPainter old) =>
      !identical(old.position, position) ||
      !identical(old.elements, elements) ||
      old.staffSpace != staffSpace ||
      old.topInset != topInset ||
      old.color != color;
}
