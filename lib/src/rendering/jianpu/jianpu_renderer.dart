// Jianpu (numbered notation) renderer — GB/T 46845-2025 (§5–§6 + lyrics).
//
// Self-contained CustomPainter that draws a single-staff score as Jianpu:
// numerals 1–7, octave dots, accidentals, beat-grouped diminution underlines
// (减时线), augmentation dashes (增时线) and dots (附点), rests (0), ties,
// tuplets (连音符), lyrics under the numerals, structural barlines/repeats and
// a `1=<key>  n/d` header. Walks the notation-agnostic music model directly
// and does not touch the SMuFL staff rendering path.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

import 'jianpu_pitch_mapper.dart';

/// Visual configuration for [JianpuPainter] / `JianpuScore`.
class JianpuTheme {
  final Color color;
  final double numeralSize;

  const JianpuTheme({
    this.color = const Color(0xFF101010),
    this.numeralSize = 22.0,
  });
}

/// End-of-measure barline kinds Jianpu draws.
enum _BarKind { single, double_, finalBar, repeatEnd, repeatStartEnd }

/// One positioned note/rest cell.
class _Glyph {
  final String accidental;
  final String numeral; // '1'..'7' or '0'
  final int octaveDots; // signed: >0 above, <0 below
  final int underlines; // 减时线 level count
  final int dashes; // 增时线 count
  final int augDots; // 附点 count
  final bool tieStart;
  final List<String> lyrics; // per-verse syllable text
  final int beatIndex; // for underline grouping (per measure)

  double accX = 0; // left of accidental
  double numX = 0; // left of numeral
  double numW = 0; // numeral width
  double advance = 0; // full advance for this cell

  _Glyph({
    required this.accidental,
    required this.numeral,
    required this.octaveDots,
    required this.underlines,
    required this.dashes,
    required this.augDots,
    required this.tieStart,
    required this.lyrics,
    required this.beatIndex,
  });

  double get numCenter => numX + numW / 2;
}

class _Measure {
  final List<_Glyph> glyphs = [];
  final List<(int, int, int)> tuplets = []; // (startIdx, endIdx, number)
  bool repeatStart = false;
  _BarKind endBar = _BarKind.single;
  double startX = 0;
  double endX = 0;
}

class _Row {
  final List<_Measure> measures = [];
  double width = 0;
}

({int underlines, int dashes, int augDots}) _durationParts(Duration d) {
  final underlines = switch (d.type) {
    DurationType.eighth => 1,
    DurationType.sixteenth => 2,
    DurationType.thirtySecond => 3,
    DurationType.sixtyFourth => 4,
    DurationType.oneHundredTwentyEighth => 5,
    _ => 0,
  };
  // Augmentation dashes: extra beats a sustained value occupies beyond one.
  final dashes = switch (d.type) {
    DurationType.half => 1,
    DurationType.whole => 3,
    DurationType.breve => 7,
    DurationType.long || DurationType.maxima => 7,
    _ => 0,
  };
  return (underlines: underlines, dashes: dashes, augDots: d.dots);
}

_BarKind _barKind(BarlineType t) => switch (t) {
      BarlineType.double || BarlineType.lightLight => _BarKind.double_,
      BarlineType.final_ || BarlineType.lightHeavy => _BarKind.finalBar,
      BarlineType.repeatBackward => _BarKind.repeatEnd,
      BarlineType.repeatBoth => _BarKind.repeatStartEnd,
      _ => _BarKind.single,
    };

/// Builds the Jianpu layout (rows of measures) for [staff] within [maxWidth].
class JianpuLayout {
  final List<_Row> _rows;
  final JianpuPitchMapper mapper;
  final TimeSignature? timeSignature;
  final int verseCount;
  final double headerHeight;
  final double rowHeight;

  JianpuLayout._(
    this._rows,
    this.mapper,
    this.timeSignature,
    this.verseCount,
    this.headerHeight,
    this.rowHeight,
  );

  int get rowCount => _rows.length;

