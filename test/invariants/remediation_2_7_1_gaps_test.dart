// test/invariants/remediation_2_7_1_gaps_test.dart
//
// The nine remediated findings that had NO test in
// `remediation_2_7_1_test.dart`: N-02b, N-08, N-16, N-17, N-18, N-20, N-28,
// N-32 and ADR-004. The 2.7.1 re-audit verified each of them by hand and then
// wrote, in section 16: "Sem teste na suíte de remediação: N-02b, N-08, N-16,
// N-17, N-18, N-20, N-28, N-32, ADR-004." A hand verification that leaves no
// executable trace protects nothing.
//
// Every expectation quotes the number that was measured — before the fix where
// the audit recorded one, and on 2.7.1 where the assertion is a new floor.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../support/ink_probe.dart';

Note _n(
  String step,
  int octave, {
  DurationType d = DurationType.quarter,
  double alter = 0.0,
  int? voice,
  TieType? tie,
  List<Syllable>? syllables,
}) =>
    Note(
      pitch: Pitch(step: step, octave: octave, alter: alter),
      duration: Duration(d),
      voice: voice,
      tie: tie,
      syllables: syllables,
    );

Measure _bar(List<MusicalElement> elements) =>
    Measure()..elements.addAll(elements);

/// Family under which a REAL text face is registered for the N-16 test.
///
/// The name appears nowhere in `lib/`, which is the point: if the engine draws
/// with it, it can only be because [MusicTextFont.use] reached the painter.
const String _probeTextFamily = 'W4TextProbe';

