// lib/src/rendering/renderers/slur_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../engraving/engraving_rules.dart';
import '../../layout/layout_engine.dart';
import '../../layout/skyline_calculator.dart';
import '../../layout/slur_calculator.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../grace_note_geometry.dart';
import '../staff_position_calculator.dart';
import 'chord_renderer.dart';
import 'group_renderer.dart';

/// Draws slurs and ties, including the ones broken by a system (line) break.
///
/// ## Slurs and ties across a system break
///
/// A slur or tie whose endpoints land on two different systems is **not** one
/// curve stretched between them — drawn that way it runs backwards and over the
/// staff that sits in between. Gould (*Behind Bars*, p.109 for slurs, p.63 for
/// ties) prescribes two independent segments:
///
/// * on the system it leaves, a segment starts at its note and runs a little
///   past the last barline of that system, ending **in the air** — the curve
///   lifts away from the staff and simply stops, pointing at nothing;
/// * on the system it enters, a second segment starts at the beginning of the
///   staff (after the restated clef and key signature, before the first note)
///   and lands on the closing note.
///
/// [PositionedElement.system] is what identifies the break. Three cases are
/// handled, because the caller may pass one system at a time (the normal path,
/// where a straddling span has only one of its two ends in the list) or the
/// whole staff at once:
///
/// * **(a) start present, end missing** — outgoing segment only;
/// * **(b) end present, start missing** — incoming segment only;
/// * **(c) both present on different systems** — both segments;
/// * both present on the same system — one ordinary curve.
///
/// The horizontal limits of a system are measured from the elements themselves:
/// the right edge from the largest X of that system (or its rightmost
/// [Barline]), the left edge from the smallest X.
class SlurRenderer {
  final EngravingRules rules;
  final SmuflMetadata metadata;
  final double staffSpace;
  final double staffBaselineY;
  final SkyBottomLineCalculator? skylineCalculator;

  /// 8va/8vb displacement per note, keyed by note identity (absent = 0).
  ///
  /// A slur or tie curve is anchored to the notehead, and the notehead's Y is
  /// recomputed here from the pitch (positions carry the system baseline, not
  /// the note's own Y). So this renderer has to apply the SAME bracket
  /// displacement the layout engine and `NoteRenderer` applied, or every curve
  /// under an 8va would hang an octave away from the notes it joins.
  ///
  /// It is a per-note map, not one int, because a slur legitimately straddles
  /// the start or the end of a bracket. It is a constructor field rather than a
  /// parameter because the displacement is needed in a dozen private helpers
  /// down the endpoint/placement/collision chain; `StaffRenderer` rebuilds this
  /// renderer once per pass anyway (for the skyline), so there is no stale-state
  /// window.
  final Map<Note, int> octaveShifts;

  SlurRenderer({
    required this.staffSpace,
    required this.metadata,
    required this.staffBaselineY,
    EngravingRules? rules,
    this.skylineCalculator,
    this.octaveShifts = const {},
  }) : rules = rules ?? EngravingRules();

  /// Bracket displacement in force for [note] (0 outside every 8va/8vb span).
  int _octaveShiftOf(Note note) => octaveShifts[note] ?? 0;

  /// Space, in staff spaces, kept past the right edge of a system by the
  /// outgoing half of a slur/tie broken by a line break (Behind Bars: the curve
  /// continues "a little beyond the barline").
  static const double systemBreakTrailingSpaces = 1.0;

  /// Lead-in, in staff spaces, kept before the first note of a system by the
  /// incoming half of a broken slur/tie, so it starts after the restated
  /// clef/key signature and before the note it closes on.
  static const double systemBreakLeadInSpaces = 2.0;

  /// How far the free ("in the air") end of a broken segment lifts away from
  /// the note end, in staff spaces. The lift is what makes the segment read as
  /// "continues on the next system" instead of as a short, complete slur.
  static const double systemBreakAirLiftSpaces = 0.9;

  _NoteheadMetrics _resolveNoteheadMetrics(
    Offset notePos,
    Note note, {
    double scaleFactor = 1.0,
  }) {
    final glyphName = note.duration.type.glyphName;
    final glyphInfo = metadata.getGlyphInfo(glyphName);
    final bbox = glyphInfo?.boundingBox;

    final leftEdge =
        notePos.dx + ((bbox?.bBoxSwX ?? 0.0) * staffSpace * scaleFactor);
    final rightEdge =
        notePos.dx +
        (((bbox?.bBoxNeX ?? metadata.getGlyphWidth(glyphName)) * staffSpace) *
            scaleFactor);
    final width = math.max(
      rightEdge - leftEdge,
      staffSpace * 0.7 * scaleFactor,
    );
    final halfHeight = math.max(
      (((bbox?.height ?? 0.88) * staffSpace * scaleFactor) * 0.5),
      staffSpace * 0.22 * scaleFactor,
    );

    Offset? toAbsoluteAnchor(String anchorName) {
      final anchor = metadata.getGlyphAnchor(glyphName, anchorName);
      if (anchor == null) return null;
      return Offset(
        notePos.dx + (anchor.dx * staffSpace * scaleFactor),
        notePos.dy - (anchor.dy * staffSpace * scaleFactor),
      );
    }

    return _NoteheadMetrics(
      leftEdge: leftEdge,
      rightEdge: rightEdge,
      width: width,
      halfHeight: halfHeight,
      stemUpAnchor: toAbsoluteAnchor('stemUpSE'),
      stemDownAnchor: toAbsoluteAnchor('stemDownNW'),
    );
  }

