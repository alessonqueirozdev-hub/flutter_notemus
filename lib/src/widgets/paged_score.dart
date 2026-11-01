// lib/src/widgets/paged_score.dart
//
// A score as a sequence of paper pages: the systems GrandStaff lays out,
// cut into pages on system boundaries and shown one page at a time, with
// zoom, taps, the playback cursor and a page that turns with the cursor.
//
// Ported from @zamvar's fork (`codex/note-tap`, `PagedScoreView`). The fork
// built a separate cached layout and painted each page through its own
// region renderer; here a page is a clipped band of the one GrandStaffPainter
// the screen and the PDF exporter already share, cut with the same
// arithmetic as `ScoreRasterizer.renderGroupPages`.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../interaction/score_taps.dart';
import '../playback/playback_plan.dart';
import '../rendering/grand_staff_painter.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';
import 'grand_staff.dart' show GrandStaffPlayheadPainter;

/// Page navigation and zoom for a [PagedScoreView].
class PagedScoreController extends ChangeNotifier {
  /// The [PageView] controller; jump to a page with [jumpToPage].
  final PageController pageController = PageController();

  final Map<int, TransformationController> _zoom = {};

  int _page = 0;
  int _pageCount = 0;

  /// Zero-based page on screen.
  int get currentPage => _page;

  /// Number of pages the score was cut into.
  int get pageCount => _pageCount;

  /// The zoom transform of [page], kept per page so turning a page does not
  /// lose the zoom of the one you come back to.
  TransformationController transformationFor(int page) =>
      _zoom.putIfAbsent(page, () {
        final controller = TransformationController();
        controller.addListener(() {
          if (page == _page) notifyListeners();
        });
        return controller;
      });

  /// Zoom of the page on screen, 1.0 when it fits.
  double get currentScale =>
      transformationFor(_page).value.getMaxScaleOnAxis();

  /// Multiplies the current page's zoom by [factor], within 1x to 4x.
  void zoomBy(double factor) {
    final next = (currentScale * factor).clamp(1.0, 4.0).toDouble();
    transformationFor(_page).value =
        Matrix4.diagonal3Values(next, next, 1.0);
    notifyListeners();
  }

  /// Back to the whole page.
  void resetZoom() {
    transformationFor(_page).value = Matrix4.identity();
    notifyListeners();
  }

  /// Shows [page] (clamped to the score).
  void jumpToPage(int page) {
    if (_pageCount == 0 || !pageController.hasClients) return;
    pageController.jumpToPage(page.clamp(0, _pageCount - 1));
  }

  void previousPage() => jumpToPage(_page - 1);
  void nextPage() => jumpToPage(_page + 1);

  void _setPageCount(int count) {
    if (_pageCount == count) return;
    _pageCount = count;
    if (_page >= count) _page = math.max(0, count - 1);
    notifyListeners();
  }

  void _setPage(int page) {
    if (_page == page) return;
    _page = page;
    notifyListeners();
  }

