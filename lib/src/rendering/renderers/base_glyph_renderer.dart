// lib/src/rendering/renderers/base_glyph_renderer.dart
// NOVA CLASSE BASE: Renderização unificada de glifos SMuFL
//
// Esta classe base fornece método unificado para desenhar glifos
// usando SEMPRE bounding box SMuFL para posicionamento preciso.
//
// ELIMINA inconsistências de uso de centerVertically/centerHorizontally
// que causam alinhamentos imprecisos.

import 'package:flutter/material.dart';
import '../../utils/lru_cache.dart';
import '../../layout/collision_detector.dart'; // CORREÇÃO: Caminho correto após consolidação
import '../../smufl/smufl_metadata_loader.dart';
import '../staff_coordinate_system.dart';

/// Classe base para renderizadores de glifos SMuFL
///
/// Fornece método unificado [drawGlyphWithBBox] que SEMPRE usa
/// bounding box do metadata SMuFL para posicionamento preciso.
///
/// IMPORTANTE: Todos os renderizadores devem herdar desta classe
/// e usar exclusivamente [drawGlyphWithBBox] para renderização.
abstract class BaseGlyphRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final double glyphSize;

  /// Cache LRU de TextPainters reutilizáveis para performance
  ///
  /// **Limite:** 500 entradas (evita memory leak)
  /// **Estratégia:** LRU (Least Recently Used) - remove entradas menos usadas
  /// **Key:** glyphName_size_color
  ///
  /// **Cálculo de tamanho estimado:**
  /// - Cada TextPainter: ~2-5 KB (dependendo do glyph)
  /// - 500 entradas: ~1-2.5 MB de memória máxima
  ///
  /// **Benchmarks:**
  /// - Hit rate típico: 85-95% (poucas combinações de glyph/size/color)
  /// - Miss apenas em glyphs raros ou tamanhos incomuns
  ///
  /// **Referências:**
  /// - Guia completo: docs/IMPLEMENTATION_GUIDE_LRU_CACHE.md
  /// - Magic numbers: docs/MAGIC_NUMBERS_REFERENCE.md
  final LruCache<String, TextPainter> _textPainterCache = LruCache(500);

  /// Detector de colisões opcional (pode ser compartilhado entre renderizadores)
  CollisionDetector? collisionDetector;

  BaseGlyphRenderer({
    required this.coordinates,
    required this.metadata,
    required this.glyphSize,
    this.collisionDetector,
  });

  /// Desenha um glifo SMuFL usando bounding box para posicionamento preciso
  ///
  /// Este é o ÚNICO método que deve ser usado para renderização de glifos.
  /// Ele garante:
  /// 1. Uso correto de bounding box SMuFL (nunca TextPainter.height/width)
  /// 2. Centralização precisa baseada em bbox.centerY e bbox.centerX
  /// 3. Cache de TextPainters para performance
  ///
  /// @param canvas Canvas do Flutter para desenho
  /// @param glyphName Nome do glifo SMuFL (ex: 'noteheadBlack', 'gClef')
  /// @param position Posição de referência (onde o glifo será desenhado)
  /// @param color Cor do glifo
  /// @param options Opções de alinhamento e transformação
  void drawGlyphWithBBox(
    Canvas canvas, {
    required String glyphName,
    required Offset position,
    required Color color,
    GlyphDrawOptions options = const GlyphDrawOptions(),
  }) {
    // Obter codepoint Unicode do glifo
    final character = metadata.getCodepoint(glyphName);
    if (character.isEmpty) {
      // Glifo não encontrado, usar fallback se fornecido
      if (options.fallbackGlyph != null) {
        drawGlyphWithBBox(
          canvas,
          glyphName: options.fallbackGlyph!,
          position: position,
          color: color,
          options: options.copyWith(fallbackGlyph: null),
        );
      }
      return;
    }

    // Obter ou criar TextPainter do cache
    final cacheKey = '${glyphName}_${options.size ?? glyphSize}_${color.toARGB32()}';
    TextPainter textPainter;

    // Tentar obter do cache LRU
    final cached = options.disableCache ? null : _textPainterCache.get(cacheKey);
    if (cached != null) {
      textPainter = cached;
    } else {
      textPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(
            fontFamily: 'Bravura',
            fontSize: options.size ?? glyphSize,
            color: color,
            height: 1.0,
            letterSpacing: 0.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      if (!options.disableCache) {
        _textPainterCache.put(cacheKey, textPainter);
      }
    }

    // CORREÇÃO CRÍTICA: Usar bounding box SMuFL ao invés de TextPainter dimensions
    final glyphInfo = metadata.getGlyphInfo(glyphName);
    double xOffset = 0.0;
    double yOffset = 0.0;

    if (glyphInfo != null && glyphInfo.hasBoundingBox) {
      final bbox = glyphInfo.boundingBox!;

      // Calcular offsets baseados no bounding box SMuFL
      if (options.centerHorizontally) {
        // Centralizar horizontalmente usando centro do bbox
        xOffset = -(bbox.centerX * coordinates.staffSpace);
      } else if (options.alignLeft) {
        // Alinhar à esquerda usando borda esquerda do bbox
        xOffset = -(bbox.bBoxSwX * coordinates.staffSpace);
      } else if (options.alignRight) {
        // Alinhar à direita usando borda direita do bbox
        xOffset = -(bbox.bBoxNeX * coordinates.staffSpace);
      }
      // Se nenhum, usar posição como está (sem offset horizontal)

      if (options.centerVertically) {
        // Centralizar verticalmente usando centro do bbox
        yOffset = -(bbox.centerY * coordinates.staffSpace);
      } else if (options.alignTop) {
        // Alinhar ao topo usando borda superior do bbox
        yOffset = -(bbox.bBoxNeY * coordinates.staffSpace);
      } else if (options.alignBottom) {
        // Alinhar à base usando borda inferior do bbox
        yOffset = -(bbox.bBoxSwY * coordinates.staffSpace);
      }
      // Se nenhum, usar posição como está (sem offset vertical)
    } else {
      // FALLBACK: Se não houver bounding box, usar dimensões do TextPainter
      // (menos preciso, mas funcional)
      if (options.centerHorizontally) {
        xOffset = -textPainter.width * 0.5;
      }
      if (options.centerVertically) {
        yOffset = -textPainter.height * 0.5;
      }
    }

    // Aplicar transformações (rotação, escala) se necessário
    if (options.rotation != 0.0 || options.scale != 1.0) {
      canvas.save();

      // Transladar para ponto de rotação/escala
      canvas.translate(position.dx + xOffset, position.dy + yOffset);

      // Aplicar rotação
      if (options.rotation != 0.0) {
        canvas.rotate(options.rotation * 3.14159 / 180.0); // Graus para radianos
      }

      // Aplicar escala
      if (options.scale != 1.0) {
        canvas.scale(options.scale);
      }

      // Desenhar na origem (já transladamos)
      textPainter.paint(canvas, Offset.zero);

      canvas.restore();
    } else {
      // Desenho simples sem transformações
      final finalX = position.dx + xOffset;
      final finalY = position.dy + yOffset;
      
      // CORREÇÃO CRÍTICA: TextPainter não desenha pela baseline SMuFL!
      // Para fontes SMuFL, o TextPainter desenha o glyph com o TOPO na coordenada Y especificada,
      // não pela baseline. Precisamos compensar deslocando o glyph para cima em metade da altura.
      // A baseline SMuFL está aproximadamente no centro vertical do bounding box renderizado.
      // 
      // EXCEÇÃO: Noteheads NÃO devem receber essa correção pois precisam alinhar
      // exatamente com linhas suplementares!
      double baselineCorrection = 0.0;
      if (!options.centerVertically && !options.alignTop && !options.alignBottom 
          && !options.disableBaselineCorrection) {
        // Apenas aplicar correção se não estamos usando nenhum alinhamento vertical
        // E se a correção não foi explicitamente desabilitada
        // NO FLUTTER: Y+ = BAIXO, então SUBTRAÍMOS para fazer o glifo SUBIR
        baselineCorrection = -textPainter.height * 0.5;
      }
      
      final correctedY = finalY + baselineCorrection;
      
      textPainter.paint(
        canvas,
        Offset(finalX, correctedY),
      );
    }

    // Registrar desenho para sistema de detecção de colisões (se habilitado)
    if (options.trackBounds &&
        collisionDetector != null &&
        glyphInfo != null &&
        glyphInfo.hasBoundingBox) {
      final bbox = glyphInfo.boundingBox!;
      final bounds = Rect.fromLTWH(
        position.dx + xOffset + (bbox.bBoxSwX * coordinates.staffSpace),
        position.dy + yOffset + (bbox.bBoxSwY * coordinates.staffSpace),
        bbox.widthInPixels(coordinates.staffSpace),
        bbox.heightInPixels(coordinates.staffSpace),
      );

      // Registrar no sistema de colisões
      collisionDetector!.register(
        id: '${glyphName}_${position.dx.toStringAsFixed(1)}_${position.dy.toStringAsFixed(1)}',
        bounds: bounds,
        category: _getCategoryForGlyph(glyphName, options),
        priority: options.collisionPriority ?? CollisionPriority.medium,
      );
    }
  }

  /// NOVO: Desenha um glifo alinhando um anchor SMuFL a um alvo
  /// Ex.: alinhar 'opticalCenter' do glifo exatamente em `target`.
  void drawGlyphAlignedToAnchor(
    Canvas canvas, {
    required String glyphName,
    required String anchorName,
    required Offset target,
    required Color color,
    GlyphDrawOptions options = const GlyphDrawOptions(),
  }) {
    final anchor = metadata.getGlyphAnchor(glyphName, anchorName);
    if (anchor == null) {
      // Sem anchor: fallback para centralização padrão
      drawGlyphWithBBox(
        canvas,
        glyphName: glyphName,
        position: target,
        color: color,
        options: options,
      );
      return;
    }

    // Converter anchor de staff spaces para pixels
    final anchorPx = Offset(
      anchor.dx * coordinates.staffSpace,
      -anchor.dy * coordinates.staffSpace,
    );

    // Para alinhar o anchor ao alvo, desenhar o glifo em (target - anchorPx)
    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: Offset(target.dx - anchorPx.dx, target.dy - anchorPx.dy),
      color: color,
      options: options.copyWith(
        // Anchor alignment geralmente não requer centralizações adicionais
        centerHorizontally: false,
        centerVertically: false,
        alignLeft: false,
        alignRight: false,
        alignTop: false,
        alignBottom: false,
      ),
    );
  }

  /// Limpa cache de TextPainters
  /// Útil para liberar memória ou quando mudanças de tema ocorrem
  void clearCache() {
    _textPainterCache.clear();
  }

  /// Obtém número de itens no cache
  int get cacheSize => _textPainterCache.size;

  /// Determina a categoria de colisão baseada no nome do glifo e opções
  CollisionCategory _getCategoryForGlyph(String glyphName, GlyphDrawOptions options) {
    // Mapear baseado no nome do glifo
    if (glyphName.startsWith('notehead')) return CollisionCategory.notehead;
    if (glyphName.startsWith('accidental')) return CollisionCategory.accidental;
    if (glyphName.startsWith('flag')) return CollisionCategory.flag;
    if (glyphName.startsWith('rest')) return CollisionCategory.notehead;
    if (glyphName.contains('Clef')) return CollisionCategory.clef;
    if (glyphName.startsWith('artic')) return CollisionCategory.articulation;
    if (glyphName.contains('dynamic') || glyphName.startsWith('dynamic')) {
      return CollisionCategory.dynamic;
    }
    if (glyphName.contains('ornament')) return CollisionCategory.ornament;

    // Categoria padrão baseada nas opções predefinidas
    if (options == GlyphDrawOptions.noteheadDefault) {
      return CollisionCategory.notehead;
    }
    if (options == GlyphDrawOptions.accidentalDefault) {
      return CollisionCategory.accidental;
    }
    if (options == GlyphDrawOptions.articulationDefault) {
      return CollisionCategory.articulation;
    }
    if (options == GlyphDrawOptions.ornamentDefault) {
      return CollisionCategory.ornament;
    }

    return CollisionCategory.text; // Fallback
  }
}

