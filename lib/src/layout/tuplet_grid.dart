// lib/src/layout/tuplet_grid.dart

import 'dart:math' as math;

import '../../core/core.dart';

/// How much space an element reserves to the LEFT of its own origin, in pixels.
///
/// Supplied by the caller because the answer depends on the SMuFL metadata AND
/// on the resolved [AccidentalDisplay] of the note — neither of which this
/// file has, and neither of which may be re-derived here: `LayoutEngine`
/// already owns that computation (`LayoutEngine.elementLeftExtent`) and a
/// second implementation is exactly the layout/renderer divergence this class
/// exists to remove.
typedef TupletLeftExtent = double Function(MusicalElement element);

/// Horizontal placement of the children of a [Tuplet], as offsets in pixels
/// from the tuplet's own origin.
///
/// Why this exists
/// ---------------
/// A tuplet used to be laid out on a FLAT grid of `2.5` staff spaces per child,
/// in two independent places: `LayoutEngine._registerTupletNotes` (which fed
/// the position maps, beams and hit-testing) and `TupletRenderer` (which drew).
/// Two implementations of one geometry is the shape of finding F-12, and the
/// geometry itself was wrong: measured, a quarter and an eighth inside the same
/// triplet both received exactly 30.00 px, and so did an eighth followed by two
/// sixteenths. Inside a tuplet the notes still have relative durations, and a
/// quarter-plus-eighth triplet is one of the most common figures in the
/// repertoire.
///
/// The offsets are now duration-proportional and BOTH callers read them from
/// here.
///
/// The law is deliberately FIXED to Gould's square root rather than delegating
/// to the configured `SpacingModel`. The renderer has no spacing engine, so a
/// delegating grid would compute one curve in the layout and another in the
/// renderer for any app that selected a non-default model — which is the very
/// divergence this class exists to remove. Tuplet-internal spacing is therefore
/// model-independent by construction; the tuplet's placement in the outer flow
/// still follows the configured model.
///
/// The trade-off that buys, stated plainly
/// ---------------------------------------
/// An app that selects a non-default `SpacingModel` gets it EVERYWHERE EXCEPT
/// INSIDE A TUPLET. Measured on the same figure across all four models
/// (`squareRoot` / `logarithmic` / `linear` / `exponential`): the X positions of
/// the tuplet's children were identical in all four, while the same durations
/// written as plain notes moved by ratios of 1.250 / 1.137 / 1.027 / 1.278
/// against each other. So the setting is not partially honoured inside a
/// tuplet — it is not honoured at all, by design. Whoever changes that has to
/// give `TupletRenderer` a spacing engine first, or the two callers diverge
/// again.
///
/// Two corrections sit on top of the raw law, and they are deliberately
/// different in kind (see [slotWidths]):
///
/// * the **legibility floor** is a CONTEXT SCALE, because a slot that is too
///   narrow is a property of the surrounding music's density, and clamping it
///   per child — or scaling it per group — destroys the very proportion the law
///   exists to show. It used to be a per-GROUP scale, which fixed the ratios
///   inside one bracket and flattened the ratios between two brackets in the
///   same bar (findings M-08 / M-31, measured in [TupletGrid.smallestRawLeafSpaces]);
/// * the **accidental clearance** is a PER-SLOT FLOOR, because an accidental is
///   local ink in front of one notehead — which is exactly how the main flow
///   treats it in `LayoutEngine._minimumInterNoteGap`.
class TupletGrid {
  /// Minimum slot width, in staff spaces, for the NARROWEST child of a group.
  ///
  /// Raised from 1.4 to 1.9 together with the switch from per-child clamping to
  /// the group scale in [slotWidths]. Both halves of that change are needed and
  /// neither works alone:
  ///
  /// * 1.4 was measured to be illegible. At `staffSpace = 12` on the corpus
  ///   case `m04m_tuplet_ratio` (5:4, five stepwise sixteenths) every step came
  ///   out at 16.800 px, and the real ink gap between adjacent noteheads was
  ///   **2 px = 0.167 staff spaces**. The package's own
  ///   `SpacingPreferences.normal.minGap` is 0.25 staff spaces, so the floor
  ///   violated the library's own minimum. A `noteheadBlack` is 1.18 staff
  ///   spaces wide, so 1.4 leaves 0.22 staff spaces of nominal slack and the
  ///   glyph's own side bearings eat most of that.
  /// * raising the floor while still clamping PER CHILD would have made things
  ///   worse, not better: the raw eighth slot is 1.7678 staff spaces, so any
  ///   per-child floor at or above 1.75 makes an eighth and a sixteenth
  ///   identical. Measured on the old code, ten of the fifteen `DurationType`s
  ///   (sixteenth through 1/2048) all received exactly 1.4 — the "proportional"
  ///   grid was flat over two thirds of its domain.
  ///
  /// The number itself: 1.18 staff spaces of `noteheadBlack` advance + 0.72 of
  /// optical clearance. 1.43 (`1.18 + 0.25`) is the ABSOLUTE minimum that
  /// merely respects `SpacingPreferences.normal.minGap`; it is not a spacing a
  /// player can read at speed. 1.9 puts 0.72 staff spaces of white between
  /// adjacent noteheads — measured on the rasterised `m04m_tuplet_ratio` at
  /// `staffSpace = 12`, the real ink gap goes from 2 px to **9 px**
  /// (0.750 staff spaces), three times `SpacingPreferences.normal.minGap`.
  /// The 9 px is the gap on the WIDEST notehead row (13–14 px of black ink);
  /// the nominal 0.72 staff spaces = 8.64 px is what the slot arithmetic
  /// reserves, and the extra fraction is the glyph's own side bearing.
  static const double minimumSlotSpaces = 1.9;

