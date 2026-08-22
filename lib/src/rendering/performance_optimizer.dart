// lib/src/rendering/performance_optimizer.dart

import 'package:flutter/material.dart';
import '../layout/layout_engine.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../utils/lru_cache.dart';

/// Owner of the render-time caches shared by every SMuFL renderer.
///
/// **Where this is used**
///
/// * [BaseGlyphRenderer] (`lib/src/rendering/renderers/base_glyph_renderer.dart`)
///   — and therefore every concrete glyph renderer, since they all inherit
///   from it — asks [glyphPainter] for the [TextPainter] of each glyph it
///   draws, instead of building (and laying out) a new one on every frame.
/// * [drawOptimizedSmuflText] is a one-call convenience built on the same
///   cache for painters that only need "draw this character here".
/// * [optimizeRenderOrder] and [getStaffLinesPath] are helpers for painters
///   that batch a whole system.
///
/// Everything is static: the caches are process-wide on purpose, because the
/// same glyph/size/colour combination is drawn by many renderer instances and
/// by successive frames of the same widget.
///
/// ## Cache key and invalidation policy
///
/// The key of a cached [TextPainter] is built by [glyphPainterKey] from
/// **every parameter that can change the text layout**:
///
/// * the character (the SMuFL codepoint actually painted),
/// * the [SmuflFontDescriptor] — family plus owning package — so two music
///   fonts loaded side by side never share a cached painter,
/// * the font size, quantised by [quantizeFontSize] to
///   [fontSizeQuantum] so that float noise (`12.000000000000002`) does not
///   fill the cache with duplicates,
/// * the colour (`Color.toARGB32()`), which the painter bakes into its
///   [TextSpan].
///
/// Every other property of the span — `height: 1.0`, `letterSpacing: 0.0`,
/// `TextDirection.ltr` — is a constant of [buildGlyphPainter], which is the
/// only place a glyph painter is ever constructed. That is what makes the key
/// complete: two calls with the same key necessarily produce the same layout.
///
/// A cached painter is laid out once, in [buildGlyphPainter], and is **never
/// mutated afterwards** ([TextPainter.paint] does not change it), so reusing
/// one inside the same frame is safe. Never call `layout()` or reassign `text`
/// on a painter obtained from [glyphPainter]; if a caller needs a painter it
/// intends to mutate, it must build its own with [buildGlyphPainter].
///
/// Entries leave the cache in three ways:
///
/// 1. **LRU eviction** — the cache holds [glyphPainterCacheCapacity] entries
///    (~256, a couple of MB at most); the least recently used one is dropped.
/// 2. **[clearGlyphCache] / [clearCaches]** — call these when the font assets
///    change (a new SMuFL font is registered, a hot reload swaps them) or to
///    reclaim memory. A theme change does *not* require clearing: the colour
///    is part of the key, so new colours simply produce new entries and the
///    stale ones age out.
/// 3. Never implicitly: a painter is not invalidated by time or by frames.
class PerformanceOptimizer {
  /// SMuFL font assumed when a caller does not name one.
  ///
  /// This is the *fallback*, not a hard-wired choice: every entry point below
  /// takes a [SmuflFontDescriptor], and the renderers always pass the one their
  /// [SmuflMetadata] was loaded with, so a score engraved with Petaluma or
  /// Leland is painted with that font's family/package — never this default.
  static const SmuflFontDescriptor defaultGlyphFont =
      SmuflFontDescriptor.bravura;

  /// Family of [defaultGlyphFont] (convenience for callers and tests).
  static String get defaultGlyphFontFamily => defaultGlyphFont.fontFamily;

  /// Package shipping [defaultGlyphFontFamily], or null for an app font.
  static String? get defaultGlyphFontPackage => defaultGlyphFont.fontPackage;

  /// Maximum number of [TextPainter]s kept alive.
  ///
  /// A score rarely uses more than a few dozen glyph/size/colour combinations,
  /// so 256 gives a hit rate above 90% while bounding memory to a few MB.
  static const int glyphPainterCacheCapacity = 256;

  /// Font sizes are rounded to this many decimals before being used as part
  /// of a cache key (and to build the painter), collapsing float noise.
  static const int fontSizeQuantum = 4;

  /// Cache size limit for the geometry caches.
  static const int maxCacheSize = 500;

  static final LruCache<String, TextPainter> _glyphPainters =
      LruCache<String, TextPainter>(glyphPainterCacheCapacity);

  static final LruCache<String, Path> _pathCache =
      LruCache<String, Path>(maxCacheSize);

  static int _glyphCacheHits = 0;
  static int _glyphCacheMisses = 0;

  static List<PositionedElement> optimizeRenderOrder(
    List<PositionedElement> elements,
  ) {
    // Sort elements to render from bottom to top
    final sorted = List<PositionedElement>.from(elements);
    sorted.sort((a, b) {
      // First by system
      final systemComp = a.system.compareTo(b.system);
      if (systemComp != 0) return systemComp;

      // Then by Y position
      return a.position.dy.compareTo(b.position.dy);
    });
    return sorted;
  }

