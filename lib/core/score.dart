// lib/core/score.dart

import 'staff.dart';
import 'staff_group.dart';

/// Represents a complete musical score with multiple staves
///
/// A [Score] is the top-level container for musical notation, containing
/// one or more [StaffGroup]s. Each group can contain one or more [Staff]s
/// connected by brackets or braces.
///
/// Example:
/// ```dart
/// // Piano score (grand staff)
/// final score = Score(
///   title: 'Moonlight Sonata',
///   composer: 'Ludwig van Beethoven',
///   staffGroups: [
///     StaffGroup(
///       staves: [trebleStaff, bassStaff],
///       bracket: BracketType.brace, // Piano brace {
///       name: 'Piano',
///     ),
///   ],
/// );
///
/// // Choir score (SATB)
/// final score = Score(
///   title: 'Ave Maria',
///   staffGroups: [
///     StaffGroup(
///       staves: [sopranoStaff, altoStaff, tenorStaff, bassStaff],
///       bracket: BracketType.bracket, // Choir bracket [
///       name: 'Choir',
///     ),
///   ],
/// );
/// ```
class Score {
  /// Title of the musical piece
  final String? title;

  /// Subtitle (optional)
  final String? subtitle;

  /// Composer name
  final String? composer;

  /// Arranger name (optional)
  final String? arranger;

  /// Copyright notice (optional)
  final String? copyright;

  /// List of staff groups in the score
  final List<StaffGroup> staffGroups;

  /// Additional metadata (tempo, key, time signature, etc.)
  final Map<String, dynamic> metadata;

  /// Page layout settings
  final PageLayout? pageLayout;

  const Score({
    this.title,
    this.subtitle,
    this.composer,
    this.arranger,
    this.copyright,
    required this.staffGroups,
    this.metadata = const {},
    this.pageLayout,
  });

  /// Get all staves in the score (flattened from all groups)
  List<Staff> get allStaves {
    return staffGroups.expand((group) => group.staves).toList();
  }

  /// Get total number of staves in the score
  int get staffCount {
    return staffGroups.fold(0, (sum, group) => sum + group.staves.length);
  }

  /// Get a specific staff by index (flattened)
  Staff? getStaff(int index) {
    if (index < 0 || index >= staffCount) return null;
    return allStaves[index];
  }

  /// Get a specific staff group by index
  StaffGroup? getStaffGroup(int index) {
    if (index < 0 || index >= staffGroups.length) return null;
    return staffGroups[index];
  }

  /// Create a copy with modified fields
  Score copyWith({
    String? title,
    String? subtitle,
    String? composer,
    String? arranger,
    String? copyright,
    List<StaffGroup>? staffGroups,
    Map<String, dynamic>? metadata,
    PageLayout? pageLayout,
  }) {
    return Score(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      composer: composer ?? this.composer,
      arranger: arranger ?? this.arranger,
      copyright: copyright ?? this.copyright,
      staffGroups: staffGroups ?? this.staffGroups,
      metadata: metadata ?? this.metadata,
      pageLayout: pageLayout ?? this.pageLayout,
    );
  }

  /// Factory: Create a simple single-staff score
  factory Score.singleStaff(
    Staff staff, {
    String? title,
    String? composer,
  }) {
    return Score(
      title: title,
      composer: composer,
      staffGroups: [
        StaffGroup(
          staves: [staff],
          bracket: BracketType.none,
        ),
      ],
    );
  }

  /// Factory: Create a grand staff (piano) score
  factory Score.grandStaff(
    Staff trebleStaff,
    Staff bassStaff, {
    String? title,
    String? composer,
    String? instrumentName = 'Piano',
  }) {
    return Score(
      title: title,
      composer: composer,
      staffGroups: [
        StaffGroup(
          staves: [trebleStaff, bassStaff],
          bracket: BracketType.brace, // Piano brace {
          name: instrumentName,
        ),
      ],
    );
  }

  /// Factory: Create a choir (SATB) score
  factory Score.choir(
    Staff soprano,
    Staff alto,
    Staff tenor,
    Staff bass, {
    String? title,
    String? composer,
  }) {
    return Score(
      title: title,
      composer: composer,
      staffGroups: [
        StaffGroup(
          staves: [soprano, alto, tenor, bass],
          bracket: BracketType.bracket, // Choir bracket [
          name: 'Choir',
        ),
      ],
    );
  }

  /// Factory: Create an orchestral score with multiple groups
  factory Score.orchestral({
    String? title,
    String? composer,
    required List<StaffGroup> groups,
  }) {
    return Score(
      title: title,
      composer: composer,
      staffGroups: groups,
    );
  }
}

/// Page layout settings for score rendering
class PageLayout {
  /// Page width in pixels (or logical units)
  final double width;

  /// Page height in pixels (or logical units)
  final double height;

  /// Top margin
  final double marginTop;

  /// Bottom margin
  final double marginBottom;

  /// Left margin
  final double marginLeft;

  /// Right margin
  final double marginRight;

  /// Space between staff groups (in staff spaces)
  final double staffGroupSpacing;

  /// Space between staves within a group (in staff spaces)
  final double staffSpacing;

  /// Space between systems (in staff spaces)
  final double systemSpacing;

  const PageLayout({
    this.width = 800.0,
    this.height = 1100.0, // A4 proportions
    this.marginTop = 80.0,
    this.marginBottom = 80.0,
    this.marginLeft = 80.0,
    this.marginRight = 80.0,
    this.staffGroupSpacing = 12.0, // Space between groups
    this.staffSpacing = 8.0, // Space between staves in a group
    this.systemSpacing = 16.0, // Space between systems
  });

  /// Factory: A4 page (portrait)
  factory PageLayout.a4Portrait() {
    return const PageLayout(
      width: 595.0, // 210mm in points
      height: 842.0, // 297mm in points
    );
  }

  /// Factory: A4 page (landscape)
  factory PageLayout.a4Landscape() {
    return const PageLayout(
      width: 842.0,
      height: 595.0,
    );
  }

  /// Factory: Letter page (US standard)
  factory PageLayout.letter() {
    return const PageLayout(
      width: 612.0, // 8.5 inches
      height: 792.0, // 11 inches
    );
  }

  /// Get content width (excluding margins)
  double get contentWidth => width - marginLeft - marginRight;

  /// Get content height (excluding margins)
  double get contentHeight => height - marginTop - marginBottom;

  PageLayout copyWith({
    double? width,
    double? height,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    double? staffGroupSpacing,
    double? staffSpacing,
    double? systemSpacing,
  }) {
    return PageLayout(
      width: width ?? this.width,
      height: height ?? this.height,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      staffGroupSpacing: staffGroupSpacing ?? this.staffGroupSpacing,
      staffSpacing: staffSpacing ?? this.staffSpacing,
      systemSpacing: systemSpacing ?? this.systemSpacing,
    );
  }
}
