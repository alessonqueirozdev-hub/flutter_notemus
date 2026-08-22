// lib/src/smufl/smufl_metadata_loader.dart

import 'dart:convert';
import 'package:flutter/material.dart' show Offset;
import 'package:flutter/services.dart' show rootBundle;
import 'smufl_coordinates.dart';

/// Identifies one SMuFL-compliant music font: the family name Flutter should
/// draw with, plus the two JSON files the SMuFL spec defines.
///
/// The package ships Bravura ([SmuflFontDescriptor.bravura]), but nothing in
/// the engine is Bravura-specific: every metric comes from `engravingDefaults`,
/// `glyphBBoxes`, `glyphAdvanceWidths` and `glyphsWithAnchors`. Point this at
/// Petaluma, Leland, Sebastian or a house font and the renderer follows.
class SmuflFontDescriptor {
  /// Flutter font family used to draw the glyphs.
  final String fontFamily;

  /// Package that owns [fontFamily], or null for an application font.
  final String? fontPackage;

  /// Asset key of the font's `*_metadata.json` (SMuFL font metadata).
  final String metadataAsset;

  /// Asset key of `glyphnames.json` (SMuFL glyph name to codepoint map).
  final String glyphNamesAsset;

  const SmuflFontDescriptor({
    required this.fontFamily,
    required this.metadataAsset,
    required this.glyphNamesAsset,
    this.fontPackage,
  });

  /// The font bundled with this package.
  static const SmuflFontDescriptor bravura = SmuflFontDescriptor(
    fontFamily: 'Bravura',
    fontPackage: 'flutter_notemus',
    metadataAsset:
        'packages/flutter_notemus/assets/smufl/bravura_metadata.json',
    glyphNamesAsset: 'packages/flutter_notemus/assets/smufl/glyphnames.json',
  );

  /// Family string to hand to a [TextStyle], package-qualified when needed.
  String get resolvedFamily =>
      fontPackage == null ? fontFamily : 'packages/$fontPackage/$fontFamily';

  @override
  String toString() => 'SmuflFontDescriptor($fontFamily)';
}

class SmuflMetadata {
  /// Process-wide default instance (Bravura), kept for backwards
  /// compatibility: `SmuflMetadata()` returns it.
  static final SmuflMetadata _instance = SmuflMetadata._internal();
  factory SmuflMetadata() => _instance;

  /// Creates an INDEPENDENT loader, so an app can hold several music fonts at
  /// once (or load a different one in a test) instead of being pinned to the
  /// single global Bravura instance.
  SmuflMetadata.forFont(SmuflFontDescriptor font) : _font = font;

  SmuflMetadata._internal();

  SmuflFontDescriptor _font = SmuflFontDescriptor.bravura;

  /// The font this instance describes.
  SmuflFontDescriptor get font => _font;

  Map<String, dynamic>? _metadata;
  Map<String, dynamic>? _glyphnames;
  final Map<String, SmuflGlyphInfo> _glyphInfoCache = {};
  bool _isLoaded = false;
  Future<void>? _loading;

  // Cached metadata sections
  Map<String, dynamic>? _glyphsWithAnchors;
  Map<String, dynamic>? _glyphBBoxes;
  Map<String, dynamic>? _glyphAdvanceWidths;
  Map<String, dynamic>? _engravingDefaults;

  /// Loads (once) the SMuFL metadata for [font], or for this instance's font.
  ///
  /// Concurrent calls share one in-flight future: the previous implementation
  /// checked a plain bool, so two simultaneous callers both hit `rootBundle`
  /// and briefly observed a half-populated loader.
  Future<void> load({SmuflFontDescriptor? font}) {
    if (font != null && font != _font) {
      _font = font;
      _isLoaded = false;
      _loading = null;
      _glyphInfoCache.clear();
    }
    if (_isLoaded) return Future<void>.value();
    return _loading ??= _loadNow();
  }

