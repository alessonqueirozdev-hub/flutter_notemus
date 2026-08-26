// test/invariants/text_painter_provenance_test.dart
//
// A STRUCTURAL guard over `lib/`: every `TextPainter` this package builds must
// either be a SMuFL/Greciliae GLYPH painter (which names the music font
// descriptor and must NOT be diverted to a text face) or receive a `TextStyle`
// that has passed through `MusicTextFallback.withMusicTextFallback`.
//
// Why a source-walking test and not a pixel test
// ----------------------------------------------
// `lib/src/rendering/text_font.dart` states the rule in a dartdoc and the
// 2.7.1 remediation applied it by hand. Two sites were missed —
// `symbol_and_text_renderer.dart:863` (the 8va/8vb label) and `:945` (the
// volta/bracket label) — and BOTH forensic audits missed them too: the 2.7.0
// audit did not look, and the 2.7.1 re-audit listed seven offending FILES from
// a coarse per-file grep and therefore could not see two stragglers inside a
// file that already used the helper eight times. They only turned up in an
// exhaustive per-call-site sweep, which is what this test automates.
//
// A pixel test cannot replace this. Measured while writing it: in a headless
// `flutter test` binary none of the four faces named by
// `kMusicTextFontFallback` resolves, so a style that bypasses the chain and one
// that honours it rasterise to BYTE-IDENTICAL PNGs — the re-audit hit exactly
// this wall and had to record its own finding as "Evidence B, visual impact not
// proven". The rule is a property of the SOURCE, so the source is what this
// test reads. The behavioural half of the same claim (N-16) is proven
// separately, by font injection, in `remediation_2_7_1_gaps_test.dart`.
//
// What counts as "resolved"
// -------------------------
// The style expression at each call site is followed through the file:
//
//   1. `.withMusicTextFallback()` written at the call site;
//   2. a `TextStyle` member (`TextStyle _x() {…}` / `TextStyle get _x => …`)
//      whose body applies it;
//   3. a local `final x = <expr>;` in the enclosing member, resolved again;
//   4. a `TextStyle` PARAMETER of the enclosing member — a pass-through helper
//      such as `_drawText` — in which case every call site of that member in
//      the same file must pass a style that resolves by rules 1-3.
//
// Anything else fails, and the failure message names file, line and the style
// expression, so the fix is a one-liner.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One `TextPainter(` construction found in `lib/`.
class _Site {
  final String path;
  final int line;

  /// Character offset of the opening parenthesis, used to look at the code
  /// that follows a painter whose span is assigned later.
  final int offset;

  /// The text between the `TextPainter(` parentheses, balanced.
  final String args;

  /// Name of the class member (or top-level function) that contains it.
  final String enclosing;

  _Site(this.path, this.line, this.offset, this.args, this.enclosing);

  @override
  String toString() => '$path:$line (in $enclosing)';
}

/// Matches a style that names the loaded SMuFL/chant font descriptor.
///
/// `BaseGlyphRenderer`'s "Font independence" note forbids naming a music family
/// literally, so every glyph painter reads `<something>.font.fontFamily` off the
/// metadata. Greciliae is the single documented exception (the chant renderer
/// owns its font and says so).
final RegExp _musicFont = RegExp(
  r"font\.fontFamily|fontFamily:\s*'Greciliae'",
);

/// Extracts the balanced-parenthesis text starting at [open], which must be the
/// index of the `(`.
String _balanced(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final ch = source[i];
    if (ch == '(') depth++;
    if (ch == ')') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return source.substring(open + 1);
}

/// Declaration of a class member or top-level function.
final RegExp _member = RegExp(
  r'^\s{0,2}(?:@\w+\s+)?(?:static\s+)?(?:[\w<>,\s\?\[\]]+\s+)?'
  r'(?:get\s+)?([_$A-Za-z][_$A-Za-z0-9]*)\s*(?:\(|=>|\s*\{)',
);

const Set<String> _keywords = {
  'if', 'for', 'while', 'switch', 'return', 'else', 'catch', 'do',
  'class', 'enum', 'mixin', 'extension', 'typedef', 'import', 'export',
};

