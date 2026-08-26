// test/invariants/adr005_guard_test.dart
//
// ADR-005, made executable.
//
// ADR-005 ("a layout decision is a value owned by the layout result, never a
// mutation of the model") is a CONVENTION, and its own "honest residue"
// section says so:
//
//   > Nothing in the type system stops a future contributor from writing
//   > `note.beam = ...` inside the engine again, and nothing stops a renderer
//   > from READING `note.beam` and quietly drawing no beam.
//
// BOTH halves of that prediction fired inside the very wave that landed the
// ADR, and the second one is the worst defect of the whole remediation
// programme.
//
// `GrandStaffPainter` kept reading `note.beam` straight off the model in two
// places - the cross-staff relocation predicate (`grand_staff_painter.dart:227`
// at the time) and the cross-staff beam-run scanner (`:854`). The engine had
// stopped writing that field, so both read `null` for every note,
// `_crossStaffGroups` returned ZERO runs, and NO CROSS-STAFF BEAM WAS DRAWN
// ANYWHERE IN THE PACKAGE.
//
// Measured on four quavers in the right hand with the middle two sent to the
// left hand, after `GrandStaffPainter.alignedSystem(0)`:
//
//     modelBeams  = [null, null, null, null]      <- what the painter read
//     engineBeams = [start, end, start, end]      <- what the engine decided
//
// and on the raster:
//
//     | quantity                                    | broken | fixed  |
//     |---------------------------------------------|--------|--------|
//     | total ink                                    | 15 840 | 14 457 |
//     | longest horizontal run across the staff gap  |     41 |    115 |
//
// The ink went UP while the drawing got WORSE: every note printed a loose flag
// where a beam belonged. Not one of 963 tests and 53 goldens noticed.
//
// TWO independent audit waves diagnosed it correctly, and each wrote the exact
// patch into the `notes` field of its report. Nobody applied it. It survived to
// the final audit. A report is not executable. This file is.
//
// ADR-005 action item 7.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ===========================================================================
// THE ALLOW-LIST
// ===========================================================================
//
// Every place in `lib/` that is permitted to touch the MODEL'S beam field
// (`Note.beam` / `Chord.beam`), with the reason it is allowed. Nothing else in
// `lib/` may mention it; everything else must go through
// `LayoutEngine.beamOf(note)` or the `LayoutEngine.beams` /
// `LayoutEngine.tupletBeams` maps.
//
// An entry is (file, pattern, count, why). The pattern is matched against the
// SOURCE LINE the mention sits on, so it survives edits elsewhere in the file
// but pins the SHAPE of the sanctioned expression; `count` pins how many
// mentions that file is allowed. Both have to be updated by hand, which is the
// whole point - adding a reader of `Note.beam` must show up in review as an
// edit to this list, next to a written justification, and never as a silent
// line in a renderer.
//
// `count` is `null` on the two entries whose sanctioned expression is an
// ordinary inline test rather than a uniquely named accessor - there the SHAPE
// is the guarantee and the multiplicity is not, because the same safe
// expression legitimately recurs (`spacing_engine` asks it once per element
// kind). Everywhere else the count is exact, which is the stronger form: those
// reads live in a single named helper by construction, so a second occurrence
// means somebody added a new reader.
//
// The categories that are legitimate, and only these:
//
//   1. the MODEL declaring its own field;
//   2. the PARSERS and EXPORTERS, which serialise the author's hint - keeping
//      that serialisation a pure function of the model is the entire reason
//      ADR-005 stopped the engine writing it;
//   3. `LayoutEngine.beamOf`, which IS the documented author-hint fallback,
//      plus the one place per renderer that implements the same fallback
//      locally because it can be driven without an engine;
//   4. hand-authored beams (`BeamingMode.manual`), where the author's hint is
//      the truth and there is nothing for the engine to have decided;
//   5. a read of a value the ENGINE ITSELF put there on a throw-away object it
//      owns (never on the caller's model).
const List<_Allowed> _allowList = <_Allowed>[
  // --- 1. the model declaring the field -----------------------------------
  _Allowed(
    'lib/core/note.dart',
    r'^this\.beam,$',
    1,
    'The constructor parameter that DECLARES the field. Note.beam is public '
        'API and stays writable: ADR-005 narrows its meaning to "input hint", '
        'it does not remove it, because BeamingMode.manual rests on it.',
  ),
  _Allowed(
    'lib/core/chord.dart',
    r'^this\.beam,$',
    1,
    'Ditto for Chord.',
  ),

  // --- 2. parsers and exporters -------------------------------------------
  _Allowed(
    'lib/src/parsers/json_exporter.dart',
    r'note\.beam',
    2,
    'Serialises the AUTHORS hint. This is the read whose fidelity ADR-005 '
        'exists to protect: while the engine stamped its answer here, two bars '
        'of loose quavers exported 3 349 chars / 0 <beam> tags fresh and 3 973 '
        'chars / 16 tags after a layout() call.',
  ),
  _Allowed(
    'lib/src/parsers/musicxml_parser.dart',
    r'note\.beam',
    2,
    'Emits <beam> elements from the authors hint, same contract as the JSON '
        'exporter.',
  ),
  _Allowed(
    'lib/src/parsers/parser_support.dart',
    r'beam: last\.beam,',
    2,
    'Carries the hint across a note being split/merged during import. A parser '
        'SETS Note.beam; that is the input side of the field and is exactly '
        'what ADR-005 preserves.',
  ),

  // --- 3. beamOf, and the per-renderer local fallback ----------------------
  _Allowed(
    'lib/src/layout/layout_engine.dart',
    r'beams\[note\] \?\? tupletBeams\[note\] \?\? note\.beam;',
    1,
    'IS LayoutEngine.beamOf - the single documented read, and the one place '
        'the precedence "engine decision, else author hint" is stated.',
  ),
  _Allowed(
    'lib/src/rendering/renderers/group_renderer.dart',
    r'beamTypes\?\[note\] \?\? note\.beam;',
    1,
    'GroupRenderer can be driven with no engine (it takes the beams map as an '
        'optional parameter), so it re-implements beamOfs exact precedence '
        'locally. Same expression, same order, one line.',
  ),
  _Allowed(
    'lib/src/rendering/staff_renderer.dart',
    r'_beams\?\[note\] \?\? note\.beam;',
    1,
    'Same as GroupRenderer: StaffRenderer._beamOf is the local mirror of '
        'LayoutEngine.beamOf for the no-engine path.',
  ),
  _Allowed(
    'lib/src/interaction/score_hit_tester.dart',
    r'engine\?\.beamOf\(note\) \?\? note\.beam',
    1,
    'ScoreHitTester.engine is optional, so ScoreHitTester._noteIsBeamed is the '
        'same local mirror. It used to be a bare "element.beam != null", which '
        'silently changed the meaning of the public selection API the day the '
        'engine stopped writing the field.',
  ),
  _Allowed(
    'lib/src/interaction/score_hit_tester.dart',
    r'_chordIsBeamed\(Chord chord\) => chord\.beam != null;',
    1,
    'Category 4, for a Chord. Both engine maps are Map<Note, BeamType> and '
        'BeamGrouper groups Notes only, so no Chord ever appears in either: '
        'the authors hint is the whole of what is knowable here. Named and '
        'documented rather than inlined, so the next reader does not mistake '
        'it for the stale read it replaced.',
  ),
  _Allowed(
    'lib/core/tuplet_bracket.dart',
    r'_authorBeamHint\(Note note\) => note\.beam;',
    1,
    'TupletBracket.shouldShow now TAKES the layout decision as a parameter; '
        'this is the fallback it uses when given none, and it is deliberately '
        'the same expression as beamOfs fallback half. core/ cannot see the '
        'layout, so there is nothing better to fall back to.',
  ),

  // --- 4. hand-authored beams ---------------------------------------------
  _Allowed(
    'lib/src/rendering/renderers/note_renderer.dart',
    r'note\.beam == null\)',
    1,
    'Honours a HAND-AUTHORED beam: a caller who set Note.beam themselves and '
        'renders a bare note gets its flag suppressed. The ENGINEs decision '
        'reaches this renderer as renderOnlyNotehead, resolved by '
        'StaffRenderer through _beamOf - "!renderOnlyNotehead && '
        'note.beam == null" is the conjunction of the two.',
  ),
  _Allowed(
    'lib/src/rendering/renderers/chord_renderer.dart',
    r'chord\.beam == null',
    1,
    'The authors hint is the ONLY beam information a Chord has: both engine '
        'maps are Map<Note, BeamType> and BeamGrouper groups Notes only, so no '
        'Chord ever appears in either. The engine-driven case arrives as '
        'suppressStem / suppressFlag from TupletRenderer instead.',
  ),

  // --- 5. a value the engine put on its own throw-away object --------------
  _Allowed(
    'lib/src/layout/spacing/spacing_engine.dart',
    r'element\.beam != null',
    null,
    'IntelligentSpacingEngine is handed either an explicit isBeamed override '
        'or a throw-away stand-in the engine built itself; it never sees the '
        'callers own Note here. Without one of those routes the optical '
        'compensator would space every automatically beamed note as if it were '
        'flagged - measured at 17 647 changed pixels and 10 px of extra reach '
        'on two bars of loose eighths.',
  ),
  _Allowed(
    'lib/src/layout/layout_engine.dart',
    r'element\.beam',
    null,
    'LayoutEngine.structuralHash hashes the MODEL, on purpose: it answers '
        '"are these two scores the same music?", and the authors beam hint is '
        'part of the music. Hashing the engines own decision instead would '
        'make the hash depend on the layout width.',
  ),
];

