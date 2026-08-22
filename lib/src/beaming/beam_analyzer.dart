import 'package:flutter_notemus/core/note.dart';
import 'package:flutter_notemus/core/time_signature.dart';
import 'package:flutter_notemus/core/duration.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/beaming/beam_segment.dart';
import 'package:flutter_notemus/src/beaming/beam_types.dart';
import 'package:flutter_notemus/src/beaming/beat_position_calculator.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';

/// Analyzes note groups and determines beam geometry and structure.
class BeamAnalyzer {
  /// Horizontal correction, in pixels, applied to the stem anchor of an
  /// up-stem so the stem edge lands on the notehead anchor.
  static const double _stemUpXOffsetPixels = 0.7;

  /// Horizontal correction, in pixels, applied to the stem anchor of a
  /// down-stem so the stem edge lands on the notehead anchor.
  static const double _stemDownXOffsetPixels = -0.8;

  final double staffSpace;
  final double noteheadWidth;
  final SMuFLPositioningEngine positioningEngine;

  BeamAnalyzer({
    required this.staffSpace,
    required this.noteheadWidth,
    required this.positioningEngine,
  });

  AdvancedBeamGroup analyzeAdvancedBeamGroup(
    List<Note> notes,
    TimeSignature timeSignature, {
    Map<Note, double>? noteXPositions,
    Map<Note, int>? noteStaffPositions,
    Map<Note, double>? noteYPositions, // absolute Y in pixels
  }) {
    if (notes.isEmpty) {
      throw ArgumentError('Beam group cannot be empty');
    }

    final group = AdvancedBeamGroup(notes: notes);
    group.stemDirection = _calculateStemDirection(notes, noteStaffPositions);
    final stemXPositions = _calculateXPositions(group, noteXPositions);
    _calculatePrimaryBeamGeometry(
      group,
      noteStaffPositions,
      noteYPositions,
      stemXPositions,
    );
    _analyzeSecondaryBeams(group, timeSignature);
    return group;
  }

  /// Minimum length, in staff spaces, required for every stem of a beamed
  /// group with [beamCount] beams.
  ///
  /// Exposed so callers and tests can assert the invariant enforced by
  /// [analyzeAdvancedBeamGroup]: for every note of the returned group,
  /// `(noteY - group.interpolateBeamY(stemX)).abs()` is at least
  /// `minimumStemLengthSpaces(beamCount: ...) * staffSpace`, and the notehead
  /// always stays on the far side of the beam line.
  ///
  /// Delegates to [SMuFLPositioningEngine.minimumStemLengthSpaces], which
  /// derives the secondary-beam allowance from the font `engravingDefaults`.
  double minimumStemLengthSpaces({required int beamCount}) =>
      positioningEngine.minimumStemLengthSpaces(beamCount: beamCount);

  StemDirection _calculateStemDirection(
    List<Note> notes,
    Map<Note, int>? noteStaffPositions,
  ) {
    if (noteStaffPositions == null || noteStaffPositions.isEmpty) {
      return StemDirection.up; // Default
    }

    // The center line is always staffPosition = 0.
    const int centerLine = 0;

    Note? farthest;
    int maxDistance = 0;
    for (final note in notes) {
      final pos = noteStaffPositions[note];
      if (pos != null) {
        final distance = (pos - centerLine).abs();
        if (distance > maxDistance) {
          maxDistance = distance;
          farthest = note;
        }
      }
    }

    if (farthest == null) {
      return StemDirection.up;
    }

    final farthestPos = noteStaffPositions[farthest]!;
    return farthestPos >= centerLine ? StemDirection.down : StemDirection.up;
  }

  /// Computes the stem X of every note of the group and stores the beam
  /// endpoints (`leftX`/`rightX`) on [group].
  ///
  /// Returns the stem X of each note, in the same order as `group.notes`.
  /// The inner notes are needed by the fit-and-shift pass, which measures the
  /// stem length of every note against the beam line, not just the endpoints.
  List<double> _calculateXPositions(
    AdvancedBeamGroup group,
    Map<Note, double>? noteXPositions,
  ) {
    if (noteXPositions == null || noteXPositions.isEmpty) {
      final stemXPositions = List<double>.generate(
        group.notes.length,
        (index) => index * staffSpace * 2,
      );
      group.leftX = 0;
      group.rightX = (group.notes.length - 1) * staffSpace * 2;
      return stemXPositions;
    }

    final stemXPositions = <double>[
      for (final note in group.notes)
        _stemXForNote(note, noteXPositions[note] ?? 0, group.stemDirection),
    ];

    group.leftX = stemXPositions.first;
    group.rightX = stemXPositions.last;
    return stemXPositions;
  }