String _enclosingMember(List<String> lines, int lineIndex) {
  for (var i = lineIndex; i >= 0; i--) {
    final line = lines[i];
    if (line.startsWith('    ')) continue; // too deep to be a member header
    final match = _member.firstMatch(line);
    if (match == null) continue;
    final name = match.group(1)!;
    if (_keywords.contains(name)) continue;
    return name;
  }
  return '<top level>';
}

/// The `style:` argument text of a `TextSpan`/`TextPainter` argument blob.
String? _styleExpression(String args) {
  final at = args.indexOf('style:');
  if (at < 0) return null;
  var depth = 0;
  final buffer = StringBuffer();
  for (var i = at + 'style:'.length; i < args.length; i++) {
    final ch = args[i];
    if (ch == '(' || ch == '[' || ch == '{') depth++;
    if (ch == ')' || ch == ']' || ch == '}') {
      if (depth == 0) break;
      depth--;
    }
    if (ch == ',' && depth == 0) break;
    buffer.write(ch);
  }
  return buffer.toString().trim();
}

final RegExp _headIdentifier = RegExp(r'^[_$A-Za-z][_$A-Za-z0-9]*');

/// Full body of the member named [name] — brace-matched for a block body,
/// terminated at the first top-level `;` for an `=>` body.
///
/// A fixed-size window is not enough: `_resolveMusicTextStyle` in
/// `symbol_and_text_renderer.dart` is a 70-line switch that puts its
/// `.withMusicTextFallback()` on the LAST line, 2.8 KB past its declaration.
String? _memberBody(String source, String name, {String? returnType}) {
  // A DECLARATION, never a call: the name must be preceded either by a type
  // token (`void _drawText(`) or by `get`. A call site such as
  // `      _drawText(` has only whitespace in front of it and is skipped —
  // which matters, because the first `_drawText(` in
  // `symbol_and_text_renderer.dart` is a call 900 lines above the declaration.
  final prefix = returnType == null
      ? r'(?:[\w>\]?]\s+|get\s+)'
      : '(?:${RegExp.escape(returnType)}[?]?\\s+(?:get\\s+)?)';
  final decl = RegExp(
    '$prefix${RegExp.escape(name)}\\s*(?:\\(|=>|\\{)',
  ).firstMatch(source);
  if (decl == null) return null;
  var i = decl.start;
  var depth = 0;
  while (i < source.length) {
    if (source.startsWith('=>', i) && depth == 0) {
      final end = source.indexOf(';', i);
      return source.substring(decl.start, end < 0 ? source.length : end);
    }
    final ch = source[i];
    if (ch == '(') depth++;
    if (ch == ')') depth--;
    if (ch == '{' && depth == 0) break;
    if (ch == ';' && depth == 0) return source.substring(decl.start, i);
    i++;
  }
  if (i >= source.length) return null;
  var braces = 0;
  for (var j = i; j < source.length; j++) {
    if (source[j] == '{') braces++;
    if (source[j] == '}') {
      braces--;
      if (braces == 0) return source.substring(decl.start, j + 1);
    }
  }
  return source.substring(decl.start);
}

/// Splits a comma-separated argument/parameter list at bracket depth 0.
List<String> _splitTopLevel(String text) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == '(' || ch == '[' || ch == '{' || ch == '<') depth++;
    if (ch == ')' || ch == ']' || ch == '}' || ch == '>') depth--;
    if (ch == ',' && depth == 0) {
      parts.add(buffer.toString().trim());
      buffer.clear();
      continue;
    }
    buffer.write(ch);
  }
  if (buffer.toString().trim().isNotEmpty) {
    parts.add(buffer.toString().trim());
  }
  return parts;
}

/// Parameter list of [member], or null.
String? _parameterList(String source, String member) {
  final body = _memberBody(source, member);
  if (body == null) return null;
  final open = body.indexOf('(');
  if (open < 0) return null;
  return _balanced(body, open);
}

bool _hasTextStyleParameter(String parameters, String name) =>
    RegExp('TextStyle[?]?\\s+${RegExp.escape(name)}\\b').hasMatch(parameters);