  /// Slot width, in staff spaces, of a child whose duration is a quarter note.
  ///
  /// Kept equal to the historical flat grid so a triplet of equal quarters is
  /// laid out exactly as before and the corpus goldens that contain one do not
  /// move for no reason.
  static const double quarterSlotSpaces = 2.5;

  /// Advance width of a black notehead in staff spaces, used when the caller
  /// supplies no metadata-derived value. Bravura's `noteheadBlack` measures
  /// 1.18; every SMuFL font is within a few percent of that.
  static const double defaultNoteheadAdvanceSpaces = 1.18;

  /// Air between the previous notehead's right edge and the next child's ink,
  /// in staff spaces. Equal to `SpacingPreferences.normal.minGap`, so the
  /// tuplet honours the same minimum the rest of the package does.
  static const double slotAirSpaces = 0.25;

  /// Per-child slot widths in pixels, `length == tuplet.elements.length`.
  ///
  /// This is the single geometry both `LayoutEngine` and `TupletRenderer` walk.
  /// It cannot be expressed as an independent per-child function, which is why
  /// the old `slotWidth(child, staffSpace)` is gone: two of the three
  /// corrections below need to see the whole group.
  ///
  /// 1. **Raw law.** `quarterSlotSpaces * sqrt(duration / quarter)`.
  /// 2. **Context scale.** The smallest raw LEAF slot is found first — over the
  ///    caller's whole context when [contextSmallestLeafSpaces] is supplied,
  ///    over this group alone when it is not. If it falls under
  ///    [minimumSlotSpaces], EVERY slot is multiplied by the single factor
  ///    `minimumSlotSpaces / smallestRaw`. The exact 1.4142 eighth : sixteenth
  ///    ratio survives untouched, which per-child clamping destroyed — and,
  ///    with a context, it survives BETWEEN groups as well, which a per-group
  ///    scale destroyed.
  /// 3. **Accidental clearance.** Slot `i` carries the distance from child `i`
  ///    to child `i + 1`, so it must also cover whatever child `i + 1` draws to
  ///    its LEFT. Measured at `staffSpace = 12` against a 14.16 px notehead
  ///    before this existed, the clearance between the accidental and the
  ///    previous notehead was `-20.78 px` (double flat), `-12.96` (double
  ///    sharp), `-11.81` (flat) and `-12.91` (sharp): the accidental was drawn
  ///    entirely on top of the previous note. The main flow has enforced this
  ///    since `LayoutEngine._minimumInterNoteGap`; inside the grid it simply
  ///    did not exist.
  ///
  /// [leftExtent] is optional only so a caller with no layout engine (a bare
  /// `TupletRenderer` in a test, say) still gets geometry; when it is null the
  /// grid is not accidental-aware and matches step 2 alone.
  ///
  /// A nested [Tuplet] contributes its OWN total width as one slot and is NOT
  /// multiplied by the parent's group scale: its children are placed by a
  /// recursive call that knows nothing of the parent's factor, so scaling the
  /// slot here would make the parent's advance disagree with the inner group's
  /// own geometry. The recursion does pass [contextSmallestLeafSpaces] down, so
  /// an inner group scales by the same factor as its parent.
  ///
  /// [contextSmallestLeafSpaces] widens step 2 from THIS group to a whole
  /// context — see [smallestRawLeafSpaces] for what it is and why the group
  /// alone is the wrong denominator.
  static List<double> slotWidths(
    Tuplet tuplet,
    double staffSpace, {
    TupletLeftExtent? leftExtent,
    double noteheadAdvanceSpaces = defaultNoteheadAdvanceSpaces,
    double? contextSmallestLeafSpaces,
  }) {
    final elements = tuplet.elements;
    if (elements.isEmpty) return const <double>[];

    // Step 1: the raw law, in staff spaces, plus the smallest raw LEAF slot.
    // Nested tuplets are excluded from the minimum: they already carry their
    // own floor from their own recursive call, and their total is a sum, so
    // letting one participate would scale the parent by a number that has
    // nothing to do with how dense the parent's own children are.
    final raw = List<double>.filled(elements.length, 0.0);
    final isNested = List<bool>.filled(elements.length, false);
    var smallestLeaf = double.infinity;

    for (var i = 0; i < elements.length; i++) {
      final child = elements[i];
      if (child is Tuplet) {
        isNested[i] = true;
        final inner = slotWidths(
          child,
          staffSpace,
          leftExtent: leftExtent,
          noteheadAdvanceSpaces: noteheadAdvanceSpaces,
          contextSmallestLeafSpaces: contextSmallestLeafSpaces,
        );
        final total = inner.fold<double>(0.0, (a, b) => a + b) / staffSpace;
        raw[i] = total == 0 ? minimumSlotSpaces : total;
        continue;
      }
      final duration = _durationOf(child);
      raw[i] = duration == null
          ? quarterSlotSpaces
          : quarterSlotSpaces * _squareRootFactor(duration);
      if (raw[i] < smallestLeaf) smallestLeaf = raw[i];
    }

    // Step 2: one scale factor for the whole CONTEXT (the measure, when the
    // caller supplied one) — not for this group alone. See
    // [smallestRawLeafSpaces].
    final denominator = contextSmallestLeafSpaces ?? smallestLeaf;
    final scale = denominator.isFinite &&
            denominator > 0 &&
            denominator < minimumSlotSpaces
        ? minimumSlotSpaces / denominator
        : 1.0;

    final result = List<double>.filled(elements.length, 0.0);
    for (var i = 0; i < elements.length; i++) {
      var spaces = isNested[i] ? raw[i] : raw[i] * scale;

      // Step 3: the slot has to clear the NEXT child's leading ink.
      if (leftExtent != null && i + 1 < elements.length) {
        final ahead = leftExtent(elements[i + 1]) / staffSpace;
        final needed = ahead + noteheadAdvanceSpaces + slotAirSpaces;
        if (spaces < needed) spaces = needed;
      }

      result[i] = spaces * staffSpace;
    }
    return result;
  }

