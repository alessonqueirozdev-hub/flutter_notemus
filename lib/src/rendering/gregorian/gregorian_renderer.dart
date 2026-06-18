// Gregorian (square-notation) renderer using the Greciliae chant font.
//
// Greciliae (SIL OFL, from the Gregorio project) ships PRECOMPOSED neume glyphs
// designed by chant typographers — one glyph for a pes/clivis(flexus)/torculus/
// porrectus/scandicus of a given ambitus. We pick the glyph by NAME from the
// neume contour (the ambitus = diatonic step interval), place ONE glyph per
// neume at its first note, and assemble only the descending climacus from
// Punctum + PunctumInclinatum. Pitch is RELATIVE to the clef line (chant has no
// fixed pitch); the melodic contour is centered on the staff.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

import 'greciliae_font.dart';

/// Visual configuration for the Gregorian renderer.
class GregorianTheme {
  final Color color;

  /// Pixels per staff space (≈ the inter-line gap).
  final double staffSpace;

  final double lyricSize;
  final String? lyricTextFamily;

  const GregorianTheme({
    this.color = const Color(0xFF1A1A1A),
    this.staffSpace = 26.0,
    this.lyricSize = 15.0,
    this.lyricTextFamily,
  });
}

enum ChantClefType { doClef, faClef }

class ChantClef {
  final ChantClefType type;

  /// Staff line the clef sits on, 1 (bottom) .. 4 (top). Default: top line.
  final int line;
  const ChantClef({this.type = ChantClefType.doClef, this.line = 4});

  String get glyphName => type == ChantClefType.doClef ? 'CClef' : 'FClef';
}

// ── Greciliae geometry calibration (font units; unitsPerEm = 1000) ──
// Glyphs scale with fontSize = staffSpace * _fontScale. One diatonic step is
// _unitsPerStep font units (measured from PesOne..PesThree ambitus increments).
// _firstNoteAnchor is the font-y of the first/reference note's center above the
// glyph origin (used to seat the note on its staff line/space).
const double _fontScale = 3.4; // -> inter-line gap ≈ staffSpace
const double _unitsPerStep = 147.0;
const double _firstNoteAnchor = 70.0;

int _diatonic(String step, int octave) {
  const order = 'CDEFGAB';
  final i = order.indexOf(step.toUpperCase());
  return octave * 7 + (i < 0 ? 0 : i);
}

const _words = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven'];
String? _word(int n) => (n >= 1 && n < _words.length) ? _words[n] : null;

/// A single positioned glyph within a neume (placed so its first-note anchor
/// lands at staff [step], at x offset [dx]).
class _GlyphOp {
  final String name;
  final int step;
  final double dx;
  _GlyphOp(this.name, this.step, this.dx);
}

/// A rhythmic sign attached to one component (episema, ictus, mora dot).
enum _MarkType { episema, ictus, ictusAbove, mora }

class _Mark {
  final _MarkType type;
  final int step;

  /// Center-x of the mark within the neume box (px).
  final double dx;
  _Mark(this.type, this.step, this.dx);
}

class _NeumeBox {
  final List<_GlyphOp> glyphs;
  final List<_Mark> marks;
  final double width;
  final String? syllable;
  final int firstStep;
  double startX = 0;
  _NeumeBox(this.glyphs, this.marks, this.width, this.syllable, this.firstStep);
  double get endX => startX + width;
}

class _Divisio {
  final NeumeDivisionType type;
  double x = 0;
  _Divisio(this.type);
}

class _Row {
  final List<Object> items = []; // _NeumeBox | _Divisio
  int? custosStep;
  double lineEnd = 0;
}

/// Single-note glyph name by form.
String _singleGlyph(NcForm form) => switch (form) {
      NcForm.virga => 'Virga',
      NcForm.quilisma => 'Quilisma',
      NcForm.oriscus => 'AscendensOriscus',
      NcForm.stropha => 'Stropha',
      _ => 'Punctum',
    };

