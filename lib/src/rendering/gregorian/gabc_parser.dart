// GABC import (Gregorio chant format) — Tier B.
//
// Parses a .gabc string into the chant model (ChantClef + a flat list of
// Neume/NeumeDivision) for the Gregorian renderer. Grounded in the Gregorio
// GABC spec (see doc/GREGORIAN_RESEARCH.json):
//   * header lines "field: value;" until a line that is exactly "%%", then a
//     stream of `syllable(notes)` tokens (whitespace separates words);
//   * pitch letters a..m are STAFF SLOTS relative to the clef (a lowest), never
//     absolute pitches — resolved HERE to a real diatonic pitch under the clef
//     in force (see [GabcParser._slotToPitch]), so `ChantMidiMapper` can sound
//     them and a mid-score clef change re-anchors everything after it;
//   * clefs c1..c4 (do) / f1..f4 (fa), optional clef-flat (cb/fb); the first
//     clef token is the score's clef, every later one becomes a
//     [ChantClefChange] element in the stream (document order);
//   * note shapes: lowercase = punctum, UPPER = punctum inclinatum, v = virga,
//     w = quilisma, o = oriscus, s = stropha;
//   * modifiers: ~ deminutus (liquescent), < / > liquescence, . mora, _ episema,
//     ' ictus, accidentals x/y/#;
//   * compound neumes auto-classified from the melodic contour;
//   * divisiones ` , ; : :: and spaces !, /, //;
//   * fusion `@` between neumes (Gregorio 4.1+): the notes on either side are
//     welded into ONE neume and the joint is flagged `NeumeComponent.connected`
//     so the renderer draws them touching;
//   * `nabc` (adiastematic St. Gall/Laon notation) written after a `|` inside a
//     note token is IGNORED — the pipe and everything after it are dropped so
//     nabc letters can never be mistaken for pitches;
//   * `%` comments to end of line inside the score body.
//
// One syllable group may contain several neumes separated by chant spaces; the
// syllable text attaches to the first.
//
// STILL UNSUPPORTED (parsed defensively, never fatal):
//   * the SECOND clef of a double clef (`c3@c1`): only the first is used, the
//     second is reported in `GabcResult.unsupported`;
//   * nabc CONTENT — it is discarded, not rendered on an nabc line;
//   * `z`/`Z` (explicit line/page break), `[...]` braces (choral signs, custom
//     spacing, verses, translations), `<sp>`/`<v>` verbatim text macros beyond
//     the tag stripping done by [GabcParser._cleanText], the `-` initio
//     debilis, `r` cavum, numbered episema variants (`_0`.. `_5`) and the
//     `<eu>`/`<nlba>` block markers: all are skipped without breaking the
//     surrounding neume.

import 'package:flutter_notemus/core/musical_element.dart';
import 'package:flutter_notemus/core/neume.dart';

// Only the clef model is needed here, and it lives in a Flutter-free library,
// so GABC import stays usable outside a UI (CLI tools, tests, MIDI export).
import 'chant_clef.dart';

/// Result of parsing a GABC document.
class GabcResult {
  /// The INITIAL clef (the first clef token of the document). Kept for
  /// compatibility: mid-score clef changes are elements, not fields — look for
  /// [ChantClefChange] inside [elements].
  final ChantClef clef;

  final List<MusicalElement> elements;
  final Map<String, String> headers;

  /// Human-readable notes about GABC constructs that were recognised but not
  /// implemented (the second half of a double clef, discarded nabc, ...). Empty
  /// when the document used nothing outside the supported subset.
  final List<String> unsupported;

  const GabcResult(this.clef, this.elements, this.headers,
      {this.unsupported = const <String>[]});
}

