/// System de Intelligent spacing
/// 
/// Exports all os componentes of the system de spacing tipográfico musical.
/// 
/// **Uso básico:**
/// ```dart
/// final engine = IntelligentSpacingEngine(
///   preferences: SpacingPreferences.normal,
/// );
/// 
/// engine.initializeOpticalCompensator(staffSpace);
/// 
/// final symbols = [...]; // List of MusicalSymbolInfo
/// final textual = engine.computeTextualSpacing(...);
/// final durational = engine.computeDurationalSpacing(...);
/// final final = engine.combineSpacings(...);
/// engine.applyOpticalCompensation(...);
/// ```
library;

export 'spacing_model.dart';
export 'spacing_preferences.dart';
export 'spacing_engine.dart';
export 'optical_compensation.dart';
export 'collision_detector.dart';
