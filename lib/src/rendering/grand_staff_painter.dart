// lib/src/rendering/grand_staff_painter.dart
//
// Multi-staff (grand-staff / system) rendering. Lays out each staff of a
// [StaffGroup] independently, then aligns them on a shared horizontal grid so
// the content start and every barline line up across staves, stacks them
// vertically, and draws the connecting brace/bracket and barlines.
//
// Scope: a single system (no mid-system wrapping). Grand-staff examples and the
// common keyboard/SATB layouts fit on one line; multi-system wrapping is a
// follow-up.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../layout/layout_engine.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';
import 'renderers/bracket_renderer.dart';
import 'staff_coordinate_system.dart';
import 'staff_renderer.dart';

/// Layout output for one staff in the group.
class _StaffLayout {
  final List<PositionedElement> elements;
  final LayoutEngine engine;
  _StaffLayout(this.elements, this.engine);
}

/// Renders a [StaffGroup] as a vertically-stacked, horizontally-aligned system.
class GrandStaffPainter extends CustomPainter {
  final StaffGroup staffGroup;
  final double staffSpace;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double availableWidth;

  /// Baseline-to-baseline vertical distance between adjacent staves.
  final double staffGap;

  late final List<_StaffLayout> _layouts;

  /// Left padding reserved for the brace/bracket (and group name).
  late final double _bracePad;

  GrandStaffPainter({
    required this.staffGroup,
    required this.staffSpace,
    required this.metadata,
    required this.theme,
    required this.availableWidth,
    double? staffGap,
  }) : staffGap = staffGap ?? staffSpace * 11.0 {
    _bracePad = staffSpace * 2.8;
    _layouts = [
      for (final staff in staffGroup.staves) _layoutStaff(staff),
    ];
    _alignStaves(_layouts);
  }

  _StaffLayout _layoutStaff(Staff staff) {
    final engine = LayoutEngine(
      staff,
      availableWidth: availableWidth - _bracePad,
      staffSpace: staffSpace,
      metadata: metadata,
    );
    final result = engine.layoutWithSignature();
    return _StaffLayout(result.elements, engine);
  }

  // --- Horizontal alignment -------------------------------------------------

  /// Per-staff anchor X positions: the system left margin, the content-start
  /// (first note/rest/chord) and each barline X. Returns the anchors and the
  /// indices into [elements] that mark each barline.
  List<double> _anchorsOf(List<PositionedElement> elements) {
    final anchors = <double>[];
    double? contentStart;
    for (final pe in elements) {
      final e = pe.element;
      if (contentStart == null &&
          (e is Note || e is Rest || e is Chord)) {
        contentStart = pe.position.dx;
      }
      if (e is Barline) {
        anchors.add(pe.position.dx);
      }
    }
    // anchors currently = barline Xs; prepend content start.
    return [contentStart ?? 0.0, ...anchors];
  }

  /// Aligns every staff so their content-start and barlines share the same X
  /// (the maximum across staves), remapping each staff's elements with a
  /// piecewise-linear map between the per-staff and shared anchors.
  void _alignStaves(List<_StaffLayout> layouts) {
    if (layouts.isEmpty) return;

    final perStaffAnchors = [for (final l in layouts) _anchorsOf(l.elements)];
    // Number of shared anchors = min across staves (align the common prefix).
    var anchorCount = perStaffAnchors.first.length;
    for (final a in perStaffAnchors) {
      if (a.length < anchorCount) anchorCount = a.length;
    }
    if (anchorCount == 0) return;

    // Shared anchor = max across staves at each index (widest wins → no clash).
    final shared = <double>[];
    for (var k = 0; k < anchorCount; k++) {
      var maxX = perStaffAnchors.first[k];
      for (final a in perStaffAnchors) {
        if (a[k] > maxX) maxX = a[k];
      }
      shared.add(maxX);
    }

    // Remap each staff's element X by piecewise-linear interpolation between
    // its own anchors and the shared anchors. The first segment is from the
    // system left margin (constant) to the first anchor.
    const double leftMargin = 0.0; // both spaces share the same left origin
    for (var s = 0; s < layouts.length; s++) {
      final anchors = perStaffAnchors[s];
      double remap(double x) {
        // Segment 0: [leftMargin, anchors[0]] -> [leftMargin, shared[0]].
        if (x <= anchors[0]) {
          final lo = leftMargin, hi = anchors[0];
          final sLo = leftMargin, sHi = shared[0];
          if (hi - lo < 1e-6) return sLo;
          return sLo + (x - lo) / (hi - lo) * (sHi - sLo);
        }
        for (var k = 0; k < anchorCount - 1; k++) {
          if (x <= anchors[k + 1]) {
            final lo = anchors[k], hi = anchors[k + 1];
            final sLo = shared[k], sHi = shared[k + 1];
            if (hi - lo < 1e-6) return sLo;
            return sLo + (x - lo) / (hi - lo) * (sHi - sLo);
          }
        }
        // Beyond the last shared anchor: shift by the last anchor's delta.
        return x + (shared[anchorCount - 1] - anchors[anchorCount - 1]);
      }

      final remapped = <PositionedElement>[];
      for (final pe in layouts[s].elements) {
        final nx = remap(pe.position.dx);
        remapped.add(PositionedElement(
          pe.element,
          Offset(nx, pe.position.dy),
          system: pe.system,
          voiceNumber: pe.voiceNumber,
        ));
        // Keep the engine's note-X map (used by beams) in sync.
        if (pe.element is Note) {
          layouts[s].engine.overrideNoteX(pe.element as Note, nx);
        }
      }
      layouts[s] = _StaffLayout(remapped, layouts[s].engine);
    }
  }

