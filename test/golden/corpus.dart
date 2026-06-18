// Golden-test corpus for the engraving quality sprint.
//
// Each [CorpusCase] builds a single-staff [Staff] (the public [MusicScore]
// widget renders one staff) that exercises a slice of the engraving checklist:
// spacing, stems, beams, slurs/ties, accidentals, dots, rests, ledger lines,
// tuplets, polyphony, articulations, dynamics. Cases are deterministic so the
// golden PNGs are reproducible.
//
// The corpus doubles as (a) the figure generator for the paper's evaluation
// section (run with --update-goldens) and (b) the regression suite (Phase 4).

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_notemus/flutter_notemus.dart';

/// A single reproducible corpus entry.
class CorpusCase {
  final String id;
  final String title;
  final String tier; // 'simple' | 'intermediate' | 'complex'
  final String exercises; // engraving aspects under test
  final double staffSpace;
  final Size size;
  final Staff Function() build;

  const CorpusCase({
    required this.id,
    required this.title,
    required this.tier,
    required this.exercises,
    required this.build,
    this.staffSpace = 12.0,
    this.size = const Size(900, 240),
  });
}

// ---------------------------------------------------------------------------
// Small builder helpers (keep cases terse and readable).
// ---------------------------------------------------------------------------

Note _n(
  String step,
  int octave, {
  DurationType dur = DurationType.quarter,
  int dots = 0,
  double alter = 0.0,
  List<ArticulationType>? artic,
  TieType? tie,
  SlurType? slur,
  BeamType? beam,
}) {
  return Note(
    pitch: Pitch(step: step, octave: octave, alter: alter),
    duration: Duration(dur, dots: dots),
    articulations: artic ?? const [],
    tie: tie,
    slur: slur,
    beam: beam,
  );
}

Rest _r(DurationType dur, {int dots = 0}) =>
    Rest(duration: Duration(dur, dots: dots));

Measure _measure(List<MusicalElement> elements) {
  final m = Measure();
  for (final e in elements) {
    m.add(e);
  }
  return m;
}

Staff _staff(List<Measure> measures) {
  final s = Staff();
  for (final m in measures) {
    s.add(m);
  }
  return s;
}

// ---------------------------------------------------------------------------
// SIMPLE
// ---------------------------------------------------------------------------

Staff _cMajorScale() {
  // One octave ascending + descending, eighth notes (auto-beamed),
  // C4 sits below the staff (ledger line).
  final steps = ['C', 'D', 'E', 'F', 'G', 'A', 'B', 'C'];
  final up = <MusicalElement>[
    Clef(clefType: ClefType.treble),
    TimeSignature(numerator: 4, denominator: 4),
  ];
  for (var i = 0; i < steps.length; i++) {
    up.add(_n(steps[i], i == 7 ? 5 : 4, dur: DurationType.eighth));
  }
  return _staff([_measure(up)]);
}

const _odeToJoyJson = '''
{
  "measures": [
    {"elements": [
      {"type": "clef", "clefType": "treble"},
      {"type": "keySignature", "count": 2},
      {"type": "timeSignature", "numerator": 4, "denominator": 4},
      {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 1.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 1.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "G", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "A", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
    ]},
    {"elements": [
      {"type": "note", "pitch": {"step": "A", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "G", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 1.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
    ]},
    {"elements": [
      {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
      {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 1.0}, "duration": {"type": "quarter"}}
    ]},
    {"elements": [
      {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 1.0}, "duration": {"type": "quarter", "dots": 1}},
      {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "eighth"}},
      {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "half"}}
    ]}
  ]
}
''';

Staff _odeToJoy() => JsonMusicParser.parseStaff(_odeToJoyJson);

// ---------------------------------------------------------------------------
// INTERMEDIATE
// ---------------------------------------------------------------------------

