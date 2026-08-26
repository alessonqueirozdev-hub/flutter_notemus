// lib/flutter_notemus.dart
// Public entry point: the [MusicScore] widget and the package-wide exports.

/// Flutter Notemus — professional music notation rendering for Flutter.
///
/// This package provides a complete solution for rendering high-quality
/// music notation in Flutter apps, built on the SMuFL (Standard Music
/// Font Layout) specification using the Bravura font.
///
/// ## Quick Start
/// ```dart
/// import 'package:flutter_notemus/flutter_notemus.dart';
///
/// MusicScore(
///   staff: Staff(measures: [
///     Measure()
///       ..add(Note(pitch: Pitch(step: 'C', octave: 4), duration: Duration(DurationType.quarter)))
///   ]),
/// )
/// ```
///
/// ## Key classes
/// - [MusicScore]: The main Flutter widget to embed in your app
/// - [Staff]: Top-level container for music notation
/// - [Measure]: Container for musical elements within a bar
/// - [Note]: A pitched note with duration, articulations, and ornaments
/// - [Rest]: A rest (silence) with duration
/// - [Chord]: Multiple simultaneous notes
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'core/core.dart'; // Musical model types live in core/
import 'src/layout/layout_engine.dart';
import 'src/parsers/json_parser.dart';
import 'src/parsers/mei_parser.dart';
import 'src/parsers/musicxml_parser.dart';
import 'src/parsers/notation_format.dart';
import 'src/parsers/notation_parser.dart';
import 'src/rendering/staff_renderer.dart';
import 'src/rendering/staff_coordinate_system.dart';
import 'src/smufl/smufl_metadata_loader.dart';
import 'src/theme/music_score_theme.dart';

// Architecture: all music theory types live in core/
export 'core/core.dart';
export 'midi.dart';

// Public API exports
export 'src/theme/music_score_theme.dart';
export 'src/layout/layout_engine.dart';
export 'src/parsers/json_parser.dart';
export 'src/parsers/mei_parser.dart';
export 'src/parsers/musicxml_parser.dart';
export 'src/parsers/notation_format.dart';
export 'src/parsers/notation_parser.dart';
export 'src/smufl/glyph_categories.dart';
export 'src/smufl/smufl_metadata_loader.dart';
export 'src/rendering/staff_position_calculator.dart';
export 'src/rendering/staff_coordinate_system.dart';
export 'src/rendering/staff_renderer.dart';
// `LayoutEngine.accidentalDecisions` returns a Map<Note, AccidentalDisplay>, so
// the enum is part of the public surface and has to be exported with it.
export 'src/rendering/accidental_resolver.dart'
    show AccidentalDisplay, AccidentalResolver;

// Where sung text goes. Exported because it is the one number an embedding
// needs in order to draw anything of its own under a staff — a karaoke
// highlight, a chord grid, a second verse from outside the model — and because
// the placement stopped being a constant it could hard-code.
export 'src/rendering/lyric_layout.dart' show LyricLayout;
export 'src/rendering/renderers/base_glyph_renderer.dart';
// The text-font escape hatch. `MusicTextFont.use` is the ONLY way an embedding
// app can name the face this package draws non-SMuFL strings with — the
// built-in chain in `kMusicTextFontFallback` names four faces the package does
// not ship, and the headless export path has no `Theme` ancestor to rescue it,
// so without this a `ScoreRasterizer`/`PdfExporter` run on a bare host emits
// `.notdef` boxes (measured: 16 in one CMN page).
//
// It was reachable only through a convenience re-export buried in
// `music_score_theme.dart` (`export '../rendering/text_font.dart' show
// MusicTextFont, kMusicTextFontFallback;`), which is a THEME file — nothing
// tells a consumer to look there, and that `show` clause hides
// `MusicTextFallback`, the extension whose name the dartdoc of every text site
// in the library links to.
//
// No collision: `MusicTextFont` and `kMusicTextFontFallback` arrive here twice
// (directly and via `src/theme/music_score_theme.dart`) but they are the SAME
// declarations from the SAME library, which Dart merges rather than treating as
// ambiguous. `MusicTextFallback` is newly public and is declared nowhere else
// in `lib/`. Measured before: 26 exports, 0 of them naming
// `MusicTextFallback`.
export 'src/rendering/text_font.dart';
export 'src/rendering/jianpu/jianpu_pitch_mapper.dart';
export 'src/rendering/jianpu/jianpu_renderer.dart' show JianpuTheme;
export 'src/rendering/jianpu/jianpu_score.dart';
export 'src/rendering/gregorian/gregorian_renderer.dart'
    show GregorianTheme, ChantClef, ChantClefType, ChantClefChange;