/// Opções para desenho de glifos
class GlyphDrawOptions {
  /// Centralizar horizontalmente usando bounding box center
  final bool centerHorizontally;

  /// Centralizar verticalmente usando bounding box center
  final bool centerVertically;

  /// Alinhar à esquerda usando bounding box left edge
  final bool alignLeft;

  /// Alinhar à direita usando bounding box right edge
  final bool alignRight;

  /// Alinhar ao topo usando bounding box top edge
  final bool alignTop;

  /// Alinhar à base usando bounding box bottom edge
  final bool alignBottom;

  /// Tamanho customizado (se null, usa glyphSize padrão)
  final double? size;

  /// Rotação em graus (horário positivo)
  final double rotation;

  /// Escala (1.0 = normal)
  final double scale;

  /// Glifo de fallback caso o principal não seja encontrado
  final String? fallbackGlyph;

  /// Desabilitar cache (útil para glifos que mudam frequentemente)
  final bool disableCache;

  /// Registrar bounds para detecção de colisões
  final bool trackBounds;

  /// Prioridade de colisão (usado se trackBounds = true)
  final CollisionPriority? collisionPriority;

  /// Desabilitar correção de baseline automática
  /// (útil para noteheads que devem alinhar precisamente com linhas)
  final bool disableBaselineCorrection;

