// Gregorian (square-notation / neume) renderer — Vatican/Solesmes style.
//
// Sibling of `MusicScore`/`JianpuScore` for plainchant. Renders clean, uniform
// SQUARE notation on a precise 4-line staff:
//   * the 4 staff lines are drawn as primitives on an exact grid, and every
//     glyph is registered by its SMuFL bounding box so noteheads sit EXACTLY on
//     a line or in a space (one diatonic step = half the inter-line gap);
//   * neumes are built from the uniform square punctum (and the diamond punctum
//     inclinatum for climacus tails), joined by simple geometric strokes — NOT
//     the calligraphic fused-ligatura glyphs, which clash with the square style;
//   * do/fa clef, divisiones, end-of-line custos, multi-system wrapping, and
//     serif syllable text.
// Pitch is RELATIVE to the clef line (chant has no fixed pitch); the melodic
// contour is centered on the staff. Absolute pitch/audio is deferred.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

import '../../smufl/smufl_metadata_loader.dart';

/// Visual configuration for the Gregorian renderer.
class GregorianTheme {
  final Color color;

  /// Pixels per staff space. The SMuFL em is 4 staff spaces.
  final double staffSpace;

  /// Lyric (syllable) font size in pixels.
  final double lyricSize;

  /// Optional font family for syllable text (defaults to a serif fallback).
  final String? lyricTextFamily;

  const GregorianTheme({
    this.color = const Color(0xFF1A1A1A),
    this.staffSpace = 26.0,
    this.lyricSize = 15.0,
    this.lyricTextFamily,
  });
}

/// Chant clef: a do (ut) or fa clef anchored on a staff line (1 = bottom).
enum ChantClefType { doClef, faClef }

class ChantClef {
  final ChantClefType type;

  /// Staff line the clef sits on, 1 (bottom) .. 4 (top). Default: top line.
  final int line;

  const ChantClef({this.type = ChantClefType.doClef, this.line = 4});

  String get glyphName =>
      type == ChantClefType.doClef ? 'chantCclef' : 'chantFclef';
}

// Inter-line gap in staff-space units (from the SMuFL chantStaff: 4 lines over
// 3.064 sp). Drawing our own lines on this grid keeps clef/divisio glyphs — all
// designed for this gap — consistent with the noteheads.
const double _lineGapU = 3.064 / 3; // ≈ 1.021
const double _halfStepU = _lineGapU / 2; // one diatonic step ≈ 0.511 sp

int _diatonic(String step, int octave) {
  const order = 'CDEFGAB';
  final i = order.indexOf(step.toUpperCase());
  return octave * 7 + (i < 0 ? 0 : i);
}

enum _OpKind { note, stroke, episema, ictus, mora }

class _Op {
  final _OpKind kind;
  final String glyph; // note: glyph name; mora/ictus/episema: glyph name
  final int step; // note step / stroke top step
  final int step2; // stroke bottom step (else == step)
  final double dx; // x offset within the neume (px)
  _Op(this.kind, this.glyph, this.step, this.dx, [int? step2])
      : step2 = step2 ?? step;
}

class _NeumeBox {
  final List<_Op> ops;
  final double width;
  final String? syllable;
  final int firstStep;
  double startX = 0;
  _NeumeBox(this.ops, this.width, this.syllable, this.firstStep);
  double get endX => startX + width;
}

class _Divisio {
  final String glyphName;
  double x = 0;
  _Divisio(this.glyphName);
}

class _Row {
  final List<Object> items = []; // _NeumeBox | _Divisio, in reading order
  int? custosStep;
  double lineEnd = 0; // x where this system's staff lines stop
}

String _divisioGlyph(NeumeDivisionType t) => switch (t) {
      NeumeDivisionType.minima => 'chantDivisioMinima',
      NeumeDivisionType.minor => 'chantDivisioMaior',
      NeumeDivisionType.maior => 'chantDivisioMaior',
      NeumeDivisionType.finalis => 'chantDivisioFinalis',
    };

/// Glyph for a single square note by its form.
String _noteGlyph(NcForm form) => switch (form) {
      NcForm.virga => 'chantPunctumVirga',
      NcForm.quilisma => 'chantQuilisma',
      NcForm.oriscus => 'chantOriscusAscending',
      NcForm.stropha => 'chantStrophicus',
      _ => 'chantPunctum',
    };

