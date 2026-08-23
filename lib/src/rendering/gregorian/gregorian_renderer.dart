// Gregorian (square-notation) renderer using the Greciliae chant font.
//
// Greciliae (SIL OFL, from the Gregorio project) ships PRECOMPOSED neume glyphs
// designed by chant typographers — one glyph for a pes/clivis(flexus)/torculus/
// porrectus/scandicus of a given ambitus. We pick the glyph by NAME from the
// neume contour (the ambitus = diatonic step interval), place ONE glyph per
// neume at its first note, and assemble only the descending climacus from
// Punctum + PunctumInclinatum. Pitch is RELATIVE to the clef line (chant has no
// fixed pitch); the melodic contour is centered on the staff.
//
// The clef may CHANGE mid-chant: GABC lets a clef token appear anywhere, and
// `GabcParser` emits every clef after the first as a [ChantClefChange] element
// in the stream. `GregorianLayout.build` therefore tracks the active clef while
// it walks the elements and stores every glyph at a STAFF-ABSOLUTE position, so
// notes after a change stay on their real line instead of being drawn (and
// heard) transposed against the opening clef.

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';

import '../text_font.dart';
import 'chant_clef.dart';
import 'greciliae_font.dart';

// The chant clef model lives in its own Flutter-free library so the MIDI mapper
// can react to clef changes; it is re-exported here (and from chant_score.dart)
// so importers keep seeing ChantClef/ChantClefType/ChantClefChange.
export 'chant_clef.dart';

/// Visual configuration for the Gregorian renderer.
class GregorianTheme {
  final Color color;

  /// Pixels per staff space (≈ the inter-line gap).
  final double staffSpace;

  final double lyricSize;

  /// Text face for the chant syllables and word-internal hyphens.
  ///
  /// Null means "use the package text chain" — see
  /// `lib/src/rendering/text_font.dart`. That chain names four faces the package
  /// does NOT ship (`Academico`, `Century Schoolbook`, `Edwin`, `serif`), so on
  /// a host that provides none of them the syllables render as `.notdef` boxes:
  /// measured 2 solid box runs / 2235 filled px in the probe chant. Name a face
  /// here, or inject one process-wide with `MusicTextFont.use(...)`.
  final String? lyricTextFamily;

  const GregorianTheme({
    this.color = const Color(0xFF1A1A1A),
    this.staffSpace = 26.0,
    this.lyricSize = 15.0,
    this.lyricTextFamily,
  });
}

// ── Greciliae geometry calibration (font units; unitsPerEm = 1000) ──
//
// EVERY vertical metric here is MEASURED from the shipped font metrics
// (assets/gregorian/greciliae_glyphnames.json) rather than hardcoded, so that a
// future Greciliae release with different outlines re-calibrates itself instead
// of silently drifting off the staff:
//
//  * the diatonic step comes from GreciliaeFont.diatonicStepUnits(): the median
//    bbox-center increment across the precomposed PesTwo..PesFive glyphs,
//    doubled (raising the ambitus by one step lifts the center by half a step).
//    ≈157.5 units on the pinned font;
//  * the font scale is DERIVED from that step so the staff keeps its contract
//    `lineGap == theme.staffSpace`: one inter-line gap is two diatonic steps,
//    hence fontScale = unitsPerEm / (2 * unitsPerStep) ≈ 3.17;
//  * the first-note anchor is the Punctum's bbox center (≈66.5 units) — the
//    font-y that must land on the note's staff line/space.
//
// Hardcoding the step (it used to be 147.0, picked so the line gap matched a
// fixed 3.4 font scale) made the staff lines ≈7% tighter than the step BUILT
// INTO the precomposed neumes: an ambitus-4 neume ended up 42 units — about a
// third of the line-to-space distance — off its pitch (F-29).
//
// INVARIANT (asserted by [_assertPesProgression] in debug builds):
//   for every N in 3..5,
//     |centerY(Pes<N>) − centerY(Pes<N−1>) − unitsPerStep / 2| < 3 units.
//   N == 2 is excluded on purpose: PesOne's two notes touch, so it is drawn as
//   a different shape and its center sits ≈7.5 units off the progression.

/// Fallback anchor when the font has no Punctum metrics.
const double _firstNoteAnchorFallback = 70.0;

/// One diatonic step in font units, measured from [font].
double _unitsPerStepOf(GreciliaeFont font) {
  final step = font.diatonicStepUnits();
  assert(_assertPesProgression(font, step));
  return step;
}

/// Font scale (fontSize = staffSpace * this) that keeps one inter-line gap —
/// two diatonic steps of the font — exactly one `theme.staffSpace`.
double _fontScaleOf(GreciliaeFont font) =>
    GreciliaeFont.unitsPerEm / (2 * _unitsPerStepOf(font));

/// Font-y of a notehead's center above the glyph origin, used to seat a note on
/// its staff line/space.
double _firstNoteAnchorOf(GreciliaeFont font) =>
    font.centerYUnitsOrNull('Punctum') ?? _firstNoteAnchorFallback;

