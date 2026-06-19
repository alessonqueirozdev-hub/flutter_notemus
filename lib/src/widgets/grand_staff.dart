// lib/src/widgets/grand_staff.dart
//
// Public widget that renders a multi-staff system (grand staff / ensemble) from
// a [StaffGroup]: the staves are stacked vertically, aligned on a shared
// horizontal grid, and connected by a brace/bracket and continuous barlines.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../rendering/grand_staff_painter.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';

/// Renders a [StaffGroup] as a vertically-stacked, horizontally-aligned system
/// (e.g. a piano grand staff or an SATB / ensemble group).
///
/// ```dart
/// GrandStaff(
///   group: StaffGroup(
///     staves: [trebleStaff, bassStaff],
///     bracket: BracketType.brace,
///   ),
/// )
/// ```
///
/// Scope: a single system (no mid-system wrapping) — the common grand-staff and
/// short-example layout. For a single staff use [MusicScore] instead.
class GrandStaff extends StatefulWidget {
  /// The staves (and their brace/bracket) to render together.
  final StaffGroup group;

  /// Visual theme.
  final MusicScoreTheme theme;

  /// Staff space in logical pixels.
  final double staffSpace;

  /// Baseline-to-baseline vertical distance between adjacent staves. Defaults
  /// to 11 staff spaces (a comfortable grand-staff gap).
  final double? staffGap;

  const GrandStaff({
    super.key,
    required this.group,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.staffGap,
  });

  @override
  State<GrandStaff> createState() => _GrandStaffState();
}

class _GrandStaffState extends State<GrandStaff> {
  late Future<void> _metadataFuture;
  late SmuflMetadata _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = SmuflMetadata();
    _metadataFuture = _metadata.load();
  }

  double get _gap => widget.staffGap ?? widget.staffSpace * 11.0;

  double get _height {
    final n = widget.group.staves.length;
    if (n == 0) return 0;
    // First staff baseline at 5 SS; each further staff one gap below; plus the
    // bottom staff's lower half and a margin.
    return (n - 1) * _gap + widget.staffSpace * 5.0 + widget.staffSpace * 4.0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load metadata: ${snapshot.error}'));
        }
        if (widget.group.staves.isEmpty) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 800.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: _height,
                child: CustomPaint(
                  size: Size(width, _height),
                  painter: GrandStaffPainter(
                    staffGroup: widget.group,
                    staffSpace: widget.staffSpace,
                    metadata: _metadata,
                    theme: widget.theme,
                    availableWidth: width,
                    staffGap: _gap,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
