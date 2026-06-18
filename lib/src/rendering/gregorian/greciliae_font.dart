// Loads the Greciliae chant font's glyph-name -> codepoint map.
//
// Greciliae's neume glyphs live in the Private Use Area with build-order
// codepoints (not a stable standard), but their NAMES are deterministic
// (Punctum, PesTwoNothing, FlexusTwoNothing, TorculusTwoTwoNothing, ...). The
// map is extracted once from the pinned greciliae.ttf with fontTools and shipped
// as `assets/gregorian/greciliae_glyphnames.json` (name -> codepoint int).

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class GreciliaeFont {
  static final GreciliaeFont _instance = GreciliaeFont._();
  factory GreciliaeFont() => _instance;
  GreciliaeFont._();

  /// Font design units per em (Greciliae = 1000).
  static const double unitsPerEm = 1000.0;

  Map<String, int>? _cp; // glyph name -> codepoint
  Map<String, int>? _adv; // glyph name -> advance width (font units)
  Map<String, double>? _centerY; // glyph name -> bbox vertical center (units)
  bool get isLoaded => _cp != null;

  Future<void> load() async {
    if (_cp != null) return;
    final raw = await rootBundle.loadString(
      'packages/flutter_notemus/assets/gregorian/greciliae_glyphnames.json',
    );
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final cp = <String, int>{};
    final adv = <String, int>{};
    final centerY = <String, double>{};
    decoded.forEach((name, v) {
      final list = v as List;
      cp[name] = (list[0] as num).toInt();
      adv[name] = (list[1] as num).toInt();
      if (list.length >= 4) {
        centerY[name] = ((list[2] as num) + (list[3] as num)) / 2.0;
      }
    });
    _cp = cp;
    _adv = adv;
    _centerY = centerY;
  }

  /// The codepoint for a glyph [name], or null if absent.
  int? codepoint(String name) => _cp?[name];

  /// The character string for a glyph [name], or null if absent.
  String? glyph(String name) {
    final c = _cp?[name];
    return c == null ? null : String.fromCharCode(c);
  }

  /// Advance width of a glyph [name] in font units (0 if absent).
  int advanceUnits(String name) => _adv?[name] ?? 0;

  /// Vertical center of a glyph's bounding box in font units (0 if absent).
  double centerYUnits(String name) => _centerY?[name] ?? 0.0;

  /// Whether a glyph [name] exists in the font.
  bool has(String name) => _cp?.containsKey(name) ?? false;
}
