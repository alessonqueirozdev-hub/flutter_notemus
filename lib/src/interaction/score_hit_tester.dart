// Hit-testing and selection over a laid-out score.
//
// This is the first piece of editor infrastructure the engine can honestly
// offer. It only became possible once the layout stopped REPLACING the caller's
// `Note` objects with clones: hit-testing is worthless if the element you get
// back is not the element you hold in your model, because you cannot then edit,
// highlight or delete it.
//
// Everything here is derived from `PositionedElement`, which now carries the
// element itself, its absolute position, its system, its measure index, its
// voice and its musical onset — i.e. all four axes a score editor selects on:
// by point, by region, by structural unit (measure / system / voice) and by
// time (for playing just a selection).

import 'package:flutter/material.dart' show Offset, Rect;

import '../../core/core.dart';
import '../layout/layout_engine.dart';
import '../rendering/smufl_positioning_engine.dart';
import '../rendering/staff_position_calculator.dart';

/// One element found under a point or inside a region.
class ScoreHit {
  /// The element from the caller's own model (identity preserved).
  final MusicalElement element;

  /// Top-left anchor the layout gave this element.
  final Offset position;

  /// Box used for the test, in the same coordinate space as [position].
  final Rect bounds;

  /// System (wrapped line) the element belongs to.
  final int system;

  /// Measure index within the staff, or -1 when unknown.
  final int measureIndex;

  /// Voice number in polyphonic contexts, or null.
  final int? voiceNumber;

  /// Musical onset in whole notes from the start of the staff.
  final double onset;

  /// Distance from the tested point to [bounds] (0 when inside).
  final double distance;

  const ScoreHit({
    required this.element,
    required this.position,
    required this.bounds,
    required this.system,
    required this.measureIndex,
    required this.voiceNumber,
    required this.onset,
    required this.distance,
  });

  @override
  String toString() => 'ScoreHit(${element.runtimeType} '
      'bar $measureIndex, onset $onset, d=${distance.toStringAsFixed(1)})';
}

/// A contiguous musical span, e.g. what a click-drag selected.
///
/// Feed [startOnset]/[endOnset] to the MIDI mapper to play only the selection.
class ScoreSelection {
  final List<ScoreHit> hits;
  final double startOnset;
  final double endOnset;
  final int firstMeasure;
  final int lastMeasure;

  const ScoreSelection({
    required this.hits,
    required this.startOnset,
    required this.endOnset,
    required this.firstMeasure,
    required this.lastMeasure,
  });

  bool get isEmpty => hits.isEmpty;

  /// Elements of the selection that carry sound.
  Iterable<MusicalElement> get soundingElements => hits
      .map((h) => h.element)
      .where((e) => e is Note || e is Chord || e is Tuplet);
}

/// Point / region / structural selection over a laid-out staff.
///
/// ```dart
/// final engine = LayoutEngine(staff, availableWidth: w, metadata: meta);
/// final elements = engine.layout();
/// final tester = ScoreHitTester(
///   elements: elements, staffSpace: 12, engine: engine);
///
/// final hit = tester.hitTest(localPosition);
/// if (hit != null) highlight(hit.element);
/// ```
class ScoreHitTester {
  /// The laid-out elements to test against.
  final List<PositionedElement> elements;

  /// Staff space used for the layout (drives the default box heights).
  final double staffSpace;

  /// Optional engine, used for exact element widths. Without it, widths fall
  /// back to a notehead-sized box, which is enough for coarse picking but will
  /// not match wide glyphs such as clefs or whole rests.
  final LayoutEngine? engine;

  ScoreHitTester({
    required this.elements,
    required this.staffSpace,
    this.engine,
  });

