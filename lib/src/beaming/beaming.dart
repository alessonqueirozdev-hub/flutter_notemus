// lib/src/beaming/beaming.dart

/// Sistema avançado de beaming (ligaduras de colcheia) com suporte a:
/// - Primary beams (colcheias)
/// - Secondary beams (semicolcheias, fusas, semifusas)
/// - Broken beams / Fractional beams (para ritmos pontuados)
/// - Regras profissionais de quebra de beams seguindo Behind Bars
/// - Geometria precisa baseada em especificações SMuFL
/// - Beat position calculation (Behind Bars) para quebras inteligentes

export 'beam_types.dart';
export 'beam_segment.dart';
export 'beam_group.dart';
export 'beam_analyzer.dart';
export 'beam_renderer.dart';
export 'beat_position_calculator.dart'; // ✅ ADICIONADO