  @override
  void dispose() {
    pageController.dispose();
    for (final controller in _zoom.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Shows a [Score] as paper pages, one at a time, swiped left and right.
///
/// The systems are the ones [GrandStaff] lays out at the page's inner width;
/// a page holds as many whole systems as fit its height, and the first page
/// opens with the score's title, subtitle and composer. Pinch or
/// [PagedScoreController.zoomBy] to zoom a page; taps and the playback cursor
/// work as on [GrandStaff], and with [followPlayback] the page turns to keep
/// the cursor in view.
///
/// ```dart
/// PagedScoreView(score: score, playbackPosition: position);
/// ```
class PagedScoreView extends StatefulWidget {
  final Score score;
  final MusicScoreTheme theme;

  /// Staff space in page points (A4 is 595 x 842).
  final double staffSpace;

  /// Baseline distance between the staves of a system; see [GrandStaff].
  final double? staffGap;

  /// Page size in points; A4 portrait by default. The page is scaled to fit
  /// the space the widget is given.
  final Size pageSize;

  /// Blank margin on every side of a page, in points.
  final double pageMargin;

  /// See [GrandStaff.onNoteTap].
  final ValueChanged<ScoreNoteTap>? onNoteTap;

  /// See [GrandStaff.onMeasureTap].
  final ValueChanged<ScoreMeasureTap>? onMeasureTap;

  /// See [GrandStaff.playbackPosition].
  final ValueListenable<PlaybackPosition?>? playbackPosition;

  /// Turn the page when the playback cursor moves onto another one.
  final bool followPlayback;

  /// Page navigation and zoom; one is made (and disposed) when omitted.
  final PagedScoreController? controller;

  const PagedScoreView({
    super.key,
    required this.score,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 7.0,
    this.staffGap,
    this.pageSize = const Size(595, 842),
    this.pageMargin = 40.0,
    this.onNoteTap,
    this.onMeasureTap,
    this.playbackPosition,
    this.followPlayback = true,
    this.controller,
  })  : assert(pageMargin >= 0),
        assert(staffSpace > 0);

  @override
  State<PagedScoreView> createState() => _PagedScoreViewState();
}

/// One page: a band of the shared painter.
typedef _Page = ({int firstSystem, int systemCount, double top, double height});

class _PagedScoreViewState extends State<PagedScoreView> {
  late final SmuflMetadata _metadata = SmuflMetadata();
  late final Future<void> _metadataFuture = _metadata.load();
  late PagedScoreController _controller;
  bool _ownsController = false;

  GrandStaffPainter? _painter;
  List<_Page> _pages = const [];
  Object? _painterKey;

  @override
  void initState() {
    super.initState();
    _adoptController();
    widget.playbackPosition?.addListener(_followCursor);
  }

  void _adoptController() {
    _controller = widget.controller ?? PagedScoreController();
    _ownsController = widget.controller == null;
  }

  @override
  void didUpdateWidget(covariant PagedScoreView old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      if (_ownsController) _controller.dispose();
      _adoptController();
      // A new controller starts at 0 pages, and an unchanged layout would
      // never tell it otherwise: its navigation stayed a no-op.
      final count = _pages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller._setPageCount(count);
        _controller._setPage(
            _controller.pageController.hasClients
                ? (_controller.pageController.page ?? 0).round()
                : 0);
        _followCursor();
      });
    }
    if (!old.followPlayback && widget.followPlayback) {
      // Turned on with playback paused on another page: go there now, not
      // at the next tick that may never come.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _followCursor();
      });
    }
    if (!identical(old.playbackPosition, widget.playbackPosition)) {
      old.playbackPosition?.removeListener(_followCursor);
      widget.playbackPosition?.addListener(_followCursor);
      // A listener hears the next change, not the current value: a notifier
      // arriving with a position already set (playback paused) was never
      // followed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _followCursor();
      });
    }
  }

  @override
  void dispose() {
    widget.playbackPosition?.removeListener(_followCursor);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  double get _headerHeight {
    final s = widget.score;
    final lines = [s.title, s.subtitle, s.composer]
        .where((t) => t != null && t.trim().isNotEmpty)
        .length;
    return lines == 0 ? 0.0 : widget.staffSpace * (3.5 + 2.2 * lines);
  }

  /// The painter and pages for the current inputs, rebuilt only when they
  /// change.
  void _ensureLayout() {
    final key = Object.hash(
      // Content, not just the instance: an edit made in place was never laid
      // out again when keyed on the Score alone.
      identityHashCode(widget.score),
      staffGroupsSignature(widget.score.staffGroups),
      widget.pageSize,
      widget.pageMargin,
      widget.staffSpace,
      widget.staffGap,
      widget.theme,
    );
    if (_painter != null && key == _painterKey) return;
    final painter = GrandStaffPainter(
      groups: widget.score.staffGroups,
      staffSpace: widget.staffSpace,
      metadata: _metadata,
      theme: widget.theme,
      availableWidth: widget.pageSize.width - 2 * widget.pageMargin,
      staffGap: widget.staffGap,
    );
    _painter = painter;
    _painterKey = key;
    _pages = painter.pages(
      maxHeight: widget.pageSize.height - 2 * widget.pageMargin,
      firstPageReserve: _headerHeight,
    );
    final count = _pages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller._setPageCount(count);
      // A position set before the pages existed found no painter to place
      // it; without this the view stayed on page 0 until the next tick.
      _followCursor();
    });
  }

  /// Turns to the page holding the playback cursor's bar.
  void _followCursor() {
    if (!widget.followPlayback) return;
    final position = widget.playbackPosition?.value;
    final painter = _painter;
    if (position == null || painter == null) return;
    final system = painter.systemOfMeasure(position.measureIndex);
    if (system == null) return;
    final page = pageOfSystem(_pages, system);
    if (page != null && page != _controller.currentPage) {
      _controller.jumpToPage(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Failed to load metadata: ${snapshot.error}'));
        }
        if (widget.score.staffGroups.every((g) => g.staves.isEmpty)) {
          // No pages now: drop the old layout and tell the controller, which
          // otherwise kept reporting the pages of the score before it was
          // emptied.
          _painter = null;
          _painterKey = null;
          _pages = const [];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _controller._setPageCount(0);
          });
          return const SizedBox.shrink();
        }
        _ensureLayout();
        return LayoutBuilder(builder: (context, constraints) {
          final page = widget.pageSize;
          // Unbounded (a Column child without Expanded, a scroll view): one
          // page and its gutter. The PageView is held to this size below; it
          // used to get the unbounded constraint itself and fail layout.
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : page.width + 24;
          final height = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : page.height + 24;
          final scale = math.max(
            0.01,
            math.min((width - 24) / page.width, (height - 24) / page.height),
          );
          return SizedBox(
            width: width,
            height: height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => PageView.builder(
                controller: _controller.pageController,
                itemCount: _pages.length,
                // Zoomed in, a drag pans the page instead of turning it.
                physics: _controller.currentScale > 1.01
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: _controller._setPage,
                itemBuilder: (context, index) => Center(
                  child: SizedBox(
                    width: page.width * scale,
                    height: page.height * scale,
                    child: InteractiveViewer(
                      transformationController:
                          _controller.transformationFor(index),
                      minScale: 1.0,
                      maxScale: 4.0,
                      panEnabled: _controller.currentScale > 1.01,
                      clipBehavior: Clip.hardEdge,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _PageSheet(
                          key: ValueKey(index),
                          view: widget,
                          painter: _painter!,
                          page: _pages[index],
                          headerHeight: index == 0 ? _headerHeight : 0.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

/// The index of the page among [pages] that holds [system], or null.
int? pageOfSystem(
  List<({int firstSystem, int systemCount, double top, double height})> pages,
  int system,
) {
  for (var i = 0; i < pages.length; i++) {
    final p = pages[i];
    if (system >= p.firstSystem && system < p.firstSystem + p.systemCount) {
      return i;
    }
  }
  return null;
}

/// One sheet of paper: margin, optional title block, and the page's band of
/// the shared painter, with taps and the cursor mapped into that band.
class _PageSheet extends StatelessWidget {
  const _PageSheet({
    super.key,
    required this.view,
    required this.painter,
    required this.page,
    required this.headerHeight,
  });

  final PagedScoreView view;
  final GrandStaffPainter painter;
  final _Page page;
  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    final size = view.pageSize;
    final margin = view.pageMargin;
    final bandWidth = math.max(painter.contentWidth, size.width - 2 * margin);
    // Painter canvas y of the band's top: the band shows painter rows
    // [page.top, page.top + page.height).
    final shift = Offset(0, -page.top);

    Widget band = ClipRect(
      child: SizedBox(
        width: bandWidth,
        height: page.height,
        child: Stack(
          children: [
            Transform.translate(
              offset: shift,
              child: CustomPaint(
                size: Size(bandWidth, painter.totalHeight),
                painter: painter,
              ),
            ),
            if (view.playbackPosition != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: Transform.translate(
                      offset: shift,
                      child: CustomPaint(
                        size: Size(bandWidth, painter.totalHeight),
                        painter: GrandStaffPlayheadPainter(
                          position: view.playbackPosition!,
                          layout: painter,
                          color: view.theme.playheadColor ??
                              view.theme.noteheadColor.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final onNoteTap = view.onNoteTap;
    final onMeasureTap = view.onMeasureTap;
    if (onNoteTap != null || onMeasureTap != null) {
      band = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final point = details.localPosition - shift;
          if (onMeasureTap != null) {
            final bar = painter.measureTapAt(point,
                globalPosition: details.globalPosition);
            if (bar != null) onMeasureTap(bar);
          }
          if (onNoteTap != null) {
            final note = painter.noteTapAt(point,
                globalPosition: details.globalPosition);
            if (note != null) onNoteTap(note);
          }
        },
        child: band,
      );
    }

    return Container(
      width: size.width,
      height: size.height,
      color: const Color(0xFFFFFFFF),
      padding: EdgeInsets.all(margin),
      alignment: Alignment.topLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // Not stretch: a FittedBox gives its child unbounded width.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (headerHeight > 0)
              SizedBox(
                width: bandWidth,
                height: headerHeight,
                child: _TitleBlock(
                  score: view.score,
                  staffSpace: view.staffSpace,
                  theme: view.theme,
                ),
              ),
            band,
          ],
        ),
      ),
    );
  }
}

/// Title, subtitle and composer at the head of the first page.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.score,
    required this.staffSpace,
    required this.theme,
  });

  final Score score;
  final double staffSpace;
  final MusicScoreTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = theme.textColor ?? theme.staffLineColor;
    final base = TextStyle(color: color, height: 1.2);
    String? clean(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
    final title = clean(score.title);
    final subtitle = clean(score.subtitle);
    final composer = clean(score.composer);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Text(title,
              textAlign: TextAlign.center,
              style: base.copyWith(
                  fontSize: staffSpace * 2.4, fontWeight: FontWeight.w600)),
        if (subtitle != null)
          Text(subtitle,
              textAlign: TextAlign.center,
              style: base.copyWith(fontSize: staffSpace * 1.5)),
        if (composer != null)
          Text(composer,
              textAlign: TextAlign.right,
              style: base.copyWith(fontSize: staffSpace * 1.4)),
      ],
    );
  }
}