export 'src/rendering/gregorian/chant_score.dart';
export 'src/rendering/gregorian/chant_playback.dart';
export 'src/rendering/gregorian/gabc_parser.dart' show GabcParser, GabcResult;
export 'src/layout/collision_detector.dart';
// Selection / hit-testing over a laid-out score (editor infrastructure).
export 'src/interaction/score_hit_tester.dart';
export 'src/widgets/grand_staff.dart' show GrandStaff, ScoreView;

// PDF export is a headline feature of 2.7.x, but until 2.7.1 `PdfExporter`,
// `ScoreRasterizer` and `GrandStaffPainter` were reachable only through
// `package:flutter_notemus/src/export/...`, which the `implementation_imports`
// lint flags and which semver does not cover. Measured before: 26 exports, 0 of
// which reached the export subtree. Exported through the existing
// `src/export/export.dart` barrel so the subtree keeps one entry point.
export 'src/export/export.dart';
// The painter that draws a multi-staff system. `ScoreRasterizer.rasterize`
// returns pages painted by it and `GrandStaff` builds one, so consumers writing
// their own `CustomPaint` need the type to be public.
export 'src/rendering/grand_staff_painter.dart' show GrandStaffPainter;

/// The main Flutter widget for rendering music notation.
///
/// [MusicScore] asynchronously loads SMuFL font metadata and then renders
/// the provided [Staff] using a [CustomPaint] canvas. It supports horizontal
/// and vertical scrolling out of the box and applies viewport culling so only
/// visible systems are repainted.
///
/// The result of the layout pass is memoized per (staff, viewport width,
/// staff space), so rebuilds that do not change any of those — a scroll, a
/// theme change, an ancestor rebuild — reuse the previous layout instead of
/// running the engine again.
///
/// Example:
/// ```dart
/// MusicScore(
///   staff: Staff(measures: [
///     Measure()
///       ..add(Note(
///         pitch: const Pitch(step: 'C', octave: 4),
///         duration: const Duration(DurationType.quarter),
///       )),
///   ]),
/// )
/// ```
class MusicScore extends StatefulWidget {
  /// The [Staff] containing all measures and musical elements to render.
  ///
  /// Layout results are cached per staff instance and measure/element counts.
  /// When editing a score, pass a **new** [Staff] instance (or add/remove
  /// elements) so the cache is invalidated; mutating a note in place inside the
  /// same [Staff] instance is not detected.
  final Staff staff;

  /// Visual theme controlling colors, line widths, and font sizes.
  ///
  /// Defaults to [MusicScoreTheme] with standard values.
  final MusicScoreTheme theme;

  /// Size of one staff space in logical pixels.
  ///
  /// A staff space is the distance between two adjacent staff lines.
  /// The default value of `12.0` produces a standard-size score.
  /// Increase this value to render a larger score, decrease for smaller.
  final double staffSpace;

  /// Enables automatic scale-down on narrow screens (useful for mobile web).
  ///
  /// When enabled, [staffSpace] is reduced proportionally below
  /// [responsiveBreakpointWidth], preserving readability while preventing
  /// cramped or clipped layouts.
  final bool enableResponsiveLayout;

  /// Viewport width (logical px) below which responsive scale-down starts.
  final double responsiveBreakpointWidth;

  /// Minimum scale factor applied to [staffSpace] in responsive mode.
  final double minResponsiveScale;

  /// Prevents vertical clipping in constrained containers by scaling the score down.
  ///
  /// When enabled and the available height is bounded, [MusicScore] performs a
  /// second layout pass using a reduced [staffSpace] so the full staff fits.
  final bool preventVerticalOverflow;

  /// Lower bound for automatic vertical fit scaling.
  ///
  /// Smaller values prioritize "always fit" behavior in very short containers,
  /// while larger values prioritize readability over guaranteed fit.
  final double minimumVerticalFitScale;

