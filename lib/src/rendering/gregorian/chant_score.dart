// ChantScore — widget that renders Gregorian (square-notation) chant.
//
// Sibling of `MusicScore`/`JianpuScore`. Renders precomposed neume glyphs from
// the Greciliae chant font, so it loads the Greciliae glyph map before painting.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

import 'gabc_parser.dart';
import 'greciliae_font.dart';
import 'gregorian_renderer.dart';

/// Renders a sequence of [Neume]/[NeumeDivision] elements as Gregorian chant
/// under the given [clef].
class ChantScore extends StatefulWidget {
  /// The chant content: a flat list of [Neume] and [NeumeDivision] elements.
  final List<MusicalElement> elements;

  /// The chant clef (do/fa on a staff line). Defaults to a do clef on line 4.
  final ChantClef clef;

  final GregorianTheme theme;

  const ChantScore({
    super.key,
    required this.elements,
    this.clef = const ChantClef(),
    this.theme = const GregorianTheme(),
  });

  /// Builds a [ChantScore] from a GABC (Gregorio) document.
  factory ChantScore.fromGabc(
    String gabc, {
    Key? key,
    GregorianTheme theme = const GregorianTheme(),
  }) {
    final result = GabcParser.parse(gabc);
    return ChantScore(
      key: key,
      elements: result.elements,
      clef: result.clef,
      theme: theme,
    );
  }

  @override
  State<ChantScore> createState() => _ChantScoreState();
}

class _ChantScoreState extends State<ChantScore> {
  late final Future<void> _fontFuture;
  final GreciliaeFont _font = GreciliaeFont();

  @override
  void initState() {
    super.initState();
    _fontFuture = _font.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _fontFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
            final layout = GregorianLayout.build(
              widget.elements,
              widget.clef,
              maxWidth,
              widget.theme,
              _font,
            );
            return SingleChildScrollView(
              child: CustomPaint(
                size: Size(layout.width, layout.totalHeight()),
                painter: GregorianPainter(
                  layout: layout,
                  theme: widget.theme,
                  font: _font,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