class GabcParser {
  static GabcResult parse(String gabc) {
    final headers = <String, String>{};

    // 1. Split header block from the score on a line that is exactly "%%".
    final lines = gabc.split('\n');
    var sep = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() == '%%') {
        sep = i;
        break;
      }
    }
    final headerLines = sep >= 0 ? lines.sublist(0, sep) : const <String>[];
    // GABC comments run from a `%` to the end of the line; strip them before
    // the score lines are joined, or a comment would be read as lyrics/notes.
    final body = (sep >= 0 ? lines.sublist(sep + 1) : lines)
        .map(_stripComment)
        .join(' ');
    for (final line in headerLines) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        headers[line.substring(0, idx).trim()] =
            line.substring(idx + 1).replaceAll(';', '').trim();
      }
    }

    // 2. Walk `text(notes)` tokens. Pitch is resolved against the active clef,
    // which may CHANGE mid-score: the first clef token is the document's clef
    // (reported by GabcResult.clef) and every later one is emitted as a
    // [ChantClefChange] element so the renderer re-anchors the staff and the
    // MIDI mapper picks up the new clef-flat.
    var clef = const ChantClef();
    var firstClef = clef;
    var sawClef = false;
    final elements = <MusicalElement>[];
    final unsupported = <String>[];
    final token = RegExp(r'([^()\s]*)\(([^)]*)\)');
    final matches = token.allMatches(body).toList();
    for (var mi = 0; mi < matches.length; mi++) {
      final m = matches[mi];
      final text = _cleanText(m.group(1) ?? '');
      var notes = (m.group(2) ?? '').trim();

      // `nabc`: adiastematic notation written after a `|` inside the token
      // (enabled by the `nabc-lines` header). It uses its own alphabet, several
      // of whose letters collide with GABC pitch letters, so it MUST be dropped
      // before anything else looks at the token.
      final bar = notes.indexOf('|');
      if (bar >= 0) {
        final nabc = notes.substring(bar + 1).trim();
        notes = notes.substring(0, bar).trim();
        if (nabc.isNotEmpty && !unsupported.contains(_nabcNote)) {
          unsupported.add(_nabcNote);
        }
      }

      final clefMatch = _clefRe.firstMatch(notes);
      if (clefMatch != null) {
        final next = ChantClef(
          type: clefMatch.group(1) == 'c'
              ? ChantClefType.doClef
              : ChantClefType.faClef,
          line: int.parse(clefMatch.group(3)!),
          flat: clefMatch.group(2) == 'b',
        );
        // Double clef (`c3@c1`): Gregorio draws two clefs for two-choir
        // notation. Only the first governs the pitches here.
        if (clefMatch.group(4) != null && !unsupported.contains(_doubleClefNote)) {
          unsupported.add(_doubleClefNote);
        }
        if (!sawClef) {
          firstClef = next;
          sawClef = true;
        } else if (next != clef) {
          elements.add(ChantClefChange(next));
        }
        clef = next;
        continue;
      }

      // Hyphenation: a syllable joins the next with a hyphen when the next token
      // is also a syllable and there is NO whitespace between them in the source
      // (GABC writes a word's syllables contiguously; whitespace = word break).
      var hyphenAfter = false;
      if (text.isNotEmpty && mi + 1 < matches.length) {
        final next = matches[mi + 1];
        final between = body.substring(m.end, next.start);
        if (!between.contains(RegExp(r'\s')) &&
            _cleanText(next.group(1) ?? '').isNotEmpty) {
          hyphenAfter = true;
        }
      }

      _parseSyllable(notes, text, elements, clef, hyphenAfter);
    }

    return GabcResult(sawClef ? firstClef : clef, elements, headers,
        unsupported: List<String>.unmodifiable(unsupported));
  }

  /// Clef token: `c1..c4` / `f1..f4`, optional `b` for the clef-flat, plus the
  /// optional second half of a DOUBLE clef (`c3@c1`), which is recognised so it
  /// cannot be mistaken for notes but is otherwise ignored.
  static final RegExp _clefRe =
      RegExp(r'^([cf])(b?)([1-4])(?:@([cf])(b?)([1-4]))?$');

  static const String _nabcNote =
      'nabc (adiastematic notation after `|`) was discarded.';
  static const String _doubleClefNote =
      'double clef (`c3@c1`): only the first clef was applied.';

  /// Drops a `%` comment (to end of line) from one GABC source line.
  static String _stripComment(String line) {
    final i = line.indexOf('%');
    return i < 0 ? line : line.substring(0, i);
  }

  /// Maps a GABC staff slot (a=0 .. m=12, the vertical position) to a real
  /// diatonic pitch under [clef]. The note letters are positions RELATIVE to the
  /// clef, not absolute names: a do-clef makes its line "do" (C), an fa-clef
  /// makes its line "fa" (F); the natural diatonic scale is then walked so the
  /// E-F and B-C semitones land on the correct lines for that clef.
  ///
  /// Convention (documented; chant has no fixed pitch, so the octave is only a
  /// default register adjustable downstream): the 4 staff lines sit at slots
  /// {3,5,7,9} (clefSlot = 2*line+1), centring the a..m range on the staff, and
  /// the clef line is anchored at octave 4.
  static ({String step, int octave}) _slotToPitch(int slot, ChantClef clef) {
    const anchorOctave = 4;
    final clefSlot = 2 * clef.line + 1;
    final degree = slot - clefSlot; // diatonic steps above the clef line
    final base = clef.type == ChantClefType.doClef ? 0 : 3; // C or F index
    final diatonicNumber = anchorOctave * 7 + base + degree;
    final stepIndex = diatonicNumber % 7; // Dart % is non-negative here
    final octave = (diatonicNumber - stepIndex) ~/ 7;
    return (step: 'CDEFGAB'[stepIndex], octave: octave);
  }

  /// Strips GABC text-layer markup (`<i>..</i>`, `<sp>..</sp>`, `*`, etc.).
  static String _cleanText(String t) => t
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'[*{}]'), '')
      .trim();

  /// Parses the note string of one syllable group into neumes/divisiones.
  static void _parseSyllable(
    String rawNotes,
    String syllable,
    List<MusicalElement> out,
    ChantClef clef,
    bool hyphenAfter,
  ) {
    if (rawNotes.isEmpty) return;

    // FUSION (Gregorio `@`): `@` welds the notes on either side into a single
    // graphical neume. Because fusion beats spacing, any chant space written
    // next to the operator (`g/@hi`, `g@!hi`, `g @ hi`) is absorbed here, so the
    // fused group always ends up inside ONE segment below and therefore in ONE
    // [Neume]. The joint itself is flagged on the left-hand component
    // (`NeumeComponent.connected`) by [_buildNeume].
    final notes = rawNotes.replaceAll(_fusionRe, '@');
    if (notes.isEmpty) return;

    // Split into segments on chant spaces (/, //, !) — each becomes a neume.
    // Divisio characters are emitted as their own elements in order.
    var assignedSyllable = false;
    final segment = StringBuffer();

    void flushSegment() {
      final s = segment.toString();
      segment.clear();
      if (s.trim().isEmpty) return;
      // Only the neume that actually carries the syllable gets the hyphen.
      final elems = _buildNeume(s, assignedSyllable ? null : syllable, clef,
          assignedSyllable ? false : hyphenAfter);
      if (elems.isNotEmpty) {
        out.addAll(elems);
        assignedSyllable = true;
      }
    }

    for (var i = 0; i < notes.length; i++) {
      final c = notes[i];
      switch (c) {
        case ':':
          flushSegment();
          // "::" = finalis, ":" = maior.
          if (i + 1 < notes.length && notes[i + 1] == ':') {
            out.add(NeumeDivision(type: NeumeDivisionType.finalis));
            i++;
          } else {
            out.add(NeumeDivision(type: NeumeDivisionType.maior));
          }
        case ';':
          flushSegment();
          out.add(NeumeDivision(type: NeumeDivisionType.minor));
        case ',':
          flushSegment();
          out.add(NeumeDivision(type: NeumeDivisionType.minima));
        case '`':
          flushSegment();
          out.add(NeumeDivision(type: NeumeDivisionType.minima));
        case '/':
        case '!':
        case ' ':
          flushSegment();
        default:
          segment.write(c);
      }
    }
    flushSegment();
  }

  /// Builds the elements of a single note segment (no spaces/divisiones).
  ///
  /// Returns a list because a segment can interleave accidental SIGNS
  /// (pitch + `x`/`y`/`#`) with note neumes: each accidental is emitted as its
  /// own standalone element (no notehead), flushing any pending notes first so
  /// the sign precedes the notes it governs.
  ///
  /// SOFT ACCIDENTAL SCOPE (Gregorio): `x` (flat), `y` (natural) and `#`
  /// (sharp) are written at a staff position and hold from that point **to the
  /// end of the word, or to the next divisio, whichever comes first**. The sign
  /// itself is only a mark on the staff, so the scope is applied where the
  /// pitches are sounded — see `ChantMidiMapper`, which resets its table at
  /// every divisio and at every word start (a word start being the first
  /// syllable after one whose `hyphenAfter` is false).
  static List<MusicalElement> _buildNeume(
      String seg, String? syllable, ChantClef clef, bool hyphenAfter) {
    final result = <MusicalElement>[];
    var comps = <NeumeComponent>[];
    var steps = <int>[];
    var hasInclinatum = false;
    var syllableUsed = false;

    void flushNotes() {
      if (comps.isEmpty) return;
      final carriesSyllable = !syllableUsed;
      result.add(Neume(
        type: _classify(steps, hasInclinatum, comps),
        components: comps,
        syllable: carriesSyllable ? syllable : null,
        hyphenAfter: carriesSyllable && hyphenAfter,
      ));
      syllableUsed = true;
      comps = <NeumeComponent>[];
      steps = <int>[];
      hasInclinatum = false;
    }

    var i = 0;
    while (i < seg.length) {
      final ch = seg[i];
      final lower = ch.toLowerCase();
      final code = lower.codeUnitAt(0);
      final isPitch = code >= 0x61 && code <= 0x6d; // a..m
      if (!isPitch) {
        i++;
        continue;
      }
      final idx = code - 0x61; // 0..12 (staff slot, a lowest)
      final (step: step, octave: octave) = _slotToPitch(idx, clef);
      final upper = ch != lower; // uppercase = punctum inclinatum

      var form = NcForm.punctum;
      var episema = false;
      var ictus = false;
      var liquescent = false;
      var morae = 0;
      var accidental = NeumeAccidental.none;
      var fused = false;

      // Consume trailing shape/modifier characters bound to this pitch.
      i++;
      while (i < seg.length) {
        final mod = seg[i];
        final mlow = mod.toLowerCase();
        final mcode = mlow.codeUnitAt(0);
        if (mcode >= 0x61 && mcode <= 0x6d) break; // next pitch
        switch (mod) {
          case 'v':
          case 'V':
            form = NcForm.virga;
          case 'w':
            form = NcForm.quilisma;
          case 'o':
          case 'O':
            form = NcForm.oriscus;
          case 's':
            form = NcForm.stropha;
          case '~':
          case '<':
          case '>':
            liquescent = true;
          case '_':
            episema = true;
          case "'":
            ictus = true;
          case '.':
            morae++;
          case 'x':
            accidental = NeumeAccidental.flat;
          case 'y':
            accidental = NeumeAccidental.natural;
          case '#':
            accidental = NeumeAccidental.sharp;
          case '@':
            // Fusion joint: this note is welded to the next one.
            fused = true;
          default:
            break; // unknown/unsupported modifiers are skipped, never fatal
        }
        i++;
      }

      if (accidental != NeumeAccidental.none) {
        // Standalone accidental sign at this staff position.
        flushNotes();
        result.add(Neume(
          type: NeumeType.custom,
          components: [
            NeumeComponent(
              pitchName: step,
              octave: octave,
              accidental: accidental,
            ),
          ],
        ));
        continue;
      }

      if (upper) hasInclinatum = true;
      comps.add(NeumeComponent(
        pitchName: step,
        octave: octave,
        form: form,
        isLiquescent: liquescent,
        connected: fused,
        episema: episema,
        ictus: ictus,
        morae: morae,
      ));
      steps.add(idx);
    }

    flushNotes();
    return result;
  }

  /// Chant space(s) adjacent to a fusion operator — absorbed by the fusion.
  static final RegExp _fusionRe = RegExp(r'[\s/!]*@[\s/!]*');

  /// Classifies a neume from its melodic contour (and shapes).
  static NeumeType _classify(
    List<int> steps,
    bool hasInclinatum,
    List<NeumeComponent> comps,
  ) {
    final n = steps.length;
    if (n == 1) {
      return comps.first.form == NcForm.virga
          ? NeumeType.virga
          : NeumeType.punctum;
    }
    // Repeated notes at the same pitch: bivirga / trivirga (repeated virgae);
    // repeated puncta/strophae have no dedicated enum value and stay custom.
    if (steps.every((s) => s == steps[0])) {
      if (comps.every((c) => c.form == NcForm.virga)) {
        if (n == 2) return NeumeType.bivirga;
        if (n == 3) return NeumeType.trivirga;
      }
      return NeumeType.custom;
    }
    if (n == 2) {
      return steps[1] > steps[0] ? NeumeType.pes : NeumeType.clivis;
    }
    if (n == 3) {
      final a = steps[1] - steps[0];
      final b = steps[2] - steps[1];
      if (a > 0 && b > 0) {
        // Three rising notes with an oriscus in the middle are a salicus;
        // otherwise a scandicus.
        return comps[1].form == NcForm.oriscus
            ? NeumeType.salicus
            : NeumeType.scandicus;
      }
      if (a < 0 && b < 0) return NeumeType.climacus;
      if (a > 0 && b < 0) return NeumeType.torculus;
      if (a < 0 && b > 0) return NeumeType.porrectus;
    }
    if (n == 4) {
      final a = steps[1] - steps[0];
      final b = steps[2] - steps[1];
      final c = steps[3] - steps[2];
      if (a > 0 && b < 0 && c > 0) return NeumeType.torculusResupinus;
      if (a < 0 && b > 0 && c < 0) return NeumeType.porrectusFlexus;
      if (a > 0 && b > 0 && c < 0) return NeumeType.scandicusFlexus;
      if (a < 0 && b < 0 && c > 0) return NeumeType.climacusResupinus;
    }
    // Descending runs with inclinata read as a climacus.
    if (hasInclinatum &&
        n >= 3 &&
        List.generate(n - 1, (k) => steps[k + 1] <= steps[k]).every((x) => x)) {
      return NeumeType.climacus;
    }
    return NeumeType.custom;
  }
}
