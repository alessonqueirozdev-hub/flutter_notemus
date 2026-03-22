// lib/core/staff_group.dart

import 'staff.dart';

/// Type of bracket/brace connecting staves in a group
///
/// Different bracket types are used for different instrument families:
/// - [brace] ({) for keyboard instruments (piano, organ, harp)
/// - [bracket] ([) for vocal groups (choir) and orchestral sections
/// - [line] (|) for multiple instances of the same instrument
/// - [none] for independent staves
enum BracketType {
  /// Curly brace { - Used for keyboard instruments
  ///
  /// Examples: Piano, Organ, Harp, Celesta
  brace,

  /// Square bracket [ - Used for vocal groups and orchestral sections
  ///
  /// Examples: Choir (SATB), String section, Woodwind section
  bracket,

  /// Vertical line | - Used for multiple instances of same instrument
  ///
  /// Examples: Violin I & II, Flute I & II
  line,

  /// No bracket - Independent staves
  ///
  /// Used when staves are not grouped together
  none,
}

/// Represents a group of staves connected by a bracket or brace
///
/// A [StaffGroup] contains one or more [Staff]s that are visually
/// connected and typically represent a single instrument or section.
///
/// Examples:
/// ```dart
/// // Piano (grand staff with brace)
/// final piano = StaffGroup(
///   staves: [trebleStaff, bassStaff],
///   bracket: BracketType.brace,
///   name: 'Piano',
/// );
///
/// // Choir SATB (with bracket)
/// final choir = StaffGroup(
///   staves: [soprano, alto, tenor, bass],
///   bracket: BracketType.bracket,
///   name: 'Choir',
/// );
///
/// // Violin I & II (with line)
/// final violins = StaffGroup(
///   staves: [violin1, violin2],
///   bracket: BracketType.line,
///   name: 'Violins',
/// );
/// ```
class StaffGroup {
  /// List of staves in this group (must contain at least one staff)
  final List<Staff> staves;

  /// Type of bracket connecting the staves
  final BracketType bracket;

  /// Name of the group (displayed to the left of the staves)
  ///
  /// Examples: "Piano", "Violin", "Choir", "Woodwinds"
  final String? name;

  /// Abbreviated name (displayed on subsequent systems)
  ///
  /// Examples: "Pno.", "Vln.", "Ww."
  final String? abbreviation;

  /// Whether barlines should connect all staves in the group
  ///
  /// Default: true for all bracket types except [BracketType.none]
  final bool connectBarlines;

  /// Vertical spacing between staves in this group (in staff spaces)
  ///
  /// Default: null (uses global spacing from PageLayout)
  final double? customSpacing;

  /// Whether to show instrument name on every system
  ///
  /// Default: false (show only on first system)
  final bool showNameOnAllSystems;

  const StaffGroup({
    required this.staves,
    this.bracket = BracketType.none,
    this.name,
    this.abbreviation,
    bool? connectBarlines,
    this.customSpacing,
    this.showNameOnAllSystems = false,
  })  : assert(staves.length > 0, 'StaffGroup must contain at least one staff'),
        connectBarlines = connectBarlines ?? (bracket != BracketType.none);

  /// Number of staves in this group
  int get staffCount => staves.length;

  /// Check if this is a grand staff (2 staves with brace)
  bool get isGrandStaff => staves.length == 2 && bracket == BracketType.brace;

  /// Get a specific staff by index
  Staff? getStaff(int index) {
    if (index < 0 || index >= staves.length) return null;
    return staves[index];
  }

  /// Create a copy with modified fields
  StaffGroup copyWith({
    List<Staff>? staves,
    BracketType? bracket,
    String? name,
    String? abbreviation,
    bool? connectBarlines,
    double? customSpacing,
    bool? showNameOnAllSystems,
  }) {
    return StaffGroup(
      staves: staves ?? this.staves,
      bracket: bracket ?? this.bracket,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      connectBarlines: connectBarlines ?? this.connectBarlines,
      customSpacing: customSpacing ?? this.customSpacing,
      showNameOnAllSystems: showNameOnAllSystems ?? this.showNameOnAllSystems,
    );
  }

