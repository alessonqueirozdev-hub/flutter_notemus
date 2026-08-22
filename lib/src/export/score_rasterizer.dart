// lib/src/export/score_rasterizer.dart

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../layout/layout_engine.dart';
import '../rendering/staff_coordinate_system.dart';
import '../rendering/grand_staff_painter.dart';
import '../rendering/staff_renderer.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';

/// Result of laying a [Staff] out for rasterization.
///
/// Bundles everything a caller needs to slice the layout into pages without
/// running the engine again.
class StaffRasterLayout {
  /// Elements positioned by [LayoutEngine], in layout order.
  final List<PositionedElement> elements;

  /// The engine that produced [elements]; still needed at paint time (beam
  /// groups, accidental decisions, measure numbers).
  final LayoutEngine engine;

  /// Staff space, in logical pixels, used for the layout.
  final double staffSpace;

  /// Full logical width of the laid-out music (see [LayoutEngine.contentWidth]).
  final double logicalWidth;

  /// Full logical height of the laid-out music.
  final double logicalHeight;

  /// Number of systems (staff lines wrapped onto separate rows) produced.
  final int systemCount;

  const StaffRasterLayout({
    required this.elements,
    required this.engine,
    required this.staffSpace,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.systemCount,
  });

  /// Vertical size of one system band, in logical pixels.
  ///
  /// Mirrors `MusicScorePainter`: system `i` is drawn with its baseline at
  /// `i * staffSpace * 10 + staffSpace * 5`, so each system owns a band of
  /// `staffSpace * 10`.
  double get systemBandHeight =>
      staffSpace * ScoreRasterizer.systemHeightInStaffSpaces;

  /// Whether anything at all was laid out.
  bool get isEmpty => elements.isEmpty;
}

/// A single rasterized page: PNG bytes plus the geometry they were drawn with.
class RasterizedStaffPage {
  /// Encoded PNG bytes, ready to embed in a PDF.
  final Uint8List pngBytes;

  /// Pixel dimensions of [pngBytes].
  final int pixelWidth;

  /// Pixel dimensions of [pngBytes].
  final int pixelHeight;

  /// Logical (unscaled) size of the band this page covers.
  final double logicalWidth;

  /// Logical (unscaled) size of the band this page covers.
  final double logicalHeight;

  /// Index of the first system drawn on this page.
  final int firstSystem;

  /// How many systems this page covers.
  final int systemCount;

  const RasterizedStaffPage({
    required this.pngBytes,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.firstSystem,
    required this.systemCount,
  });
}

/// Rasterizes engraved notation to a [ui.Image] / PNG using the same layout and
/// rendering pipeline the on-screen `MusicScore` widget uses.
///
/// This is how the PDF export gets *real* notation instead of placeholders:
/// [LayoutEngine] positions the elements, [StaffRenderer] paints them onto a
/// [ui.Canvas] backed by a [ui.PictureRecorder], and the recorded picture is
/// converted to an image.
///
/// ## Requires a live Flutter engine
/// [ui.Picture.toImage] rasterizes through the engine, so every method here
/// only works inside a running Flutter application or a `flutter_test`
/// environment (where the test binding provides an engine). It cannot run in a
/// plain Dart VM (`dart test`, a server, a build script): there is no
/// rasterizer there and the calls will throw. Callers that must degrade
/// gracefully should catch and fall back — [ScoreRasterizer.renderStaffPages]
/// does exactly that and returns an empty list.
///
/// The glyph font must also be available: `SmuflMetadata.load()` has to have
/// completed, otherwise nothing is drawn.
///
/// Example:
/// ```dart
/// final metadata = SmuflMetadata();
/// await metadata.load();
/// final image = await ScoreRasterizer.renderStaffToImage(
///   staff: myStaff,
///   metadata: metadata,
///   width: 1200,
/// );
/// ```
class ScoreRasterizer {
  const ScoreRasterizer._();

  /// Height of one system band, expressed in staff spaces.
  ///
  /// Kept in sync with `MusicScorePainter.paint`, which spaces system
  /// baselines by `staffSpace * 10`.
  static const double systemHeightInStaffSpaces = 10.0;

  /// Runs the layout pass for [staff] without rasterizing anything.
  ///
  /// Useful when the caller needs the geometry (system count, content size) to
  /// decide on pagination before paying for rasterization.
  static StaffRasterLayout layoutStaff({
    required Staff staff,
    required SmuflMetadata metadata,
    required double width,
    double staffSpace = 12.0,
  }) {
    final engine = LayoutEngine(
      staff,
      availableWidth: width,
      staffSpace: staffSpace,
      metadata: metadata,
    );
    final elements = engine.layoutWithSignature().elements;

    var maxSystem = 0;
    for (final element in elements) {
      if (element.system > maxSystem) maxSystem = element.system;
    }

    return StaffRasterLayout(
      elements: elements,
      engine: engine,
      staffSpace: staffSpace,
      // The canvas must never be narrower than the music, otherwise the right
      // edge of a system is cropped away (same rule the widget applies).
      logicalWidth: math.max(width, engine.contentWidth(elements)),
      logicalHeight: engine.calculateTotalHeight(elements),
      systemCount: elements.isEmpty ? 0 : maxSystem + 1,
    );
  }

