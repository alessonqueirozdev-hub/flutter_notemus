// lib/src/beaming/beam_types.dart

/// Stem direction of a note.
enum StemDirection {
  /// Stem up.
  up,

  /// Stem down.
  down,

  /// No stem (for whole notes, breves, or special cases).
  none,
}

/// Beam slope type.
enum BeamSlope {
  /// Horizontal beam (same height at both ends).
  horizontal,

  /// Ascending beam (rising from left to right).
  ascending,

  /// Descending beam (falling from left to right).
  descending,
}

/// Position of the beam relative to staff lines.
enum BeamLineAttachment {
  /// Beam hanging below the line (stem-up notes).
  hanging,

  /// Beam centered on the line.
  centered,

  /// Beam sitting above the line (stem-down notes).
  sitting,
}