  /// Standard stem length, in staff spaces (Behind Bars p.13).
  ///
  /// Only ever used by the no-engine fallback: with an engine in hand the reach
  /// comes from [SMuFLPositioningEngine.calculateStemLength], which is the
  /// function the renderer itself calls, and which routinely returns far more
  /// than this. MEASURED at staffSpace 12, treble, quarter notes: staff
  /// position -20 renders a stem of 10.000 staff spaces, not 3.5, because
  /// Behind Bars p.47 requires the stem to reach the middle line.
  static const double _stemLengthSpaces = 3.5;

  /// Extra reach of a flag past the end of the stem, in staff spaces.
  ///
  /// Kept as an ADDITION on top of the computed stem length rather than as a
  /// replacement for it. MEASURED, `flag8thUp` at staffSpace 12: the glyph
  /// hangs from the stem tip DOWNWARDS (bounding box y from +0.035 to -3.241
  /// staff spaces), so it overshoots the tip by only 0.035 SS vertically — this
  /// 0.6 SS is pure cushion for the flags whose upper edge sits a little above
  /// their anchor.
  static const double _flagReachSpaces = 0.6;

  /// Half-height of a notehead, in staff spaces.
  static const double _noteheadHalfSpaces = 0.7;

  /// Notehead stem-attachment offset assumed when no metadata is available.
  ///
  /// Bravura's `noteheadBlack` publishes `stemUpSE = [1.18, 0.168]` and
  /// `stemDownNW = [0.0, -0.168]`; the renderer starts the stem at that anchor,
  /// so the tip is |0.168| staff spaces further out than the notehead centre.
  /// MEASURED: ignoring it is exactly the 2.02 px by which the old box missed
  /// the tip of an ordinary 3.5 SS stem at staffSpace 12.
  static const double _fallbackStemAttachmentSpaces = 0.168;

  /// SMuFL `legerLineExtension` assumed when no metadata is available (0.4 SS
  /// in Bravura): how far a ledger line sticks out past the notehead on EACH
  /// side.
  static const double _fallbackLegerLineExtensionSpaces = 0.4;

  /// Notehead advance width assumed when no metadata is available, in staff
  /// spaces (Bravura `noteheadBlack` bounding box: 0.0 .. 1.18).
  static const double _fallbackNoteheadWidthSpaces = 1.18;

  /// Horizontal shift, as a multiple of the notehead width, that
  /// `ChordRenderer.calculateClusterOffsets` gives the displaced notehead of a
  /// second inside a chord (chord_renderer.dart: `noteheadWidthPx * 1.04`).
  static const double _clusterShiftFactor = 1.04;

  /// The renderer's own positioning engine, rebuilt here from the layout
  /// engine's metadata.
  ///
  /// This is the whole point of M-14: the box must be derived from the SAME
  /// function that draws the stem ([SMuFLPositioningEngine.calculateStemLength]
  /// / [SMuFLPositioningEngine.calculateChordStemLength]), not from an
  /// independent guess that happened to agree with it only for notes near the
  /// middle line. Null when the tester was built without a layout engine, or
  /// with one that carries no metadata — see [_stemReachPx] for what happens
  /// then.
  late final SMuFLPositioningEngine? _positioning = _buildPositioning();

  SMuFLPositioningEngine? _buildPositioning() {
    final metadata = engine?.metadata;
    if (metadata == null) return null;
    return SMuFLPositioningEngine(metadataLoader: metadata);
  }