/// Debug-only check of the Pes progression invariant documented above.
bool _assertPesProgression(GreciliaeFont font, double unitsPerStep) {
  const family = ['PesTwoNothing', 'PesThreeNothing', 'PesFourNothing',
      'PesFiveNothing'];
  for (var i = 1; i < family.length; i++) {
    final lo = font.centerYUnitsOrNull(family[i - 1]);
    final hi = font.centerYUnitsOrNull(family[i]);
    if (lo == null || hi == null) continue;
    final drift = (hi - lo - unitsPerStep / 2).abs();
    if (drift >= 3.0) {
      throw StateError('Greciliae Pes progression off by '
          '${drift.toStringAsFixed(1)} units between ${family[i - 1]} and '
          '${family[i]} (step = ${unitsPerStep.toStringAsFixed(1)})');
    }
  }
  return true;
}

int _diatonic(String step, int octave) {
  const order = 'CDEFGAB';
  final i = order.indexOf(step.toUpperCase());
  return octave * 7 + (i < 0 ? 0 : i);
}

/// Diatonic value that sits ON the clef line: do-clef line = C4, fa-clef = F4
/// (octave 4 anchor, matching GabcParser._slotToPitch).
int _clefAnchorDiatonic(ChantClef clef) =>
    clef.type == ChantClefType.doClef ? _diatonic('C', 4) : _diatonic('F', 4);

const _words = ['Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven'];
String? _word(int n) => (n >= 1 && n < _words.length) ? _words[n] : null;

/// A single positioned glyph within a neume (placed so its first-note anchor
/// lands at staff position [step], at x offset [dx]).
///
/// [step] is measured in diatonic steps above the BOTTOM staff line, i.e. it is
/// absolute on the staff and independent of the clef. That matters because the
/// clef can change mid-score (see [ChantClefChange]): storing a clef-relative
/// step would make every glyph after a clef change land on the wrong line.
class _GlyphOp {
  final String name;
  final int step;
  final double dx;
  _GlyphOp(this.name, this.step, this.dx);
}

/// A rhythmic sign attached to one component (episema, ictus, mora dot).
enum _MarkType { episema, ictus, ictusAbove, mora }

class _Mark {
  final _MarkType type;
  final int step;

  /// Center-x of the mark within the neume box (px).
  final double dx;

  /// Notehead form under an episema, so the matching HEpisema glyph is chosen.
  final NcForm form;
  _Mark(this.type, this.step, this.dx, {this.form = NcForm.punctum});
}

class _NeumeBox {
  final List<_GlyphOp> glyphs;
  final List<_Mark> marks;
  final double width;
  final String? syllable;

  /// This syllable is joined to the next of the same word by a hyphen.
  final bool hyphen;

  /// Staff position (steps above the bottom line) of the box's first note —
  /// what the previous line's custos has to announce.
  final int firstStep;

  /// True when the box is a standalone accidental SIGN (flat/natural/sharp with
  /// no notehead). Such a box governs the notes that FOLLOW it, so a line break
  /// must never be taken between the sign and its note.
  final bool isAccidentalSign;

  double startX = 0;
  _NeumeBox(this.glyphs, this.marks, this.width, this.syllable, this.hyphen,
      this.firstStep, {this.isAccidentalSign = false});
  double get endX => startX + width;
}

class _Divisio {
  final NeumeDivisionType type;
  double x = 0;
  _Divisio(this.type);
}

/// A clef change drawn INSIDE a line (see [ChantClefChange]). When the change
/// falls on a line boundary it becomes that line's own leading clef instead and
/// is [suppressed] here, so the sign is never printed twice.
class _ClefBox {
  final ChantClef clef;
  final double width;
  double startX = 0;
  bool suppressed = false;
  _ClefBox(this.clef, this.width);
}

class _Row {
  final List<Object> items = []; // _NeumeBox | _Divisio | _ClefBox
  int? custosStep;
  double lineEnd = 0;

  /// Clef in force at the START of this line — the one drawn at its left edge.
  /// Lines after a mid-score clef change repeat the NEW clef, as Gregorio does.
  ChantClef clef = const ChantClef();
}

/// Accidental glyph name.
String _accidentalGlyph(NeumeAccidental a) => switch (a) {
      NeumeAccidental.flat => 'Flat',
      NeumeAccidental.natural => 'Natural',
      NeumeAccidental.sharp => 'Sharp',
      NeumeAccidental.none => 'Natural',
    };

/// Single-note glyph name by form.
String _singleGlyph(NcForm form) => switch (form) {
      NcForm.virga => 'Virga',
      NcForm.quilisma => 'Quilisma',
      NcForm.oriscus => 'AscendensOriscus',
      NcForm.stropha => 'Stropha',
      _ => 'Punctum',
    };