  // --- Painting -------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded || _layouts.isEmpty) return;

    // Shift the whole system right to leave room for the brace/bracket.
    canvas.translate(_bracePad, 0);

    final baseline0 = staffSpace * 5.0;

    for (var i = 0; i < _layouts.length; i++) {
      canvas.save();
      canvas.translate(0, i * staffGap);
      final coords = StaffCoordinateSystem(
        staffSpace: staffSpace,
        staffBaseline: Offset(0, baseline0),
      );
      final renderer = StaffRenderer(
        coordinates: coords,
        metadata: metadata,
        theme: theme,
      );
      renderer.renderStaff(
        canvas,
        _layouts[i].elements,
        size,
        layoutEngine: _layouts[i].engine,
        // Barlines are drawn once across the whole system below, so the staves
        // don't draw their own (which would double up and not connect).
        renderBarlines: false,
      );
      canvas.restore();
    }

    // Vertical extent of the system: top line of the first staff to the bottom
    // line of the last staff (staff lines span 4 staff spaces around baseline).
    final topY = baseline0 - staffSpace * 2;
    final bottomY =
        (_layouts.length - 1) * staffGap + baseline0 + staffSpace * 2;

    // Draw every barline once as a continuous line spanning the whole system,
    // so connected staves share unbroken barlines (and the final barline too).
    for (final bl in _systemBarlines()) {
      _drawSystemBarline(canvas, bl.x, bl.type, topY, bottomY);
    }

    // Brace / bracket on the left edge connecting the staves.
    final bracket = BracketRenderer(
      coordinates: StaffCoordinateSystem(
        staffSpace: staffSpace,
        staffBaseline: Offset(0, baseline0),
      ),
      theme: theme,
      metadata: metadata,
    );
    final leftX = staffSpace * 0.6; // system left origin (matches systemMargin)
    bracket.render(canvas, staffGroup, topY, bottomY, leftX);
  }

  /// The system's barlines (x + type), taken from the (aligned) first staff —
  /// all staves share the same measure structure in a group.
  List<({double x, BarlineType type})> _systemBarlines() {
    if (_layouts.isEmpty) return const [];
    final out = <({double x, BarlineType type})>[];
    for (final pe in _layouts.first.elements) {
      if (pe.element is Barline) {
        out.add((x: pe.position.dx, type: (pe.element as Barline).type));
      }
    }
    return out;
  }

  /// Draws a single system-spanning barline of the given [type] from [topY] to
  /// [bottomY]. Normal barlines are one thin line; final/heavy barlines add a
  /// thick line; double/light-light draws two thin lines.
  void _drawSystemBarline(
    Canvas canvas,
    double x,
    BarlineType type,
    double topY,
    double bottomY,
  ) {
    final thin = metadata.getEngravingDefault('thinBarlineThickness', 0.16) *
        staffSpace;
    final thick = metadata.getEngravingDefault('thickBarlineThickness', 0.5) *
        staffSpace;
    final color = theme.barlineColor;
    Paint p(double w) => Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt;
    void line(double cx, double w) =>
        canvas.drawLine(Offset(cx, topY), Offset(cx, bottomY), p(w));

    switch (type) {
      case BarlineType.final_:
      case BarlineType.lightHeavy:
        line(x, thin);
        line(x + thin * 0.5 + staffSpace * 0.45 + thick * 0.5, thick);
        break;
      case BarlineType.heavy:
        line(x, thick);
        break;
      case BarlineType.double:
      case BarlineType.lightLight:
        line(x, thin);
        line(x + staffSpace * 0.45, thin);
        break;
      case BarlineType.none:
        break;
      default:
        line(x, thin);
    }
  }

  @override
  bool shouldRepaint(covariant GrandStaffPainter oldDelegate) {
    return oldDelegate.staffGroup != staffGroup ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.availableWidth != availableWidth;
  }
}
