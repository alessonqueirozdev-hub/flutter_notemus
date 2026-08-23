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

/// Result of laying a multi-staff [StaffGroup] out for rasterization.
///
/// The grand-staff mirror of [StaffRasterLayout]. It exists for the same
/// reason: `PdfExporter` has to know the system count and the height of ONE
/// system band before it can decide how many systems fit on a page, and it must
/// not pay for a second layout pass to find out.
///
/// The whole layout lives inside [painter] — building a [GrandStaffPainter] is
/// what runs the per-system [LayoutEngine] passes and the cross-staff onset
/// alignment — so the painter is carried here and reused for every band.
class GroupRasterLayout {
  /// The painter that holds the laid-out systems; reused for every band so the
  /// (expensive) layout runs exactly once per export.
  final GrandStaffPainter painter;

  /// Full logical width of the laid-out music, never narrower than the width
  /// the caller asked for. See [ScoreRasterizer.measureGroupContentWidth].
  final double logicalWidth;

  /// Full logical height of all systems stacked (`painter.totalHeight`).
  final double logicalHeight;

  /// Vertical size of one system band, in logical pixels
  /// (`painter.systemBlockHeight`).
  final double systemBandHeight;

  /// Headroom the painter reserves above the first system for music that
  /// reaches above the staff (`painter.contentTopInset`).
  final double topInset;

  /// Space below the last system: the painter's bottom margin plus whatever
  /// the music reaches below the staff.
  ///
  /// `GrandStaffPainter` keeps its bottom inset private, so it is recovered
  /// from the identity `totalHeight == systems * block + 2 * staffSpace +
  /// topInset + bottomInset`.
  final double bottomInset;

  const GroupRasterLayout({
    required this.painter,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.systemBandHeight,
    required this.topInset,
    required this.bottomInset,
  });

  /// Number of wrapped systems the group produced.
  int get systemCount => painter.systemCount;

  /// Whether anything at all was laid out.
  bool get isEmpty => painter.systemCount == 0 || logicalHeight <= 0;
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

  /// Largest edge, in PIXELS, that a single rasterized page may have.
  ///
  /// `Picture.toImage` allocates one GPU texture per image, and a texture wider
  /// or taller than the device limit either fails outright or silently falls
  /// back to a software path. 8192 is the smallest of the limits worth
  /// targeting: contemporary mobile GPUs guarantee 4096-8192, desktop GL
  /// commonly stops at 16384. It is also a memory ceiling — RGBA at 8192 x 8192
  /// is already 256 MB.
  ///
  /// Measured before the guard existed: a 60-bar two-staff piano group wrapped
  /// into 20 systems, 5064 logical px tall, and `renderGroupToPage` rasterized
  /// it at `pixelRatio` 2 into a single 10128 px tall image; the forensic audit
  /// measured 15168 px (~97 MB of RGBA, 3570 ms) on a 30-system group and
  /// projected 151248 px for a 600-bar score. Both exceed every mobile limit.
  ///
  /// The guard is deliberately a RESOLUTION cap, not a crop: [_fitPixelRatio]
  /// lowers the pixel ratio until both edges fit, so an oversized page comes
  /// out softer but complete. Cropping would lose music, which is the very
  /// defect this class exists to avoid. Callers that want full resolution
  /// should paginate — [renderStaffPages] and [renderGroupPages] do.
  static const int maxPageDimension = 8192;

  /// Scales [requested] down until neither edge of the resulting image exceeds
  /// [maxPageDimension] pixels.
  ///
  /// Returns [requested] unchanged for every page that already fits, which is
  /// every page produced by the paginated entry points at sane page sizes: the
  /// A4 band of 5 systems that a 40-bar piano score paginates into measures
  /// 1928 x 2520 px at `pixelRatio` 2.
  static double _fitPixelRatio(
    double requested,
    double logicalWidth,
    double logicalHeight,
  ) {
    final base = requested.isFinite && requested > 0 ? requested : 1.0;
    final width = math.max(1.0, logicalWidth);
    final height = math.max(1.0, logicalHeight);
    final cap = math.min(maxPageDimension / width, maxPageDimension / height);
    if (cap >= base) return base;
    // Never return zero or a negative ratio: a 1 px image still beats a throw.
    return math.max(cap, 1.0 / math.max(width, height));
  }

