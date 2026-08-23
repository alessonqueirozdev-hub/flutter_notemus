import 'dart:math' as math;

import 'package:flutter/material.dart' show Offset;
import '../smufl/smufl_metadata_loader.dart';

/// Class responsible for calculating precise positions using SMuFL metadata
/// and professional music typography rules.
///
/// Based on:
/// - SMuFL specification (w3c.github.io/smufl)
/// - Bravura font metadata
/// - "Behind Bars" by Elaine Gould
/// - "The Art of Music Engraving" by Ted Ross
class SMuFLPositioningEngine {
  // REMOVED: stemUpXCorrection / stemDownXCorrection (old pixel-based constants).
  // The offset is now computed dynamically from stemThickness inside
  // calculateStemAttachmentOffset — see the explanation there.

  /// Standard stem length, in staff spaces.
  ///
  /// This value is deliberately a named constant and NOT read from
  /// `engravingDefaults`: the SMuFL specification defines 29 engraving default
  /// keys and none of them describes stem length, so any lookup of a
  /// `'stemLength'` key would always fall through to its fallback while
  /// pretending to be font-derived.
  ///
  /// Source: Elaine Gould, "Behind Bars", p. 13 — the standard stem length is
  /// one octave, i.e. 3.5 staff spaces.
  static const double kStandardStemLengthSpaces = 3.5;

  /// Absolute lower bound for a stem, in staff spaces.
  ///
  /// "Behind Bars", p. 13: stems of notes lying far outside the staff may be
  /// shortened, but never below 2.5 staff spaces.
  static const double kAbsoluteMinimumStemLengthSpaces = 2.5;

  /// Longest stem, in staff spaces, that a single-beam group may draw before
  /// the beam is re-sloped to bring it back.
  ///
  /// "Behind Bars", pp. 17-18: inside a beamed group the stems keep the
  /// standard length as far as the contour allows; a stem that grows far past
  /// it makes the group read as a leap with a rule through it rather than as a
  /// beamed figure. Gould works in the 4-5 staff-space range.
  ///
  /// The value is the longest stem that a group already resolved by Gould's
  /// own slant table can legitimately need, at the widest interval that table
  /// covers:
  ///
  /// ```text
  /// standard stem 3.5 + octave ambitus 3.5 - octave slant 1.5 = 5.5
  /// ```
  ///
  /// Half a staff space above Gould's stated 4-5 range, and deliberately so:
  /// [kBeamSlantByDiatonicStep] gives an octave leap a slant of 1.5 spaces,
  /// which MEASURES as an outer stem of exactly 5.50. A ceiling of 5.0 would
  /// contradict the slant table on the most ordinary wide leap there is. Past
  /// the octave the slant table saturates (every interval wider than an octave
  /// shares the 1.5 entry) while the stem keeps growing by half a space per
  /// diatonic step, and that is precisely where this ceiling takes over.
  ///
  /// MEASURED, outer stem of a two-eighth group against its ambitus, before
  /// any of this existed: 0 steps 3.50, 4 steps 4.50, 7 steps (octave) 5.50,
  /// 10 steps 7.00, 14 steps 9.00 staff spaces — the last one more than twice
  /// the height of the staff.
  static const double kMaximumBeamedStemLengthSpaces =
      kStandardStemLengthSpaces + 3.5 - 1.5;

  /// How much a beamed stem may be shortened below [kStandardStemLengthSpaces].
  ///
  /// Kept at zero: inside a beam group the beam itself already replaces the
  /// flag, so the classical full-octave stem is used as the target minimum.
  static const double kBeamedStemShorteningSpaces = 0.0;

  /// Fallback beam thickness in staff spaces, used when the loaded font does
  /// not publish `beamThickness` in its `engravingDefaults` (Bravura: 0.5).
  static const double kFallbackBeamThicknessSpaces = 0.5;

  /// Fallback beam spacing in staff spaces, used when the loaded font does not
  /// publish `beamSpacing` in its `engravingDefaults` (Bravura: 0.25).
  static const double kFallbackBeamSpacingSpaces = 0.25;

  // Reference to the metadata loader (required)
  final SmuflMetadata _metadataLoader;

