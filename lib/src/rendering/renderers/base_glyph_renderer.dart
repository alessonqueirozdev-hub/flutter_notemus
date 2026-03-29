// lib/src/rendering/renderers/base_glyph_renderer.dart
// Base class: unified SMuFL glyph rendering
//
// This class base fornece method unificado for desenhar glifos
// using Always bounding box SMuFL for posicionamento preciso.
//
// ELIMINA inconsistências de uso de centerVertically/centerHorizontally
// that cause alinhamentos imprecisos.

import 'package:flutter/material.dart';
import '../../utils/lru_cache.dart';
import '../../layout/collision_detector.dart'; // CORREÇÃO: Caminho correto após consolidação
import '../../smufl/smufl_metadata_loader.dart';
import '../staff_coordinate_system.dart';

/// Class base for Renderers de glifos SMuFL
///
/// Fornece method unificado [drawGlyphWithBBox] that Always Uses
/// bounding box of the metadata SMuFL for posicionamento preciso.
///
/// Important: All os renderers must herdar desta class
/// and Use exclusivamente [drawGlyphWithBBox] for Rendering.
abstract class BaseGlyphRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final double glyphSize;

  /// Cache LRU de TextPainters reutilizáveis for performance
  ///
  /// **Limite:** 500 entradas (avoids memory leak)
  /// **Estratégia:** LRU (Least Recently Used) - remove entradas less used
  /// **Key:** glyphName_size_color
  ///
  /// **Calculation de size estimado:**
  /// - Each TextPainter: ~2-5 KB (dependendo of the glyph)
  /// - 500 entradas: ~1-2.5 MB de memória máxima
  ///
  /// **Benchmarks:**
  /// - Hit rate típico: 85-95% (poucas combinações de glyph/size/color)
  /// - Miss only in glyphs raros or sizes incomuns
  ///
  /// **References:**
  /// - Guia completo: docs/IMPLEMENTATION_GUIDE_LRU_CACHE.md
  /// - Magic numbers: docs/MAGIC_NUMBERS_REFERENCE.md
  final LruCache<String, TextPainter> _textPainterCache = LruCache(500);

  /// Detector de colisões opcional (can be shared between Renderers)
  CollisionDetector? collisionDetector;

  BaseGlyphRenderer({
    required this.coordinates,
    required this.metadata,
    required this.glyphSize,
    this.collisionDetector,
  });

  /// Desenha a glifo SMuFL using bounding box for posicionamento preciso
  ///
  /// This is o ÚNICO method that must be used for Rendering de glifos.
  /// It ensures:
  /// 1. Uso correct de bounding box SMuFL (never TextPainter.height/width)
  /// 2. Centralização needs baseada in bbox.centerY and bbox.centerX
  /// 3. Cache de TextPainters for performance
  ///
  /// @param canvas Flutter canvas for drawing
  /// @param glyphName Glyph name SMuFL (ex: 'noteheadBlack', 'gClef')
  /// @param position Position reference (where o glifo será desenhado)
  /// @param color Cor of the glifo
  /// @param options Opções de alinhamento and transformação
  void drawGlyphWithBBox(
    Canvas canvas, {
    required String glyphName,
    required Offset position,
    required Color color,
    GlyphDrawOptions options = const GlyphDrawOptions(),
  }) {
    // Get codepoint Unicode of the glifo
    final character = metadata.getCodepoint(glyphName);
    if (character.isEmpty) {
      // Glifo not encontrado, Use fallback if fornecido
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

    // Get or Createsr TextPainter of the cache
    final cacheKey = '${glyphName}_${options.size ?? glyphSize}_${color.toARGB32()}';
    TextPainter textPainter;

    // Tentar Get of the cache LRU
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

    // Fix: CRÍTICA: Use bounding box SMuFL to the invés de TextPainter dimensions
    final glyphInfo = metadata.getGlyphInfo(glyphName);
    double xOffset = 0.0;
    double yOffset = 0.0;

    if (glyphInfo != null && glyphInfo.hasBoundingBox) {
      final bbox = glyphInfo.boundingBox!;

      // Calculate offsets based on the SMuFL bounding box
      if (options.centerHorizontally) {
        // Centralizar horizontalmente using centre of the bbox
        xOffset = -(bbox.centerX * coordinates.staffSpace);
      } else if (options.alignLeft) {
        // Align to the left using borda left of the bbox
        xOffset = -(bbox.bBoxSwX * coordinates.staffSpace);
      } else if (options.alignRight) {
        // Align to the right using borda right of the bbox
        xOffset = -(bbox.bBoxNeX * coordinates.staffSpace);
      }
      // If nenhum, Use position as está (sem offset horizontal)

      if (options.centerVertically) {
        // Centralizar verticalmente using centre of the bbox
        yOffset = -(bbox.centerY * coordinates.staffSpace);
      } else if (options.alignTop) {
        // Align to the top using borda upper of the bbox
        yOffset = -(bbox.bBoxNeY * coordinates.staffSpace);
      } else if (options.alignBottom) {
        // Align to the base using borda lower of the bbox
        yOffset = -(bbox.bBoxSwY * coordinates.staffSpace);
      }
      // If nenhum, Use position as está (sem offset vertical)
    } else {
      // FALLBACK: If not houver bounding box, Use dimensões of the TextPainter
      // (less preciso, mas funcional)
      if (options.centerHorizontally) {
        xOffset = -textPainter.width * 0.5;
      }
      if (options.centerVertically) {
        yOffset = -textPainter.height * 0.5;
      }
    }

    // Appliesr transformações (rotação, escala) if required
    if (options.rotation != 0.0 || options.scale != 1.0) {
      canvas.save();

      // Transladar for point de rotação/escala
      canvas.translate(position.dx + xOffset, position.dy + yOffset);

      // Appliesr rotação
      if (options.rotation != 0.0) {
        canvas.rotate(options.rotation * 3.14159 / 180.0); // Graus para radianos
      }

      // Appliesr escala
      if (options.scale != 1.0) {
        canvas.scale(options.scale);
      }

      // Desenhar na origem (already transladamos)
      textPainter.paint(canvas, Offset.zero);

      canvas.restore();
    } else {
      // Desenho simples sem transformações
      final finalX = position.dx + xOffset;
      final finalY = position.dy + yOffset;
      
      // Fix: CRÍTICA: TextPainter not desenha pela baseline SMuFL!
      // For fontes SMuFL, o TextPainter desenha o glyph with o Top na coordenada Y especificada,
      // not pela baseline. Precisamos compensar deslocando o glyph for top in metade of the height.
      // A baseline SMuFL está aproximadamente no centre vertical of the bounding box Rendersdo.
      // 
      // EXCEÇÃO: Noteheads Not must receber this correção pois need align
      // exatamente with ledger lines!
      double baselineCorrection = 0.0;
      if (!options.centerVertically && !options.alignTop && !options.alignBottom 
          && !options.disableBaselineCorrection) {
        // Only Appliesr correção if not estamos using nenhum alinhamento vertical
        // And if a correção not foi explicitamente desabilitada
        // NO FLUTTER: Y+ = Bottom, então SUBTRAÍMOS for fazer o glifo SUBIR
        baselineCorrection = -textPainter.height * 0.5;
      }
      
      final correctedY = finalY + baselineCorrection;
      
      textPainter.paint(
        canvas,
        Offset(finalX, correctedY),
      );
    }

    // Registrar desenho for system de detecção de colisões (if habilitado)
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

      // Registrar no system de colisões
      collisionDetector!.register(
        id: '${glyphName}_${position.dx.toStringAsFixed(1)}_${position.dy.toStringAsFixed(1)}',
        bounds: bounds,
        category: _getCategoryForGlyph(glyphName, options),
        priority: options.collisionPriority ?? CollisionPriority.medium,
      );
    }
  }

  /// New: Desenha a glifo alinhando a anchor SMuFL a a alvo
  /// E.g., align 'opticalCenter' of the glifo exatamente in `target`.
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
      // Sem anchor: fallback for centralização default
      drawGlyphWithBBox(
        canvas,
        glyphName: glyphName,
        position: target,
        color: color,
        options: options,
      );
      return;
    }

    // Convertsr anchor de staff spaces for pixels
    final anchorPx = Offset(
      anchor.dx * coordinates.staffSpace,
      -anchor.dy * coordinates.staffSpace,
    );

    // For align o anchor to the alvo, desenhar o glifo in (target - anchorPx)
    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: Offset(target.dx - anchorPx.dx, target.dy - anchorPx.dy),
      color: color,
      options: options.copyWith(
        // Anchor alignment Generateslmente not requer centralizações Addsis
        centerHorizontally: false,
        centerVertically: false,
        alignLeft: false,
        alignRight: false,
        alignTop: false,
        alignBottom: false,
        disableBaselineCorrection: true,
      ),
    );
  }

  /// Limpa cache de TextPainters
  /// Útil for liberar memória or when mudanças de tema ocorrem
  void clearCache() {
    _textPainterCache.clear();
  }

  /// Gets number de itens no cache
  int get cacheSize => _textPainterCache.size;

  /// Determina a categoria de colisão baseada no glyph name and opções
  CollisionCategory _getCategoryForGlyph(String glyphName, GlyphDrawOptions options) {
    // Map based no glyph name
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

    // Categoria default baseada nas opções predefinidas
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

/// Opções for desenho de glifos
class GlyphDrawOptions {
  /// Centralizar horizontalmente using bounding box center
  final bool centerHorizontally;

  /// Centralizar verticalmente using bounding box center
  final bool centerVertically;

  /// Align to the left using bounding box left edge
  final bool alignLeft;

  /// Align to the right using bounding box right edge
  final bool alignRight;

  /// Align to the top using bounding box top edge
  final bool alignTop;

  /// Align to the base using bounding box bottom edge
  final bool alignBottom;

  /// Size customizado (if null, Uses glyphSize default)
  final double? size;

  /// Rotação in graus (horário positivo)
  final double rotation;

  /// Escala (1.0 = normal)
  final double scale;

  /// Glifo de fallback caso o principal not seja encontrado
  final String? fallbackGlyph;

  /// Desabilitar cache (útil for glifos that mudam frequently)
  final bool disableCache;

  /// Registrar bounds for detecção de colisões
  final bool trackBounds;

  /// Prioridade de colisão (used if trackBounds = true)
  final CollisionPriority? collisionPriority;

  /// Desabilitar correção de baseline automática
  /// (útil for noteheads that must align precisamente with lines)
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

  /// Creates cópia with valores modificados
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

  /// Opções default for noteheads
  /// Critical: A baseline correction is Required for position as notes corretamente!
  /// Os anchors (stemUpSE, stemDownNW) are relativos to the baseline SMuFL.
  /// Note: Isso caUses a offset nos points de aumento, that is compensado no DotRenderer.
  static const GlyphDrawOptions noteheadDefault = GlyphDrawOptions(
    centerHorizontally: false,
    centerVertically: false,
    // disableBaselineCorrection: false (default) - Required!
    trackBounds: true,
    collisionPriority: CollisionPriority.veryHigh,
  );

  /// Opções default for accidentals
  /// Critical: centerVertically: false for consistência with baseline SMuFL
  static const GlyphDrawOptions accidentalDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true,
    collisionPriority: CollisionPriority.veryHigh,
  );

  /// Opções default for articulations
  /// Critical: centerVertically: false for consistência with baseline SMuFL
  static const GlyphDrawOptions articulationDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // CORREÇÃO: Ativado para collision detection
    collisionPriority: CollisionPriority.high,
  );

  /// Opções default for ornaments
  /// Critical: centerVertically: false for consistência with baseline SMuFL
  static const GlyphDrawOptions ornamentDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // CORREÇÃO: Ativado para collision detection
    collisionPriority: CollisionPriority.medium,
  );

  /// Opções default for paUsess
  /// Critical: centerVertically: false for consistência with baseline SMuFL
  static const GlyphDrawOptions restDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // CORREÇÃO: Ativado para collision detection
    collisionPriority: CollisionPriority.high,
  );
}