  factory JianpuLayout.build(Staff staff, double maxWidth, JianpuTheme theme) {
    final size = theme.numeralSize;
    final gap = size * 0.5;
    final dashW = size * 0.7;
    final dotAdv = size * 0.34;
    final barPad = size * 0.55;

    JianpuPitchMapper headerMapper = JianpuPitchMapper(0);
    TimeSignature? timeSig;
    for (final m in staff.measures) {
      for (final e in m.elements) {
        if (e is KeySignature) headerMapper = JianpuPitchMapper.fromKeySignature(e);
        if (e is TimeSignature) timeSig ??= e;
      }
      if (timeSig != null) break;
    }
    final beatWhole = timeSig != null ? 1.0 / timeSig.denominator : 0.25;

    final tp = TextPainter(textDirection: TextDirection.ltr);
    double textW(String s, double scale) {
      tp.text = TextSpan(
        text: s,
        style: TextStyle(fontSize: size * scale, color: theme.color),
      );
      tp.layout();
      return tp.width;
    }

    var verseCount = 0;
    var liveMapper = headerMapper;
    final builtMeasures = <_Measure>[];

    void addGlyph(_Measure box, Note? note, Rest? rest, double onset) {
      final dur = note?.duration ?? rest!.duration;
      final parts = _durationParts(dur);
      final beatIndex = (onset / beatWhole + 1e-6).floor();
      List<String> lyrics = const [];
      if (note?.syllables != null && note!.syllables!.isNotEmpty) {
        lyrics = note.syllables!.map((s) => s.text).toList();
        if (lyrics.length > verseCount) verseCount = lyrics.length;
      }
      final j = note != null ? liveMapper.map(note.pitch) : null;
      final g = _Glyph(
        accidental: j?.accidental ?? '',
        numeral: j?.numeral ?? '0',
        octaveDots: j?.octaveDots ?? 0,
        underlines: parts.underlines,
        dashes: parts.dashes,
        augDots: parts.augDots,
        tieStart: note?.tie == TieType.start,
        lyrics: lyrics,
        beatIndex: beatIndex,
      );
      g.accX = box.endX;
      var cursor = box.endX;
      if (g.accidental.isNotEmpty) cursor += textW(g.accidental, 0.6) + size * 0.04;
      g.numX = cursor;
      g.numW = textW(g.numeral, 1.0);
      cursor += g.numW + g.augDots * dotAdv + g.dashes * dashW + gap;
      g.advance = cursor - box.endX;
      box.endX = cursor;
      box.glyphs.add(g);
    }

    for (final m in staff.measures) {
      final box = _Measure();
      box.endX = 0;
      var onset = 0.0;
      Barline? trailing;
      for (final e in m.elements) {
        if (e is KeySignature) {
          liveMapper = JianpuPitchMapper.fromKeySignature(e);
        } else if (e is Barline) {
          if (box.glyphs.isEmpty && e.type == BarlineType.repeatForward) {
            box.repeatStart = true;
          } else {
            trailing = e;
          }
        } else if (e is Note) {
          addGlyph(box, e, null, onset);
          onset += e.duration.realValue;
        } else if (e is Rest) {
          addGlyph(box, null, e, onset);
          onset += e.duration.realValue;
        } else if (e is Chord) {
          // Render the chord as its top note (melody line) for MVP.
          final top = e.notes.reduce(
            (a, b) => a.pitch.midiNumber >= b.pitch.midiNumber ? a : b,
          );
          addGlyph(
            box,
            Note(pitch: top.pitch, duration: e.duration),
            null,
            onset,
          );
          onset += e.duration.realValue;
        } else if (e is Tuplet) {
          final start = box.glyphs.length;
          for (final inner in e.elements) {
            if (inner is Note) {
              addGlyph(box, inner, null, onset);
            } else if (inner is Rest) {
              addGlyph(box, null, inner, onset);
            }
          }
          final end = box.glyphs.length - 1;
          if (end >= start) box.tuplets.add((start, end, e.actualNotes));
          onset += e.totalDuration;
        }
      }
      box.endBar = trailing != null ? _barKind(trailing.type) : _BarKind.single;
      if (box.glyphs.isNotEmpty) builtMeasures.add(box);
    }

    // Final barline at the end of the piece unless an explicit one was set.
    if (builtMeasures.isNotEmpty &&
        builtMeasures.last.endBar == _BarKind.single) {
      builtMeasures.last.endBar = _BarKind.finalBar;
    }

    // Wrap measures into rows by width.
    final rows = <_Row>[];
    var current = _Row();
    for (final box in builtMeasures) {
      final w = box.endX + barPad * 2;
      if (current.measures.isNotEmpty &&
          current.width + w > maxWidth &&
          maxWidth > 0) {
        rows.add(current);
        current = _Row();
      }
      current.measures.add(box);
      current.width += w;
    }
    if (current.measures.isNotEmpty) rows.add(current);

    final lyricBlock = verseCount * size * 1.05;
    final rowHeight = size * 2.9 + lyricBlock;
    final headerHeight = size * 1.9;
    return JianpuLayout._(
      rows,
      headerMapper,
      timeSig,
      verseCount,
      headerHeight,
      rowHeight,
    );
  }

