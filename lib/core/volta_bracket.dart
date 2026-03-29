// lib/core/volta_bracket.dart

import 'musical_element.dart';

/// Represents a volta bracket (1st/2nd ending) in music notetion.
///
/// Volta brackets indicate alternative endings for a repeated section.
/// The first time through a repeat the passage under bracket 1 is played;
/// on the repeat the passage under bracket 2 is played instead.
///
/// Example:
/// ```dart
/// final bracket = VoltaBracket(number: 1, length: 150.0);
/// print(bracket.displayLabel); // "1."
///
/// final custom = VoltaBracket(number: 1, length: 150.0, label: '1.-3.');
/// print(custom.displayLabel); // "1.-3."
/// ```
class VoltaBracket extends MusicalElement {
  /// The volta number (1 for first ending, 2 for second ending, etc.).
  final int number;

  /// The horizontal length of the bracket in logical pixels.
  final double length;

  /// Whether the bracket has an open right end (no closing vertical line).
  ///
  /// Defaults to `false` (closed bracket with a vertical line on the right).
  final bool hasOpenEnd;

  /// Optional custom label text shown inside the bracket.
  ///
  /// If `null`, [displayLabel] is automatically derived from [number]
  /// as `"$number."` (e.g. `"1."` or `"2."`).
  final String? label;

  /// Creates a [VoltaBracket].
  ///
  /// [number] and [length] are required. [hasOpenEnd] defaults to `false`.
  /// Provide [label] to override the automatically generated display text.
  VoltaBracket({
    required this.number,
    required this.length,
    this.hasOpenEnd = false,
    this.label,
  });

  /// The text displayed inside the bracket.
  ///
  /// Returns [label] when set, otherwise returns `"$number."`.
  String get displayLabel => label ?? '$number.';
}
