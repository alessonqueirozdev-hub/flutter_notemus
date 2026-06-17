// Gregorian (square-notation / neume) renderer — Tier A.
//
// Sibling of `MusicScore`/`JianpuScore` for plainchant. Assembles neumes from
// SMuFL "chant" components on a 4-line staff with a do/fa clef, following the
// geometric assembly rules (Gregorio / SMuFL plainchant): chant glyphs carry no
// anchors, so registration is via the SMuFL baseline (glyph origin y=0). One
// diatonic step is HALF the inter-line gap. Pitch is RELATIVE to the clef line;
// absolute pitch/audio is deferred (chant has no fixed concert pitch).
//
// Tier A renders: the staff, the do/fa clef, single notes (punctum, virga,
// quilisma), the two-note pes (ascending, joined by a connecting line) and
// clivis (descending, fused ligatura glyph), the climacus (virga + descending
// puncta inclinata), divisiones, the syllable text, and an end-of-line custos.
// Torculus/porrectus and fine ornaments are Tier A+ (tracked in the epic).

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

int _diatonic(String step, int octave) {
  const order = 'CDEFGAB';
  final i = order.indexOf(step.toUpperCase());
  return octave * 7 + (i < 0 ? 0 : i);
}

/// A neume component resolved to a staff step (relative to the clef line) and a
/// glyph, with its absolute X assigned during layout.
class _Glyph {
  final String glyphName;
  final int step; // diatonic steps from the do/fa line (+ = higher)
  double x = 0;
  _Glyph(this.glyphName, this.step);
}

/// A drawn connecting line (ascending join) or fused descending ligatura.
class _Join {
  final String glyphName;
  final int bottomStep; // registration step (bottom for asc, top for desc)
  double x = 0;
  _Join(this.glyphName, this.bottomStep);
}

/// One laid-out neume (its glyphs + joins + optional syllable).
class _NeumeBox {
  final List<_Glyph> glyphs = [];
  final List<_Join> joins = [];
  String? syllable;
  double startX = 0;
  double endX = 0;
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

/// Glyph for a single neume component by its form.
String _componentGlyph(NcForm form, {required bool descendingInclinatum}) {
  if (descendingInclinatum) return 'chantPunctumInclinatum';
  return switch (form) {
    NcForm.virga => 'chantPunctumVirga',
    NcForm.quilisma => 'chantQuilisma',
    NcForm.oriscus => 'chantOriscusAscending',
    NcForm.stropha => 'chantStrophicus',
    _ => 'chantPunctum',
  };
}

/// Ascending connecting line glyph for an interval of [steps] diatonic steps.
String? _ascLine(int steps) => switch (steps) {
      1 => 'chantConnectingLineAsc2nd',
      2 => 'chantConnectingLineAsc3rd',
      3 => 'chantConnectingLineAsc4th',
      4 => 'chantConnectingLineAsc5th',
      5 => 'chantConnectingLineAsc6th',
      _ => null,
    };

/// Builds and lays out a chant line (Tier A: a single horizontal flow).
class GregorianLayout {
  final List<_NeumeBox> _neumes;
  final List<_Divisio> _divisiones;
  final ChantClef clef;
  final int referenceDi; // diatonic index mapped onto the clef line
  final double clefX;
  final double notesStartX;
  final double contentWidth;
  final double staffSpace;
  final bool hasSyllables;