  /// The smallest RAW slot, in staff spaces, of any leaf under [tuplet] —
  /// nested groups included, because a nested group's own children are leaves
  /// too.
  ///
  /// This is the denominator of the legibility scale of [slotWidths] step 2,
  /// exposed so a caller that can see MORE THAN ONE tuplet can compute it over
  /// all of them and hand the same number back through
  /// `slotWidths(contextSmallestLeafSpaces: …)`.
  ///
  /// Why the group alone is the wrong denominator (findings M-08 / M-31)
  /// -------------------------------------------------------------------
  /// The floor is a LEGIBILITY constraint on adjacent noteheads and it is
  /// genuinely needed: at the old 1.4 the corpus case `m04m_tuplet_ratio` left
  /// 2 px = 0.167 staff spaces of white between heads, under the package's own
  /// `SpacingPreferences.normal.minGap` of 0.25. But a floor is by definition
  /// non-linear, so WHERE it is applied decides what proportion survives it.
  ///
  /// Applied per group, it destroys the proportion BETWEEN groups. Measured at
  /// `staffSpace = 12` on one 4/4 bar holding a 3:2 triplet of EIGHTHS and a
  /// 3:2 triplet of SIXTEENTHS:
  ///
  ///   group        | raw slot | own scale | slot BEFORE | slot AFTER
  ///   -------------+----------+-----------+-------------+------------
  ///   eighths      |   1.7678 |    1.0748 |   1.9000 SS |  2.6870 SS
  ///   sixteenths   |   1.2500 |    1.5200 |   1.9000 SS |  1.9000 SS
  ///   ratio        |   1.4142 |         — |   1.0000    |  1.4142
  ///
  /// Both groups were scaled up to the same floor, so the bar printed an eighth
  /// and a sixteenth at IDENTICAL width — the reader could not tell the two
  /// figures apart, which is the one thing proportional spacing exists to do.
  ///
  /// Two answers were considered.
  ///
  /// * **Per-slot floor** (`max(raw, minimumSlotSpaces)`), preserving ratios
  ///   above the floor. Rejected: it does not fix this case at all. Both raws
  ///   (1.7678 and 1.2500) are BELOW 1.9, so both clamp to 1.9 and the measured
  ///   ratio stays 1.0000. It also reintroduces the flattening that raising the
  ///   floor to 1.9 was meant to end — ten of the fifteen `DurationType`s land
  ///   under 1.9 and would all come out identical.
  /// * **One scale per context** — this. The scale is `minimumSlotSpaces` over
  ///   the smallest raw leaf ANYWHERE in the context, so the narrowest note in
  ///   the bar is the one placed exactly on the floor and every other slot
  ///   keeps its exact √2-per-halving relationship to it. The narrowest slot is
  ///   still 1.9000 SS, so the legibility guarantee is untouched: measured ink
  ///   gap between adjacent noteheads stays 9 px = 0.750 SS at
  ///   `staffSpace = 12`, three times `minGap`.
  ///
  /// The cost is stated plainly: a bar that contains one dense tuplet now makes
  /// every OTHER tuplet in that bar wider too. That is the correct engraving
  /// answer (Gould, Behind Bars p.85: relative duration must read across the
  /// whole bar, not only inside one bracket) and it is what a bar of ordinary
  /// notes already does — the main flow spaces the whole measure from one
  /// curve. It does mean an over-full bar can now trip the compression floor
  /// where it did not before; that case is reported through
  /// `LayoutEngine.warnings`.
  ///
  /// The context is chosen by the CALLER, not here: `LayoutEngine` computes it
  /// per MEASURE (the unit the reader compares within, and the unit the engine
  /// already justifies as a whole) and publishes it as
  /// `LayoutEngine.tupletContextFloor` so `TupletRenderer` draws with the same
  /// number instead of re-deriving one. A renderer driven with no engine passes
  /// nothing and gets the old per-group behaviour, which is still self
  /// consistent — it simply cannot see the neighbours.
  static double smallestRawLeafSpaces(Tuplet tuplet) {
    var smallest = double.infinity;
    void walk(Tuplet group) {
      for (final child in group.elements) {
        if (child is Tuplet) {
          walk(child);
          continue;
        }
        final duration = _durationOf(child);
        final raw = duration == null
            ? quarterSlotSpaces
            : quarterSlotSpaces * _squareRootFactor(duration);
        if (raw < smallest) smallest = raw;
      }
    }

    walk(tuplet);
    return smallest;
  }

