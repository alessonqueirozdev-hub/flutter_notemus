// lib/core/core.dart
// 🎵 TEORIA MUSICAL COMPLETA EM CÓDIGO
// Barrel export file - exporta todos os modelos core

// === ELEMENTOS BÁSICOS ===
export 'musical_element.dart';
export 'pitch.dart';
export 'duration.dart';

// === ELEMENTOS DE PAUTA ===
export 'clef.dart';
export 'time_signature.dart';
export 'key_signature.dart';
export 'barline.dart';
export 'measure.dart';
export 'staff.dart';
export 'staff_group.dart';  // ✅ NEW: Staff grouping with brackets/braces
export 'score.dart';  // ✅ NEW: Complete score with multiple staff groups

// === ELEMENTOS MELÓDICOS ===
export 'note.dart';
export 'rest.dart';
export 'chord.dart';

// === AGRUPAMENTOS ===
export 'tuplet.dart';
export 'tuplet_bracket.dart';
export 'tuplet_number.dart';
export 'beam.dart';
export 'voice.dart';

// === EXPRESSÃO E ARTICULAÇÃO ===
export 'ornament.dart';
export 'articulation.dart';
export 'dynamic.dart';
export 'technique.dart';

// === LIGADURAS E LINHAS ===
export 'slur.dart';
export 'line.dart';

// === ANDAMENTO E TEMPO ===
export 'tempo.dart';

// === ESTRUTURAS E NAVEGAÇÃO ===
export 'repeat.dart';
export 'breath.dart';
export 'volta_bracket.dart';

// === TEXTO E ANOTAÇÕES ===
export 'text.dart';

// === TÉCNICAS AVANÇADAS ===
export 'octave.dart';
export 'cluster.dart';

// === SUPORTE ADICIONAL ===
export '../src/music_model/bounding_box_support.dart';
