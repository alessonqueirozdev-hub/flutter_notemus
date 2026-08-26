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

/// The clef and key signature in force after walking a run of measures.
///
/// This exists because a scan over `Measure.elements` is NOT a scan over the
/// music. ADR-004 deliberately moved mid-measure attribute changes INTO the
/// voices, so a `Clef` written half way through voice 1 of a polyphonic bar
/// lives in `Voice.elements` and is invisible to `Measure.elements`.
///
/// Measured consequence before this class existed (ten polyphonic bars, a
/// bass clef in the middle of voice 1 of bar 3, painter at 400 px, one bar per
/// system): system 2 opened with NO clef at all and systems 3, 4 and 5
/// restated `treble` while the BASS clef was in force — every note from bar 3
/// on was drawn a twelfth out of place, silently.
///
/// [Measure.allElements] yields the measure-level attributes first and then
/// each voice in ascending voice-number order, which is the same order the
/// layout engine consumes, so the LAST clef it yields is the clef that leaves
/// the bar.
class _ClefKeyTracker {
  Clef? clef;
  KeySignature? key;

  /// The meter last declared, carried for the same reason the clef is: a
  /// system that starts at bar `a` does not contain the meter declared at bar
  /// 1, and since ADR-005 action item 8 the layout engine no longer stamps
  /// `Measure.inheritedTimeSignature` onto the caller's bars, so there is
  /// nothing left in the sub-staff to re-derive it from.
  ///
  /// Without this, every wrapped system after the one holding the meter
  /// validated NOTHING: `LayoutEngine` skips capacity validation when it has no
  /// meter, so an over-full bar in system 2..n was silently counted as valid.
  ///
  /// Unlike clef and key this reads `Measure.timeSignature` — the
  /// measure-level `elements` list — because a meter is a bar attribute and
  /// never lives inside a `Voice`; that is also exactly the scan
  /// `LayoutEngine` performs, so the two cannot disagree.
  TimeSignature? timeSignature;

  /// Absorbs one whole measure, voices included.
  void advance(Measure measure) {
    for (final element in measure.allElements) {
      if (element is Clef) {
        clef = element;
      } else if (element is KeySignature) {
        key = element;
      }
    }
    final meter = measure.timeSignature;
    if (meter != null) timeSignature = meter;
  }
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
  ///
  /// A cross-staff note is reported on the staff it is PRINTED on, not on the
  /// voice's home staff — otherwise a hit test built from this list misses a
  /// cross-staff notehead by a whole `staffGap`. The unbeamed ones were
  /// already moved at layout time; this relocates the beamed ones, which the
  /// paint pass draws on the target staff but keeps in their home list so the
  /// spanning beam can be drawn from one run.
  @visibleForTesting
  List<List<PositionedElement>> alignedSystem(int systemIndex) =>
      _relocateCrossStaff(
        [for (final layout in _systems[systemIndex]) layout.elements],
        (_) => true,
      );

  /// Number of wrapped systems this painter produced.
  ///
  /// Public because the PDF rasterizer reports it on each page it emits; it was
  /// `@visibleForTesting` when only tests read it.
  int get systemCount => _systems.length;

  /// Y of the top staff's middle line inside a system block.
  double get _baseline0 => staffSpace * 5.0;

  /// Total painted WIDTH, in the same coordinate space as [totalHeight]: the
  /// right edge of the rightmost element of any staff of any system, plus the
  /// brace/bracket gutter the paint pass translates everything by.
  ///
  /// The host widget must size its canvas from this number, exactly as
  /// `MusicScore` sizes itself from [LayoutEngine.contentWidth]. It did not,
  /// and the music was unreachable: measured with one bar of 2000 thirty-second
  /// notes at `availableWidth` 300, the painter's content reached x = 57,436.2
  /// px inside a `CustomPaint` pinned at 300.0 px with no scrollable anywhere
  /// in the tree — about 99.5% of the bar could not be brought on screen.
  ///
  /// The right edge of an element is `dx + width - leftExtent`, not
  /// `dx + width`, for the reason spelled out on [LayoutEngine.contentWidth]:
  /// part of an element's advance (an accidental, a stem-down cluster's
  /// notehead) hangs to the LEFT of `dx` and would otherwise be counted twice.
  late final double contentWidth = _computeContentWidth();