  /// Box a given element occupies, derived from what is actually DRAWN.
  ///
  /// The box used to be an independent estimate and it was wrong in three ways
  /// a user could feel:
  ///
  /// * it was `elementWidth` wide starting at `x`, but `elementWidth` INCLUDES
  ///   the accidental, which is drawn to the LEFT of the notehead — so the box
  ///   was about an accidental too wide on the right and an accidental short on
  ///   the left, and clicking an accidental selected nothing;
  /// * it was one notehead tall, so the STEM and the flag were outside it;
  /// * for a [Chord] it was centred on `position.dy`, which for a chord is the
  ///   STAFF BASELINE and not the noteheads. A C6-E6-G6 chord got a box drawn
  ///   around the staff while its noteheads sat far above: clicking exactly on
  ///   a notehead returned null.
  ///
  /// A fourth way was found later and is the subject of M-14: even once the box
  /// grew a stem, the stem was a CONSTANT 3.5 staff spaces while the renderer
  /// draws whatever [SMuFLPositioningEngine.calculateStemLength] returns — up
  /// to 10 staff spaces for a note an octave below the staff, and 17.5 for a
  /// four-octave chord. See [_stemReachPx].
  ///
  /// Everything below now comes from the same numbers the renderers use —
  /// `LayoutEngine.noteYPositions` for where a notehead really is,
  /// `noteStaffPositions` for stem direction, and the engine's own left/right
  /// extents for the horizontal span.
  Rect boundsOf(PositionedElement positioned) {
    final element = positioned.element;
    final x = positioned.position.dx;
    final air = staffSpace * 0.2;

    if (element is Note) {
      final span = _horizontalSpan(element, x);
      final y = engine?.noteYPositions[element] ?? positioned.position.dy;
      final stemUp = _stemPointsUp([element]);
      final positions = _staffPositionsOf([element]);
      final glyph = element.duration.type.glyphName;
      final vertical = _verticalSpan(
        highestNoteY: y,
        lowestNoteY: y,
        stemUp: stemUp,
        duration: element.duration.type,
        stemReachPx: _stemReachPx(
          noteheadGlyph: glyph,
          stemUp: stemUp,
          staffPositions: positions,
          duration: element.duration.type,
          isChord: false,
        ),
      );
      return _withGlyphOverhang(
        Rect.fromLTRB(span.left, vertical.top, span.right, vertical.bottom),
        x: x,
        noteheadGlyph: glyph,
        stemUp: stemUp,
        staffPositions: positions,
        duration: element.duration.type,
        beamed: _noteIsBeamed(element),
        isChord: false,
      );
    }

    if (element is Chord) {
      final span = _horizontalSpan(element, x);
      var highest = double.infinity;
      var lowest = double.negativeInfinity;
      for (final note in element.notes) {
        final y = engine?.noteYPositions[note];
        if (y == null) continue;
        if (y < highest) highest = y;
        if (y > lowest) lowest = y;
      }
      if (!highest.isFinite || !lowest.isFinite) {
        // No geometry registered (a chord laid out with no clef in force):
        // fall back to the staff, which is the only thing we know.
        highest = positioned.staffBaselineY - staffSpace * 2;
        lowest = positioned.staffBaselineY + staffSpace * 2;
      }
      final stemUp = _stemPointsUp(element.notes);
      final positions = _staffPositionsOf(element.notes);
      final glyph = element.duration.type.glyphName;
      final vertical = _verticalSpan(
        highestNoteY: highest,
        lowestNoteY: lowest,
        stemUp: stemUp,
        duration: element.duration.type,
        stemReachPx: _stemReachPx(
          noteheadGlyph: glyph,
          stemUp: stemUp,
          staffPositions: positions,
          duration: element.duration.type,
          isChord: true,
        ),
      );
      return _withGlyphOverhang(
        Rect.fromLTRB(span.left, vertical.top, span.right, vertical.bottom),
        x: x,
        noteheadGlyph: glyph,
        stemUp: stemUp,
        staffPositions: positions,
        duration: element.duration.type,
        beamed: _chordIsBeamed(element),
        isChord: true,
      );
    }

    final width = engine?.elementWidth(element) ?? staffSpace * 1.2;
    if (element is Rest) {
      return Rect.fromLTWH(
        x - air,
        positioned.position.dy - staffSpace * 2,
        width + air * 2,
        staffSpace * 4,
      );
    }

    // Clefs, key/time signatures, barlines, brackets: full staff height plus a
    // little air above and below, measured from the staff this element sits on.
    return Rect.fromLTWH(
      x - air,
      positioned.position.dy - staffSpace * 3,
      width + air * 2,
      staffSpace * 6,
    );
  }