/// Picks the precomposed Greciliae glyph name for a neume, or null if it must be
/// assembled from components. When [liquescent], prefers the diminished
/// (`Deminutus`) variant — the epiphonus (pes), cephalicus (clivis), etc. —
/// falling back to the full (`Nothing`) form if that ambitus has no liquescent
/// glyph. The returned name is guaranteed present in [font].
String? _neumeGlyphName(NeumeType type, List<int> steps, List<NcForm> forms,
    bool liquescent, GreciliaeFont font) {
  int up(int i, int j) => steps[j] - steps[i];
  int dn(int i, int j) => steps[i] - steps[j];
  final suffix = liquescent ? 'Deminutus' : 'Nothing';
  String? pick(String shape, String? amb) {
    if (amb == null) return null;
    final want = '$shape$amb$suffix';
    if (font.has(want)) return want;
    final alt = '$shape${amb}Nothing';
    return font.has(alt) ? alt : null;
  }

  // A quilisma must keep its wavy glyph: the 2-note rising case is the
  // precomposed quilisma-pes; longer quilisma groups assemble (return null) so
  // the Quilisma glyph still shows instead of a plain scandicus/pes.
  if (forms.any((f) => f == NcForm.quilisma)) {
    if (steps.length == 2 && up(0, 1) > 0) {
      return pick('QuilismaPes', _word(up(0, 1)));
    }
    return null;
  }

  switch (type) {
    case NeumeType.pes:
      return pick('Pes', _word(up(0, 1)));
    case NeumeType.clivis:
      return pick('Flexus', _word(dn(0, 1)));
    case NeumeType.climacus:
      // Ordinary climacus assembles (virga + inclinata); the liquescent
      // (diminished) climacus is the precomposed Ancus.
      if (!liquescent || steps.length != 3) return null;
      final a = _word(dn(0, 1)), b = _word(dn(1, 2));
      return (a == null || b == null) ? null : pick('Ancus', '$a$b');
    case NeumeType.torculus:
      final a = _word(up(0, 1)), b = _word(dn(1, 2));
      return (a == null || b == null) ? null : pick('Torculus', '$a$b');
    case NeumeType.porrectus:
      final a = _word(dn(0, 1)), b = _word(up(1, 2));
      return (a == null || b == null) ? null : pick('Porrectus', '$a$b');
    case NeumeType.scandicus:
      final a = _word(up(0, 1)), b = _word(up(1, 2));
      return (a == null || b == null) ? null : pick('Scandicus', '$a$b');
    case NeumeType.salicus:
      final a = _word(up(0, 1)), b = _word(up(1, 2));
      return (a == null || b == null) ? null : pick('Salicus', '$a$b');
    case NeumeType.torculusResupinus:
      if (steps.length < 4) return null;
      final a = _word(up(0, 1)), b = _word(dn(1, 2)), c = _word(up(2, 3));
      return (a == null || b == null || c == null)
          ? null
          : pick('TorculusResupinus', '$a$b$c');
    case NeumeType.porrectusFlexus:
      if (steps.length < 4) return null;
      final a = _word(dn(0, 1)), b = _word(up(1, 2)), c = _word(dn(2, 3));
      return (a == null || b == null || c == null)
          ? null
          : pick('PorrectusFlexus', '$a$b$c');
    case NeumeType.quilismaGroup:
      if (steps.length == 2) return pick('QuilismaPes', _word(up(0, 1)));
      return null;
    default:
      return null;
  }
}

/// Emits the glyph ops + rhythmic marks for one neume using the [font].
_NeumeBox _emitNeume(
    Neume e, List<int> steps, GreciliaeFont font, double scale) {
  final forms = e.components.map((c) => c.form).toList();
  final comps = e.components;
  double advPx(String name) {
    final u = font.advanceUnits(name);
    return (u > 0 ? u : 166) * scale;
  }

  final noteW = advPx('Punctum');

  // Standalone accidental sign (no notehead): flat/natural/sharp at a staff
  // position, governing the following notes of the same pitch.
  if (comps.length == 1 && comps[0].accidental != NeumeAccidental.none) {
    final g = _accidentalGlyph(comps[0].accidental);
    final name = font.has(g) ? g : 'Punctum';
    return _NeumeBox([_GlyphOp(name, steps[0], 0)], const [], advPx(name),
        e.syllable, e.hyphenAfter, steps[0], isAccidentalSign: true);
  }

  // Build the glyph ops, the box width, and a center-x per component (px), used
  // to anchor the rhythmic marks.
  late final List<_GlyphOp> ops;
  late final List<double> compX;
  late final double width;

  if (steps.length == 1) {
    final name = e.type == NeumeType.virga ? 'Virga' : _singleGlyph(forms[0]);
    final g = font.has(name) ? name : 'Punctum';
    ops = [_GlyphOp(g, steps[0], 0)];
    width = advPx(g);
    compX = [width / 2];
  } else {
    // The liquescent (melting) note is the last of the neume; prefer the
    // diminished glyph when it is flagged liquescent.
    final last = comps.last;
    final liquescent = last.isLiquescent ||
        last.form == NcForm.liquescentAscending ||
        last.form == NcForm.liquescentDescending;
    final name = _neumeGlyphName(e.type, steps, forms, liquescent, font);
    if (name != null && font.has(name)) {
      // Precomposed single glyph: spread the component anchors across its width
      // (approximate — exact sub-glyph offsets are not exposed by the font).
      width = advPx(name);
      ops = [_GlyphOp(name, steps[0], 0)];
      final n = steps.length;
      compX = [for (var i = 0; i < n; i++) width * (i + 0.5) / n];
    } else {
      // Assemble glyph-per-note left to right. Descending steps use a punctum
      // inclinatum (diamond); the first note of a descending run is a virga.
      final o = <_GlyphOp>[];
      final cxs = <double>[];
      var cx = 0.0;
      for (var i = 0; i < steps.length; i++) {
        final descending = i > 0 && steps[i] < steps[i - 1];
        String g;
        if (descending) {
          g = font.has('DescendensPunctumInclinatum')
              ? 'DescendensPunctumInclinatum'
              : (font.has('PunctumInclinatumDeminutus')
                  ? 'PunctumInclinatumDeminutus'
                  : 'Punctum');
        } else if (i == 0 && steps.length > 1 && steps[1] < steps[0]) {
          g = 'Virga'; // climacus head
        } else {
          g = _singleGlyph(forms[i]);
          if (!font.has(g)) g = 'Punctum';
        }
        final w = advPx(g);
        o.add(_GlyphOp(g, steps[i], cx));
        cxs.add(cx + w / 2);
        // A climacus's descending inclinata tuck under the head/each other so
        // the run reads as one neume rather than detached puncta; same-pitch
        // repeated strophae (di/tristropha) also sit closer than puncta.
        final nextDescends = i + 1 < steps.length && steps[i + 1] < steps[i];
        final nextSameStropha = i + 1 < steps.length &&
            steps[i + 1] == steps[i] &&
            forms[i] == NcForm.stropha;
        // GABC fusion (`@`): the two notes are drawn as ONE fused figure, so
        // they touch instead of being spaced as independent puncta.
        final fused = i + 1 < comps.length && comps[i].connected;
        cx += w *
            (fused
                ? 0.62
                : (nextDescends ? 0.72 : (nextSameStropha ? 0.78 : 0.98)));
      }
      ops = o;
      compX = cxs;
      width = cx;
    }
  }

  // Rhythmic marks per component (episema bar, ictus tick, mora dot(s)).
  final marks = <_Mark>[];
  for (var i = 0; i < comps.length && i < compX.length; i++) {
    final c = comps[i];
    final x = compX[i];
    if (c.episema) {
      marks.add(_Mark(_MarkType.episema, steps[i], x, form: c.form));
    }
    if (c.ictus) {
      marks.add(_Mark(
          c.ictusAbove ? _MarkType.ictusAbove : _MarkType.ictus, steps[i], x));
    }
    for (var d = 0; d < c.morae; d++) {
      // Mora dot(s) sit to the right of the note; successive dots step further.
      marks.add(_Mark(_MarkType.mora, steps[i], x + noteW * (0.6 + d * 0.5)));
    }
  }

  return _NeumeBox(ops, marks, width, e.syllable, e.hyphenAfter, steps.first);
}

