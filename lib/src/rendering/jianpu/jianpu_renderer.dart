// Jianpu (numbered notation) renderer — GB/T 46845-2025 (MVP, §5–§6 subset).
//
// A self-contained CustomPainter that draws a single-staff melody as Jianpu:
// numerals 1–7, octave dots, accidentals, duration underlines / augmentation
// dashes / dots, rests (0), ties and barlines, with a `1=<key>  n/d` header.
// It walks the notation-agnostic music model directly and does not touch the
// SMuFL staff rendering path.

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

/// One drawable Jianpu cell (a note or rest) with precomputed glyph parts.
class _Cell {
  final String numeral; // '1'..'7' or '0'
  final String accidental; // '', '#', 'b'
  final int octaveDots; // >0 above, <0 below
  final int underlines; // 减时线 count
  final int dashes; // 增时线 count
  final int dots; // 附点 count
  final bool tieStart;
  double width = 0;

  _Cell({
    required this.numeral,
    required this.accidental,
    required this.octaveDots,
    required this.underlines,
    required this.dashes,
    required this.dots,
    required this.tieStart,
  });
}

/// A laid-out row: a list of measures, each a list of cells.
class _Row {
  final List<List<_Cell>> measures = [];
  double width = 0;
}

/// Computes duration decoration counts from a [Duration].
({int underlines, int dashes, int dots}) _durationParts(Duration d) {
  final underlines = switch (d.type) {
    DurationType.eighth => 1,
    DurationType.sixteenth => 2,
    DurationType.thirtySecond => 3,
    DurationType.sixtyFourth => 4,
    DurationType.oneHundredTwentyEighth => 5,
    _ => 0,
  };
  final dashes = switch (d.type) {
    DurationType.half => 1,
    DurationType.whole => 3,
    DurationType.breve ||
    DurationType.long ||
    DurationType.maxima =>
      3, // capped for MVP readability
    _ => 0,
  };
  return (underlines: underlines, dashes: dashes, dots: d.dots);
}

/// Builds the Jianpu layout (rows of measures) for [staff] within [maxWidth].
class JianpuLayout {
  final List<_Row> _rows;
  final JianpuPitchMapper mapper;
  final TimeSignature? timeSignature;
  final double headerHeight;
  final double rowHeight;

  JianpuLayout._(
    this._rows,
    this.mapper,
    this.timeSignature,
    this.headerHeight,
    this.rowHeight,
  );

  /// Number of laid-out rows (after measure-based line wrapping).
  int get rowCount => _rows.length;

  factory JianpuLayout.build(
    Staff staff,
    double maxWidth,
    JianpuTheme theme,
  ) {
    JianpuPitchMapper mapper = const JianpuPitchMapper(0); // default 1=C
    TimeSignature? timeSig;
    final size = theme.numeralSize;
    final cellGap = size * 0.55;
    final dashWidth = size * 0.7;
    final barlinePad = size * 0.5;

    // First pass: pick up the first key/time signature for the header/mapper.
    for (final m in staff.measures) {
      for (final e in m.elements) {
        if (e is KeySignature) {
          mapper = JianpuPitchMapper.fromKeySignature(e);
        } else if (e is TimeSignature) {
          timeSig ??= e;
        }
      }
      if (timeSig != null) break;
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);
    double measureNumeralWidth(String s) {
      tp.text = TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: theme.color),
      );
      tp.layout();
      return tp.width;
    }

    // Build measures of cells.
    final allMeasures = <List<_Cell>>[];
    JianpuPitchMapper liveMapper = mapper;
    for (final m in staff.measures) {
      final cells = <_Cell>[];
      for (final e in m.elements) {
        if (e is KeySignature) {
          liveMapper = JianpuPitchMapper.fromKeySignature(e);
          continue;
        }
        if (e is Note) {
          final j = liveMapper.map(e.pitch);
          final parts = _durationParts(e.duration);
          final cell = _Cell(
            numeral: j.numeral,
            accidental: j.accidental,
            octaveDots: j.octaveDots,
            underlines: parts.underlines,
            dashes: parts.dashes,
            dots: parts.dots,
            tieStart: e.tie == TieType.start,
          );
          cell.width = measureNumeralWidth('${j.accidental}${j.numeral}') +
              cell.dots * (size * 0.4) +
              cell.dashes * dashWidth +
              cellGap;
          cells.add(cell);
        } else if (e is Rest) {
          final parts = _durationParts(e.duration);
          final cell = _Cell(
            numeral: '0',
            accidental: '',
            octaveDots: 0,
            underlines: parts.underlines,
            dashes: parts.dashes,
            dots: parts.dots,
            tieStart: false,
          );
          cell.width = measureNumeralWidth('0') +
              cell.dots * (size * 0.4) +
              cell.dashes * dashWidth +
              cellGap;
          cells.add(cell);
        }
        // Clef and other staff-only elements are ignored in Jianpu.
      }
      if (cells.isNotEmpty) allMeasures.add(cells);
    }

    // Second pass: wrap measures into rows by width.
    final rows = <_Row>[];
    _Row current = _Row();
    for (final measure in allMeasures) {
      final mWidth =
          measure.fold<double>(0, (s, c) => s + c.width) + barlinePad * 2;
      if (current.measures.isNotEmpty &&
          current.width + mWidth > maxWidth &&
          maxWidth > 0) {
        rows.add(current);
        current = _Row();
      }
      current.measures.add(measure);
      current.width += mWidth;
    }
    if (current.measures.isNotEmpty) rows.add(current);

    final rowHeight = size * 3.2; // numeral + octave dots + underlines + slack
    final headerHeight = size * 1.8;
    return JianpuLayout._(rows, mapper, timeSig, headerHeight, rowHeight);
  }

  double totalHeight() => headerHeight + _rows.length * rowHeight + rowHeight;
}