  void renderSlurs({
    required Canvas canvas,
    required Map<int, List<int>> slurGroups,
    required List<PositionedElement> positions,
    required Clef currentClef,
    Color color = Colors.black,
  }) {
    // Nesting level per group: how many other slurs it strictly encloses, so an
    // enclosing (outer) slur arches farther from the notes than the inner ones
    // (Gould p.110-112). Keyed by element-index span.
    final groupList = slurGroups.values.where((g) => g.length >= 2).toList();
    int nestLevel(List<int> g) {
      var level = 0;
      for (final other in groupList) {
        if (identical(other, g)) continue;
        final inside = g.first <= other.first && g.last >= other.last;
        final isSmaller = other.first > g.first || other.last < g.last;
        if (inside && isSmaller) level++;
      }
      return level;
    }

    const nestOffsetSS = 1.3;

    // Horizontal limits of every system present in [positions], used to break
    // spans that straddle a line break (see the class docs).
    final extents = _measureSystems(positions);
    final referenceSystem = positions.isEmpty ? 0 : positions.first.system;

    for (final group in groupList) {
      if (group.length < 2) {
        continue;
      }
      final nestOffset = nestLevel(group) * nestOffsetSS * staffSpace;

      final startElement = positions[group.first];
      final endElement = positions[group.last];

      // Fix: skip grace-note slurs — now rendered by the grace-note renderer
      // automaticamente pelo OrnamentRenderer._renderGraceSlur
      if (_hasGraceOrnamentOnElement(startElement.element)) {
        continue;
      }

      final tempStart = _pickNoteFromElement(
        startElement,
        above: true,
        clef: currentClef,
        preferredSlurType: SlurType.start,
      );
      final tempEnd = _pickNoteFromElement(
        endElement,
        above: true,
        clef: currentClef,
        preferredSlurType: SlurType.end,
      );
      if (tempStart == null || tempEnd == null) {
        continue;
      }

      final direction = _calculateSlurDirection(tempStart, tempEnd);
      final slurAbove = direction == SlurDirection.up;

      final startNote = _pickNoteFromElement(
        startElement,
        above: slurAbove,
        clef: currentClef,
        preferredSlurType: SlurType.start,
      )!;
      final endNote = _pickNoteFromElement(
        endElement,
        above: slurAbove,
        clef: currentClef,
        preferredSlurType: SlurType.end,
      )!;
      final isGraceSlur = false; // Grace slurs handled by OrnamentRenderer

      final startPoint = _calculateSlurEndpoint(
        startNote.noteOrigin,
        startNote.note,
        currentClef,
        isStart: true,
        above: slurAbove,
        isGraceSlur: isGraceSlur,
        stemUp: startNote.stemUp,
      );

      final endPoint = _calculateSlurEndpoint(
        endNote.noteOrigin,
        endNote.note,
        currentClef,
        isStart: false,
        above: slurAbove,
        isGraceSlur: isGraceSlur,
        stemUp: endNote.stemUp,
      );

      // Raise (or lower) an enclosing slur so it clears the inner ones.
      final dy = slurAbove ? -nestOffset : nestOffset;
      final nestedStart = nestOffset == 0
          ? startPoint
          : Offset(startPoint.dx, startPoint.dy + dy);
      final nestedEnd = nestOffset == 0
          ? endPoint
          : Offset(endPoint.dx, endPoint.dy + dy);

      // Case (c): the span straddles a line break, so it becomes two segments
      // instead of one curve running backwards across the page.
      if (startElement.system != endElement.system) {
        _drawSystemBreakSegment(
          canvas: canvas,
          anchor: nestedStart.translate(
            0,
            _systemBaselineShift(startElement, referenceSystem, currentClef),
          ),
          extent: extents[startElement.system],
          above: slurAbove,
          outgoing: true,
          isSlur: true,
          color: color,
        );
        _drawSystemBreakSegment(
          canvas: canvas,
          anchor: nestedEnd.translate(
            0,
            _systemBaselineShift(endElement, referenceSystem, currentClef),
          ),
          extent: extents[endElement.system],
          above: slurAbove,
          outgoing: false,
          isSlur: true,
          color: color,
        );
        continue;
      }

      final calculator = SlurCalculator(
        rules: rules,
        skylineCalculator: skylineCalculator,
      );

      final curve = calculator.calculateSlur(
        startPoint: nestedStart,
        endPoint: nestedEnd,
        placement: slurAbove,
        staffSpace: staffSpace,
      );

      _drawVariableThicknessCurve(canvas, curve, color, isSlur: true);
    }

    // Cases (a) and (b): boundaries whose partner is on another system and so
    // is absent from [positions].
    _renderHangingSlurs(
      canvas: canvas,
      positions: positions,
      currentClef: currentClef,
      color: color,
      extents: extents,
      referenceSystem: referenceSystem,
    );
  }