  static Path getStaffLinesPath(double width, double staffSpace, double y) {
    final key = 'staff_${width}_${staffSpace}_$y';
    final cached = _pathCache.get(key);
    if (cached != null) return cached;

    final path = Path();
    for (int i = 0; i < 5; i++) {
      final lineY = y + (i * staffSpace);
      path.moveTo(0, lineY);
      path.lineTo(width, lineY);
    }

    _pathCache.put(key, path);
    return path;
  }

  static Paint getPaint(Color color, double strokeWidth) {
    return Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
  }

  static void returnPaint(Paint paint) {
    // Method kept for compatibility, but does nothing
    // since we are not pooling Paint objects
  }

  /// Rounds [fontSize] to [fontSizeQuantum] decimals.
  ///
  /// Used for the cache key *and* for the painter itself, so a cached painter
  /// always matches its key exactly (the quantum is 0.0001 px, far below any
  /// visible difference).
  static double quantizeFontSize(double fontSize) {
    return double.parse(fontSize.toStringAsFixed(fontSizeQuantum));
  }

  /// The cache key of a glyph painter.
  ///
  /// Exposed so that tests (and callers doing their own bookkeeping) can reason
  /// about cache identity. See the class docs for why these fields are enough.
  static String glyphPainterKey({
    required String character,
    required double fontSize,
    required Color color,
    SmuflFontDescriptor font = defaultGlyphFont,
  }) {
    final size = quantizeFontSize(fontSize);
    return '${font.fontFamily}|${font.fontPackage ?? ''}'
        '|$character|$size|${color.toARGB32()}';
  }

  /// Builds a **fresh**, laid-out [TextPainter] for a SMuFL glyph.
  ///
  /// Bypasses the cache: use it when the caller intends to mutate the painter
  /// (or explicitly disabled caching). Every constant that affects layout is
  /// set here and only here — see the class docs on key completeness.
  static TextPainter buildGlyphPainter({
    required String character,
    required double fontSize,
    required Color color,
    SmuflFontDescriptor font = defaultGlyphFont,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontFamily: font.fontFamily,
          package: font.fontPackage,
          fontSize: quantizeFontSize(fontSize),
          color: color,
          height: 1.0,
          letterSpacing: 0.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  /// Returns the shared, laid-out [TextPainter] for a SMuFL glyph.
  ///
  /// The painter is created on the first call and reused afterwards. **Do not
  /// mutate it** (no `layout()`, no `text =`): several renderers and several
  /// draw calls of the same frame share the very same instance. Painting is a
  /// read-only operation, so drawing the same painter many times per frame is
  /// safe.
  static TextPainter glyphPainter({
    required String character,
    required double fontSize,
    required Color color,
    SmuflFontDescriptor font = defaultGlyphFont,
  }) {
    final key = glyphPainterKey(
      character: character,
      fontSize: fontSize,
      color: color,
      font: font,
    );

    final cached = _glyphPainters.get(key);
    if (cached != null) {
      _glyphCacheHits++;
      return cached;
    }

    _glyphCacheMisses++;
    final painter = buildGlyphPainter(
      character: character,
      fontSize: fontSize,
      color: color,
      font: font,
    );
    _glyphPainters.put(key, painter);
    return painter;
  }

  /// Draws a SMuFL character reusing the shared painter cache.
  ///
  /// [position] is the top-left corner passed to [TextPainter.paint]; callers
  /// that need SMuFL bounding-box alignment should use
  /// `BaseGlyphRenderer.drawGlyphWithBBox` instead.
  static void drawOptimizedSmuflText({
    required Canvas canvas,
    required String character,
    required Offset position,
    required double size,
    required Color color,
    SmuflFontDescriptor font = defaultGlyphFont,
  }) {
    glyphPainter(
      character: character,
      fontSize: size,
      color: color,
      font: font,
    ).paint(canvas, position);
  }

  /// Number of glyph painters currently alive in the cache.
  static int get glyphCacheSize => _glyphPainters.size;

  /// Number of glyph lookups served from the cache since the last reset.
  static int get glyphCacheHits => _glyphCacheHits;

  /// Number of glyph lookups that had to build a painter since the last reset.
  static int get glyphCacheMisses => _glyphCacheMisses;

  /// Hit rate in `[0, 1]` (`0` when no lookup happened yet).
  static double get glyphCacheHitRate {
    final total = _glyphCacheHits + _glyphCacheMisses;
    return total == 0 ? 0.0 : _glyphCacheHits / total;
  }

  /// Zeroes the hit/miss counters without touching the cached painters.
  static void resetGlyphCacheStats() {
    _glyphCacheHits = 0;
    _glyphCacheMisses = 0;
  }

  /// Drops every cached glyph painter (and the hit/miss counters).
  ///
  /// Call after registering or replacing font assets. Not needed for theme
  /// changes: the colour is part of the key.
  static void clearGlyphCache() {
    _glyphPainters.clear();
    resetGlyphCacheStats();
  }

  /// Drops every cache owned by this class.
  static void clearCaches() {
    _pathCache.clear();
    clearGlyphCache();
  }
}
