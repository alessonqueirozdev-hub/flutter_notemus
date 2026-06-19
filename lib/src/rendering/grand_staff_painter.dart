// lib/src/rendering/grand_staff_painter.dart
//
// Multi-staff rendering for one or more [StaffGroup]s (grand staff, SATB, or a
// full multi-section score). Lays out each staff, aligns them on a shared
// horizontal grid (content start and barlines line up across all staves),
// stacks them vertically, wraps into stacked systems when the music is too wide
// for one line, and draws each group's brace/bracket plus continuous system
// barlines (and cross-staff beams).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../layout/layout_engine.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';
import 'renderers/bracket_renderer.dart';
import 'staff_coordinate_system.dart';
import 'staff_position_calculator.dart';
import 'staff_renderer.dart';

/// Layout output for one staff in the group.
class _StaffLayout {
  final List<PositionedElement> elements;
  final LayoutEngine engine;
  _StaffLayout(this.elements, this.engine);
}

/// Renders one or more [StaffGroup]s as a unified, vertically-stacked,
/// horizontally-aligned system (a grand staff, an SATB choir, or a full
/// multi-section score). All staves across all groups share one horizontal
/// grid; each group carries its own brace/bracket.
class GrandStaffPainter extends CustomPainter {
  /// The staff groups, top to bottom. A single group is the common grand-staff
  /// case; multiple groups form an orchestral/ensemble score.
  final List<StaffGroup> groups;
  final double staffSpace;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double availableWidth;

  /// Baseline-to-baseline vertical distance between adjacent staves.
  final double staffGap;

  /// One aligned list of per-staff layouts per system (the group wraps into
  /// systems when it doesn't fit on one line; every staff breaks at the same
  /// measures so barlines line up).
  late final List<List<_StaffLayout>> _systems;

  /// Left padding reserved for the brace/bracket (and group name).
  late final double _bracePad;

  /// All staves across all groups, top to bottom.
  List<Staff> get _allStaves => [for (final g in groups) ...g.staves];

  /// Total painted height (all systems stacked).
  double get totalHeight =>
      _systems.length * systemBlockHeight + staffSpace * 2.0;

  /// Baseline-to-baseline distance between the tops of consecutive systems.
  double get systemBlockHeight =>
      (_allStaves.length - 1) * staffGap +
      staffSpace * 4.0 + // bottom staff lower half + margin
      staffSpace * 6.0; // inter-system gap

  GrandStaffPainter({
    StaffGroup? staffGroup,
    List<StaffGroup>? groups,
    required this.staffSpace,
    required this.metadata,
    required this.theme,
    required this.availableWidth,
    double? staffGap,
  })  : assert(staffGroup != null || groups != null,
            'Provide either staffGroup or groups'),
        groups = groups ?? [staffGroup!],
        staffGap = staffGap ?? staffSpace * 11.0 {
    _bracePad = staffSpace * 2.8;
    final ranges = _computeSystemRanges();
    _systems = [
      for (final range in ranges) _layoutSystem(range.start, range.end),
    ];
  }

  /// Lays out + aligns one system's measures (inclusive [a]..[b]) across staves.
  List<_StaffLayout> _layoutSystem(int a, int b) {
    final layouts = [
      for (final staff in _allStaves)
        _layoutSubStaff(_systemStaff(staff, a, b)),
    ];
    _alignStaves(layouts);
    return layouts;
  }

  _StaffLayout _layoutSubStaff(Staff staff) {
    final engine = LayoutEngine(
      staff,
      // Very wide so a system never wraps internally — breaks are decided here.
      availableWidth: (availableWidth - _bracePad) * 1000,
      staffSpace: staffSpace,
      metadata: metadata,
    );
    final result = engine.layoutWithSignature();
    return _StaffLayout(result.elements, engine);
  }

  /// Builds a sub-[Staff] holding measures [a]..[b] of [staff]; for a system
  /// that doesn't start the piece, the prevailing clef and key are restated at
  /// the start (Gould/Verovio).
  Staff _systemStaff(Staff staff, int a, int b) {
    Clef? clef;
    KeySignature? key;
    for (var i = 0; i < a && i < staff.measures.length; i++) {
      for (final e in staff.measures[i].elements) {
        if (e is Clef) clef = e;
        if (e is KeySignature) key = e;
      }
    }
    final measures = <Measure>[];
    for (var i = a; i <= b && i < staff.measures.length; i++) {
      final orig = staff.measures[i];
      if (i == a && a > 0) {
        final m = Measure();
        if (!orig.elements.any((e) => e is Clef) && clef != null) m.add(clef);
        if (!orig.elements.any((e) => e is KeySignature) &&
            key != null &&
            key.count != 0) {
          m.add(key);
        }
        for (final e in orig.elements) {
          m.add(e);
        }
        measures.add(m);
      } else {
        measures.add(orig);
      }
    }
    return Staff(measures: measures);
  }