  void renderTies({
    required Canvas canvas,
    required Map<int, List<int>> tieGroups,
    required List<PositionedElement> positions,
    required Clef currentClef,
    Color color = Colors.black,
  }) {
    final extents = _measureSystems(positions);
    final referenceSystem = positions.isEmpty ? 0 : positions.first.system;

    for (final group in tieGroups.values) {
      final startElement = positions[group.first];
      final endElement = positions[group.last];
      final tiePairs = _resolveTiePairs(startElement, endElement, currentClef);

      // In a chord, ties fan outward from the notehead column: notes above the
      // chord's vertical midpoint curve up, those below curve down (Gould
      // p.62-64). A single tie follows the stem rule.
      double? midPos;
      if (tiePairs.length > 1) {
        var maxP = tiePairs.first.start.staffPosition;
        var minP = maxP;
        for (final p in tiePairs) {
          if (p.start.staffPosition > maxP) maxP = p.start.staffPosition;
          if (p.start.staffPosition < minP) minP = p.start.staffPosition;
        }
        midPos = (maxP + minP) / 2;
      }

      for (final pair in tiePairs) {
        final tieAbove = midPos != null
            ? pair.start.staffPosition >= midPos
            : !pair.start.stemUp;
        final (startPoint, endPoint) = _calculateTieEndpoints(
          pair.start.noteOrigin,
          pair.start.note,
          pair.end.noteOrigin,
          pair.end.note,
          tieAbove: tieAbove,
          clef: currentClef,
          startStemUp: pair.start.stemUp,
          endStemUp: pair.end.stemUp,
        );

        // Case (c): a tie that straddles a line break is engraved as two
        // segments (Behind Bars p.63), never as one curve across systems.
        if (startElement.system != endElement.system) {
          _drawSystemBreakSegment(
            canvas: canvas,
            anchor: startPoint.translate(
              0,
              _systemBaselineShift(startElement, referenceSystem, currentClef),
            ),
            extent: extents[startElement.system],
            above: tieAbove,
            outgoing: true,
            isSlur: false,
            color: color,
          );
          _drawSystemBreakSegment(
            canvas: canvas,
            anchor: endPoint.translate(
              0,
              _systemBaselineShift(endElement, referenceSystem, currentClef),
            ),
            extent: extents[endElement.system],
            above: tieAbove,
            outgoing: false,
            isSlur: false,
            color: color,
          );
          continue;
        }

        final calculator = SlurCalculator(rules: rules);
        final curve = calculator.calculateTie(
          startPoint: startPoint,
          endPoint: endPoint,
          placement: tieAbove,
          staffSpace: staffSpace,
        );

        _drawVariableThicknessCurve(canvas, curve, color, isSlur: false);
      }
    }

    // Cases (a) and (b): tied notes whose partner is on another system.
    _renderHangingTies(
      canvas: canvas,
      positions: positions,
      currentClef: currentClef,
      color: color,
      extents: extents,
      referenceSystem: referenceSystem,
    );
  }

  // ==========================================================================
  // System-break support (Behind Bars: slurs p.109, ties p.63)
  // ==========================================================================

  /// Measures the horizontal extent of every system found in [positions].
  ///
  /// The right edge is the largest X of the system — or its rightmost
  /// [Barline], whichever is further right — and the left edge the smallest X.
  /// [_SystemExtent.musicLeft] is the first note/chord/rest of the system, i.e.
  /// where the restated clef and key signature stop.
  Map<int, _SystemExtent> _measureSystems(List<PositionedElement> positions) {
    final left = <int, double>{};
    final right = <int, double>{};
    final musicLeft = <int, double>{};
    final barlineRight = <int, double>{};
    final headerRight = <int, double>{};

    for (final positioned in positions) {
      final system = positioned.system;
      final x = positioned.position.dx;
      final knownLeft = left[system];
      left[system] = knownLeft == null ? x : math.min(knownLeft, x);
      final knownRight = right[system];
      right[system] = knownRight == null ? x : math.max(knownRight, x);

      final element = positioned.element;
      if (element is Barline) {
        final known = barlineRight[system];
        barlineRight[system] = known == null ? x : math.max(known, x);
      }
      if (element is Note || element is Chord || element is Rest) {
        final known = musicLeft[system];
        musicLeft[system] = known == null ? x : math.min(known, x);
      }
      if (element is Clef || element is KeySignature || element is TimeSignature) {
        final known = headerRight[system];
        headerRight[system] = known == null ? x : math.max(known, x);
      }
    }

    return {
      for (final system in left.keys)
        system: _SystemExtent(
          left: left[system]!,
          right: math.max(
            right[system]!,
            barlineRight[system] ?? right[system]!,
          ),
          musicLeft: musicLeft[system] ?? left[system]!,
          headerRight: headerRight[system] ?? left[system]!,
        ),
    };
  }

  /// X where the outgoing half of a broken span stops: a little past the last
  /// barline of the system it leaves, always ahead of its own note.
  double _outgoingBreakX(_SystemExtent? extent, double anchorX) {
    final edge =
        (extent?.right ?? anchorX) + (systemBreakTrailingSpaces * staffSpace);
    return math.max(edge, anchorX + staffSpace * 1.5);
  }

