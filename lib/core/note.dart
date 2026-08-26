// lib/core/note.dart

import 'musical_element.dart';
import 'pitch.dart';
import 'duration.dart';
import 'ornament.dart';
import 'dynamic.dart';
import 'technique.dart';
import 'text.dart';
import '../src/music_model/bounding_box_support.dart';

/// Define the articulation types that a note may have.
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

/// How a (cautionary/editorial) accidental is bracketed when displayed.
enum AccidentalParenthesis {
  none, // normal accidental
  parentheses, // cautionary, e.g. (♯)
  brackets, // editorial, e.g. [♯]
}

/// Represents a musical note with pitch and duration.
class Note extends MusicalElement with BoundingBoxSupport {
  final Pitch pitch;
  final Duration duration;

  /// Beam membership of this note, as an **input hint**.
  ///
  /// Set it yourself to encode beams explicitly (and set
  /// `Measure.autoBeaming = false`, or use `BeamingMode.manual`, so the
  /// automatic grouping leaves your value alone).
  ///
  /// Since 2.7.2 the layout NEVER writes here. It publishes its own decision as
  /// a value on `LayoutEngine.beams` / `LayoutEngine.tupletBeams`, and
  /// `LayoutEngine.beamOf(note)` is the only supported read: it returns the
  /// engine's answer when the engine made one and falls back to this field when
  /// it did not. See `doc/adr/ADR-005-layout-decisions-are-values.md`.
  ///
  /// Until 2.7.1 the engine did stamp its answer back in place, which made a
  /// pure export depend on whether the score had been displayed: MEASURED on
  /// two bars of loose quavers, the same `Staff` exported 3 349 characters with
  /// 0 `<beam>` tags before `layout()` and 3 973 with 16 after. Both are
  /// byte-identical now.
  BeamType? beam;
  final List<ArticulationType> articulations;
  final TieType? tie;

  /// Optional: Define whether this note starts or ends a slur.
  final SlurType? slur;

  /// Concurrent (nested/overlapping) slur boundaries on this note, each with a
  /// number so starts and ends can be matched by id. When non-empty this is the
  /// source of truth; otherwise [slur] (a single unnumbered slur) is used.
  final List<SlurEvent> slurs;

  /// List of ornaments applied to the note.
  final List<Ornament> ornaments;

  /// Note-specific dynamic marking.
  final Dynamic? dynamicElement;

  /// Special playing techniques for the note.
  final List<PlayingTechnique> techniques;

  /// Voice number for polyphonic notation (1 = soprano, 2 = alto, etc.).
  /// null = single voice (default).
  final int? voice;

  /// Number of tremolo strokes (0 = none, 1–5 = number of strokes).
  final int tremoloStrokes;

  /// Lyric syllables associated with this note (one per verse).
  /// Index 0 = verse 1, index 1 = verse 2, etc.
  final List<Syllable>? syllables;

  /// Indicates whether this note is a grace note.
  final bool isGraceNote;

  /// Cautionary/editorial bracketing of the displayed accidental (MusicXML
  /// `cautionary`/`editorial`/`parentheses`/`bracket`). Default = none.
  final AccidentalParenthesis accidentalParenthesis;

  /// Cross-staff display offset (keyboard music): the note belongs to its home
  /// staff (for voice/beam/spacing) but its notehead is drawn on another staff.
  /// 0 = home staff, +1 = one staff below, -1 = one staff above. Honored by the
  /// multi-staff (grand-staff) renderer.
  final int crossStaffMove;

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
    this.accidentalParenthesis = AccidentalParenthesis.none,
    this.slurs = const [],
    this.crossStaffMove = 0,
  });
}
