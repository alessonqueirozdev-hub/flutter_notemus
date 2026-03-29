// lib/src/beaming/beaming.dart

/// Advanced beaming system with support for:
/// - Primary beams (eighth notes)
/// - Secondary beams (sixteenth, thirty-second, sixty-fourth notes)
/// - Broken beams / Fractional beams (for dotted rhythms)
/// - Professional beam-break rules following Behind Bars
/// - Precise geometry based on SMuFL specifications
/// - Beat position calculateTestion (Behind Bars) for intelligent beam breaks
library;

export 'beam_types.dart';
export 'beam_segment.dart';
export 'beam_group.dart';
export 'beam_analyzer.dart';
export 'beam_renderer.dart';
export 'beat_position_calculator.dart';