  /// X where the incoming half of a broken span starts: at the beginning of the
  /// staff, after the restated clef/key signature and before the first note.
  double _incomingBreakX(_SystemExtent? extent, double anchorX) {
    if (extent == null) {
      return anchorX - staffSpace * 1.5;
    }

    // The lead-in must start in the GAP between the system's header (restated
    // clef, key signature, meter) and its first note — never at the header's
    // own left edge.
    //
    // It used to be `max(extent.left, musicLeft - leadIn)`, and `extent.left`
    // is the X of the restated CLEF. Whenever the header was wider than
    // `systemBreakLeadInSpaces`, the max picked the clef's own origin and the
    // curve was drawn straight through the clef glyph. Visible in any
    // rasterised multi-system score with a tie across the break.
    //
    // Anchoring at the midpoint of the header-to-note gap is self-normalising:
    // `musicLeft` is by construction already clear of the header, so half of
    // that gap always is too, however wide the header happens to be.
    final headerGap = extent.musicLeft - extent.headerRight;
    final leadIn = headerGap > 0
        ? math.min(systemBreakLeadInSpaces * staffSpace, headerGap * 0.5)
        : systemBreakLeadInSpaces * staffSpace;
    final lead = extent.musicLeft - leadIn;

    // Degenerate case: the closing note IS the leftmost element of the system,
    // so there is no header to start after — fall back to a fixed lead-in.
    return (anchorX - lead) < staffSpace ? anchorX - staffSpace * 1.5 : lead;
  }

  /// Vertical correction for an element that belongs to another system than the
  /// one this renderer was built for.
  ///
  /// Endpoint Y is derived from the pitch and [staffBaselineY], which only
  /// describes [referenceSystem]. When the caller passes several systems at
  /// once, the element's own position carries its system baseline (notes hold
  /// their pixel Y, other elements the baseline itself), so the difference
  /// gives the shift. Elements of [referenceSystem] are never shifted, so the
  /// single-system path is bit-for-bit unchanged.
  double _systemBaselineShift(
    PositionedElement positioned,
    int referenceSystem,
    Clef clef,
  ) {
    if (positioned.system == referenceSystem) {
      return 0.0;
    }
    final element = positioned.element;
    if (element is Note) {
      final staffPosition = StaffPositionCalculator.calculate(
        element.pitch,
        clef,
        extraOctaveShift: _octaveShiftOf(element),
      );
      // Inverse of StaffPositionCalculator.toPixelY.
      return (positioned.position.dy + (staffPosition * staffSpace * 0.5)) -
          staffBaselineY;
    }
    return positioned.position.dy - staffBaselineY;
  }

  /// Draws one half of a span broken by a system break.
  ///
  /// [anchor] is the endpoint on the note; the other end is free ("in the air"):
  /// it sits at the system limit and is lifted away from the staff so the
  /// segment stops without pointing at anything. Curvature, control points and
  /// the Bravura endpoint/midpoint thicknesses are the ordinary ones.
  void _drawSystemBreakSegment({
    required Canvas canvas,
    required Offset anchor,
    required _SystemExtent? extent,
    required bool above,
    required bool outgoing,
    required bool isSlur,
    required Color color,
  }) {
    final freeX = outgoing
        ? _outgoingBreakX(extent, anchor.dx)
        : _incomingBreakX(extent, anchor.dx);
    final lift = systemBreakAirLiftSpaces * staffSpace * (above ? -1 : 1);
    final free = Offset(freeX, anchor.dy + lift);

    final startPoint = outgoing ? anchor : free;
    final endPoint = outgoing ? free : anchor;

    final calculator = SlurCalculator(
      rules: rules,
      skylineCalculator: isSlur ? skylineCalculator : null,
    );
    final curve = isSlur
        ? calculator.calculateSlur(
            startPoint: startPoint,
            endPoint: endPoint,
            placement: above,
            staffSpace: staffSpace,
          )
        : calculator.calculateTie(
            startPoint: startPoint,
            endPoint: endPoint,
            placement: above,
            staffSpace: staffSpace,
          );

    _drawVariableThicknessCurve(canvas, curve, color, isSlur: isSlur);
  }

  /// Draws the slur boundaries in [positions] whose partner is missing because
  /// it lives on another system (cases (a) and (b) of the class docs).
  ///
  /// Pairing uses [GroupRenderer.slurEventsOf] and the same number-keyed
  /// matching as `GroupRenderer.identifySlurGroups`, so a boundary is reported
  /// here exactly when no complete group was produced for it — a span is never
  /// drawn twice.
  void _renderHangingSlurs({
    required Canvas canvas,
    required List<PositionedElement> positions,
    required Clef currentClef,
    required Color color,
    required Map<int, _SystemExtent> extents,
    required int referenceSystem,
  }) {
    final open = <int, int>{}; // slur number -> element index
    final hanging = <({int index, bool isStart})>[];

    for (int index = 0; index < positions.length; index++) {
      final element = positions[index].element;
      if (element is! Note && element is! Chord) {
        continue;
      }
      for (final event in GroupRenderer.slurEventsOf(element)) {
        if (event.type == SlurType.start) {
          open[event.number] = index;
        } else if (event.type == SlurType.end) {
          if (open.remove(event.number) == null) {
            hanging.add((index: index, isStart: false));
          }
        }
      }
    }
    for (final entry in open.entries) {
      hanging.add((index: entry.value, isStart: true));
    }

    for (final boundary in hanging) {
      final positioned = positions[boundary.index];
      // Grace-note slurs belong to the grace-note renderer.
      if (_hasGraceOrnamentOnElement(positioned.element)) {
        continue;
      }

      final preferred = boundary.isStart ? SlurType.start : SlurType.end;
      final probe = _pickNoteFromElement(
        positioned,
        above: true,
        clef: currentClef,
        preferredSlurType: preferred,
      );
      if (probe == null) {
        continue;
      }

      // Only one note is available, so the side comes from its stem alone
      // (Behind Bars: a slur sits on the side opposite the stem).
      final above = !probe.stemUp;
      final note = _pickNoteFromElement(
        positioned,
        above: above,
        clef: currentClef,
        preferredSlurType: preferred,
      )!;

      final anchor =
          _calculateSlurEndpoint(
            note.noteOrigin,
            note.note,
            currentClef,
            isStart: boundary.isStart,
            above: above,
            stemUp: note.stemUp,
          ).translate(
            0,
            _systemBaselineShift(positioned, referenceSystem, currentClef),
          );

      _drawSystemBreakSegment(
        canvas: canvas,
        anchor: anchor,
        extent: extents[positioned.system],
        above: above,
        outgoing: boundary.isStart,
        isSlur: true,
        color: color,
      );
    }
  }

