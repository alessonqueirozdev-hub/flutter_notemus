// ChantScore — widget that renders Gregorian (square-notation) chant.
//
// Sibling of `MusicScore`/`JianpuScore`. Like `MusicScore` it draws SMuFL chant
// glyphs, so it loads the Bravura metadata before painting.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

import '../../smufl/smufl_metadata_loader.dart';
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

  @override
  State<ChantScore> createState() => _ChantScoreState();
}

class _ChantScoreState extends State<ChantScore> {
  late final Future<void> _metadataFuture;
  final SmuflMetadata _metadata = SmuflMetadata();

  @override
  void initState() {
    super.initState();
    _metadataFuture = _metadata.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _metadataFuture,
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
            );
            return SingleChildScrollView(
              child: CustomPaint(
                size: Size(layout.width, layout.totalHeight()),
                painter: GregorianPainter(
                  layout: layout,
                  theme: widget.theme,
                  metadata: _metadata,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