  // Values loaded dynamically from SMuFL metadata
  // Previously were hardcoded static constants, now loaded from engravingDefaults
  late final double standardStemLength;
  late final double minimumStemLength;
  /// Extra stem length, in staff spaces, that each beam level BEYOND THE FIRST
  /// costs.
  ///
  /// Derived from the font: `beamThickness + beamSpacing` (Bravura:
  /// `0.5 + 0.25 = 0.75`). It was the literal
  /// `stemExtensionPerBeam = 0.5; // Calculated based on beamSpacing` — a
  /// comment describing a calculation that was never performed. 0.5 is
  /// `beamThickness` alone, so the gap BETWEEN the beams was never paid for
  /// and every level past the first ate 0.25 staff spaces of stem.
  ///
  /// Verified against the code that actually stacks the beams rather than
  /// against the prose: `BeamRenderer._calculateLevelOffset`
  /// (`beam_renderer.dart:176`) places level *n* at
  /// `(n - 1) * (beamThickness + beamGap)` below the primary, and
  /// `BeamRenderer.beamStackDepth` (`:301`) reports the total as
  /// `beamThickness + (beamCount - 1) * (beamThickness + beamGap)` — both
  /// reading the metadata since 2.7.1. The marginal cost of one more level is
  /// therefore `beamThickness + beamGap`, which is this number. Measured at
  /// `staffSpace = 12`: a 32nd (3 levels) used to add `2 * 0.5 = 1.00` staff
  /// space to the stem while its beam stack reached `2 * 0.75 = 1.50` below
  /// the primary — the innermost beam sat 0.50 staff spaces (6.00 px) past the
  /// end of the stem it was supposed to hang from.
  late final double stemExtensionPerBeam;
  late final double stemThickness;

  /// Beam thickness in staff spaces (`engravingDefaults.beamThickness`).
  late final double beamThickness;

  /// Vertical gap between two adjacent beams, in staff spaces
  /// (`engravingDefaults.beamSpacing`).
  late final double beamSpacing;

  // Accidental spacing
  late final double accidentalToNoteheadDistance;
  late final double accidentalMinimumClearance;

  // Beam angles
  late final double minimumBeamSlant;
  late final double maximumBeamSlant;
  late final double twoNoteBeamMaxSlant;

  // Ornaments and articulations
  late final double articulationToNoteDistance;
  late final double ornamentToNoteDistance;

  // Slurs and dynamics
  late final double slurEndpointThickness;
  late final double slurMidpointThickness;
  late final double slurHeightFactor;

  // Grace notes (appoggiaturas)
  late final double graceNoteScale;
  late final double graceNoteStemLength;

  // Tuplets
  late final double tupletBracketHeight;
  late final double tupletNumberDistance;

  // Constructor now REQUIRES metadata loader
  SMuFLPositioningEngine({required SmuflMetadata metadataLoader})
    : _metadataLoader = metadataLoader {
    // Load values from SMuFL metadata
    // Stem lengths are NOT part of engravingDefaults (see the dartdoc on
    // kStandardStemLengthSpaces): use the documented engraving constants.
    standardStemLength = kStandardStemLengthSpaces;
    minimumStemLength = kAbsoluteMinimumStemLengthSpaces;
    stemThickness = _loadEngravingDefault('stemThickness', 0.12);
    beamThickness = _loadEngravingDefault(
      'beamThickness',
      kFallbackBeamThicknessSpaces,
    );
    beamSpacing = _loadEngravingDefault(
      'beamSpacing',
      kFallbackBeamSpacingSpaces,
    );
    // DERIVED, not chosen: one more beam level pushes the beam stack down by
    // exactly one beam body plus one gap, so the stem has to grow by the same
    // amount. Assigned after [beamThickness]/[beamSpacing] because it reads
    // them.
    stemExtensionPerBeam = beamThickness + beamSpacing;

    // Spacing - Behind Bars recommends 0.16-0.25 SS of visual clearance.
    // Using 0.25 SS to ensure clear separation between the accidental and the notehead.
    accidentalToNoteheadDistance = 0.25;
    accidentalMinimumClearance = 0.12;

    // Beam slant - Behind Bars pp.19-25, via [kBeamSlantByDiatonicStep].
    //
    // These three were tuned by eye against the package's own screenshots and
    // ended up encoding only the DIRECTION of the melodic line, not its size:
    // `maximumBeamSlant` was 0.5 ("was 1.0, too steep!") and `BeamAnalyzer`
    // clamped pairs to 0.25 to match "the stable beam showcase examples".
    // Measured: an ascending 2nd, an ascending 6th and a TWO-OCTAVE leap all
    // produced a slant of exactly 0.25 staff spaces. They are kept as the floor
    // and the ceiling of the real table.
    minimumBeamSlant = 0.25;
    maximumBeamSlant = 2.0;
    twoNoteBeamMaxSlant = 2.0;

    // Ornaments and articulations - standard typographic values
    articulationToNoteDistance = 0.5;
    ornamentToNoteDistance = 0.75;

    // Slurs - loaded from engravingDefaults
    slurEndpointThickness = _loadEngravingDefault('slurEndpointThickness', 0.1);
    slurMidpointThickness = _loadEngravingDefault('slurMidpointThickness', 0.22);
    slurHeightFactor = 0.25;

    // Grace notes
    graceNoteScale = 0.6;
    graceNoteStemLength = 2.5;

    // Tuplets
    tupletBracketHeight = 1.0;
    tupletNumberDistance = 0.5;
  }