  /// Draws the tied notes in [positions] whose partner note is missing because
  /// it lives on another system (cases (a) and (b) of the class docs).
  void _renderHangingTies({
    required Canvas canvas,
    required List<PositionedElement> positions,
    required Clef currentClef,
    required Color color,
    required Map<int, _SystemExtent> extents,
    required int referenceSystem,
  }) {
    for (int index = 0; index < positions.length; index++) {
      final positioned = positions[index];
      if (positioned.element is! Note && positioned.element is! Chord) {
        continue;
      }
      final placements = _resolveElementPlacements(positioned, currentClef);
      final tied = placements
          .where((placement) => placement.note.tie != null)
          .toList();
      if (tied.isEmpty) {
        continue;
      }

      // Same fan rule as renderTies: inside a chord the ties spread outward
      // from the vertical midpoint (Gould p.62-64).
      double? midPos;
      if (tied.length > 1) {
        var maxP = tied.first.staffPosition;
        var minP = maxP;
        for (final placement in tied) {
          if (placement.staffPosition > maxP) maxP = placement.staffPosition;
          if (placement.staffPosition < minP) minP = placement.staffPosition;
        }
        midPos = (maxP + minP) / 2;
      }

      final shift = _systemBaselineShift(
        positioned,
        referenceSystem,
        currentClef,
      );
      final extent = extents[positioned.system];

      for (final placement in tied) {
        final tie = placement.note.tie;
        final opensForward = tie == TieType.start || tie == TieType.inner;
        final closesBackward = tie == TieType.end || tie == TieType.inner;
        final hangingStart =
            opensForward &&
            !_hasTiePartner(positions, index, placement.note, forward: true) &&
            _isSystemEdgeEvent(positions, index, forward: true);
        final hangingEnd =
            closesBackward &&
            !_hasTiePartner(positions, index, placement.note, forward: false) &&
            _isSystemEdgeEvent(positions, index, forward: false);
        if (!hangingStart && !hangingEnd) {
          continue;
        }

        final tieAbove = midPos != null
            ? placement.staffPosition >= midPos
            : !placement.stemUp;

        if (hangingStart) {
          _drawSystemBreakSegment(
            canvas: canvas,
            anchor: _tieBreakAnchor(
              placement,
              tieAbove: tieAbove,
              isStart: true,
            ).translate(0, shift),
            extent: extent,
            above: tieAbove,
            outgoing: true,
            isSlur: false,
            color: color,
          );
        }
        if (hangingEnd) {
          _drawSystemBreakSegment(
            canvas: canvas,
            anchor: _tieBreakAnchor(
              placement,
              tieAbove: tieAbove,
              isStart: false,
            ).translate(0, shift),
            extent: extent,
            above: tieAbove,
            outgoing: false,
            isSlur: false,
            color: color,
          );
        }
      }
    }
  }

