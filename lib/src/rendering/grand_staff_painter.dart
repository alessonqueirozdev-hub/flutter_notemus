// lib/src/rendering/grand_staff_painter.dart
//
// Multi-staff rendering for one or more [StaffGroup]s (grand staff, SATB, or a
// full multi-section score). Lays out each staff, aligns them on a shared
// horizontal grid (every MUSICAL ONSET lines up across all staves, not just
// the barlines),
// stacks them vertically, wraps into stacked systems when the music is too wide
// for one line, and draws each group's brace/bracket plus continuous system
// barlines (and cross-staff beams).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../layout/onset_grid.dart';
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

  /// Aligned, positioned elements for one system, per staff (top to bottom).
  ///
  /// Exposed so the shared-time-grid invariant can be checked end to end: two
  /// staves must place events with the same [PositionedElement.onset] at the
  /// same X. Before 2.7.0 they did not — with four quarters against two halves,
  /// beat 3 landed 38 px (more than three staff spaces) apart.
  @visibleForTesting
  List<List<PositionedElement>> alignedSystem(int systemIndex) => [
        for (final layout in _systems[systemIndex]) layout.elements,
      ];

  /// Number of wrapped systems this painter produced.
  ///
  /// Public because the PDF rasterizer reports it on each page it emits; it was
  /// `@visibleForTesting` when only tests read it.
  int get systemCount => _systems.length;

  /// Total painted height (all systems stacked), including the headroom the
  /// music actually needs above the top staff and below the bottom one.
  ///
  /// A flat margin cut off high ledger-line notes, boxed rehearsal marks and
  /// multi-verse lyrics; `LayoutEngine.contentTopOverflow` /
  /// `contentBottomOverflow` measure the real reach.
  double get totalHeight =>
      _systems.length * systemBlockHeight +
      staffSpace * 2.0 +
      contentTopInset +
      _contentBottomInset;

  /// Extra space reserved above the first staff. The paint pass shifts the
  /// whole drawing down by this much.
  late final double contentTopInset = _maxOverflow(
    (engine, elements) => engine.contentTopOverflow(elements),
  );

  late final double _contentBottomInset = _maxOverflow(
    (engine, elements) => engine.contentBottomOverflow(elements),
  );

  double _maxOverflow(
    double Function(LayoutEngine, List<PositionedElement>) measure,
  ) {
    var worst = 0.0;
    for (final system in _systems) {
      for (final layout in system) {
        final value = measure(layout.engine, layout.elements);
        if (value > worst) worst = value;
      }
    }
    return worst;
  }

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
    _bracePad = staffSpace * 2.2;
    final ranges = _computeSystemRanges();
    _systems = [
      for (final range in ranges) _layoutSystem(range.start, range.end),
    ];
  }

  /// Lays out + aligns one system's measures (inclusive [a]..[b]) across staves.
  List<_StaffLayout> _layoutSystem(int a, int b) {
    final layouts = [
      for (final staff in _allStaves)
        _layoutSubStaff(_systemStaff(staff, a, b), measureOffset: a),
    ];
    _alignStaves(layouts);
    return layouts;
  }

  _StaffLayout _layoutSubStaff(Staff staff, {int measureOffset = 0}) {
    final engine = LayoutEngine(
      staff,
      // Very wide so a system never wraps internally — breaks are decided here.
      availableWidth: (availableWidth - _bracePad) * 1000,
      staffSpace: staffSpace,
      metadata: metadata,
      // Indices restart at 0 inside a system's sub-staff; this restores the
      // absolute bar number without touching the caller's Measure objects.
      measureNumberOffset: measureOffset,
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
        measures.add(_restated(orig, clef: clef, key: key));
      } else {
        measures.add(orig);
      }
    }
    return Staff(measures: measures, lineCount: staff.lineCount);
  }

  /// A copy of [orig] with the prevailing [clef] and [key] restated in front.
  ///
  /// Three things this must get right, all of which the previous version got
  /// wrong:
  ///
  /// 1. **It must not validate.** It used to copy with `Measure.add`, which
  ///    checks bar capacity and throws [MeasureCapacityException]. Importers
  ///    legitimately produce over-full bars — `Measure.elements`' own dartdoc
  ///    says so — and an over-full bar that happened to land first in a wrapped
  ///    system took the whole widget down from this painter's CONSTRUCTOR.
  ///    Validating imported music is the importer's job, not the painter's.
  ///
  /// 2. **It must carry the measure's configuration over.** A fresh `Measure()`
  ///    silently reset `autoBeaming`, `beamingMode`, `manualBeamGroups` and
  ///    `number`, so an author who turned auto-beaming off saw it honoured in
  ///    the first system and quietly overridden in every wrapped one.
  ///
  /// 3. **It must preserve polyphony.** For a [MultiVoiceMeasure] the old copy
  ///    walked `orig.elements` only, which holds the bar's system elements —
  ///    every voice, and therefore every note, was dropped.
  Measure _restated(Measure orig, {Clef? clef, KeySignature? key}) {
    final hasClef = orig.allElements.any((e) => e is Clef);
    final hasKey = orig.allElements.any((e) => e is KeySignature);

    final restated = <MusicalElement>[
      if (!hasClef && clef != null) clef,
      if (!hasKey && key != null && key.count != 0) key,
    ];

    if (orig is MultiVoiceMeasure) {
      final copy = MultiVoiceMeasure()
        ..autoBeaming = orig.autoBeaming
        ..beamingMode = orig.beamingMode
        ..manualBeamGroups = orig.manualBeamGroups
        ..inheritedTimeSignature = orig.inheritedTimeSignature
        ..number = orig.number;
      copy.elements.addAll(restated);
      copy.elements.addAll(orig.elements);
      for (final voice in orig.sortedVoices) {
        copy.addVoice(voice);
      }
      return copy;
    }

    final copy = Measure(
      autoBeaming: orig.autoBeaming,
      beamingMode: orig.beamingMode,
      manualBeamGroups: orig.manualBeamGroups,
      inheritedTimeSignature: orig.inheritedTimeSignature,
      number: orig.number,
    );
    copy.elements.addAll(restated);
    copy.elements.addAll(orig.elements);
    return copy;
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

  /// Per-staff mapping from MUSICAL ONSET to X.
  ///
  /// Onsets are whole-note offsets from the start of the (sub-)staff, carried
  /// on every [PositionedElement] by the layout engine. When two staves have an
  /// event at the same onset, those events are simultaneous and MUST share an
  /// X — that is the whole point of a system.
  List<({double onset, double x})> _onsetAnchorsOf(
    List<PositionedElement> elements,
  ) {
    final byOnset = <double, double>{};
    for (final pe in elements) {
      final e = pe.element;
      final counts = e is Note ||
          e is Rest ||
          e is Chord ||
          e is Tuplet ||
          e is Barline;
      if (!counts) continue;
      // Quantise so floating-point noise never splits one musical instant.
      //
      // The grid is 1/8192 of a whole note. It used to be 1/1024, which is the
      // value of a 1024th note, so a 2048th note advanced the onset by HALF a
      // grid step and consecutive 2048ths collapsed onto the same key: sixteen
      // distinct onsets produced nine keys. 8192 resolves every duration the
      // model can express (down to 1/2048) with a factor of four to spare for
      // nested-tuplet arithmetic.
      final key = (pe.onset * kOnsetGrid).round() / kOnsetGrid;
      final current = byOnset[key];
      if (current == null || pe.position.dx < current) {
        byOnset[key] = pe.position.dx;
      }
    }
    final keys = byOnset.keys.toList()..sort();
    return [for (final k in keys) (onset: k, x: byOnset[k]!)];
  }

  /// X this staff would use for [onset], interpolating between its own anchors.
  double _xAtOnset(List<({double onset, double x})> anchors, double onset) {
    if (anchors.isEmpty) return 0.0;
    if (onset <= anchors.first.onset) return anchors.first.x;
    if (onset >= anchors.last.onset) return anchors.last.x;
    for (var i = 0; i < anchors.length - 1; i++) {
      final lo = anchors[i];
      final hi = anchors[i + 1];
      if (onset < lo.onset || onset > hi.onset) continue;
      final span = hi.onset - lo.onset;
      if (span.abs() < 1e-9) return lo.x;
      return lo.x + (hi.x - lo.x) * ((onset - lo.onset) / span);
    }
    return anchors.last.x;
  }

  /// Puts every staff of a system on ONE shared horizontal time grid.
  ///
  /// This used to align only the content-start and the BARLINES, remapping the
  /// inside of each measure proportionally to each staff's own spacing. Inside
  /// a bar the staves therefore disagreed: with four quarters in the treble and
  /// two halves in the bass, beat 3 landed 38 px apart (>3 staff spaces) — the
  /// single most damaging engraving defect for keyboard and ensemble music.
  ///
  /// Now the anchors are MUSICAL ONSETS. For every onset present on any staff
  /// the shared X is the widest requirement across staves (so nothing is
  /// squeezed), and each staff is remapped piecewise-linearly onto that grid.
  /// Because the shared X is the max of monotonic functions it is itself
  /// monotonic, so the remap can never reorder a staff's events.
  void _alignStaves(List<_StaffLayout> layouts) {
    if (layouts.isEmpty) return;

    final perStaff = [for (final l in layouts) _onsetAnchorsOf(l.elements)];
    if (perStaff.every((a) => a.isEmpty)) return;

    // Union of every onset on any staff of this system.
    final onsetSet = <double>{};
    for (final anchors in perStaff) {
      for (final a in anchors) {
        onsetSet.add(a.onset);
      }
    }
    final onsets = onsetSet.toList()..sort();
    if (onsets.isEmpty) return;

    // Shared grid: the widest X any staff needs at that instant.
    final shared = <double>[];
    for (final onset in onsets) {
      var maxX = double.negativeInfinity;
      for (var s = 0; s < perStaff.length; s++) {
        if (perStaff[s].isEmpty) continue;
        final x = _xAtOnset(perStaff[s], onset);
        if (x > maxX) maxX = x;
      }
      shared.add(maxX.isFinite ? maxX : 0.0);
    }
    // Enforce strict monotonicity (defensive: equal onsets from rounding).
    for (var k = 1; k < shared.length; k++) {
      if (shared[k] < shared[k - 1]) shared[k] = shared[k - 1];
    }

    const double leftMargin = 0.0;

    for (var s = 0; s < layouts.length; s++) {
      final anchors = perStaff[s];
      if (anchors.isEmpty) continue;

      // This staff's own X at each shared onset -> the shared X there.
      final from = <double>[];
      for (final onset in onsets) {
        from.add(_xAtOnset(anchors, onset));
      }

      double remap(double x) {
        if (x <= from.first) {
          final lo = leftMargin, hi = from.first;
          final sLo = leftMargin, sHi = shared.first;
          if (hi - lo < 1e-6) return sLo;
          return sLo + (x - lo) / (hi - lo) * (sHi - sLo);
        }
        for (var k = 0; k < from.length - 1; k++) {
          if (x <= from[k + 1]) {
            final lo = from[k], hi = from[k + 1];
            final sLo = shared[k], sHi = shared[k + 1];
            if (hi - lo < 1e-6) return sLo;
            return sLo + (x - lo) / (hi - lo) * (sHi - sLo);
          }
        }
        return x + (shared.last - from.last);
      }

      final remapped = <PositionedElement>[];
      for (final pe in layouts[s].elements) {
        final nx = remap(pe.position.dx);
        remapped.add(pe.movedTo(Offset(nx, pe.position.dy)));
        // Keep the engine's note-X map (used by beams) in sync.
        if (pe.element is Note) {
          layouts[s].engine.overrideNoteX(pe.element as Note, nx);
        } else if (pe.element is Chord) {
          for (final n in (pe.element as Chord).notes) {
            layouts[s].engine.overrideNoteX(n, nx);
          }
        }
      }
      layouts[s] = _StaffLayout(remapped, layouts[s].engine);
    }
  }

  // --- Painting -------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded || _systems.isEmpty) return;

    // Shift the whole system right to leave room for the brace/bracket, and
    // down by whatever headroom the music above the top staff needs.
    canvas.translate(_bracePad, contentTopInset);

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
        // Bar numbers belong to the SYSTEM, so only the top staff prints them.
        renderMeasureNumbers: i == 0,
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
    // Staff lines are drawn from x = 0 (the coordinate origin), so the
    // brace/bracket caps them there and extends left into the reserved _bracePad
    // margin (the whole system is already translated right by _bracePad).
    const leftX = 0.0;
    var staffIdx = 0;
    for (final g in groups) {
      final gTop = baseline0 + staffIdx * staffGap - staffSpace * 2;
      final gBottom =
          baseline0 + (staffIdx + g.staves.length - 1) * staffGap +
              staffSpace * 2;
      bracket.render(canvas, g, gTop, gBottom, leftX);
      staffIdx += g.staves.length;
    }

    // A system-start barline at the left edge joins every staff of the system
    // (the vertical line the brace/bracket caps) — present on any grand staff
    // or multi-staff system, not just multi-group scores.
    if (_allStaves.length > 1) {
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
    for (final g in _crossStaffGroups(layouts[home].elements)) {
      out.addAll(g);
    }
    return out;
  }

  /// Beam runs (note.beam start..end) among positioned elements that contain a
  /// cross-staff note. Works regardless of whether the beam was rendered via the
  /// advanced or the simple path.
  List<List<Note>> _crossStaffGroups(List<PositionedElement> els) {
    final groups = <List<Note>>[];
    List<Note>? cur;
    for (final pe in els) {
      final e = pe.element;
      if (e is! Note) continue;
      switch (e.beam) {
        case BeamType.start:
          cur = [e];
          break;
        case BeamType.inner:
          cur?.add(e);
          break;
        case BeamType.end:
          if (cur != null) {
            cur.add(e);
            if (cur.any((n) => n.crossStaffMove != 0)) groups.add(cur);
            cur = null;
          }
          break;
        case null:
          cur = null;
          break;
      }
    }
    return groups;
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
      // Note X positions from the (aligned) positioned elements.
      final noteX = <Note, double>{};
      for (final pe in layouts[home].elements) {
        if (pe.element is Note) noteX[pe.element as Note] = pe.position.dx;
      }
      for (final g in _crossStaffGroups(layouts[home].elements)) {
        final pts = <({double x, double y})>[];
        for (final note in g) {
          final x = noteX[note];
          if (x == null) continue;
          final target = (home + note.crossStaffMove)
              .clamp(0, _allStaves.length - 1);
          final pos =
              StaffPositionCalculator.calculate(note.pitch, _clefOf(target));
          final y = baseline0 + target * staffGap - pos * ss * 0.5;
          pts.add((x: x, y: y));

          // Notehead glyph (noteheadBlack is ~baseline-centred vertically).
          if (noteheadChar.isNotEmpty) {
            final tp = TextPainter(
              text: TextSpan(
                text: noteheadChar,
                style: TextStyle(
                  // Never name the font literally: the engine is SMuFL-based,
                  // not Bravura-based, and the descriptor is what makes a
                  // different SMuFL font swappable.
                  fontFamily: metadata.font.fontFamily,
                  package: metadata.font.fontPackage,
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

        // Stems attach at the notehead edge nearest the beam: a note below the
        // beam stems up (right edge); a note above stems down (left edge).
        double stemXof(({double x, double y}) p) => p.y > beamY
            ? p.x + noteheadW - stemW * 0.5
            : p.x + stemW * 0.5;
        for (final p in pts) {
          final sx = stemXof(p);
          canvas.drawLine(Offset(sx, p.y), Offset(sx, beamY), stemPaint);
        }
        final xs = pts.map(stemXof).toList()..sort();
        canvas.drawRect(
          Rect.fromLTRB(
            xs.first - stemW * 0.5,
            beamY - beamThick / 2,
            xs.last + stemW * 0.5,
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
