// Gregorian (square-notation / neume) renderer — Tier A / A+.
//
// Sibling of `MusicScore`/`JianpuScore` for plainchant. Assembles neumes from
// the bundled SMuFL "chant" glyphs on a 4-line staff with a do/fa clef. Chant
// glyphs carry no anchors, so registration is via the SMuFL baseline (glyph
// origin y=0). One diatonic step is HALF the inter-line gap. Pitch is RELATIVE
// to the clef line; absolute pitch/audio is deferred (chant has no fixed pitch).
//
// Neumes are rendered per [NeumeType] using the SMuFL/Gregorio assembly recipes:
//   * pes/podatus  = two stacked notes joined by an ascending connecting line;
//   * clivis/flexus = ONE fused descending ligatura glyph;
//   * climacus     = virga + a run of descending puncta inclinata;
//   * scandicus    = ascending puncta joined by connecting lines (virga on top);
//   * torculus     = rise then fall; porrectus = fused descending stroke + rise;
//   * single notes = punctum / virga / quilisma / oriscus / strophicus.
// Other/compound forms fall back to a generic contour walk.

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

  /// Optional font family for syllable text (defaults to the ambient font).
  final String? lyricTextFamily;

  const GregorianTheme({
    this.color = const Color(0xFF101010),
    this.staffSpace = 24.0,
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

// SMuFL chant staff metrics (from bravura_metadata.json, in staff spaces).
const double _staffHalfHeight = 1.532; // chantStaff bbox NE.y
const double _lineGap = (2 * _staffHalfHeight) / 3; // 4 lines, 3 gaps ≈ 1.021
const double _halfStep = _lineGap / 2; // one diatonic step ≈ 0.511 sp
const double _staffAdvance = 2.0; // chantStaff advance width
const double _noteWidth = 0.64; // chantPunctum advance
const double _inclWidth = 0.6; // chantPunctumInclinatum advance

int _diatonic(String step, int octave) {
  const order = 'CDEFGAB';
  final i = order.indexOf(step.toUpperCase());
  return octave * 7 + (i < 0 ? 0 : i);
}

/// A positioned draw operation within a neume.
enum _OpKind { note, ascLine, descLig, episema, ictus, mora }

class _Op {
  final _OpKind kind;
  final String glyph;
  final int step; // note step / asc-line bottom step / ligatura top step
  final int step2; // asc-line top step / ligatura bottom step (else == step)
  final double dx; // x offset within the neume, in pixels
  _Op(this.kind, this.glyph, this.step, this.dx, [int? step2])
      : step2 = step2 ?? step;
}

/// One laid-out neume: its draw ops + optional syllable.
class _NeumeBox {
  final List<_Op> ops;
  final double width;
  final String? syllable;
  final int firstStep; // staff step of the first note (for the custos)
  double startX = 0;
  _NeumeBox(this.ops, this.width, this.syllable, this.firstStep);
  double get endX => startX + width;
}

/// A divisio (chant barline) laid out at an X.
class _Divisio {
  final String glyphName;
  double x = 0;
  _Divisio(this.glyphName);
}

String _divisioGlyph(NeumeDivisionType t) => switch (t) {
      NeumeDivisionType.minima => 'chantDivisioMinima',
      NeumeDivisionType.minor => 'chantDivisioMaior',
      NeumeDivisionType.maior => 'chantDivisioMaior',
      NeumeDivisionType.finalis => 'chantDivisioFinalis',
    };

/// Glyph for a single note by its form.
String _noteGlyph(NcForm form) => switch (form) {
      NcForm.virga => 'chantPunctumVirga',
      NcForm.quilisma => 'chantQuilisma',
      NcForm.oriscus => 'chantOriscusAscending',
      NcForm.stropha => 'chantStrophicus',
      _ => 'chantPunctum',
    };

/// Ascending connecting-line glyph for an interval of [steps] diatonic steps.
String? _ascLineGlyph(int steps) => switch (steps) {
      1 => 'chantConnectingLineAsc2nd',
      2 => 'chantConnectingLineAsc3rd',
      3 => 'chantConnectingLineAsc4th',
      4 => 'chantConnectingLineAsc5th',
      >= 5 => 'chantConnectingLineAsc6th',
      _ => null,
    };

/// Fused descending ligatura glyph (clivis pair) for [steps] diatonic steps.
String _descLigGlyph(int steps) => switch (steps) {
      1 => 'chantLigaturaDesc2nd',
      2 => 'chantLigaturaDesc3rd',
      3 => 'chantLigaturaDesc4th',
      _ => 'chantLigaturaDesc5th',
    };

/// Approximate fused-ligatura advance width (staff spaces) by interval.
double _descLigWidth(int steps) => switch (steps) {
      1 => 1.86,
      2 => 2.316,
      3 => 2.77,
      _ => 3.2,
    };

/// Emits the draw ops for one neume (relative dx in pixels), per its type.
_NeumeBox _emitNeume(Neume e, List<int> steps, double sp) {
  final ops = <_Op>[];
  final forms = e.components.map((c) => c.form).toList();
  final noteW = _noteWidth * sp;
  final inclW = _inclWidth * sp;

  String first() => _noteGlyph(forms.isNotEmpty ? forms.first : NcForm.punctum);

  // Single-component neumes (or any type with one note) render as one glyph.
  if (steps.length == 1) {
    final glyph = e.type == NeumeType.virga ? 'chantPunctumVirga' : first();
    return _NeumeBox(
        [_Op(_OpKind.note, glyph, steps[0], 0)], noteW, e.syllable, steps[0]);
  }

  // Types needing exactly three notes degrade to the generic walk otherwise.
  final type = (e.type == NeumeType.torculus || e.type == NeumeType.porrectus) &&
          steps.length < 3
      ? NeumeType.custom
      : e.type;

  double width;
  switch (type) {
    case NeumeType.punctum:
    case NeumeType.oriscusGroup:
      ops.add(_Op(_OpKind.note, first(), steps[0], 0));
      width = noteW;
    case NeumeType.virga:
      ops.add(_Op(_OpKind.note, 'chantPunctumVirga', steps[0], 0));
      width = noteW;
    case NeumeType.bivirga:
    case NeumeType.trivirga:
      final n = e.type == NeumeType.bivirga ? 2 : 3;
      for (var i = 0; i < n; i++) {
        ops.add(_Op(_OpKind.note, 'chantPunctumVirga', steps[0], i * noteW * 0.95));
      }
      width = noteW + (n - 1) * noteW * 0.95;
    case NeumeType.pes:
      // Two stacked notes joined by an ascending connecting line.
      ops.add(_Op(_OpKind.note, 'chantPunctum', steps[0], 0));
      ops.add(_Op(_OpKind.note, _noteGlyph(forms.length > 1 ? forms[1] : NcForm.punctum),
          steps[1], 0));
      final iv = steps[1] - steps[0];
      final line = _ascLineGlyph(iv);
      if (line != null && iv >= 1) {
        ops.add(_Op(_OpKind.ascLine, line, steps[0], 0, steps[1]));
      }
      width = noteW;
    case NeumeType.clivis:
      // One fused descending ligatura glyph.
      final iv = steps[0] - steps[1];
      ops.add(_Op(_OpKind.descLig, _descLigGlyph(iv), steps[0], 0, steps[1]));
      width = _descLigWidth(iv) * sp;
    case NeumeType.scandicus:
    case NeumeType.salicus:
      // Ascending puncta on a diagonal, joined by connecting lines; virga top.
      var cx = 0.0;
      for (var i = 0; i < steps.length; i++) {
        final isLast = i == steps.length - 1;
        ops.add(_Op(_OpKind.note, isLast ? 'chantPunctumVirga' : 'chantPunctum',
            steps[i], cx));
        if (i > 0 && steps[i] > steps[i - 1]) {
          final line = _ascLineGlyph(steps[i] - steps[i - 1]);
          if (line != null) {
            ops.add(_Op(_OpKind.ascLine, line, steps[i - 1], cx, steps[i]));
          }
        }
        cx += noteW * 0.82;
      }
      width = cx - noteW * 0.82 + noteW;
    case NeumeType.climacus:
      // Virga then a run of descending puncta inclinata (diamonds).
      var cx = 0.0;
      ops.add(_Op(_OpKind.note, 'chantPunctumVirga', steps[0], cx));
      cx += noteW * 0.95;
      for (var i = 1; i < steps.length; i++) {
        ops.add(_Op(_OpKind.note, 'chantPunctumInclinatum', steps[i], cx));
        cx += inclW * 0.95;
      }
      width = cx;
    case NeumeType.torculus:
      // Rise (pes) then fall: low, high, low.
      ops.add(_Op(_OpKind.note, 'chantPunctum', steps[0], 0));
      ops.add(_Op(_OpKind.note, 'chantPunctum', steps[1], 0));
      final up = steps[1] - steps[0];
      final upLine = _ascLineGlyph(up);
      if (upLine != null && up >= 1) {
        ops.add(_Op(_OpKind.ascLine, upLine, steps[0], 0, steps[1]));
      }
      // Descending tail as a fused ligatura from the apex to the last note.
      final dn = steps[1] - steps[2];
      ops.add(_Op(_OpKind.descLig, _descLigGlyph(dn), steps[1], noteW * 0.35,
          steps[2]));
      width = noteW * 0.35 + _descLigWidth(dn) * sp;
    case NeumeType.porrectus:
      // Fused descending stroke (high->low) then ascending join to a high note.
      final dn = steps[0] - steps[1];
      ops.add(_Op(_OpKind.descLig, _descLigGlyph(dn), steps[0], 0, steps[1]));
      var cx = _descLigWidth(dn) * sp;
      ops.add(_Op(_OpKind.note, 'chantPunctumVirga', steps[2], cx));
      final up = steps[2] - steps[1];
      final upLine = _ascLineGlyph(up);
      if (upLine != null && up >= 1) {
        ops.add(_Op(_OpKind.ascLine, upLine, steps[1], cx, steps[2]));
      }
      width = cx + noteW;
    default:
      // Generic contour walk: a notehead per component on a diagonal, ascending
      // joins where the line rises; descending steps use puncta inclinata.
      var cx = 0.0;
      for (var i = 0; i < steps.length; i++) {
        final descending = i > 0 && steps[i] < steps[i - 1];
        final glyph =
            descending ? 'chantPunctumInclinatum' : _noteGlyph(forms[i]);
        ops.add(_Op(_OpKind.note, glyph, steps[i], cx));
        if (i > 0 && steps[i] > steps[i - 1]) {
          final line = _ascLineGlyph(steps[i] - steps[i - 1]);
          if (line != null) {
            ops.add(_Op(_OpKind.ascLine, line, steps[i - 1], cx, steps[i]));
          }
        }
        cx += noteW * 0.9;
      }
      width = (steps.length <= 1) ? noteW : cx - noteW * 0.9 + noteW;
  }

  // Rhythmic / expressive marks (Solesmes): episema, ictus, mora (augmentum).
  // Attach each component's marks to the corresponding notehead op (in order).
  final noteOps = ops.where((o) => o.kind == _OpKind.note).toList();
  for (var i = 0; i < e.components.length && i < noteOps.length; i++) {
    final c = e.components[i];
    final no = noteOps[i];
    if (c.episema) {
      ops.add(_Op(_OpKind.episema, 'chantEpisema', no.step, no.dx));
    }
    if (c.ictus) {
      ops.add(_Op(_OpKind.ictus,
          c.ictusAbove ? 'chantIctusAbove' : 'chantIctusBelow', no.step, no.dx));
    }
    for (var d = 0; d < c.morae; d++) {
      ops.add(_Op(_OpKind.mora, 'chantAugmentum', no.step,
          no.dx + noteW + d * noteW * 0.5));
    }
  }
  // Reserve a little extra width when the last note carries mora dots.
  final lastMorae = e.components.isNotEmpty ? e.components.last.morae : 0;
  if (lastMorae > 0) width += noteW * (0.6 * lastMorae);

  return _NeumeBox(ops, width, e.syllable, steps.first);
}

/// One staff line (system) of chant: its neumes/divisiones (with row-relative
/// X already assigned) plus an optional end-of-line custos.
class _Row {
  final List<_NeumeBox> neumes = [];
  final List<_Divisio> divisiones = [];
  int? custosStep; // step of the next row's first note; null on the last row
}

/// Builds and lays out chant as rows (systems) wrapped to a maximum width.
class GregorianLayout {
  final List<_Row> _rows;
  final ChantClef clef;
  final double clefX;
  final double width; // canvas width
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

    // Reference diatonic index placed on the staff middle: the median pitch, so
    // the relative melodic contour is fully visible (absolute pitch deferred).
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

    final ordered = <Object>[]; // _NeumeBox | _Divisio
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

    // Each row repeats the clef; reserve room at the right for the custos.
    final clefX = sp * 0.4;
    final notesStartX = clefX + sp * 1.7;
    final neumeGap = sp * 1.0;
    final divisioGap = sp * 0.85;
    final rightPad = sp * 1.6; // custos space
    final hardWidth = maxWidth.isFinite && maxWidth > sp * 12 ? maxWidth : 0.0;

    final rows = <_Row>[];
    var row = _Row();
    var cursor = notesStartX;
    var maxCursor = notesStartX;
    for (final o in ordered) {
      final w = o is _NeumeBox ? o.width + neumeGap : divisioGap;
      final hasContent = row.neumes.isNotEmpty || row.divisiones.isNotEmpty;
      if (hardWidth > 0 && hasContent && cursor + w > hardWidth - rightPad) {
        rows.add(row);
        row = _Row();
        cursor = notesStartX;
      }
      if (o is _NeumeBox) {
        o.startX = cursor;
        row.neumes.add(o);
        cursor += o.width + neumeGap;
      } else if (o is _Divisio) {
        o.x = cursor;
        row.divisiones.add(o);
        cursor += divisioGap;
      }
      if (cursor > maxCursor) maxCursor = cursor;
    }
    if (row.neumes.isNotEmpty || row.divisiones.isNotEmpty) rows.add(row);

    // Custos: end of each row (except the last) shows the next row's first pitch.
    for (var i = 0; i < rows.length - 1; i++) {
      if (rows[i + 1].neumes.isNotEmpty) {
        rows[i].custosStep = rows[i + 1].neumes.first.firstStep;
      }
    }

    final width = hardWidth > 0 ? hardWidth : maxCursor + rightPad;
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
    final lyric = hasSyllables ? sp * 2.2 : 0.0;
    return sp * 6.0 + lyric;
  }

  double totalHeight() => _rows.length * rowHeight() + staffSpace * 1.2;
}

/// Paints a [GregorianLayout] using the bundled Bravura chant glyphs.
class GregorianPainter extends CustomPainter {
  final GregorianLayout layout;
  final GregorianTheme theme;
  final SmuflMetadata metadata;

  GregorianPainter({
    required this.layout,
    required this.theme,
    required this.metadata,
  });

  /// Canvas Y of staff line [line] (1 = bottom .. 4 = top) for a row whose staff
  /// center is at [centerY].
  double _lineY(double centerY, int line) =>
      centerY + (_staffHalfHeight - (line - 1) * _lineGap) * theme.staffSpace;

  /// Canvas Y of a note at diatonic [step] within a row centered at [centerY].
  double _stepY(double centerY, int step) =>
      centerY - step * _halfStep * theme.staffSpace;

  /// Draws a chant glyph so its SMuFL origin (baseline, x=0) lands at (x, y).
  void _glyph(Canvas canvas, String glyphName, double x, double y) {
    final ch = metadata.getCodepoint(glyphName);
    if (ch.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          fontFamily: 'Bravura',
          package: 'flutter_notemus',
          fontSize: theme.staffSpace * 4.0, // SMuFL em = 4 staff spaces
          color: theme.color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(x, y - ascent));
  }

  void _lyric(Canvas canvas, String text, double centerX, double topY) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: theme.lyricSize,
          color: theme.color,
          fontFamily: theme.lyricTextFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, topY));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded) return;
    final sp = theme.staffSpace;
    final rowHeight = layout.rowHeight();

    for (var r = 0; r < layout._rows.length; r++) {
      final row = layout._rows[r];
      final centerY = r * rowHeight + sp * 3.0;
      final lyricTop = _lineY(centerY, 1) + sp * 1.4;

      // Staff: tile chantStaff across the row width.
      var sx = 0.0;
      while (sx < layout.width) {
        _glyph(canvas, 'chantStaff', sx, centerY);
        sx += _staffAdvance * sp;
      }

      // Clef (repeated each row).
      _glyph(canvas, layout.clef.glyphName, layout.clefX,
          _lineY(centerY, layout.clef.line));

      for (final box in row.neumes) {
        // Connecting lines / ligaturas first, then noteheads on top.
        for (final op in box.ops) {
          if (op.kind == _OpKind.ascLine) {
            final y = (_stepY(centerY, op.step) + _stepY(centerY, op.step2)) / 2;
            _glyph(canvas, op.glyph, box.startX + op.dx, y);
          } else if (op.kind == _OpKind.descLig) {
            _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(centerY, op.step));
          }
        }
        for (final op in box.ops) {
          if (op.kind == _OpKind.note) {
            _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(centerY, op.step));
          }
        }
        // Rhythmic / expressive marks on top of the noteheads.
        for (final op in box.ops) {
          switch (op.kind) {
            case _OpKind.episema:
              _glyph(canvas, op.glyph, box.startX + op.dx,
                  _stepY(centerY, op.step) - sp * 0.55);
            case _OpKind.ictus:
              final dy = op.glyph == 'chantIctusAbove' ? -sp * 0.7 : sp * 0.7;
              _glyph(canvas, op.glyph, box.startX + op.dx,
                  _stepY(centerY, op.step) + dy);
            case _OpKind.mora:
              _glyph(canvas, op.glyph, box.startX + op.dx,
                  _stepY(centerY, op.step));
            default:
              break;
          }
        }
        if (box.syllable != null && box.syllable!.isNotEmpty) {
          _lyric(canvas, box.syllable!, (box.startX + box.endX) / 2, lyricTop);
        }
      }

      for (final d in row.divisiones) {
        _glyph(canvas, d.glyphName, d.x, centerY);
      }

      // End-of-line custos pointing at the next row's first pitch.
      if (row.custosStep != null) {
        _glyph(canvas, 'chantCustosStemUpPosMiddle', layout.width - sp * 1.3,
            _stepY(centerY, row.custosStep!));
      }
    }
  }

  @override
  bool shouldRepaint(covariant GregorianPainter old) =>
      old.layout != layout || old.theme != theme;
}