Staff _triads() {
  Chord triad(String root, int oct, List<int> thirds) {
    // Build a simple stacked triad from diatonic offsets (in steps).
    const order = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    final rootIdx = order.indexOf(root);
    final notes = <Note>[];
    var idx = rootIdx;
    var o = oct;
    for (final step in [0, 2, 4]) {
      var target = rootIdx + step;
      o = oct + (target ~/ 7);
      idx = target % 7;
      notes.add(Note(
        pitch: Pitch(step: order[idx], octave: o),
        duration: const Duration(DurationType.half),
      ));
    }
    return Chord(notes: notes, duration: const Duration(DurationType.half));
  }

  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      triad('C', 4, const []),
      triad('G', 4, const []),
    ]),
    _measure([
      triad('A', 4, const []),
      triad('F', 4, const []),
    ]),
  ]);
}

Staff _accidentals() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('F', 5, alter: 1.0), // sharp
      _n('B', 4, alter: -1.0), // flat
      _n('C', 5, alter: 0.0), // natural (after context)
      _n('G', 4, alter: 1.0),
    ]),
    // A chord whose members need accidentals on adjacent staff positions.
    _measure([
      Chord(notes: [
        Note(pitch: const Pitch(step: 'E', octave: 4, alter: -1.0), duration: const Duration(DurationType.whole)),
        Note(pitch: const Pitch(step: 'G', octave: 4, alter: 1.0), duration: const Duration(DurationType.whole)),
        Note(pitch: const Pitch(step: 'B', octave: 4, alter: -1.0), duration: const Duration(DurationType.whole)),
      ], duration: const Duration(DurationType.whole)),
    ]),
  ]);
}

Staff _augmentationDots() {
  // Treble lines: E4 G4 B4 D5 F5 ; spaces: F4 A4 C5 E5 G5.
  return _staff([
    // Notes ON lines → augmentation dot sits in the space above.
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('G', 4, dur: DurationType.quarter, dots: 1), // line
      _n('A', 4, dur: DurationType.eighth),
      _n('B', 4, dur: DurationType.quarter, dots: 1), // line
      _n('C', 5, dur: DurationType.eighth),
    ]),
    // Notes IN spaces → augmentation dot sits in the same space.
    _measure([
      _n('A', 4, dur: DurationType.quarter, dots: 1), // space
      _n('G', 4, dur: DurationType.eighth),
      _n('E', 5, dur: DurationType.quarter, dots: 1), // space
      _n('D', 5, dur: DurationType.eighth),
    ]),
  ]);
}

Staff _triplets() {
  Tuplet triplet(List<Note> notes) =>
      Tuplet(actualNotes: 3, normalNotes: 2, elements: notes);
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      // Ascending triplet → bracket should slope upward (E2).
      triplet([
        _n('C', 5, dur: DurationType.eighth),
        _n('E', 5, dur: DurationType.eighth),
        _n('G', 5, dur: DurationType.eighth),
      ]),
      // Descending triplet → bracket should slope downward.
      triplet([
        _n('G', 5, dur: DurationType.eighth),
        _n('E', 5, dur: DurationType.eighth),
        _n('C', 5, dur: DurationType.eighth),
      ]),
      _n('C', 5, dur: DurationType.half),
    ]),
  ]);
}

Staff _slursAndTies() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('C', 5, slur: SlurType.start),
      _n('D', 5),
      _n('E', 5),
      _n('F', 5, slur: SlurType.end),
    ]),
    _measure([
      _n('G', 5, dur: DurationType.half, tie: TieType.start),
      _n('G', 5, dur: DurationType.half, tie: TieType.end),
    ]),
  ]);
}

Staff _articulations() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('C', 5, artic: [ArticulationType.staccato]),
      _n('D', 5, artic: [ArticulationType.accent]),
      _n('E', 5, artic: [ArticulationType.tenuto]),
      _n('F', 5, artic: [ArticulationType.marcato]),
    ]),
  ]);
}

Staff _dynamics() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      Dynamic(type: DynamicType.piano),
      _n('C', 5),
      _n('E', 5),
      Dynamic(type: DynamicType.forte),
      _n('G', 5),
      _n('C', 6),
    ]),
  ]);
}