/// Index of the `TextStyle` parameter called [name] among the POSITIONAL
/// parameters of a member, or -1 when it is named / absent.
int _positionalTextStyleIndex(String parameters, String name) {
  final positional = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < parameters.length; i++) {
    final ch = parameters[i];
    if ((ch == '{' || ch == '[') && depth == 0) break; // named/optional section
    if (ch == '(' || ch == '<' || ch == '{' || ch == '[') depth++;
    if (ch == ')' || ch == '>' || ch == '}' || ch == ']') depth--;
    if (ch == ',' && depth == 0) {
      positional.add(buffer.toString().trim());
      buffer.clear();
      continue;
    }
    buffer.write(ch);
  }
  if (buffer.toString().trim().isNotEmpty) {
    positional.add(buffer.toString().trim());
  }
  for (var i = 0; i < positional.length; i++) {
    if (RegExp('TextStyle[?]?\\s+${RegExp.escape(name)}\$')
        .hasMatch(positional[i])) {
      return i;
    }
  }
  return -1;
}

/// Every argument passed for the parameter [name] at each call of [member].
///
/// Handles both spellings: a named argument (`style: _tempoTextStyle()`) and a
/// positional one (`_drawRehearsalEnclosure(canvas, label, position, style)`).
List<({String expression, String enclosing})> _argumentsFor(
  String source,
  List<String> lines,
  String member,
  String name,
  int positionalIndex,
) {
  final result = <({String expression, String enclosing})>[];
  final declBody = _memberBody(source, member);
  final declStart = declBody == null ? -1 : source.indexOf(declBody);
  final declParenthesis = declStart < 0 ? -1 : source.indexOf('(', declStart);
  for (final match
      in RegExp('${RegExp.escape(member)}\\s*\\(').allMatches(source)) {
    final open = match.end - 1;
    if (open == declParenthesis) continue; // the declaration, not a call
    final line = '\n'.allMatches(source.substring(0, open)).length;
    final caller = _enclosingMember(lines, line);
    final args = _splitTopLevel(_balanced(source, open));
    final named = args.firstWhere(
      (a) => a.startsWith('$name:'),
      orElse: () => '',
    );
    if (named.isNotEmpty) {
      result.add((
        expression: named.substring(name.length + 1).trim(),
        enclosing: caller,
      ));
      continue;
    }
    if (positionalIndex >= 0 && positionalIndex < args.length) {
      result.add((expression: args[positionalIndex], enclosing: caller));
    }
  }
  return result;
}

bool _resolves(
  String source,
  List<String> lines,
  String expr,
  String enclosing,
  int depth,
) {
  if (depth > 5) return false;
  if (expr.contains('withMusicTextFallback')) return true;
  final head = _headIdentifier.firstMatch(expr)?.group(0);
  if (head == null) return false;

  final styleMember = _memberBody(source, head, returnType: 'TextStyle');
  if (styleMember != null && styleMember.contains('withMusicTextFallback')) {
    return true;
  }

  // A local `final <head> = <expr>;` declared inside the enclosing member.
  final enclosingBody = _memberBody(source, enclosing) ?? source;
  final local = RegExp(
    '(?:final|var|const)\\s+(?:TextStyle\\s+)?${RegExp.escape(head)}'
    r'\s*=\s*([^;]*);',
  ).firstMatch(enclosingBody);
  if (local != null && local.group(1)!.trim() != expr.trim()) {
    if (_resolves(source, lines, local.group(1)!, enclosing, depth + 1)) {
      return true;
    }
  }

  // A `TextStyle` PARAMETER of the enclosing member: a pass-through helper, so
  // the proof moves to its callers.
  final parameters = _parameterList(source, enclosing);
  if (parameters != null && _hasTextStyleParameter(parameters, head)) {
    final index = _positionalTextStyleIndex(parameters, head);
    final arguments = _argumentsFor(source, lines, enclosing, head, index);
    if (arguments.isEmpty) return false;
    return arguments.every((a) =>
        _resolves(source, lines, a.expression, a.enclosing, depth + 1));
  }
  return false;
}

