// lib/src/playback/playhead.dart
//
// Where a playback cursor stands inside a laid-out bar. Shared by
// MusicScore's and GrandStaff's playhead layers so both widgets put the line
// at the same x for the same musical moment.
//
// Ported from @zamvar's fork (`codex/note-tap`, `_playheadForSystem` /
// `_interpolateRhythmicX`): the cursor glides between the bar's rhythmic
// events, so it reaches each note exactly when that note starts sounding,
// however unevenly the layout spaced them.

import '../../core/core.dart';
import '../layout/layout_engine.dart';

/// The x at which a cursor [offset] whole notes into a bar of
/// [measureLength] whole notes stands, given the bar's positioned
/// [elements] (one staff's, or every staff's of one system — the shared grid
/// gives the same x to the same onset).
///
/// The cursor is linear between consecutive rhythmic events (notes, rests,
/// chords, tuplets, spaces) by their `onset`, and from the last one to
/// [closingX] — the bar's closing barline — over the rest of the bar. Null
/// when the bar has no rhythmic event to anchor on.
double? playheadX(
  Iterable<PositionedElement> elements, {
  required double offset,
  required double measureLength,
  double? closingX,
}) {
  // Earliest x per onset: noteheads of one chord, or of several staves,
  // share the onset; the leftmost is where the event begins.
  final byOnset = <double, double>{};
  for (final positioned in elements) {
    final e = positioned.element;
    final rhythmic = e is Note && !e.isGraceNote ||
        e is Rest ||
        e is Chord ||
        e is Tuplet ||
        e is Space;
    if (!rhythmic) continue;
    final onset = positioned.onset;
    final known = byOnset[onset];
    if (known == null || positioned.position.dx < known) {
      byOnset[onset] = positioned.position.dx;
    }
  }
  if (byOnset.isEmpty) return null;

  final onsets = byOnset.keys.toList()..sort();
  final start = onsets.first;
  final anchors = <({double at, double x})>[
    for (final onset in onsets) (at: onset - start, x: byOnset[onset]!),
  ];
  if (closingX != null && closingX > anchors.last.x) {
    final end = measureLength > anchors.last.at ? measureLength : anchors.last.at;
    anchors.add((at: end, x: closingX));
  }

  if (offset <= anchors.first.at) return anchors.first.x;
  for (var i = 1; i < anchors.length; i++) {
    final a = anchors[i - 1];
    final b = anchors[i];
    if (offset <= b.at) {
      final span = b.at - a.at;
      if (span <= 0) return b.x;
      return a.x + (b.x - a.x) * (offset - a.at) / span;
    }
  }
  return anchors.last.x;
}

/// Where bar [measureIndex] ends, among [elements] (the whole staff's or
/// system's, not just the bar's): its closing barline, or null when nothing
/// on its line follows it.
///
/// A bar does not always carry its own closing barline: before a bar that
/// OPENS with a repeat barline, the layout draws only that one, and it
/// belongs to the next bar. Filtering on the bar's own index found nothing,
/// and the cursor sat on the last note for the rest of the bar before
/// jumping. The next bar's opening barline closes this one; failing that,
/// the next bar's first element — on the same system only, since a bar
/// ending a line is not closed by anything on the line below.
double? closingBarlineX(Iterable<PositionedElement> elements, int measureIndex) {
  double? close;
  int? system;
  for (final positioned in elements) {
    if (positioned.measureIndex != measureIndex) continue;
    system ??= positioned.system;
    if (positioned.element is! Barline) continue;
    final dx = positioned.position.dx;
    if (close == null || dx > close) close = dx;
  }
  if (close != null || system == null) return close;

  double? opening;
  double? firstOfNext;
  for (final positioned in elements) {
    if (positioned.measureIndex != measureIndex + 1) continue;
    if (positioned.system != system) continue;
    final dx = positioned.position.dx;
    if (positioned.element is Barline) {
      if (opening == null || dx < opening) opening = dx;
    }
    if (firstOfNext == null || dx < firstOfNext) firstOfNext = dx;
  }
  return opening ?? firstOfNext;
}