  /// Loads a value from engravingDefaults with fallback.
  /// This method eliminates hardcoding by consulting the real metadata.
  double _loadEngravingDefault(String key, double fallback) {
    final value = _metadataLoader.getEngravingDefaultValue(key);
    return value ?? fallback;
  }

  // Method initialize() removed - no longer needed.
  // The metadata loader is now passed in the constructor and already loaded.

  /// Returns the stemUpSE anchor point for a notehead
  /// (lower right corner where the upward stem should connect)
  /// Returns coordinates in STAFF SPACES (SMuFL units)
  Offset getStemUpAnchor(String noteheadGlyphName) {
    // Always use metadata loader (now required)
    final anchor = _metadataLoader.getGlyphAnchor(
      noteheadGlyphName,
      'stemUpSE',
    );
    if (anchor != null) {
      return anchor; // Already in staff spaces
    }

    // Final fallback: default noteheadBlack from Bravura metadata
    // stemUpSE for noteheadBlack: [1.18, 0.168] per bravura_metadata.json
    return const Offset(1.18, 0.168);
  }

  /// Returns the stemDownNW anchor point for a notehead
  /// (upper left corner where the downward stem should connect)
  /// Returns coordinates in STAFF SPACES (SMuFL units)
  Offset getStemDownAnchor(String noteheadGlyphName) {
    // Always use metadata loader (now required)
    final anchor = _metadataLoader.getGlyphAnchor(
      noteheadGlyphName,
      'stemDownNW',
    );
    if (anchor != null) {
      return anchor; // Already in staff spaces
    }

    // Final fallback: default noteheadBlack from Bravura metadata
    // stemDownNW for noteheadBlack: [0.0, -0.168] per bravura_metadata.json
    return const Offset(0.0, -0.168);
  }

  /// Returns the notehead-to-stem attachment offset in pixels.
  ///
  /// The returned offset is relative to the notehead drawing origin used by the
  /// renderers in this package.
  Offset calculateStemAttachmentOffset({
    required String noteheadGlyphName,
    required bool stemUp,
    required double staffSpace,
  }) {
    final stemAnchor = stemUp
        ? getStemUpAnchor(noteheadGlyphName)
        : getStemDownAnchor(noteheadGlyphName);

    // SMuFL spec: stemUpSE gives the SE CORNER (right edge) of the stem
    // rectangle; stemDownNW gives the NW CORNER (left edge).
    // canvas.drawLine centres the strokeWidth on the coordinate, so we must
    // offset by half the stem thickness to make the visual edge land exactly
    // on the anchor position.
    //
    // stemUp  → shift LEFT  by halfThickness (right edge stays at anchor.x)
    // stemDown→ shift RIGHT by halfThickness (left edge stays at anchor.x)
    final halfStemSS = stemThickness / 2; // in staff spaces
    final xAdjust = stemUp ? -halfStemSS : halfStemSS;

    return Offset(
      (stemAnchor.dx + xAdjust) * staffSpace,
      -stemAnchor.dy * staffSpace, // invert Y for Flutter (Y+ down)
    );
  }

  double calculateStemX({
    required double noteX,
    required String noteheadGlyphName,
    required bool stemUp,
    required double staffSpace,
  }) {
    return noteX +
        calculateStemAttachmentOffset(
          noteheadGlyphName: noteheadGlyphName,
          stemUp: stemUp,
          staffSpace: staffSpace,
        ).dx;
  }