Staff _lyrics() {
  Note lyr(
    String step,
    int oct,
    String text,
    SyllableType type, {
    DurationType dur = DurationType.quarter,
  }) =>
      Note(
        pitch: Pitch(step: step, octave: oct),
        duration: Duration(dur),
        syllables: [Syllable(text: text, type: type)],
      );
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      lyr('C', 5, 'Twin', SyllableType.initial),
      lyr('C', 5, 'kle', SyllableType.terminal),
      lyr('G', 5, 'twin', SyllableType.initial),
      lyr('G', 5, 'kle', SyllableType.terminal),
    ]),
    _measure([
      lyr('A', 5, 'lit', SyllableType.initial),
      lyr('A', 5, 'tle', SyllableType.terminal),
      lyr('G', 5, 'star', SyllableType.single, dur: DurationType.half),
    ]),
  ]);
}

Staff _melisma() {
  Note lyr(String s, int o, String text, SyllableType type,
          {DurationType dur = DurationType.quarter}) =>
      Note(
        pitch: Pitch(step: s, octave: o),
        duration: Duration(dur),
        syllables: [Syllable(text: text, type: type)],
      );
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      lyr('C', 5, 'Sing', SyllableType.single), // held over the next 3 notes
      _n('D', 5),
      _n('E', 5),
      _n('F', 5),
    ]),
    _measure([
      lyr('G', 5, 'song', SyllableType.single, dur: DurationType.half),
      _r(DurationType.half), // rest ends any melisma
    ]),
  ]);
}

Staff _dynamicsSpectrum() {
  // One dynamic before each note (co-positioned with the following note),
  // covering full-word spellings, abbreviations, special accents, and a
  // word-based dynamic rendered as text.
  Note q(String s, int o) =>
      Note(pitch: Pitch(step: s, octave: o), duration: const Duration(DurationType.quarter));
  Dynamic d(DynamicType t, {bool hairpin = false}) =>
      Dynamic(type: t, isHairpin: hairpin);
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      d(DynamicType.pianissimo), q('C', 5),
      d(DynamicType.piano), q('D', 5),
      d(DynamicType.mezzoPiano), q('E', 5),
      d(DynamicType.mezzoForte), q('F', 5),
    ]),
    _measure([
      d(DynamicType.forte), q('E', 5),
      d(DynamicType.fortissimo), q('D', 5),
      d(DynamicType.fortePiano), q('C', 5),
      d(DynamicType.sforzando), q('D', 5),
    ]),
    _measure([
      d(DynamicType.niente), q('E', 5),
      d(DynamicType.rinforzando), q('F', 5),
      d(DynamicType.fff), q('G', 5),
      q('A', 5),
    ]),
  ]);
}

Staff _twoVoice() {
  final m = MultiVoiceMeasure();
  m.addVoice(Voice.voice1(elements: [
    Clef(clefType: ClefType.treble),
    TimeSignature(numerator: 4, denominator: 4),
    _n('E', 5),
    _n('F', 5),
    _n('G', 5),
    _n('A', 5),
  ]));
  m.addVoice(Voice.voice2(elements: [
    _n('C', 4, dur: DurationType.half),
    _n('B', 3, dur: DurationType.half),
  ]));
  return _staff([m]);
}

Staff _anacrusis() {
  // Pickup measure (single quarter) then a full bar.
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('G', 4), // anacrusis (under capacity)
    ]),
    _measure([
      _n('C', 5),
      _n('C', 5),
      _n('C', 5),
      _n('D', 5),
    ]),
  ]);
}

Staff _rests() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('C', 5),
      _r(DurationType.quarter, dots: 1), // dotted quarter rest
      _r(DurationType.eighth),
      _n('E', 5),
    ]),
    _measure([
      _r(DurationType.whole), // whole-measure rest, centered
    ]),
  ]);
}

// ---------------------------------------------------------------------------
// COMPLEX
// ---------------------------------------------------------------------------

