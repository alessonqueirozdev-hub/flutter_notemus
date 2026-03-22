// lib/src/animation/animation_config.dart

import 'package:flutter/material.dart';

/// Configuration for music score animations
///
/// Defines durations, curves, and behavior for various animation types
/// that can be applied to musical elements in the score.
class AnimationConfig {
  // ═══════════════════════════════════════════════════════════════════════
  // DURATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Duration for primary/global animations
  final Duration primaryDuration;

  /// Duration for individual element animations
  final Duration elementDuration;

  /// Delay between staggered element animations
  final Duration staggerDelay;

  /// Duration for highlight pulse animation
  final Duration highlightDuration;

  /// Duration for crescendo visual animation
  final Duration crescendoDuration;

  /// Duration for tempo pulse animation
  final Duration tempoPulseDuration;

  // ═══════════════════════════════════════════════════════════════════════
  // ANIMATION TYPES (ENABLE/DISABLE)
  // ═══════════════════════════════════════════════════════════════════════

  /// Enable entrance animation (fade + slide in)
  final bool entranceAnimation;

  /// Enable fade animation
  final bool fadeAnimation;

  /// Enable slide animation
  final bool slideAnimation;

  /// Enable scale animation
  final bool scaleAnimation;

  /// Enable bounce animation
  final bool bounceAnimation;

  /// Enable crescendo width animation
  final bool animateCrescendo;

  /// Enable tempo metronome pulse
  final bool animateTempo;

  // ═══════════════════════════════════════════════════════════════════════
  // ANIMATION CURVES
  // ═══════════════════════════════════════════════════════════════════════

  /// Curve for fade animations
  final Curve fadeCurve;

  /// Curve for slide animations
  final Curve slideCurve;

  /// Curve for scale animations
  final Curve scaleCurve;

  /// Curve for bounce animations
  final Curve bounceCurve;

  /// Curve for highlight pulse
  final Curve highlightCurve;

  // ═══════════════════════════════════════════════════════════════════════
  // ANIMATION PARAMETERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Direction for slide animation (e.g., Offset(-50, 0) for left-to-right)
  final Offset slideDirection;

  /// Color for highlighted notes during playback
  final Color highlightColor;

  /// Minimum scale factor for scale animations (0.0 - 1.0)
  final double minScale;

  /// Maximum scale factor for scale animations (1.0 - 2.0)
  final double maxScale;

  // ═══════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ═══════════════════════════════════════════════════════════════════════