  double calculateStemStartY({
    required double noteY,
    required String noteheadGlyphName,
    required bool stemUp,
    required double staffSpace,
  }) {
    final attachmentOffset = calculateStemAttachmentOffset(
      noteheadGlyphName: noteheadGlyphName,
      stemUp: stemUp,
      staffSpace: staffSpace,
    );
    final overlapPx = (stemThickness * staffSpace) * 0.5;

    return noteY +
        attachmentOffset.dy +
        (stemUp ? overlapPx : -overlapPx);
  }

  /// Returns the anchor point for flags (eighth notes, sixteenth notes, etc.)
  /// Flags are registered with y=0 at the end of a standard stem length (3.5 spaces)
  /// Returns coordinates in STAFF SPACES (SMuFL units)
  Offset getFlagAnchor(String flagGlyphName) {
    String anchorName;

    // For upward flags, use stemUpNW
    if (flagGlyphName.contains('Up')) {
      anchorName = 'stemUpNW';
    }
    // For downward flags, use stemDownSW
    else if (flagGlyphName.contains('Down')) {
      anchorName = 'stemDownSW';
    } else {
      return Offset.zero;
    }

    // Always use metadata loader (now required)
    final anchor = _metadataLoader.getGlyphAnchor(flagGlyphName, anchorName);
    if (anchor != null) {
      return anchor; // Already in staff spaces
    }

    return Offset.zero;
  }

  /// Calculates the stem length based on the note's position in the staff
  /// and the number of beams
  double calculateStemLength({
    required int staffPosition,
    required bool stemUp,
    required int beamCount,
    bool isBeamed = false,
  }) {
    // Base length: 3.5 staff spaces (Behind Bars, p.47)
    double length = standardStemLength;

    // Behind Bars (p.47): "The stem must reach the middle line of the staff."
    // If the standard length is not enough to reach the middle line,
    // extend the stem to reach it.
    //
    // staffPosition in half staff spaces; distance to line 3 (staffPos=0):
    //   distance (in SS) = |staffPosition| * 0.5
    //
    // For stem UP (stemUp): if the note is BELOW the middle line (staffPos < 0),
    // the stem must reach the middle line.
    // For stem DOWN (!stemUp): if the note is ABOVE the middle line (staffPos > 0),
    // the stem must reach the middle line.
    if (stemUp && staffPosition < 0) {
      final distanceToMiddle = (-staffPosition) * 0.5; // in SS
      if (distanceToMiddle > length) length = distanceToMiddle;
    } else if (!stemUp && staffPosition > 0) {
      final distanceToMiddle = staffPosition * 0.5;
      if (distanceToMiddle > length) length = distanceToMiddle;
    }

    // Additional extension for multiple beams
    if (!isBeamed && beamCount > 0) {
      length += (beamCount - 1) * stemExtensionPerBeam;
    }

    return length;
  }

  /// Calculates the stem length for CHORDS.
  /// The stem must span ALL notes in the chord!
  ///
  /// Behind Bars (p. 16): "The stem of a chord must connect the most extreme note
  /// to the beam line or the standard length, whichever is greater."
  ///
  /// [noteStaffPositions] - Positions of all notes in the chord
  /// [stemUp] - Whether the stem goes up
  /// [beamCount] - Number of beams (0 for unbeamed notes)
  double calculateChordStemLength({
    required List<int> noteStaffPositions,
    required bool stemUp,
    required int beamCount,
  }) {
    if (noteStaffPositions.isEmpty) return standardStemLength;
    if (noteStaffPositions.length == 1) {
      return calculateStemLength(
        staffPosition: noteStaffPositions.first,
        stemUp: stemUp,
        beamCount: beamCount,
      );
    }

    // Find the chord span
    final int highestPos = noteStaffPositions.reduce((a, b) => a > b ? a : b);
    final int lowestPos = noteStaffPositions.reduce((a, b) => a < b ? a : b);
    final int chordSpan = (highestPos - lowestPos).abs();

    // Convert span from staff positions (half spaces) to staff spaces
    final double chordSpanSpaces = chordSpan * 0.5;

    // FORMULA: stemLength = chordSpan + standardStemLength
    // The stem must SPAN all notes (span) + standard length
    double length = chordSpanSpaces + standardStemLength;

    // Add extra length for multiple beams
    if (beamCount > 0) {
      length += (beamCount - 1) * stemExtensionPerBeam;
    }

    // Floor only. There used to be a ceiling of 6.0 staff spaces here, and it
    // cut INSIDE the chord: a chord spanning 7 half-positions needs 7.00 staff
    // spaces, 10 needs 8.50, 14 needs 10.50, 21 needs 14.00 and 28 needs
    // 17.50 — every one of them was returned as 6.000, so a C3+C6 chord drew a
    // stem that touched neither of its own noteheads and floated in the middle
    // of the staff. Behind Bars p.16: the stem of a chord spans the chord plus
    // the standard length from the outer notehead; there is no upper bound
    // that may cut inside the chord.
    return length < minimumStemLength ? minimumStemLength : length;
  }

