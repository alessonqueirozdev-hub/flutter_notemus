// lib/core/clef.dart

import 'musical_element.dart';

/// Available musical clef types.
enum ClefType {
  /// Treble clef (G clef)
  treble,
  /// Treble clef, 8va (one octave above)
  treble8va,
  /// Treble clef, 8vb (one octave below)
  treble8vb,
  /// Treble clef, 15ma (two octaves above)
  treble15ma,
  /// Treble clef, 15mb (two octaves below)
  treble15mb,
  /// Bass clef (F clef) — 4th line (standard position)
  bass,
  /// Bass clef on the 3rd line
  bassThirdLine,
  /// Bass clef, 8va (one octave above)
  bass8va,
  /// Bass clef, 8vb (one octave below)
  bass8vb,
  /// Bass clef, 15ma (two octaves above)
  bass15ma,
  /// Bass clef, 15mb (two octaves below)
  bass15mb,

  /// C clef on the 1st line (soprano)
  soprano,
  /// C clef on the 2nd line (mezzo-soprano)
  mezzoSoprano,
  /// C clef on the 3rd line (alto/viola)
  alto,
  /// C clef on the 4th line (tenor)
  tenor,
  /// C clef on the 5th line (baritone — historical)
  baritone,
  /// C clef, 8vb (one octave below)
  c8vb,
  /// Percussion clef 1
  percussion,
  /// Percussion clef 2
  percussion2,
  /// 6-string tablature clef
  tab6,
  /// 4-string tablature clef
  tab4,
}

/// Represents a clef at the beginning of a staff.
class Clef extends MusicalElement {
  final ClefType clefType;
  final int? staffPosition; // For C clefs that can vary in position

  Clef({this.clefType = ClefType.treble, this.staffPosition, String? type}) {
    // Backward compatibility — if type is provided, convert to ClefType
    if (type != null) {
      switch (type) {
        case 'g':
          _clefType = ClefType.treble;
          break;
        case 'f':
          _clefType = ClefType.bass;
          break;
        case 'c':
          _clefType = ClefType.alto;
          break;
        default:
          _clefType = ClefType.treble;
      }
    } else {
      _clefType = clefType;
    }
  }

  ClefType _clefType = ClefType.treble;

  /// Returns the "real" clef type (without octave transposition).
  ClefType get actualClefType {
    switch (_clefType) {
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return ClefType.treble;
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return ClefType.bass;
      default:
        return _clefType;
    }
  }

  /// Returns the SMuFL glyph name corresponding to this clef.
  String get glyphName {
    switch (_clefType) {
      case ClefType.treble:
        return 'gClef';
      case ClefType.treble8va:
        return 'gClef8va';
      case ClefType.treble8vb:
        return 'gClef8vb';
      case ClefType.treble15ma:
        return 'gClef15ma';
      case ClefType.treble15mb:
        return 'gClef15mb';
      case ClefType.bass:
      case ClefType.bassThirdLine:
        return 'fClef';
      case ClefType.bass8va:
        return 'fClef8va';
      case ClefType.bass8vb:
        return 'fClef8vb';
      case ClefType.bass15ma:
        return 'fClef15ma';
      case ClefType.bass15mb:
        return 'fClef15mb';
      case ClefType.soprano:
      case ClefType.mezzoSoprano:
      case ClefType.alto:
      case ClefType.tenor:
      case ClefType.baritone:
        return 'cClef';
      case ClefType.c8vb:
        return 'cClef8vb';
      case ClefType.percussion:
        return 'unpitchedPercussionClef1';
      case ClefType.percussion2:
        return 'unpitchedPercussionClef2';
      case ClefType.tab6:
        return '6stringTabClef';
      case ClefType.tab4:
        return '4stringTabClef';
    }
  }

  /// Returns the reference line position of the clef on the staff
  /// (0 = middle line, positive = above, negative = below).
  int get referenceLinePosition {
    switch (_clefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return 2; // G on the 2nd line
      case ClefType.bass:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return -2; // F on the 4th line (standard position)
      case ClefType.bassThirdLine:
        return -1; // F on the 3rd line

      // C clefs in all positions
      case ClefType.soprano:
        return 2; // C on the 1st line
      case ClefType.mezzoSoprano:
        return 1; // C on the 2nd line
      case ClefType.alto:
        return 0; // C on the 3rd line (middle line)
      case ClefType.tenor:
        return -1; // C on the 4th line
      case ClefType.baritone:
        return -2; // C on the 5th line
      case ClefType.c8vb:
        return 0; // C on the 3rd line (one octave below)
      case ClefType.percussion:
      case ClefType.percussion2:
      case ClefType.tab6:
      case ClefType.tab4:
        return 0; // Centered
    }
  }

  /// Returns the octave shift applied by the clef.
  int get octaveShift {
    switch (_clefType) {
      case ClefType.treble8va:
      case ClefType.bass8va:
        return 1;
      case ClefType.treble8vb:
      case ClefType.bass8vb:
      case ClefType.c8vb:
        return -1;
      case ClefType.treble15ma:
      case ClefType.bass15ma:
        return 2;
      case ClefType.treble15mb:
      case ClefType.bass15mb:
        return -2;
      default:
        return 0;
    }
  }

  /// Backward compatibility - DEPRECATED: Use actualClefType instead
  @Deprecated('Use actualClefType instead. This getter will be removed in future versions.')
  String get type => _getCompatibilityType();

  String _getCompatibilityType() {
    switch (_clefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return 'g';
      case ClefType.bass:
      case ClefType.bassThirdLine:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return 'f';
      case ClefType.soprano:
      case ClefType.mezzoSoprano:
      case ClefType.alto:
      case ClefType.tenor:
      case ClefType.baritone:
      case ClefType.c8vb:
        return 'c';
      default:
        return 'g';
    }
  }

  /// Returns the vertical offset of the clef reference line on the staff
  /// according to SMuFL specifications (in staff space units).
  double get referenceLineOffsetSmufl {
    switch (_clefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return -1.0; // G on the 2nd line (1 staff space below center)
      case ClefType.bass:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return 1.0; // F on the 4th line (1 staff space above center)
      case ClefType.bassThirdLine:
        return 0.0; // F on the 3rd line (middle line)
      case ClefType.soprano:
        return -2.0; // C on the 1st line
      case ClefType.mezzoSoprano:
        return -1.0; // C on the 2nd line
      case ClefType.alto:
        return 0.0; // C on the 3rd line (middle line)
      case ClefType.tenor:
        return 1.0; // C on the 4th line
      case ClefType.baritone:
        return 2.0; // C on the 5th line
      case ClefType.c8vb:
        return 0.0; // C on the 3rd line (one octave below)
      case ClefType.percussion:
      case ClefType.percussion2:
      case ClefType.tab6:
      case ClefType.tab4:
        return 0.0; // Centered
    }
  }
}