  /// Pixel extent of a [logical] length at [ratio], never above
  /// [maxPageDimension].
  ///
  /// [_fitPixelRatio] already sizes the ratio so both edges fit, but it divides
  /// and this multiplies: at the exact boundary the round trip can land on
  /// 8192.0000000001 and `ceil()` would hand `Picture.toImage` an 8193 px edge.
  /// The clamp costs at most one pixel column of the band and cannot be the
  /// reason a texture allocation fails.
  static int _pixelExtent(double logical, double ratio) =>
      math.min(maxPageDimension, math.max(1, (logical * ratio).ceil()));

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

    // The band must START at the highest logical Y the music actually reaches,
    // not at 0 (finding M-23).
    //
    // `layout.logicalHeight` is `LayoutEngine.calculateTotalHeight`, which
    // already ADDS `contentTopOverflow` — but height alone buys nothing if the
    // origin does not move with it: `_rasterizeBand` translates by
    // `-topLogicalY`, so with 0 here the extra headroom was appended to the
    // BOTTOM of the image and everything above logical y = 0 was still cropped.
    // [renderStaffPages] never had the bug because it passes
    // `bandHeight * first - extraTop`.
    //
    // Measured, a 5:4 tuplet on C6-G6 at staffSpace 12 in a 900 px viewport:
    // `contentTopOverflow` reports 38.40 px (the G6 notehead sits 72.00 px above
    // the baseline against 60.00 px of default headroom) and the image was
    // correctly sized 900x231 — yet row 0 carried 74 dark pixels, the E6 ledger
    // lines of the last three notes, and the G6 notehead with its own ledger
    // line was off the canvas entirely. The same score through
    // [renderStaffToPng] (i.e. [renderStaffPages]) measured 0 px on row 0.
    // After this line: 0 px on row 0 for the C6-G6 case and for the C3-G3 one.
    return _rasterizeBand(
      layout: layout,
      metadata: metadata,
      theme: theme,
      firstSystem: 0,
      systemCount: math.max(1, layout.systemCount),
      topLogicalY: -layout.engine.contentTopOverflow(layout.elements),
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
  /// Right edge of everything a [GrandStaffPainter] draws, in logical pixels.
  ///
  /// The grand-staff mirror of [LayoutEngine.contentWidth], and the reason
  /// [layoutGroup] never hands the rasterizer a canvas narrower than the music.
  ///
  /// [layoutStaff] has always widened its canvas to
  /// `max(width, engine.contentWidth(elements))` "otherwise the right edge of a
  /// system is cropped away". The group path used the requested width verbatim:
  /// measured on a single bar of sixteen sixteenths requested at 200 logical
  /// px, the painter placed its last element at x = 679.99 (content edge 718.39
  /// including the 26.4 px brace pad) and the rasterizer produced a 200 px wide
  /// canvas — 518 px of music simply cut off. The same music through the
  /// single-staff path widened to 570.67 px and lost nothing.
  ///
  /// ## Now a pure delegation to [GrandStaffPainter.contentWidth]
  /// This used to RECONSTRUCT the width from OUTSIDE the painter, because the
  /// painter published neither its content width nor its per-system
  /// [LayoutEngine]s. It walked `painter.alignedSystem(...)` — a
  /// `@visibleForTesting` member, reached past its own annotation with an
  /// `// ignore: invalid_use_of_visible_for_testing_member` — measured every
  /// element with a THROWAWAY [LayoutEngine] over an empty staff used as a
  /// width oracle, and restated the painter's private `_bracePad`
  /// (`staffSpace * 2.2`) as a local constant to finish the sum. Three copies
  /// of the painter's internals lived in this file: the brace pad, the
  /// element-width rule, and the trailing half staff space.
  ///
  /// The oracle was also measurably WRONG, and said so: having run no layout
  /// pass it had no accidental decisions, so it could not subtract
  /// [LayoutEngine.elementLeftExtent] and deliberately over-reported the width
  /// by the left extent of the rightmost element ("over-reporting a left extent
  /// UNDER-reports the right edge, which crops music again").
  /// [GrandStaffPainter.contentWidth] asks the real per-system engines, with
  /// the real accidental decisions, and subtracts the real left extent — so it
  /// is simultaneously simpler and strictly closer to the ink.
  ///
  /// [staffSpace] and [metadata] are no longer read: the painter was built with
  /// both, and measuring against a SECOND pair was the defect. They stay in the
  /// signature so existing callers keep compiling.
  static double measureGroupContentWidth(
    GrandStaffPainter painter, {
    required double staffSpace,
    required SmuflMetadata metadata,
  }) =>
      painter.systemCount == 0 ? 0.0 : painter.contentWidth;

  /// Lays a multi-staff [group] out as a braced grand staff without
  /// rasterizing anything.
  ///
  /// The grand-staff mirror of [layoutStaff]: it gives the caller the system
  /// count and the band height needed to paginate, and carries the built
  /// [GrandStaffPainter] so [renderGroupPages] does not lay the music out a
  /// second time (measured on a 40-bar two-staff piano score, the layout pass
  /// is by far the expensive half of the export).
  static GroupRasterLayout layoutGroup({
    required StaffGroup group,
    required SmuflMetadata metadata,
    required double width,
    double staffSpace = 12.0,
    MusicScoreTheme theme = const MusicScoreTheme(),
  }) {
    final painter = GrandStaffPainter(
      staffGroup: group,
      staffSpace: staffSpace,
      metadata: metadata,
      theme: theme,
      availableWidth: width,
    );

    final systemCount = painter.systemCount;
    final blockHeight = painter.systemBlockHeight;
    final topInset = painter.contentTopInset;
    // `totalHeight == systems * block + 2 * staffSpace + topInset +
    // bottomInset`; the painter keeps the bottom inset private, so recover the
    // whole tail (margin + overflow) as one number.
    final bottomInset =
        painter.totalHeight - systemCount * blockHeight - topInset;

    return GroupRasterLayout(
      painter: painter,
      logicalWidth: math.max(
        width,
        measureGroupContentWidth(
          painter,
          staffSpace: staffSpace,
          metadata: metadata,
        ),
      ),
      logicalHeight: painter.totalHeight,
      systemBandHeight: blockHeight,
      topInset: topInset,
      bottomInset: math.max(0.0, bottomInset),
    );
  }

  /// Rasterizes a multi-staff [StaffGroup] as a real grand staff into one PNG
  /// per page, never splitting a system across a page boundary.
  ///
  /// The grand-staff mirror of [renderStaffPages], and the fix for two measured
  /// defects that only the group path had:
  ///
  /// * **Width.** The canvas is [GroupRasterLayout.logicalWidth], i.e. never
  ///   narrower than the music — see [measureGroupContentWidth] for the 518 px
  ///   of cropped notation that motivated it.
  /// * **Height.** There was no banding at all: every system went into one
  ///   image. Measured, a 60-bar two-staff group produced a 2000 x 10128 px
  ///   image, past the texture limit of every mobile GPU, and `PdfExporter`
  ///   then squeezed that one image into one page and showed 39.8% of it.
  ///
  /// [systemsPerPage] caps how many systems land on one page; when null (or
  /// smaller than 1) every system goes on a single page (still subject to
  /// [maxPageDimension]). Pages are cut on system BLOCK boundaries, exactly
  /// like [renderStaffPages]: interior pages are `systemsPerPage` blocks tall
  /// and only the outer edges grow, by the headroom the music reaches above the
  /// first system and below the last. That keeps one scale factor valid for
  /// every page of a group.
  ///
  /// Returns an empty list — instead of throwing — when the metadata is not
  /// loaded, the group is empty, or rasterization is unavailable (no live
  /// Flutter engine).
  static Future<List<RasterizedStaffPage>> renderGroupPages({
    required StaffGroup group,
    required SmuflMetadata metadata,
    required double width,
    int? systemsPerPage,
    double staffSpace = 12.0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double pixelRatio = 2.0,
    Color background = const Color(0xFFFFFFFF),
    GroupRasterLayout? precomputedLayout,
  }) async {
    if (metadata.isNotLoaded) return const <RasterizedStaffPage>[];
    if (group.staves.isEmpty) return const <RasterizedStaffPage>[];
    if (group.staves.every((staff) => staff.measures.isEmpty)) {
      return const <RasterizedStaffPage>[];
    }

    final layout =
        precomputedLayout ??
        layoutGroup(
          group: group,
          metadata: metadata,
          width: width,
          staffSpace: staffSpace,
          theme: theme,
        );
    if (layout.isEmpty) return const <RasterizedStaffPage>[];

    final perPage = (systemsPerPage == null || systemsPerPage < 1)
        ? layout.systemCount
        : systemsPerPage;
    final blockHeight = layout.systemBandHeight;
    if (!blockHeight.isFinite || blockHeight <= 0) {
      return const <RasterizedStaffPage>[];
    }

    final pages = <RasterizedStaffPage>[];
    try {
      for (var first = 0; first < layout.systemCount; first += perPage) {
        final count = math.min(perPage, layout.systemCount - first);
        final isFirstPage = first == 0;
        final isLastPage = first + count >= layout.systemCount;

        final extraTop = isFirstPage ? layout.topInset : 0.0;
        final extraBottom = isLastPage ? layout.bottomInset : 0.0;
        final logicalHeight = blockHeight * count + extraTop + extraBottom;

        // The painter shifts its whole drawing down by `topInset`, so system
        // `first` starts at `topInset + first * blockHeight`; the first page
        // additionally shows the headroom above it.
        final topLogicalY = layout.topInset + blockHeight * first - extraTop;

        final image = await _rasterizeGroupBand(
          layout: layout,
          topLogicalY: topLogicalY,
          logicalHeight: logicalHeight,
          pixelRatio: pixelRatio,
          background: background,
        );

        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) return const <RasterizedStaffPage>[];
          pages.add(
            RasterizedStaffPage(
              pngBytes: data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
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
  /// Every system lands in ONE image. That is fine for a short group and wrong
  /// for a long one: at 20 systems the image is 10128 px tall and gets scaled
  /// down to fit [maxPageDimension]. Anything that paginates — `PdfExporter`
  /// does — should call [renderGroupPages] instead.
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
    final pages = await renderGroupPages(
      group: group,
      metadata: metadata,
      width: width,
      staffSpace: staffSpace,
      theme: theme,
      pixelRatio: pixelRatio,
      background: background,
    );
    if (pages.isEmpty) return null;
    return pages.first;
  }

  /// Paints the logical band `[topLogicalY, topLogicalY + logicalHeight)` of a
  /// grand-staff [layout] into an image.
  ///
  /// [GrandStaffPainter.paint] always draws every system, so the band is
  /// selected by translating the canvas up and letting the image bounds crop
  /// the rest — the same trick [_rasterizeBand] uses for the single-staff path,
  /// which additionally skips out-of-band systems outright.
  static Future<ui.Image> _rasterizeGroupBand({
    required GroupRasterLayout layout,
    required double topLogicalY,
    required double logicalHeight,
    required double pixelRatio,
    required Color background,
  }) async {
    final width = layout.logicalWidth;
    final height = math.max(1.0, logicalHeight);
    final ratio = _fitPixelRatio(pixelRatio, width, height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);

    // Opaque page background: a PDF page under a transparent PNG would show
    // through, and printers do not like transparency.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = background,
    );

    canvas.save();
    // Systems outside the band must not leak into it even when the recorder is
    // replayed onto a larger surface.
    canvas.clipRect(Rect.fromLTWH(0, 0, width, height));
    canvas.translate(0, -topLogicalY);
    layout.painter.paint(canvas, Size(width, topLogicalY + height));
    canvas.restore();

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        _pixelExtent(width, ratio),
        _pixelExtent(height, ratio),
      );
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
    final width = layout.logicalWidth;
    final height = math.max(1.0, logicalHeight);
    // `renderStaffToImage` puts a whole score in one image, so this path can
    // ask for an over-large texture too — the same guard applies.
    final ratio = _fitPixelRatio(pixelRatio, width, height);

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
        _pixelExtent(width, ratio),
        _pixelExtent(height, ratio),
      );
    } finally {
      picture.dispose();
    }
  }
}