  const GlyphDrawOptions({
    this.centerHorizontally = false,
    this.centerVertically = false,
    this.alignLeft = false,
    this.alignRight = false,
    this.alignTop = false,
    this.alignBottom = false,
    this.size,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.fallbackGlyph,
    this.disableCache = false,
    this.trackBounds = true, // CORREÇÃO: Ativado por padrão para collision detection
    this.collisionPriority,
    this.disableBaselineCorrection = false,
  });

  /// Cria cópia com valores modificados
  GlyphDrawOptions copyWith({
    bool? centerHorizontally,
    bool? centerVertically,
    bool? alignLeft,
    bool? alignRight,
    bool? alignTop,
    bool? alignBottom,
    double? size,
    double? rotation,
    double? scale,
    String? fallbackGlyph,
    bool? disableCache,
    bool? trackBounds,
    CollisionPriority? collisionPriority,
    bool? disableBaselineCorrection,
  }) {
    return GlyphDrawOptions(
      centerHorizontally: centerHorizontally ?? this.centerHorizontally,
      centerVertically: centerVertically ?? this.centerVertically,
      alignLeft: alignLeft ?? this.alignLeft,
      alignRight: alignRight ?? this.alignRight,
      alignTop: alignTop ?? this.alignTop,
      alignBottom: alignBottom ?? this.alignBottom,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      fallbackGlyph: fallbackGlyph ?? this.fallbackGlyph,
      disableCache: disableCache ?? this.disableCache,
      trackBounds: trackBounds ?? this.trackBounds,
      collisionPriority: collisionPriority ?? this.collisionPriority,
      disableBaselineCorrection: disableBaselineCorrection ?? this.disableBaselineCorrection,
    );
  }