  const MusicScore({
    super.key,
    required this.staff,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.enableResponsiveLayout = true,
    this.responsiveBreakpointWidth = 640.0,
    this.minResponsiveScale = 0.72,
    this.preventVerticalOverflow = true,
    this.minimumVerticalFitScale = 0.4,
  });

  factory MusicScore.fromJson({
    Key? key,
    required String json,
    int staffIndex = 0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double staffSpace = 12.0,
  }) {
    return MusicScore(
      key: key,
      staff: JsonMusicParser.parseStaff(json, staffIndex: staffIndex),
      theme: theme,
      staffSpace: staffSpace,
    );
  }

  factory MusicScore.fromMusicXml({
    Key? key,
    required String musicXml,
    int partIndex = 0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double staffSpace = 12.0,
  }) {
    return MusicScore(
      key: key,
      staff: MusicXMLParser.parseMusicXML(musicXml, partIndex: partIndex),
      theme: theme,
      staffSpace: staffSpace,
    );
  }

  factory MusicScore.fromMei({
    Key? key,
    required String mei,
    int staffIndex = 0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double staffSpace = 12.0,
  }) {
    return MusicScore(
      key: key,
      staff: MEIParser.parseMEI(mei, staffIndex: staffIndex),
      theme: theme,
      staffSpace: staffSpace,
    );
  }

  factory MusicScore.fromSource({
    Key? key,
    required String source,
    NotationFormat? format,
    int partIndex = 0,
    int staffIndex = 0,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double staffSpace = 12.0,
  }) {
    return MusicScore(
      key: key,
      staff: NotationParser.parseStaff(
        source,
        format: format,
        partIndex: partIndex,
        staffIndex: staffIndex,
      ),
      theme: theme,
      staffSpace: staffSpace,
    );
  }

  @override
  State<MusicScore> createState() => _MusicScoreState();
}

class _MusicScoreState extends State<MusicScore> {
  /// Maximum number of memoized layout passes kept alive at once.
  ///
  /// Two entries cover the common case (first pass + adaptive second pass);
  /// two more absorb viewport resizes. Kept small because each entry retains a
  /// full [LayoutEngine] and its positioned elements.
  static const int _maxCachedLayouts = 4;

  late Future<void> _metadataFuture;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  late SmuflMetadata _metadata;

  /// Memoized layout passes, keyed by staff + viewport width + staff space.
  ///
  /// Without this cache the whole [LayoutEngine] runs inside
  /// `LayoutBuilder.builder`, i.e. on every build and twice whenever the
  /// adaptive second pass kicks in (~82 ms for 800 measures per pass).
  final Map<_LayoutCacheKey, _LayoutSnapshot> _layoutCache =
      <_LayoutCacheKey, _LayoutSnapshot>{};

  @override
  void initState() {
    super.initState();
    _metadata = SmuflMetadata();
    _metadataFuture = _metadata.load();
  }

  @override
  void didUpdateWidget(covariant MusicScore oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Anything that changes the geometry of the layout invalidates the cache.
    // The theme is deliberately absent: it only affects painting.
    if (!identical(oldWidget.staff, widget.staff) ||
        oldWidget.staffSpace != widget.staffSpace ||
        oldWidget.enableResponsiveLayout != widget.enableResponsiveLayout ||
        oldWidget.responsiveBreakpointWidth !=
            widget.responsiveBreakpointWidth ||
        oldWidget.minResponsiveScale != widget.minResponsiveScale ||
        oldWidget.preventVerticalOverflow != widget.preventVerticalOverflow ||
        oldWidget.minimumVerticalFitScale != widget.minimumVerticalFitScale) {
      _layoutCache.clear();
    }
  }