/// Emits the draw ops for one neume (square style), per [NeumeType].
_NeumeBox _emitNeume(Neume e, List<int> steps, double sp) {
  final ops = <_Op>[];
  final forms = e.components.map((c) => c.form).toList();
  final noteW = 0.64 * sp; // chantPunctum advance

  String formGlyph(int i) =>
      _noteGlyph(i < forms.length ? forms[i] : NcForm.punctum);

  // Single note.
  if (steps.length == 1) {
    final glyph =
        e.type == NeumeType.virga ? 'chantPunctumVirga' : formGlyph(0);
    return _NeumeBox(
        [_Op(_OpKind.note, glyph, steps[0], 0)], noteW, e.syllable, steps[0]);
  }

  final type = (e.type == NeumeType.torculus || e.type == NeumeType.porrectus) &&
          steps.length < 3
      ? NeumeType.custom
      : e.type;

  double width;
  switch (type) {
    case NeumeType.bivirga:
    case NeumeType.trivirga:
      final n = type == NeumeType.bivirga ? 2 : 3;
      for (var i = 0; i < n; i++) {
        ops.add(_Op(_OpKind.note, 'chantPunctumVirga', steps[0], i * noteW));
      }
      width = noteW * n;
    case NeumeType.pes:
      // Two squares stacked (lower then upper) joined by a left vertical stroke.
      ops.add(_Op(_OpKind.note, 'chantPunctum', steps[0], 0));
      ops.add(_Op(_OpKind.note, formGlyph(1), steps[1], 0));
      ops.add(_Op(_OpKind.stroke, '', steps[1], noteW * 0.06, steps[0]));
      width = noteW;
    case NeumeType.clivis:
      // First (higher) square, then a lower square to the right; a left vertical
      // stroke descends from the first note to the second's level.
      ops.add(_Op(_OpKind.note, 'chantPunctum', steps[0], 0));
      ops.add(_Op(_OpKind.note, 'chantPunctum', steps[1], noteW * 0.92));
      ops.add(_Op(_OpKind.stroke, '', steps[0], noteW * 0.06, steps[1]));
      width = noteW * 1.92;
    case NeumeType.scandicus:
    case NeumeType.salicus:
      var cx = 0.0;
      for (var i = 0; i < steps.length; i++) {
        final isLast = i == steps.length - 1;
        ops.add(_Op(_OpKind.note, isLast ? 'chantPunctumVirga' : 'chantPunctum',
            steps[i], cx));
        cx += noteW * 0.95;
      }
      width = cx - noteW * 0.95 + noteW;
    case NeumeType.climacus:
      // Virga then a run of descending puncta inclinata (diamonds).
      var cx = 0.0;
      ops.add(_Op(_OpKind.note, 'chantPunctumVirga', steps[0], cx));
      cx += noteW * 0.95;
      for (var i = 1; i < steps.length; i++) {
        ops.add(_Op(_OpKind.note, 'chantPunctumInclinatum', steps[i], cx));
        cx += noteW * 0.95;
      }
      width = cx;
    case NeumeType.torculus:
    case NeumeType.porrectus:
      // Three squares on a diagonal (hump / valley) — the contour conveys it.
      var cx = 0.0;
      for (var i = 0; i < steps.length; i++) {
        ops.add(_Op(_OpKind.note, 'chantPunctum', steps[i], cx));
        cx += noteW * 0.95;
      }
      width = cx - noteW * 0.95 + noteW;
    default:
      // Generic contour walk: square per component; descending steps use
      // puncta inclinata (diamonds).
      var cx = 0.0;
      for (var i = 0; i < steps.length; i++) {
        final descending = i > 0 && steps[i] < steps[i - 1];
        ops.add(_Op(_OpKind.note,
            descending ? 'chantPunctumInclinatum' : formGlyph(i), steps[i], cx));
        cx += noteW * 0.92;
      }
      width = cx - noteW * 0.92 + noteW;
  }

  // Rhythmic marks (Solesmes): episema, ictus, mora — attached per notehead.
  final noteOps = ops.where((o) => o.kind == _OpKind.note).toList();
  for (var i = 0; i < e.components.length && i < noteOps.length; i++) {
    final c = e.components[i];
    final no = noteOps[i];
    if (c.episema) ops.add(_Op(_OpKind.episema, 'chantEpisema', no.step, no.dx));
    if (c.ictus) {
      ops.add(_Op(_OpKind.ictus,
          c.ictusAbove ? 'chantIctusAbove' : 'chantIctusBelow', no.step, no.dx));
    }
    for (var d = 0; d < c.morae; d++) {
      ops.add(_Op(_OpKind.mora, 'chantAugmentum', no.step,
          no.dx + noteW + d * noteW * 0.5));
    }
  }
  final lastMorae = e.components.isNotEmpty ? e.components.last.morae : 0;
  if (lastMorae > 0) width += noteW * 0.6 * lastMorae;

  return _NeumeBox(ops, width, e.syllable, steps.first);
}