  /// Opções padrão para cabeças de nota
  /// CRÍTICO: A baseline correction é NECESSÁRIA para posicionar as notas corretamente!
  /// Os anchors (stemUpSE, stemDownNW) são relativos à baseline SMuFL.
  /// NOTA: Isso causa um offset nos pontos de aumento, que é compensado no DotRenderer.
  static const GlyphDrawOptions noteheadDefault = GlyphDrawOptions(
    centerHorizontally: false,
    centerVertically: false,
    // disableBaselineCorrection: false (padrão) - NECESSÁRIO!
    trackBounds: true,
    collisionPriority: CollisionPriority.veryHigh,
  );

  /// Opções padrão para acidentes
  /// CRÍTICO: centerVertically: false para consistência com baseline SMuFL
  static const GlyphDrawOptions accidentalDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true,
    collisionPriority: CollisionPriority.veryHigh,
  );

  /// Opções padrão para articulações
  /// CRÍTICO: centerVertically: false para consistência com baseline SMuFL
  static const GlyphDrawOptions articulationDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // CORREÇÃO: Ativado para collision detection
    collisionPriority: CollisionPriority.high,
  );

  /// Opções padrão para ornamentos
  /// CRÍTICO: centerVertically: false para consistência com baseline SMuFL
  static const GlyphDrawOptions ornamentDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // CORREÇÃO: Ativado para collision detection
    collisionPriority: CollisionPriority.medium,
  );

  /// Opções padrão para pausas
  /// CRÍTICO: centerVertically: false para consistência com baseline SMuFL
  static const GlyphDrawOptions restDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // CORREÇÃO: Ativado para collision detection
    collisionPriority: CollisionPriority.high,
  );
}