/// Paints a [JianpuLayout].
class JianpuPainter extends CustomPainter {
  final JianpuLayout layout;
  final JianpuTheme theme;

  JianpuPainter({required this.layout, required this.theme});

  TextPainter _text(String s, {double scale = 1.0}) {
    final tp = TextPainter(
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
    return tp;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = theme.numeralSize;
    final paint = Paint()
      ..color = theme.color
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round;

    // Header: 1=<tonic>   n/d
    final header = StringBuffer('1=${layout.mapper.tonicName}');
    if (layout.timeSignature != null) {
      header.write(
        '    ${layout.timeSignature!.numerator}/'
        '${layout.timeSignature!.denominator}',
      );
    }
    _text(header.toString(), scale: 0.85).paint(canvas, const Offset(0, 0));

    double y = layout.headerHeight + layout.rowHeight * 0.5;
    final dashWidth = s * 0.7;
    final cellGap = s * 0.55;
    final barlinePad = s * 0.5;

    for (final row in layout._rows) {
      double x = 0;
      for (final measure in row.measures) {
        for (final cell in measure) {
          x = _paintCell(canvas, paint, cell, x, y, dashWidth, cellGap);
        }
        // Barline after the measure.
        x += barlinePad * 0.4;
        canvas.drawLine(
          Offset(x, y - s * 0.7),
          Offset(x, y + s * 0.7),
          paint,
        );
        x += barlinePad;
      }
      y += layout.rowHeight;
    }
  }

  double _paintCell(
    Canvas canvas,
    Paint paint,
    _Cell cell,
    double x,
    double y,
    double dashWidth,
    double cellGap,
  ) {
    final s = theme.numeralSize;
    double cursor = x;

    // Accidental (smaller, raised before the numeral).
    if (cell.accidental.isNotEmpty) {
      final acc = _text(cell.accidental, scale: 0.6);
      acc.paint(canvas, Offset(cursor, y - s * 0.55));
      cursor += acc.width + s * 0.04;
    }

    // Numeral.
    final num = _text(cell.numeral);
    final numCenterX = cursor + num.width / 2;
    num.paint(canvas, Offset(cursor, y - num.height / 2));
    cursor += num.width;

    // Octave dots (filled circles), above for >0, below for <0.
    final dotR = s * 0.07;
    if (cell.octaveDots != 0) {
      final count = cell.octaveDots.abs();
      final above = cell.octaveDots > 0;
      for (int i = 0; i < count; i++) {
        final dy = above
            ? y - num.height / 2 - s * 0.18 - i * (dotR * 3)
            : y +
                num.height / 2 +
                s * 0.18 +
                cell.underlines * (s * 0.16) +
                i * (dotR * 3);
        canvas.drawCircle(Offset(numCenterX, dy), dotR, paint);
      }
    }

    // Augmentation dots (附点) after the numeral.
    for (int i = 0; i < cell.dots; i++) {
      cursor += s * 0.16;
      canvas.drawCircle(Offset(cursor, y), s * 0.07, paint);
      cursor += s * 0.16;
    }

    // Diminution underlines (减时线) under the numeral.
    for (int i = 0; i < cell.underlines; i++) {
      final uy = y + num.height / 2 + s * 0.08 + i * (s * 0.16);
      canvas.drawLine(Offset(x, uy), Offset(cursor, uy), paint);
    }

    // Augmentation dashes (增时线) after the numeral.
    for (int i = 0; i < cell.dashes; i++) {
      final dx = cursor + dashWidth * 0.2;
      canvas.drawLine(
        Offset(dx, y),
        Offset(dx + dashWidth * 0.6, y),
        paint,
      );
      cursor += dashWidth;
    }

    cursor += cellGap;

    // Tie: a short arc from this numeral toward the next cell.
    if (cell.tieStart) {
      final path = Path()
        ..moveTo(numCenterX, y - num.height / 2 - s * 0.12)
        ..quadraticBezierTo(
          (numCenterX + cursor) / 2,
          y - num.height / 2 - s * 0.5,
          cursor + s * 0.1,
          y - num.height / 2 - s * 0.12,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05,
      );
    }

    return cursor;
  }

  @override
  bool shouldRepaint(covariant JianpuPainter old) =>
      old.layout != layout || old.theme != theme;
}