  /// Whether [note] has a partner of the same written pitch elsewhere in
  /// [positions] — later in the list when [forward], earlier otherwise.
  ///
  /// A tie with no partner in the list is a tie broken by a system break: the
  /// other note is on the neighbouring system, which the caller renders in its
  /// own pass.
  bool _hasTiePartner(
    List<PositionedElement> positions,
    int index,
    Note note, {
    required bool forward,
  }) {
    final step = forward ? 1 : -1;
    for (int j = index + step; j >= 0 && j < positions.length; j += step) {
      final element = positions[j].element;
      final candidates = element is Note
          ? <Note>[element]
          : (element is Chord ? element.notes : const <Note>[]);
      for (final candidate in candidates) {
        if (!_sameWrittenPitch(note, candidate)) {
          continue;
        }
        final tie = candidate.tie;
        if (forward && (tie == TieType.end || tie == TieType.inner)) {
          return true;
        }
        if (!forward && (tie == TieType.start || tie == TieType.inner)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether the element at [index] is the last event of its system (or the
  /// first, when [forward] is false), counting only the notes of its own voice.
  ///
  /// A tie always joins CONSECUTIVE notes of the same pitch, so it can only be
  /// broken by a line break when its note sits at the very edge of the system:
  /// its partner is then the first note of the next system. An unmatched tie
  /// anywhere else is a defect in the data, not a broken tie, and gets no
  /// segment — otherwise every stray `TieType.start` would sprout a stub.
  bool _isSystemEdgeEvent(
    List<PositionedElement> positions,
    int index, {
    required bool forward,
  }) {
    final anchor = positions[index];
    final step = forward ? 1 : -1;
    for (int j = index + step; j >= 0 && j < positions.length; j += step) {
      final other = positions[j];
      if (other.system != anchor.system ||
          other.voiceNumber != anchor.voiceNumber) {
        continue;
      }
      if (other.element is Note || other.element is Chord) {
        return false;
      }
    }
    return true;
  }

  /// Single-sided tie anchor, used by the broken halves.
  ///
  /// Mirrors [_calculateTieEndpoints]; that method keeps a clearance shared by
  /// both noteheads, which is impossible here because only one of them exists
  /// in this system.
  Offset _tieBreakAnchor(
    _ElementNotePlacement placement, {
    required bool tieAbove,
    required bool isStart,
  }) {
    final metrics = _resolveNoteheadMetrics(
      placement.noteOrigin,
      placement.note,
    );
    final clearance = math.max(
      metrics.halfHeight + staffSpace * 0.1,
      staffSpace * 0.35,
    );
    return Offset(
      _resolveStemSafeAnchorX(
        metrics,
        stemUp: placement.stemUp,
        above: tieAbove,
        isStart: isStart,
      ),
      placement.noteOrigin.dy + (tieAbove ? -clearance : clearance),
    );
  }

  _ElementNotePlacement? _pickNoteFromElement(
    PositionedElement element, {
    required bool above,
    required Clef clef,
    SlurType? preferredSlurType,
  }) {
    final placements = _resolveElementPlacements(element, clef);
    if (placements.isEmpty) {
      return null;
    }

    final preferredPlacements = preferredSlurType == null
        ? placements
        : placements
              .where(
                (placement) =>
                    placement.note.slur == preferredSlurType ||
                    placement.note.slur == SlurType.inner,
              )
              .toList();
    final candidates = preferredPlacements.isNotEmpty
        ? preferredPlacements
        : placements;

    candidates.sort(
      (left, right) => right.staffPosition.compareTo(left.staffPosition),
    );
    return above ? candidates.first : candidates.last;
  }

  List<_ElementNotePlacement> _resolveElementPlacements(
    PositionedElement element,
    Clef clef,
  ) {
    final placements = <_ElementNotePlacement>[];
    if (element.element is Note) {
      final note = element.element as Note;
      final staffPosition = StaffPositionCalculator.calculate(
        note.pitch,
        clef,
        extraOctaveShift: _octaveShiftOf(note),
      );
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        staffBaselineY,
      );
      placements.add(
        _ElementNotePlacement(
          note: note,
          noteOrigin: Offset(element.position.dx, noteY),
          staffPosition: staffPosition,
          stemUp: _resolveStemUp(note, staffPosition, element.voiceNumber),
        ),
      );
      return placements;
    }

    if (element.element is! Chord) {
      return placements;
    }

    final chord = element.element as Chord;
    int chordPosOf(Note n) => StaffPositionCalculator.calculate(
      n.pitch,
      clef,
      extraOctaveShift: _octaveShiftOf(n),
    );
    final sortedNotes = [...chord.notes]
      ..sort((left, right) => chordPosOf(right).compareTo(chordPosOf(left)));
    final positions = sortedNotes.map(chordPosOf).toList();
    final stemUp = ChordRenderer.resolveStemDirection(
      chord: chord,
      positions: positions,
      voiceNumber: element.voiceNumber,
    );
    final noteheadBox = metadata
        .getGlyphInfo(chord.duration.type.glyphName)
        ?.boundingBox;
    final noteheadWidth =
        ((noteheadBox?.width ?? metadata.getGlyphWidth('noteheadBlack')).clamp(
          0.7,
          2.2,
        )).toDouble();
    final clusterOffset = noteheadWidth * staffSpace * 1.04;
    final clusterOffsets = ChordRenderer.calculateClusterOffsets(
      positions: positions,
      stemUp: stemUp,
      clusterOffset: clusterOffset,
    );

    for (int index = 0; index < sortedNotes.length; index++) {
      final staffPosition = positions[index];
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        staffBaselineY,
      );
      placements.add(
        _ElementNotePlacement(
          note: sortedNotes[index],
          noteOrigin: Offset(
            element.position.dx + clusterOffsets[index],
            noteY,
          ),
          staffPosition: staffPosition,
          stemUp: stemUp,
        ),
      );
    }

    return placements;
  }

  List<_TiePair> _resolveTiePairs(
    PositionedElement startElement,
    PositionedElement endElement,
    Clef clef,
  ) {
    final startCandidates = _resolveElementPlacements(startElement, clef)
        .where(
          (placement) =>
              placement.note.tie == TieType.start ||
              placement.note.tie == TieType.inner,
        )
        .toList();
    final endCandidates = _resolveElementPlacements(endElement, clef)
        .where(
          (placement) =>
              placement.note.tie == TieType.end ||
              placement.note.tie == TieType.inner,
        )
        .toList();

    if (startCandidates.isEmpty || endCandidates.isEmpty) {
      return const [];
    }

    final pairs = <_TiePair>[];
    final claimedEnds = <int>{};
    for (final start in startCandidates) {
      for (int index = 0; index < endCandidates.length; index++) {
        if (claimedEnds.contains(index)) {
          continue;
        }

        final end = endCandidates[index];
        if (!_sameWrittenPitch(start.note, end.note)) {
          continue;
        }

        pairs.add(_TiePair(start: start, end: end));
        claimedEnds.add(index);
        break;
      }
    }

    return pairs;
  }

  bool _sameWrittenPitch(Note left, Note right) {
    return left.pitch.step == right.pitch.step &&
        left.pitch.octave == right.pitch.octave &&
        left.pitch.alter == right.pitch.alter;
  }

  SlurDirection _calculateSlurDirection(
    _ElementNotePlacement startNote,
    _ElementNotePlacement endNote,
  ) {
    if (startNote.stemUp == endNote.stemUp) {
      return startNote.stemUp ? SlurDirection.down : SlurDirection.up;
    }

    final avgPos = (startNote.staffPosition + endNote.staffPosition) / 2;
    return avgPos > 0 ? SlurDirection.up : SlurDirection.down;
  }

  Offset _calculateSlurEndpoint(
    Offset notePos,
    Note note,
    Clef clef, {
    required bool isStart,
    required bool above,
    bool isGraceSlur = false,
    bool? stemUp,
  }) {
    final metrics = _resolveNoteheadMetrics(notePos, note);
    final effectiveGraceSlur = isGraceSlur || hasGraceOrnament(note);

    final staffPos = StaffPositionCalculator.calculate(
      note.pitch,
      clef,
      extraOctaveShift: _octaveShiftOf(note),
    );
    final noteY = StaffPositionCalculator.toPixelY(
      staffPos,
      staffSpace,
      staffBaselineY,
    );

    if (isStart && effectiveGraceSlur) {
      return graceSlurStartPointForNote(
        note: note,
        notePos: Offset(notePos.dx, noteY),
        above: above,
        staffSpace: staffSpace,
        glyphSize: staffSpace * 4.0,
        metadata: metadata,
      );
    }

    final resolvedStemUp = stemUp ?? _resolveStemUp(note, staffPos);

    // Slurs anchor to the notehead surface, not the stem.
    final noteheadClearance = math.max(
      metrics.halfHeight + staffSpace * 0.15,
      staffSpace * 0.4,
    );
    final yOffset = noteheadClearance * (above ? -1 : 1);
    final x = _resolveStemSafeAnchorX(
      metrics,
      stemUp: resolvedStemUp,
      above: above,
      isStart: isStart,
    );
    return Offset(x, noteY + yOffset);
  }

  (Offset, Offset) _calculateTieEndpoints(
    Offset startPos,
    Note startNote,
    Offset endPos,
    Note endNote, {
    required bool tieAbove,
    required Clef clef,
    bool? startStemUp,
    bool? endStemUp,
  }) {
    final startMetrics = _resolveNoteheadMetrics(startPos, startNote);
    final endMetrics = _resolveNoteheadMetrics(endPos, endNote);

    // Compute ACTUAL notehead Y from pitch (positions carry system-baseline Y).
    final startStaffPos = StaffPositionCalculator.calculate(
      startNote.pitch,
      clef,
      extraOctaveShift: _octaveShiftOf(startNote),
    );
    final endStaffPos = StaffPositionCalculator.calculate(
      endNote.pitch,
      clef,
      extraOctaveShift: _octaveShiftOf(endNote),
    );
    final startNoteY = StaffPositionCalculator.toPixelY(
      startStaffPos,
      staffSpace,
      staffBaselineY,
    );
    final endNoteY = StaffPositionCalculator.toPixelY(
      endStaffPos,
      staffSpace,
      staffBaselineY,
    );

    // Tie sits just outside the notehead surface (Behind Bars: 0.25 SS clearance).
    final clearance = math.max(
      math.max(startMetrics.halfHeight, endMetrics.halfHeight) +
          staffSpace * 0.1,
      staffSpace * 0.35,
    );

    return (
      Offset(
        _resolveStemSafeAnchorX(
          startMetrics,
          stemUp: startStemUp ?? _resolveStemUp(startNote, startStaffPos),
          above: tieAbove,
          isStart: true,
        ),
        startNoteY + (tieAbove ? -clearance : clearance),
      ),
      Offset(
        _resolveStemSafeAnchorX(
          endMetrics,
          stemUp: endStemUp ?? _resolveStemUp(endNote, endStaffPos),
          above: tieAbove,
          isStart: false,
        ),
        endNoteY + (tieAbove ? -clearance : clearance),
      ),
    );
  }

  double _resolveStemSafeAnchorX(
    _NoteheadMetrics metrics, {
    required bool stemUp,
    required bool above,
    required bool isStart,
  }) {
    final centerX = (metrics.leftEdge + metrics.rightEdge) * 0.5;
    final stemSafeInset = math.min(metrics.width * 0.18, staffSpace * 0.22);
    final directionalInset = math.min(metrics.width * 0.08, staffSpace * 0.12);

    if (above && !stemUp) {
      return centerX + (isStart ? stemSafeInset : directionalInset);
    }

    if (!above && stemUp) {
      return centerX - (isStart ? directionalInset : stemSafeInset);
    }

    final edgeInset = math.min(metrics.width * 0.16, staffSpace * 0.14);
    return isStart
        ? metrics.rightEdge - edgeInset
        : metrics.leftEdge + edgeInset;
  }

  bool _resolveStemUp(Note note, int staffPosition, [int? voiceNumber]) {
    final effectiveVoice = voiceNumber ?? note.voice;
    if (effectiveVoice != null) {
      return effectiveVoice.isOdd;
    }
    return StaffPositionCalculator.stemUpFor(staffPosition);
  }

  Offset calculateSlurEndpointForTesting(
    Offset notePos,
    Note note,
    Clef clef, {
    required bool isStart,
    required bool above,
    bool isGraceSlur = false,
    bool? stemUp,
  }) {
    return _calculateSlurEndpoint(
      notePos,
      note,
      clef,
      isStart: isStart,
      above: above,
      isGraceSlur: isGraceSlur,
      stemUp: stemUp,
    );
  }

  (Offset, Offset) calculateTieEndpointsForTesting(
    Offset startPos,
    Note startNote,
    Offset endPos,
    Note endNote, {
    required bool tieAbove,
    required Clef clef,
    bool? startStemUp,
    bool? endStemUp,
  }) {
    return _calculateTieEndpoints(
      startPos,
      startNote,
      endPos,
      endNote,
      tieAbove: tieAbove,
      clef: clef,
      startStemUp: startStemUp,
      endStemUp: endStemUp,
    );
  }

  bool _hasGraceOrnamentOnElement(dynamic element) {
    if (element is Note) {
      return hasGraceOrnament(element);
    }
    if (element is Chord) {
      return hasGraceOrnamentInOrnaments(element.ornaments);
    }
    return false;
  }

  void _drawVariableThicknessCurve(
    Canvas canvas,
    CubicBezierCurve curve,
    Color color, {
    required bool isSlur,
  }) {
    final endpointThickness = isSlur
        ? metadata.getEngravingDefaultValue('slurEndpointThickness') ?? 0.1
        : metadata.getEngravingDefaultValue('tieEndpointThickness') ?? 0.1;

    final midpointThickness = isSlur
        ? metadata.getEngravingDefaultValue('slurMidpointThickness') ?? 0.22
        : metadata.getEngravingDefaultValue('tieMidpointThickness') ?? 0.22;

    final endpointThicknessPx = endpointThickness * staffSpace;
    final midpointThicknessPx = midpointThickness * staffSpace;

    final pathTop = Path();
    final pathBottom = Path();

    const numPoints = 50;
    final points = <Offset>[];
    final thicknesses = <double>[];

    for (int i = 0; i <= numPoints; i++) {
      final t = i / numPoints;
      final point = curve.pointAt(t);
      points.add(point);

      final tCentered = 2 * t - 1;
      final factor = 1 - tCentered * tCentered;
      final thickness =
          endpointThicknessPx +
          (midpointThicknessPx - endpointThicknessPx) * factor;
      thicknesses.add(thickness);
    }

    for (int i = 0; i <= numPoints; i++) {
      final point = points[i];
      final thickness = thicknesses[i];
      final t = i / numPoints;
      final tangent = curve.derivativeAt(t);
      final tangentAngle = math.atan2(tangent.dy, tangent.dx);

      final perpAngle = tangentAngle + math.pi / 2;
      final perpDx = math.cos(perpAngle) * thickness / 2;
      final perpDy = math.sin(perpAngle) * thickness / 2;

      final topPoint = Offset(point.dx + perpDx, point.dy + perpDy);
      final bottomPoint = Offset(point.dx - perpDx, point.dy - perpDy);

      if (i == 0) {
        pathTop.moveTo(topPoint.dx, topPoint.dy);
        pathBottom.moveTo(bottomPoint.dx, bottomPoint.dy);
      } else {
        pathTop.lineTo(topPoint.dx, topPoint.dy);
        pathBottom.lineTo(bottomPoint.dx, bottomPoint.dy);
      }
    }

    final closedPath = Path()..addPath(pathTop, Offset.zero);

    for (int i = numPoints; i >= 0; i--) {
      final t = i / numPoints;
      final point = curve.pointAt(t);
      final thickness = thicknesses[i];
      final tangent = curve.derivativeAt(t);
      final tangentAngle = math.atan2(tangent.dy, tangent.dx);
      final perpAngle = tangentAngle + math.pi / 2;
      final perpDx = math.cos(perpAngle) * thickness / 2;
      final perpDy = math.sin(perpAngle) * thickness / 2;
      final bottomPoint = Offset(point.dx - perpDx, point.dy - perpDy);
      closedPath.lineTo(bottomPoint.dx, bottomPoint.dy);
    }

    closedPath.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(closedPath, paint);
  }
}

/// Horizontal limits of one system, in canvas pixels.
class _SystemExtent {
  /// Smallest X of the system (usually the restated clef).
  final double left;

  /// Largest X of the system, or its rightmost barline.
  final double right;

  /// X of the first note/chord/rest, i.e. where the clef/key restatement ends.
  final double musicLeft;

  /// X of the RIGHTMOST system element (clef, key signature or meter) of this
  /// system — the head of the gap a cross-system slur may lead in through.
  final double headerRight;

  const _SystemExtent({
    required this.left,
    required this.right,
    required this.musicLeft,
    required this.headerRight,
  });
}

class _NoteheadMetrics {
  final double leftEdge;
  final double rightEdge;
  final double width;
  final double halfHeight;
  final Offset? stemUpAnchor;
  final Offset? stemDownAnchor;

  const _NoteheadMetrics({
    required this.leftEdge,
    required this.rightEdge,
    required this.width,
    required this.halfHeight,
    required this.stemUpAnchor,
    required this.stemDownAnchor,
  });
}

class _ElementNotePlacement {
  final Note note;
  final Offset noteOrigin;
  final int staffPosition;
  final bool stemUp;

  const _ElementNotePlacement({
    required this.note,
    required this.noteOrigin,
    required this.staffPosition,
    required this.stemUp,
  });
}

class _TiePair {
  final _ElementNotePlacement start;
  final _ElementNotePlacement end;

  const _TiePair({required this.start, required this.end});
}
