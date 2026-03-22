// lib/src/smufl/smufl_metadata_loader.dart

import 'dart:convert';
import 'package:flutter/material.dart' show Offset;
import 'package:flutter/services.dart' show rootBundle;
import 'smufl_coordinates.dart';

class SmuflMetadata {
  // Usaremos um Singleton para garantir que os dados sejam carregados apenas uma vez.
  static final SmuflMetadata _instance = SmuflMetadata._internal();
  factory SmuflMetadata() => _instance;

  SmuflMetadata._internal();

  Map<String, dynamic>? _metadata;
  Map<String, dynamic>? _glyphnames;
  final Map<String, SmuflGlyphInfo> _glyphInfoCache = {};
  bool _isLoaded = false;

  // CORREÇÃO: Cache de metadata carregados
  Map<String, dynamic>? _glyphsWithAnchors;
  Map<String, dynamic>? _glyphBBoxes;
  Map<String, dynamic>? _glyphAdvanceWidths;
  Map<String, dynamic>? _engravingDefaults;

  Future<void> load() async {
    if (_isLoaded) return;

    final metadataString = await rootBundle.loadString(
      'packages/flutter_notemus/assets/smufl/bravura_metadata.json',
    );
    _metadata = json.decode(metadataString);

    final glyphnamesString = await rootBundle.loadString(
      'packages/flutter_notemus/assets/smufl/glyphnames.json',
    );
    _glyphnames = json.decode(glyphnamesString);

    // NOVO: Carregar seções do metadata de forma estruturada
    _glyphsWithAnchors = _metadata?['glyphsWithAnchors'] as Map<String, dynamic>?;
    _glyphBBoxes = _metadata?['glyphBBoxes'] as Map<String, dynamic>?;
    _glyphAdvanceWidths = _metadata?['glyphAdvanceWidths'] as Map<String, dynamic>?;
    _engravingDefaults = _metadata?['engravingDefaults'] as Map<String, dynamic>?;

    _isLoaded = true;
  }

