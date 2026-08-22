/// Musical typographic spacing system.
///
/// # Production path vs. analysis tools
///
/// This directory contains two different kinds of code, and mixing them up is
/// how a suite ends up with hundreds of green lines that never touch a pixel.
/// The split is explicit:
///
/// ## On the production path (called by `LayoutEngine` on every layout pass)
///
/// * [IntelligentSpacingEngine.interNoteSpacing] — **the** rhythmic law
///   (Gould's square-root law, computed, normalised to the quarter note,
///   covering all 15 `DurationType` values and augmentation dots).
/// * [IntelligentSpacingEngine.durationShapeFactor] — the bare model factor
///   behind it.
/// * [IntelligentSpacingEngine.opticalAdjustment] — optical compensation to
///   add on top of the base gap; `0.0` when disabled.
/// * [SpacingPreferences] / [SpacingConstants] — configuration and constants.
/// * [SpacingModel] / [SpacingCalculator] — the mathematical models the law is
///   parameterised over.
/// * `TimeSlice` / `SystemData` (from `spacing_result.dart`) — shared width and
///   shortest-duration helpers.
///
/// ## Analysis tools (never called while rendering)
///
/// * [IntelligentSpacingEngine.analyzeMeasure] and its return type
///   `SpacingResult` — a measurement report built on the production law. Safe
///   to trust, but purely diagnostic.
/// * [IntelligentSpacingEngine.computeTextualSpacing],
///   [IntelligentSpacingEngine.computeDurationalSpacing],
///   [IntelligentSpacingEngine.combineSpacings] and
///   [IntelligentSpacingEngine.applyOpticalCompensation], plus
///   [MusicalSymbolInfo], [SymbolSpacing], `SymbolPosition`, `TextualSpacing`,
///   `DurationalSpacing`, `FinalSpacing` — the dual-algorithm
///   (textual + durational) experiment. Kept for offline comparison; a passing
///   test over these proves nothing about rendered output.
/// * [CollisionDetector] and [OpticalCompensator] are shared primitives: the
///   production path reaches them through
///   [IntelligentSpacingEngine.opticalAdjustment] and
///   [IntelligentSpacingEngine.analyzeMeasure].
///
/// **Basic production use:**
/// ```dart
/// final engine = IntelligentSpacingEngine(
///   preferences: SpacingPreferences.normal,
/// );
///
/// // Gap to leave before `current`, given `previous`:
/// var gap = engine.interNoteSpacing(
///   previousDuration: previous.duration,
///   previousIsRest: previous is Rest,
///   staffSpace: staffSpace,
/// );
/// gap += engine.opticalAdjustment(
///   previous: previous,
///   current: current,
///   staffSpace: staffSpace,
/// );
/// ```
library;

export 'collision_detector.dart';
export 'optical_compensation.dart';
export 'spacing_engine.dart';
export 'spacing_model.dart';
export 'spacing_preferences.dart';
export 'spacing_result.dart';