  @override
  void dispose() {
    _layoutCache.clear();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  /// Runs the layout engine for the given geometry, reusing a cached pass when
  /// one is available.
  ///
  /// [viewportWidth] is quantised to 0.5 px and [effectiveStaffSpace] to
  /// 0.01 px in the cache key so sub-pixel layout noise does not invalidate an
  /// otherwise identical layout. The engine itself still receives the exact
  /// values.
  _LayoutSnapshot _resolveLayout({
    required double viewportWidth,
    required double effectiveStaffSpace,
  }) {
    final key = _LayoutCacheKey(
      staffIdentity: identityHashCode(widget.staff),
      staffStructure: _staffStructureFingerprint(widget.staff),
      viewportWidthTicks: _quantize(viewportWidth, 2.0),
      staffSpaceTicks: _quantize(effectiveStaffSpace, 100.0),
    );

    final cached = _layoutCache[key];
    if (cached != null) {
      return cached;
    }

    final layoutEngine = LayoutEngine(
      widget.staff,
      availableWidth: viewportWidth,
      staffSpace: effectiveStaffSpace,
      metadata: _metadata,
    );
    final layoutResult = layoutEngine.layoutWithSignature();
    final snapshot = _LayoutSnapshot(
      engine: layoutEngine,
      result: layoutResult,
      // Height, like width, comes from the ENGINE, which knows how far the
      // music actually reaches above and below the staff. The widget's own
      // formula used a flat 8.5-staff-space margin, so a high ledger-line note
      // or a boxed rehearsal mark was silently cut off.
      totalHeight: math.max(
        layoutEngine.calculateTotalHeight(layoutResult.elements),
        _calculateTotalHeight(layoutResult.elements, effectiveStaffSpace),
      ),
      // Ask the ENGINE for the width: it owns the element metrics, so a single
      // implementation decides both what the layout consumes and how wide the
      // canvas must be. Two independent width formulas is exactly the defect
      // (F-12) that let a dense bar run off a canvas sized by the other one.
      contentWidth: math.max(
        layoutEngine.contentWidth(layoutResult.elements),
        _calculateContentWidth(layoutResult.elements, effectiveStaffSpace),
      ),
    );

    if (_layoutCache.length >= _maxCachedLayouts) {
      _layoutCache.clear();
    }
    _layoutCache[key] = snapshot;
    return snapshot;
  }

  /// Quantises [value] into integer steps of `1 / ticksPerUnit`.
  ///
  /// Non-finite values collapse to 0 so they can never poison the key.
  static int _quantize(double value, double ticksPerUnit) {
    if (!value.isFinite) return 0;
    return (value * ticksPerUnit).round();
  }

  /// Cheap structural fingerprint of a [Staff] (measure and element counts).
  ///
  /// Catches the common in-place edit — adding or removing measures/elements on
  /// the same [Staff] instance — which identity alone would miss.
  static int _staffStructureFingerprint(Staff staff) {
    int hash = staff.measures.length;
    for (final measure in staff.measures) {
      hash = Object.hash(hash, measure.elements.length);
    }
    return Object.hash(hash, staff.lineCount);
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
            child: Text('Failed to load metadata: ${snapshot.error}'),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final viewportWidth = _resolveViewportWidth(context, constraints);
            var effectiveStaffSpace = _resolveEffectiveStaffSpace(
              viewportWidth,
            );

            var layout = _resolveLayout(
              viewportWidth: viewportWidth,
              effectiveStaffSpace: effectiveStaffSpace,
            );

            if (layout.result.elements.isEmpty) {
              return const Center(child: Text('Empty score'));
            }

            var totalHeight = layout.totalHeight;
            var contentWidth = layout.contentWidth;

            final hasBoundedHeight =
                constraints.hasBoundedHeight &&
                constraints.maxHeight.isFinite &&
                constraints.maxHeight > 0;
            if (hasBoundedHeight) {
              final adaptiveScale = _resolveAdaptiveContainerScale(
                viewportWidth: viewportWidth,
                maxHeight: constraints.maxHeight,
                totalHeight: totalHeight,
                contentWidth: contentWidth,
              );

              if ((adaptiveScale - 1.0).abs() > 0.02) {
                final nextStaffSpace = effectiveStaffSpace * adaptiveScale;
                if ((nextStaffSpace - effectiveStaffSpace).abs() > 0.01) {
                  effectiveStaffSpace = nextStaffSpace;
                }
                // The adaptive second pass goes through the same cache, so a
                // stable container only pays for it once.
                layout = _resolveLayout(
                  viewportWidth: viewportWidth,
                  effectiveStaffSpace: effectiveStaffSpace,
                );

                if (layout.result.elements.isEmpty) {
                  return const Center(child: Text('Empty score'));
                }

                totalHeight = layout.totalHeight;
                contentWidth = layout.contentWidth;
              }
            }

            final viewportSize = Size(
              viewportWidth,
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : totalHeight,
            );
            final centeredCanvasHeight = math.max(
              totalHeight,
              viewportSize.height,
            );
            // The canvas must be at least as wide as the content, otherwise the
            // horizontal SingleChildScrollView has nothing to scroll and the
            // overflowing part of the music is clipped away for good.
            final canvasWidth = math.max(contentWidth, viewportWidth);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                controller: _verticalController,
                child: SizedBox(
                  width: canvasWidth,
                  height: centeredCanvasHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(canvasWidth, totalHeight),
                        painter: MusicScorePainter(
                          positionedElements: layout.result.elements,
                          positionedElementsSignature: layout.result.signature,
                          metadata: _metadata,
                          theme: widget.theme,
                          staffSpace: effectiveStaffSpace,
                          layoutEngine: layout.engine,
                          topInset: layout.engine
                              .contentTopOverflow(layout.result.elements),
                          viewportSize: viewportSize,
                          horizontalController: _horizontalController,
                          verticalController: _verticalController,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _resolveViewportWidth(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    if (constraints.hasBoundedWidth &&
        constraints.maxWidth.isFinite &&
        constraints.maxWidth > 0) {
      return constraints.maxWidth;
    }
    return MediaQuery.sizeOf(context).width;
  }

  double _resolveEffectiveStaffSpace(double viewportWidth) {
    if (!widget.enableResponsiveLayout ||
        !viewportWidth.isFinite ||
        viewportWidth <= 0 ||
        viewportWidth >= widget.responsiveBreakpointWidth) {
      return widget.staffSpace;
    }

    final scale = (viewportWidth / widget.responsiveBreakpointWidth).clamp(
      widget.minResponsiveScale,
      1.0,
    );
    return widget.staffSpace * scale;
  }

  double _resolveAdaptiveContainerScale({
    required double viewportWidth,
    required double maxHeight,
    required double totalHeight,
    required double contentWidth,
  }) {
    if (!maxHeight.isFinite ||
        maxHeight <= 0 ||
        !totalHeight.isFinite ||
        totalHeight <= 0 ||
        !contentWidth.isFinite ||
        contentWidth <= 0) {
      return 1.0;
    }

    final widthFitScale = viewportWidth / contentWidth;
    final heightFitScale = maxHeight / totalHeight;
    final fitScale = math.min(widthFitScale, heightFitScale);

    if (fitScale < 1.0) {
      if (!widget.preventVerticalOverflow && heightFitScale < 1.0) {
        return 1.0;
      }
      return fitScale.clamp(widget.minimumVerticalFitScale, 1.0);
    }

    final desiredWidth =
        viewportWidth * _resolveDesiredWidthCoverage(viewportWidth);
    final desiredHeight =
        maxHeight * _resolveDesiredHeightCoverage(viewportWidth);
    final widthGrowthScale = desiredWidth / contentWidth;
    final heightGrowthScale = desiredHeight / totalHeight;
    final targetScale = math.min(widthGrowthScale, heightGrowthScale);
    if (targetScale <= 1.0) {
      return 1.0;
    }

    final maximumScale = _resolveMaximumAdaptiveScale(viewportWidth);
    final upperBound = math.min(maximumScale, fitScale);
    return targetScale.clamp(1.0, upperBound);
  }

  double _resolveMaximumAdaptiveScale(double viewportWidth) {
    if (viewportWidth >= 1200) {
      return 1.8;
    }
    if (viewportWidth >= 900) {
      return 1.6;
    }
    if (viewportWidth >= widget.responsiveBreakpointWidth) {
      return 1.42;
    }
    return 1.12;
  }

  double _resolveDesiredWidthCoverage(double viewportWidth) {
    if (viewportWidth >= 1200) {
      return 0.9;
    }
    if (viewportWidth >= 900) {
      return 0.88;
    }
    if (viewportWidth >= widget.responsiveBreakpointWidth) {
      return 0.84;
    }
    return 0.96;
  }

  double _resolveDesiredHeightCoverage(double viewportWidth) {
    if (viewportWidth >= 1200) {
      return 0.82;
    }
    if (viewportWidth >= 900) {
      return 0.78;
    }
    if (viewportWidth >= widget.responsiveBreakpointWidth) {
      return 0.74;
    }
    return 0.68;
  }

  /// Width, in logical pixels, needed to show the widest system in full.
  ///
  /// [PositionedElement.position] is the *origin* of a glyph, so the width of
  /// the rightmost element has to be added on top of the raw span, plus a right
  /// margin — otherwise the last notehead or barline sits exactly on the canvas
  /// edge (or beyond it) and gets clipped.
  double _calculateContentWidth(
    List<PositionedElement> elements,
    double effectiveStaffSpace,
  ) {
    if (elements.isEmpty) {
      return 0.0;
    }

    final systemBounds = <int, ({double minX, double maxX, double endWidth})>{};
    for (final positioned in elements) {
      final x = positioned.position.dx;
      final width = _estimateElementWidth(
        positioned.element,
        effectiveStaffSpace,
      );
      final current = systemBounds[positioned.system];
      if (current == null) {
        systemBounds[positioned.system] = (minX: x, maxX: x, endWidth: width);
        continue;
      }

      systemBounds[positioned.system] = (
        minX: x < current.minX ? x : current.minX,
        maxX: x > current.maxX ? x : current.maxX,
        // Track the width of the element that currently ends the system.
        endWidth: x > current.maxX ? width : current.endWidth,
      );
    }

    double maxSpan = 0.0;
    for (final bounds in systemBounds.values) {
      final span = bounds.maxX - bounds.minX + bounds.endWidth;
      if (span > maxSpan) {
        maxSpan = span;
      }
    }

    return maxSpan + (effectiveStaffSpace * 2.4);
  }

  /// Conservative advance-width estimate for [element], in logical pixels.
  ///
  /// Deliberately self-contained (no SMuFL lookup): it only has to be a safe
  /// right-hand allowance for the canvas width, not an engraving-grade metric.
  static double _estimateElementWidth(
    MusicalElement element,
    double effectiveStaffSpace,
  ) {
    if (element is Clef) {
      return effectiveStaffSpace * 3.0;
    }
    if (element is KeySignature) {
      final accidentals = element.count.abs();
      final cancelled = element.previousCount?.abs() ?? 0;
      return effectiveStaffSpace * (0.4 + (accidentals + cancelled) * 1.2);
    }
    if (element is TimeSignature) {
      return effectiveStaffSpace * 2.2;
    }
    if (element is Barline) {
      return effectiveStaffSpace * 1.2;
    }
    if (element is Chord || element is Note || element is Rest) {
      return effectiveStaffSpace * 1.8;
    }
    return effectiveStaffSpace * 1.4;
  }

  double _calculateTotalHeight(
    List<PositionedElement> elements,
    double effectiveStaffSpace,
  ) {
    if (elements.isEmpty) return 200;

    int maxSystem = 0;
    for (final element in elements) {
      if (element.system > maxSystem) {
        maxSystem = element.system;
      }
    }

    final systemHeight = effectiveStaffSpace * 10;
    // Larger vertical margins prevent clipping of tempo marks and upper ornaments.
    final margins = effectiveStaffSpace * 8.5;

    return margins + ((maxSystem + 1) * systemHeight);
  }
}

/// Cache key for a memoized layout pass.
///
/// Widths are stored quantised (see `_MusicScoreState._quantize`) so that
/// sub-pixel jitter in the incoming constraints does not defeat the cache.
@immutable
class _LayoutCacheKey {
  final int staffIdentity;
  final int staffStructure;
  final int viewportWidthTicks;
  final int staffSpaceTicks;

  const _LayoutCacheKey({
    required this.staffIdentity,
    required this.staffStructure,
    required this.viewportWidthTicks,
    required this.staffSpaceTicks,
  });

  @override
  bool operator ==(Object other) =>
      other is _LayoutCacheKey &&
      other.staffIdentity == staffIdentity &&
      other.staffStructure == staffStructure &&
      other.viewportWidthTicks == viewportWidthTicks &&
      other.staffSpaceTicks == staffSpaceTicks;

  @override
  int get hashCode => Object.hash(
    staffIdentity,
    staffStructure,
    viewportWidthTicks,
    staffSpaceTicks,
  );
}

/// Everything one layout pass produces, kept together so it can be cached and
/// reused as a unit.
@immutable
class _LayoutSnapshot {
  final LayoutEngine engine;
  final LayoutResult result;
  final double totalHeight;
  final double contentWidth;

  const _LayoutSnapshot({
    required this.engine,
    required this.result,
    required this.totalHeight,
    required this.contentWidth,
  });
}

/// Custom [CustomPainter] that renders positioned music notation elements.
///
/// Optimised for large scores through viewport culling: only systems that
/// intersect the current scroll viewport are painted. A [RepaintBoundary]
/// wraps this painter so that scrolling does not trigger full repaints.
///
/// Elements are grouped by system once, in the constructor, and the per-system
/// [StaffRenderer] instances are cached for the lifetime of the painter — both
/// used to happen inside `paint`, i.e. on every scrolled pixel.
///
/// This class is used internally by [MusicScore] and is exposed publicly so
/// that advanced users can integrate it into their own [CustomPaint] widgets.
class MusicScorePainter extends CustomPainter {
  /// Pre-computed list of elements with absolute canvas positions.
  final List<PositionedElement> positionedElements;

  /// Deterministic signature of [positionedElements] for cheap repaint checks.
  final int positionedElementsSignature;

  /// SMuFL metadata providing glyph bounding boxes and advance widths.
  final SmuflMetadata metadata;

  /// Extra headroom, in pixels, reserved above the first staff line for music
  /// that reaches higher than the default margin — high ledger-line notes,
  /// boxed rehearsal marks, tempo text. The whole drawing is shifted down by
  /// this much so none of it is cut off.
  ///
  /// Comes from `LayoutEngine.contentTopOverflow`; the widget adds the same
  /// value to the canvas height.
  final double topInset;

  /// Visual theme applied during rendering.
  final MusicScoreTheme theme;

  /// Staff space in logical pixels (same value passed to [LayoutEngine]).
  final double staffSpace;

  /// Optional reference to the [LayoutEngine] for beam-group data.
  final LayoutEngine? layoutEngine;

  /// Current viewport size, used to determine which systems are visible.
  final Size viewportSize;

  /// Horizontal scroll controller used to invalidate paint on scroll.
  final ScrollController horizontalController;

  /// Vertical scroll controller used to compute visible systems on scroll.
  final ScrollController verticalController;

  /// [positionedElements] grouped by system index, computed once.
  final Map<int, List<PositionedElement>> _systemGroups;

  /// Highest system index present in [positionedElements].
  ///
  /// Used to clamp the visible range: a hard-coded upper bound would blank out
  /// the score entirely once the reader scrolled past it.
  final int _maxSystemIndex;

  /// Per-system renderers, created on demand and reused across frames.
  ///
  /// Each [StaffRenderer] is bound to a staff baseline, hence one per system.
  /// [StaffRenderer.renderStaff] resets its own per-pass state, so reusing an
  /// instance between frames is safe.
  final Map<int, StaffRenderer> _rendererCache = <int, StaffRenderer>{};

  MusicScorePainter({
    required this.positionedElements,
    int? positionedElementsSignature,
    required this.metadata,
    this.topInset = 0.0,
    required this.theme,
    required this.staffSpace,
    this.layoutEngine,
    required this.viewportSize,
    required this.horizontalController,
    required this.verticalController,
  }) : positionedElementsSignature =
           positionedElementsSignature ??
           PositionedElement.computeSignature(positionedElements),
       _systemGroups = _groupBySystem(positionedElements),
       _maxSystemIndex = _resolveMaxSystem(positionedElements),
       super(
         repaint: Listenable.merge(<Listenable>[
           horizontalController,
           verticalController,
         ]),
       );

  /// Groups [elements] by [PositionedElement.system], preserving their order.
  static Map<int, List<PositionedElement>> _groupBySystem(
    List<PositionedElement> elements,
  ) {
    final groups = <int, List<PositionedElement>>{};
    for (final element in elements) {
      groups
          .putIfAbsent(element.system, () => <PositionedElement>[])
          .add(element);
    }
    return groups;
  }

  /// Highest system index in [elements] (0 when the list is empty).
  static int _resolveMaxSystem(List<PositionedElement> elements) {
    int maxSystem = 0;
    for (final element in elements) {
      if (element.system > maxSystem) {
        maxSystem = element.system;
      }
    }
    return maxSystem;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded || positionedElements.isEmpty) return;

    // Optimisation: clip the canvas to its own bounds. `size` is the full
    // canvas (content width, not the viewport width), so nothing that should be
    // reachable by scrolling is cut off here.
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Shift everything down by the reserved headroom so nothing above the staff
    // is cut off (see `LayoutEngine.contentTopOverflow`).
    if (topInset > 0) canvas.translate(0, topInset);

    // Optimisation: only the systems intersecting the viewport are painted.
    final systemHeight = staffSpace * 10;
    final visibleSystemRange = _calculateVisibleSystems(systemHeight);

    for (final systemIndex in visibleSystemRange) {
      final elements = _systemGroups[systemIndex];
      if (elements == null || elements.isEmpty) {
        continue;
      }

      final renderer = _rendererCache.putIfAbsent(systemIndex, () {
        // Keep the renderer baseline aligned with LayoutCursor.currentY so
        // noteheads, stems and advanced beams share the same vertical
        // reference.
        final systemY = (systemIndex * staffSpace * 10) + (staffSpace * 5.0);
        return StaffRenderer(
          coordinates: StaffCoordinateSystem(
            staffSpace: staffSpace,
            staffBaseline: Offset(0, systemY),
          ),
          metadata: metadata,
          theme: theme,
        );
      });

      renderer.renderStaff(canvas, elements, size, layoutEngine: layoutEngine);
    }
  }

  /// Computes which systems are visible in the current viewport.
  ///
  /// Returns the set of system indices intersecting the viewport, with one
  /// extra system above and below so scrolling stays smooth.
  Set<int> _calculateVisibleSystems(double systemHeight) {
    // Guard against division by zero and non-finite values.
    if (systemHeight <= 0 || !systemHeight.isFinite) {
      // Fallback: render system 0 only.
      return {0};
    }

    if (!viewportSize.height.isFinite || viewportSize.height <= 0) {
      // Fallback: render system 0 only.
      return {0};
    }

    final scrollOffsetY = verticalController.hasClients
        ? verticalController.offset
        : 0.0;

    if (!scrollOffsetY.isFinite) {
      // Fallback: render system 0 only.
      return {0};
    }

    // Viewport Y range, padded by one system on each side.
    final margin = systemHeight;
    final viewportTop = scrollOffsetY - margin;
    final viewportBottom = scrollOffsetY + viewportSize.height + margin;

    // Compute the visible systems, guarding against non-finite values.
    final firstSystemRaw = (viewportTop / systemHeight).floor();
    final lastSystemRaw = (viewportBottom / systemHeight).ceil();

    if (!firstSystemRaw.isFinite || !lastSystemRaw.isFinite) {
      return {0};
    }

    // Clamp to the systems that actually exist. A fixed upper bound (this used
    // to be 999) blanks the score out completely past that system.
    final firstSystem = firstSystemRaw.clamp(0, _maxSystemIndex);
    final lastSystem = lastSystemRaw.clamp(0, _maxSystemIndex);

    if (lastSystem < firstSystem) {
      return {0};
    }

    // Return the range as an ordered set.
    return Set<int>.from(
      List<int>.generate(lastSystem - firstSystem + 1, (i) => firstSystem + i),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! MusicScorePainter) return true;

    // Fast path: the very same element list (memoized layout) cannot have moved,
    // so only the painting configuration can force a repaint. The *structural*
    // stability of the signature — two layouts of the same [Staff] hashing
    // equal — is the layout engine's responsibility (see
    // [PositionedElement.computeSignature]); this shortcut just avoids
    // depending on it when the lists are literally identical.
    final contentChanged =
        !identical(oldDelegate.positionedElements, positionedElements) &&
        oldDelegate.positionedElementsSignature != positionedElementsSignature;

    // Repaint when viewport, styles, or positioned content signature changes.
    return contentChanged ||
        oldDelegate.theme != theme ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.topInset != topInset ||
        oldDelegate.layoutEngine != layoutEngine ||
        oldDelegate.horizontalController != horizontalController ||
        oldDelegate.verticalController != verticalController ||
        oldDelegate.viewportSize != viewportSize;
  }
}