  /// Offsets, in pixels from the tuplet origin, of each direct child of
  /// [tuplet] — plus a final entry holding the tuplet's total width.
  ///
  /// `offsets.length == tuplet.elements.length + 1`.
  static List<double> offsets(
    Tuplet tuplet,
    double staffSpace, {
    TupletLeftExtent? leftExtent,
    double noteheadAdvanceSpaces = defaultNoteheadAdvanceSpaces,
    double? contextSmallestLeafSpaces,
  }) {
    final result = <double>[0.0];
    var x = 0.0;
    for (final slot in slotWidths(
      tuplet,
      staffSpace,
      leftExtent: leftExtent,
      noteheadAdvanceSpaces: noteheadAdvanceSpaces,
      contextSmallestLeafSpaces: contextSmallestLeafSpaces,
    )) {
      x += slot;
      result.add(x);
    }
    return result;
  }

  /// Total width of [tuplet] in pixels.
  static double totalWidth(
    Tuplet tuplet,
    double staffSpace, {
    TupletLeftExtent? leftExtent,
    double noteheadAdvanceSpaces = defaultNoteheadAdvanceSpaces,
    double? contextSmallestLeafSpaces,
  }) =>
      offsets(
        tuplet,
        staffSpace,
        leftExtent: leftExtent,
        noteheadAdvanceSpaces: noteheadAdvanceSpaces,
        contextSmallestLeafSpaces: contextSmallestLeafSpaces,
      ).last;