  /// Renders [staff] to a single [ui.Image] containing the whole score.
  ///
  /// [width] is the available width handed to [LayoutEngine] (logical pixels);
  /// the produced image is `width * pixelRatio` pixels wide, or wider when the
  /// music overflows. The image is painted on an opaque [background] (white by
  /// default) so it can be dropped straight into a PDF page.
  ///
  /// Requires a live Flutter engine — see the class doc.
  ///
  /// The caller owns the returned image and should call `dispose()` on it.
  static Future<ui.Image> renderStaffToImage({
    required Staff staff,
    required SmuflMetadata metadata,
    required double width,
    double staffSpace = 12.0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double pixelRatio = 2.0,
    Color background = const Color(0xFFFFFFFF),
  }) async {
    final layout = layoutStaff(
      staff: staff,
      metadata: metadata,
      width: width,
      staffSpace: staffSpace,
    );

    return _rasterizeBand(
      layout: layout,
      metadata: metadata,
      theme: theme,
      firstSystem: 0,
      systemCount: math.max(1, layout.systemCount),
      topLogicalY: 0,
      logicalHeight: layout.logicalHeight,
      pixelRatio: pixelRatio,
      background: background,
    );
  }

  /// Renders [staff] and returns it as PNG bytes, or null when the notation
  /// could not be rasterized (no live engine, unloaded metadata, empty staff).
  static Future<Uint8List?> renderStaffToPng({
    required Staff staff,
    required SmuflMetadata metadata,
    required double width,
    double staffSpace = 12.0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double pixelRatio = 2.0,
    Color background = const Color(0xFFFFFFFF),
  }) async {
    final pages = await renderStaffPages(
      staff: staff,
      metadata: metadata,
      width: width,
      staffSpace: staffSpace,
      theme: theme,
      pixelRatio: pixelRatio,
      background: background,
    );
    if (pages.isEmpty) return null;
    return pages.first.pngBytes;
  }

  /// Rasterizes [staff] into one PNG per page, never splitting a system across
  /// a page boundary.
  ///
  /// [systemsPerPage] caps how many systems land on one page; when null (or
  /// smaller than 1) every system goes on a single page. Pages are cut on
  /// system band boundaries, so a page always contains whole systems.
  ///
  /// Returns an empty list — instead of throwing — when the metadata is not
  /// loaded, the staff produced no elements, or rasterization is unavailable
  /// (no live Flutter engine). Callers can therefore treat "no pages" as
  /// "notation could not be rendered" and report it honestly.
  static Future<List<RasterizedStaffPage>> renderStaffPages({
    required Staff staff,
    required SmuflMetadata metadata,
    required double width,
    int? systemsPerPage,
    double staffSpace = 12.0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double pixelRatio = 2.0,
    Color background = const Color(0xFFFFFFFF),
    StaffRasterLayout? precomputedLayout,
  }) async {
    if (metadata.isNotLoaded) return const <RasterizedStaffPage>[];

    final layout =
        precomputedLayout ??
        layoutStaff(
          staff: staff,
          metadata: metadata,
          width: width,
          staffSpace: staffSpace,
        );
    if (layout.isEmpty || layout.systemCount <= 0) {
      return const <RasterizedStaffPage>[];
    }

    final perPage = (systemsPerPage == null || systemsPerPage < 1)
        ? layout.systemCount
        : systemsPerPage;
    final bandHeight = layout.systemBandHeight;

    // Headroom the music needs beyond the default band: high ledger-line notes,
    // boxed rehearsal marks, tempo text above; multi-verse lyrics below. A band
    // sized purely as `systems * bandHeight` clips them — the very defect the
    // on-screen painter was fixed for, so the PDF must not reintroduce it.
    final topInset = layout.engine.contentTopOverflow(layout.elements);
    final bottomInset = layout.engine.contentBottomOverflow(layout.elements);

    final pages = <RasterizedStaffPage>[];
    try {
      for (var first = 0; first < layout.systemCount; first += perPage) {
        final count = math.min(perPage, layout.systemCount - first);
        final isFirstPage = first == 0;
        final isLastPage = first + count >= layout.systemCount;

        // Bands stay a whole number of system heights so every page shares one
        // scale factor; only the outer edges grow, by the measured overflow.
        final extraTop = isFirstPage ? topInset : 0.0;
        final extraBottom = isLastPage ? bottomInset : 0.0;
        final logicalHeight = bandHeight * count + extraTop + extraBottom;

        final image = await _rasterizeBand(
          layout: layout,
          metadata: metadata,
          theme: theme,
          firstSystem: first,
          systemCount: count,
          topLogicalY: bandHeight * first - extraTop,
          logicalHeight: logicalHeight,
          pixelRatio: pixelRatio,
          background: background,
        );

        try {
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) return const <RasterizedStaffPage>[];
          pages.add(
            RasterizedStaffPage(
              pngBytes: byteData.buffer.asUint8List(
                byteData.offsetInBytes,
                byteData.lengthInBytes,
              ),
              pixelWidth: image.width,
              pixelHeight: image.height,
              logicalWidth: layout.logicalWidth,
              logicalHeight: logicalHeight,
              firstSystem: first,
              systemCount: count,
            ),
          );
        } finally {
          image.dispose();
        }
      }
    } catch (_) {
      // No live engine (plain Dart VM) or a rasterization failure: report
      // "nothing rendered" rather than emitting a half-drawn score.
      return const <RasterizedStaffPage>[];
    }

