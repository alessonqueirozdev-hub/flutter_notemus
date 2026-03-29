/// Mathematical spacing models for music notetion.
///
/// Based on common engraving strategies:
/// - Square-root model (recommended)
/// - Logarithmic model
/// - Linear model
/// - Exponential model
library;

import 'dart:math';

/// Spacing model type.
enum SpacingModel {
  /// Square-root model.
  ///
  /// Formula: `s = sqrt(t)`
  /// where `t = duration / shortestDuration`.
  squareRoot,

  /// Logarithmic model.
  ///
  /// Formula: `s = 1 + 0.865617 * ln(t)`
  logarithmic,

  /// Linear model.
  ///
  /// Formula: `s = 1 - 0.134 + 0.134 * t`
  linear,

  /// Exponential model.
  ///
  /// Formula: `s = base^(1/t)`
  exponential,
}

/// Duration-based spacing calculateTestor.
class SpacingCalculator {
  /// Model used for spacing calculateTestions.
  final SpacingModel model;

  /// Global multiplier (1.0 = normal).
  final double spacingRatio;

  /// Base for exponential model (0.0 - 1.0).
  final double exponentialBase;

  const SpacingCalculator({
    this.model = SpacingModel.squareRoot,
    this.spacingRatio = 1.5,
    this.exponentialBase = 0.7,
  });

  /// Returns spacing in relative units.
  double calculateSpace(double duration, double shortestDuration) {
    if (shortestDuration <= 0) {
      return spacingRatio;
    }

    final double t = duration / shortestDuration;
    double baseSpace;

    switch (model) {
      case SpacingModel.squareRoot:
        baseSpace = sqrt(t);
        break;
      case SpacingModel.logarithmic:
        baseSpace = 1.0 + (0.865617 * log(t));
        break;
      case SpacingModel.linear:
        baseSpace = 1.0 - 0.134 + (0.134 * t);
        break;
      case SpacingModel.exponential:
        if (t > 0) {
          baseSpace = pow(exponentialBase, 1.0 / t).toDouble();
        } else {
          baseSpace = 1.0;
        }
        break;
    }

    return baseSpace * spacingRatio;
  }

  /// Reference table used for model validation.
  ///
  /// Values are normalized to the shortest duration (1/32).
  static final Map<double, double> gouldSpacingTable = {
    1.0 / 32.0: 1.0,
    1.0 / 16.0: 1.41,
    1.0 / 8.0: 2.0,
    1.0 / 4.0: 2.83,
    1.0 / 2.0: 4.0,
    1.0: 5.66,
    2.0: 8.0,
  };

  /// Compares the active model against [gouldSpacingTable].
  ///
  /// Returns: duration -> percent error.
  Map<double, double> validateAgainstGould() {
    final Map<double, double> errors = {};
    const double referenceShort = 1.0 / 32.0;

    gouldSpacingTable.forEach((duration, expectedSpace) {
      final double calculatedSpace = calculateSpace(duration, referenceShort);
      final double error =
          ((calculatedSpace - expectedSpace).abs() / expectedSpace) * 100;
      errors[duration] = error;
    });

    return errors;
  }
}
