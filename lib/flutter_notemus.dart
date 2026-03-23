// lib/flutter_notemus.dart
// VERSÃO CORRIGIDA: Widget principal com todas as melhorias

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
/// ## Key Classes
/// - [MusicScore]: The main Flutter widget to embed in your app
/// - [Staff]: Top-level container for music notation
/// - [Measure]: Container for musical elements within a bar
/// - [Note]: A pitched note with duration, articulations, and ornaments
/// - [Rest]: A rest (silence) with duration
/// - [Chord]: Multiple simultaneous notes
library;

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

// 🆕 NOVA ARQUITETURA - Toda teoria musical em core/
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

/// The main Flutter widget for rendering music notation.
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

  const MusicScore({
    super.key,
    required this.staff,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.enableResponsiveLayout = true,
    this.responsiveBreakpointWidth = 640.0,
    this.minResponsiveScale = 0.72,
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
            child: Text('Erro ao carregar metadados: ${snapshot.error}'),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final viewportWidth = _resolveViewportWidth(context, constraints);
            final effectiveStaffSpace =
                _resolveEffectiveStaffSpace(viewportWidth);

            final layoutEngine = LayoutEngine(
              widget.staff,
              availableWidth: viewportWidth,
              staffSpace: effectiveStaffSpace,
              metadata: _metadata,
            );

            final positionedElements = layoutEngine.layout();

            if (positionedElements.isEmpty) {
              return const Center(child: Text('Partitura vazia'));
            }

            final totalHeight =
                _calculateTotalHeight(positionedElements, effectiveStaffSpace);
            final viewportSize = Size(
              viewportWidth,
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : totalHeight,
            );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                controller: _verticalController,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(viewportWidth, totalHeight),
                    painter: MusicScorePainter(
                      positionedElements: positionedElements,
                      metadata: SmuflMetadata(),
                      theme: widget.theme,
                      staffSpace: effectiveStaffSpace,
                      layoutEngine: layoutEngine,
                      viewportSize: viewportSize,
                      scrollOffsetX: _horizontalController.hasClients
                          ? _horizontalController.offset
                          : 0.0,
                      scrollOffsetY: _verticalController.hasClients
                          ? _verticalController.offset
                          : 0.0,
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
      BuildContext context, BoxConstraints constraints) {
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

    final scale = (viewportWidth / widget.responsiveBreakpointWidth)
        .clamp(widget.minResponsiveScale, 1.0);
    return widget.staffSpace * scale;
  }

  double _calculateTotalHeight(
      List<PositionedElement> elements, double effectiveStaffSpace) {
    if (elements.isEmpty) return 200;

    int maxSystem = 0;
    for (final element in elements) {
      if (element.system > maxSystem) {
        maxSystem = element.system;
      }
    }

    final systemHeight = effectiveStaffSpace * 10;
    final margins = effectiveStaffSpace * 6;

    return margins + ((maxSystem + 1) * systemHeight);
  }
}

/// Custom [CustomPainter] that renders positioned music notation elements.
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

  /// Horizontal scroll offset in logical pixels.
  final double scrollOffsetX;

  /// Vertical scroll offset in logical pixels.
  final double scrollOffsetY;

  MusicScorePainter({
    required this.positionedElements,
    required this.metadata,
    required this.theme,
    required this.staffSpace,
    this.layoutEngine,
    required this.viewportSize,
    required this.scrollOffsetX,
    required this.scrollOffsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded || positionedElements.isEmpty) return;

    // OTIMIZAÇÃO 1: Clip canvas ao viewport
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // OTIMIZAÇÃO 2: Calcular sistemas visíveis
    final systemHeight = staffSpace * 10;
    final visibleSystemRange = _calculateVisibleSystems(systemHeight);

    // Agrupar elementos por sistema
    final Map<int, List<PositionedElement>> systemGroups = {};

    for (final element in positionedElements) {
      systemGroups.putIfAbsent(element.system, () => []).add(element);
    }

    // OTIMIZAÇÃO 3: Renderizar APENAS sistemas visíveis
    for (final entry in systemGroups.entries) {
      final systemIndex = entry.key;

      // Skip sistemas fora do viewport
      if (!visibleSystemRange.contains(systemIndex)) {
        continue;
      }

      final elements = entry.value;
      final systemY = (systemIndex * staffSpace * 10) + (staffSpace * 5);
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

    // DEBUG: Para ver quantos sistemas foram renderizados vs pulados:
    // int rendered = visibleSystemRange.length;
    // int skipped = systemGroups.length - rendered;
    // debugPrint('Canvas Clipping: Renderizados=$rendered, Pulados=$skipped');
  }

  /// Calcula quais sistemas estão visíveis no viewport atual
  ///
  /// Retorna um range (Set) de índices de sistemas que intersectam o viewport.
  /// Adiciona margem de 1 sistema acima e abaixo para suavidade no scroll.
  Set<int> _calculateVisibleSystems(double systemHeight) {
    // VALIDAÇÃO: Prevenir divisão por zero e valores inválidos
    if (systemHeight <= 0 || !systemHeight.isFinite) {
      // Fallback: renderizar apenas sistema 0
      return {0};
    }

    if (!viewportSize.height.isFinite || viewportSize.height <= 0) {
      // Fallback: renderizar apenas sistema 0
      return {0};
    }

    if (!scrollOffsetY.isFinite) {
      // Fallback: renderizar apenas sistema 0
      return {0};
    }

    // Viewport Y range (com margem)
    final margin = systemHeight; // 1 sistema de margem
    final viewportTop = scrollOffsetY - margin;
    final viewportBottom = scrollOffsetY + viewportSize.height + margin;

    // Calcular sistemas visíveis com proteção contra Infinity
    final firstSystemRaw = (viewportTop / systemHeight).floor();
    final lastSystemRaw = (viewportBottom / systemHeight).ceil();

    // Validar que os valores são finitos antes de fazer clamp
    if (!firstSystemRaw.isFinite || !lastSystemRaw.isFinite) {
      return {0};
    }

    final firstSystem = firstSystemRaw.clamp(0, 999);
    final lastSystem = lastSystemRaw.clamp(0, 999);

    // Validar range
    if (lastSystem < firstSystem) {
      return {0};
    }

    // Retornar range como Set
    return Set<int>.from(
      List<int>.generate(lastSystem - firstSystem + 1, (i) => firstSystem + i),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! MusicScorePainter) return true;

    // Repintar se viewport ou conteúdo mudaram
    return oldDelegate.positionedElements.length != positionedElements.length ||
        oldDelegate.theme != theme ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.scrollOffsetX != scrollOffsetX ||
        oldDelegate.scrollOffsetY != scrollOffsetY ||
        oldDelegate.viewportSize != viewportSize;
  }
}
