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
  final int? staffPosition; // For C clefs that can vary in position

  /// The clef this element actually is.
  ///
  /// There used to be TWO fields here that could disagree: a public final
  /// `clefType` set straight from the named parameter, and a private
  /// `_clefType` that every renderer, every position calculation and every
  /// exporter in this package read instead. Passing the legacy `type:` string
  /// set only the private one, so `clef.clefType` reported treble while the
  /// page drew a bass clef — a model that lies to its own consumer about what
  /// it is. One field now, resolved once in the initializer list.
  ClefType get clefType => _clefType;

  Clef({
    ClefType clefType = ClefType.treble,
    this.staffPosition,
    String? type,
  }) : _clefType = type == null ? clefType : clefTypeFromName(type);

  /// Resolves the legacy string [name] to a [ClefType].
  ///
  /// Throws [ArgumentError] on an unrecognised name — deliberately, and this
  /// is a behaviour change. The switch here used to accept exactly `'g'`,
  /// `'f'` and `'c'` and fall through to **treble** for everything else, in
  /// silence. Every legacy call site in this repository (8 of them, across
  /// three example files) passed `'treble'` or `'bass'` instead: `'treble'`
  /// happened to be right because treble is also the fallback, and every
  /// single `'bass'` rendered a TREBLE clef on a bass staff, with the notes
  /// then engraved on the wrong lines and nothing anywhere saying so.
  ///
  /// A fallback that turns a typo into a plausible-looking wrong score is
  /// worse than a crash, so the vocabulary is now the obvious one, the
  /// single-letter MusicXML signs still work, and anything else is refused by
  /// name.
  static ClefType clefTypeFromName(String name) {
    switch (name.trim().toLowerCase()) {
      // MusicXML <sign> letters, kept for the callers that predate the
      // long-form names.
      case 'g':
      case 'treble':
        return ClefType.treble;
      case 'f':
      case 'bass':
        return ClefType.bass;
      case 'c':
      case 'alto':
        return ClefType.alto;
      case 'tenor':
        return ClefType.tenor;
      case 'soprano':
        return ClefType.soprano;
      case 'mezzosoprano':
      case 'mezzo-soprano':
        return ClefType.mezzoSoprano;
      case 'baritone':
        return ClefType.baritone;
      case 'percussion':
        return ClefType.percussion;
      case 'treble8va':
        return ClefType.treble8va;
      case 'treble8vb':
        return ClefType.treble8vb;
      case 'treble15ma':
        return ClefType.treble15ma;
      case 'treble15mb':
        return ClefType.treble15mb;
      case 'bass8va':
        return ClefType.bass8va;
      case 'bass8vb':
        return ClefType.bass8vb;
      case 'bass15ma':
        return ClefType.bass15ma;
      case 'bass15mb':
        return ClefType.bass15mb;
      case 'tab':
      case 'tab6':
        return ClefType.tab6;
      case 'tab4':
        return ClefType.tab4;
    }
    throw ArgumentError.value(
      name,
      'type',
      'unknown clef name. Use a ClefType directly, or one of: treble, bass, '
          'alto, tenor, soprano, mezzoSoprano, baritone, percussion, '
          'treble8va/8vb/15ma/15mb, bass8va/8vb/15ma/15mb, tab6, tab4 '
          "(the MusicXML signs 'g', 'f' and 'c' also work)",
    );
  }

  final ClefType _clefType;

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