/// Builds and lays out chant as width-wrapped systems using [font].
///
/// The element stream may contain [ChantClefChange]s; the layout tracks the
/// active clef as it walks the elements, re-anchors the notes that follow, draws
/// the new sign in place, and repeats the new clef at the head of every
/// subsequent line.
class GregorianLayout {
  final List<_Row> _rows;

  /// The INITIAL clef of the chant (the one governing its first note). Later
  /// [ChantClefChange] elements do not change this field - each line records the
  /// clef in force where it starts.
  final ChantClef clef;
  final double clefX;
  final double width;
  final double staffSpace;
  final bool hasSyllables;

  int get rowCount => _rows.length;

  GregorianLayout._({
    required List<_Row> rows,
    required this.clef,
    required this.clefX,
    required this.width,
    required this.staffSpace,
    required this.hasSyllables,
  }) : _rows = rows;

  factory GregorianLayout.build(
    List<MusicalElement> elements,
    ChantClef clef,
    double maxWidth,
    GregorianTheme theme,
    GreciliaeFont font,
  ) {
    final sp = theme.staffSpace;
    final scale = sp * _fontScaleOf(font) / GreciliaeFont.unitsPerEm;

    // Vertical reference is the CLEF, not the melody: a do-clef makes its line
    // "do" (C4), an fa-clef "fa" (F4), matching GabcParser._slotToPitch.
    //
    // Because the clef may CHANGE mid-score (GABC allows a clef token anywhere;
    // GabcParser emits every later one as a [ChantClefChange]), positions are
    // stored STAFF-ABSOLUTE - diatonic steps above the bottom staff line -
    // instead of relative to one clef. A note `d` diatonic steps above the line
    // of a clef on line L therefore sits at `d + 2 * (L - 1)`, since consecutive
    // staff lines are two diatonic steps apart. Without this, everything after a
    // clef change would be drawn against the initial clef, i.e. transposed.
    var active = clef;
    var ref = _clefAnchorDiatonic(active);
    var lineOffset = 2 * (active.line - 1);

    final ordered = <Object>[];
    var hasSyllables = false;
    for (final e in elements) {
      if (e is Neume) {
        final steps = e.components.map((c) {
          final di = (c.pitchName != null && c.octave != null)
              ? _diatonic(c.pitchName!, c.octave!)
              : ref;
          return di - ref + lineOffset;
        }).toList();
        if (steps.isEmpty) continue;
        final box = _emitNeume(e, steps, font, scale);
        if (box.syllable != null && box.syllable!.isNotEmpty) hasSyllables = true;
        ordered.add(box);
      } else if (e is NeumeDivision) {
        ordered.add(_Divisio(e.type));
      } else if (e is ChantClefChange) {
        active = e.clef;
        ref = _clefAnchorDiatonic(active);
        lineOffset = 2 * (active.line - 1);
        final u = font.advanceUnits(active.glyphName);
        var w = (u > 0 ? u : 166) * scale;
        if (active.flat) w += sp * 0.8;
        ordered.add(_ClefBox(active, w));
      }
    }

    final clefX = sp * 0.3;
    final notesStartX = clefX + sp * 1.6;
    final gap = sp * 0.85;
    final divisioGap = sp * 0.9;
    final rightPad = sp * 1.4;
    final hardWidth = maxWidth.isFinite && maxWidth > sp * 10 ? maxWidth : 0.0;

    double itemWidth(Object o) => switch (o) {
          _NeumeBox b => b.width,
          _ClefBox c => c.suppressed ? 0.0 : c.width,
          _ => sp * 0.3,
        };

    // -- Line-breaking rule (Gregorio / Solesmes practice) -------------------
    //
    // The elements are first grouped into ATOMIC chunks; a line may only break
    // BETWEEN chunks. A chunk is opened by an element that starts a new reading
    // unit and absorbs everything that must stay glued to it:
    //
    //  1. never inside a neume - a neume is a single [_NeumeBox], so a box is
    //     indivisible by construction;
    //  2. never inside a syllable - a syllable may span several neumes (GABC
    //     writes them `a(gh/ij)` or `a(gh!ij)`); only the FIRST carries the
    //     lyric text, so a box without a syllable continues the previous one and
    //     is absorbed into its chunk;
    //  3. an accidental SIGN governs the notes after it, so it opens the chunk
    //     of the note it precedes rather than closing the previous one;
    //  4. prefer breaking AT a divisio: a divisio is absorbed by the chunk that
    //     precedes it, so a bar can never begin a line - it always terminates
    //     the line it ends, and the break naturally falls after it;
    //  5. a clef change opens a chunk of its own; if it lands at the head of a
    //     line it becomes that line's leading clef (see [_ClefBox.suppressed]).
    //
    // Word-internal breaks (between two hyphenated syllables) remain legal -
    // Gregorio breaks words across lines and prints the hyphen - so the rule is
    // about neumes and syllables, not whole words.
    final chunks = <List<Object>>[];
    var current = <Object>[];
    for (final o in ordered) {
      final opensUnit = o is _ClefBox ||
          (o is _NeumeBox &&
              !o.isAccidentalSign &&
              (o.syllable?.isNotEmpty ?? false));
      if (opensUnit && current.isNotEmpty) {
        // Rule 3: hand any trailing accidental signs to the new chunk.
        final pulled = <Object>[];
        while (current.isNotEmpty) {
          final last = current.last;
          if (last is _NeumeBox && last.isAccidentalSign) {
            pulled.insert(0, current.removeLast());
          } else {
            break;
          }
        }
        if (current.isNotEmpty) chunks.add(current);
        current = pulled;
      }
      current.add(o);
    }
    if (current.isNotEmpty) chunks.add(current);

    double chunkWidth(List<Object> c) => c.fold<double>(
        0, (a, o) => a + itemWidth(o) + (o is _Divisio ? divisioGap : gap));

    final rows = <_Row>[];
    var rowClef = clef;
    var row = _Row()..clef = rowClef;
    var cursor = notesStartX;
    var maxContent = notesStartX;
    for (final chunk in chunks) {
      final w = chunkWidth(chunk);
      if (hardWidth > 0 &&
          row.items.isNotEmpty &&
          cursor + w > hardWidth - rightPad) {
        rows.add(row);
        row = _Row()..clef = rowClef;
        cursor = notesStartX;
      }
      for (final o in chunk) {
        final head = row.items.isEmpty;
        row.items.add(o);
        if (o is _ClefBox) {
          if (head) {
            // The change coincides with a line start: print it once, as this
            // line's own leading clef.
            o.suppressed = true;
            row.clef = o.clef;
          }
          rowClef = o.clef;
        }
      }
      cursor += w;
      if (cursor > maxContent) maxContent = cursor;
    }
    if (row.items.isNotEmpty) rows.add(row);

    final fullWidth = hardWidth > 0 ? hardWidth : maxContent + rightPad;

    // Asymmetric breathing space around a divisio (Solesmes): more after the
    // bar than before, scaled by the bar's weight. A mid-line clef change gets
    // symmetric breathing room so it does not crowd the notes around it.
    double breathAfter(Object o) {
      if (o is _ClefBox) return o.suppressed ? 0 : sp * 0.45;
      if (o is! _Divisio) return 0;
      switch (o.type) {
        case NeumeDivisionType.minima:
          return sp * 0.35;
        case NeumeDivisionType.minor:
          return sp * 0.6;
        case NeumeDivisionType.maior:
          return sp * 0.95;
        case NeumeDivisionType.finalis:
          return sp * 1.1;
      }
    }

    double breathBefore(Object o) =>
        o is _ClefBox ? breathAfter(o) : breathAfter(o) * 0.4;

    for (var r = 0; r < rows.length; r++) {
      final items = rows[r].items;
      final isLast = r == rows.length - 1;
      final sumW = items.fold<double>(0, (a, o) => a + itemWidth(o));
      final breath = items.fold<double>(
          0, (a, o) => a + breathBefore(o) + breathAfter(o));
      final avail = (fullWidth - rightPad) - notesStartX;
      final g = (!isLast && items.length > 1 && avail > sumW + breath)
          ? (avail - sumW - breath) / items.length
          : gap;
      var x = notesStartX;
      for (final o in items) {
        x += breathBefore(o);
        if (o is _NeumeBox) {
          o.startX = x;
        } else if (o is _Divisio) {
          o.x = x;
        } else if (o is _ClefBox) {
          o.startX = x;
        }
        x += itemWidth(o) + g + breathAfter(o);
      }
      rows[r].lineEnd = isLast ? (x - g + rightPad * 0.4) : fullWidth;
    }

    // Custos: every line but the last ends with the pitch the NEXT line opens
    // on. It is dropped when the next line re-clefs, because the sign would be
    // read against a clef that no longer applies (Gregorio omits it there too).
    for (var i = 0; i < rows.length - 1; i++) {
      if (rows[i + 1].clef != rows[i].clef) continue;
      final next = rows[i + 1].items.whereType<_NeumeBox>();
      if (next.isNotEmpty) rows[i].custosStep = next.first.firstStep;
    }

    return GregorianLayout._(
      rows: rows,
      clef: clef,
      clefX: clefX,
      width: fullWidth,
      staffSpace: sp,
      hasSyllables: hasSyllables,
    );
  }

