/// Sistema de Espaçamento Inteligente
/// 
/// Exporta todos os componentes do sistema de espaçamento tipográfico musical.
/// 
/// **Uso básico:**
/// ```dart
/// final engine = IntelligentSpacingEngine(
///   preferences: SpacingPreferences.normal,
/// );
/// 
/// engine.initializeOpticalCompensator(staffSpace);
/// 
/// final symbols = [...]; // Lista de MusicalSymbolInfo
/// final textual = engine.computeTextualSpacing(...);
/// final durational = engine.computeDurationalSpacing(...);
/// final final = engine.combineSpacings(...);
/// engine.applyOpticalCompensation(...);
/// ```
library intelligent_spacing;

export 'spacing_model.dart';
export 'spacing_preferences.dart';
export 'spacing_engine.dart';
export 'optical_compensation.dart';
export 'collision_detector.dart';