/// Builds and lays out chant as width-wrapped systems.
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
  ) {
    final sp = theme.staffSpace;

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
    final referenceDi = dis.isEmpty ? 0 : dis[dis.length ~/ 2];

    final ordered = <Object>[];
    var hasSyllables = false;
    for (final e in elements) {
      if (e is Neume) {
        final steps = e.components.map((c) {
          final di = (c.pitchName != null && c.octave != null)
              ? _diatonic(c.pitchName!, c.octave!)
              : referenceDi;
          return di - referenceDi;
        }).toList();
        if (steps.isEmpty) continue;
        final box = _emitNeume(e, steps, sp);
        if (box.syllable != null && box.syllable!.isNotEmpty) hasSyllables = true;
        ordered.add(box);
      } else if (e is NeumeDivision) {
        ordered.add(_Divisio(_divisioGlyph(e.type)));
      }
    }

    final clefX = sp * 0.4;
    final notesStartX = clefX + sp * 1.8;
    final neumeGap = sp * 0.9;
    final divisioGap = sp * 0.9;
    final rightPad = sp * 1.6;
    final hardWidth = maxWidth.isFinite && maxWidth > sp * 12 ? maxWidth : 0.0;

    double itemWidth(Object o) => o is _NeumeBox ? o.width : divisioGap;

    // Pack items into rows by width (just record membership + order here;
    // X positions are assigned afterwards, with justification).
    final rows = <_Row>[];
    var row = _Row();
    var packCursor = notesStartX;
    var maxContent = notesStartX;
    for (final o in ordered) {
      final w = itemWidth(o) + neumeGap;
      if (hardWidth > 0 &&
          row.items.isNotEmpty &&
          packCursor + w > hardWidth - rightPad) {
        rows.add(row);
        row = _Row();
        packCursor = notesStartX;
      }
      row.items.add(o);
      packCursor += w;
      if (packCursor > maxContent) maxContent = packCursor;
    }
    if (row.items.isNotEmpty) rows.add(row);

    final fullWidth = hardWidth > 0 ? hardWidth : maxContent + rightPad;

    // Assign X. Non-last rows are JUSTIFIED to fill the line; the last row is
    // left-packed and its staff lines stop just after the final element.
    for (var r = 0; r < rows.length; r++) {
      final items = rows[r].items;
      final isLast = r == rows.length - 1;
      final sumW = items.fold<double>(0, (a, o) => a + itemWidth(o));
      final avail = (fullWidth - rightPad) - notesStartX;
      final gaps = items.length; // gaps between + trailing (before custos)
      final gap = (!isLast && items.length > 1 && avail > sumW)
          ? (avail - sumW) / gaps
          : neumeGap;
      var x = notesStartX;
      for (final o in items) {
        if (o is _NeumeBox) {
          o.startX = x;
        } else if (o is _Divisio) {
          o.x = x;
        }
        x += itemWidth(o) + gap;
      }
      rows[r].lineEnd = isLast ? (x - gap + rightPad * 0.4) : fullWidth;
    }

    // Custos: end of each row (except last) shows the next row's first pitch.
    for (var i = 0; i < rows.length - 1; i++) {
      final next = rows[i + 1].items;
      final firstNeume = next.whereType<_NeumeBox>().cast<_NeumeBox?>().firstWhere(
            (b) => b != null,
            orElse: () => null,
          );
      if (firstNeume != null) rows[i].custosStep = firstNeume.firstStep;
    }

    final width = fullWidth;
    return GregorianLayout._(
      rows: rows,
      clef: clef,
      clefX: clefX,
      width: width,
      staffSpace: sp,
      hasSyllables: hasSyllables,
    );
  }

  double rowHeight() {
    final sp = staffSpace;
    final lyric = hasSyllables ? sp * 2.0 : 0.0;
    return sp * 6.2 + lyric;
  }

  double totalHeight() => _rows.length * rowHeight() + staffSpace * 1.0;
}

/// Paints a [GregorianLayout] using a precise staff grid + square chant glyphs.
class GregorianPainter extends CustomPainter {
  final GregorianLayout layout;
  final GregorianTheme theme;
  final SmuflMetadata metadata;