  // Função para obter o caractere Unicode a partir do nome do glifo
  String getCodepoint(String glyphName) {
    if (!_isLoaded || _glyphnames == null) return '';
    final codepointStr = _glyphnames![glyphName]?['codepoint'] as String?;
    if (codepointStr == null || codepointStr.isEmpty) return '';

    // Converte "U+E050" para o caractere Unicode real
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

  // Funções para obter dados de desenho
  double getEngravingDefault(String key) {
    if (!_isLoaded || _metadata == null) return 0.0;
    return (_metadata!['engravingDefaults'][key] as num).toDouble();
  }

  // CORREÇÃO 1: Getter que estava faltando
  bool get isNotLoaded => !_isLoaded;

  // CORREÇÃO 2: Método que estava faltando
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

  /// Obtém informações completas de um glifo, incluindo bounding box e anchors
  SmuflGlyphInfo? getGlyphInfo(String glyphName) {
    // Verifica cache primeiro
    if (_glyphInfoCache.containsKey(glyphName)) {
      return _glyphInfoCache[glyphName];
    }

    if (!_isLoaded || _glyphnames == null) return null;

    final glyphData = _glyphnames![glyphName] as Map<String, dynamic>?;
    if (glyphData == null) return null;

    // Cria informações básicas do glifo
    final codepoint = glyphData['codepoint'] as String? ?? '';
    final description = glyphData['description'] as String? ?? '';

    // Obtém bounding box se disponível
    GlyphBoundingBox? boundingBox;
    if (_glyphBBoxes != null && _glyphBBoxes![glyphName] != null) {
      final bboxData = _glyphBBoxes![glyphName] as Map<String, dynamic>?;
      if (bboxData != null) {
        boundingBox = GlyphBoundingBox.fromMetadata(bboxData);
      }
    }

    // Obtém anchors se disponível
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

    // Cache para uso futuro
    _glyphInfoCache[glyphName] = glyphInfo;
    return glyphInfo;
  }

  /// NOVO: Obtém um anchor específico de um glyph
  /// @param glyphName Nome do glyph SMuFL
  /// @param anchorName Nome do anchor (ex: 'stemUpSE', 'stemDownNW')
  /// @return Offset em staff spaces, ou null se não encontrado
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

  /// NOVO: Obtém advance width de um glyph em staff spaces
  double? getGlyphAdvanceWidth(String glyphName) {
    if (!_isLoaded || _glyphAdvanceWidths == null) return null;

    final width = _glyphAdvanceWidths![glyphName];
    if (width is num) {
      return width.toDouble();
    }

    return null;
  }

  /// NOVO: Obtém um engraving default específico
  /// @param key Nome do parâmetro (ex: 'stemThickness', 'beamThickness')
  /// @return Valor em staff spaces
  double? getEngravingDefaultValue(String key) {
    if (!_isLoaded || _engravingDefaults == null) return null;

    final value = _engravingDefaults![key];
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  /// NOVO: Obtém todos os engraving defaults
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

  /// Obtém bounding box de um glifo como objeto
  GlyphBoundingBox? getGlyphBoundingBox(String glyphName) {
    return getGlyphInfo(glyphName)?.boundingBox;
  }

  /// Obtém anchors de um glifo
  GlyphAnchors? getGlyphAnchors(String glyphName) {
    return getGlyphInfo(glyphName)?.anchors;
  }

  /// Obtém largura de um glifo em unidades SMuFL
  /// Usa advance width se disponível, senão usa bounding box width
  double getGlyphWidth(String glyphName) {
    // Preferir advance width (mais preciso para espaçamento)
    final advanceWidth = getGlyphAdvanceWidth(glyphName);
    if (advanceWidth != null) return advanceWidth;

    // Fallback para bounding box
    return getGlyphBoundingBox(glyphName)?.width ?? 0.0;
  }

  /// Obtém altura de um glifo em unidades SMuFL
  double getGlyphHeight(String glyphName) {
    return getGlyphBoundingBox(glyphName)?.height ?? 0.0;
  }

  /// Obtém largura de um glifo em pixels
  double getGlyphWidthInPixels(String glyphName, double staffSpace) {
    return getGlyphBoundingBox(glyphName)?.widthInPixels(staffSpace) ?? 0.0;
  }

  /// Obtém altura de um glifo em pixels
  double getGlyphHeightInPixels(String glyphName, double staffSpace) {
    return getGlyphBoundingBox(glyphName)?.heightInPixels(staffSpace) ?? 0.0;
  }

  /// Verifica se um glifo existe na fonte
  bool hasGlyph(String glyphName) {
    return _glyphnames?.containsKey(glyphName) ?? false;
  }

  /// Obtém todos os nomes de glifos disponíveis
  List<String> getAllGlyphNames() {
    return _glyphnames?.keys.toList() ?? [];
  }

  /// Obtém glifos por categoria
  List<String> getGlyphsByCategory(String category) {
    final allGlyphs = getAllGlyphNames();
    return allGlyphs.where((glyph) => glyph.startsWith(category)).toList();
  }

  /// Busca glifos por padrão
  List<String> searchGlyphs(String pattern) {
    final allGlyphs = getAllGlyphNames();
    final regex = RegExp(pattern, caseSensitive: false);
    return allGlyphs.where((glyph) => regex.hasMatch(glyph)).toList();
  }

  /// Obtém informações de classes de glifos (se disponível nos metadados)
  Map<String, List<String>>? getGlyphClasses() {
    if (!_isLoaded || _metadata == null) return null;
    return _metadata!['glyphClasses'] as Map<String, List<String>>?;
  }

  /// Obtém conjuntos estilísticos (se disponível nos metadados)
  Map<String, dynamic>? getStylisticSets() {
    if (!_isLoaded || _metadata == null) return null;
    return _metadata!['stylisticSets'] as Map<String, dynamic>?;
  }

  /// Limpa o cache de glifos
  void clearCache() {
    _glyphInfoCache.clear();
  }
}