  static Duration? _durationOf(MusicalElement element) {
    if (element is Note) return element.duration;
    if (element is Rest) return element.duration;
    if (element is Chord) return element.duration;
    return null;
  }

  /// Gould's square-root law, normalised to the quarter note.
  ///
  /// Same LAW as `SpacingModel.squareRoot` — `sqrt(t)` with
  /// `t = duration / quarter`, the package default — but NOT the same resulting
  /// widths, which an earlier version of this comment claimed. The two apply
  /// different normalisation and different corrections:
  ///
  /// - Normalisation. `SpacingCalculator` multiplies the shape by its
  ///   `spacingRatio`, which defaults to `1.5`; this function does not. Measured
  ///   on a half note: the package's own calculator returns **2.1213** where
  ///   this returns **1.4142** (quarter: 1.5000 vs 1.0000, eighth: 1.0607 vs
  ///   0.7071). The ratio is a constant 1.5, so the *proportions* between
  ///   children still agree — only the absolute scale differs, and the tuplet's
  ///   absolute scale is set by [quarterSlotSpaces] instead.
  /// - Corrections. The group scale of [slotWidths] moves the whole curve, so
  ///   unlike the old per-child floor it does NOT change its shape: a tuplet of
  ///   sixteenths is 1.52x wider than the bare law asks for, and so is every
  ///   other slot in it.
  ///
  /// Read this as "the same curve, differently scaled", never as "the same
  /// numbers".
  static double _squareRootFactor(Duration duration) {
    final absolute = duration.absoluteValue;
    if (absolute <= 0) return 1.0;
    return math.sqrt(absolute / DurationType.quarter.value);
  }
}