  /// Calculates the correct position of an accidental relative to the notehead.
  /// Based on professional music typography practices.
  /// Behind Bars: 0.16-0.20 staff spaces from the notehead.
  /// Returns coordinates in STAFF SPACES (SMuFL units)
  Offset calculateAccidentalPosition({
    required String accidentalGlyph,
    required String noteheadGlyph,
    required double staffPosition,
  }) {
    // Use metadata loader (now required)
    double accidentalWidth = _metadataLoader.getGlyphWidth(accidentalGlyph);
    if (accidentalWidth == 0.0) {
      // Fallback if not found
      accidentalWidth = 1.0;
    }

    // Base position: accidental to the left of the note with standard spacing
    double xOffset = -(accidentalWidth + accidentalToNoteheadDistance);

    // Use cutOutNW of the notehead for advanced optical spacing.
    // Cut-outs allow positioning the accidental closer when there is empty space in the notehead.
    final cutOutNW = _metadataLoader.getGlyphAnchor(noteheadGlyph, 'cutOutNW');

    if (cutOutNW != null && cutOutNW.dx > 0) {
      // There is empty space to the left of the notehead, we can bring the accidental closer
      xOffset += cutOutNW.dx;
    }

    // Y aligned with the note's staff position
    final double yOffset = 0.0;

    return Offset(xOffset, yOffset);
  }

  /// Calculates the angle of a beam based on note positions.
  /// Follows the rules of Ted Ross and Elaine Gould.
  /// Beam slant, in staff spaces, for the interval between the FIRST and LAST
  /// note of a beam group (Gould, *Behind Bars*, pp. 19-25).
  ///
  /// Indexed by the diatonic interval in steps: 0 = unison, 1 = 2nd, 2 = 3rd,
  /// … 7 = octave. Anything wider than an octave uses the last entry. One staff
  /// position is one diatonic step, so the index is `|lastPos - firstPos|`.
  ///
  /// This replaces a linear interpolation between two eyeballed constants
  /// (`minimumBeamSlant = 0.15`, `maximumBeamSlant = 0.5`, the latter carrying
  /// the comment "was 1.0, too steep!") plus a separate clamp of 0.25 for
  /// two-note groups in `BeamAnalyzer`, justified in its own comment as
  /// matching "the stable beam showcase examples". Between them they encoded
  /// only the DIRECTION of the line: measured, an ascending 2nd, an ascending
  /// 6th and a two-octave leap all produced a slant of exactly 0.25 spaces.
  static const List<double> kBeamSlantByDiatonicStep = <double>[
    0.00, // unison — a flat beam
    0.25, // 2nd
    0.50, // 3rd
    1.00, // 4th
    1.00, // 5th
    1.25, // 6th
    1.25, // 7th
    1.50, // octave or wider
  ];

  double calculateBeamAngle({
    required List<int> noteStaffPositions,
    required bool stemUp,
  }) {
    if (noteStaffPositions.length < 2) return 0.0;

    final int firstPos = noteStaffPositions.first;
    final int lastPos = noteStaffPositions.last;
    final int positionDifference = (lastPos - firstPos).abs();
    if (positionDifference == 0) return 0.0;

    final index = positionDifference >= kBeamSlantByDiatonicStep.length
        ? kBeamSlantByDiatonicStep.length - 1
        : positionDifference;
    double slant = kBeamSlantByDiatonicStep[index];

    // A pair carries the same slant as any other group of the same interval;
    // Behind Bars gives two-note beams no separate table.
    final ceiling =
        noteStaffPositions.length == 2 ? twoNoteBeamMaxSlant : maximumBeamSlant;
    slant = slant.clamp(minimumBeamSlant, ceiling);

    return stemUp
        ? (lastPos > firstPos ? slant : -slant)
        : (lastPos > firstPos ? -slant : slant);
  }

