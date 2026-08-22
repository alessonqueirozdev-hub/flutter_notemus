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

  /// Diatonic step (in font units) used when the Pes family cannot be measured
  /// — the value measured on the pinned greciliae.ttf.
  static const double fallbackDiatonicStepUnits = 157.5;

  Map<String, int>? _cp; // glyph name -> codepoint
  Map<String, int>? _adv; // glyph name -> advance width (font units)
  Map<String, double>? _centerY; // glyph name -> bbox vertical center (units)
  double? _stepUnits; // memoized diatonicStepUnits()
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
    _stepUnits = null;
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

  /// Vertical center of a glyph's bounding box, or null when the glyph (or its
  /// bounding box) is absent from the shipped metrics.
  double? centerYUnitsOrNull(String name) => _centerY?[name];

  /// One diatonic step, in font units, MEASURED from the font's own metrics.
  ///
  /// Method: the precomposed `Pes<N>Nothing` glyphs draw a two-note rising
  /// neume whose ambitus is N diatonic steps. Their lower note is fixed, so
  /// raising the ambitus by one step raises the bounding box CENTER by half a
  /// step. Taking the median of the center deltas across
  /// PesTwo→PesThree→PesFour→PesFive and doubling it therefore yields the full
  /// diatonic step in font units.
  ///
  /// `PesOneNothing` is deliberately excluded: its two notes touch, so the
  /// glyph is drawn as a different shape and its center does not follow the
  /// same arithmetic progression (its delta to PesTwo is ≈71.5 rather than 79).
  ///
  /// Falls back to [fallbackDiatonicStepUnits] when fewer than two glyphs of the
  /// family carry metrics (e.g. the font is not loaded yet). The result is
  /// memoized and reset by [load].
  double diatonicStepUnits() {
    final cached = _stepUnits;
    if (cached != null) return cached;
    const family = [
      'PesTwoNothing',
      'PesThreeNothing',
      'PesFourNothing',
      'PesFiveNothing',
    ];
    final deltas = <double>[];
    for (var i = 1; i < family.length; i++) {
      // Only ADJACENT pairs count: a missing glyph must not turn into a
      // double-width step.
      final lo = _centerY?[family[i - 1]];
      final hi = _centerY?[family[i]];
      if (lo == null || hi == null) continue;
      deltas.add(hi - lo);
    }
    if (deltas.isEmpty) return fallbackDiatonicStepUnits;
    deltas.sort();
    final mid = deltas.length ~/ 2;
    final median = deltas.length.isOdd
        ? deltas[mid]
        : (deltas[mid - 1] + deltas[mid]) / 2.0;
    final step = median * 2.0;
    if (!step.isFinite || step <= 0) return fallbackDiatonicStepUnits;
    if (isLoaded) _stepUnits = step;
    return step;
  }
}
