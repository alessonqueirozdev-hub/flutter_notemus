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
  double startX = 0;
  _NeumeBox(this.ops, this.width, this.syllable);
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
    return _NeumeBox([_Op(_OpKind.note, glyph, steps[0], 0)], noteW, e.syllable);
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

  return _NeumeBox(ops, width, e.syllable);
}

/// Builds and lays out a chant line (Tier A: a single horizontal flow).
class GregorianLayout {
  final List<_NeumeBox> _neumes;
  final List<_Divisio> _divisiones;
  final ChantClef clef;
  final double clefX;
  final double contentWidth;
  final double staffSpace;
  final bool hasSyllables;

  GregorianLayout._({
    required List<_NeumeBox> neumes,
    required List<_Divisio> divisiones,
    required this.clef,
    required this.clefX,
    required this.contentWidth,
    required this.staffSpace,
    required this.hasSyllables,
  })  : _neumes = neumes,
        _divisiones = divisiones;

  factory GregorianLayout.build(
    List<MusicalElement> elements,
    ChantClef clef,
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

    final neumes = <_NeumeBox>[];
    final divisiones = <_Divisio>[];
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
        if (box.syllable != null && box.syllable!.isNotEmpty) {
          hasSyllables = true;
        }
        neumes.add(box);
        ordered.add(box);
      } else if (e is NeumeDivision) {
        final d = _Divisio(_divisioGlyph(e.type));
        divisiones.add(d);
        ordered.add(d);
      }
    }

    // Horizontal layout: clef, then neumes/divisiones left to right.
    final clefX = sp * 0.4;
    var cursor = clefX + sp * 1.7;
    final neumeGap = sp * 1.0;
    final divisioGap = sp * 0.85;
    for (final o in ordered) {
      if (o is _NeumeBox) {
        o.startX = cursor;
        cursor += o.width + neumeGap;
      } else if (o is _Divisio) {
        o.x = cursor;
        cursor += divisioGap;
      }
    }

    return GregorianLayout._(
      neumes: neumes,
      divisiones: divisiones,
      clef: clef,
      clefX: clefX,
      contentWidth: cursor + sp * 1.2,
      staffSpace: sp,
      hasSyllables: hasSyllables,
    );
  }

  double totalHeight() {
    final sp = staffSpace;
    final lyric = hasSyllables ? sp * 2.2 : 0.0;
    return sp * 7.0 + lyric;
  }
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

  double get _staffCenterY => theme.staffSpace * 3.4;

  /// Canvas Y of staff line [line] (1 = bottom .. 4 = top).
  double _lineY(int line) =>
      _staffCenterY +
      (_staffHalfHeight - (line - 1) * _lineGap) * theme.staffSpace;

  /// Canvas Y of a note at diatonic [step] (median centered on staff middle).
  double _stepY(int step) => _staffCenterY - step * _halfStep * theme.staffSpace;

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

    // Staff: tile chantStaff across the content width.
    var sx = 0.0;
    while (sx < layout.contentWidth) {
      _glyph(canvas, 'chantStaff', sx, _staffCenterY);
      sx += _staffAdvance * sp;
    }

    // Clef on its line.
    _glyph(canvas, layout.clef.glyphName, layout.clefX, _lineY(layout.clef.line));

    final lyricTop = _lineY(1) + sp * 1.4;

    for (final box in layout._neumes) {
      // Connecting lines / ligaturas first, then noteheads on top.
      for (final op in box.ops) {
        if (op.kind == _OpKind.ascLine) {
          final y = (_stepY(op.step) + _stepY(op.step2)) / 2;
          _glyph(canvas, op.glyph, box.startX + op.dx, y);
        } else if (op.kind == _OpKind.descLig) {
          // Fused descending pair, registered near the top (starting) note.
          _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(op.step));
        }
      }
      for (final op in box.ops) {
        if (op.kind == _OpKind.note) {
          _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(op.step));
        }
      }
      // Rhythmic / expressive marks on top of the noteheads.
      for (final op in box.ops) {
        switch (op.kind) {
          case _OpKind.episema:
            // Horizontal bar just above the notehead.
            _glyph(canvas, op.glyph, box.startX + op.dx,
                _stepY(op.step) - sp * 0.55);
          case _OpKind.ictus:
            // Vertical episema below (or above) the notehead.
            final dy = op.glyph == 'chantIctusAbove' ? -sp * 0.7 : sp * 0.7;
            _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(op.step) + dy);
          case _OpKind.mora:
            // Augmentum dot to the right, at note height.
            _glyph(canvas, op.glyph, box.startX + op.dx, _stepY(op.step));
          default:
            break;
        }
      }
      if (box.syllable != null && box.syllable!.isNotEmpty) {
        _lyric(canvas, box.syllable!, (box.startX + box.endX) / 2, lyricTop);
      }
    }

    for (final d in layout._divisiones) {
      _glyph(canvas, d.glyphName, d.x, _staffCenterY);
    }
  }

  @override
  bool shouldRepaint(covariant GregorianPainter old) =>
      old.layout != layout || old.theme != theme;
}