void main() {
  // The guard is only worth having if it can still say NO. A structural test
  // that has quietly become vacuous is worse than no test, so its resolver is
  // exercised on a synthetic file with one honest site and one offender.
  test('the resolver rejects a style that bypasses the chain', () {
    const source = '''
class _Fake {
  TextStyle _good() => const TextStyle(fontSize: 12).withMusicTextFallback();
  TextStyle _bad() => const TextStyle(fontSize: 12);

  void drawGood(Canvas canvas) {
    final style = _good();
    TextPainter(text: TextSpan(text: 'x', style: style));
  }

  void drawBad(Canvas canvas) {
    final style = _bad();
    TextPainter(text: TextSpan(text: 'x', style: style));
  }

  void passThrough(Canvas canvas, TextStyle style) {
    TextPainter(text: TextSpan(text: 'x', style: style));
  }

  void callsPassThrough(Canvas canvas) {
    passThrough(canvas, _good());
  }
}
''';
    final lines = source.split('\n');
    expect(_resolves(source, lines, 'style', 'drawGood', 0), isTrue);
    expect(_resolves(source, lines, 'style', 'drawBad', 0), isFalse,
        reason: 'a style built without withMusicTextFallback must be caught');
    expect(_resolves(source, lines, 'style', 'passThrough', 0), isTrue,
        reason: 'a pass-through helper is proven by its callers');
  });

  test(
      'every TextPainter in lib/ is a SMuFL glyph painter or uses the '
      'package text-font fallback chain', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'run from the package root');

    final sites = <_Site>[];
    final sources = <String, String>{};
    final sourceLines = <String, List<String>>{};
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      sources[entity.path] = source;
      final lines = source.split('\n');
      sourceLines[entity.path] = lines;
      for (final match in RegExp(r'\bTextPainter\s*\(').allMatches(source)) {
        final open = match.end - 1;
        final line = '\n'.allMatches(source.substring(0, open)).length + 1;
        sites.add(_Site(
          entity.path,
          line,
          open,
          _balanced(source, open),
          _enclosingMember(lines, line - 1),
        ));
      }
    }

    // The sweep must actually find the sites; a refactor that renames the class
    // (or a glob that stops matching) would otherwise turn this into a no-op.
    // Measured on 2.7.1: 33 constructions across 14 files.
    expect(sites.length, greaterThanOrEqualTo(25),
        reason: 'only ${sites.length} TextPainter sites found — the sweep '
            'stopped seeing lib/');

    final offenders = <String>[];
    var glyphPainters = 0;
    for (final site in sites) {
      if (_musicFont.hasMatch(site.args)) {
        glyphPainters++;
        continue;
      }
      final source = sources[site.path]!;
      final style = _styleExpression(site.args);
      if (style == null) {
        // `TextPainter(textDirection: …)` with the `TextSpan` assigned to the
        // painter a few lines later (the Jianpu measuring painter does this so
        // one painter measures every column). Look at the code that follows.
        final from = site.offset;
        final to = (from + 900).clamp(0, source.length);
        if (source.substring(from, to).contains('withMusicTextFallback')) {
          continue;
        }
        if (_musicFont.hasMatch(source.substring(from, to))) {
          glyphPainters++;
          continue;
        }
        offenders.add('$site — no style argument, and no '
            'withMusicTextFallback follows the construction');
        continue;
      }
      if (_resolves(source, sourceLines[site.path]!, style, site.enclosing, 0)) {
        continue;
      }
      offenders.add('$site — style `$style` never passes through '
          'MusicTextFallback.withMusicTextFallback');
    }

    expect(glyphPainters, greaterThan(0),
        reason: 'no SMuFL glyph painter recognised — the music-font pattern '
            'stopped matching, so the guard is now checking the wrong thing');

    expect(offenders, isEmpty,
        reason: 'text_font.dart states the rule: every TextStyle handed to a '
            'TextPainter must pass through withMusicTextFallback first, '
            'because the headless export path has no Theme ancestor and the '
            'text degrades to .notdef boxes.\n'
            '${offenders.join('\n')}');
  });
}