  /// Whether [note] is beamed, as the LAYOUT decided - never as the model
  /// happens to be labelled.
  ///
  /// `beamed` widens the box a stem's worth and drops the flag's overhang, so
  /// it has to agree with what was actually drawn. This used to read
  /// `element.beam != null` straight off the model, which was right only while
  /// the engine stamped its answer there. ADR-005 stopped the stamp, and the
  /// read did not move: from 2.7.2 it reported the AUTHOR'S HINT - `null` for
  /// every automatically beamed note - so `boundsOf` reserved a flag's
  /// overhang under every beam and hit-testing quietly stopped matching the
  /// picture. That is a silent semantic change in a public selection API, not
  /// a rendering blemish, which is why it is a named helper now.
  ///
  /// `LayoutEngine.beamOf` already falls back to the author's hint when the
  /// engine made no decision, so the two branches differ only in whether an
  /// engine was supplied at all.
  bool _noteIsBeamed(Note note) =>
      (engine?.beamOf(note) ?? note.beam) != null;

  /// Whether [chord] is beamed.
  ///
  /// There is no engine-published answer to prefer here: both
  /// `LayoutEngine.beams` and `LayoutEngine.tupletBeams` are
  /// `Map<Note, BeamType>`, and `BeamGrouper.groupElementsForBeaming` returns
  /// runs of `Note` only, so a `Chord` never appears in either map. The
  /// author's [Chord.beam] hint is therefore the whole of what is knowable at
  /// this layer, and reading it is not a stale read - it is the only read.
  ///
  /// One case is now under-reported: since `TupletBeamPlan` learned to beam a
  /// bare `Chord` automatically (M-38), a chord inside a tuplet can be DRAWN
  /// beamed while carrying no hint. Closing that needs the engine to publish a
  /// chord-keyed beam map. The cost meanwhile is bounded - one flag's overhang
  /// of extra height on the selection box of a chord inside a tuplet - and it
  /// never loses a hit, because the box comes out too LARGE, never too small.
  bool _chordIsBeamed(Chord chord) => chord.beam != null;

  /// Horizontal reach of a note or chord: the accidental hangs to the LEFT of
  /// the origin, the notehead and its dots to the right.
  ({double left, double right}) _horizontalSpan(
    MusicalElement element,
    double x,
  ) {
    final air = staffSpace * 0.2;
    final total = engine?.elementWidth(element) ?? staffSpace * 1.2;
    final left = engine?.elementLeftExtent(element) ?? 0.0;
    return (left: x - left - air, right: x + (total - left) + air);
  }

  /// Stem direction under Behind Bars' rule: the note furthest from the middle
  /// line decides, and the middle line itself takes a downward stem.
  bool _stemPointsUp(List<Note> notes) {
    final positions = engine?.noteStaffPositions;
    if (positions == null) return true;
    var furthest = 0;
    var seen = false;
    for (final note in notes) {
      final p = positions[note];
      if (p == null) continue;
      if (!seen || p.abs() > furthest.abs()) {
        furthest = p;
        seen = true;
      }
    }
    return seen ? furthest < 0 : true;
  }

  /// Staff positions of [notes], in the order the renderers sort them
  /// (highest first), skipping any note the layout registered no position for.
  List<int> _staffPositionsOf(List<Note> notes) {
    final map = engine?.noteStaffPositions;
    if (map == null) return const <int>[];
    final positions = <int>[
      for (final note in notes)
        if (map[note] != null) map[note]!,
    ];
    positions.sort((a, b) => b.compareTo(a));
    return positions;
  }

  /// Beams a duration carries, mirroring `NoteRenderer._getBeamCount` and
  /// `ChordRenderer._getBeamCount` exactly — including the fact that both stop
  /// at the 64th, so anything shorter is treated as beamless by the renderer
  /// and therefore gets no per-beam stem extension here either.
  static int _beamCount(DurationType duration) => switch (duration) {
        DurationType.eighth => 1,
        DurationType.sixteenth => 2,
        DurationType.thirtySecond => 3,
        DurationType.sixtyFourth => 4,
        _ => 0,
      };