Staff _mixedPhrase() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      KeySignature(-1), // F major
      TimeSignature(numerator: 4, denominator: 4),
      _n('F', 4, dur: DurationType.eighth, slur: SlurType.start),
      _n('A', 4, dur: DurationType.eighth),
      _n('C', 5, dur: DurationType.eighth),
      _n('F', 5, dur: DurationType.eighth, slur: SlurType.end),
      _n('E', 5, dur: DurationType.quarter, dots: 1, alter: 0.0),
      _n('D', 5, dur: DurationType.eighth, artic: [ArticulationType.staccato]),
    ]),
    _measure([
      _n('B', 4, alter: -1.0, dur: DurationType.quarter, artic: [ArticulationType.accent]),
      _n('A', 4, dur: DurationType.quarter),
      _n('G', 4, dur: DurationType.half, tie: TieType.start),
    ]),
    _measure([
      _n('G', 4, dur: DurationType.half, tie: TieType.end),
      _r(DurationType.half),
    ]),
  ]);
}

Staff _chromaticChords() {
  // Stress test for accidental stacking on adjacent staff lines (V3).
  // A leading quarter note gives each chord horizontal room so the accidental
  // column packing is visible (not crammed against the clef).
  Chord halfChord(List<Note> notes) =>
      Chord(notes: notes, duration: const Duration(DurationType.half));
  Note h(String s, int o, double a) => Note(
        pitch: Pitch(step: s, octave: o, alter: a),
        duration: const Duration(DurationType.half),
      );
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('C', 5, dur: DurationType.quarter),
      _r(DurationType.quarter),
      halfChord([h('D', 4, 1.0), h('F', 4, 1.0), h('A', 4, -1.0), h('C', 5, 1.0)]),
    ]),
    _measure([
      _n('C', 5, dur: DurationType.quarter),
      _r(DurationType.quarter),
      halfChord([h('E', 4, -1.0), h('G', 4, 1.0), h('B', 4, -1.0)]),
    ]),
  ]);
}

/// Soprano C-clef: the clef sits on the bottom line and C4 (its reference) is
/// read off that line, so a C-D-E-F-G run climbs from the bottom line up.
Staff _cClefPositions() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.soprano),
      TimeSignature(numerator: 4, denominator: 4),
      _n('C', 4),
      _n('E', 4),
      _n('G', 4),
      _n('B', 4),
    ]),
  ]);
}

/// Stacked articulations: multiple marks on one note stack outward (dot/tenuto
/// inner, accent/marcato outer) instead of overlapping.
Staff _stackedArticulations() {
  Note a(String s, int o, List<ArticulationType> arts) => _n(s, o, artic: arts);
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      a('G', 5, [ArticulationType.staccato, ArticulationType.accent]),
      a('G', 5, [ArticulationType.tenuto, ArticulationType.staccato]),
      a('G', 5, [ArticulationType.staccato, ArticulationType.strongAccent]),
      a('C', 4, [ArticulationType.staccato, ArticulationType.accent]),
    ]),
  ]);
}

/// Articulations beyond the basics — portato, snap pizzicato, brass stopped/
/// open/half-stopped, thumb — which previously rendered nothing.
Staff _extendedArticulations() {
  Note a(String s, int o, ArticulationType art) => _n(s, o, artic: [art]);
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 6, denominator: 4),
      a('E', 5, ArticulationType.portato),
      a('E', 5, ArticulationType.snap),
      a('E', 5, ArticulationType.stopped),
      a('E', 5, ArticulationType.open),
      a('E', 5, ArticulationType.halfStopped),
      a('E', 5, ArticulationType.thumb),
    ]),
  ]);
}

/// Multi-system wrap: a key-signature piece long enough to break across systems,
/// so the clef and key signature are restated at the start of each new line.
Staff _multiSystem() {
  final measures = <Measure>[];
  const steps = ['G', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'A', 'B', 'C', 'D'];
  for (var m = 0; m < 8; m++) {
    final els = <MusicalElement>[];
    if (m == 0) {
      els.add(Clef(clefType: ClefType.treble));
      els.add(KeySignature(1)); // G major (F#)
      els.add(TimeSignature(numerator: 4, denominator: 4));
    }
    for (var b = 0; b < 4; b++) {
      final s = steps[(m + b) % steps.length];
      els.add(_n(s, 4, dur: DurationType.quarter,
          alter: s == 'F' ? 1.0 : 0.0));
    }
    measures.add(_measure(els));
  }
  return _staff(measures);
}

