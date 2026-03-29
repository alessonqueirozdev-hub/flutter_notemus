// lib/src/beaming/beam_segment.dart

/// Represents a beam segment (full or fractional/broken).
class BeamSegment {
  /// Beam level (1 = primary, 2 = secondary, 3 = tertiary, etc.).
  final int level;

  /// Index of the first note in the group.
  final int startNoteIndex;

  /// Index of the last note in the group.
  final int endNoteIndex;

  /// Whether this is a fractional beam (broken beam/stub).
  final bool isFractional;

  /// Side of the fractional beam (only relevant when isFractional = true).
  final FractionalBeamSide? fractionalSide;

  /// Length of the fractional beam in staff spaces (default: notehead width).
  final double? fractionalLength;

  BeamSegment({
    required this.level,
    required this.startNoteIndex,
    required this.endNoteIndex,
    this.isFractional = false,
    this.fractionalSide,
    this.fractionalLength,
  });

  @override
  String toString() {
    if (isFractional) {
      return 'BeamSegment(level: $level, note: $startNoteIndex, fractional: $fractionalSide)';
    }
    return 'BeamSegment(level: $level, notes: $startNoteIndex-$endNoteIndex)';
  }
}

/// Direction of a fractional beam (beam stub).
enum FractionalBeamSide {
  /// Beam stub points to the left.
  left,

  /// Beam stub points to the right (default for dotted rhythms).
  right,
}