  const AnimationConfig({
    // Durations
    this.primaryDuration = const Duration(milliseconds: 500),
    this.elementDuration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 50),
    this.highlightDuration = const Duration(milliseconds: 300),
    this.crescendoDuration = const Duration(milliseconds: 1000),
    this.tempoPulseDuration = const Duration(milliseconds: 500),
    // Animation types
    this.entranceAnimation = false,
    this.fadeAnimation = true,
    this.slideAnimation = false,
    this.scaleAnimation = false,
    this.bounceAnimation = false,
    this.animateCrescendo = false,
    this.animateTempo = false,
    // Curves
    this.fadeCurve = Curves.easeInOut,
    this.slideCurve = Curves.easeOut,
    this.scaleCurve = Curves.elasticOut,
    this.bounceCurve = Curves.bounceOut,
    this.highlightCurve = Curves.easeInOut,
    // Parameters
    this.slideDirection = const Offset(-50, 0),
    this.highlightColor = Colors.blue,
    this.minScale = 0.0,
    this.maxScale = 1.0,
  });

  // ═══════════════════════════════════════════════════════════════════════
  // PRESET CONFIGURATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Subtle entrance animation (recommended for most use cases)
  static const AnimationConfig subtle = AnimationConfig(
    entranceAnimation: true,
    fadeAnimation: true,
    slideAnimation: false,
    scaleAnimation: false,
    elementDuration: Duration(milliseconds: 200),
    staggerDelay: Duration(milliseconds: 30),
    fadeCurve: Curves.easeInOut,
  );

  /// Playback mode with note highlighting (for MIDI playback visualization)
  static const AnimationConfig playback = AnimationConfig(
    bounceAnimation: true,
    highlightColor: Colors.blue,
    highlightDuration: Duration(milliseconds: 200),
    bounceCurve: Curves.easeOut,
    minScale: 0.9,
    maxScale: 1.1,
  );

  /// Dramatic entrance with multiple animation types
  static const AnimationConfig dramatic = AnimationConfig(
    entranceAnimation: true,
    fadeAnimation: true,
    slideAnimation: true,
    scaleAnimation: true,
    slideDirection: Offset(-100, -50),
    elementDuration: Duration(milliseconds: 500),
    staggerDelay: Duration(milliseconds: 80),
    scaleCurve: Curves.elasticOut,
    slideCurve: Curves.easeOutCubic,
    minScale: 0.0,
    maxScale: 1.0,
  );

  /// Smooth fade-in only (no slide or scale)
  static const AnimationConfig fadeOnly = AnimationConfig(
    entranceAnimation: true,
    fadeAnimation: true,
    slideAnimation: false,
    scaleAnimation: false,
    elementDuration: Duration(milliseconds: 300),
    staggerDelay: Duration(milliseconds: 40),
  );

  /// Musical expression animations (crescendo, tempo pulses)
  static const AnimationConfig expressive = AnimationConfig(
    animateCrescendo: true,
    animateTempo: true,
    crescendoDuration: Duration(milliseconds: 1500),
    tempoPulseDuration: Duration(milliseconds: 600),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // COPYUNHA
  // ═══════════════════════════════════════════════════════════════════════

  AnimationConfig copyWith({
    Duration? primaryDuration,
    Duration? elementDuration,
    Duration? staggerDelay,
    Duration? highlightDuration,
    Duration? crescendoDuration,
    Duration? tempoPulseDuration,
    bool? entranceAnimation,
    bool? fadeAnimation,
    bool? slideAnimation,
    bool? scaleAnimation,
    bool? bounceAnimation,
    bool? animateCrescendo,
    bool? animateTempo,
    Curve? fadeCurve,
    Curve? slideCurve,
    Curve? scaleCurve,
    Curve? bounceCurve,
    Curve? highlightCurve,
    Offset? slideDirection,
    Color? highlightColor,
    double? minScale,
    double? maxScale,
  }) {
    return AnimationConfig(
      primaryDuration: primaryDuration ?? this.primaryDuration,
      elementDuration: elementDuration ?? this.elementDuration,
      staggerDelay: staggerDelay ?? this.staggerDelay,
      highlightDuration: highlightDuration ?? this.highlightDuration,
      crescendoDuration: crescendoDuration ?? this.crescendoDuration,
      tempoPulseDuration: tempoPulseDuration ?? this.tempoPulseDuration,
      entranceAnimation: entranceAnimation ?? this.entranceAnimation,
      fadeAnimation: fadeAnimation ?? this.fadeAnimation,
      slideAnimation: slideAnimation ?? this.slideAnimation,
      scaleAnimation: scaleAnimation ?? this.scaleAnimation,
      bounceAnimation: bounceAnimation ?? this.bounceAnimation,
      animateCrescendo: animateCrescendo ?? this.animateCrescendo,
      animateTempo: animateTempo ?? this.animateTempo,
      fadeCurve: fadeCurve ?? this.fadeCurve,
      slideCurve: slideCurve ?? this.slideCurve,
      scaleCurve: scaleCurve ?? this.scaleCurve,
      bounceCurve: bounceCurve ?? this.bounceCurve,
      highlightCurve: highlightCurve ?? this.highlightCurve,
      slideDirection: slideDirection ?? this.slideDirection,
      highlightColor: highlightColor ?? this.highlightColor,
      minScale: minScale ?? this.minScale,
      maxScale: maxScale ?? this.maxScale,
    );
  }
}

/// Animation state for a single musical element
///
/// Contains opacity, scale, color, position offset, and rotation
/// values to be applied during rendering.
class ElementAnimationState {
  /// Opacity (0.0 = fully transparent, 1.0 = fully opaque)
  final double opacity;

  /// Scale factor (0.5 = 50% size, 1.0 = normal, 2.0 = 200% size)
  final double scale;

  /// Color to render (can be interpolated for smooth transitions)
  final Color color;

  /// Position offset (added to original position)
  final Offset offset;

  /// Rotation in radians (0.0 = no rotation, pi/2 = 90° clockwise)
  final double rotation;

  /// Animation progress (0.0 = start, 1.0 = end) - for path drawing
  final double progress;

  const ElementAnimationState({
    this.opacity = 1.0,
    this.scale = 1.0,
    required this.color,
    this.offset = Offset.zero,
    this.rotation = 0.0,
    this.progress = 1.0,
  });

  /// Check if any animation is active (differs from default state)
  bool get isAnimated {
    return opacity != 1.0 ||
        scale != 1.0 ||
        offset != Offset.zero ||
        rotation != 0.0 ||
        progress != 1.0;
  }

  /// Create a default (non-animated) state
  static ElementAnimationState defaultState(Color color) {
    return ElementAnimationState(color: color);
  }

  ElementAnimationState copyWith({
    double? opacity,
    double? scale,
    Color? color,
    Offset? offset,
    double? rotation,
    double? progress,
  }) {
    return ElementAnimationState(
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      color: color ?? this.color,
      offset: offset ?? this.offset,
      rotation: rotation ?? this.rotation,
      progress: progress ?? this.progress,
    );
  }
}