/// Within-measure accidental persistence: a repeated altered pitch shows its
/// accidental once; reverting to natural shows a natural; the rule resets at the
/// barline.
Staff _withinMeasureAccidentals() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      _n('C', 5, alter: 1.0), // C#  -> sharp shown
      _n('C', 5, alter: 1.0), // C#  -> hidden (already sharp)
      _n('C', 5, alter: 0.0), // C   -> natural shown (cancels the sharp)
      _n('C', 5, alter: 0.0), // C   -> hidden (already natural)
    ]),
    _measure([
      _n('C', 5, alter: 1.0), // new measure -> sharp shown again
      _n('F', 4, alter: 1.0), // F# shown
      _n('F', 4, alter: 1.0), // hidden
      _r(DurationType.quarter),
    ]),
  ]);
}

/// Compound + multi-digit meters: 12/8 (two-digit numerator) and 6/8, to
/// verify multi-digit time-signature rendering and width reservation.
Staff _compoundMeter() {
  return _staff([
    _measure([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 12, denominator: 8),
      _n('G', 4, dur: DurationType.eighth, beam: BeamType.start),
      _n('A', 4, dur: DurationType.eighth, beam: BeamType.inner),
      _n('B', 4, dur: DurationType.eighth, beam: BeamType.end),
      _n('C', 5, dur: DurationType.eighth, beam: BeamType.start),
      _n('B', 4, dur: DurationType.eighth, beam: BeamType.inner),
      _n('A', 4, dur: DurationType.eighth, beam: BeamType.end),
    ]),
    _measure([
      TimeSignature(numerator: 6, denominator: 8),
      _n('G', 4, dur: DurationType.eighth, beam: BeamType.start),
      _n('A', 4, dur: DurationType.eighth, beam: BeamType.inner),
      _n('B', 4, dur: DurationType.eighth, beam: BeamType.end),
    ]),
  ]);
}

