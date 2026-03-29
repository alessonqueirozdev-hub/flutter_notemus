// lib/flutter_notemus.dart
// Corrected implementation: Widget principal with all as melhorias

/// Flutter Notemus — professional music notetion rendering for Flutter.
///
/// This package provides a complete solution for rendering high-quality
/// music notetion in Flutter apps, built on the SMuFL (Standard Music
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
/// ## Key Classs
/// - [MusicScore]: The main Flutter widget to embed in your app
/// - [Staff]: Top-level container for music notetion
/// - [Measure]: Container for musical elements within a bar
/// - [Note]: A pitched note with duration, articulations, and ornaments
/// - [Rest]: A rest (silence) with duration
/// - [Chord]: Multiple simultaneous notes
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'core/core.dart'; // 🆕 Usar tipos do core
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

// 🆕 New ARQUITETURA - Toda teoria musical in core/
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
export 'src/rendering/renderers/base_glyph_renderer.dart';
export 'src/layout/collision_detector.dart';

/// The main Flutter widget for rendering music notetion.
///
/// [MusicScore] asynchronously loads SMuFL font metadata and then renders
/// the provided [Staff] using a [CustomPaint] canvas. It supports horizontal
/// and vertical scrolling out of the box and applies viewport culling so only
/// visible systems are repainted.
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
  late Future<void> _metadataFuture;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  late SmuflMetadata _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = SmuflMetadata();
    _metadataFuture = _metadata.load();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
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

            var layoutEngine = LayoutEngine(
              widget.staff,
              availableWidth: viewportWidth,
              staffSpace: effectiveStaffSpace,
              metadata: _metadata,
            );

            var layoutResult = layoutEngine.layoutWithSignature();
            var positionedElements = layoutResult.elements;

            if (positionedElements.isEmpty) {
              return const Center(child: Text('Empty score'));
            }

            var totalHeight = _calculateTotalHeight(
              positionedElements,
              effectiveStaffSpace,
            );
            var contentWidth = _calculateContentWidth(
              positionedElements,
              effectiveStaffSpace,
            );

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
                layoutEngine = LayoutEngine(
                  widget.staff,
                  availableWidth: viewportWidth,
                  staffSpace: effectiveStaffSpace,
                  metadata: _metadata,
                );
                layoutResult = layoutEngine.layoutWithSignature();
                positionedElements = layoutResult.elements;

                if (positionedElements.isEmpty) {
                  return const Center(child: Text('Empty score'));
                }

                totalHeight = _calculateTotalHeight(
                  positionedElements,
                  effectiveStaffSpace,
                );
                contentWidth = _calculateContentWidth(
                  positionedElements,
                  effectiveStaffSpace,
                );
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

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                controller: _verticalController,
                child: SizedBox(
                  width: viewportWidth,
                  height: centeredCanvasHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(viewportWidth, totalHeight),
                        painter: MusicScorePainter(
                          positionedElements: positionedElements,
                          positionedElementsSignature: layoutResult.signature,
                          metadata: SmuflMetadata(),
                          theme: widget.theme,
                          staffSpace: effectiveStaffSpace,
                          layoutEngine: layoutEngine,
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

  double _calculateContentWidth(
    List<PositionedElement> elements,
    double effectiveStaffSpace,
  ) {
    if (elements.isEmpty) {
      return 0.0;
    }

    final systemBounds = <int, ({double minX, double maxX})>{};
    for (final positioned in elements) {
      final current = systemBounds[positioned.system];
      final x = positioned.position.dx;
      if (current == null) {
        systemBounds[positioned.system] = (minX: x, maxX: x);
        continue;
      }

      systemBounds[positioned.system] = (
        minX: x < current.minX ? x : current.minX,
        maxX: x > current.maxX ? x : current.maxX,
      );
    }

    double maxSpan = 0.0;
    for (final bounds in systemBounds.values) {
      final span = bounds.maxX - bounds.minX;
      if (span > maxSpan) {
        maxSpan = span;
      }
    }

    return maxSpan + (effectiveStaffSpace * 2.4);
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

/// Custom [CustomPainter] that renders positioned music notetion elements.
///
/// Optimised for large scores through viewport culling: only systems that
/// intersect the current scroll viewport are painted. A [RepaintBoundary]
/// wraps this painter so that scrolling does not trigger full repaints.
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

  MusicScorePainter({
    required this.positionedElements,
    int? positionedElementsSignature,
    required this.metadata,
    required this.theme,
    required this.staffSpace,
    this.layoutEngine,
    required this.viewportSize,
    required this.horizontalController,
    required this.verticalController,
  }) : positionedElementsSignature =
           positionedElementsSignature ??
           PositionedElement.computeSignature(positionedElements),
       super(
         repaint: Listenable.merge(<Listenable>[
           horizontalController,
           verticalController,
         ]),
       );

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded || positionedElements.isEmpty) return;

    // Optimisation: Clip canvas ao viewport
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Optimisation: Calculate system visíveis
    final systemHeight = staffSpace * 10;
    final visibleSystemRange = _calculateVisibleSystems(systemHeight);

    // Agrupar elementos por system
    final Map<int, List<PositionedElement>> systemGroups = {};

    for (final element in positionedElements) {
      systemGroups.putIfAbsent(element.system, () => []).add(element);
    }

    // Optimisation: Render APENAS system visíveis
    for (final entry in systemGroups.entries) {
      final systemIndex = entry.key;

      // Skip systems fora of the viewport
      if (!visibleSystemRange.contains(systemIndex)) {
        continue;
      }

      final elements = entry.value;
      // Keep the renderer baseline aligned with LayoutCursor.currentY so
      // noteheads, stems and advanced beams share the same vertical reference.
      final systemY = (systemIndex * staffSpace * 10) + (staffSpace * 5.0);
      final staffBaseline = Offset(0, systemY);

      final coordinates = StaffCoordinateSystem(
        staffSpace: staffSpace,
        staffBaseline: staffBaseline,
      );

      final renderer = StaffRenderer(
        coordinates: coordinates,
        metadata: metadata,
        theme: theme,
      );

      renderer.renderStaff(canvas, elements, size, layoutEngine: layoutEngine);
    }

    // DEBUG: For ver quantos systems foram Rendersdos vs pulados:
    // int rendered = visibleSystemRange.length;
    // int skipped = systemGroups.length - rendered;
    // debugPrint('Canvas Clipping: Rendersdos=$rendered, Pulados=$skipped');
  }

  /// Calculatestes quais systems estão visíveis no viewport current
  ///
  /// Returns um range (Set) de indexs de systems that intersectam o viewport.
  /// Adds margem de 1 system acima e abaixo for suavidade no scroll.
  Set<int> _calculateVisibleSystems(double systemHeight) {
    // Validation: Prevenir divisão por zero e valores inválidos
    if (systemHeight <= 0 || !systemHeight.isFinite) {
      // Fallback: Rendersr apenas system 0
      return {0};
    }

    if (!viewportSize.height.isFinite || viewportSize.height <= 0) {
      // Fallback: Rendersr apenas system 0
      return {0};
    }

    final scrollOffsetY = verticalController.hasClients
        ? verticalController.offset
        : 0.0;

    if (!scrollOffsetY.isFinite) {
      // Fallback: Rendersr apenas system 0
      return {0};
    }

    // Viewport Y range (with margem)
    final margin = systemHeight; // 1 sistema de margem
    final viewportTop = scrollOffsetY - margin;
    final viewportBottom = scrollOffsetY + viewportSize.height + margin;

    // Calculatestesr systems visíveis with proteção contra Infinity
    final firstSystemRaw = (viewportTop / systemHeight).floor();
    final lastSystemRaw = (viewportBottom / systemHeight).ceil();

    // Validar that os valores are finitos antes de fazer clamp
    if (!firstSystemRaw.isFinite || !lastSystemRaw.isFinite) {
      return {0};
    }

    final firstSystem = firstSystemRaw.clamp(0, 999);
    final lastSystem = lastSystemRaw.clamp(0, 999);

    // Validar range
    if (lastSystem < firstSystem) {
      return {0};
    }

    // Returnsr range como Set
    return Set<int>.from(
      List<int>.generate(lastSystem - firstSystem + 1, (i) => firstSystem + i),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! MusicScorePainter) return true;

    // Repaint when viewport, styles, or positioned content signature changes.
    return oldDelegate.positionedElementsSignature !=
            positionedElementsSignature ||
        oldDelegate.theme != theme ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.layoutEngine != layoutEngine ||
        oldDelegate.horizontalController != horizontalController ||
        oldDelegate.verticalController != verticalController ||
        oldDelegate.viewportSize != viewportSize;
  }
}
