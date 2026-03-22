// lib/src/theme/adaptive_theme.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'music_score_theme.dart';

/// Theme that automatically adapts colors based on background color and brightness
///
/// This class extends [MusicScoreTheme] to provide automatic color adaptation
/// that ensures sufficient contrast for readability while preserving color
/// identity when desired.
///
/// Example:
/// ```dart
/// // Adapt from BuildContext
/// final theme = AdaptiveMusicScoreTheme.fromContext(context);
///
/// // Adapt from brightness
/// final theme = AdaptiveMusicScoreTheme.fromBrightness(Brightness.dark);
/// ```
class AdaptiveMusicScoreTheme extends MusicScoreTheme {
  /// Background color to adapt against
  final Color backgroundColor;

  /// Brightness mode (light or dark)
  final Brightness brightness;

  /// Minimum contrast ratio (WCAG 2.0 AA standard: 4.5:1 for normal text)
  final double minContrast;

  /// Whether to preserve original color hue and adjust only lightness/saturation
  final bool preserveColorIdentity;

  AdaptiveMusicScoreTheme({
    required this.backgroundColor,
    required this.brightness,
    this.minContrast = 4.5,
    this.preserveColorIdentity = true,
  }) : super(
          // Basic elements
          staffLineColor:
              _adaptColor(Colors.black, backgroundColor, brightness),
          noteheadColor:
              _adaptColor(Colors.black, backgroundColor, brightness),
          stemColor: _adaptColor(Colors.black, backgroundColor, brightness),
          clefColor: _adaptColor(Colors.black, backgroundColor, brightness),
          barlineColor: _adaptColor(Colors.black, backgroundColor, brightness),
          timeSignatureColor:
              _adaptColor(Colors.black, backgroundColor, brightness),
          keySignatureColor:
              _adaptColor(Colors.black, backgroundColor, brightness),
          restColor: _adaptColor(Colors.black, backgroundColor, brightness),
          articulationColor:
              _adaptColor(Colors.black, backgroundColor, brightness),

          // Colored elements (preserve hue if enabled)
          ornamentColor: _adaptColor(
            const Color(0xFFE91E63), // Pink
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          dynamicColor: _adaptColor(
            const Color(0xFF388E3C), // Green
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          tupletColor: _adaptColor(
            const Color(0xFF7B1FA2), // Purple
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          breathColor: _adaptColor(
            const Color(0xFFFF5722), // Deep Orange
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          slurColor: _adaptColor(Colors.black, backgroundColor, brightness),
          tieColor: _adaptColor(Colors.black, backgroundColor, brightness),
          beamColor: _adaptColor(Colors.black, backgroundColor, brightness),
          accidentalColor:
              _adaptColor(Colors.black, backgroundColor, brightness),
          harmonicColor: _adaptColor(
            const Color(0xFF2196F3), // Blue
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          textColor: _adaptColor(Colors.black, backgroundColor, brightness),
          repeatColor: _adaptColor(
            const Color(0xFF9C27B0), // Purple
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          octaveColor: _adaptColor(
            const Color(0xFF00BCD4), // Cyan
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          clusterColor: _adaptColor(
            const Color(0xFFFF9800), // Orange
            backgroundColor,
            brightness,
            preserveHue: preserveColorIdentity,
          ),
          caesuraColor:
              _adaptColor(const Color(0xFFFF5722), backgroundColor, brightness),
          metronomeColor: _adaptColor(
              const Color(0xFF607D8B), backgroundColor, brightness),
        );

  // ═══════════════════════════════════════════════════════════════════════
  // FACTORY CONSTRUCTORS
  // ═══════════════════════════════════════════════════════════════════════

  /// Create adaptive theme from Flutter [BuildContext]
  ///
  /// Automatically detects background color and brightness from
  /// the current theme context.
  ///
  /// Example:
  /// ```dart
  /// final theme = AdaptiveMusicScoreTheme.fromContext(
  ///   context,
  ///   preserveColorIdentity: true,
  /// );
  /// ```
  factory AdaptiveMusicScoreTheme.fromContext(
    BuildContext context, {
    double minContrast = 4.5,
    bool preserveColorIdentity = true,
  }) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final brightness = theme.brightness;

    return AdaptiveMusicScoreTheme(
      backgroundColor: bgColor,
      brightness: brightness,
      minContrast: minContrast,
      preserveColorIdentity: preserveColorIdentity,
    );
  }

  /// Create adaptive theme from [Brightness] only
  ///
  /// Uses Material Design standard background colors:
  /// - Light mode: White (#FFFFFF)
  /// - Dark mode: Dark grey (#121212)
  ///
  /// Example:
  /// ```dart
  /// final theme = AdaptiveMusicScoreTheme.fromBrightness(
  ///   Brightness.dark,
  /// );
  /// ```
  factory AdaptiveMusicScoreTheme.fromBrightness(
    Brightness brightness, {
    double minContrast = 4.5,
    bool preserveColorIdentity = true,
  }) {
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF121212) // Material dark background
        : const Color(0xFFFFFFFF); // White

    return AdaptiveMusicScoreTheme(
      backgroundColor: bgColor,
      brightness: brightness,
      minContrast: minContrast,
      preserveColorIdentity: preserveColorIdentity,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COLOR ADAPTATION ALGORITHMS
  // ═══════════════════════════════════════════════════════════════════════

  /// Adapt a color to ensure sufficient contrast against background
  ///
  /// Algorithm:
  /// 1. Check current contrast ratio
  /// 2. If sufficient (>= minContrast), return original color
  /// 3. If insufficient:
  ///    - If [preserveHue] is true: Adjust lightness/saturation, keep hue
  ///    - If [preserveHue] is false: Use high-contrast black/white
  ///
  /// References:
  /// - WCAG 2.0 Contrast Guidelines
  /// - HSL color space for perceptual adjustments
  static Color _adaptColor(
    Color original,
    Color background,
    Brightness brightness, {
    bool preserveHue = false,
    double minContrast = 4.5,
  }) {
    // Check current contrast
    final currentContrast = _calculateContrast(original, background);

    if (currentContrast >= minContrast) {
      return original; // Already sufficient contrast
    }

    // Need to adapt
    if (preserveHue) {
      // Preserve hue, adjust lightness and saturation
      return _adaptColorPreservingHue(original, background, brightness);
    } else {
      // Simple black/white based on background luminance
      return background.computeLuminance() > 0.5
          ? Colors.black87 // Dark foreground for light background
          : Colors.white87; // Light foreground for dark background
    }
  }

  /// Adapt color while preserving its hue (color identity)
  ///
  /// Algorithm:
  /// 1. Convert to HSL color space
  /// 2. Adjust lightness based on brightness:
  ///    - Dark mode: Lighter colors (L=0.7)
  ///    - Light mode: Darker colors (L=0.3)
  /// 3. Adjust saturation to maintain vibrancy
  static Color _adaptColorPreservingHue(
    Color original,
    Color background,
    Brightness brightness,
  ) {
    final hsl = HSLColor.fromColor(original);

    if (brightness == Brightness.dark) {
      // Dark mode: lighter and slightly less saturated
      return hsl
          .withLightness(0.7) // Increase lightness for visibility
          .withSaturation(
              (hsl.saturation * 0.7).clamp(0.0, 1.0)) // Reduce saturation
          .toColor();
    } else {
      // Light mode: darker and more saturated
      return hsl
          .withLightness(0.3) // Decrease lightness for contrast
          .withSaturation(
              (hsl.saturation * 1.2).clamp(0.0, 1.0)) // Increase saturation
          .toColor();
    }
  }

  /// Calculate contrast ratio between two colors (WCAG 2.0 formula)
  ///
  /// Formula:
  /// ```
  /// contrast = (lighter + 0.05) / (darker + 0.05)
  /// ```
  ///
  /// Where lighter and darker are the relative luminance values.
  ///
  /// Results:
  /// - 1:1 = No contrast (same color)
  /// - 4.5:1 = WCAG AA minimum for normal text
  /// - 7:1 = WCAG AAA minimum for normal text
  /// - 21:1 = Maximum contrast (black on white)
  static double _calculateContrast(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();
    final lighter = max(fgLuminance, bgLuminance);
    final darker = min(fgLuminance, bgLuminance);
    return (lighter + 0.05) / (darker + 0.05);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Check if a color has sufficient contrast against the background
  ///
  /// Returns true if contrast ratio >= [minContrast] (default: 4.5)
  bool hasSufficientContrast(Color color) {
    return _calculateContrast(color, backgroundColor) >= minContrast;
  }

  /// Get contrast ratio between a color and the background
  ///
  /// Returns a value from 1.0 (no contrast) to 21.0 (maximum contrast)
  double getContrastRatio(Color color) {
    return _calculateContrast(color, backgroundColor);
  }

  /// Adapt a custom color to this theme's background
  ///
  /// Useful for dynamically adapting colors at runtime.
  ///
  /// Example:
  /// ```dart
  /// final theme = AdaptiveMusicScoreTheme.fromContext(context);
  /// final adaptedRed = theme.adaptCustomColor(Colors.red);
  /// ```
  Color adaptCustomColor(
    Color color, {
    bool preserveHue = true,
  }) {
    return _adaptColor(
      color,
      backgroundColor,
      brightness,
      preserveHue: preserveHue,
      minContrast: minContrast,
    );
  }
}

/// Mixin for widgets that need adaptive theming
///
/// Provides automatic theme adaptation based on [BuildContext] changes.
///
/// Example:
/// ```dart
/// class MyWidget extends StatefulWidget { ... }
///
/// class _MyWidgetState extends State<MyWidget> with ThemeAdapterMixin {
///   @override
///   Widget build(BuildContext context) {
///     final adaptedTheme = getAdaptiveTheme(context, widget.baseTheme);
///     return MusicScore(theme: adaptedTheme);
///   }
/// }
/// ```
mixin ThemeAdapterMixin<T extends StatefulWidget> on State<T> {
  MusicScoreTheme? _adaptedTheme;
  Brightness? _lastBrightness;
  Color? _lastBackgroundColor;

  /// Get adaptive theme, rebuilding if context has changed
  ///
  /// Caches the adapted theme and only rebuilds when:
  /// - Brightness changes (light ↔ dark mode)
  /// - Background color changes
  MusicScoreTheme getAdaptiveTheme(
    BuildContext context,
    MusicScoreTheme baseTheme,
  ) {
    final currentBrightness = Theme.of(context).brightness;
    final currentBgColor = Theme.of(context).scaffoldBackgroundColor;

    // Check if we need to rebuild theme
    if (_adaptedTheme == null ||
        _lastBrightness != currentBrightness ||
        _lastBackgroundColor != currentBgColor) {
      _adaptedTheme = _adaptTheme(
        baseTheme,
        currentBgColor,
        currentBrightness,
      );

      _lastBrightness = currentBrightness;
      _lastBackgroundColor = currentBgColor;
    }

    return _adaptedTheme!;
  }

  /// Internal method to adapt a theme
  MusicScoreTheme _adaptTheme(
    MusicScoreTheme base,
    Color backgroundColor,
    Brightness brightness,
  ) {
    // If already an AdaptiveMusicScoreTheme, return it directly
    if (base is AdaptiveMusicScoreTheme) {
      return base;
    }

    // Otherwise, create adapted version
    return AdaptiveMusicScoreTheme(
      backgroundColor: backgroundColor,
      brightness: brightness,
      minContrast: 4.5,
      preserveColorIdentity: true,
    );
  }

  /// Clear cached theme (call this if you need to force rebuild)
  void clearThemeCache() {
    _adaptedTheme = null;
    _lastBrightness = null;
    _lastBackgroundColor = null;
  }
}
