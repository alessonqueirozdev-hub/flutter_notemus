// lib/src/widgets/grand_staff.dart
//
// Public widget that renders a multi-staff system (grand staff / ensemble) from
// a [StaffGroup]: the staves are stacked vertically, aligned on a shared
// horizontal grid, and connected by a brace/bracket and continuous barlines.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../rendering/grand_staff_painter.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';

/// Renders a whole [Score] — each of its [StaffGroup]s as a [GrandStaff],
/// stacked vertically. A single-group score (piano, SATB) renders as one
/// grand staff; a multi-group score (e.g. choir + piano) stacks the groups.
///
/// ```dart
/// ScoreView(score: MusicXMLParser.scoreFromMusicXML(xml));
/// ```
class ScoreView extends StatelessWidget {
  final Score score;
  final MusicScoreTheme theme;
  final double staffSpace;

  const ScoreView({
    super.key,
    required this.score,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final groups = score.staffGroups;
    if (groups.isEmpty) return const SizedBox.shrink();
    // All groups on one unified horizontal grid (a true multi-section system).
    return GrandStaff(groups: groups, theme: theme, staffSpace: staffSpace);
  }
}

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
/// Wraps into stacked systems when the music is wider than one line. For a
/// single staff use [MusicScore] instead; for a whole [Score] use [ScoreView].
class GrandStaff extends StatefulWidget {
  /// The staves (and their brace/bracket) to render together. Provide this or
  /// [groups].
  final StaffGroup? group;

  /// Multiple groups rendered on one unified grid (ensemble / full score).
  final List<StaffGroup>? groups;

  /// Visual theme.
  final MusicScoreTheme theme;

  /// Staff space in logical pixels.
  final double staffSpace;

  /// Baseline-to-baseline vertical distance between adjacent staves. Defaults
  /// to 11 staff spaces (a comfortable grand-staff gap).
  final double? staffGap;

  const GrandStaff({
    super.key,
    this.group,
    this.groups,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.staffGap,
  }) : assert(group != null || groups != null,
            'Provide either group or groups');

  List<StaffGroup> get _groups => groups ?? [group!];

  @override
  State<GrandStaff> createState() => _GrandStaffState();
}

class _GrandStaffState extends State<GrandStaff> {
  late Future<void> _metadataFuture;
  late SmuflMetadata _metadata;

  /// Owned by the widget (not created per build) so the scroll offset survives
  /// a rebuild — a theme change or a hot reload used to be able to jump the
  /// reader back to bar 1.
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _metadata = SmuflMetadata();
    _metadataFuture = _metadata.load();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  double get _gap => widget.staffGap ?? widget.staffSpace * 11.0;

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
        if (widget._groups.every((g) => g.staves.isEmpty)) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 800.0;
            // Build the painter first so we can size to its (multi-system) height.
            final painter = GrandStaffPainter(
              groups: widget._groups,
              staffSpace: widget.staffSpace,
              metadata: _metadata,
              theme: widget.theme,
              availableWidth: width,
              staffGap: _gap,
            );
            final height = painter.totalHeight;
            // The canvas must be at least as wide as the music, or the
            // horizontal scroll view has nothing to scroll and everything past
            // the viewport is clipped away for good. Measured before this
            // existed: one bar of 2000 thirty-second notes at a 300 px
            // viewport laid out to x = 57,436.2 px inside a `CustomPaint`
            // pinned at 300.0 px, with ZERO scrollables in the tree — 99.5% of
            // the bar was unreachable. `MusicScore` has always sized itself
            // this way from `LayoutEngine.contentWidth`; this is the
            // multi-staff analogue.
            final canvasWidth = math.max(painter.contentWidth, width);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalController,
              child: SizedBox(
                width: canvasWidth,
                height: height,
                child: CustomPaint(
                  size: Size(canvasWidth, height),
                  painter: painter,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