  /// How far, in pixels, the drawn stem reaches past the notehead it attaches
  /// to.
  ///
  /// This is the fix for M-14. The reach used to be the constant 3.5 staff
  /// spaces of Behind Bars p.13, but the renderer does not draw that: it calls
  /// [SMuFLPositioningEngine.calculateStemLength], which EXTENDS the stem until
  /// it reaches the middle line (Behind Bars p.47), and it starts the stem at
  /// the SMuFL stem anchor of the notehead rather than at its centre. MEASURED
  /// at staffSpace 12, treble, quarter notes, beamCount 0, before this change:
  ///
  /// ```text
  /// staffPos  drawn stem   tip y    old box top   tip OUTSIDE the box by
  ///   -20     10.000 SS    57.98      138.00            80.02 px
  ///   -12      6.000 SS    57.98       90.00            32.02 px
  ///    -6      3.500 SS    51.98       54.00             2.02 px
  /// ```
  ///
  /// — the last row being the residual `att.dy` = 2.016 px that the box missed
  /// even in the completely ordinary case, so `hitTest` at the stem tip of a
  /// plain C4 quarter note returned null.
  ///
  /// A chord goes through [SMuFLPositioningEngine.calculateChordStemLength],
  /// which spans the chord and adds the standard length on top. It used to be
  /// clamped at 6.0 staff spaces, which is why the chord box (derived from the
  /// notehead span) accidentally contained the tip; with the clamp gone a
  /// 28-half-position chord draws a 17.5 SS stem and the old box missed it.
  ///
  /// [_flagReachSpaces] stays as an ADDITION beyond the computed length.
  ///
  /// One case is still an approximation and is left so knowingly: a BEAMED note
  /// has its stem drawn by the beam renderer, up to the beam line, which the
  /// beam's own slant can place well above the standard length. `isBeamed` is
  /// deliberately left at its default here so the note keeps the per-beam
  /// extension, which makes the box the LONGER of the two models rather than
  /// the shorter one.
  ///
  /// Fallback, when no layout engine (or no metadata) was supplied: the
  /// standard 3.5 staff spaces plus [_fallbackStemAttachmentSpaces]. That is
  /// deliberately weaker — without the engine there are no staff positions to
  /// feed the middle-line rule with, so a note far outside the staff will still
  /// grow a stem past the box. Callers that need exact picking must pass the
  /// engine.
  double _stemReachPx({
    required String noteheadGlyph,
    required bool stemUp,
    required List<int> staffPositions,
    required DurationType duration,
    required bool isChord,
  }) {
    final flag = duration.needsFlag ? _flagReachSpaces : 0.0;
    final positioning = _positioning;
    if (positioning == null || staffPositions.isEmpty) {
      return staffSpace *
          (_stemLengthSpaces + _fallbackStemAttachmentSpaces + flag);
    }

    final beamCount = _beamCount(duration);
    final lengthSpaces = isChord
        ? positioning.calculateChordStemLength(
            noteStaffPositions: staffPositions,
            stemUp: stemUp,
            beamCount: beamCount,
          )
        : positioning.calculateStemLength(
            staffPosition: staffPositions.first,
            stemUp: stemUp,
            beamCount: beamCount,
          );

    // The stem does not start at the notehead centre but at the SMuFL
    // `stemUpSE` / `stemDownNW` anchor, which always sits on the OUTWARD side
    // of the notehead, so its magnitude adds to the reach in both directions.
    final attachment = positioning
        .calculateStemAttachmentOffset(
          noteheadGlyphName: noteheadGlyph,
          stemUp: stemUp,
          staffSpace: staffSpace,
        )
        .dy
        .abs();

    return lengthSpaces * staffSpace + attachment + staffSpace * flag;
  }

