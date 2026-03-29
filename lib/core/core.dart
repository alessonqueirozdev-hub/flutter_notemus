// lib/core/core.dart
// Barrel export file — exports all core models of flutter_notemus
// Full compliance with MEI v5 (Music Encoding Initiative)

// === BASIC ELEMENTS ===
export 'musical_element.dart';
export 'pitch.dart';
export 'duration.dart';

// === STAFF ELEMENTS ===
export 'clef.dart';
export 'time_signature.dart';
export 'key_signature.dart';
export 'barline.dart';
export 'measure.dart';
export 'staff.dart';
export 'staff_group.dart';
export 'score.dart';
export 'score_def.dart';        // MEI <scoreDef>

// === MELODIC ELEMENTS ===
export 'note.dart';
export 'rest.dart';
export 'chord.dart';
export 'space.dart';            // MEI <space> and <mSpace>

// === GROUPINGS ===
export 'tuplet.dart';
export 'tuplet_bracket.dart';
export 'tuplet_number.dart';
export 'beam.dart';
export 'voice.dart';

// === EXPRESSION AND ARTICULATION ===
export 'ornament.dart';
export 'articulation.dart';
export 'dynamic.dart';
export 'technique.dart';
export 'figured_bass.dart';     // MEI <fb>/<f> (figured bass)

// === SLURS AND LINES ===
export 'slur.dart';
export 'line.dart';

// === TEMPO AND TIMING ===
export 'tempo.dart';

// === STRUCTURE AND NAVIGATION ===
export 'repeat.dart';
export 'breath.dart';
export 'volta_bracket.dart';

// === TEXT AND ANNoteTIONS ===
export 'text.dart';             // includes Syllable, Verse (MEI <syl>/<verse>)

// === ADVANCED TECHNIQUES ===
export 'octave.dart';
export 'cluster.dart';

// === HARMONIC ANALYSIS (MEI v5) ===
export 'harmonic_analysis.dart';  // intm, mfunc, deg, inth, ChordTable, HarmonicLabel

// === MEI METADATA (meiHead) ===
export 'mei_header.dart';         // MeiHeader, FileDescription, WorkList, FRBR

// === SPECIALIZED MEI v5 REPERTORIES ===
export 'mensural.dart';           // Medieval/Renaissance mensural notation
export 'neume.dart';              // Neume notation (Gregorian chant)
export 'tablature.dart';          // Tablature (guitar, lute, bass)

// === ADDITIONAL SUPPORT ===
export '../src/music_model/bounding_box_support.dart';