  /// Returns the X of the stem of [note] whose notehead origin is at [noteX].
  double _stemXForNote(Note note, double noteX, StemDirection stemDirection) {
    final noteheadGlyph = note.duration.type.glyphName;
    final stemUp = stemDirection == StemDirection.up;

    final stemAnchor = stemUp
        ? positioningEngine.getStemUpAnchor(noteheadGlyph)
        : positioningEngine.getStemDownAnchor(noteheadGlyph);

    final xOffset = stemUp ? _stemUpXOffsetPixels : _stemDownXOffsetPixels;

    return noteX + (stemAnchor.dx * staffSpace - xOffset);
  }

  /// Places the primary beam line.
  ///
  /// Two-step algorithm, as used by LilyPond and Verovio:
  ///
  /// 1. FIT - the slope comes from `calculateBeamAngle` (with the flattening
  ///    clamp for two-note groups) and an initial vertical placement is taken
  ///    from the extreme notes of the group.
  /// 2. SHIFT - the stem length of EVERY note is measured against that line
  ///    and the whole line is translated rigidly (slope preserved) by the
  ///    smallest amount that brings the shortest stem up to
  ///    [minimumStemLengthSpaces].
  ///
  /// Step 2 is what keeps inner notes honest: averaging only the first and the
  /// last note leaves a wide leap with a stub of a stem on the extreme inner
  /// note, and can even push a notehead through the beam.
  void _calculatePrimaryBeamGeometry(
    AdvancedBeamGroup group,
    Map<Note, int>? noteStaffPositions,
    Map<Note, double>? noteYPositions, // absolute Y in pixels
    List<double> stemXPositions,
  ) {
    if (noteStaffPositions == null || noteStaffPositions.isEmpty) {
      throw ArgumentError(
        'noteStaffPositions is required for beam geometry calculation',
      );
    }

    if (noteYPositions == null || noteYPositions.isEmpty) {
      throw ArgumentError('noteYPositions is required for beam geometry calculation');
    }

    final firstNote = group.notes.first;
    final lastNote = group.notes.last;
    final firstNoteY = noteYPositions[firstNote];
    final lastNoteY = noteYPositions[lastNote];
    if (firstNoteY == null || lastNoteY == null) {
      throw ArgumentError('Note Y positions not found');
    }

    final stemUp = group.stemDirection == StemDirection.up;
    final resolvedStaffPositions = noteStaffPositions;
    final groupStaffPositions = group.notes
        .map((note) => resolvedStaffPositions[note])
        .whereType<int>()
        .toList();

    if (groupStaffPositions.length != group.notes.length) {
      throw ArgumentError(
        'Missing staff positions for one or more notes in the beam group',
      );
    }

    var maxBeams = 0;
    for (final note in group.notes) {
      final beams = _getBeamCount(note.duration);
      if (beams > maxBeams) {
        maxBeams = beams;
      }
    }

    final firstStaffPosition = resolvedStaffPositions[firstNote];
    final lastStaffPosition = resolvedStaffPositions[lastNote];
    if (firstStaffPosition == null || lastStaffPosition == null) {
      throw ArgumentError(
        'Missing staff positions for the first or last note in the beam group',
      );
    }

    final beamHeightSpaces = positioningEngine.calculateBeamHeight(
      staffPosition: firstStaffPosition,
      stemUp: stemUp,
      allStaffPositions: groupStaffPositions,
      beamCount: maxBeams,
    );
    final beamHeightPixels = beamHeightSpaces * staffSpace;
    final averageNoteY = (firstNoteY + lastNoteY) / 2;
    final beamBaseY = stemUp
        ? averageNoteY - beamHeightPixels
        : averageNoteY + beamHeightPixels;

    var beamAngleSpaces = positioningEngine.calculateBeamAngle(
      noteStaffPositions: groupStaffPositions,
      stemUp: stemUp,
    );
    // No extra clamp for pairs.
    //
    // There used to be one at 0.25 staff spaces, justified as keeping short
    // groups "visually closer to the flatter beam style already used by the
    // stable beam showcase examples" — a number calibrated against this
    // package's own screenshots rather than against a reference. Combined with
    // `maximumBeamSlant = 0.5` it flattened everything: an ascending 2nd, an
    // ascending 6th and a two-octave leap all came out at exactly 0.25 spaces.
    // `calculateBeamAngle` now reads Gould's interval table, which gives pairs
    // and longer groups the same treatment.
    final beamAnglePixels = beamAngleSpaces * staffSpace;

    final xDistance = group.rightX - group.leftX;
    var beamSlope = xDistance > 0 ? beamAnglePixels / xDistance : 0.0;

    final melodicDelta = lastStaffPosition - firstStaffPosition;
    if (melodicDelta != 0 && beamSlope != 0.0) {
      final expectedSign = melodicDelta > 0 ? -1.0 : 1.0;
      if (beamSlope.sign != expectedSign) {
        beamSlope = -beamSlope;
      }
    }

    group.leftY = beamBaseY;
    group.rightY = beamBaseY + (beamSlope * xDistance);

    _enforceMinimumStemLengths(
      group,
      noteYPositions,
      stemXPositions,
      beamCount: maxBeams,
      stemUp: stemUp,
    );
  }