  Future<void> _loadNow() async {
    final metadataString = await rootBundle.loadString(_font.metadataAsset);
    _metadata = json.decode(metadataString);

    final glyphnamesString = await rootBundle.loadString(_font.glyphNamesAsset);
    _glyphnames = json.decode(glyphnamesString);

    // Load metadata sections in a structured way
    _glyphsWithAnchors = _metadata?['glyphsWithAnchors'] as Map<String, dynamic>?;
    _glyphBBoxes = _metadata?['glyphBBoxes'] as Map<String, dynamic>?;
    _glyphAdvanceWidths = _metadata?['glyphAdvanceWidths'] as Map<String, dynamic>?;
    _engravingDefaults = _metadata?['engravingDefaults'] as Map<String, dynamic>?;

    _isLoaded = true;
    _loading = null;
  }

  // Returns the Unicode character for a given glyph name
  String getCodepoint(String glyphName) {
    if (!_isLoaded || _glyphnames == null) return '';
    final codepointStr = _glyphnames![glyphName]?['codepoint'] as String?;
    if (codepointStr == null || codepointStr.isEmpty) return '';

    // Converts "U+E050" to the actual Unicode character
    if (codepointStr.startsWith('U+')) {
      final hexValue = codepointStr.substring(2);
      try {
        final codeUnit = int.parse(hexValue, radix: 16);
        return String.fromCharCode(codeUnit);
      } catch (e) {
        return '';
      }
    }
    return codepointStr;
  }

  // Functions to retrieve drawing data
  //
  // Null-safe: returns [fallback] when metadata is not loaded, the
  // `engravingDefaults` section is absent, or the key is missing/non-numeric.
  // Previously this threw on a missing section/key (unchecked `as num` on null).
  double getEngravingDefault(String key, [double fallback = 0.0]) {
    if (!_isLoaded) return fallback;
    final value = _engravingDefaults?[key];
    if (value is num) return value.toDouble();
    return fallback;
  }

  // Missing getter added
  bool get isNotLoaded => !_isLoaded;

  // Missing method added
  Map<String, List<double>>? getGlyphBBox(String glyphName) {
    if (isNotLoaded || _metadata == null) return null;
    if (!_metadata!['glyphBBoxes'].containsKey(glyphName)) return null;

    return (_metadata!['glyphBBoxes'][glyphName] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(
        key,
        (value as List).map((e) => (e as num).toDouble()).toList(),
      ),
    );
  }

  /// Returns complete information for a glyph, including bounding box and anchors
  SmuflGlyphInfo? getGlyphInfo(String glyphName) {
    // Checks cache first
    if (_glyphInfoCache.containsKey(glyphName)) {
      return _glyphInfoCache[glyphName];
    }

    if (!_isLoaded || _glyphnames == null) return null;

    final glyphData = _glyphnames![glyphName] as Map<String, dynamic>?;
    if (glyphData == null) return null;

    // Creates informações básicas of the glifo
    final codepoint = glyphData['codepoint'] as String? ?? '';
    final description = glyphData['description'] as String? ?? '';

    // Gets bounding box if disponível
    GlyphBoundingBox? boundingBox;
    if (_glyphBBoxes != null && _glyphBBoxes![glyphName] != null) {
      final bboxData = _glyphBBoxes![glyphName] as Map<String, dynamic>?;
      if (bboxData != null) {
        boundingBox = GlyphBoundingBox.fromMetadata(bboxData);
      }
    }

    // Gets anchors if disponível
    GlyphAnchors? anchors;
    if (_glyphsWithAnchors != null && _glyphsWithAnchors![glyphName] != null) {
      final anchorsData = _glyphsWithAnchors![glyphName] as Map<String, dynamic>?;
      if (anchorsData != null) {
        anchors = GlyphAnchors.fromMetadata(anchorsData);
      }
    }

    final glyphInfo = SmuflGlyphInfo(
      name: glyphName,
      codepoint: codepoint,
      description: description,
      boundingBox: boundingBox,
      anchors: anchors,
    );

    // Cache for uso futuro
    _glyphInfoCache[glyphName] = glyphInfo;
    return glyphInfo;
  }

  /// New: Gets a anchor específico de a glyph
  /// @param glyphName SMuFL glyph name
  /// @param anchorName Anchor name (ex: 'stemUpSE', 'stemDownNW')
  /// @return Offset in staff spaces, or null if not encontrado
  Offset? getGlyphAnchor(String glyphName, String anchorName) {
    if (!_isLoaded || _glyphsWithAnchors == null) {
      return null;
    }

    final glyphData = _glyphsWithAnchors![glyphName] as Map<String, dynamic>?;
    if (glyphData == null) {
      return null;
    }

    final anchorData = glyphData[anchorName];
    if (anchorData is List && anchorData.length >= 2) {
      final x = (anchorData[0] as num).toDouble();
      final y = (anchorData[1] as num).toDouble();
      final result = Offset(x, y);
      return result;
    }

    return null;
  }

