// lib/src/rendering/renderers/base_glyph_renderer.dart
// Base class: unified SMuFL glyph rendering.
//
// Provides the single method every renderer uses to draw a glyph, always
// positioning it from the SMuFL bounding box rather than from TextPainter
// metrics — which is what removes the inconsistent use of
// centerVertically/centerHorizontally that used to misalign glyphs.

import 'package:flutter/material.dart';
import '../performance_optimizer.dart';
import '../../layout/collision_detector.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../staff_coordinate_system.dart';

/// Base class for SMuFL glyph renderers.
///
/// Provides the unified [drawGlyphWithBBox] method, which always positions a
/// glyph from its SMuFL bounding box. Every renderer must extend this class and
/// draw exclusively through [drawGlyphWithBBox].
///
/// ## Font independence
///
/// **No renderer may name a music font literally.** Writing `'Bravura'` (or any
/// other family) into a [TextStyle] is a defect, not a shortcut: it silently
/// re-pins the engine to one font while the package advertises SMuFL
/// compliance, and it desynchronises drawing from measuring.
///
/// The font actually in use is carried by [SmuflMetadata.font], a
/// [SmuflFontDescriptor] holding the family and the package that ships it.
/// Renderers read `metadata.font.fontFamily` together with
/// `package: metadata.font.fontPackage` when the [TextStyle] accepts a package,
/// or [SmuflFontDescriptor.resolvedFamily] when it does not.
///
/// This matters because *every geometric decision in this package already comes
/// from the loaded font's metadata* — `engravingDefaults` (stem, beam, barline
/// and staff-line thicknesses), `glyphBBoxes` (bounding boxes, hence every
/// alignment computed above), `glyphAdvanceWidths` (spacing and digit advance)
/// and `glyphsWithAnchors` (stem attachment, optical centres). Point
/// [SmuflMetadata.load] at Petaluma, Leland or Sebastian and all of those
/// numbers change accordingly. A hardcoded family would keep drawing Bravura
/// outlines under another font's metrics: glyphs measured from one font and
/// rasterised from another, which is worse than either font alone.
///
/// **Where the TextPainters come from**
///
/// Building (and laying out) a [TextPainter] per glyph per frame is the single
/// most expensive thing a score painter does. Every painter used here is
/// therefore obtained from [PerformanceOptimizer.glyphPainter], the process-wide
/// LRU cache (`lib/src/rendering/performance_optimizer.dart`, capacity
/// [PerformanceOptimizer.glyphPainterCacheCapacity]) keyed by character, font
/// family/package, quantised size and colour. That class documents the full
/// invalidation policy; the two rules that matter to renderers are:
///
/// * the returned painter is **shared and must not be mutated** (never call
///   `layout()` on it, never reassign `text`) — it is only ever painted;
/// * pass `GlyphDrawOptions(disableCache: true)` to get a private painter
///   instead (built by [PerformanceOptimizer.buildGlyphPainter]).
abstract class BaseGlyphRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final double glyphSize;

  /// Optional collision detector (may be shared between renderers).
  CollisionDetector? collisionDetector;

  BaseGlyphRenderer({
    required this.coordinates,
    required this.metadata,
    required this.glyphSize,
    this.collisionDetector,
  });

  /// Draws a SMuFL glyph, positioning it from its bounding box.
  ///
  /// This is the ONLY method that may be used to render a glyph. It guarantees:
  /// 1. correct use of the SMuFL bounding box (never TextPainter.height/width);
  /// 2. precise centring based on bbox.centerX / bbox.centerY;
  /// 3. TextPainter caching, drawn with the loaded font (see *Font
  ///    independence* above).
  ///
  /// [canvas] Flutter canvas to draw on.
  /// [glyphName] SMuFL glyph name (e.g. 'noteheadBlack', 'gClef').
  /// [position] Reference point where the glyph is drawn.
  /// [color] Colour of the glyph.
  /// [options] Alignment and transform options.
  void drawGlyphWithBBox(
    Canvas canvas, {
    required String glyphName,
    required Offset position,
    required Color color,
    GlyphDrawOptions options = const GlyphDrawOptions(),
  }) {
    // Unicode codepoint of the glyph.
    final character = metadata.getCodepoint(glyphName);
    if (character.isEmpty) {
      // Glyph not found: use the fallback glyph when one was supplied.
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

    // Get the (shared, already laid out) TextPainter from the LRU cache owned
    // by PerformanceOptimizer. The key covers every parameter that changes the
    // text layout: character, font descriptor (family + package), quantised
    // size and colour. The font comes from `metadata.font`, so the glyphs are
    // rasterised with the very font whose metrics positioned them.
    // The painter is read-only for us — we only paint it, never re-layout it.
    final fontSize = options.size ?? glyphSize;
    final TextPainter textPainter = options.disableCache
        ? PerformanceOptimizer.buildGlyphPainter(
            character: character,
            fontSize: fontSize,
            color: color,
            font: metadata.font,
          )
        : PerformanceOptimizer.glyphPainter(
            character: character,
            fontSize: fontSize,
            color: color,
            font: metadata.font,
          );

    // CRITICAL: use the SMuFL bounding box instead of TextPainter dimensions.
    final glyphInfo = metadata.getGlyphInfo(glyphName);
    double xOffset = 0.0;
    double yOffset = 0.0;

    if (glyphInfo != null && glyphInfo.hasBoundingBox) {
      final bbox = glyphInfo.boundingBox!;

      // Calculate offsets based on the SMuFL bounding box
      if (options.centerHorizontally) {
        // Centre horizontally on the bbox centre.
        xOffset = -(bbox.centerX * coordinates.staffSpace);
      } else if (options.alignLeft) {
        // Align to the bbox's left edge.
        xOffset = -(bbox.bBoxSwX * coordinates.staffSpace);
      } else if (options.alignRight) {
        // Align to the bbox's right edge.
        xOffset = -(bbox.bBoxNeX * coordinates.staffSpace);
      }
      // With no option set, use `position` as-is (no horizontal offset).

      if (options.centerVertically) {
        // Centre vertically on the bbox centre.
        yOffset = -(bbox.centerY * coordinates.staffSpace);
      } else if (options.alignTop) {
        // Align to the bbox's top edge.
        yOffset = -(bbox.bBoxNeY * coordinates.staffSpace);
      } else if (options.alignBottom) {
        // Align to the bbox's bottom edge.
        yOffset = -(bbox.bBoxSwY * coordinates.staffSpace);
      }
      // With no option set, use `position` as-is (no vertical offset).
    } else {
      // FALLBACK: with no bounding box, fall back to the TextPainter's own
      // dimensions (less precise, but functional).
      if (options.centerHorizontally) {
        xOffset = -textPainter.width * 0.5;
      }
      if (options.centerVertically) {
        yOffset = -textPainter.height * 0.5;
      }
    }

    // Apply transforms (rotation, scale) when requested.
    if (options.rotation != 0.0 || options.scale != 1.0) {
      canvas.save();

      // Translate to the rotation/scale pivot.
      canvas.translate(position.dx + xOffset, position.dy + yOffset);

      // Rotation.
      if (options.rotation != 0.0) {
        canvas.rotate(options.rotation * 3.14159 / 180.0); // degrees -> radians
      }

      // Scale.
      if (options.scale != 1.0) {
        canvas.scale(options.scale);
      }

      // Draw at the origin (we already translated).
      textPainter.paint(canvas, Offset.zero);

      canvas.restore();
    } else {
      // Plain draw, no transform.
      final finalX = position.dx + xOffset;
      final finalY = position.dy + yOffset;

      // CRITICAL: TextPainter does not draw from the SMuFL baseline. It places
      // the glyph's TOP at the given Y, so we compensate by lifting the glyph
      // half its height — the SMuFL baseline sits roughly at the vertical
      // centre of the rendered bounding box.
      //
      // EXCEPTION: noteheads must NOT get this correction, since they have to
      // line up exactly with the ledger lines.
      double baselineCorrection = 0.0;
      if (!options.centerVertically &&
          !options.alignTop &&
          !options.alignBottom &&
          !options.disableBaselineCorrection) {
        // Only correct when no vertical alignment was requested and the
        // correction was not explicitly disabled.
        // In Flutter Y+ points DOWN, so we SUBTRACT to move the glyph UP.
        baselineCorrection = -textPainter.height * 0.5;
      }

      final correctedY = finalY + baselineCorrection;

      textPainter.paint(
        canvas,
        Offset(finalX, correctedY),
      );
    }

    // Register the drawn bounds with the collision system (when enabled).
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

      collisionDetector!.register(
        id: '${glyphName}_${position.dx.toStringAsFixed(1)}_${position.dy.toStringAsFixed(1)}',
        bounds: bounds,
        category: _getCategoryForGlyph(glyphName, options),
        priority: options.collisionPriority ?? CollisionPriority.medium,
      );
    }
  }

  /// Draws a glyph with one of its SMuFL anchors placed on a target point.
  ///
  /// E.g. put the glyph's 'opticalCenter' exactly at `target`.
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
      // No such anchor: fall back to the default centring.
      drawGlyphWithBBox(
        canvas,
        glyphName: glyphName,
        position: target,
        color: color,
        options: options,
      );
      return;
    }

    // Convert the anchor from staff spaces to pixels.
    final anchorPx = Offset(
      anchor.dx * coordinates.staffSpace,
      -anchor.dy * coordinates.staffSpace,
    );

    // To land the anchor on the target, draw the glyph at (target - anchorPx).
    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: Offset(target.dx - anchorPx.dx, target.dy - anchorPx.dy),
      color: color,
      options: options.copyWith(
        // Anchor alignment generally needs no additional centring.
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

  /// Clears the TextPainter cache shared by every renderer.
  ///
  /// Delegates to [PerformanceOptimizer.clearGlyphCache]: the cache is
  /// process-wide, so this clears it for every renderer, not just this one.
  /// Needed when the font assets change; **not** needed on theme changes,
  /// since the colour is part of the cache key.
  void clearCache() {
    PerformanceOptimizer.clearGlyphCache();
  }

  /// Number of glyph painters alive in the shared cache
  /// ([PerformanceOptimizer.glyphCacheSize]).
  int get cacheSize => PerformanceOptimizer.glyphCacheSize;

  /// Picks the collision category from the glyph name and the draw options.
  CollisionCategory _getCategoryForGlyph(String glyphName, GlyphDrawOptions options) {
    // Map from the glyph name first.
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

    // Otherwise fall back to the category implied by the preset options.
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

/// Options for drawing a glyph.
class GlyphDrawOptions {
  /// Centre horizontally on the bounding-box centre.
  final bool centerHorizontally;

  /// Centre vertically on the bounding-box centre.
  final bool centerVertically;

  /// Align to the bounding box's left edge.
  final bool alignLeft;

  /// Align to the bounding box's right edge.
  final bool alignRight;

  /// Align to the bounding box's top edge.
  final bool alignTop;

  /// Align to the bounding box's bottom edge.
  final bool alignBottom;

  /// Custom size (when null, the renderer's default glyphSize is used).
  final double? size;

  /// Rotation in degrees (clockwise positive).
  final double rotation;

  /// Scale (1.0 = natural size).
  final double scale;

  /// Glyph to draw instead when the requested one is missing from the font.
  final String? fallbackGlyph;

  /// Bypass the shared painter cache (for glyphs that change every frame).
  final bool disableCache;

  /// Register the drawn bounds with the collision detector.
  final bool trackBounds;

  /// Collision priority (used when [trackBounds] is true).
  final CollisionPriority? collisionPriority;

  /// Disable the automatic baseline correction (needed by noteheads, which
  /// must sit exactly on the staff/ledger lines).
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

  /// Returns a copy with the given fields replaced.
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

  /// Defaults for noteheads.
  ///
  /// Critical: the baseline correction is REQUIRED to position notes correctly,
  /// because the stem anchors (stemUpSE, stemDownNW) are relative to the SMuFL
  /// baseline. Note that this introduces an offset on the augmentation dots,
  /// which DotRenderer compensates for.
  static const GlyphDrawOptions noteheadDefault = GlyphDrawOptions(
    centerHorizontally: false,
    centerVertically: false,
    // disableBaselineCorrection: false (the default) — required!
    trackBounds: true,
    collisionPriority: CollisionPriority.veryHigh,
  );

  /// Defaults for accidentals.
  ///
  /// Critical: centerVertically stays false, for consistency with the SMuFL
  /// baseline.
  static const GlyphDrawOptions accidentalDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true,
    collisionPriority: CollisionPriority.veryHigh,
  );

  /// Defaults for articulations.
  ///
  /// Critical: centerVertically stays false, for consistency with the SMuFL
  /// baseline.
  static const GlyphDrawOptions articulationDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // enabled so collision detection sees these glyphs
    collisionPriority: CollisionPriority.high,
  );

  /// Defaults for ornaments.
  ///
  /// Critical: centerVertically stays false, for consistency with the SMuFL
  /// baseline.
  static const GlyphDrawOptions ornamentDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // enabled so collision detection sees these glyphs
    collisionPriority: CollisionPriority.medium,
  );

  /// Defaults for rests.
  ///
  /// Critical: centerVertically stays false, for consistency with the SMuFL
  /// baseline.
  static const GlyphDrawOptions restDefault = GlyphDrawOptions(
    centerHorizontally: true,
    centerVertically: false,
    trackBounds: true, // enabled so collision detection sees these glyphs
    collisionPriority: CollisionPriority.high,
  );
}