  ({double top, double bottom}) _verticalSpan({
    required double highestNoteY,
    required double lowestNoteY,
    required bool stemUp,
    required DurationType duration,
    required double stemReachPx,
  }) {
    var top = highestNoteY - staffSpace * _noteheadHalfSpaces;
    var bottom = lowestNoteY + staffSpace * _noteheadHalfSpaces;

    // A whole note, breve, longa or maxima carries no stem.
    if (!duration.needsStem) return (top: top, bottom: bottom);

    // The stem hangs off the notehead NEAREST the stem side, which for a chord
    // is the LOWEST note when the stem points up and the HIGHEST when it points
    // down (`ChordRenderer`: `stemNoteIndex = stemUp ? positions.length - 1 :
    // 0` over a list sorted highest-first). `calculateChordStemLength` already
    // contains the chord span, so measuring from that notehead — not from the
    // far one — is what makes the two agree.
    // The same 0.2 staff spaces of air the box already carries horizontally.
    // It is not cosmetic here: the reach is assembled as
    // `length * staffSpace + attachment` while the renderer computes
    // `(noteY + attachment) -+ length * staffSpace`, and the two orders of
    // operations disagree in the last bit of a double. MEASURED, staff position
    // -6 at staffSpace 12: box top 51.98400000000001 against a drawn tip of
    // 51.98399999999999, so a click exactly on the tip missed by 2e-14 px while
    // the identical case at staff position -20 hit. Air makes the boundary a
    // question of geometry rather than of rounding.
    final air = staffSpace * 0.2;
    if (stemUp) {
      final stemTop = lowestNoteY - stemReachPx - air;
      if (stemTop < top) top = stemTop;
    } else {
      final stemBottom = highestNoteY + stemReachPx + air;
      if (stemBottom > bottom) bottom = stemBottom;
    }
    return (top: top, bottom: bottom);
  }

  /// Widens [box] to cover the two things that are drawn OUTSIDE the notehead's
  /// horizontal advance: the flag and the ledger lines.
  ///
  /// The forensic audit's N-19 named both and measured neither. MEASURED at
  /// staffSpace 12, treble, before this change:
  ///
  /// * lone eighth note on C4 — the stem sits 13.44 px right of the note origin
  ///   and `flag8thUp` is 12.67 px wide from there, so the flag occupies
  ///   x 95.32 .. 107.99 while the box ended at x 99.20. A click anywhere on
  ///   the outer two thirds of the flag returned null;
  /// * C6 and A3 quarter notes — the ledger lines run 23.76 px wide
  ///   (notehead 14.16 px + 2 x `legerLineExtension` 4.80 px) centred on the
  ///   notehead, i.e. 2.43 px past each side of the box. A click on either END
  ///   of a ledger line returned null; the middle worked.
  ///
  /// Nothing is added vertically: the ledger lines always lie BETWEEN the staff
  /// and the notehead, and the flag hangs back along the stem, so the vertical
  /// span computed from the stem already covers both.
  Rect _withGlyphOverhang(
    Rect box, {
    required double x,
    required String noteheadGlyph,
    required bool stemUp,
    required List<int> staffPositions,
    required DurationType duration,
    required bool beamed,
    required bool isChord,
  }) {
    final air = staffSpace * 0.2;
    var left = box.left;
    var right = box.right;

    final metadata = engine?.metadata;
    final bbox = metadata?.getGlyphInfo(noteheadGlyph)?.boundingBox;
    final headLeftSpaces = bbox?.bBoxSwX ?? 0.0;
    final headRightSpaces = bbox?.bBoxNeX ?? _fallbackNoteheadWidthSpaces;
    final headWidthPx = (headRightSpaces - headLeftSpaces) * staffSpace;
    final headCentrePx = ((headLeftSpaces + headRightSpaces) / 2) * staffSpace;

    if (staffPositions.any(StaffPositionCalculator.needsLedgerLines)) {
      final extension = (metadata?.getEngravingDefault(
                'legerLineExtension',
                _fallbackLegerLineExtensionSpaces,
              ) ??
              _fallbackLegerLineExtensionSpaces) *
          staffSpace;
      final half = headWidthPx / 2 + extension;
      // A chord containing a second displaces one notehead column by
      // `noteheadWidth * 1.04` (right for stem up, left for stem down), and its
      // ledger lines travel with it.
      final cluster = isChord && _hasSecond(staffPositions)
          ? headWidthPx * _clusterShiftFactor * (stemUp ? 1.0 : -1.0)
          : 0.0;
      final centres = <double>[x + headCentrePx, x + headCentrePx + cluster];
      for (final centre in centres) {
        if (centre - half - air < left) left = centre - half - air;
        if (centre + half + air > right) right = centre + half + air;
      }
    }

    final flagGlyph = _flagGlyph(duration, stemUp);
    if (flagGlyph != null && !beamed) {
      final positioning = _positioning;
      final flagBox = metadata?.getGlyphInfo(flagGlyph)?.boundingBox;
      if (positioning != null && flagBox != null) {
        // Reproduces `FlagRenderer.render`: the glyph is drawn at the stem end
        // shifted back by its own stem anchor and half the stem thickness.
        final stemX = x +
            positioning
                .calculateStemAttachmentOffset(
                  noteheadGlyphName: noteheadGlyph,
                  stemUp: stemUp,
                  staffSpace: staffSpace,
                )
                .dx;
        final anchor = positioning.getFlagAnchor(flagGlyph);
        final flagX = stemX -
            anchor.dx * staffSpace -
            (positioning.stemThickness / 2) * staffSpace;
        final flagLeft = flagX + flagBox.bBoxSwX * staffSpace - air;
        final flagRight = flagX + flagBox.bBoxNeX * staffSpace + air;
        if (flagLeft < left) left = flagLeft;
        if (flagRight > right) right = flagRight;
      }
    }

    if (left == box.left && right == box.right) return box;
    return Rect.fromLTRB(left, box.top, right, box.bottom);
  }