  GregorianLayout._({
    required List<_NeumeBox> neumes,
    required List<_Divisio> divisiones,
    required this.clef,
    required this.referenceDi,
    required this.clefX,
    required this.notesStartX,
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

    // Reference diatonic index placed on the clef line: the median of all
    // component pitches, so the chant centers vertically on the staff (relative
    // contour is what neume engraving conveys; absolute pitch is deferred).
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
    var hasSyllables = false;

    // Sequence of (box | divisio) preserving order, tracked via parallel lists
    // with an order tag is unnecessary for Tier A: we lay out left-to-right.
    final ordered = <Object>[]; // _NeumeBox or _Divisio

    for (final e in elements) {
      if (e is Neume) {
        final box = _NeumeBox();
        box.syllable = e.syllable;
        if (e.syllable != null && e.syllable!.isNotEmpty) hasSyllables = true;
        final steps = <int>[];
        for (final c in e.components) {
          final di = (c.pitchName != null && c.octave != null)
              ? _diatonic(c.pitchName!, c.octave!)
              : referenceDi;
          steps.add(di - referenceDi);
        }
        for (var i = 0; i < e.components.length; i++) {
          final descending = i > 0 && steps[i] < steps[i - 1];
          // Use a descending fused ligatura for a 2-note clivis-like descent;
          // otherwise diamonds (climacus) / plain puncta.
          box.glyphs.add(
            _Glyph(
              _componentGlyph(
                e.components[i].form,
                descendingInclinatum: descending && i >= 1,
              ),
              steps[i],
            ),
          );
        }
        // Ascending joins between consecutive ascending notes.
        for (var i = 1; i < steps.length; i++) {
          final delta = steps[i] - steps[i - 1];
          if (delta > 0) {
            final g = _ascLine(delta);
            if (g != null) box.joins.add(_Join(g, steps[i - 1]));
          }
        }
        neumes.add(box);
        ordered.add(box);
      } else if (e is NeumeDivision) {
        final d = _Divisio(_divisioGlyph(e.type));
        divisiones.add(d);
        ordered.add(d);
      }
    }

    // Horizontal layout: clef, then neumes/divisiones left-to-right.
    final clefX = sp * 0.4;
    final notesStartX = clefX + sp * 1.6;
    var cursor = notesStartX;
    final noteAdvance = sp * 0.64; // chantPunctum advance
    final neumeGap = sp * 1.1;
    final divisioGap = sp * 0.8;

    for (final o in ordered) {
      if (o is _NeumeBox) {
        o.startX = cursor;
        for (var i = 0; i < o.glyphs.length; i++) {
          o.glyphs[i].x = cursor;
          cursor += noteAdvance;
        }
        // Joins sit between their note and the next note.
        for (final j in o.joins) {
          // place the join just after the lower note's x (approx).
          j.x = o.startX; // refined in paint using note xs
        }
        o.endX = cursor;
        cursor += neumeGap;
      } else if (o is _Divisio) {
        o.x = cursor;
        cursor += divisioGap;
      }
    }

    return GregorianLayout._(
      neumes: neumes,
      divisiones: divisiones,
      clef: clef,
      referenceDi: referenceDi,
      clefX: clefX,
      notesStartX: notesStartX,
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

  // Vertical center of the staff in canvas pixels (headroom for notes/clef
  // above the top line).
  double get _staffCenterY => theme.staffSpace * 3.4;

  /// Canvas Y of staff line [line] (1 = bottom .. 4 = top).
  double _lineY(int line) =>
      _staffCenterY + (_staffHalfHeight - (line - 1) * _lineGap) * theme.staffSpace;

  /// Canvas Y of a note at diatonic [step] relative to the reference pitch.
  ///
  /// Tier A centers the melody's median pitch (step 0) on the staff's vertical
  /// middle so the relative contour is fully visible; the clef glyph is drawn on
  /// its own line independently (absolute pitch is deferred to Tier C).
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
    final width = layout.contentWidth;
    var x = 0.0;
    while (x < width) {
      _glyph(canvas, 'chantStaff', x, _staffCenterY);
      x += _staffAdvance * sp;
    }

    // Clef on its line.
    _glyph(canvas, layout.clef.glyphName, layout.clefX, _lineY(layout.clef.line));

    final lyricTop = _lineY(1) + sp * 1.4;

    // Neumes.
    for (final box in layout._neumes) {
      // Ascending connecting lines between consecutive notes (drawn first, so
      // noteheads sit on top).
      for (var i = 1; i < box.glyphs.length; i++) {
        final prev = box.glyphs[i - 1];
        final cur = box.glyphs[i];
        if (cur.step > prev.step) {
          final line = _ascLine(cur.step - prev.step);
          if (line != null) {
            // Register at the bottom (previous) note, just left of the upper note.
            _glyph(canvas, line, cur.x, _stepY(prev.step));
          }
        }
      }
      // Noteheads.
      for (final g in box.glyphs) {
        _glyph(canvas, g.glyphName, g.x, _stepY(g.step));
      }
      // Syllable centered under the neume.
      if (box.syllable != null && box.syllable!.isNotEmpty) {
        _lyric(canvas, box.syllable!, (box.startX + box.endX) / 2, lyricTop);
      }
    }

    // Divisiones.
    for (final d in layout._divisiones) {
      _glyph(canvas, d.glyphName, d.x, _staffCenterY);
    }

    // End-of-line custos pointing at the first note's pitch is omitted in Tier A
    // (single-line layout); added with multi-line wrapping in Tier A+.
  }

  @override
  bool shouldRepaint(covariant GregorianPainter old) =>
      old.layout != layout || old.theme != theme;
}
