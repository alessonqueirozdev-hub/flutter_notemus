// lib/core/core.dart
// Barrel export file — exporta todos os modelos core do flutter_notemus
// Conformidade total com MEI v5 (Music Encoding Initiative)

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
export 'staff_group.dart';
export 'score.dart';
export 'score_def.dart';        // MEI <scoreDef>

// === ELEMENTOS MELÓDICOS ===
export 'note.dart';
export 'rest.dart';
export 'chord.dart';
export 'space.dart';            // MEI <space> e <mSpace>

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
export 'figured_bass.dart';     // MEI <fb>/<f> (baixo cifrado)

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
export 'text.dart';             // inclui Syllable, Verse (MEI <syl>/<verse>)

// === TÉCNICAS AVANÇADAS ===
export 'octave.dart';
export 'cluster.dart';

// === ANÁLISE HARMÔNICA (MEI v5) ===
export 'harmonic_analysis.dart';  // intm, mfunc, deg, inth, ChordTable, HarmonicLabel

// === METADADOS MEI (meiHead) ===
export 'mei_header.dart';         // MeiHeader, FileDescription, WorkList, FRBR

// === REPERTÓRIOS ESPECIALIZADOS MEI v5 ===
export 'mensural.dart';           // Notação mensural medieval/renascentista
export 'neume.dart';              // Notação de neuma (canto gregoriano)
export 'tablature.dart';          // Tablatura (guitarra, alaúde, baixo)

// === SUPORTE ADICIONAL ===
export '../src/music_model/bounding_box_support.dart';
