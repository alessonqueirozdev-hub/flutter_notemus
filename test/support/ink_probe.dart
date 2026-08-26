// test/support/ink_probe.dart
//
// Pixel-measurement helpers shared by the wave-4 invariant suites.
//
// Several of the invariants those suites pin are claims about INK — how thick a
// bracket is drawn, how much white is left between two noteheads, how far past
// its reserved advance a glyph paints. Every one of them had been argued from
// geometry alone before, and geometry is exactly what a renderer is free to
// disagree with; that disagreement is the shape of findings M-16, M-17, M-28
// and M-33. So these read the real raster.
//
// The one trick worth knowing: [invisibleStaffTheme] paints the staff lines and
// barlines in fully transparent black. They are the only ink that covers every
// column of the image, so without it no per-element ink measurement is possible
// at all — a notehead's cluster would be fused to the whole staff.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// A theme whose staff lines and barlines draw nothing, so the only ink in the
/// raster belongs to the notation symbols themselves.
const MusicScoreTheme invisibleStaffTheme = MusicScoreTheme(
  staffLineColor: Color(0x00000000),
  barlineColor: Color(0x00000000),
);

/// A rasterised score, addressable by pixel.
class InkImage {
  final int width;
  final int height;

  /// Device pixels per logical pixel used for the render.
  final double pixelRatio;

  final Uint8List _rgba;

  InkImage(this.width, this.height, this.pixelRatio, this._rgba);

  /// True when the pixel is dark enough to count as ink.
  ///
  /// 140 rather than 128: Skia's analytic anti-aliasing puts a half-covered
  /// edge pixel at about 0x80, and a threshold exactly there makes a 1-pixel
  /// difference in a measured width depend on sub-pixel rounding.
  bool dark(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    final i = (y * width + x) * 4;
    return _rgba[i] < 140 && _rgba[i + 1] < 140 && _rgba[i + 2] < 140;
  }

  /// Maximal runs of consecutive dark pixels along the row [y], as
  /// `(start, end)` device-pixel columns, `end` inclusive.
  List<({int start, int end})> runsInRow(int y) =>
      _runs((x) => dark(x, y), width);

  /// Maximal runs of consecutive dark pixels down the column [x].
  List<({int start, int end})> runsInColumn(int x) =>
      _runs((y) => dark(x, y), height);

  /// The run of [runs] that contains [value], or null.
  static ({int start, int end})? runContaining(
    List<({int start, int end})> runs,
    int value,
  ) {
    for (final run in runs) {
      if (value >= run.start && value <= run.end) return run;
    }
    return null;
  }

  static List<({int start, int end})> _runs(
    bool Function(int) isInk,
    int limit,
  ) {
    final result = <({int start, int end})>[];
    var start = -1;
    for (var i = 0; i <= limit; i++) {
      final ink = i < limit && isInk(i);
      if (ink && start < 0) start = i;
      if (!ink && start >= 0) {
        result.add((start: start, end: i - 1));
        start = -1;
      }
    }
    return result;
  }

  /// Columns holding at least one ink pixel, restricted to rows `[top, bottom)`
  /// when given.
  List<bool> inkColumns({int top = 0, int? bottom}) {
    final last = bottom ?? height;
    final columns = List<bool>.filled(width, false);
    for (var x = 0; x < width; x++) {
      for (var y = top; y < last; y++) {
        if (dark(x, y)) {
          columns[x] = true;
          break;
        }
      }
    }
    return columns;
  }
}

/// Rasterises [staff] and returns it as an [InkImage].
///
/// [width] is a LOGICAL width and must stay under
/// `ScoreRasterizer.maxPageDimension / pixelRatio`, or the rasteriser shrinks
/// the pixel ratio to fit and every measurement silently changes scale.
Future<InkImage> rasterise(
  Staff staff,
  SmuflMetadata metadata, {
  double staffSpace = 12.0,
  double width = 900,
  double pixelRatio = 1.0,
  MusicScoreTheme theme = invisibleStaffTheme,
}) async {
  final image = await ScoreRasterizer.renderStaffToImage(
    staff: staff,
    metadata: metadata,
    width: width,
    staffSpace: staffSpace,
    pixelRatio: pixelRatio,
    theme: theme,
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return InkImage(
    image.width,
    image.height,
    pixelRatio,
    bytes!.buffer.asUint8List(),
  );
}
