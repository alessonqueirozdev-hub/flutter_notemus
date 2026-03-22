// lib/flutter_notemus.dart
// VERSÃO CORRIGIDA: Widget principal com todas as melhorias

import 'package:flutter/material.dart';
import 'core/core.dart'; // 🆕 Usar tipos do core
import 'src/layout/layout_engine.dart';
import 'src/rendering/staff_renderer.dart';
import 'src/rendering/staff_coordinate_system.dart';
import 'src/smufl/smufl_metadata_loader.dart';
import 'src/theme/music_score_theme.dart';

// 🆕 NOVA ARQUITETURA - Toda teoria musical em core/
export 'core/core.dart';

// Public API exports
export 'src/theme/music_score_theme.dart';
export 'src/layout/layout_engine.dart';
export 'src/parsers/json_parser.dart';
export 'src/smufl/glyph_categories.dart';
export 'src/smufl/smufl_metadata_loader.dart';
export 'src/rendering/staff_position_calculator.dart';
export 'src/rendering/staff_coordinate_system.dart';
export 'src/rendering/staff_renderer.dart';
export 'src/rendering/renderers/base_glyph_renderer.dart';
export 'src/layout/collision_detector.dart';

/// Widget principal para renderização de partituras musicais
/// VERSÃO CORRIGIDA E COMPLETA
class MusicScore extends StatefulWidget {
  final Staff staff;
  final MusicScoreTheme theme;
  final double staffSpace;

  const MusicScore({
    super.key,
    required this.staff,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
  });

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
            final layoutEngine = LayoutEngine(
              widget.staff,
              availableWidth: constraints.maxWidth,
              staffSpace: widget.staffSpace,
              metadata: _metadata,
            );

            final positionedElements = layoutEngine.layout();

            if (positionedElements.isEmpty) {
              return const Center(child: Text('Partitura vazia'));
            }

            final totalHeight = _calculateTotalHeight(positionedElements);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                controller: _verticalController,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, totalHeight),
                    painter: MusicScorePainter(
                      positionedElements: positionedElements,
                      metadata: SmuflMetadata(),
                      theme: widget.theme,
                      staffSpace: widget.staffSpace,
                      layoutEngine: layoutEngine,
                      viewportSize: constraints.biggest,
                      scrollOffsetX: _horizontalController.hasClients ? _horizontalController.offset : 0.0,
                      scrollOffsetY: _verticalController.hasClients ? _verticalController.offset : 0.0,
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

  double _calculateTotalHeight(List<PositionedElement> elements) {
    if (elements.isEmpty) return 200;

    int maxSystem = 0;
    for (final element in elements) {
      if (element.system > maxSystem) {
        maxSystem = element.system;
      }
    }

    final systemHeight = widget.staffSpace * 10;
    final margins = widget.staffSpace * 6;

    return margins + ((maxSystem + 1) * systemHeight);
  }
}

/// Painter customizado para renderização da partitura
/// VERSÃO OTIMIZADA: Canvas Clipping + Viewport Culling
///
/// **OTIMIZAÇÕES:**
/// - Renderiza apenas sistemas visíveis no viewport
/// - Usa clipRect para segurança
/// - RepaintBoundary para evitar repaints desnecessários
class MusicScorePainter extends CustomPainter {
  final List<PositionedElement> positionedElements;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double staffSpace;
  final LayoutEngine? layoutEngine;
  final Size viewportSize;
  final double scrollOffsetX;
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