/// The full corpus, ordered simple → complex.
final List<CorpusCase> corpus = [
  CorpusCase(
    id: 's01_c_major_scale',
    title: 'C major scale (eighth notes, beamed)',
    tier: 'simple',
    exercises: 'spacing, beaming, ledger lines, stem direction',
    build: _cMajorScale,
    size: const Size(900, 240),
  ),
  CorpusCase(
    id: 's02_ode_to_joy',
    title: 'Ode to Joy (Beethoven) — matches paper figure',
    tier: 'simple',
    exercises: 'key signature, barlines, dotted+eighth+half, JSON import',
    build: _odeToJoy,
    staffSpace: 14.0,
    size: const Size(1100, 260),
  ),
  CorpusCase(
    id: 'm01_triads',
    title: 'Block triads',
    tier: 'intermediate',
    exercises: 'chord notehead stacking, stems',
    build: _triads,
  ),
  CorpusCase(
    id: 'm02_accidentals',
    title: 'Accidentals (single + in chords)',
    tier: 'intermediate',
    exercises: 'accidental placement and stacking in chords',
    build: _accidentals,
  ),
  CorpusCase(
    id: 'm03_augmentation_dots',
    title: 'Augmentation dots (line vs space)',
    tier: 'intermediate',
    exercises: 'dot vertical placement and clearance',
    build: _augmentationDots,
  ),
  CorpusCase(
    id: 'm04_triplets',
    title: 'Triplets (ascending + descending)',
    tier: 'intermediate',
    exercises: 'tuplet bracket + number, bracket angle',
    build: _triplets,
  ),
  CorpusCase(
    id: 'm04b_compound_meter',
    title: 'Compound meters (12/8, 6/8)',
    tier: 'intermediate',
    exercises: 'multi-digit time signature digits + width reservation',
    build: _compoundMeter,
  ),
  CorpusCase(
    id: 'm04c_articulations_extended',
    title: 'Extended articulations (portato, snap, brass mutes, thumb)',
    tier: 'intermediate',
    exercises: 'articulation glyph coverage beyond the basics',
    build: _extendedArticulations,
  ),
  CorpusCase(
    id: 'm04f_articulations_stacked',
    title: 'Stacked articulations (staccato+accent, etc.)',
    tier: 'intermediate',
    exercises: 'multiple articulations stack outward without overlap',
    build: _stackedArticulations,
  ),
  CorpusCase(
    id: 'm04g_c_clefs',
    title: 'C-clef / F-clef positions (soprano…baritone)',
    tier: 'intermediate',
    exercises: 'C/F clef vertical placement on lines 1-5',
    build: _cClefPositions,
    size: const Size(1000, 240),
  ),
  CorpusCase(
    id: 'm04d_within_measure_accidentals',
    title: 'Within-measure accidental persistence',
    tier: 'intermediate',
    exercises: 'accidental shown once/measure, natural cancel, barline reset',
    build: _withinMeasureAccidentals,
  ),
  CorpusCase(
    id: 'm04e_multi_system',
    title: 'Multi-system wrap (clef + key restated per system)',
    tier: 'intermediate',
    exercises: 'clef/key restatement at each new system',
    build: _multiSystem,
    staffSpace: 13.0,
    size: const Size(460, 360),
  ),
  CorpusCase(
    id: 'm05_slurs_ties',
    title: 'Slurs and ties',
    tier: 'intermediate',
    exercises: 'slur curve, tie curve, anchoring',
    build: _slursAndTies,
  ),
  CorpusCase(
    id: 'm06_articulations',
    title: 'Articulations',
    tier: 'intermediate',
    exercises: 'staccato/accent/tenuto/marcato placement',
    build: _articulations,
  ),
  CorpusCase(
    id: 'm07_dynamics',
    title: 'Dynamics',
    tier: 'intermediate',
    exercises: 'dynamics glyph placement below staff',
    build: _dynamics,
  ),
  CorpusCase(
    id: 'm07b_dynamics_spectrum',
    title: 'Dynamics spectrum (pp…fff, fp, sf, n, rfz)',
    tier: 'intermediate',
    exercises: 'complete DynamicType -> glyph mapping (V2)',
    build: _dynamicsSpectrum,
    size: const Size(1000, 240),
  ),
  CorpusCase(
    id: 'm11_lyrics',
    title: 'Lyrics with syllabification (hyphenated)',
    tier: 'intermediate',
    exercises: 'syllable text, hyphen on initial/middle syllables',
    build: _lyrics,
    size: const Size(900, 280),
  ),
  CorpusCase(
    id: 'm12_melisma',
    title: 'Melisma extension line',
    tier: 'intermediate',
    exercises: 'melisma line from a syllable over note-less notes (#13)',
    build: _melisma,
    size: const Size(900, 280),
  ),
  CorpusCase(
    id: 'm08_two_voice',
    title: 'Two-voice polyphony',
    tier: 'intermediate',
    exercises: 'voice stem direction + horizontal offset',
    build: _twoVoice,
  ),
  CorpusCase(
    id: 'm09_anacrusis',
    title: 'Anacrusis (pickup measure)',
    tier: 'intermediate',
    exercises: 'short first measure handling',
    build: _anacrusis,
  ),
  CorpusCase(
    id: 'm10_rests',
    title: 'Rests (incl. whole-measure rest)',
    tier: 'intermediate',
    exercises: 'rest vertical position, whole-measure centering',
    build: _rests,
  ),
  CorpusCase(
    id: 'c01_mixed_phrase',
    title: 'Mixed phrase (beams, accidentals, dots, slur, tie, rest)',
    tier: 'complex',
    exercises: 'combined engraving under realistic density',
    build: _mixedPhrase,
    size: const Size(1100, 260),
  ),
  CorpusCase(
    id: 'c02_chromatic_chords',
    title: 'Chromatic chords (accidental stacking stress test)',
    tier: 'complex',
    exercises: 'accidental stacking on adjacent staff lines',
    build: _chromaticChords,
  ),
];