    return pages;
  }

  /// Paints systems `[firstSystem, firstSystem + systemCount)` of [layout] into
  /// an image covering the logical band starting at [topLogicalY].
  ///
  /// The geometry deliberately mirrors `MusicScorePainter.paint`: one
  /// [StaffRenderer] per system, with its baseline at
  /// `system * staffSpace * 10 + staffSpace * 5`.
  /// Rasterizes a multi-staff [StaffGroup] as a real grand staff, using the
  /// SAME [GrandStaffPainter] the widget draws with.
  ///
  /// `PdfExporter` used to loop over `group.staves` and rasterize each staff on
  /// its own through the single-staff path, so a piano part came out of the
  /// exporter as two independent one-line staves with headings: no brace, no
  /// system barlines, and the two hands not aligned with each other. Reusing
  /// the painter means the printed page and the screen cannot disagree — the
  /// alternative is a second implementation of the multi-staff geometry, which
  /// is the defect this whole remediation exists to remove.
  ///
  /// Returns null when there is nothing to draw.
  static Future<RasterizedStaffPage?> renderGroupToPage({
    required StaffGroup group,
    required SmuflMetadata metadata,
    required double width,
    double staffSpace = 12.0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double pixelRatio = 2.0,
    Color background = const Color(0xFFFFFFFF),
  }) async {
    if (metadata.isNotLoaded) return null;
    if (group.staves.isEmpty) return null;
    if (group.staves.every((staff) => staff.measures.isEmpty)) return null;

    final painter = GrandStaffPainter(
      staffGroup: group,
      staffSpace: staffSpace,
      metadata: metadata,
      theme: theme,
      availableWidth: width,
    );

    final ratio = pixelRatio.isFinite && pixelRatio > 0 ? pixelRatio : 1.0;
    final height = math.max(1.0, painter.totalHeight);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = background,
    );
    painter.paint(canvas, Size(width, height));

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        math.max(1, (width * ratio).ceil()),
        math.max(1, (height * ratio).ceil()),
      );
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) return null;
        return RasterizedStaffPage(
          pngBytes: data.buffer.asUint8List(),
          pixelWidth: image.width,
          pixelHeight: image.height,
          logicalWidth: width,
          logicalHeight: height,
          firstSystem: 0,
          systemCount: painter.systemCount,
        );
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  static Future<ui.Image> _rasterizeBand({
    required StaffRasterLayout layout,
    required SmuflMetadata metadata,
    required MusicScoreTheme theme,
    required int firstSystem,
    required int systemCount,
    required double topLogicalY,
    required double logicalHeight,
    required double pixelRatio,
    required Color background,
  }) async {
    final ratio = pixelRatio.isFinite && pixelRatio > 0 ? pixelRatio : 1.0;
    final width = layout.logicalWidth;
    final height = math.max(1.0, logicalHeight);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);

    // Opaque page background: a PDF page under a transparent PNG would show
    // through, and printers do not like transparency.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = background,
    );

    // Move the requested band to the top of the image.
    canvas.translate(0, -topLogicalY);

    final groups = <int, List<PositionedElement>>{};
    for (final element in layout.elements) {
      groups
          .putIfAbsent(element.system, () => <PositionedElement>[])
          .add(element);
    }

    final staffSpace = layout.staffSpace;
    for (var i = 0; i < systemCount; i++) {
      final systemIndex = firstSystem + i;
      final elements = groups[systemIndex];
      if (elements == null || elements.isEmpty) continue;

      final systemY =
          (systemIndex * staffSpace * systemHeightInStaffSpaces) +
          (staffSpace * 5.0);
      final renderer = StaffRenderer(
        coordinates: StaffCoordinateSystem(
          staffSpace: staffSpace,
          staffBaseline: Offset(0, systemY),
        ),
        metadata: metadata,
        theme: theme,
      );
      renderer.renderStaff(
        canvas,
        elements,
        Size(width, height),
        layoutEngine: layout.engine,
      );
    }

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        math.max(1, (width * ratio).ceil()),
        math.max(1, (height * ratio).ceil()),
      );
    } finally {
      picture.dispose();
    }
  }
}