  /// Per-measure widths laid out unwrapped, used to decide shared breaks.
  List<double> _measureWidths(Staff staff) {
    final engine = LayoutEngine(
      staff,
      availableWidth: 1000000,
      staffSpace: staffSpace,
      metadata: metadata,
    );
    final els = engine.layout();
    final widths = <double>[];
    var prev = 0.0;
    for (final pe in els) {
      if (pe.element is Barline) {
        widths.add(pe.position.dx - prev);
        prev = pe.position.dx;
      }
    }
    return widths;
  }

  /// Greedy system breaks shared by all staves: pack measures (by their widest
  /// per-staff width) into lines no wider than the usable width.
  List<({int start, int end})> _computeSystemRanges() {
    final nMeasures = _allStaves
        .map((s) => s.measures.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (nMeasures == 0) return [(start: 0, end: 0)];

    final widths = List<double>.filled(nMeasures, 0);
    for (final staff in _allStaves) {
      final w = _measureWidths(staff);
      for (var i = 0; i < w.length && i < nMeasures; i++) {
        if (w[i] > widths[i]) widths[i] = w[i];
      }
    }

    final usable = (availableWidth - _bracePad) - staffSpace * 1.0;
    final lead = staffSpace * 4.0; // restated clef+key allowance per new system
    final ranges = <({int start, int end})>[];
    var start = 0;
    var running = 0.0;
    for (var i = 0; i < nMeasures; i++) {
      final w = widths[i];
      if (i > start && running + w > usable) {
        ranges.add((start: start, end: i - 1));
        start = i;
        running = lead + w;
      } else {
        running += w + (i == start && start > 0 ? lead : 0);
      }
    }
    ranges.add((start: start, end: nMeasures - 1));
    return ranges;
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
    if (metadata.isNotLoaded || _systems.isEmpty) return;

    // Shift the whole system right to leave room for the brace/bracket.
    canvas.translate(_bracePad, 0);

    final baseline0 = staffSpace * 5.0;
    for (var sysIdx = 0; sysIdx < _systems.length; sysIdx++) {
      final layouts = _systems[sysIdx];
      if (layouts.isEmpty) continue;
      canvas.save();
      canvas.translate(0, sysIdx * systemBlockHeight);
      _paintSystem(canvas, size, layouts, baseline0);
      canvas.restore();
    }
  }

  void _paintSystem(
    Canvas canvas,
    Size size,
    List<_StaffLayout> layouts,
    double baseline0,
  ) {
    // Notes drawn by the cross-staff beam pass (skipped by their home staff).
    final skipPerStaff = [
      for (var i = 0; i < layouts.length; i++)
        _crossStaffNotesOf(layouts, i),
    ];

    for (var i = 0; i < layouts.length; i++) {
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
        layouts[i].elements,
        size,
        layoutEngine: layouts[i].engine,
        // Barlines are drawn once across the whole system below, so the staves
        // don't draw their own (which would double up and not connect).
        renderBarlines: false,
        skipNotes: skipPerStaff[i],
      );
      canvas.restore();
    }

    // Cross-staff beam groups, drawn after the staves so the beam sits between.
    _drawCrossStaffBeams(canvas, baseline0, layouts);

    // Vertical extent of the system: top line of the first staff to the bottom
    // line of the last staff (staff lines span 4 staff spaces around baseline).
    final topY = baseline0 - staffSpace * 2;
    final bottomY =
        (layouts.length - 1) * staffGap + baseline0 + staffSpace * 2;

    // Draw every barline once as a continuous line spanning the whole system,
    // so connected staves share unbroken barlines (and the final barline too).
    for (final bl in _systemBarlines(layouts)) {
      _drawSystemBarline(canvas, bl.x, bl.type, topY, bottomY);
    }

    // Each group carries its own brace/bracket, spanning only its own staves.
    final bracket = BracketRenderer(
      coordinates: StaffCoordinateSystem(
        staffSpace: staffSpace,
        staffBaseline: Offset(0, baseline0),
      ),
      theme: theme,
      metadata: metadata,
    );
    final leftX = staffSpace * 0.6; // system left origin (matches systemMargin)
    var staffIdx = 0;
    for (final g in groups) {
      final gTop = baseline0 + staffIdx * staffGap - staffSpace * 2;
      final gBottom =
          baseline0 + (staffIdx + g.staves.length - 1) * staffGap +
              staffSpace * 2;
      bracket.render(canvas, g, gTop, gBottom, leftX);
      staffIdx += g.staves.length;
    }

    // With more than one group, a thin system barline at the left edge joins
    // every staff (the orchestral "system start" line).
    if (groups.length > 1) {
      final paint = Paint()
        ..color = theme.barlineColor
        ..strokeWidth =
            metadata.getEngravingDefault('thinBarlineThickness', 0.16) *
                staffSpace;
      canvas.drawLine(Offset(leftX, topY), Offset(leftX, bottomY), paint);
    }
  }