/// Picks the precomposed Greciliae glyph name for a neume, or null if it must be
/// assembled from components. When [liquescent], prefers the diminished
/// (`Deminutus`) variant — the epiphonus (pes), cephalicus (clivis), etc. —
/// falling back to the full (`Nothing`) form if that ambitus has no liquescent
/// glyph. The returned name is guaranteed present in [font].
String? _neumeGlyphName(NeumeType type, List<int> steps, List<NcForm> forms,
    bool liquescent, GreciliaeFont font) {
  int up(int i, int j) => steps[j] - steps[i];
  int dn(int i, int j) => steps[i] - steps[j];
  final suffix = liquescent ? 'Deminutus' : 'Nothing';
  String? pick(String shape, String? amb) {
    if (amb == null) return null;
    final want = '$shape$amb$suffix';
    if (font.has(want)) return want;
    final alt = '$shape${amb}Nothing';
    return font.has(alt) ? alt : null;
  }

  switch (type) {
    case NeumeType.pes:
      return pick('Pes', _word(up(0, 1)));
    case NeumeType.clivis:
      return pick('Flexus', _word(dn(0, 1)));
    case NeumeType.torculus:
      final a = _word(up(0, 1)), b = _word(dn(1, 2));
      return (a == null || b == null) ? null : pick('Torculus', '$a$b');
    case NeumeType.porrectus:
      final a = _word(dn(0, 1)), b = _word(up(1, 2));
      return (a == null || b == null) ? null : pick('Porrectus', '$a$b');
    case NeumeType.scandicus:
      final a = _word(up(0, 1)), b = _word(up(1, 2));
      return (a == null || b == null) ? null : pick('Scandicus', '$a$b');
    case NeumeType.salicus:
      final a = _word(up(0, 1)), b = _word(up(1, 2));
      return (a == null || b == null) ? null : pick('Salicus', '$a$b');
    case NeumeType.torculusResupinus:
      if (steps.length < 4) return null;
      final a = _word(up(0, 1)), b = _word(dn(1, 2)), c = _word(up(2, 3));
      return (a == null || b == null || c == null)
          ? null
          : pick('TorculusResupinus', '$a$b$c');
    case NeumeType.porrectusFlexus:
      if (steps.length < 4) return null;
      final a = _word(dn(0, 1)), b = _word(up(1, 2)), c = _word(dn(2, 3));
      return (a == null || b == null || c == null)
          ? null
          : pick('PorrectusFlexus', '$a$b$c');
    case NeumeType.quilismaGroup:
      if (steps.length == 2) return pick('QuilismaPes', _word(up(0, 1)));
      return null;
    default:
      return null;
  }
}

/// Emits the glyph ops + rhythmic marks for one neume using the [font].
_NeumeBox _emitNeume(
    Neume e, List<int> steps, GreciliaeFont font, double scale) {
  final forms = e.components.map((c) => c.form).toList();
  final comps = e.components;
  double advPx(String name) {
    final u = font.advanceUnits(name);
    return (u > 0 ? u : 166) * scale;
  }

  final noteW = advPx('Punctum');

  // Build the glyph ops, the box width, and a center-x per component (px), used
  // to anchor the rhythmic marks.
  late final List<_GlyphOp> ops;
  late final List<double> compX;
  late final double width;

  if (steps.length == 1) {
    final name = e.type == NeumeType.virga ? 'Virga' : _singleGlyph(forms[0]);
    final g = font.has(name) ? name : 'Punctum';
    ops = [_GlyphOp(g, steps[0], 0)];
    width = advPx(g);
    compX = [width / 2];
  } else {
    // The liquescent (melting) note is the last of the neume; prefer the
    // diminished glyph when it is flagged liquescent.
    final last = comps.last;
    final liquescent = last.isLiquescent ||
        last.form == NcForm.liquescentAscending ||
        last.form == NcForm.liquescentDescending;
    final name = _neumeGlyphName(e.type, steps, forms, liquescent, font);
    if (name != null && font.has(name)) {
      // Precomposed single glyph: spread the component anchors across its width
      // (approximate — exact sub-glyph offsets are not exposed by the font).
      width = advPx(name);
      ops = [_GlyphOp(name, steps[0], 0)];
      final n = steps.length;
      compX = [for (var i = 0; i < n; i++) width * (i + 0.5) / n];
    } else {
      // Assemble glyph-per-note left to right. Descending steps use a punctum
      // inclinatum (diamond); the first note of a descending run is a virga.
      final o = <_GlyphOp>[];
      final cxs = <double>[];
      var cx = 0.0;
      for (var i = 0; i < steps.length; i++) {
        final descending = i > 0 && steps[i] < steps[i - 1];
        String g;
        if (descending) {
          g = font.has('DescendensPunctumInclinatum')
              ? 'DescendensPunctumInclinatum'
              : (font.has('PunctumInclinatumDeminutus')
                  ? 'PunctumInclinatumDeminutus'
                  : 'Punctum');
        } else if (i == 0 && steps.length > 1 && steps[1] < steps[0]) {
          g = 'Virga'; // climacus head
        } else {
          g = _singleGlyph(forms[i]);
          if (!font.has(g)) g = 'Punctum';
        }
        final w = advPx(g);
        o.add(_GlyphOp(g, steps[i], cx));
        cxs.add(cx + w / 2);
        cx += w * 0.98;
      }
      ops = o;
      compX = cxs;
      width = cx;
    }
  }

  // Rhythmic marks per component (episema bar, ictus tick, mora dot(s)).
  final marks = <_Mark>[];
  for (var i = 0; i < comps.length && i < compX.length; i++) {
    final c = comps[i];
    final x = compX[i];
    if (c.episema) marks.add(_Mark(_MarkType.episema, steps[i], x));
    if (c.ictus) {
      marks.add(_Mark(
          c.ictusAbove ? _MarkType.ictusAbove : _MarkType.ictus, steps[i], x));
    }
    for (var d = 0; d < c.morae; d++) {
      // Mora dot(s) sit to the right of the note; successive dots step further.
      marks.add(_Mark(_MarkType.mora, steps[i], x + noteW * (0.6 + d * 0.5)));
    }
  }

  return _NeumeBox(ops, marks, width, e.syllable, steps.first);
}