  GregorianPainter({
    required this.layout,
    required this.theme,
    required this.metadata,
  });

  double get _sp => theme.staffSpace;
  double get _lineGap => _lineGapU * _sp;
  double get _halfStep => _halfStepU * _sp;

  /// Canvas Y of staff line [line] (1 = bottom .. 4 = top) for staff center cy.
  double _lineY(double cy, int line) => cy + (1.5 - (line - 1)) * _lineGap;

  /// Canvas Y of a note at diatonic [step] (median centered on the staff middle).
  double _stepY(double cy, int step) => cy - step * _halfStep;

  /// Draws a chant glyph so its notehead/bbox anchor lands EXACTLY at (cx, cy).
  /// Horizontally the glyph's left edge is at cx; vertically [cy] is the bbox
  /// center, except virga (where the notehead sits at the top → origin anchor).
  void _glyph(Canvas canvas, String glyphName, double cx, double cy,
      {bool originAnchor = false}) {
    final ch = metadata.getCodepoint(glyphName);
    if (ch.isEmpty) return;
    final box = metadata.getGlyphBoundingBox(glyphName);
    final isVirga = glyphName.contains('Virga');
    // Divisiones/custos register by their SMuFL origin (staff reference);
    // virga by its origin (notehead at top); everything else by bbox center.
    final anchorY =
        (originAnchor || isVirga) ? 0.0 : (box?.centerY ?? 0.0);
    final leftX = (box?.bBoxSwX ?? 0.0);

    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          fontFamily: 'Bravura',
          package: 'flutter_notemus',
          fontSize: _sp * 4.0,
          color: theme.color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final px = cx - leftX * _sp;
    final py = cy - ascent + anchorY * _sp;
    tp.paint(canvas, Offset(px, py));
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

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded) return;
    final sp = _sp;
    final rowHeight = layout.rowHeight();
    final linePaint = Paint()
      ..color = theme.color
      ..strokeWidth = sp * 0.07
      ..strokeCap = StrokeCap.butt;
    final notePaint = Paint()..color = theme.color;

    for (var r = 0; r < layout.rowCount; r++) {
      final row = layout._rows[r];
      final cy = r * rowHeight + sp * 3.2;

      // 4 staff lines (primitives, exact grid), stopping at this row's end.
      for (var ln = 1; ln <= 4; ln++) {
        final y = _lineY(cy, ln);
        canvas.drawLine(Offset(0, y), Offset(row.lineEnd, y), linePaint);
      }

      // Clef (repeated each row), centered on its line.
      _glyph(canvas, layout.clef.glyphName, layout.clefX,
          _lineY(cy, layout.clef.line));

      final lyricTop = _lineY(cy, 1) + sp * 1.0;

      for (final item in row.items) {
        if (item is _Divisio) {
          _glyph(canvas, item.glyphName, item.x, cy, originAnchor: true);
          continue;
        }
        final box = item as _NeumeBox;
        // Connecting strokes first (under the squares).
        for (final op in box.ops) {
          if (op.kind == _OpKind.stroke) {
            final x = box.startX + op.dx;
            canvas.drawRect(
              Rect.fromLTRB(
                  x, _stepY(cy, op.step), x + sp * 0.1, _stepY(cy, op.step2)),
              notePaint,
            );
          }
        }
        for (final op in box.ops) {
          if (op.kind == _OpKind.note) {
            _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(cy, op.step));
          }
        }
        for (final op in box.ops) {
          switch (op.kind) {
            case _OpKind.episema:
              _glyph(canvas, op.glyph, box.startX + op.dx,
                  _stepY(cy, op.step) - sp * 0.6);
            case _OpKind.ictus:
              final dy = op.glyph == 'chantIctusAbove' ? -sp * 0.7 : sp * 0.7;
              _glyph(canvas, op.glyph, box.startX + op.dx,
                  _stepY(cy, op.step) + dy);
            case _OpKind.mora:
              _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(cy, op.step));
            default:
              break;
          }
        }
        if (box.syllable != null && box.syllable!.isNotEmpty) {
          _lyric(canvas, box.syllable!, (box.startX + box.endX) / 2, lyricTop);
        }
      }

      if (row.custosStep != null) {
        _glyph(canvas, 'chantCustosStemUpPosMiddle', row.lineEnd - sp * 1.0,
            _stepY(cy, row.custosStep!), originAnchor: true);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GregorianPainter old) =>
      old.layout != layout || old.theme != theme;
}