  /// Factory: Create a piano (grand staff) group
  factory StaffGroup.piano(Staff trebleStaff, Staff bassStaff) {
    return StaffGroup(
      staves: [trebleStaff, bassStaff],
      bracket: BracketType.brace,
      name: 'Piano',
      abbreviation: 'Pno.',
    );
  }

  /// Factory: Create an organ group (typically 3 staves)
  factory StaffGroup.organ(Staff manual1, Staff manual2, Staff pedal) {
    return StaffGroup(
      staves: [manual1, manual2, pedal],
      bracket: BracketType.brace,
      name: 'Organ',
      abbreviation: 'Org.',
    );
  }

  /// Factory: Create a harp group (grand staff)
  factory StaffGroup.harp(Staff trebleStaff, Staff bassStaff) {
    return StaffGroup(
      staves: [trebleStaff, bassStaff],
      bracket: BracketType.brace,
      name: 'Harp',
      abbreviation: 'Hp.',
    );
  }

  /// Factory: Create a choir SATB group
  factory StaffGroup.choir(
    Staff soprano,
    Staff alto,
    Staff tenor,
    Staff bass,
  ) {
    return StaffGroup(
      staves: [soprano, alto, tenor, bass],
      bracket: BracketType.bracket,
      name: 'Choir',
    );
  }

  /// Factory: Create a string section group
  factory StaffGroup.strings(List<Staff> staves) {
    return StaffGroup(
      staves: staves,
      bracket: BracketType.bracket,
      name: 'Strings',
      abbreviation: 'Str.',
    );
  }

  /// Factory: Create a woodwind section group
  factory StaffGroup.woodwinds(List<Staff> staves) {
    return StaffGroup(
      staves: staves,
      bracket: BracketType.bracket,
      name: 'Woodwinds',
      abbreviation: 'Ww.',
    );
  }

  /// Factory: Create a brass section group
  factory StaffGroup.brass(List<Staff> staves) {
    return StaffGroup(
      staves: staves,
      bracket: BracketType.bracket,
      name: 'Brass',
      abbreviation: 'Br.',
    );
  }

  /// Factory: Create a percussion section group
  factory StaffGroup.percussion(List<Staff> staves) {
    return StaffGroup(
      staves: staves,
      bracket: BracketType.bracket,
      name: 'Percussion',
      abbreviation: 'Perc.',
    );
  }

  /// Factory: Create a group for multiple instances of same instrument
  ///
  /// Uses [BracketType.line] to indicate related but independent parts
  factory StaffGroup.multipleInstruments(
    List<Staff> staves,
    String instrumentName,
  ) {
    return StaffGroup(
      staves: staves,
      bracket: BracketType.line,
      name: instrumentName,
    );
  }
}

/// Configuration for bracket/brace rendering
class BracketRenderConfig {
  /// Thickness of bracket/brace lines (in staff spaces)
  final double thickness;

  /// Width of bracket tips (in staff spaces)
  final double tipWidth;

  /// Horizontal offset from staff (in staff spaces)
  ///
  /// Positive values move bracket to the left (away from notes)
  final double horizontalOffset;

  /// SMuFL glyph names for bracket/brace rendering
  final String? glyphName;

  const BracketRenderConfig({
    this.thickness = 0.16, // SMuFL standard
    this.tipWidth = 0.5,
    this.horizontalOffset = 1.0,
    this.glyphName,
  });

  /// Factory: Configuration for brace { rendering
  factory BracketRenderConfig.brace() {
    return const BracketRenderConfig(
      thickness: 0.16,
      glyphName: 'brace', // SMuFL glyph for curly brace
      horizontalOffset: 1.5,
    );
  }

  /// Factory: Configuration for bracket [ rendering
  factory BracketRenderConfig.bracket() {
    return const BracketRenderConfig(
      thickness: 0.16,
      tipWidth: 0.5,
      horizontalOffset: 1.0,
    );
  }

  /// Factory: Configuration for line | rendering
  factory BracketRenderConfig.line() {
    return const BracketRenderConfig(
      thickness: 0.08, // Thinner than bracket
      tipWidth: 0.0, // No tips
      horizontalOffset: 0.8,
    );
  }
}