  double totalHeight() => headerHeight + _rows.length * rowHeight + rowHeight;
}

/// Paints a [JianpuLayout].
class JianpuPainter extends CustomPainter {
  final JianpuLayout layout;
  final JianpuTheme theme;

  JianpuPainter({required this.layout, required this.theme});

  TextPainter _text(String s, {double scale = 1.0}) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: theme.numeralSize * scale,
            color: theme.color,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final s = theme.numeralSize;
    final stroke = Paint()
      ..color = theme.color
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;
    final thick = Paint()
      ..color = theme.color
      ..strokeWidth = s * 0.18
      ..strokeCap = StrokeCap.butt;

    final header = StringBuffer('1=${layout.mapper.tonicName}');
    if (layout.timeSignature != null) {
      header.write(
        '    ${layout.timeSignature!.numerator}/'
        '${layout.timeSignature!.denominator}',
      );
    }
    _text(header.toString(), scale: 0.85).paint(canvas, const Offset(0, 0));

    final dashW = s * 0.7;
    final barPad = s * 0.55;
    final underlineGap = s * 0.15;
    double y = layout.headerHeight + s * 1.4;

    for (final row in layout._rows) {
      double x = barPad;
      for (final box in row.measures) {
        if (box.repeatStart) {
          _barline(canvas, stroke, thick, x, y, _BarKind.repeatStartEnd,
              startOnly: true);
          x += barPad;
        }
        // Position this measure's glyphs absolutely from the measure origin
        // (build stored only per-cell advances, measure-relative).
        double cur = x;
        for (final g in box.glyphs) {
          g.accX = cur;
          var c = cur;
          if (g.accidental.isNotEmpty) {
            final acc = _text(g.accidental, scale: 0.58);
            acc.paint(canvas, Offset(c, y - s * 0.62));
            c += acc.width + s * 0.04;
          }
          g.numX = c;
          final num = _text(g.numeral);
          g.numW = num.width;
          num.paint(canvas, Offset(c, y - num.height / 2));

          // Octave dots.
          if (g.octaveDots != 0) {
            final r = s * 0.075;
            final n = g.octaveDots.abs();
            for (var i = 0; i < n; i++) {
              final dy = g.octaveDots > 0
                  ? y - num.height / 2 - s * 0.16 - i * (r * 3.2)
                  : y +
                      num.height / 2 +
                      s * 0.12 +
                      g.underlines * underlineGap +
                      s * 0.12 +
                      i * (r * 3.2);
              canvas.drawCircle(Offset(g.numCenter, dy), r, stroke);
            }
          }

          c += num.width;
          // Augmentation dots.
          for (var i = 0; i < g.augDots; i++) {
            c += s * 0.17;
            canvas.drawCircle(Offset(c, y), s * 0.07, stroke);
            c += s * 0.17;
          }
          // Augmentation dashes.
          for (var i = 0; i < g.dashes; i++) {
            final dx = c + dashW * 0.18;
            canvas.drawLine(Offset(dx, y), Offset(dx + dashW * 0.62, y),
                stroke);
            c += dashW;
          }

          // Lyrics (verses) centered under the numeral.
          if (g.lyrics.isNotEmpty) {
            var ly = y +
                num.height / 2 +
                g.underlines * underlineGap +
                (g.octaveDots < 0 ? s * 0.5 : 0) +
                s * 0.5;
            for (final verse in g.lyrics) {
              final t = _text(verse, scale: 0.66);
              t.paint(canvas, Offset(g.numCenter - t.width / 2, ly));
              ly += s * 1.0;
            }
          }

          cur += g.advance;
        }

        // Beat-grouped diminution underlines (减时线).
        final maxLvl = box.glyphs.fold<int>(0, (m, g) {
          return g.underlines > m ? g.underlines : m;
        });
        for (var lvl = 1; lvl <= maxLvl; lvl++) {
          int i = 0;
          while (i < box.glyphs.length) {
            if (box.glyphs[i].underlines < lvl) {
              i++;
              continue;
            }
            final beat = box.glyphs[i].beatIndex;
            int j = i;
            while (j + 1 < box.glyphs.length &&
                box.glyphs[j + 1].underlines >= lvl &&
                box.glyphs[j + 1].beatIndex == beat) {
              j++;
            }
            final uy = y +
                _text(box.glyphs[i].numeral).height / 2 +
                s * 0.06 +
                (lvl - 1) * underlineGap;
            canvas.drawLine(
              Offset(box.glyphs[i].numX, uy),
              Offset(box.glyphs[j].numX + box.glyphs[j].numW, uy),
              stroke,
            );
            i = j + 1;
          }
        }

        // Ties.
        for (var i = 0; i < box.glyphs.length - 1; i++) {
          if (!box.glyphs[i].tieStart) continue;
          final a = box.glyphs[i].numCenter;
          final b = box.glyphs[i + 1].numCenter;
          final top = y - _text(box.glyphs[i].numeral).height / 2 - s * 0.14;
          final path = Path()
            ..moveTo(a, top)
            ..quadraticBezierTo((a + b) / 2, top - s * 0.42, b, top);
          canvas.drawPath(
            path,
            Paint()
              ..color = theme.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = s * 0.05,
          );
        }

        // Tuplet brackets with the ratio number above.
        for (final (sIdx, eIdx, number) in box.tuplets) {
          final gx0 = box.glyphs[sIdx].numX;
          final gx1 = box.glyphs[eIdx].numX + box.glyphs[eIdx].numW;
          final by = y - _text(box.glyphs[sIdx].numeral).height / 2 - s * 0.7;
          canvas.drawLine(Offset(gx0, by + s * 0.18), Offset(gx0, by), stroke);
          canvas.drawLine(Offset(gx0, by), Offset(gx1, by), stroke);
          canvas.drawLine(Offset(gx1, by), Offset(gx1, by + s * 0.18), stroke);
          final t = _text('$number', scale: 0.62);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset((gx0 + gx1) / 2, by),
              width: t.width + s * 0.18,
              height: t.height,
            ),
            Paint()..color = const Color(0xFFFFFFFF),
          );
          t.paint(
            canvas,
            Offset((gx0 + gx1) / 2 - t.width / 2, by - t.height / 2),
          );
        }