  /// Minimum length, in staff spaces, that every stem of a beamed group must
  /// have once the beam line has been placed.
  ///
  /// This is the invariant enforced by the "fit and shift" step of the beam
  /// placement (the same approach used by LilyPond and Verovio): after the
  /// beam slope is chosen, the whole beam line is translated until the
  /// shortest stem of the group reaches this length.
  ///
  /// The value is
  ///
  /// ```text
  /// max(kAbsoluteMinimumStemLengthSpaces,
  ///     kStandardStemLengthSpaces - kBeamedStemShorteningSpaces)
  ///   + (beamCount - 1) * (beamThickness + beamSpacing)
  /// ```
  ///
  /// The extra term reserves room for the secondary beams, which grow away
  /// from the notehead: without it a 32nd-note group would have its innermost
  /// beam sitting on top of the noteheads ("Behind Bars", pp. 17-18).
  ///
  /// [beamCount] is the number of beams of the group (1 for eighths, 2 for
  /// sixteenths, ...). Values below 1 are treated as 1.
  double minimumStemLengthSpaces({required int beamCount}) {
    final extraBeams = beamCount > 1 ? beamCount - 1 : 0;
    final base = math.max(
      kAbsoluteMinimumStemLengthSpaces,
      kStandardStemLengthSpaces - kBeamedStemShorteningSpaces,
    );
    return base + extraBeams * (beamThickness + beamSpacing);
  }

  /// Maximum length, in staff spaces, of a stem of a beamed group with
  /// [beamCount] beams — the counterpart of [minimumStemLengthSpaces].
  ///
  /// The secondary-beam allowance is the same term used by the minimum: the
  /// beams grow away from the notehead, so a 16th-note group is allowed the
  /// same headroom above its own (larger) minimum as an 8th-note group.
  ///
  /// This is a TARGET, not a hard guarantee: the only way to shorten the
  /// longest stem of a group without shortening the shortest one below
  /// [minimumStemLengthSpaces] is to steepen the beam, and a group with an
  /// inner peak (measured: staff positions -2, +5, -2 give 3.50 / 7.00 / 3.50)
  /// cannot be helped by any slope at all. `BeamAnalyzer` steepens as far as
  /// the minimum allows and stops there; the residual case is handled upstream
  /// by `BeamGrouper.kMaximumBeamAmbitusSteps`, which never lets an automatic
  /// group span more than twelve diatonic steps in the first place.
  double maximumStemLengthSpaces({required int beamCount}) {
    final extraBeams = beamCount > 1 ? beamCount - 1 : 0;
    return kMaximumBeamedStemLengthSpaces +
        extraBeams * (beamThickness + beamSpacing);
  }

  /// Calculates the ideal beam height at the position of the first note.
  ///
  /// This is only the INITIAL placement of the beam line; it looks at the
  /// extreme notes of the group and does not guarantee a minimum length for
  /// every stem. The caller is expected to run the fit-and-shift pass against
  /// [minimumStemLengthSpaces] afterwards (see `BeamAnalyzer`).
  double calculateBeamHeight({
    required int staffPosition,
    required bool stemUp,
    required List<int> allStaffPositions,
    int beamCount = 1, // Number of beams (1, 2, 3, or 4)
  }) {
    if (stemUp) {
      // Find the HIGHEST note (largest staffPosition)
      // With positive staffPosition = above, the highest note has the LARGER value
      final int highestPosition = allStaffPositions.reduce(
        (a, b) => a > b ? a : b,
      );
      double height = standardStemLength;

      // If the highest note is far above the staff (> 4), extend
      if (highestPosition > 4) {
        height += (highestPosition - 4) * 0.5;
      }

      // Minimum length for multiple beams: the stem has to be long enough to
      // carry the whole beam stack. The per-level cost is
      // [stemExtensionPerBeam] (= `beamThickness + beamSpacing`), the same
      // number `BeamRenderer` offsets each level by; it used to be a second
      // `0.5` literal here, i.e. beam bodies only, with the gaps between them
      // unpaid for.
      if (beamCount > 1) {
        final minHeightForBeams =
            standardStemLength + ((beamCount - 1) * stemExtensionPerBeam);
        height = height > minHeightForBeams ? height : minHeightForBeams;
      }

      return height;
    } else {
      // Find the LOWEST note (smallest staffPosition)
      // With negative staffPosition = below, the lowest note has the SMALLER value
      final int lowestPosition = allStaffPositions.reduce(
        (a, b) => a < b ? a : b,
      );
      double height = standardStemLength;

      // If the lowest note is far below the staff (< -4), extend
      if (lowestPosition < -4) {
        height += (-4 - lowestPosition) * 0.5;
      }

      // Minimum length for multiple beams: the stem has to be long enough to
      // carry the whole beam stack. The per-level cost is
      // [stemExtensionPerBeam] (= `beamThickness + beamSpacing`), the same
      // number `BeamRenderer` offsets each level by; it used to be a second
      // `0.5` literal here, i.e. beam bodies only, with the gaps between them
      // unpaid for.
      if (beamCount > 1) {
        final minHeightForBeams =
            standardStemLength + ((beamCount - 1) * stemExtensionPerBeam);
        height = height > minHeightForBeams ? height : minHeightForBeams;
      }

      return height;
    }
  }