  /// True when any two of [staffPositions] (sorted highest-first) are a second
  /// apart, which is what triggers the notehead-column shift in a chord.
  static bool _hasSecond(List<int> staffPositions) {
    for (var i = 0; i + 1 < staffPositions.length; i++) {
      if ((staffPositions[i] - staffPositions[i + 1]).abs() <= 1) return true;
    }
    return false;
  }

  /// The flag glyph the renderer would draw, mirroring
  /// `FlagRenderer._getFlagGlyph` — which stops at the 64th, so shorter
  /// durations draw no flag at all and get no horizontal allowance here.
  static String? _flagGlyph(DurationType duration, bool stemUp) =>
      switch (duration) {
        DurationType.eighth => stemUp ? 'flag8thUp' : 'flag8thDown',
        DurationType.sixteenth => stemUp ? 'flag16thUp' : 'flag16thDown',
        DurationType.thirtySecond => stemUp ? 'flag32ndUp' : 'flag32ndDown',
        DurationType.sixtyFourth => stemUp ? 'flag64thUp' : 'flag64thDown',
        _ => null,
      };

  /// Nearest element to [point], or null when nothing is within [tolerance]
  /// (in pixels) of it.
  ///
  /// Notes and chords win ties against staff furniture at the same distance,
  /// which is what a user pointing at a chord expects.
  ScoreHit? hitTest(Offset point, {double tolerance = 0.0}) {
    ScoreHit? best;
    for (final positioned in elements) {
      final rect = boundsOf(positioned);
      final d = _distanceTo(rect, point);
      if (d > tolerance) continue;
      final hit = _hitFrom(positioned, rect, d);
      if (best == null ||
          d < best.distance ||
          (d == best.distance && _rank(hit) > _rank(best))) {
        best = hit;
      }
    }
    return best;
  }

