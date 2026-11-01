// lib/src/widgets/grand_staff.dart
//
// Public widget that renders a multi-staff system (grand staff / ensemble) from
// a [StaffGroup]: the staves are stacked vertically, aligned on a shared
// horizontal grid, and connected by a brace/bracket and continuous barlines.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../interaction/score_taps.dart';
import '../playback/playback_plan.dart';
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

  /// See [GrandStaff.onNoteTap].
  final ValueChanged<ScoreNoteTap>? onNoteTap;

  /// See [GrandStaff.onMeasureTap].
  final ValueChanged<ScoreMeasureTap>? onMeasureTap;

  /// See [GrandStaff.playbackPosition].
  final ValueListenable<PlaybackPosition?>? playbackPosition;

  const ScoreView({
    super.key,
    required this.score,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.onNoteTap,
    this.onMeasureTap,
    this.playbackPosition,
  });

  @override
  Widget build(BuildContext context) {
    final groups = score.staffGroups;
    if (groups.isEmpty) return const SizedBox.shrink();
    // All groups on one unified horizontal grid (a true multi-section system).
    return GrandStaff(
      groups: groups,
      theme: theme,
      staffSpace: staffSpace,
      onNoteTap: onNoteTap,
      onMeasureTap: onMeasureTap,
      playbackPosition: playbackPosition,
    );
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

  /// Called when a note is tapped, with the very [Note] from the caller's
  /// staff (a tap on a chord reports its nearest note) and the bar and staff
  /// it is on. Resolved through `ScoreHitTester`, so the stem and flag count
  /// as the note too.
  final ValueChanged<ScoreNoteTap>? onNoteTap;

  /// Called when a tap lands inside a bar's horizontal span, with its index
  /// and printed number and the staff nearest the tap. Fires together with
  /// [onNoteTap] when the tap is also on a note.
  final ValueChanged<ScoreMeasureTap>? onMeasureTap;

  /// Where playback is, for a cursor drawn across every staff of the system
  /// — typically a `ValueNotifier` set from `PlaybackPlan.positionAt` on each
  /// clock tick. Its own layer: a tick repaints one line, not the notation.
  /// Coloured by `MusicScoreTheme.playheadColor`.
  final ValueListenable<PlaybackPosition?>? playbackPosition;

  const GrandStaff({
    super.key,
    this.group,
    this.groups,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.staffGap,
    this.onNoteTap,
    this.onMeasureTap,
    this.playbackPosition,
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

  /// Stacks the playback cursor layer over [child] when there is a position
  /// to follow.
  Widget _withPlayhead(GrandStaffPainter painter, Size size, Widget child) {
    final position = widget.playbackPosition;
    if (position == null) return child;
    return Stack(
      children: [
        RepaintBoundary(child: child),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: GrandStaffPlayheadPainter(
                  position: position,
                  layout: painter,
                  color: widget.theme.playheadColor ??
                      widget.theme.noteheadColor.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wraps [child] in a tap detector only when a callback wants taps, so a
  /// plain score stays out of the gesture arena (and keeps scrolling crisp).
  Widget _tappable(GrandStaffPainter painter, Widget child) {
    final onNoteTap = widget.onNoteTap;
    final onMeasureTap = widget.onMeasureTap;
    if (onNoteTap == null && onMeasureTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        if (onMeasureTap != null) {
          final bar = painter.measureTapAt(details.localPosition,
              globalPosition: details.globalPosition);
          if (bar != null) onMeasureTap(bar);
        }
        if (onNoteTap != null) {
          final note = painter.noteTapAt(details.localPosition,
              globalPosition: details.globalPosition);
          if (note != null) onNoteTap(note);
        }
      },
      child: child,
    );
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
                child: _tappable(
                  painter,
                  _withPlayhead(
                    painter,
                    Size(canvasWidth, height),
                    CustomPaint(
                      size: Size(canvasWidth, height),
                      painter: painter,
                    ),
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

/// The cursor layer of [GrandStaff]: one line across the system, placed by
/// [GrandStaffPainter.playheadAt], repainted on its own when [position]
/// changes.
class GrandStaffPlayheadPainter extends CustomPainter {
  GrandStaffPlayheadPainter({
    required this.position,
    required this.layout,
    required this.color,
  }) : super(repaint: position);

  final ValueListenable<PlaybackPosition?> position;
  final GrandStaffPainter layout;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = position.value;
    if (p == null) return;
    final at = layout.playheadAt(p);
    if (at == null) return;
    final width = layout.staffSpace * 0.25;
    canvas.drawLine(
      Offset(at.x, at.top),
      Offset(at.x, at.bottom),
      Paint()
        ..color = color
        ..strokeWidth = width < 1.0 ? 1.0 : width,
    );
  }

  @override
  bool shouldRepaint(GrandStaffPlayheadPainter old) =>
      !identical(old.position, position) ||
      !identical(old.layout, layout) ||
      old.color != color;
}