  /// Calculates the position of an ornament relative to the note
  Offset calculateOrnamentPosition({
    required String ornamentGlyph,
    required int staffPosition,
    required bool hasAccidentalAbove,
  }) {
    final double ornamentHeight = _getGlyphHeight(ornamentGlyph);

    // Ornaments go above the note
    double yOffset = -ornamentToNoteDistance - (ornamentHeight * 0.5);

    // If there is an accidental above (as in trills), add extra space
    if (hasAccidentalAbove) {
      yOffset -= 1.0;
    }

    // If the note is very high in the staff (above the staff)
    // staffPosition > 4 = above the 5th line
    if (staffPosition > 4) {
      yOffset -= 0.5;
    }

    return Offset(0.0, yOffset);
  }

  /// Calculates the position of an articulation (staccato, accent, etc.)
  Offset calculateArticulationPosition({
    required String articulationGlyph,
    required int staffPosition,
    required bool stemUp,
    required bool hasBeam,
  }) {
    final double articulationHeight = _getGlyphHeight(articulationGlyph);

    double yOffset;
    if (stemUp) {
      // Articulation below the note
      yOffset = articulationToNoteDistance + (articulationHeight * 0.5);

      // If the note is in the lower part of the staff (below the staff)
      // staffPosition < -4 = below the 1st line
      if (staffPosition < -4) {
        yOffset += 0.5;
      }
    } else {
      // Articulation above the note
      yOffset = -(articulationToNoteDistance + (articulationHeight * 0.5));

      // If the note is in the upper part of the staff (above the staff)
      // staffPosition > 4 = above the 5th line
      if (staffPosition > 4) {
        yOffset -= 0.5;
      }

      // If there is a beam, add extra space
      if (hasBeam) {
        yOffset -= 1.0;
      }
    }

    return Offset(0.0, yOffset);
  }

  /// Calculates control points for a smooth slur curve.
  /// Returns [startPoint, controlPoint1, controlPoint2, endPoint] for a cubic Bézier curve.
  List<Offset> calculateSlurControlPoints({
    required Offset startPosition,
    required Offset endPosition,
    required bool curveUp,
    required double intensity, // 0.0 to 1.0, how curved the slur is
  }) {
    final double dx = endPosition.dx - startPosition.dx;
    final double dy = endPosition.dy - startPosition.dy;
    final double distance = (dx * dx + dy * dy);

    // Curve height based on distance and intensity
    final double curveHeight = (distance * slurHeightFactor * intensity).clamp(
      0.5,
      3.0,
    );
    final int direction = curveUp ? -1 : 1;

    // Control points for cubic Bézier curve.
    // Based on music typography practices: asymmetric curves are more natural.
    final Offset cp1 = Offset(
      startPosition.dx + dx * 0.25,
      startPosition.dy + dy * 0.25 + direction * curveHeight * 0.7,
    );

    final Offset cp2 = Offset(
      startPosition.dx + dx * 0.75,
      startPosition.dy + dy * 0.75 + direction * curveHeight * 0.9,
    );

    return [startPosition, cp1, cp2, endPosition];
  }

  /// Calculates the position and size of a grace note (appoggiatura)
  Map<String, dynamic> calculateGraceNoteLayout({
    required int staffPosition,
    required bool mainNoteStemUp,
  }) {
    return {
      'scale': graceNoteScale,
      'stemLength': graceNoteStemLength,
      // Grace notes generally go before the main note
      'xOffset': -1.5, // spaces before the main note
      'yOffset': 0.0,
      // Grace notes with slash through the stem
      'hasSlash': true,
      'slashAngle': 45.0, // degrees
    };
  }