/// Which children of a tuplet are beamed together, and how.
///
/// Why this is a value and not a mutation
/// --------------------------------------
/// `TupletRenderer._applyAutomaticBeams` used to write [Note.beam] **in place**
/// during `render`, so the PAINT pass mutated the model. Measured: a `Staff`
/// holding a triplet of eighths exported MusicXML of 1620 characters with 0
/// `<beam>` tags before any paint; after one `ScoreRasterizer.renderStaffToPng`
/// the same `Staff` exported 1735 characters with 3 `<beam>` tags. Whether a
/// document exported the same bytes therefore depended on whether it had been
/// displayed first. A second offence rode on the same line: the engine's own
/// beam collector reads `Note.beam`, so on a SECOND layout the tuplet's notes
/// would have been picked up by the advanced beam pass as well and drawn twice.
///
/// The decision is now a pure function of the elements. `LayoutEngine`
/// publishes the result (`LayoutEngine.tupletBeams`) and `TupletRenderer` reads
/// it; when a renderer has no engine it calls [of] itself. Both paths run this
/// one function, so they cannot diverge, and neither writes to the model.
class TupletBeamPlan {
  /// Beam membership per element of the tuplet, aligned with
  /// `Tuplet.elements`; `null` where the child carries no beam (a rest, a
  /// quarter, a nested tuplet, or a note in a run too short to beam).
  final List<BeamType?> beams;

  /// Highest beam level any beamed child needs (2 for sixteenths, 3 for
  /// thirty-seconds, ...), or 0 when nothing in the group is beamed. The
  /// bracket is stacked above this.
  final int beamCount;

  const TupletBeamPlan(this.beams, this.beamCount);

  static const TupletBeamPlan none = TupletBeamPlan(<BeamType?>[], 0);

