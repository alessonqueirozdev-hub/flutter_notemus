// lib/core/note.dart

import 'musical_element.dart';
import 'pitch.dart';
import 'duration.dart';
import 'ornament.dart';
import 'dynamic.dart';
import 'technique.dart';
import 'text.dart';
import '../src/music_model/bounding_box_support.dart';

/// Definesss the articulation types that a note may have.
enum ArticulationType {
  staccato,         // Dot
  staccatissimo,    // Triangular dot
  accent,           // Accent
  strongAccent,     // Strong accent
  tenuto,           // Tenuto line
  marcato,          // Combination of accent and tenuto
  legato,           // Legato (usually as a slur)
  portato,          // Combination of staccato and tenuto
  upBow,            // Up bow (strings)
  downBow,          // Down bow (strings)
  harmonics,        // Harmonics
  pizzicato,        // Pizzicato
  snap,             // Snap pizzicato
  thumb,            // Thumb fingering
  stopped,          // Stopped notes (brass)
  open,             // Open notes (brass)
  halfStopped,      // Half-stopped (brass)
}

/// Represents a musical note with pitch and duration.
class Note extends MusicalElement with BoundingBoxSupport {
  final Pitch pitch;
  final Duration duration;

  final BeamType? beam;
  final List<ArticulationType> articulations;
  final TieType? tie;

  /// Optional: Definesss whether this note starts or ends a slur.
  final SlurType? slur;

  /// List of ornaments applied to the note.
  final List<Ornament> ornaments;

  /// Note-specific dynamic marking.
  final Dynamic? dynamicElement;

  /// Special playing techniques for the note.
  final List<PlayingTechnique> techniques;

  /// Voice number for polyphonic notetion (1 = soprano, 2 = alto, etc.).
  /// null = single voice (default).
  final int? voice;

  /// Number of tremolo strokes (0 = none, 1–5 = number of strokes).
  final int tremoloStrokes;

  /// Lyric syllables associated with this note (one per verse).
  /// Index 0 = verse 1, index 1 = verse 2, etc.
  final List<Syllable>? syllables;

  /// Indicates whether this note is a grace note.
  final bool isGraceNote;

  /// Alternate pitch for grace notes with a specific pitch.
  final Pitch? alternatePitch;

  // === Tablature fields (MEI `@tab.fret` and `@tab.string`) ===

  /// Fret number in tablature. null = note is not a tablature note.
  /// Corresponds to the MEI v5 `@tab.fret` attribute.
  /// 0 = open string, 1–24 = numbered frets.
  final int? tabFret;

  /// String number in tablature (1-based, highest string = 1).
  /// Corresponds to the MEI v5 `@tab.string` attribute.
  final int? tabString;

  /// Indicates whether this note is a tablature note (has [tabFret] or [tabString]).
  bool get isTabNote => tabFret != null || tabString != null;

  Note({
    required this.pitch,
    required this.duration,
    this.beam,
    this.articulations = const [],
    this.tie,
    this.slur,
    this.ornaments = const [],
    this.dynamicElement,
    this.techniques = const [],
    this.voice,
    this.tremoloStrokes = 0,
    this.isGraceNote = false,
    this.alternatePitch,
    this.tabFret,
    this.tabString,
    this.syllables,
  });
}