/// Builds and lays out chant as width-wrapped systems using [font].
class GregorianLayout {
  final List<_Row> _rows;
  final ChantClef clef;
  final double clefX;
  final double width;
  final double staffSpace;
  final bool hasSyllables;

  int get rowCount => _rows.length;

  GregorianLayout._({
    required List<_Row> rows,
    required this.clef,
    required this.clefX,
    required this.width,
    required this.staffSpace,
    required this.hasSyllables,
  }) : _rows = rows;

  factory GregorianLayout.build(
    List<MusicalElement> elements,
    ChantClef clef,
    double maxWidth,
    GregorianTheme theme,
    GreciliaeFont font,
  ) {
    final sp = theme.staffSpace;
    final scale = sp * _fontScale / GreciliaeFont.unitsPerEm;

    final dis = <int>[];
    for (final e in elements) {
      if (e is Neume) {
        for (final c in e.components) {
          if (c.pitchName != null && c.octave != null) {
            dis.add(_diatonic(c.pitchName!, c.octave!));
          }
        }
      }
    }
    dis.sort();
    final ref = dis.isEmpty ? 0 : dis[dis.length ~/ 2];

    final ordered = <Object>[];
    var hasSyllables = false;
    for (final e in elements) {
      if (e is Neume) {
        final steps = e.components.map((c) {
          final di = (c.pitchName != null && c.octave != null)
              ? _diatonic(c.pitchName!, c.octave!)
              : ref;
          return di - ref;
        }).toList();
        if (steps.isEmpty) continue;
        final box = _emitNeume(e, steps, font, scale);
        if (box.syllable != null && box.syllable!.isNotEmpty) hasSyllables = true;
        ordered.add(box);
      } else if (e is NeumeDivision) {
        ordered.add(_Divisio(e.type));
      }
    }

    final clefX = sp * 0.3;
    final notesStartX = clefX + sp * 1.6;
    final gap = sp * 0.85;
    final divisioGap = sp * 0.9;
    final rightPad = sp * 1.4;
    final hardWidth = maxWidth.isFinite && maxWidth > sp * 10 ? maxWidth : 0.0;

    double itemWidth(Object o) => o is _NeumeBox ? o.width : sp * 0.3;

    final rows = <_Row>[];
    var row = _Row();
    var cursor = notesStartX;
    var maxContent = notesStartX;
    for (final o in ordered) {
      final w = itemWidth(o) + (o is _Divisio ? divisioGap : gap);
      if (hardWidth > 0 &&
          row.items.isNotEmpty &&
          cursor + w > hardWidth - rightPad) {
        rows.add(row);
        row = _Row();
        cursor = notesStartX;
      }
      row.items.add(o);
      cursor += w;
      if (cursor > maxContent) maxContent = cursor;
    }
    if (row.items.isNotEmpty) rows.add(row);

    final fullWidth = hardWidth > 0 ? hardWidth : maxContent + rightPad;

    for (var r = 0; r < rows.length; r++) {
      final items = rows[r].items;
      final isLast = r == rows.length - 1;
      final sumW = items.fold<double>(0, (a, o) => a + itemWidth(o));
      final avail = (fullWidth - rightPad) - notesStartX;
      final g = (!isLast && items.length > 1 && avail > sumW)
          ? (avail - sumW) / items.length
          : gap;
      var x = notesStartX;
      for (final o in items) {
        if (o is _NeumeBox) {
          o.startX = x;
        } else if (o is _Divisio) {
          o.x = x;
        }
        x += itemWidth(o) + g;
      }
      rows[r].lineEnd = isLast ? (x - g + rightPad * 0.4) : fullWidth;
    }

    for (var i = 0; i < rows.length - 1; i++) {
      final next = rows[i + 1].items.whereType<_NeumeBox>();
      if (next.isNotEmpty) rows[i].custosStep = next.first.firstStep;
    }

    return GregorianLayout._(
      rows: rows,
      clef: clef,
      clefX: clefX,
      width: fullWidth,
      staffSpace: sp,
      hasSyllables: hasSyllables,
    );
  }