  /// Rigidly shifts the already-sloped beam line of [group] until every stem
  /// is at least [minimumStemLengthSpaces] long.
  ///
  /// The shift preserves the slope (both endpoints move by the same amount),
  /// so the beam angle chosen by the fit step survives untouched. Because the
  /// stem length is measured as a SIGNED distance (positive when the notehead
  /// is on the correct side of the beam), a notehead that would end up on the
  /// wrong side of the beam produces a large deficit and is pushed back to the
  /// correct side by the same shift - this is the anti-crossing guarantee.
  void _enforceMinimumStemLengths(
    AdvancedBeamGroup group,
    Map<Note, double> noteYPositions,
    List<double> stemXPositions, {
    required int beamCount,
    required bool stemUp,
  }) {
    final minStemLengthPixels =
        minimumStemLengthSpaces(beamCount: beamCount) * staffSpace;

    var requiredShift = 0.0;
    for (var i = 0; i < group.notes.length; i++) {
      if (i >= stemXPositions.length) break;

      final noteY = noteYPositions[group.notes[i]];
      if (noteY == null) continue;

      final beamY = group.interpolateBeamY(stemXPositions[i]);

      // Positive when the notehead sits on the expected side of the beam:
      // below it for up-stems, above it for down-stems.
      final signedStemLength = stemUp ? (noteY - beamY) : (beamY - noteY);

      final deficit = minStemLengthPixels - signedStemLength;
      if (deficit > requiredShift) {
        requiredShift = deficit;
      }
    }

    if (requiredShift <= 0) return;

    // Move the beam AWAY from the noteheads: up (negative Y) for up-stems,
    // down (positive Y) for down-stems.
    final delta = stemUp ? -requiredShift : requiredShift;
    group.leftY += delta;
    group.rightY += delta;
  }

  void _analyzeSecondaryBeams(
    AdvancedBeamGroup group,
    TimeSignature timeSignature,
  ) {
    group.beamSegments.add(
      BeamSegment(
        level: 1,
        startNoteIndex: 0,
        endNoteIndex: group.notes.length - 1,
        isFractional: false,
      ),
    );

    var maxLevel = 1;
    for (final note in group.notes) {
      final beamCount = _getBeamCount(note.duration);
      if (beamCount > maxLevel) {
        maxLevel = beamCount;
      }
    }

    for (int level = 2; level <= maxLevel; level++) {
      _analyzeBeamLevel(group, level, timeSignature);
    }
  }