  double rowHeight() {
    final sp = staffSpace;
    return sp * 6.0 + (hasSyllables ? sp * 2.0 : 0.0);
  }

  double totalHeight() => _rows.length * rowHeight() + staffSpace;
}

/// Paints a [GregorianLayout] with Greciliae glyphs on a precise staff grid.
class GregorianPainter extends CustomPainter {
  final GregorianLayout layout;
  final GregorianTheme theme;
  final GreciliaeFont font;

  GregorianPainter({
    required this.layout,
    required this.theme,
    required this.font,
  });

  double get _sp => theme.staffSpace;

  /// All of these are derived from the font's own metrics (see the calibration
  /// note above): `_lineGap` stays equal to `theme.staffSpace` by construction,
  /// while `_halfStep` is the real half-step the precomposed neumes are drawn
  /// with, so glyph-internal pitch and staff pitch cannot diverge.
  double get _fontSize => _sp * _fontScaleOf(font);
  double get _scale => _fontSize / GreciliaeFont.unitsPerEm;
  double get _halfStep => _unitsPerStepOf(font) * _scale;
  double get _lineGap => 2 * _halfStep;

  double _lineY(double cy, int line) => cy + (1.5 - (line - 1)) * _lineGap;

  /// Vertical position of a STAFF-ABSOLUTE step: 0 sits on the bottom line and
  /// each diatonic step is half an inter-line gap, so the mapping does not
  /// depend on which clef is in force. Consecutive staff lines are two steps
  /// apart, hence the line of a clef on line L is at step `2 * (L - 1)` and a
  /// note `d` steps above that clef line is at `d + 2 * (L - 1)` (see
  /// [GregorianLayout.build]).
  double _staffY(double cy, int step) => _lineY(cy, 1) - step * _halfStep;