  /// Number of beams a single duration needs.
  ///
  /// Complete over `DurationType` down to 1/2048. The old whitelist stopped at
  /// the sixty-fourth, so a tuplet of 128th notes — the ordinary way to write a
  /// fast ornamental run — silently lost its beams and printed nine loose
  /// flags (finding M-38).
  static int beamCountFor(DurationType durationType) {
    return switch (durationType) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      DurationType.oneHundredTwentyEighth => 5,
      DurationType.twoHundredFiftySixth => 6,
      DurationType.fiveHundredTwelfth => 7,
      DurationType.thousandTwentyFourth => 8,
      DurationType.twoThousandFortyEighth => 9,
      _ => 0,
    };
  }

  /// Whether [element] is a stem-carrying child that can join a beam.
  ///
  /// A [Chord] joins on exactly the same terms as a [Note]: it has a stem and a
  /// flagged duration, therefore it beams. This is the last open half of M-38.
  ///
  /// It was not always so. The guard used to read
  /// `element.beam != null && beamCountFor(...) > 0`, i.e. a chord joined only
  /// when its AUTHOR had hand-set [Chord.beam]. Two separate things made that
  /// the right call at the time and both have since been paid off:
  ///
  /// * `ChordRenderer` drew a flag whenever `Chord.beam` was null and the
  ///   duration was shorter than a quarter, so auto-beaming a bare chord would
  ///   have printed a beam AND a flag on the same stem. `ChordRenderer` now
  ///   takes `suppressStem` / `suppressFlag`, and `TupletRenderer` passes
  ///   `suppressStem: beam != null`, so the flag and the chord's own stem are
  ///   both stood down for a beamed chord;
  /// * a chord's stem does not start at its origin, so the beam pass had
  ///   nowhere to hang the line. `ChordRenderer.chordStemAnchor` now reports
  ///   the extreme notehead's x, near y and far y, and `_drawSimpleBeams` draws
  ///   the stem itself from that anchor up to the beam line.
  ///
  /// With both in place the condition became a leftover that could only say no.
  /// Measured on a 3:2 triplet of three eighth CHORDS (`[C4,E4,G4]`,
  /// `[D4,F4,A4]`, `[E4,G4,B4]`) at `staffSpace = 12`: with the old guard the
  /// plan returned `[null, null, null]` and `beamCount` 0, the renderer found
  /// zero participants, and the raster carried THREE separate flags and no
  /// beam. With the guard removed the plan returns
  /// `[start, inner, end]` / `beamCount` 1, one beam is drawn across the group
  /// and no flag is drawn at all.
  ///
  /// Reading [Chord.beam] here would in any case have been the same stale read
  /// ADR-005 is about: the engine publishes its beam decision as a value, so
  /// the field carries the author's hint only, and an ordinary chord written by
  /// a parser or by hand has none.
  static bool _carriesBeam(MusicalElement element) {
    if (element is Note) {
      return !element.isGraceNote && beamCountFor(element.duration.type) > 0;
    }
    if (element is Chord) {
      return beamCountFor(element.duration.type) > 0;
    }
    return false;
  }

  /// Decides beam membership for one tuplet's direct children.
  ///
  /// Rules, all of them changed from the old `_applyAutomaticBeams`:
  ///
  /// * a [Rest] is TRANSPARENT — it neither carries a beam nor breaks the run,
  ///   which is what Behind Bars p.30 prescribes for a rest inside a beamed
  ///   group. It used to abort beaming for the whole tuplet;
  /// * a [Chord] no longer aborts beaming either (see [_carriesBeam]);
  /// * every flagged duration down to 1/2048 beams, not just eighth..64th;
  /// * anything else (a quarter, a nested tuplet) ends the current run and
  ///   starts a new one, instead of cancelling the whole group.
  static TupletBeamPlan of(List<MusicalElement> elements) {
    if (elements.length < 2) return none;

    final beams = List<BeamType?>.filled(elements.length, null);
    var maxLevel = 0;

    // Indices of the current run of beamable stem carriers.
    //
    // A rest ENDS the run. It used to be treated as transparent, on the
    // reasoning that "the beam passes above it" — which is a real engraving
    // option, and was never implemented. The two eighths either side of a rest
    // were marked `BeamType.start` and `BeamType.end`, `NoteRenderer`
    // suppressed their stems and flags because a beamed note's stem belongs to
    // the beam, and the beam renderer then drew nothing across the gap.
    // Measured on a 3:2 triplet of [eighth, eighth rest, eighth]: two bare
    // noteheads, no stems, no beam, and a tuplet bracket left dangling under
    // them.
    //
    // Breaking the run also settles a disagreement inside this package. The
    // p.201 bracket rule is deliberately handed `Tuplet.elements` rather than
    // `Tuplet.notes` so that a rest KEEPS the bracket, on the reasoning that
    // nothing spans the group — the exact opposite of what this loop believed.
    // Now both agree: a rest breaks the beam, the notes carry their own flags,
    // and the bracket delimits the group. It also matches `BeamGrouper`, whose
    // own comment already says it treats "rests and non-beamable notes as real
    // boundaries".
    //
    // Beaming over a rest stays a legitimate future option. It needs the beam
    // renderer to span non-adjacent members and the bracket rule to agree; it
    // is not something to leave half-built in the meantime.
    final run = <int>[];

    void closeRun() {
      if (run.length >= 2) {
        for (var k = 0; k < run.length; k++) {
          beams[run[k]] = k == 0
              ? BeamType.start
              : (k == run.length - 1 ? BeamType.end : BeamType.inner);
          final level = beamCountFor(_durationTypeOf(elements[run[k]])!);
          if (level > maxLevel) maxLevel = level;
        }
      }
      run.clear();
    }

    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      if (element is Rest) {
        closeRun();
        continue;
      }
      if (_carriesBeam(element)) {
        run.add(i);
      } else {
        closeRun();
      }
    }
    closeRun();

    return TupletBeamPlan(beams, maxLevel);
  }

  static DurationType? _durationTypeOf(MusicalElement element) {
    if (element is Note) return element.duration.type;
    if (element is Chord) return element.duration.type;
    if (element is Rest) return element.duration.type;
    return null;
  }
}