  double _computeContentWidth() {
    var maxRight = 0.0;
    for (final system in _systems) {
      for (final layout in system) {
        for (final positioned in layout.elements) {
          final element = positioned.element;
          // Painted extent, not advance: a flag hangs past the advance on
          // purpose, and a canvas sized to the advance clips the flag of the
          // last note on a system (0.93 staff spaces of it, measured at
          // staffSpace 48).
          final right = positioned.position.dx +
              layout.engine.elementPaintedRightExtent(element);
          if (right > maxRight) maxRight = right;
        }
      }
    }
    return _bracePad + maxRight + staffSpace * 0.5;
  }

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
    // An UNBEAMED cross-staff note is moved onto the staff it was sent to, so
    // the ordinary staff renderer draws it there with its stem, flag, ledger
    // lines and accidental. Beamed cross-staff groups keep their home list —
    // `_drawCrossStaffBeams` needs the whole run in one place to draw the beam
    // that spans the two staves — and are relocated for REPORTING only, in
    // [alignedSystem].
    // ADR-005: the beam decision is a VALUE on the engine, not a field on the
    // note. `note.beam` alone carries only the AUTHOR's hint, and the engine
    // stopped writing its own answer back into the model in 2.7.2 — so reading
    // the field here classified every automatically beamed note as UNBEAMED
    // and relocated it out of its own beam group, which left
    // `_crossStaffGroups` with nothing to draw. MEASURED on four quavers with
    // the middle two carrying `crossStaffMove: 1`: the model read
    // `[null, null, null, null]` while `engine.beamOf` read
    // `[start, end, start, end]`, and `alignedSystem(0)` reported the two
    // beamed notes on the DESTINATION staff instead of keeping the run whole
    // on the home staff. Every cross-staff beam in the package was silently
    // not drawn.
    final relocated = _relocateCrossStaff(
      [for (final l in layouts) l.elements],
      (note) => _effectiveBeam(layouts, note) == null,
    );
    for (var i = 0; i < layouts.length; i++) {
      layouts[i] = _StaffLayout(relocated[i], layouts[i].engine);
    }
    return layouts;
  }

  /// The beam [LayoutEngine] resolved for [note], searched across every
  /// sub-staff layout of one system.
  ///
  /// A cross-staff note is laid out by the engine of its HOME staff, but the
  /// caller does not always know which staff that is (the relocation predicate
  /// runs over the flattened element lists of the whole system), so this asks
  /// each engine in turn. `beamOf` falls back to the author's `Note.beam` hint
  /// when the engine made no decision, so an engine that never saw this note
  /// returns null and the search moves on.
  static BeamType? _effectiveBeam(List<_StaffLayout> layouts, Note note) {
    for (final layout in layouts) {
      final beam = layout.engine.beamOf(note);
      if (beam != null) return beam;
    }
    return null;
  }

  /// Moves every cross-staff note that [shouldMove] accepts out of its home
  /// staff's list and into the list of the staff it is actually PRINTED on,
  /// re-deriving its Y from the destination staff's clef.
  ///
  /// `crossStaffMove` used to be honoured only inside beamed groups, and only
  /// at paint time. Measured: a quarter note with `crossStaffMove: 1` stayed
  /// at its home baseline (dy 90.0 on the top staff) instead of appearing on
  /// the staff below, and even for the beamed notes — which the paint pass did
  /// move — [alignedSystem], and therefore every hit test built on it, still
  /// reported the home staff. Doing the move on the element lists fixes both
  /// at once: what is drawn and what is reported come from the same list.
  List<List<PositionedElement>> _relocateCrossStaff(
    List<List<PositionedElement>> lists,
    bool Function(Note) shouldMove,
  ) {
    if (lists.length < 2) return lists;

    final kept = [for (var i = 0; i < lists.length; i++) <PositionedElement>[]];
    final moved = <({int target, PositionedElement pe})>[];
    for (var home = 0; home < lists.length; home++) {
      for (final pe in lists[home]) {
        final e = pe.element;
        if (e is Note && e.crossStaffMove != 0 && shouldMove(e)) {
          final target =
              (home + e.crossStaffMove).clamp(0, lists.length - 1);
          if (target != home) {
            moved.add((target: target, pe: pe));
            continue;
          }
        }
        kept[home].add(pe);
      }
    }
    if (moved.isEmpty) return lists;

    for (final entry in moved) {
      final note = entry.pe.element as Note;
      final pos = StaffPositionCalculator.calculate(
        note.pitch,
        // The clef IN FORCE at that point of the destination staff, not its
        // first clef: a destination staff that changes clef mid-system would
        // otherwise place every later cross-staff note by the opening clef.
        _clefAtX(kept[entry.target], entry.pe.position.dx),
        extraOctaveShift: _octaveShiftOf(note),
      );
      final y = _baseline0 - pos * staffSpace * 0.5;
      _insertByX(
        kept[entry.target],
        entry.pe.movedTo(Offset(entry.pe.position.dx, y)),
      );
    }
    return kept;
  }

  /// Inserts [pe] after everything already at or before its X, so the list
  /// keeps reading left to right and the note lands BEHIND a clef sharing its
  /// X rather than in front of it (the renderer tracks the clef by list
  /// order). On a polyphonic destination staff, whose list is voice 1 then
  /// voice 2 and therefore not monotonic in X, this puts the note at the end
  /// of the last voice it fits into — still after the attributes that govern
  /// it, which is all the renderer needs.
  static void _insertByX(List<PositionedElement> list, PositionedElement pe) {
    var i = list.length;
    while (i > 0 && list[i - 1].position.dx > pe.position.dx) {
      i--;
    }
    list.insert(i, pe);
  }

  /// The clef in force at [x] on the staff described by [elements], i.e. the
  /// rightmost clef printed at or before that point. Treble when the staff
  /// states none (the engine's own default).
  ///
  /// The list is NOT scanned to the first clef past [x] and stopped there: a
  /// polyphonic staff emits all of voice 1 and then all of voice 2, so its X
  /// is not monotonic in list order and an early exit would miss the clef a
  /// later voice carries.
  static Clef _clefAtX(List<PositionedElement> elements, double x) {
    Clef? found;
    var foundX = double.negativeInfinity;
    for (final pe in elements) {
      final e = pe.element;
      if (e is! Clef) continue;
      if (pe.position.dx > x + 1e-6) continue;
      if (pe.position.dx >= foundX) {
        found = e;
        foundX = pe.position.dx;
      }
    }
    return found ?? Clef(clefType: ClefType.treble);
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
    // Walk the music, not just the bar-level attribute list: a mid-measure
    // clef change lives inside a VOICE (ADR-004) and `Measure.elements` cannot
    // see it. See [_ClefKeyTracker] for the measured damage that caused.
    final prevailing = _ClefKeyTracker();
    for (var i = 0; i < a && i < staff.measures.length; i++) {
      prevailing.advance(staff.measures[i]);
    }
    final measures = <Measure>[];
    for (var i = a; i <= b && i < staff.measures.length; i++) {
      final orig = staff.measures[i];
      if (i == a && a > 0) {
        measures.add(_restated(
          orig,
          clef: prevailing.clef,
          key: prevailing.key,
          inheritedMeter: prevailing.timeSignature,
        ));
      } else {
        measures.add(orig);
      }
    }
    return Staff(measures: measures, lineCount: staff.lineCount);
  }

  /// A copy of [orig] with the prevailing [clef] and [key] restated in front,
  /// and the prevailing [inheritedMeter] carried onto it.
  ///
  /// Five things this must get right, all of which some previous version got
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
  ///
  /// 4. **"Already has a clef" means AT THE HEAD, not anywhere in the bar.**
  ///    The suppression test used to be `orig.allElements.any((e) => e is
  ///    Clef)`, so a bar whose only clef was a MID-measure change suppressed
  ///    the restatement it still needed in front. Measured: the system that
  ///    opened on such a bar printed no clef at all until its mid-bar change.
  ///
  /// 5. **It must carry the meter the system inherits.** The sub-`Staff` starts
  ///    at bar `a`, so a meter declared before `a` is not in it and the
  ///    sub-layout cannot re-derive it — and since ADR-005 action item 8 there
  ///    is no longer a value stamped on `orig` to borrow either. Passing it as
  ///    [inheritedMeter] restores what the engine used to leave behind, on a
  ///    measure THIS PAINTER OWNS rather than on the caller's. `orig`'s own
  ///    field still wins when it has one, so an author's opt-in is never
  ///    overwritten.
  Measure _restated(
    Measure orig, {
    Clef? clef,
    KeySignature? key,
    TimeSignature? inheritedMeter,
  }) {
    final hasClef = _statesAtHead(orig, (e) => e is Clef);
    final hasKey = _statesAtHead(orig, (e) => e is KeySignature);

    final restated = <MusicalElement>[
      if (!hasClef && clef != null) clef,
      if (!hasKey && key != null && key.count != 0) key,
    ];

    if (orig is MultiVoiceMeasure) {
      final copy = MultiVoiceMeasure()
        ..autoBeaming = orig.autoBeaming
        ..beamingMode = orig.beamingMode
        ..manualBeamGroups = orig.manualBeamGroups
        ..inheritedTimeSignature = orig.inheritedTimeSignature ?? inheritedMeter
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
      inheritedTimeSignature: orig.inheritedTimeSignature ?? inheritedMeter,
      number: orig.number,
    );
    copy.elements.addAll(restated);
    copy.elements.addAll(orig.elements);
    return copy;
  }

  /// Whether [orig] states a matching attribute IN FRONT of its first
  /// rhythmic event, i.e. at the bar's head where a system restatement would
  /// go. A clef that appears after a note is a mid-measure CHANGE and says
  /// nothing about what the bar opens with.
  static bool _statesAtHead(
    Measure orig,
    bool Function(MusicalElement) matches,
  ) {
    for (final element in orig.allElements) {
      if (matches(element)) return true;
      if (element is Note ||
          element is Rest ||
          element is Chord ||
          element is Tuplet) {
        return false;
      }
    }
    return false;
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
      // A GRACE note is deliberately excluded. A grace note has zero musical
      // duration, so it shares the onset of the note it ornaments, and it is
      // printed to that note's LEFT — so as an anchor it dragged the whole
      // instant backwards on the staff that carries the ornament. Measured on
      // a grand staff whose top part had a grace note and whose bottom part
      // did not: onset 0.250 anchored at 172.99 on the top staff (the grace)
      // against 172.99 on the bottom, which put the two REAL notes of that
      // beat 43.32 px apart (216.31 vs 172.99) — the ornament was aligned with
      // the other part instead of the note it belongs to. The main note is the
      // musical instant; the grace rides in front of it and is carried along
      // by the piecewise-linear remap below.
      final counts = (e is Note && !e.isGraceNote) ||
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
        } else if (pe.element is Tuplet) {
          // A tuplet's children sit on their own grid anchored on the tuplet;
          // remapping only the tuplet left them at pre-alignment coordinates,
          // which beams and hit-testing read.
          layouts[s].engine.overrideTupletX(pe.element as Tuplet, nx);
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

    final baseline0 = _baseline0;
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
    for (final g in _crossStaffGroups(layouts[home])) {
      out.addAll(g);
    }
    return out;
  }

  /// Beam runs (start..end) among positioned elements that contain a
  /// cross-staff note. Works regardless of whether the beam was rendered via the
  /// advanced or the simple path.
  ///
  /// The run is read through [LayoutEngine.beamOf], never off `Note.beam`
  /// (ADR-005): since 2.7.2 the engine publishes its grouping as a value and
  /// leaves the model alone, so the field is null for every automatically
  /// beamed note and this walk found ZERO runs — measured on four quavers with
  /// the middle two cross-staffed, model `[null, null, null, null]` against
  /// engine `[start, end, start, end]`.
  List<List<Note>> _crossStaffGroups(_StaffLayout layout) {
    final groups = <List<Note>>[];
    List<Note>? cur;
    for (final pe in layout.elements) {
      final e = pe.element;
      if (e is! Note) continue;
      switch (layout.engine.beamOf(e)) {
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

  /// 8va/8vb displacement in force at each note of every staff of the system,
  /// built once on first use.
  ///
  /// The cross-staff beam pass below re-derives a notehead's Y from its pitch,
  /// so it has to apply the SAME bracket displacement `LayoutEngine` and
  /// `StaffRenderer` applied — otherwise a cross-staff note under an 8va would
  /// be drawn an octave away from the very beam it belongs to. The clef comes
  /// from the TARGET staff (that is the staff the notehead is printed on) but
  /// the bracket comes from the note's OWN staff, which is where the bracket is
  /// written.
  Map<Note, int>? _octaveShiftCache;

  int _octaveShiftOf(Note note) {
    final cache = _octaveShiftCache ??= _buildOctaveShifts();
    return cache[note] ?? 0;
  }

  Map<Note, int> _buildOctaveShifts() {
    final shifts = <Note, int>{};
    for (final staff in _allStaves) {
      final span = OctaveSpanTracker();
      for (var i = 0; i < staff.measures.length; i++) {
        for (final element in staff.measures[i].allElements) {
          final shift = span.advance(element, measureIndex: i);
          if (shift == 0) continue;
          if (element is Note) {
            shifts[element] = shift;
          } else if (element is Chord) {
            for (final note in element.notes) {
              shifts[note] = shift;
            }
          }
        }
      }
    }
    return shifts;
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
      for (final g in _crossStaffGroups(layouts[home])) {
        final pts = <({double x, double y})>[];
        for (final note in g) {
          final x = noteX[note];
          if (x == null) continue;
          final target = (home + note.crossStaffMove)
              .clamp(0, _allStaves.length - 1);
          final pos = StaffPositionCalculator.calculate(
            note.pitch,
            // The clef in force on the DESTINATION staff at this X. It used to
            // be that staff's FIRST clef, so a destination staff that changed
            // clef during the system placed every later cross-staff notehead
            // by its opening clef instead.
            _clefAtX(layouts[target].elements, x),
            extraOctaveShift: _octaveShiftOf(note),
          );
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