  /// Every element whose box intersects [rect] — a marquee selection.
  List<ScoreHit> elementsInRect(Rect rect) {
    final result = <ScoreHit>[];
    for (final positioned in elements) {
      final bounds = boundsOf(positioned);
      if (bounds.overlaps(rect)) {
        result.add(_hitFrom(positioned, bounds, 0));
      }
    }
    return result;
  }

  /// Everything in one measure.
  List<ScoreHit> selectMeasure(int measureIndex) => _select(
      (p) => p.measureIndex == measureIndex);

  /// Everything on one wrapped system.
  List<ScoreHit> selectSystem(int system) => _select((p) => p.system == system);

  /// Everything belonging to one voice (null-voiced elements count as voice 1).
  List<ScoreHit> selectVoice(int voiceNumber) =>
      _select((p) => (p.voiceNumber ?? 1) == voiceNumber);

  /// Everything sounding in `[startOnset, endOnset)`, in whole notes.
  List<ScoreHit> selectTimeRange(double startOnset, double endOnset) =>
      _select((p) => p.onset >= startOnset - 1e-9 && p.onset < endOnset - 1e-9);

  /// Musical position under [point]: which bar, and how far into the piece.
  ///
  /// Returns null when the point is nowhere near the music. Use it to place a
  /// caret, or to start playback from where the user clicked.
  ({int measureIndex, double onset})? timeAt(Offset point) {
    final hit = hitTest(point, tolerance: staffSpace * 4);
    if (hit == null) return null;
    return (measureIndex: hit.measureIndex, onset: hit.onset);
  }

  /// Builds a [ScoreSelection] from a drag rectangle, ready to be highlighted
  /// or played back on its own.
  ScoreSelection selectionFromRect(Rect rect) {
    final hits = elementsInRect(rect);
    if (hits.isEmpty) {
      return const ScoreSelection(
        hits: [],
        startOnset: 0,
        endOnset: 0,
        firstMeasure: -1,
        lastMeasure: -1,
      );
    }
    var minOnset = double.infinity;
    var maxOnset = double.negativeInfinity;
    var firstMeasure = 1 << 30;
    var lastMeasure = -1;
    for (final h in hits) {
      if (h.onset < minOnset) minOnset = h.onset;
      if (h.onset > maxOnset) maxOnset = h.onset;
      if (h.measureIndex >= 0) {
        if (h.measureIndex < firstMeasure) firstMeasure = h.measureIndex;
        if (h.measureIndex > lastMeasure) lastMeasure = h.measureIndex;
      }
    }
    return ScoreSelection(
      hits: hits,
      startOnset: minOnset,
      endOnset: maxOnset,
      firstMeasure: firstMeasure == 1 << 30 ? -1 : firstMeasure,
      lastMeasure: lastMeasure,
    );
  }

  List<ScoreHit> _select(bool Function(PositionedElement) test) {
    final result = <ScoreHit>[];
    for (final positioned in elements) {
      if (!test(positioned)) continue;
      result.add(_hitFrom(positioned, boundsOf(positioned), 0));
    }
    return result;
  }

  ScoreHit _hitFrom(PositionedElement positioned, Rect bounds, double d) =>
      ScoreHit(
        element: positioned.element,
        position: positioned.position,
        bounds: bounds,
        system: positioned.system,
        measureIndex: positioned.measureIndex,
        voiceNumber: positioned.voiceNumber,
        onset: positioned.onset,
        distance: d,
      );

  static int _rank(ScoreHit hit) {
    final e = hit.element;
    if (e is Note || e is Chord) return 3;
    if (e is Rest) return 2;
    if (e is Tuplet) return 2;
    return 1;
  }

  static double _distanceTo(Rect rect, Offset point) {
    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : (point.dx > rect.right ? point.dx - rect.right : 0.0);
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : (point.dy > rect.bottom ? point.dy - rect.bottom : 0.0);
    if (dx == 0 && dy == 0) return 0;
    return dx > dy ? dx : dy;
  }
}