  double rowHeight() {
    final sp = staffSpace;
    return sp * 6.0 + (hasSyllables ? sp * 2.0 : 0.0);
  }

  double totalHeight() => _rows.length * rowHeight() + staffSpace;
}

/// Paints a [GregorianLayout] with Greciliae glyphs on a precise staff grid.
class GregorianPainter extends CustomPainter {
  final GregorianLayout layout;
  final GregorianTheme theme;
  final GreciliaeFont font;

  GregorianPainter({
    required this.layout,
    required this.theme,
    required this.font,
  });

  double get _sp => theme.staffSpace;
  double get _fontSize => _sp * _fontScale;
  double get _scale => _fontSize / GreciliaeFont.unitsPerEm;
  double get _halfStep => _unitsPerStep * _scale;
  double get _lineGap => 2 * _halfStep;

  double _lineY(double cy, int line) => cy + (1.5 - (line - 1)) * _lineGap;
  double _stepY(double cy, int step) => cy - step * _halfStep;

  /// Draws a Greciliae glyph by [name] so the font-y [anchorUnits] lands at
  /// (x, y). Notes use the first-note anchor; clef/custos register by bbox
  /// center so they sit centered on their line.
  void _glyph(Canvas canvas, String name, double x, double y,
      {double? anchorUnits}) {
    final ch = font.glyph(name);
    if (ch == null) return;
    final anchor = anchorUnits ?? _firstNoteAnchor;
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          fontFamily: 'Greciliae',
          package: 'flutter_notemus',
          fontSize: _fontSize,
          color: theme.color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(x, y - ascent + anchor * _scale));
  }

  void _lyric(Canvas canvas, String text, double centerX, double topY) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: theme.lyricSize,
          color: theme.color,
          fontFamily: theme.lyricTextFamily,
          fontFamilyFallback: theme.lyricTextFamily == null
              ? const ['Georgia', 'Times New Roman', 'serif']
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, topY));
  }

  /// Draws a rhythmic mark centered on a note at screen (cx, ny): a horizontal
  /// episema above, a vertical episema (ictus) below (or above), or a mora
  /// (augmentum) dot to the right at note height.
  void _drawMark(Canvas canvas, _MarkType type, double cx, double ny) {
    final sp = _sp;
    final p = Paint()
      ..color = theme.color
      ..strokeWidth = sp * 0.09
      ..strokeCap = StrokeCap.round;
    const halfH = 0.4; // note half-height in staff spaces (Punctum ≈ 0.4 sp)
    switch (type) {
      case _MarkType.mora:
        canvas.drawCircle(
            Offset(cx, ny), sp * 0.13, Paint()..color = theme.color);
        break;
      case _MarkType.episema:
        final y = ny - sp * (halfH + 0.18);
        canvas.drawLine(
            Offset(cx - sp * 0.34, y), Offset(cx + sp * 0.34, y), p);
        break;
      case _MarkType.ictus:
        final y0 = ny + sp * (halfH + 0.04);
        canvas.drawLine(Offset(cx, y0), Offset(cx, y0 + sp * 0.45), p);
        break;
      case _MarkType.ictusAbove:
        final y0 = ny - sp * (halfH + 0.04);
        canvas.drawLine(Offset(cx, y0), Offset(cx, y0 - sp * 0.45), p);
        break;
    }
  }

  /// Draws a divisio (chant pause bar) as a geometric stroke. Greciliae's
  /// Divisio* glyphs have unstable bounding boxes (and no Finalis), so the bars
  /// are drawn directly: minima cuts the top space, minor the upper half, maior
  /// the whole staff, finalis a double full bar (end of piece).
  void _drawDivisio(
      Canvas canvas, NeumeDivisionType t, double x, double cy, Paint p) {
    final top = _lineY(cy, 4);
    final l3 = _lineY(cy, 3);
    final l2 = _lineY(cy, 2);
    final bottom = _lineY(cy, 1);
    switch (t) {
      case NeumeDivisionType.minima:
        canvas.drawLine(Offset(x, top), Offset(x, l3), p);
        break;
      case NeumeDivisionType.minor:
        canvas.drawLine(Offset(x, top), Offset(x, l2), p);
        break;
      case NeumeDivisionType.maior:
        canvas.drawLine(Offset(x, top), Offset(x, bottom), p);
        break;
      case NeumeDivisionType.finalis:
        canvas.drawLine(Offset(x, top), Offset(x, bottom), p);
        canvas.drawLine(
            Offset(x + _sp * 0.3, top), Offset(x + _sp * 0.3, bottom), p);
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!font.isLoaded) return;
    final sp = _sp;
    final rowHeight = layout.rowHeight();
    final linePaint = Paint()
      ..color = theme.color
      ..strokeWidth = sp * 0.06
      ..strokeCap = StrokeCap.butt;
    final barPaint = Paint()
      ..color = theme.color
      ..strokeWidth = sp * 0.09;

    for (var r = 0; r < layout.rowCount; r++) {
      final row = layout._rows[r];
      final cy = r * rowHeight + sp * 3.0;

      for (var ln = 1; ln <= 4; ln++) {
        final y = _lineY(cy, ln);
        canvas.drawLine(Offset(0, y), Offset(row.lineEnd, y), linePaint);
      }

      _glyph(canvas, layout.clef.glyphName, layout.clefX,
          _lineY(cy, layout.clef.line),
          anchorUnits: font.centerYUnits(layout.clef.glyphName));

      final lyricTop = _lineY(cy, 1) + sp * 1.1;

      for (final item in row.items) {
        if (item is _Divisio) {
          _drawDivisio(canvas, item.type, item.x, cy, barPaint);
          continue;
        }
        final box = item as _NeumeBox;
        for (final op in box.glyphs) {
          _glyph(canvas, op.name, box.startX + op.dx, _stepY(cy, op.step));
        }
        for (final mk in box.marks) {
          _drawMark(canvas, mk.type, box.startX + mk.dx, _stepY(cy, mk.step));
        }
        if (box.syllable != null && box.syllable!.isNotEmpty) {
          _lyric(canvas, box.syllable!, (box.startX + box.endX) / 2, lyricTop);
        }
      }

      if (row.custosStep != null) {
        // The custos marks the next line's first pitch; its note-head seats on
        // the step like a note (the tail flourishes up/down from there), so it
        // uses the note anchor rather than the bbox center.
        final up = row.custosStep! >= 0;
        final g0 = up ? 'CustosUpShort' : 'CustosDownShort';
        final g = font.has(g0) ? g0 : 'Punctum';
        _glyph(canvas, g, row.lineEnd - sp * 1.0, _stepY(cy, row.custosStep!));
      }
    }
  }

  @override
  bool shouldRepaint(covariant GregorianPainter old) =>
      old.layout != layout || old.theme != theme;
}
