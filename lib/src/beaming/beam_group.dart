// lib/src/beaming/beam_group.dart

import 'package:flutter_notemus/core/note.dart';
import 'package:flutter_notemus/src/beaming/beam_segment.dart';
import 'package:flutter_notemus/src/beaming/beam_types.dart';

/// Represents a group of notes connected by beams with calculateTested geometry.
/// (Advanced version with slope analysis and beam segments.)
class AdvancedBeamGroup {
  /// Notes in the group (must be consecutive).
  List<Note> notes;

  /// Stem direction for the entire group.
  StemDirection stemDirection = StemDirection.up;

  /// Beam segments (primary, secondary, fractional, etc.).
  final List<BeamSegment> beamSegments = [];

  /// X position at the start of the beam (first note).
  double leftX = 0;

  /// X position at the end of the beam (last note).
  double rightX = 0;

  /// Y position of the beam at the first note (top/base of stem).
  double leftY = 0;

  /// Y position of the beam at the last note (top/base of stem).
  double rightY = 0;

  /// Beam slope.
  double get slope {
    if (rightX == leftX) return 0;
    return (rightY - leftY) / (rightX - leftX);
  }
  
  /// Whether the beam is horizontal (no slope).
  bool get isHorizontal => leftY == rightY;

  AdvancedBeamGroup({
    required this.notes,
    this.stemDirection = StemDirection.up,
  });

  /// Interpolates the beam Y position at a given X position.
  double interpolateBeamY(double x) {
    if (isHorizontal || rightX == leftX) {
      return leftY;
    }
    return leftY + (slope * (x - leftX));
  }

  @override
  String toString() {
    return 'AdvancedBeamGroup(notes: ${notes.length}, '
           'segments: ${beamSegments.length}, '
           'slope: ${slope.toStringAsFixed(3)}';
  }
}