        x = cur + barPad * 0.3;
        _barline(canvas, stroke, thick, x, y, box.endBar);
        x += barPad;
      }
      y += layout.rowHeight;
    }
  }

  void _barline(
    Canvas canvas,
    Paint stroke,
    Paint thick,
    double x,
    double y,
    _BarKind kind, {
    bool startOnly = false,
  }) {
    final s = theme.numeralSize;
    final top = y - s * 0.75;
    final bot = y + s * 0.75;
    void thin(double px) =>
        canvas.drawLine(Offset(px, top), Offset(px, bot), stroke);
    void heavy(double px) =>
        canvas.drawLine(Offset(px, top), Offset(px, bot), thick);
    void dots(double px) {
      canvas.drawCircle(Offset(px, y - s * 0.22), s * 0.07, stroke);
      canvas.drawCircle(Offset(px, y + s * 0.22), s * 0.07, stroke);
    }

    switch (kind) {
      case _BarKind.single:
        thin(x);
      case _BarKind.double_:
        thin(x);
        thin(x + s * 0.22);
      case _BarKind.finalBar:
        thin(x);
        heavy(x + s * 0.26);
      case _BarKind.repeatEnd:
        dots(x);
        thin(x + s * 0.28);
        heavy(x + s * 0.5);
      case _BarKind.repeatStartEnd:
        if (startOnly) {
          heavy(x);
          thin(x + s * 0.22);
          dots(x + s * 0.5);
        } else {
          dots(x);
          thin(x + s * 0.28);
          heavy(x + s * 0.5);
        }
    }
  }

  @override
  bool shouldRepaint(covariant JianpuPainter old) =>
      old.layout != layout || old.theme != theme;
}