  /// Calculates the position and layout of a tuplet
  Map<String, dynamic> calculateTupletLayout({
    required List<Offset> notePositions,
    required bool stemsUp,
    required int tupletNumber,
  }) {
    if (notePositions.isEmpty) {
      return {'show': false};
    }

    final double firstX = notePositions.first.dx;
    final double lastX = notePositions.last.dx;
    final double centerX = (firstX + lastX) / 2;

    // Find the highest/lowest note to position the bracket
    double extremeY;
    if (stemsUp) {
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      extremeY -= (standardStemLength + tupletBracketHeight);
    } else {
      extremeY = notePositions.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
      extremeY += (standardStemLength + tupletBracketHeight);
    }

    return {
      'show': true,
      'bracketStart': Offset(firstX, extremeY),
      'bracketEnd': Offset(lastX, extremeY),
      'numberPosition': Offset(
        centerX,
        extremeY + (stemsUp ? -tupletNumberDistance : tupletNumberDistance),
      ),
      'number': tupletNumber,
      'showBracket': true, // Show bracket if there is no beam
    };
  }

  /// Calculates the width of a glyph using the metadata loader
  double getGlyphWidth(String glyphName) {
    return _metadataLoader.getGlyphWidth(glyphName);
  }

  /// Calculates the height of a glyph based on its bounding box
  double _getGlyphHeight(String glyphName) {
    return _metadataLoader.getGlyphHeight(glyphName);
  }

  /// Gets the optical center of a glyph (for precise centering)
  Offset? getOpticalCenter(String glyphName) {
    // Always use metadata loader (now required)
    return _metadataLoader.getGlyphAnchor(glyphName, 'opticalCenter');
  }

  /// Calculates the position of repeat signs
  Map<String, dynamic> calculateRepeatSignPosition({
    required String repeatGlyph,
    required double barlineX,
    required bool isStart, // true for start, false for end
  }) {
    final double glyphWidth = getGlyphWidth(repeatGlyph);

    // Repeat signs are centered on the barline
    final double xOffset = isStart
        ? barlineX +
              0.3 // Slightly to the right of the start barline
        : barlineX -
              glyphWidth -
              0.3; // Slightly to the left of the end barline

    return {
      'x': xOffset,
      'y': 3.0, // Center of the staff (position 6 = middle line)
      'scale': 1.0, // Normal scale
    };
  }

  /// Calculates the layout of repeat barlines with endings (voltas)
  Map<String, dynamic> calculateEndingLayout({
    required double startX,
    required double endX,
    required int endingNumber,
  }) {
    return {
      'lineStart': Offset(startX, -2.0), // Above the staff
      'lineEnd': Offset(endX, -2.0),
      'hookHeight': 1.0, // Height of the vertical hook
      'numberPosition': Offset(startX + 0.5, -2.5),
      'number': endingNumber.toString(),
      'thickness': _loadEngravingDefault('repeatEndingLineThickness', 0.16),
    };
  }

  /// Calculates the positioning of a time signature
  Map<String, dynamic> calculateTimeSignaturePosition({
    required int numerator,
    required int denominator,
    required double xPosition,
  }) {
    // Time signatures are centered in the staff.
    // Numerator on line 2 (upper space), denominator on line 4 (lower space).
    return {
      'numeratorPosition': Offset(xPosition, 2.0),
      'denominatorPosition': Offset(xPosition, 4.0),
      'numerator': numerator,
      'denominator': denominator,
      'spacing': 0.2, // Horizontal space after the time signature
    };
  }

  /// Calculates the appropriate scale for dynamic markings (to avoid overlaps)
  double calculateDynamicsScale(String dynamicGlyph) {
    // Dynamics are generally drawn at normal scale
    // but can be reduced if there are overlaps
    return 1.0;
  }

  /// Gets the cut-outs of a glyph (for advanced spacing calculations)
  Map<String, Offset> getGlyphCutOuts(String glyphName) {
    final Map<String, Offset> cutOuts = {};

    for (final corner in ['cutOutNE', 'cutOutSE', 'cutOutSW', 'cutOutNW']) {
      final anchor = _metadataLoader.getGlyphAnchor(glyphName, corner);
      if (anchor != null) {
        cutOuts[corner] = anchor;
      }
    }

    return cutOuts;
  }
}