  void _analyzeBeamLevel(
    AdvancedBeamGroup group,
    int level,
    TimeSignature timeSignature,
  ) {
    int? segmentStart;

    for (int i = 0; i < group.notes.length; i++) {
      final note = group.notes[i];
      final noteBeams = _getBeamCount(note.duration);

      if (noteBeams >= level) {
        segmentStart ??= i;

        final shouldBreak = _shouldBreakSecondaryBeam(
          group,
          i,
          level,
          timeSignature,
        );

        if (shouldBreak && segmentStart != i) {
          group.beamSegments.add(
            BeamSegment(
              level: level,
              startNoteIndex: segmentStart,
              endNoteIndex: i - 1,
              isFractional: false,
            ),
          );
          segmentStart = i;
        }
      } else if (segmentStart != null) {
        if (segmentStart == i - 1) {
          group.beamSegments.add(
            _createFractionalBeam(group, segmentStart, i, level),
          );
        } else {
          group.beamSegments.add(
            BeamSegment(
              level: level,
              startNoteIndex: segmentStart,
              endNoteIndex: i - 1,
              isFractional: false,
            ),
          );
        }
        segmentStart = null;
      }
    }

    if (segmentStart != null) {
      if (segmentStart == group.notes.length - 1) {
        group.beamSegments.add(
          _createFractionalBeam(group, segmentStart, group.notes.length, level),
        );
      } else {
        group.beamSegments.add(
          BeamSegment(
            level: level,
            startNoteIndex: segmentStart,
            endNoteIndex: group.notes.length - 1,
            isFractional: false,
          ),
        );
      }
    }
  }

  bool _shouldBreakSecondaryBeam(
    AdvancedBeamGroup group,
    int noteIndex,
    int beamLevel,
    TimeSignature timeSignature,
  ) {
    if (noteIndex == 0) {
      return false;
    }

    int smallestBeams = 1;
    for (final note in group.notes) {
      final beams = _getBeamCount(note.duration);
      if (beams > smallestBeams) {
        smallestBeams = beams;
      }
    }

    final breakAtLevel = smallestBeams - 2;
    if (beamLevel < breakAtLevel) {
      return false;
    }

    final calculator = BeatPositionCalculator(timeSignature);
    double accumulatedPosition = 0.0;
    for (int i = 0; i < noteIndex; i++) {
      accumulatedPosition += group.notes[i].duration.realValue;
    }

    final noteEvent = NoteEvent(
      positionInBar: accumulatedPosition / calculator.barLengthInWholeNotes(),
      duration: group.notes[noteIndex].duration.realValue,
    );

    final shouldBreak = calculator.shouldBreakBeam(noteEvent);
    return shouldBreak && beamLevel >= breakAtLevel;
  }

  BeamSegment _createFractionalBeam(
    AdvancedBeamGroup group,
    int noteIndex,
    int nextNoteIndex,
    int level,
  ) {
    FractionalBeamSide side;

    if (noteIndex == 0) {
      side = FractionalBeamSide.right;
    } else if (nextNoteIndex >= group.notes.length) {
      side = FractionalBeamSide.left;
    } else {
      final note = group.notes[noteIndex];
      final prevNote = group.notes[noteIndex - 1];
      if (_getDurationValue(note.duration) <
          _getDurationValue(prevNote.duration)) {
        side = FractionalBeamSide.right;
      } else {
        side = FractionalBeamSide.left;
      }
    }

    return BeamSegment(
      level: level,
      startNoteIndex: noteIndex,
      endNoteIndex: noteIndex,
      isFractional: true,
      fractionalSide: side,
      fractionalLength: noteheadWidth,
    );
  }

  int _getBeamCount(Duration duration) {
    return switch (duration.type) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      DurationType.oneHundredTwentyEighth => 5,
      _ => 0,
    };
  }

  double _getDurationValue(Duration duration) {
    return switch (duration.type) {
      DurationType.maxima => 8.0,
      DurationType.long => 4.0,
      DurationType.breve => 2.0,
      DurationType.whole => 1.0,
      DurationType.half => 0.5,
      DurationType.quarter => 0.25,
      DurationType.eighth => 0.125,
      DurationType.sixteenth => 0.0625,
      DurationType.thirtySecond => 0.03125,
      DurationType.sixtyFourth => 0.015625,
      DurationType.oneHundredTwentyEighth => 0.0078125,
      DurationType.twoHundredFiftySixth => 0.00390625,
      DurationType.fiveHundredTwelfth => 0.001953125,
      DurationType.thousandTwentyFourth => 0.0009765625,
      DurationType.twoThousandFortyEighth => 0.00048828125,
    };
  }
}