  /// Staff-absolute step of the line a [clef] sits on.
  static int _clefLineStep(ChantClef clef) => 2 * (clef.line - 1);

  /// Draws a chant clef (and its clef-flat, when any) with its sign centred on
  /// its staff line, starting at [x].
  ///
  /// The clef-flat (GABC `cb`/`fb`) is a soft si-flat in force like a key
  /// signature; it is engraved on the si line - one diatonic step below "do"
  /// for a do-clef, three above "fa" for an fa-clef.
  void _drawClef(Canvas canvas, ChantClef clef, double x, double cy) {
    final lineStep = _clefLineStep(clef);
    _glyph(canvas, clef.glyphName, x, _staffY(cy, lineStep),
        anchorUnits: font.centerYUnits(clef.glyphName));
    if (clef.flat) {
      final siSteps = clef.type == ChantClefType.doClef ? -1 : 3;
      _glyph(canvas, font.has('Flat') ? 'Flat' : 'Punctum', x + _sp * 0.8,
          _staffY(cy, lineStep + siSteps));
    }
  }

  /// Draws a Greciliae glyph by [name] so the font-y [anchorUnits] lands at
  /// (x, y). Notes use the first-note anchor; clef/custos register by bbox
  /// center so they sit centered on their line.
  void _glyph(Canvas canvas, String name, double x, double y,
      {double? anchorUnits}) {
    final ch = font.glyph(name);
    if (ch == null) return;
    final anchor = anchorUnits ?? _firstNoteAnchorOf(font);
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          fontFamily: 'Greciliae',
          package: 'flutter_notemus',
          fontSize: _fontSize,
          color: theme.color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final ascent = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(x, y - ascent + anchor * _scale));
  }

  /// Style shared by the syllable text and the word-internal hyphen.
  ///
  /// Routed through [MusicTextFallback.withMusicTextFallback] like every other
  /// text site in the package. Before 2.7.1 this style carried its OWN chain,
  /// `['Georgia', 'Times New Roman', 'serif']`, with a null primary family —
  /// which meant chant lyrics bypassed the package chain entirely. The pixel
  /// proof: rendering one chant four ways, varying only which text face was
  /// registered (nothing / 'Academico' / 'serif' / an app face), produced four
  /// BYTE-IDENTICAL PNGs with 20 solid `.notdef` boxes each — registering the
  /// face the package asks for could not reach this painter. The local chain is
  /// gone rather than merged because its three names are no more shipped than
  /// the package's four, and putting them first would have shadowed the
  /// injection point; an app that wants Georgia now says so, via
  /// [GregorianTheme.lyricTextFamily] or `MusicTextFont.use('Georgia')`.
  TextStyle get _lyricStyle => TextStyle(
        fontSize: theme.lyricSize,
        color: theme.color,
        fontFamily: theme.lyricTextFamily,
      ).withMusicTextFallback();

  void _lyric(Canvas canvas, String text, double centerX, double topY) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _lyricStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, topY));
  }

  /// X of the syllable text for a neume box (centred under its first note).
  double _syllableX(_NeumeBox box) {
    final firstW = box.glyphs.isEmpty
        ? _sp * 0.6
        : font.advanceUnits(box.glyphs.first.name) * _scale;
    return box.startX + firstW / 2;
  }

  /// X of the next syllable-bearing neume in [row] after [current], or null.
  double? _nextSyllableX(_Row row, _NeumeBox current) {
    var seen = false;
    for (final item in row.items) {
      if (identical(item, current)) {
        seen = true;
        continue;
      }
      if (seen && item is _NeumeBox && (item.syllable?.isNotEmpty ?? false)) {
        return _syllableX(item);
      }
    }
    return null;
  }

  /// Draws the word-internal hyphen(s) between two syllables of the same word.
  ///
  /// For a normal gap a single centred '-' is drawn. When the two syllables sit
  /// far apart (a long melisma between them), one dash leaves a large blank that
  /// visually splits the word, so — following GregorioTeX — the hyphen is
  /// repeated at a roughly constant pitch across the gap to keep the word
  /// together. [x1] and [x2] are the centres of the two syllable texts.
  void _hyphen(Canvas canvas, double x1, double x2, double topY) {
    final tp = TextPainter(
      text: TextSpan(text: '-', style: _lyricStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = tp.width;
    final sp = _sp;
    void paintAt(double cx) => tp.paint(canvas, Offset(cx - w / 2, topY));

    // Normal gap: a single centred hyphen (GregorioTeX's default).
    if (x2 - x1 <= sp * 5.0) {
      paintAt((x1 + x2) / 2);
      return;
    }

    // Far apart: repeat the hyphen across the gap. Inset from the syllable
    // centres so dashes don't sit under the glyphs, then place dashes at a
    // roughly constant pitch, distributed evenly edge-to-edge of the span.
    final spanStart = x1 + sp * 1.5;
    final spanEnd = x2 - sp * 1.5;
    final span = spanEnd - spanStart;
    if (span <= w) {
      paintAt((x1 + x2) / 2);
      return;
    }

    const pitchInSp = 3.0; // staff spaces between consecutive hyphens
    var count = (span / (sp * pitchInSp)).round() + 1;
    if (count < 2) count = 2;
    final step = span / (count - 1);
    for (var i = 0; i < count; i++) {
      paintAt(spanStart + step * i);
    }
  }

  /// Draws a rhythmic mark centered on a note at screen (cx, ny): a horizontal
  /// episema above, a vertical episema (ictus) below (or above), or a mora
  /// (augmentum) dot to the right at note height.
  void _drawMark(Canvas canvas, _MarkType type, double cx, double ny,
      {NcForm form = NcForm.punctum}) {
    final sp = _sp;
    final p = Paint()
      ..color = theme.color
      ..strokeWidth = sp * 0.09
      ..strokeCap = StrokeCap.round;
    const halfH = 0.4; // note half-height in staff spaces (Punctum ≈ 0.4 sp)
    switch (type) {
      case _MarkType.mora:
        // Engraved augmentum dot (Greciliae AuctumMora); fall back to a drawn
        // dot if the glyph is unavailable.
        if (font.has('AuctumMora')) {
          final w = font.advanceUnits('AuctumMora') * _scale;
          _glyph(canvas, 'AuctumMora', cx - w / 2, ny,
              anchorUnits: font.centerYUnits('AuctumMora'));
        } else {
          canvas.drawCircle(
              Offset(cx, ny), sp * 0.13, Paint()..color = theme.color);
        }
        break;
      case _MarkType.episema:
        final y = ny - sp * (halfH + 0.18);
        // Shape-specific engraved episema (Greciliae HEpisema* matching the
        // notehead form); geometric bar as fallback.
        final name = switch (form) {
          NcForm.virga => 'HEpisemaVirga',
          NcForm.quilisma => 'HEpisemaQuilisma',
          _ => 'HEpisemaPunctum',
        };
        final glyph = font.has(name)
            ? name
            : (font.has('HEpisemaPunctum') ? 'HEpisemaPunctum' : null);
        if (glyph != null) {
          final w = font.advanceUnits(glyph) * _scale;
          _glyph(canvas, glyph, cx - w / 2, y,
              anchorUnits: font.centerYUnits(glyph));
        } else {
          canvas.drawLine(
              Offset(cx - sp * 0.34, y), Offset(cx + sp * 0.34, y), p);
        }
        break;
      case _MarkType.ictus:
        final y0 = ny + sp * (halfH + 0.04);
        canvas.drawLine(Offset(cx, y0), Offset(cx, y0 + sp * 0.45), p);
        break;
      case _MarkType.ictusAbove:
        final y0 = ny - sp * (halfH + 0.04);
        canvas.drawLine(Offset(cx, y0), Offset(cx, y0 - sp * 0.45), p);
        break;
    }
  }

  /// Draws a divisio (chant pause bar) as a geometric stroke. Greciliae's
  /// Divisio* glyphs have unstable bounding boxes (and no Finalis), so the bars
  /// are drawn directly: minima cuts the top space, minor the upper half, maior
  /// the whole staff, finalis a double full bar (end of piece).
  void _drawDivisio(
      Canvas canvas, NeumeDivisionType t, double x, double cy, Paint p) {
    final top = _lineY(cy, 4);
    final l3 = _lineY(cy, 3);
    final l2 = _lineY(cy, 2);
    final bottom = _lineY(cy, 1);
    switch (t) {
      case NeumeDivisionType.minima:
        canvas.drawLine(Offset(x, top), Offset(x, l3), p);
        break;
      case NeumeDivisionType.minor:
        canvas.drawLine(Offset(x, top), Offset(x, l2), p);
        break;
      case NeumeDivisionType.maior:
        canvas.drawLine(Offset(x, top), Offset(x, bottom), p);
        break;
      case NeumeDivisionType.finalis:
        canvas.drawLine(Offset(x, top), Offset(x, bottom), p);
        canvas.drawLine(
            Offset(x + _sp * 0.3, top), Offset(x + _sp * 0.3, bottom), p);
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!font.isLoaded) return;
    final sp = _sp;
    final rowHeight = layout.rowHeight();
    final linePaint = Paint()
      ..color = theme.color
      ..strokeWidth = sp * 0.06
      ..strokeCap = StrokeCap.butt;
    final barPaint = Paint()
      ..color = theme.color
      ..strokeWidth = sp * 0.09;

    for (var r = 0; r < layout.rowCount; r++) {
      final row = layout._rows[r];
      final cy = r * rowHeight + sp * 3.0;

      for (var ln = 1; ln <= 4; ln++) {
        final y = _lineY(cy, ln);
        canvas.drawLine(Offset(0, y), Offset(row.lineEnd, y), linePaint);
      }

      // Every line repeats the clef in force where it STARTS, so a chant that
      // re-clefs mid-piece carries the new clef on the following lines.
      _drawClef(canvas, row.clef, layout.clefX, cy);

      final lyricTop = _lineY(cy, 1) + sp * 1.1;

      for (final item in row.items) {
        if (item is _Divisio) {
          _drawDivisio(canvas, item.type, item.x, cy, barPaint);
          continue;
        }
        if (item is _ClefBox) {
          // A clef change inside the line. When it fell on a line boundary the
          // line's leading clef already shows it, so it is suppressed here.
          if (!item.suppressed) _drawClef(canvas, item.clef, item.startX, cy);
          continue;
        }
        final box = item as _NeumeBox;
        for (final op in box.glyphs) {
          _glyph(canvas, op.name, box.startX + op.dx, _staffY(cy, op.step));
        }
        for (final mk in box.marks) {
          var ny = _staffY(cy, mk.step);
          // The mora dot belongs in a space; when the note sits on a line
          // (odd step in this grid) raise the dot into the space above it.
          if (mk.type == _MarkType.mora && mk.step.isOdd) ny -= _halfStep;
          _drawMark(canvas, mk.type, box.startX + mk.dx, ny, form: mk.form);
        }
        if (box.syllable != null && box.syllable!.isNotEmpty) {
          // The syllable centres under the FIRST note of its neume (Solesmes
          // underlay), not under the whole neume box.
          final syllX = _syllableX(box);
          _lyric(canvas, box.syllable!, syllX, lyricTop);
          // Word-internal hyphen: connect to the next syllable in this row.
          if (box.hyphen) {
            final next = _nextSyllableX(row, box);
            if (next != null) _hyphen(canvas, syllX, next, lyricTop);
          }
        }
      }

      if (row.custosStep != null) {
        // The custos marks the next line's first pitch; its note-head seats on
        // the step like a note (the tail flourishes up/down from there), so it
        // uses the note anchor rather than the bbox center.
        // Direction and length are read RELATIVE to the line's clef (the
        // reference the singer reads the custos against).
        final rel = row.custosStep! - _clefLineStep(row.clef);
        final up = rel >= 0;
        // Pick the length variant by how far the next pitch reaches from the
        // staff centre (Gregorio: short within the staff, longer for big leaps).
        final reach = rel.abs();
        final size = reach <= 5 ? 'Short' : (reach <= 9 ? 'Medium' : 'Long');
        final g0 = '${up ? 'CustosUp' : 'CustosDown'}$size';
        final g = font.has(g0) ? g0 : 'Punctum';
        _glyph(canvas, g, row.lineEnd - sp * 1.0, _staffY(cy, row.custosStep!));
      }
    }
  }

  @override
  bool shouldRepaint(covariant GregorianPainter old) =>
      old.layout != layout || old.theme != theme;
}