  /// The system's barlines (x + type), taken from the (aligned) first staff —
  /// all staves share the same measure structure in a group.
  List<({double x, BarlineType type})> _systemBarlines(
    List<_StaffLayout> layouts,
  ) {
    if (layouts.isEmpty) return const [];
    final out = <({double x, BarlineType type})>[];
    for (final pe in layouts.first.elements) {
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

  // --- Cross-staff beams ----------------------------------------------------

  /// Notes of staff [home] that belong to a beam group containing a cross-staff
  /// note. The home staff skips drawing them; the cross-staff pass draws them.
  Set<Note> _crossStaffNotesOf(List<_StaffLayout> layouts, int home) {
    final out = <Note>{};
    for (final g in layouts[home].engine.advancedBeamGroups) {
      if (g.notes.any((n) => n.crossStaffMove != 0)) {
        out.addAll(g.notes);
      }
    }
    return out;
  }

  Clef _clefOf(int staffIndex) {
    if (staffIndex < 0 || staffIndex >= _allStaves.length) {
      return Clef(clefType: ClefType.treble);
    }
    for (final m in _allStaves[staffIndex].measures) {
      for (final e in m.elements) {
        if (e is Clef) return e;
      }
    }
    return Clef(clefType: ClefType.treble);
  }

  /// Draws beam groups that straddle two staves: each notehead on its target
  /// staff, stems reaching a single beam placed between the staves.
  void _drawCrossStaffBeams(
    Canvas canvas,
    double baseline0,
    List<_StaffLayout> layouts,
  ) {
    final ss = staffSpace;
    final noteheadChar = metadata.getCodepoint('noteheadBlack');
    final noteheadW =
        (metadata.getGlyphAdvanceWidth('noteheadBlack') ?? 1.18) * ss;
    final stemW = metadata.getEngravingDefault('stemThickness', 0.12) * ss;
    final beamThick = metadata.getEngravingDefault('beamThickness', 0.5) * ss;
    final fontSize = ss * 4.0;
    final stemPaint = Paint()
      ..color = theme.stemColor
      ..strokeWidth = stemW;
    final beamPaint = Paint()..color = theme.stemColor;

    for (var home = 0; home < layouts.length; home++) {
      final noteX = layouts[home].engine.noteXPositions;
      for (final g in layouts[home].engine.advancedBeamGroups) {
        if (!g.notes.any((n) => n.crossStaffMove != 0)) continue;

        final pts = <({double x, double y, double stemX})>[];
        for (final note in g.notes) {
          final x = noteX[note];
          if (x == null) continue;
          final target = (home + note.crossStaffMove)
              .clamp(0, _allStaves.length - 1);
          final pos =
              StaffPositionCalculator.calculate(note.pitch, _clefOf(target));
          final y = baseline0 + target * staffGap - pos * ss * 0.5;
          pts.add((x: x, y: y, stemX: x + noteheadW * 0.5));

          // Notehead glyph (noteheadBlack is ~baseline-centred vertically).
          if (noteheadChar.isNotEmpty) {
            final tp = TextPainter(
              text: TextSpan(
                text: noteheadChar,
                style: TextStyle(
                  fontFamily: 'Bravura',
                  package: 'flutter_notemus',
                  fontSize: fontSize,
                  color: theme.noteheadColor,
                  height: 1.0,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final baselineFromTop =
                tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
            tp.paint(canvas, Offset(x, y - baselineFromTop));
          }
        }
        if (pts.length < 2) continue;

        var minY = pts.first.y, maxY = pts.first.y;
        for (final p in pts) {
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        }
        final beamY = (minY + maxY) / 2;

        for (final p in pts) {
          canvas.drawLine(Offset(p.stemX, p.y), Offset(p.stemX, beamY), stemPaint);
        }
        final xs = pts.map((p) => p.stemX).toList()..sort();
        canvas.drawRect(
          Rect.fromLTRB(
            xs.first,
            beamY - beamThick / 2,
            xs.last,
            beamY + beamThick / 2,
          ),
          beamPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GrandStaffPainter oldDelegate) {
    return !identical(oldDelegate.groups, groups) ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.availableWidth != availableWidth;
  }
}
