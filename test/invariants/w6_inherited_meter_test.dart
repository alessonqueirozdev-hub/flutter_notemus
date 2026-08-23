// ADR-005 action item 8 — the engine must not write the inherited meter into
// the caller's `Measure`.
//
// This was the worst of the engine-writes-the-model family, because unlike
// `Note.beam` (which changed what an EXPORT contained) it changed whether a
// public method THROWS. `layout_engine.dart` did
//
//     measure.inheritedTimeSignature = timeSignatureToUse;
//
// and `Measure.add` reads that field to compute the bar's capacity. Measured on
// the two-bar staff built by [_twoBars] below — bar 1 declares 4/4, bar 2
// declares nothing and holds four quarters:
//
//   | state             | m2.inheritedTimeSignature | m2.add(fifth quarter) |
//   |-------------------|---------------------------|-----------------------|
//   | fresh             | null                      | accepted, 5 elements  |
//   | after layout()    | TimeSignature(4/4)        | MeasureCapacityException, 4 elements |
//
// So whether BUILDING a score succeeded depended on whether it had been
// DISPLAYED. The decision is a value now — `LayoutEngine.inheritedTimeSignatures`
// / `timeSignatureOf` — and the model is left alone.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/layout/measure_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
  });

  Note n(String step, int octave, DurationType d) =>
      Note(pitch: Pitch(step: step, octave: octave), duration: Duration(d));

  Measure bar(List<MusicalElement> elements) => Measure()
    ..elements.addAll(elements);

  LayoutEngine engineFor(Staff staff, {double width = 900}) => LayoutEngine(
        staff,
        availableWidth: width,
        staffSpace: 12,
        metadata: metadata,
      );

  /// Every field of [m] rendered as text, so "the model did not change" can be
  /// asserted field by field rather than by a hand-picked subset.
  ///
  /// Elements are identified by `identityHashCode` as well as by content: the
  /// point of the invariant is that the engine did not touch the CALLER'S
  /// objects, so a copy that merely compares equal would not prove it.
  String dump(Measure m) => [
        'type=${m.runtimeType}',
        'autoBeaming=${m.autoBeaming}',
        'beamingMode=${m.beamingMode}',
        'manualBeamGroups=${m.manualBeamGroups}',
        'inheritedTimeSignature=${m.inheritedTimeSignature}',
        'number=${m.number}',
        'elements=[${m.elements.map((e) => '${e.runtimeType}#${identityHashCode(e)}').join(',')}]',
        'allElements=[${m.allElements.map((e) => '${e.runtimeType}#${identityHashCode(e)}').join(',')}]',
      ].join('\n');

  /// Bar 1 declares 4/4; bar 2 declares nothing and holds four quarters, so it
  /// is exactly full under the inherited meter and a fifth quarter is the
  /// element whose fate used to depend on rendering.
  (Staff, Measure) twoBars() {
    final m1 = bar([
      Clef(clefType: ClefType.treble),
      TimeSignature(numerator: 4, denominator: 4),
      for (var i = 0; i < 4; i++) n('C', 4, DurationType.quarter),
    ]);
    final m2 = bar([for (var i = 0; i < 4; i++) n('D', 4, DurationType.quarter)]);
    return (Staff(measures: [m1, m2]), m2);
  }

  /// Adds a fifth quarter to [m] and reports whether it was accepted, undoing
  /// the change either way so the caller can ask again.
  bool acceptsFifthQuarter(Measure m) {
    final before = m.elements.length;
    try {
      m.add(n('E', 4, DurationType.quarter));
    } on MeasureCapacityException {
      expect(m.elements.length, before,
          reason: 'a rejected add must not have appended anything');
      return false;
    }
    expect(m.elements.length, before + 1);
    m.elements.removeLast();
    return true;
  }

  group('ADR-005 item 8 — layout does not change whether Measure.add throws',
      () {
    test('the fifth quarter is accepted before AND after layout()', () {
      final (staff, m2) = twoBars();

      expect(m2.inheritedTimeSignature, isNull);
      expect(acceptsFifthQuarter(m2), isTrue,
          reason: 'baseline: an un-laid-out bar with no meter accepts anything');

      final engine = engineFor(staff);
      final placed = engine.layout();
      expect(placed, isNotEmpty);

      // The engine must still have DECIDED the inheritance, otherwise "nothing
      // changed" would be trivially true because nothing happened.
      expect(engine.inheritedTimeSignatures[m2], isNotNull,
          reason: 'the engine did not derive bar 2\'s meter at all');
      expect(engine.timeSignatureOf(m2)?.numerator, 4);
      expect(engine.timeSignatureOf(m2)?.denominator, 4);
      // …and it must have derived it WITHOUT touching the model.
      expect(m2.inheritedTimeSignature, isNull,
          reason: 'layout() wrote the meter into the caller\'s Measure');
      expect(acceptsFifthQuarter(m2), isTrue,
          reason: 'layout() changed whether Measure.add throws');
    });

    test('the fifth quarter is still accepted after renderStaffToPng',
        () async {
      final (staff, m2) = twoBars();
      expect(acceptsFifthQuarter(m2), isTrue);

      final png = await ScoreRasterizer.renderStaffToPng(
        staff: staff,
        metadata: metadata,
        width: 900,
      );
      expect(png, isNotNull,
          reason: 'nothing was painted, so nothing is proven');

      expect(m2.inheritedTimeSignature, isNull,
          reason: 'the PAINT pass wrote the meter into the model');
      expect(acceptsFifthQuarter(m2), isTrue,
          reason: 'painting changed whether Measure.add throws');
    });

    test('every Measure is field-for-field identical across layout()', () {
      final (staff, _) = twoBars();
      final before = [for (final m in staff.measures) dump(m)];

      engineFor(staff).layout();

      for (var i = 0; i < staff.measures.length; i++) {
        expect(dump(staff.measures[i]), before[i],
            reason: 'layout() mutated measure $i');
      }
    });

    test('a meter the caller set itself is still honoured as an INPUT', () {
      // The field stays writable on purpose: a caller may opt a stand-alone bar
      // into preventive validation, and `GrandStaffPainter` uses it to hand a
      // wrapped system the meter declared before it.
      final m = Measure(inheritedTimeSignature: TimeSignature(numerator: 4, denominator: 4))
        ..elements.addAll([for (var i = 0; i < 4; i++) n('C', 4, DurationType.quarter)]);
      expect(acceptsFifthQuarter(m), isFalse,
          reason: 'an author-set inherited meter must still enforce capacity');

      // And the engine seeds itself from it, so the bars AFTER it inherit too.
      final follower = bar([for (var i = 0; i < 4; i++) n('D', 4, DurationType.quarter)]);
      final engine = engineFor(Staff(measures: [m, follower]));
      engine.layout();
      expect(engine.timeSignatureOf(follower)?.numerator, 4,
          reason: 'the author-supplied seed did not carry forward');
    });
  });

  group('ADR-005 item 8 — validation still finds over-full inherited bars', () {
    test('MeasureValidator.validateStaff detects a bar over an earlier meter',
        () {
      // Bar 2 declares no meter and holds FIVE quarters against bar 1's 4/4.
      final staff = Staff(measures: [
        bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          for (var i = 0; i < 4; i++) n('C', 4, DurationType.quarter),
        ]),
        bar([for (var i = 0; i < 5; i++) n('D', 4, DurationType.quarter)]),
      ]);

      final results = MeasureValidator.validateStaff(staff);
      expect(results, hasLength(2));
      expect(results[0].isValid, isTrue);
      expect(results[1].isValid, isFalse,
          reason: 'the over-full inherited bar was not detected');
      expect(results[1].numerator, 4);
      expect(results[1].denominator, 4);
      expect(results[1].actualDuration, closeTo(1.25, 1e-9));

      // …and it did so without writing anything back.
      expect(staff.measures[1].inheritedTimeSignature, isNull);
    });

    test('a declared meter beats a stale author hint on a later bar', () {
      // The old validateStaff took `_findTimeSignature(measure)` per bar, so a
      // leftover hint of 3/4 on bar 2 overrode the 4/4 the staff declares in
      // bar 1 and reported a legal 4/4 bar as over-full.
      final stale = Measure(inheritedTimeSignature: TimeSignature(numerator: 3, denominator: 4))
        ..elements.addAll([for (var i = 0; i < 4; i++) n('D', 4, DurationType.quarter)]);
      final staff = Staff(measures: [
        bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          for (var i = 0; i < 4; i++) n('C', 4, DurationType.quarter),
        ]),
        stale,
      ]);

      final results = MeasureValidator.validateStaff(staff);
      expect(results[1].numerator, 4, reason: 'the stale 3/4 hint won');
      expect(results[1].isValid, isTrue);
    });
  });

  group('ADR-005 item 8 — a wrapped grand staff keeps its inherited meter', () {
    // THE TRAP. `GrandStaffPainter._systemStaff` builds a sub-`Staff` that
    // starts at measure `a`, so a meter declared in bar 1 is not inside the
    // sub-staff and the sub-layout cannot re-derive it. It used to borrow the
    // value the engine had stamped on the caller's measures; with the write
    // gone, the painter must carry the prevailing meter itself.
    //
    // The observable consequence is ink: `_centerFullMeasureRests` centres a
    // rest that FILLS its bar, and in 2/4 a half rest only fills the bar if the
    // layout knows the meter. A system that lost the meter leaves that rest
    // hard against the left of the bar.
    //
    // Bar index 6 is the lone half rest; the meter is declared once, in bar 0.
    StaffGroup group({required bool redeclareMeter}) {
      Staff voice(String step, int octave) => Staff(measures: [
            for (var i = 0; i < 9; i++)
              bar([
                if (i == 0) Clef(clefType: ClefType.treble),
                if (i == 0) TimeSignature(numerator: 2, denominator: 4),
                if (i == 6 && redeclareMeter)
                  TimeSignature(numerator: 2, denominator: 4),
                if (i == 6)
                  Rest(duration: const Duration(DurationType.half))
                else ...[
                  n(step, octave, DurationType.quarter),
                  n(step, octave, DurationType.quarter),
                ],
              ])
          ]);
      return StaffGroup(staves: [voice('C', 5), voice('E', 4)]);
    }

    /// X of the single [Rest] on [system], plus the X of the barline that
    /// closes its bar, for the top staff.
    (double rest, double barline)? restAndBarline(
        GrandStaffPainter painter, int system) {
      final top = painter.alignedSystem(system).first;
      double? rest;
      for (final pe in top) {
        if (pe.element is Rest) rest = pe.position.dx;
        if (rest != null && pe.element is Barline) {
          return (rest, pe.position.dx);
        }
      }
      return null;
    }

    test('the half rest in a wrapped system is still centred in its 2/4 bar',
        () {
      GrandStaffPainter paint(bool redeclare) => GrandStaffPainter(
            staffGroup: group(redeclareMeter: redeclare),
            staffSpace: 12,
            metadata: metadata,
            theme: const MusicScoreTheme(),
            availableWidth: 420,
          );

      final inherited = paint(false);
      final declared = paint(true);

      expect(inherited.systemCount, greaterThan(1),
          reason: 'the score did not wrap, so nothing about systems 2..n is '
              'being tested');

      // Find the system holding the rest (the same one in both, since the
      // extra TimeSignature only widens one bar slightly).
      (double, double)? found;
      var foundSystem = -1;
      for (var s = 0; s < inherited.systemCount; s++) {
        final pair = restAndBarline(inherited, s);
        if (pair != null) {
          found = pair;
          foundSystem = s;
          break;
        }
      }
      expect(found, isNotNull, reason: 'the full-bar rest was never placed');
      expect(foundSystem, greaterThan(0),
          reason: 'the rest landed in system 1, where the meter IS present — '
              'the trap is only sprung from system 2 on');

      final (restX, barlineX) = found!;
      // Centred means the rest sits well right of the bar's content edge. The
      // uncentred (broken) placement is the content edge itself, so comparing
      // against the OTHER staff's note X on the same system is the sharpest
      // available yardstick: a centred rest is right of it by half the slack.
      final leftEdge = inherited
          .alignedSystem(foundSystem)
          .first
          .where((pe) => pe.element is Clef || pe.element is Rest)
          .map((pe) => pe.position.dx)
          .reduce((a, b) => a < b ? a : b);
      expect(restX, greaterThan(leftEdge),
          reason: 'the rest was not moved at all');
      expect(barlineX - restX, greaterThan(0));

      // The decisive check: inheriting the meter must place the rest exactly
      // where declaring it in the same bar does.
      final declaredPair = restAndBarline(declared, foundSystem);
      expect(declaredPair, isNotNull);
      final slackInherited = barlineX - restX;
      final slackDeclared = declaredPair!.$2 - declaredPair.$1;
      expect(slackInherited, closeTo(slackDeclared, 0.5),
          reason: 'the wrapped system lost its inherited meter: the full-bar '
              'rest was centred when the meter was re-declared in the bar and '
              'not when it was inherited from bar 1');
    });
  });

  // =========================================================================
  // THE GUARD
  // =========================================================================
  //
  // ADR-005's own "honest residue" section says nothing in the type system
  // stops a contributor from writing the decision back into the model again,
  // and for beams that prediction fired twice inside the wave that landed the
  // ADR (see `adr005_guard_test.dart`). The same convention now protects
  // `Measure.inheritedTimeSignature`, and it is the field with the sharpest
  // consequence: an assignment to it anywhere in the layout or rendering
  // pipeline makes `Measure.add` throw for an element it had just accepted.
  //
  // So the rule is executable. Every WRITE of the field in `lib/` must appear
  // on the allow-list below with the reason it is legitimate, which makes
  // adding one an edit a reviewer sees rather than a silent line in an engine.
  // Reads are unrestricted - the field is an INPUT hint and reading a hint is
  // the point.
  group('ADR-005 item 8 - the guard', () {
    // (file, pattern the WRITE's source line must match, count, why)
    //
    // `Measure`'s own `this.inheritedTimeSignature,` constructor parameter is
    // absent on purpose: it is a DECLARATION, not an assignment, so the pattern
    // below never sees it. The field must stay settable by the caller — it is a
    // public INPUT, exactly like `Note.beam`.
    const allowed = <(String, String, int, String)>[
      (
        'lib/src/rendering/grand_staff_painter.dart',
        'orig.inheritedTimeSignature ?? inheritedMeter',
        2,
        '_restated seeds the sub-measure IT OWNS with the meter prevailing '
            'before the system starts; the caller Measure is never touched. '
            'Two occurrences: the MultiVoiceMeasure branch and the plain one',
      ),
    ];

    final write = RegExp(r'inheritedTimeSignature\s*(=[^=]|:)');

    test('nothing in lib/ writes Measure.inheritedTimeSignature', () {
      // Comments are stripped first: this file, the field's own dartdoc and
      // ADR-005 all quote the forbidden line verbatim, and a scanner that
      // matched prose would be a scanner nobody could keep green.
      final offenders = <String>[];
      final counts = <String, int>{};

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        final lines = _stripComments(entity.readAsStringSync()).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // `foo.inheritedTimeSignature =`, `..inheritedTimeSignature =` and
          // `inheritedTimeSignature:` - a named argument is a write too.
          if (!write.hasMatch(line)) continue;
          final match =
              allowed.where((a) => path.endsWith(a.$1) && line.contains(a.$2));
          if (match.isEmpty) {
            offenders.add('$path:${i + 1}: ${line.trim()}');
          } else {
            final key = '${match.first.$1}|${match.first.$2}';
            counts[key] = (counts[key] ?? 0) + 1;
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'ADR-005 action item 8: the inherited meter is a VALUE the '
              'engine owns (LayoutEngine.inheritedTimeSignatures / '
              'timeSignatureOf). Writing it onto a Measure changes whether '
              'Measure.add throws - rendering a score would break building '
              'one. Offending line(s):\n${offenders.join('\n')}');

      for (final entry in allowed) {
        expect(counts['${entry.$1}|${entry.$2}'], entry.$3,
            reason: 'the allow-list entry "${entry.$2}" in ${entry.$1} is out '
                'of date (expected ${entry.$3}). Reason on file: ${entry.$4}');
      }
    });

    test('the scanner actually matches a reintroduced write', () {
      // A scanner that silently matches nothing passes every other test here.
      const reintroduced = ''''
        // measure.inheritedTimeSignature = ts;   <- a comment must NOT match
        void f(Measure measure, TimeSignature ts) {
          measure.inheritedTimeSignature = ts;
        }
      ''';
      final hits = _stripComments(reintroduced)
          .split('\n')
          .where(write.hasMatch)
          .toList();
      expect(hits, hasLength(1),
          reason: 'the scanner matched $hits - it must see the real write and '
              'skip the commented one');
      expect(hits.single, contains('measure.inheritedTimeSignature = ts;'));

      // ...and it must not fire on a READ, which stays legal.
      expect(
        _stripComments('final ts = measure.timeSignature ?? '
                'measure.inheritedTimeSignature;')
            .split('\n')
            .where(write.hasMatch),
        isEmpty,
      );
    });
  });
}

