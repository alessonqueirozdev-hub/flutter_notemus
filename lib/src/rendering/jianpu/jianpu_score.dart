// JianpuScore — widget that renders a [Staff] as Jianpu numbered notation.
//
// Sibling of `MusicScore` for the Jianpu (简谱) notation system. Unlike
// `MusicScore` it needs no SMuFL/Bravura font: Jianpu is typographic, so this
// widget is synchronous and self-contained.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

import 'jianpu_renderer.dart';

/// Renders [staff] as Jianpu (numbered) notation with measure-based line
/// wrapping and vertical scrolling for long pieces.
class JianpuScore extends StatelessWidget {
  /// The melody to render. Multi-voice/chord content is not part of the MVP;
  /// only notes and rests are drawn (see GB/T 46845-2025 epic for the roadmap).
  final Staff staff;

  /// Visual configuration (color and numeral size).
  final JianpuTheme theme;

  const JianpuScore({
    super.key,
    required this.staff,
    this.theme = const JianpuTheme(),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 600.0;
        final layout = JianpuLayout.build(staff, maxWidth, theme);
        return SingleChildScrollView(
          child: CustomPaint(
            size: Size(maxWidth, layout.totalHeight()),
            painter: JianpuPainter(layout: layout, theme: theme),
          ),
        );
      },
    );
  }
}