  /// New: Gets advance width de a glyph in staff spaces
  double? getGlyphAdvanceWidth(String glyphName) {
    if (!_isLoaded || _glyphAdvanceWidths == null) return null;

    final width = _glyphAdvanceWidths![glyphName];
    if (width is num) {
      return width.toDouble();
    }

    return null;
  }

  /// New: Gets a engraving default específico
  /// @param key Parameter name (ex: 'stemThickness', 'beamThickness')
  /// @return Value in staff spaces
  double? getEngravingDefaultValue(String key) {
    if (!_isLoaded || _engravingDefaults == null) return null;

    final value = _engravingDefaults![key];
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  /// New: Gets all os engraving defaults
  Map<String, double> getAllEngravingDefaults() {
    if (!_isLoaded || _engravingDefaults == null) return {};

    final defaults = <String, double>{};
    for (final entry in _engravingDefaults!.entries) {
      if (entry.value is num) {
        defaults[entry.key] = (entry.value as num).toDouble();
      }
    }

    return defaults;
  }

  /// Gets bounding box de a glifo as object
  GlyphBoundingBox? getGlyphBoundingBox(String glyphName) {
    return getGlyphInfo(glyphName)?.boundingBox;
  }

  /// Gets anchors de a glifo
  GlyphAnchors? getGlyphAnchors(String glyphName) {
    return getGlyphInfo(glyphName)?.anchors;
  }

  /// Gets width de a glifo in SMuFL units
  /// Uses advance width if disponível, senão Uses bounding box width
  double getGlyphWidth(String glyphName) {
    // Preferir advance width (more preciso for spacing)
    final advanceWidth = getGlyphAdvanceWidth(glyphName);
    if (advanceWidth != null) return advanceWidth;

    // Fallback for bounding box
    return getGlyphBoundingBox(glyphName)?.width ?? 0.0;
  }

  /// Gets height de a glifo in SMuFL units
  double getGlyphHeight(String glyphName) {
    return getGlyphBoundingBox(glyphName)?.height ?? 0.0;
  }

  /// Gets width de a glifo in pixels
  double getGlyphWidthInPixels(String glyphName, double staffSpace) {
    return getGlyphBoundingBox(glyphName)?.widthInPixels(staffSpace) ?? 0.0;
  }

  /// Gets height de a glifo in pixels
  double getGlyphHeightInPixels(String glyphName, double staffSpace) {
    return getGlyphBoundingBox(glyphName)?.heightInPixels(staffSpace) ?? 0.0;
  }

  /// Checks if a glifo existe na fonte
  bool hasGlyph(String glyphName) {
    return _glyphnames?.containsKey(glyphName) ?? false;
  }

  /// Gets all os glyph names disponíveis
  List<String> getAllGlyphNames() {
    return _glyphnames?.keys.toList() ?? [];
  }

  /// Gets glifos by categoria
  List<String> getGlyphsByCategory(String category) {
    final allGlyphs = getAllGlyphNames();
    return allGlyphs.where((glyph) => glyph.startsWith(category)).toList();
  }

  /// Finds glifos by default
  List<String> searchGlyphs(String pattern) {
    final allGlyphs = getAllGlyphNames();
    final regex = RegExp(pattern, caseSensitive: false);
    return allGlyphs.where((glyph) => regex.hasMatch(glyph)).toList();
  }

  /// Gets informações de classs de glifos (if disponível nos metadados)
  Map<String, List<String>>? getGlyphClasses() {
    if (!_isLoaded || _metadata == null) return null;
    return _metadata!['glyphClasses'] as Map<String, List<String>>?;
  }

  /// Gets conjuntos estilísticos (if disponível nos metadados)
  Map<String, dynamic>? getStylisticSets() {
    if (!_isLoaded || _metadata == null) return null;
    return _metadata!['stylisticSets'] as Map<String, dynamic>?;
  }

  /// Limpa o cache de glifos
  void clearCache() {
    _glyphInfoCache.clear();
  }
}