/// [source] with `//` line comments, `/* */` block comments and the contents of
/// string literals removed, so a scan sees CODE only.
///
/// Necessary because the forbidden line is quoted verbatim in the field's own
/// dartdoc, in ADR-005 and in this file's own header - a scanner that matched
/// prose could never be kept green, and one that was "fixed" by deleting the
/// prose would have destroyed the explanation the rule depends on. Newlines are
/// preserved through everything it removes so reported line numbers stay true.
String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final rest = source.substring(i);
    if (rest.startsWith('//')) {
      final nl = source.indexOf('\n', i);
      if (nl < 0) break;
      i = nl; // keep the newline itself so line numbers survive
      continue;
    }
    if (rest.startsWith('/*')) {
      final close = source.indexOf('*/', i + 2);
      final end = close < 0 ? source.length : close + 2;
      out.write('\n' * '\n'.allMatches(source.substring(i, end)).length);
      i = end;
      continue;
    }
    final ch = source[i];
    if (ch == "'" || ch == '"') {
      final triple = rest.startsWith(ch * 3);
      final closer = triple ? ch * 3 : ch;
      var j = i + closer.length;
      while (j < source.length) {
        if (source[j] == r'\') {
          j += 2;
          continue;
        }
        if (source.startsWith(closer, j)) {
          j += closer.length;
          break;
        }
        if (!triple && source[j] == '\n') break;
        j++;
      }
      out.write('\n' * '\n'.allMatches(source.substring(i, j)).length);
      i = j;
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}