const List<String> _textFontCandidates = <String>[
  r'C:\Windows\Fonts\arial.ttf',
  r'C:\Windows\Fonts\segoeui.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  '/Library/Fonts/Arial.ttf',
  '/System/Library/Fonts/Supplemental/Arial.ttf',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;
  var probeTextFontAvailable = false;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    final bravura = await File('assets/smufl/Bravura.otf').readAsBytes();
    await (FontLoader('packages/flutter_notemus/Bravura')
          ..addFont(Future.value(ByteData.view(bravura.buffer))))
        .load();
    for (final path in _textFontCandidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      await (FontLoader(_probeTextFamily)
            ..addFont(Future.value(ByteData.view(bytes.buffer))))
          .load();
      probeTextFontAvailable = true;
      break;
    }
  });

  tearDown(() => MusicTextFont.use(null));

  LayoutEngine engineFor(Staff staff,
          {double width = 900, double staffSpace = 12}) =>
      LayoutEngine(staff,
          availableWidth: width, staffSpace: staffSpace, metadata: metadata);

  // ----------------------------------------------------------------- N-02b --
  test('N-02b — a rebuilt system keeps both voices of every bar', () {
    // `GrandStaffPainter` rebuilds a one-system `Staff` for each system it
    // draws. `Measure.add` validates capacity and throws, and a
    // `MultiVoiceMeasure` carries its music in `voices`, not in `elements` —
    // so a rebuild that copied `elements` alone would silently drop the
    // polyphony of every wrapped bar. Ten polyphonic bars at 260 px wrap into
    // one bar per system, which is the case that exercises the copy.
    final measures = <Measure>[
      for (var i = 0; i < 10; i++)
        () {
          final mv = MultiVoiceMeasure.twoVoices(
            voice1Elements: [
              _n('C', 5, d: DurationType.half, voice: 1),
              _n('E', 5, d: DurationType.half, voice: 1),
            ],
            voice2Elements: [
              _n('C', 4, d: DurationType.half, voice: 2),
              _n('G', 4, d: DurationType.half, voice: 2),
            ],
          );
          if (i == 0) {
            mv.elements.insert(0, TimeSignature(numerator: 4, denominator: 4));
            mv.elements.insert(0, Clef(clefType: ClefType.treble));
          }
          return mv;
        }(),
    ];

    final painter = GrandStaffPainter(
      staffGroup: StaffGroup(staves: [
        Staff(measures: measures),
        Staff(measures: [
          for (var i = 0; i < 10; i++)
            _bar([
              if (i == 0) Clef(clefType: ClefType.bass),
              _n('C', 3, d: DurationType.whole),
            ])
        ]),
      ]),
      staffSpace: 12,
      metadata: metadata,
      theme: const MusicScoreTheme(),
      availableWidth: 260,
    );

    expect(painter.systemCount, greaterThanOrEqualTo(5),
        reason: 'the staff has to wrap for a rebuild to happen at all');

    for (var system = 0; system < painter.systemCount; system++) {
      final top = painter.alignedSystem(system)[0];
      final notes = top.where((p) => p.element is Note).toList();
      expect(notes, hasLength(4),
          reason: 'system $system lost notes in the rebuild');
      // Both voices, and both still at their own pitch height.
      final ys = notes.map((p) => p.position.dy).toSet();
      expect(ys.length, 4,
          reason: 'system $system: the two voices collapsed onto shared Ys');
      final voices = notes.map((p) => p.voiceNumber).toSet();
      expect(voices, containsAll(<int>[1, 2]),
          reason: 'system $system reported voices $voices');
    }
  });

  // ------------------------------------------------------------------ N-08 --
  test('N-08 — beam levels inside a tuplet are decided per note', () async {
    // `beamCount` used to be `_resolveBeamCount(notes.first.duration.type)`
    // applied to the whole span, so an eighth followed by two sixteenths drew
    // ONE beam and the sixteenths' secondary beam simply vanished — while the
    // same figure outside a tuplet, which goes through `BeamAnalyzer`, got it
    // right.
    //
    // Asserted on INK, because the defect was in the drawing: the layout never
    // had an opinion about how many beams to paint.
    const staffSpace = 36.0;
    final eighth = _n('C', 4, d: DurationType.eighth);
    final first = _n('C', 4, d: DurationType.sixteenth);
    final second = _n('C', 4, d: DurationType.sixteenth);
    final tuplet = Tuplet(
      actualNotes: 3,
      normalNotes: 2,
      elements: [eighth, first, second],
    );
    final staff = Staff(measures: [
      _bar([
        Clef(clefType: ClefType.treble),
        TimeSignature(numerator: 4, denominator: 4),
        tuplet,
      ])
    ]);
    final engine = engineFor(staff, width: 900, staffSpace: staffSpace);
    engine.layout();

    final xs = <Note, double>{
      for (final note in [eighth, first, second])
        note: engine.noteXPositions[note]!,
    };
    final noteY = engine.noteYPositions[eighth]!;
    // C4 sits below the middle line, so the stems point UP and the beams are
    // drawn above the noteheads; sample the stems' side of each gap.
    final stemOffset = metadata.getGlyphWidth('noteheadBlack') * staffSpace / 2;

    final ink = await rasterise(staff, metadata,
        staffSpace: staffSpace, width: 900);

    /// Horizontal beam bands crossing the column [x], above the noteheads.
    int bandsAt(double x) {
      final ceiling = (noteY - staffSpace * 0.8).round();
      return ink
          .runsInColumn(x.round())
          .where((run) => run.end < ceiling)
          .length;
    }

    // Between the eighth and the first sixteenth: the primary beam, and
    // nothing else.
    //
    // It used to be the primary beam AND the tuplet bracket — two bands. The
    // bracket is gone from this figure as of the W6 bracket wave, and its
    // absence is the point rather than a casualty: every note here is joined
    // by a beam, and Behind Bars p.201 has such a group print its numeral
    // alone. Until W6 the renderer gated on the deprecated `Tuplet.showBracket`
    // (default `true`) and never asked the rule, so a bracket was drawn over
    // every tuplet ever engraved by this package. Measured at staffSpace 36,
    // this column went from 2 bands to 1; the invariant this test exists for —
    // the sixteenths carrying a SECOND beam the eighth does not — is asserted
    // on the DELTA below and is untouched by that.
    final betweenEighthAndSixteenth =
        bandsAt((xs[eighth]! + xs[first]!) / 2 + stemOffset);
    // Between the two sixteenths: one band more — the secondary beam. Measured
    // at staffSpace 36: primary beam 135-152, secondary beam 162-179 (a beam is
    // 0.5 staff spaces = 18 px, the gap 0.25 = 9 px).
    final betweenSixteenths =
        bandsAt((xs[first]! + xs[second]!) / 2 + stemOffset);

    expect(betweenEighthAndSixteenth, 1,
        reason: 'expected ONE beam over the eighth and no bracket, got '
            '$betweenEighthAndSixteenth bands');
    expect(betweenSixteenths, betweenEighthAndSixteenth + 1,
        reason: 'the two sixteenths must carry a SECOND beam that the eighth '
            'does not; measured $betweenSixteenths bands against '
            '$betweenEighthAndSixteenth');
  }, timeout: const Timeout.factor(30));

  // ------------------------------------------------------------------ N-16 --
  group('N-16 — text is drawn through the package font chain', () {
    // The re-audit could not close this one: it tried to tell the chains apart
    // by ink ratio and measured 0.840 / 0.840 / 0.823, which distinguishes
    // nothing, so it filed its own finding as "Evidence B — violation visible
    // in the code, visual impact not proven".
    //
    // The measurement that DOES work is injection. `MusicTextFont.use` is the
    // one switch only a painter that consults `kMusicTextFontFallback` can
    // honour, and a real face is registered here under a family name that
    // appears nowhere in `lib/`, so a render that changes when it is injected
    // can only have gone through the chain.
    //
    // The structural half — every call site in `lib/`, not just the kinds
    // exercised here — is `text_painter_provenance_test.dart`.
    Future<Uint8List> renderPng(Staff staff, {double width = 900}) async {
      final png = await ScoreRasterizer.renderStaffToPng(
        staff: staff,
        metadata: metadata,
        width: width,
      );
      expect(png, isNotNull);
      return png!;
    }

    bool identicalBytes(Uint8List a, Uint8List b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    Future<bool> changesWhenInjected(Staff Function() build,
        {double width = 900}) async {
      MusicTextFont.use(null);
      final plain = await renderPng(build(), width: width);
      MusicTextFont.use(_probeTextFamily);
      final injected = await renderPng(build(), width: width);
      MusicTextFont.use(null);
      return !identicalBytes(plain, injected);
    }

    Staff lyrics() => Staff(measures: [
          _bar([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            for (final syllable in ['Ky', 'ri', 'e', 'son'])
              _n('C', 5, syllables: [
                Syllable(text: syllable, type: SyllableType.single)
              ]),
          ])
        ]);

    Staff manyBars() => Staff(measures: [
          for (var i = 0; i < 6; i++)
            _bar([
              if (i == 0) Clef(clefType: ClefType.treble),
              if (i == 0) TimeSignature(numerator: 4, denominator: 4),
              _n('C', 5, d: DurationType.whole),
            ])
        ]);

    test('the lyric path honours MusicTextFont.use end to end', () async {
      if (!probeTextFontAvailable) {
        markTestSkipped('no system text face to register as '
            '$_probeTextFamily; the injection cannot be observed');
        return;
      }
      expect(await changesWhenInjected(lyrics), isTrue,
          reason: 'the lyrics rasterised BYTE-IDENTICALLY with and without an '
              'injected text face, so that painter never consults '
              'kMusicTextFontFallback');
    }, timeout: const Timeout.factor(30));

    test('measure numbers honour MusicTextFont.use end to end', () async {
      if (!probeTextFontAvailable) {
        markTestSkipped('no system text face to register as '
            '$_probeTextFamily; the injection cannot be observed');
        return;
      }
      // Measure numbers are drawn for the first bar of each SYSTEM and only
      // from bar 2 on, so the score has to wrap before there is any text at
      // all — at 900 px this fixture is one system and the test would be
      // vacuous.
      expect(await changesWhenInjected(manyBars, width: 200), isTrue,
          reason: 'the measure numbers rasterised BYTE-IDENTICALLY with and '
              'without an injected text face');
    }, timeout: const Timeout.factor(30));

    test('the tempo, expression and word-dynamic text is really painted',
        () async {
      // Closing the vacuity trap for the three kinds that `SymbolAndTextRenderer`
      // owns: changing the STRING must change the picture. (It does — measured
      // true for all three.)
      //
      // This comment used to end "...what does NOT reach them is
      // `MusicTextFont.use`, because each of those styles arrives at
      // `withMusicTextFallback` with `fontFamilyFallback: smuflTextFontFallback`
      // already set ... the runtime override is not honoured on this route,
      // which is reported separately". That was finding M-30, and it was fixed
      // in 2.7.2: those ten sites no longer pre-supply the chain, so the
      // injection DOES reach tempo marks, expression text, word dynamics and
      // repeat instructions. Measured at `staffSpace = 12` in a 900 px
      // viewport: 14 942 px of ink / 2 `.notdef` boxes without an injected
      // face, 6 886 px / 0 with one. Pinned by
      // `test/invariants/w5_leftovers_test.dart`.
      Staff tempo(String text) => Staff(measures: [
            _bar([
              Clef(clefType: ClefType.treble),
              TimeSignature(numerator: 4, denominator: 4),
              TempoMark(
                  text: text, bpm: 132, beatUnit: DurationType.quarter),
              _n('C', 5, d: DurationType.whole),
            ])
          ]);
      Staff expression(String text) => Staff(measures: [
            _bar([
              Clef(clefType: ClefType.treble),
              TimeSignature(numerator: 4, denominator: 4),
              MusicText(text: text, type: TextType.expression),
              _n('C', 5, d: DurationType.whole),
            ])
          ]);
      Staff wordDynamic(String text) => Staff(measures: [
            _bar([
              Clef(clefType: ClefType.treble),
              TimeSignature(numerator: 4, denominator: 4),
              Dynamic(type: DynamicType.crescendo, customText: text),
              _n('C', 5, d: DurationType.whole),
            ])
          ]);

      for (final entry in <String, Staff Function(String)>{
        'tempo mark': tempo,
        'expression text': expression,
        'word dynamic': wordDynamic,
      }.entries) {
        final short = await renderPng(entry.value('a'));
        final long = await renderPng(entry.value('ZZZZZZZZZZZZZZZ'));
        expect(identicalBytes(short, long), isFalse,
            reason: '${entry.key} rendered identically for two different '
                'strings, so it is not being painted at all');
      }
    }, timeout: const Timeout.factor(30));

    test('withMusicTextFallback installs the chain and the injection', () {
      // The unit half. Note the exact contract, which is what decides which
      // sites the runtime override can reach:
      //   * no family and no chain  -> the head of the package chain becomes
      //     the PRIMARY family (a null primary lets the platform default win
      //     the lookup, which is how a measure number came out as a solid
      //     .notdef box even with the fallback list attached);
      //   * an injected family      -> it becomes the primary;
      //   * a caller-supplied chain -> it wins, untouched.
      const bare = TextStyle(fontSize: 12);

      MusicTextFont.use(null);
      final plain = bare.withMusicTextFallback();
      expect(plain.fontFamily, kMusicTextFontFallback.first);
      expect(plain.fontFamilyFallback, kMusicTextFontFallback.sublist(1));

      MusicTextFont.use(_probeTextFamily);
      final injected = bare.withMusicTextFallback();
      expect(injected.fontFamily, _probeTextFamily);
      expect(injected.fontFamilyFallback, kMusicTextFontFallback,
          reason: 'the injection must not destroy the built-in chain');

      // A style that already names its own chain is left alone — this is the
      // rule that keeps `MusicTextFont.use` out of the tempo/expression/
      // dynamic route, whose styles set `fontFamilyFallback` themselves.
      const owned = TextStyle(
        fontSize: 12,
        fontFamilyFallback: <String>['CallerFace'],
      );
      final kept = owned.withMusicTextFallback();
      expect(kept.fontFamily, 'CallerFace');
      expect(kept.fontFamilyFallback, isEmpty);

      MusicTextFont.use(null);
      expect(bare.withMusicTextFallback().fontFamily, plain.fontFamily,
          reason: 'clearing the injection must restore the default');
    });
  });

  // ------------------------------------------------------------------ N-17 --
  test('N-17 — a tie broken by a system break leads in AFTER the restated clef',
      () async {
    // `_incomingBreakX` used to be `max(extent.left, musicLeft - leadIn)`, and
    // `extent.left` is the X of the RESTATED CLEF. Whenever the header was
    // wider than `systemBreakLeadInSpaces` (2.0 staff spaces) the max picked
    // the clef's own origin and the curve was drawn straight through the clef
    // glyph — visible in any rasterised multi-system score with a tie across
    // the break.
    //
    // Measured by DIFFERENCE: the same score is rendered with and without the
    // tie. The layout is identical (a tie is a property of the note, not an
    // element), so every pixel that changes belongs to the tie and to nothing
    // else. Measured on 2.7.1 at staffSpace 24, three flats restated: the
    // incoming half occupies columns 191..302, the clef 60..136 and the first
    // note 239.7 — so the curve clears the clef by 55 px and still starts
    // 49 px before the note it closes on.
    //
    // Scope, stated exactly: the header the lead-in is measured against is the
    // rightmost header element's ORIGIN, not its right edge. With a key
    // signature restated the curve therefore begins inside the key signature's
    // reserved advance (191 against a KeySignature at 136.4 reserving 79.3).
    // That is a separate, narrower finding and is reported as such; what N-17
    // claimed — and what this test pins — is that the curve no longer runs
    // through the CLEF.
    const staffSpace = 24.0;
    Staff build({required bool tied}) {
      final measures = <Measure>[];
      for (var i = 0; i < 6; i++) {
        measures.add(_bar([
          if (i == 0) Clef(clefType: ClefType.treble),
          if (i == 0) KeySignature(-3),
          if (i == 0) TimeSignature(numerator: 4, denominator: 4),
          _n('E', 5,
              d: DurationType.whole,
              tie: !tied
                  ? null
                  : i == 1
                      ? TieType.start
                      : (i == 2 ? TieType.end : null)),
        ]));
      }
      return Staff(measures: measures);
    }

    final withTie = build(tied: true);
    final withoutTie = build(tied: false);

    final engine = engineFor(withTie, width: 320, staffSpace: staffSpace);
    final placed = engine.layout();
    // Bar 2 must open a system for the tie to be broken at all.
    final incomingSystem =
        placed.firstWhere((p) => p.measureIndex == 2).system;
    expect(incomingSystem, greaterThan(0),
        reason: 'the tie does not straddle a system break in this layout');

    // Right edge of the restated CLEF, and the X of the first note.
    var clefRight = double.negativeInfinity;
    var keyLeft = double.negativeInfinity;
    var musicLeft = double.infinity;
    for (final pe in placed.where((p) => p.system == incomingSystem)) {
      final element = pe.element;
      if (element is Clef) {
        clefRight =
            math.max(clefRight, pe.position.dx + engine.elementWidth(element));
      }
      if (element is KeySignature) {
        keyLeft = math.max(keyLeft, pe.position.dx);
      }
      if (element is Note) {
        musicLeft = math.min(musicLeft, pe.position.dx);
      }
    }
    expect(clefRight.isFinite, isTrue,
        reason: 'the system restated no clef, so nothing is being tested');
    expect(keyLeft.isFinite, isTrue,
        reason: 'the system restated no key signature; the case is meant to '
            'have a WIDE header, which is what the old max() tripped over');
    expect(musicLeft, greaterThan(clefRight));

    final a = await rasterise(withTie, metadata,
        staffSpace: staffSpace, width: 320, theme: const MusicScoreTheme());
    final b = await rasterise(withoutTie, metadata,
        staffSpace: staffSpace, width: 320, theme: const MusicScoreTheme());
    expect(a.width, b.width);
    expect(a.height, b.height);

    // Columns where the two renders differ = the tie's own ink.
    var leftmost = -1;
    var changed = 0;
    for (var x = 0; x < a.width; x++) {
      var differs = false;
      for (var y = 0; y < a.height; y++) {
        if (a.dark(x, y) != b.dark(x, y)) {
          differs = true;
          break;
        }
      }
      if (!differs) continue;
      changed++;
      if (leftmost < 0) leftmost = x;
    }
    expect(changed, greaterThan(0),
        reason: 'adding the tie changed nothing — nothing was drawn');
    expect(leftmost.toDouble(), greaterThanOrEqualTo(clefRight),
        reason: 'the incoming half of the tie starts at x = $leftmost, on top '
            'of the restated clef, which ends at $clefRight');
    expect(leftmost.toDouble(), greaterThan(keyLeft),
        reason: 'the lead-in must start past the head of the restated key '
            'signature at $keyLeft, not at the left edge of the system');
    expect(leftmost.toDouble(), lessThan(musicLeft),
        reason: 'the lead-in must still start BEFORE the note it closes on');
  }, timeout: const Timeout.factor(30));

  // ------------------------------------------------------------------ N-18 --
  test('N-18 — a two-staff group is exported to PDF as a grand staff',
      () async {
    // Before: `_addMusicPages` rasterised each staff of a group separately
    // through the single-staff path, so a piano part came out as two
    // independent one-line staves — no brace, no system barlines, hands not
    // aligned. And the grand-staff branch that replaced it had to paginate:
    // measured on a 40-bar two-staff score, the group wraps into 14 systems
    // (963.78 x 3552 logical px) and the un-paginated version fitted 39.8% of
    // the music onto one A4 page.
    Staff hand(String step, int octave, ClefType clef) => Staff(measures: [
          for (var i = 0; i < 40; i++)
            _bar([
              if (i == 0) Clef(clefType: clef),
              if (i == 0) TimeSignature(numerator: 4, denominator: 4),
              for (var k = 0; k < 4; k++) _n(step, octave),
            ])
        ]);

    final group = StaffGroup(
      staves: [hand('C', 5, ClefType.treble), hand('C', 3, ClefType.bass)],
      bracket: BracketType.brace,
      name: 'Piano',
    );
    final score = Score(title: 'N-18', staffGroups: [group]);

    final exporter = PdfExporter(score: score, metadata: metadata);
    final bytes = await exporter.export();

    expect(exporter.warnings, isEmpty,
        reason: 'a non-empty warning list means the PDF holds metadata only');
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Measured on the two-staff case in the re-audit: 14 522 bytes for a short
    // score. Forty bars of two staves cannot fit in a tenth of that.
    expect(bytes.length, greaterThan(10000));

    // The group went through the GRAND-STAFF path, not the single-staff one:
    // the rasteriser's group pagination has to produce the same number of
    // pages the exporter embedded, and more than one of them.
    final pages = await ScoreRasterizer.renderGroupPages(
      group: group,
      metadata: metadata,
      width: 1000,
      staffSpace: 12,
      systemsPerPage: 4,
    );
    expect(pages.length, greaterThan(1),
        reason: 'the fixture must wrap into several systems, or pagination is '
            'not exercised');

    // And it really is ONE braced system rather than two independent staves:
    // a group's system band has to hold both staves plus the gap between them.
    // Measured at staffSpace 12: 252 logical px per band, against
    // `ScoreRasterizer.systemHeightInStaffSpaces` (10 staff spaces = 120 px)
    // for a single staff.
    final groupLayout = ScoreRasterizer.layoutGroup(
      group: group,
      metadata: metadata,
      width: 1000,
      staffSpace: 12,
    );
    const singleStaffBand =
        ScoreRasterizer.systemHeightInStaffSpaces * 12.0;
    expect(groupLayout.systemBandHeight, greaterThan(singleStaffBand * 1.8),
        reason: 'a system band of ${groupLayout.systemBandHeight} px cannot '
            'hold two staves — the group was rasterised staff by staff');
    expect(groupLayout.painter.systemCount, greaterThan(1));
    // Every system of the group carries BOTH staves, aligned on one time grid.
    for (var system = 0;
        system < groupLayout.painter.systemCount;
        system++) {
      final aligned = groupLayout.painter.alignedSystem(system);
      expect(aligned, hasLength(2),
          reason: 'system $system was not engraved as a grand staff');
      for (final sub in aligned) {
        expect(sub.whereType<PositionedElement>(), isNotEmpty);
      }
    }
  }, timeout: const Timeout.factor(60));

  // ------------------------------------------------------------------ N-20 --
  group('N-20 — every positioned element carries its own staff baseline', () {
    test('a single staff steps 60 / 180 / 300 … one per system', () {
      // `PositionedElement.position` means the NOTEHEAD for a note and the
      // staff baseline for a clef, which is how `ScoreHitTester` came to build
      // a chord's box around the staff while its noteheads were an octave
      // above. `staffBaselineY` removes the ambiguity, and it has to survive
      // justification and full-bar-rest centring, both of which rebuild the
      // element with `movedTo`.
      final staff = Staff(measures: [
        for (var i = 0; i < 12; i++)
          _bar([
            if (i == 0) Clef(clefType: ClefType.treble),
            if (i == 0) TimeSignature(numerator: 4, denominator: 4),
            // A full-bar rest in the middle, so the centring pass runs.
            if (i == 5)
              Rest(duration: const Duration(DurationType.whole))
            else
              _n('C', 5, d: DurationType.whole),
          ])
      ]);
      final placed = engineFor(staff, width: 260).layout();

      final byBaseline = <int, Set<double>>{};
      for (final pe in placed) {
        (byBaseline[pe.system] ??= <double>{}).add(pe.staffBaselineY);
      }
      expect(byBaseline.length, greaterThanOrEqualTo(6));
      for (final entry in byBaseline.entries) {
        expect(entry.value, hasLength(1),
            reason: 'system ${entry.key} reported ${entry.value.length} '
                'different baselines: ${entry.value}');
        // Measured on a 12-system staff at staffSpace 12: 60 / 180 / 300 / …
        expect(entry.value.single, closeTo(60.0 + entry.key * 120.0, 1e-9),
            reason: 'system ${entry.key} baseline was ${entry.value.single}');
      }
    });

    test('position means different things per element; staffBaselineY does not',
        () {
      // This asymmetry is the trap the field exists to remove, and it is worth
      // pinning because it is surprising: `position.dy` is the NOTEHEAD for a
      // Note and the STAFF BASELINE for a Chord. `ScoreHitTester` built a
      // chord's box around `position.dy` and so drew it around the staff while
      // the chord's noteheads were an octave above it, making high chords
      // unclickable (finding N-19). Whatever `position` means,
      // `staffBaselineY` is the staff.
      final chord = Chord(
        notes: [_n('C', 6), _n('E', 6), _n('G', 6)],
        duration: const Duration(DurationType.whole),
      );
      final note = _n('C', 6, d: DurationType.whole);
      final placed = engineFor(Staff(measures: [
        _bar([Clef(clefType: ClefType.treble), chord]),
        _bar([note]),
      ])).layout();

      final positionedChord = placed.firstWhere((p) => p.element is Chord);
      final positionedNote =
          placed.firstWhere((p) => identical(p.element, note));
      final positionedClef = placed.firstWhere((p) => p.element is Clef);

      for (final pe in [positionedChord, positionedNote, positionedClef]) {
        expect(pe.staffBaselineY, 60.0,
            reason: '${pe.element.runtimeType} reported '
                '${pe.staffBaselineY} instead of the system baseline');
      }
      expect(positionedChord.position.dy, closeTo(60.0, 1e-9),
          reason: 'a Chord is positioned at the staff baseline');
      // C6 is eight staff positions above the middle line, i.e. four staff
      // spaces: 60.0 - 4 * 12 = 12.0, measured.
      expect(positionedNote.position.dy, closeTo(12.0, 1e-9),
          reason: 'a Note two octaves up is positioned at its NOTEHEAD, well '
              'above the staff — measured 60.0 for the chord against '
              '${positionedNote.position.dy} for the same pitch as a note');
      expect(positionedNote.position.dy,
          lessThan(positionedNote.staffBaselineY - 12 * 3),
          reason: 'the notehead must be at least three staff spaces above the '
              'baseline its own PositionedElement reports');
    });

    test('under GrandStaffPainter every sub-staff reports its own local 60.0',
        () {
      // Documented consequence, and one a consumer must know: each staff of
      // each system is laid out by its OWN engine over a one-system sub-staff,
      // so the value is LOCAL and `paint()` supplies the translation.
      final painter = GrandStaffPainter(
        staffGroup: StaffGroup(staves: [
          Staff(measures: [
            for (var i = 0; i < 8; i++)
              _bar([
                if (i == 0) Clef(clefType: ClefType.treble),
                _n('C', 5, d: DurationType.whole),
              ])
          ]),
          Staff(measures: [
            for (var i = 0; i < 8; i++)
              _bar([
                if (i == 0) Clef(clefType: ClefType.bass),
                _n('C', 3, d: DurationType.whole),
              ])
          ]),
        ]),
        staffSpace: 12,
        metadata: metadata,
        theme: const MusicScoreTheme(),
        availableWidth: 260,
      );
      expect(painter.systemCount, greaterThan(1));
      for (var system = 0; system < painter.systemCount; system++) {
        for (final sub in painter.alignedSystem(system)) {
          expect(sub, isNotEmpty);
          expect(sub.map((p) => p.staffBaselineY).toSet(), {60.0},
              reason: 'system $system: a sub-staff reported '
                  '${sub.map((p) => p.staffBaselineY).toSet()}');
          expect(sub.map((p) => p.system).toSet(), {0});
        }
      }
    });
  });

  // ------------------------------------------------------------------ N-28 --
  test('N-28 — the measuring dry run leaves the position maps untouched', () {
    // `_calculateMeasureWidthCursor` lays the bar out into a THROW-AWAY cursor
    // to learn its width. That cursor is built without the position maps and
    // `_measuring` suppresses `_registerTupletGeometry`, so nothing from the
    // dry run may reach `noteXPositions` — if it did, a bar's notes would
    // carry the X they had in the probe, which starts at a different place and
    // never sees the system break.
    //
    // The re-audit's own check: `tupletX 82.61 == innerXs[0] 82.61`.
    final tuplets = <Tuplet>[];
    final measures = <Measure>[];
    for (var i = 0; i < 8; i++) {
      final tuplet = Tuplet(
        actualNotes: 3,
        normalNotes: 2,
        elements: [
          for (var k = 0; k < 3; k++) _n('C', 5, d: DurationType.eighth)
        ],
      );
      tuplets.add(tuplet);
      measures.add(_bar([
        if (i == 0) Clef(clefType: ClefType.treble),
        if (i == 0) TimeSignature(numerator: 4, denominator: 4),
        tuplet,
      ]));
    }
    final staff = Staff(measures: measures);
    // Narrow enough to wrap, so the dry run's X and the real X differ by more
    // than rounding for every bar after the first system.
    final engine = engineFor(staff, width: 300);
    final placed = engine.layout();

    expect(placed.map((p) => p.system).toSet().length, greaterThan(1),
        reason: 'the staff must wrap, or the dry run and the real pass agree '
            'by accident');

    for (var i = 0; i < tuplets.length; i++) {
      final tuplet = tuplets[i];
      final positioned = placed.firstWhere((p) => identical(p.element, tuplet));
      final firstInner = tuplet.elements.first as Note;
      expect(engine.noteXPositions[firstInner], isNotNull,
          reason: 'tuplet $i registered no inner geometry at all');
      expect(engine.noteXPositions[firstInner]!,
          closeTo(positioned.position.dx, 1e-9),
          reason: 'tuplet $i: the first inner note is at '
              '${engine.noteXPositions[firstInner]} while the tuplet was '
              'placed at ${positioned.position.dx} — a stale dry-run write');
      // Every inner note must belong to the system its tuplet was placed on.
      final systemElements =
          placed.where((p) => p.system == positioned.system).toList();
      final leftEdge =
          systemElements.map((p) => p.position.dx).reduce(math.min);
      final rightEdge =
          systemElements.map((p) => p.position.dx).reduce(math.max);
      for (final child in tuplet.elements.whereType<Note>()) {
        final x = engine.noteXPositions[child]!;
        expect(x, greaterThanOrEqualTo(leftEdge - 1e-6));
        expect(x, lessThanOrEqualTo(rightEdge + 1e-6));
      }
    }

    // Exactly one entry per note: a dry run that wrote would leave extras
    // behind for notes it measured but never placed.
    expect(engine.noteXPositions, hasLength(8 * 3));

    // …and the answer is stable, which a leaked probe state would not be.
    final again = engineFor(Staff(measures: measures), width: 300);
    again.layout();
    expect(engine.layout().map((p) => p.position.dx).toList(),
        again.layout().map((p) => p.position.dx).toList());
  });

  // ------------------------------------------------------------------ N-32 --
  test('N-32 — c8vb displaces the printed pitch exactly once', () {
    // `_getClefReference` embedded the octave in the reference itself
    // (`baseOctave: 3`) for `c8vb` alone, implementing the SOUNDING convention
    // while every other octave clef implemented the WRITTEN one — so the base
    // was internally inconsistent before any correction. ADR-003 settled it:
    // `Pitch` is the sounding pitch, and the clef's octave shift is applied on
    // the DRAWING side, once.
    final c8vb = Clef(clefType: ClefType.c8vb);
    final tenor = Clef(clefType: ClefType.tenor);

    // The re-audit's own probe.
    expect(
      StaffPositionCalculator.calculate(
          const Pitch(step: 'C', octave: 3, alter: 0.0), c8vb),
      2,
    );
    expect(
      StaffPositionCalculator.calculate(
          const Pitch(step: 'C', octave: 3, alter: 0.0), c8vb),
      StaffPositionCalculator.calculate(
          const Pitch(step: 'C', octave: 4, alter: 0.0), tenor),
      reason: 'c8vb is the tenor C clef sounding an octave lower; a note an '
          'octave below prints in the same place',
    );

    // The general property, over a whole octave: c8vb is exactly a seventh
    // (seven staff positions) away from its un-shifted twin, never twice that.
    for (final step in ['C', 'D', 'E', 'F', 'G', 'A', 'B']) {
      for (final octave in [2, 3, 4]) {
        final pitch = Pitch(step: step, octave: octave, alter: 0.0);
        expect(
          StaffPositionCalculator.calculate(pitch, c8vb) -
              StaffPositionCalculator.calculate(pitch, tenor),
          7,
          reason: '$step$octave moved by the wrong amount under c8vb',
        );
      }
    }

    // Playback is unmoved: `Pitch` is already the sounding pitch.
    final staff = Staff(measures: [
      _bar([c8vb, _n('C', 4, d: DurationType.whole)])
    ]);
    final notes = MidiMapper.fromStaff(staff)
        .tracks
        .expand((t) => t.events)
        .where((e) => e.type == MidiEventType.noteOn)
        .map((e) => e.note);
    expect(notes, [60], reason: 'a sounding C4 is MIDI 60 under any clef');
  });

  // --------------------------------------------------------------- ADR-004 --
  group('ADR-004 — the opening block is a convention, the body is a sequence',
      () {
    /// X of the first element of [type] on the page.
    double xOf(List<PositionedElement> placed, Type type) => placed
        .firstWhere((p) => p.element.runtimeType == type)
        .position
        .dx;

    test('a plain Measure opens clef, key, meter whatever order it was built '
        'in', () {
      // MusicXML's `<attributes>` has a FIXED child order of
      // `divisions, key, time, …, clef`, so a faithful parse hands the engine
      // key, time, clef. Measured before: KeySignature@30.0,
      // TimeSignature@69.6, Clef@105.6 — on every imported score in existence.
      for (final order in <List<MusicalElement> Function()>[
        () => [
              KeySignature(-3),
              TimeSignature(numerator: 4, denominator: 4),
              Clef(clefType: ClefType.treble),
            ],
        () => [
              TimeSignature(numerator: 4, denominator: 4),
              Clef(clefType: ClefType.treble),
              KeySignature(-3),
            ],
        () => [
              Clef(clefType: ClefType.treble),
              KeySignature(-3),
              TimeSignature(numerator: 4, denominator: 4),
            ],
      ]) {
        final placed = engineFor(Staff(measures: [
          _bar([...order(), _n('C', 5, d: DurationType.whole)])
        ])).layout();
        expect(xOf(placed, Clef), lessThan(xOf(placed, KeySignature)));
        expect(
            xOf(placed, KeySignature), lessThan(xOf(placed, TimeSignature)));
      }
    });

    test('a MultiVoiceMeasure opens the same way — the SECOND route', () {
      // `_layoutMultiVoiceMeasure` never read `measure.elements` at all, so a
      // polyphonic bar's opening block was reached only because the parsers
      // wrote every system element twice. Both routes now call
      // `LayoutEngine.canonicalOpeningBlock`; if only one did, an imported
      // polyphonic score would be engraved differently from an imported
      // monophonic one.
      final mv = MultiVoiceMeasure.twoVoices(
        voice1Elements: [_n('C', 5, d: DurationType.whole, voice: 1)],
        voice2Elements: [_n('C', 4, d: DurationType.whole, voice: 2)],
      );
      mv.elements.insertAll(0, [
        KeySignature(-3),
        TimeSignature(numerator: 4, denominator: 4),
        Clef(clefType: ClefType.treble),
      ]);
      final placed = engineFor(Staff(measures: [mv])).layout();
      expect(xOf(placed, Clef), lessThan(xOf(placed, KeySignature)));
      expect(xOf(placed, KeySignature), lessThan(xOf(placed, TimeSignature)));
      expect(placed.where((p) => p.element is Clef), hasLength(1),
          reason: 'the opening block must be drawn once, not once per voice');
    });

    test('the BODY keeps document order in both routes', () {
      // The other half of the decision, and the one F-01 was about:
      // `[treble, C4, bass, C4]` must draw the bass clef AFTER the first C4,
      // and must position that first C4 with the TREBLE clef. Before F-01 the
      // engine hoisted every clef to the head of the bar and drew both C4s at
      // the bass-clef position, a twelfth off for the first one.
      final first = _n('C', 4, d: DurationType.half);
      final second = _n('C', 4, d: DurationType.half);
      final engine = engineFor(Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          first,
          Clef(clefType: ClefType.bass),
          second,
        ])
      ]));
      final placed = engine.layout();
      final clefXs = placed
          .where((p) => p.element is Clef)
          .map((p) => p.position.dx)
          .toList();
      expect(clefXs, hasLength(2));
      expect(clefXs.last, greaterThan(engine.noteXPositions[first]!));
      expect(engine.noteYPositions[first],
          isNot(engine.noteYPositions[second]),
          reason: 'the two C4s must be a twelfth apart');

      // The same shape inside a voice of a polyphonic bar.
      final v1First = _n('C', 4, d: DurationType.half, voice: 1);
      final v1Second = _n('C', 4, d: DurationType.half, voice: 1);
      final polyphonic = MultiVoiceMeasure.twoVoices(
        voice1Elements: [
          v1First,
          Clef(clefType: ClefType.bass),
          v1Second,
        ],
        voice2Elements: [_n('G', 3, d: DurationType.whole, voice: 2)],
      );
      polyphonic.elements.insert(0, Clef(clefType: ClefType.treble));
      final polyEngine = engineFor(Staff(measures: [polyphonic]));
      final polyPlaced = polyEngine.layout();
      final polyClefXs = polyPlaced
          .where((p) => p.element is Clef)
          .map((p) => p.position.dx)
          .toList()
        ..sort();
      expect(polyClefXs, hasLength(2));
      expect(polyClefXs.last, greaterThan(polyEngine.noteXPositions[v1First]!),
          reason: 'a mid-voice clef change must stay where it was written');
      expect(polyEngine.noteYPositions[v1First],
          isNot(polyEngine.noteYPositions[v1Second]));
    });

    test('the sort is stable, so two elements of the same kind keep their '
        'written order', () {
      // Stated in the ADR and in `canonicalOpeningBlock`'s dartdoc: a courtesy
      // meter written twice must not be reordered against itself.
      final firstMeter = TimeSignature(numerator: 4, denominator: 4);
      final secondMeter = TimeSignature(numerator: 3, denominator: 4);
      final sorted = LayoutEngine.canonicalOpeningBlock([
        firstMeter,
        secondMeter,
        Clef(clefType: ClefType.treble),
      ]);
      expect(sorted.first, isA<Clef>());
      expect(identical(sorted[1], firstMeter), isTrue);
      expect(identical(sorted[2], secondMeter), isTrue);
    });
  });
}