/// Directories in which ASSIGNING to the model's beam field is a build error.
///
/// ADR-005's decision, in one sentence: *the layout pass may not write a layout
/// decision back onto the model.* These are the two trees the ADR names.
const List<String> _writeForbiddenDirs = <String>[
  'lib/src/layout/',
  'lib/src/rendering/',
];

void main() {
  group('ADR-005 guard - layout decisions are values, not model writes', () {
    test('nothing in layout/ or rendering/ ASSIGNS to the model beam field',
        () {
      final offenders = <String>[];
      for (final file in _libDartFiles()) {
        if (!_writeForbiddenDirs.any(file.path.startsWith)) continue;
        for (final mention in _beamMentions(file.source)) {
          if (!mention.isWrite) continue;
          offenders.add('  ${file.path}:${mention.line}\n    ${mention.code}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'ADR-005: a layout decision is a VALUE owned by the layout '
            'result, never a mutation of the model.\n'
            'These sites write the model from inside the layout/render path:\n'
            '${offenders.join('\n')}\n\n'
            'Publish the decision instead - put it in a '
            'Map<Note, BeamType>.identity() on LayoutEngine next to '
            '`beams` / `tupletBeams`, and read it through '
            'LayoutEngine.beamOf(note).\n'
            'Writing Note.beam changes what the USERS OWN EXPORT produces: '
            'measured 0 -> 16 <beam> tags and 3 349 -> 3 973 characters of '
            'MusicXML from a single layout() call, plus 32 writes for 16 notes '
            'because the measuring dry run walks the same code.',
      );
    });

    test('every READ of the model beam field is on the allow-list', () {
      final offenders = <String>[];
      for (final file in _libDartFiles()) {
        for (final mention in _beamMentions(file.source)) {
          final allowed = _allowList.any(
            (entry) => entry.file == file.path && entry.matches(mention.code),
          );
          if (allowed) continue;
          offenders.add('  ${file.path}:${mention.line}\n    ${mention.code}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'ADR-005: Note.beam / Chord.beam carry the AUTHORS HINT and '
            'nothing else. Since 2.7.2 the engine no longer writes there, so a '
            'bare read returns null for every automatically beamed note and '
            'the code silently draws nothing.\n'
            'Unsanctioned reads:\n${offenders.join('\n')}\n\n'
            'Use LayoutEngine.beamOf(note) (engine decision, else author '
            'hint), or the LayoutEngine.beams / LayoutEngine.tupletBeams maps '
            'directly. A renderer that may run without an engine should mirror '
            'beamOfs precedence in ONE named helper, as StaffRenderer._beamOf '
            'and GroupRenderer.beamOf do.\n'
            'If the read really is legitimate, add it to _allowList at the top '
            'of this file WITH ITS REASON - that edit is the review.\n\n'
            'This is the exact defect that removed every cross-staff beam from '
            'the package for four waves: grand_staff_painter.dart read '
            'note.beam in two places and got [null, null, null, null] where '
            'the engine held [start, end, start, end].',
      );
    });

    test('the allow-list has no stale entries', () {
      final sources = <String, String>{
        for (final file in _libDartFiles()) file.path: file.source,
      };
      for (final entry in _allowList) {
        final source = sources[entry.file];
        expect(
          source,
          isNotNull,
          reason: 'allow-list entry points at a file that no longer exists: '
              '${entry.file}. Delete the entry.',
        );
        final hits =
            _beamMentions(source!).where((m) => entry.matches(m.code)).length;
        expect(
          hits,
          entry.count == null ? greaterThanOrEqualTo(1) : equals(entry.count),
          reason: 'allow-list drift in ${entry.file}: the sanctioned '
              'expression /${entry.pattern}/ was measured $hits time(s), '
              'recorded as ${entry.count ?? "one or more"}.\n'
              'Reason on file: ${entry.why}\n'
              'Update the count (and the reason) deliberately, or route the '
              'new site through LayoutEngine.beamOf.',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // The guard guarding the guard.
  //
  // A scanner that silently matches nothing passes every test in this file and
  // is worth exactly zero. These pin its behaviour on synthetic sources, so a
  // regression in the comment stripper cannot quietly disarm the two tests
  // above.
  // -------------------------------------------------------------------------
  group('ADR-005 guard - the scanner itself', () {
    test('a bare read is detected', () {
      final mentions = _beamMentions('bool f(Note n) => n.beam != null;');
      expect(mentions, hasLength(1));
      expect(mentions.single.isWrite, isFalse);
      expect(mentions.single.line, 1);
    });

    test('an assignment is detected, and counts as a write', () {
      for (final source in ['note.beam = BeamType.start;', 'note.beam ??= b;']) {
        final mentions = _beamMentions(source);
        expect(mentions, hasLength(1), reason: source);
        expect(mentions.single.isWrite, isTrue, reason: source);
      }
    });

    test('an equality test is a read, not a write', () {
      expect(_beamMentions('if (a.beam == b) {}').single.isWrite, isFalse);
    });

    test('prose about note.beam in a comment is not a read', () {
      // Why this matters: grand_staff_painter.dart now carries five dartdoc
      // paragraphs ABOUT note.beam and not one read of it. A scanner that
      // cannot tell prose from code is unusable, and an unusable guard gets
      // switched off.
      const source = '''
/// The run is read through [LayoutEngine.beamOf], never off `note.beam`
/// (see ADR-005): note.beam is null for every engine-decided note.
// note.beam = BeamType.start;
/* note.beam */
void f() {}
''';
      expect(_beamMentions(source), isEmpty);
    });

    test('a string literal mentioning note.beam is not a read', () {
      expect(_beamMentions("var s = 'note.beam is a hint';"), isEmpty);
    });

    test('a type-qualified .beam is not a read of the model field', () {
      // CollisionCategory.beam (bounding_box_adapter.dart) is an enum value
      // that happens to share the name. A receiver beginning with a capital is
      // a type, and a type has no model state to read.
      expect(_beamMentions('return CollisionCategory.beam;'), isEmpty);
      expect(_beamMentions('return element.beam;'), hasLength(1));
    });

    test('longer members that merely start with "beam" are not reads', () {
      const source = 'x.beamCount + y.beams.length + z.beamingMode.index '
          '+ w.beamOf(n).hashCode + v.beamSegments.length;';
      expect(_beamMentions(source), isEmpty);
    });

    test('the scanner reaches lib/, and accounts for every mention in it', () {
      // Pins the walk itself. If _libDartFiles ever returns nothing - a
      // renamed directory, a different CWD under another runner - every test
      // above passes vacuously, which is exactly the failure mode this file
      // exists to prevent.
      final files = _libDartFiles();
      expect(files.length, greaterThan(50));
      final total = files.fold<int>(
        0,
        (sum, f) => sum + _beamMentions(f.source).length,
      );
      // Only the exactly-counted entries can be summed; the two shape-pinned
      // ones contribute at least one each. The point of the assertion is that
      // the scanner is finding real code at all, so a floor is enough.
      final floor = _allowList.fold<int>(0, (sum, e) => sum + (e.count ?? 1));
      expect(total, greaterThanOrEqualTo(floor));
      expect(total, greaterThan(0));
    });
  });
}

// ===========================================================================
// Machinery
// ===========================================================================

/// One sanctioned family of mentions of the model's beam field.
class _Allowed {
  /// Package-relative path, forward slashes.
  final String file;

  /// Regex the SOURCE LINE must match for the mention to be sanctioned.
  final String pattern;

  /// How many mentions in [file] this entry accounts for, or `null` when the
  /// sanctioned thing is the expression SHAPE and its multiplicity is not
  /// pinned (see the note on [_allowList]). `null` still requires at least one
  /// match, so a dead entry is caught.
  final int? count;

  /// Why this read is legitimate. Read by humans; the test only prints it.
  final String why;

  const _Allowed(this.file, this.pattern, this.count, this.why);

  bool matches(String line) => RegExp(pattern).hasMatch(line);
}

class _SourceFile {
  final String path;
  final String source;
  const _SourceFile(this.path, this.source);
}

List<_SourceFile> _libDartFiles() => [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          _SourceFile(
            entity.path.replaceAll(r'\', '/'),
            entity.readAsStringSync(),
          ),
    ];

/// One mention of the model's beam field in real code.
class _Mention {
  final int line;

  /// The trimmed SOURCE line, for the failure message.
  final String code;

  /// True when the mention is the target of an assignment (`=`, `??=`).
  final bool isWrite;

  const _Mention(this.line, this.code, this.isWrite);
}

final RegExp _beamMember = RegExp(r'\.beam\b');
final RegExp _beamWrite = RegExp(r'\.beam\s*(\?\?)?=(?![=>])');
final RegExp _identifierTail = RegExp(r'[A-Za-z0-9_$]+$');

/// Every mention of `<expression>.beam` in [source] that is real code.
///
/// Comments and string literals are blanked first - `grand_staff_painter.dart`
/// alone carries five dartdoc paragraphs about `note.beam` and zero reads of
/// it, so a scanner that cannot tell prose from code is useless. A mention
/// whose receiver starts with a capital letter (`CollisionCategory.beam`) is a
/// type-qualified access, not a field read, and is skipped.
List<_Mention> _beamMentions(String source) {
  final code = _stripCommentsAndStrings(source);
  final rawLines = source.split('\n');
  final lines = code.split('\n');
  final result = <_Mention>[];
  for (var i = 0; i < lines.length; i++) {
    for (final match in _beamMember.allMatches(lines[i])) {
      final before = lines[i].substring(0, match.start);
      final receiver = _identifierTail.firstMatch(before)?.group(0);
      if (receiver != null &&
          receiver[0].toUpperCase() == receiver[0] &&
          receiver[0].toLowerCase() != receiver[0]) {
        continue; // SomeType.beam - an enum value or a static, not the field
      }
      final raw = i < rawLines.length ? rawLines[i].trim() : lines[i].trim();
      result.add(_Mention(i + 1, raw, _beamWrite.hasMatch(lines[i])));
    }
  }
  return result;
}

/// [source] with every comment and string literal replaced by spaces, line
/// structure preserved so line numbers stay true.
String _stripCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  void blank(String ch) => out.write(ch == '\n' ? '\n' : ' ');
  while (i < source.length) {
    final ch = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (ch == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        blank(source[i]);
        i++;
      }
      continue;
    }
    if (ch == '/' && next == '*') {
      var depth = 0;
      while (i < source.length) {
        if (source[i] == '/' && i + 1 < source.length && source[i + 1] == '*') {
          depth++;
          blank(source[i]);
          blank(source[i + 1]);
          i += 2;
          continue;
        }
        if (source[i] == '*' && i + 1 < source.length && source[i + 1] == '/') {
          depth--;
          blank(source[i]);
          blank(source[i + 1]);
          i += 2;
          if (depth <= 0) break;
          continue;
        }
        blank(source[i]);
        i++;
      }
      continue;
    }
    if (ch == "'" || ch == '"') {
      final triple = source.startsWith(ch * 3, i);
      final terminator = triple ? ch * 3 : ch;
      for (var k = 0; k < terminator.length; k++, i++) {
        blank(source[i]);
      }
      while (i < source.length && !source.startsWith(terminator, i)) {
        if (source[i] == r'\' && i + 1 < source.length) {
          blank(source[i]);
          blank(source[i + 1]);
          i += 2;
          continue;
        }
        blank(source[i]);
        i++;
      }
      for (var k = 0; k < terminator.length && i < source.length; k++, i++) {
        blank(source[i]);
      }
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}
