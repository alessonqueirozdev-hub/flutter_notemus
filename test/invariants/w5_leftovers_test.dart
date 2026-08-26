// test/invariants/w5_leftovers_test.dart
//
// The four findings that survived FOUR remediation waves because each wave
// wrote the diagnosis into a report instead of into the code: M-30 (the text
// font escape hatch is inert), M-23 (a tuplet bracket clipped at the canvas
// edge), M-08/M-31 (the tuplet proportion holds inside a group but not between
// two groups in one bar) and M-46 (an over-full bar overflows silently).
//
// Every expectation below quotes the number the final audit measured, so a
// regression reads as "this went back to the broken value" rather than as an
// anonymous failure.
//
// A note on measuring ink from `ui.Image.toByteData(rawRgba)`: the buffer is
// PREMULTIPLIED. A background row that a fractional logical height covers only
// 40% comes back as (102, 102, 102, 102), which a naive `r < 140` test reads as
// solid black — the M-23 acceptance ("0 px of ink on the last row") is
// impossible to state without un-premultiplying first, and an earlier probe of
// this very finding reported a spurious 900 px of ink on the bottom row for
// that reason. [_Ink.dark] divides by alpha before thresholding.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/layout/tuplet_grid.dart';

Note _n(
  String step,
  int octave, {
  DurationType d = DurationType.quarter,
}) =>
    Note(
      pitch: Pitch(step: step, octave: octave),
      duration: Duration(d),
    );

Measure _bar(List<MusicalElement> elements) =>
    Measure()..elements.addAll(elements);

/// Family under which a REAL text face is registered for the M-30 test.
///
/// The name appears nowhere in `lib/`, which is the whole point: if the engine
/// draws with it, it can only be because [MusicTextFont.use] reached the
/// painter through [MusicTextFallback.withMusicTextFallback].
const String _probeTextFamily = 'W5TextProbe';

const List<String> _textFontCandidates = <String>[
  r'C:\Windows\Fonts\arial.ttf',
  r'C:\Windows\Fonts\segoeui.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  '/Library/Fonts/Arial.ttf',
  '/System/Library/Fonts/Supplemental/Arial.ttf',
];

/// A rasterised score, addressable by pixel, with the premultiplication undone.
class _Ink {
  final int width;
  final int height;
  final Uint8List _rgba;

  _Ink(this.width, this.height, this._rgba);

  static Future<_Ink> of(ui.Image image) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return _Ink(image.width, image.height, bytes!.buffer.asUint8List());
  }

  /// True when the pixel is dark enough to count as ink, AFTER dividing out the
  /// premultiplied alpha. 140 rather than 128 for the reason `ink_probe.dart`
  /// gives: Skia puts a half-covered edge pixel at about 0x80.
  bool dark(int x, int y) {
    final i = (y * width + x) * 4;
    final a = _rgba[i + 3];
    if (a < 8) return false;
    int channel(int k) => (_rgba[i + k] * 255) ~/ a;
    return channel(0) < 140 && channel(1) < 140 && channel(2) < 140;
  }

  int rowInk(int y) {
    var n = 0;
    for (var x = 0; x < width; x++) {
      if (dark(x, y)) n++;
    }
    return n;
  }

  int get totalInk {
    var n = 0;
    for (var y = 0; y < height; y++) {
      n += rowInk(y);
    }
    return n;
  }

  /// Maximal runs of consecutive ink along row [y], as inclusive `(start, end)`.
  List<({int start, int end})> runsInRow(int y) {
    final result = <({int start, int end})>[];
    var start = -1;
    for (var x = 0; x <= width; x++) {
      final ink = x < width && dark(x, y);
      if (ink && start < 0) start = x;
      if (!ink && start >= 0) {
        result.add((start: start, end: x - 1));
        start = -1;
      }
    }
    return result;
  }

  /// Number of `.notdef` boxes: 4-connected ink components at least 8 px on
  /// both axes whose bounding box is more than 95% filled.
  ///
  /// That shape is what a headless Flutter binary substitutes for an
  /// unresolvable character; a resolved face never produced a sizeable
  /// component above 0.607 fill (see the table in `MusicTextFont`).
  int get notdefBoxes {
    final seen = List<bool>.filled(width * height, false);
    var boxes = 0;
    for (var y0 = 0; y0 < height; y0++) {
      for (var x0 = 0; x0 < width; x0++) {
        if (!dark(x0, y0) || seen[y0 * width + x0]) continue;
        final stack = <int>[y0 * width + x0];
        seen[y0 * width + x0] = true;
        var minX = x0, maxX = x0, minY = y0, maxY = y0, filled = 0;
        while (stack.isNotEmpty) {
          final cell = stack.removeLast();
          final cx = cell % width, cy = cell ~/ width;
          filled++;
          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;
          for (final step in const [
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1],
          ]) {
            final nx = cx + step[0], ny = cy + step[1];
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
            if (seen[ny * width + nx] || !dark(nx, ny)) continue;
            seen[ny * width + nx] = true;
            stack.add(ny * width + nx);
          }
        }
        final boxWidth = maxX - minX + 1;
        final boxHeight = maxY - minY + 1;
        if (boxWidth >= 8 &&
            boxHeight >= 8 &&
            filled / (boxWidth * boxHeight) > 0.95) {
          boxes++;
        }
      }
    }
    return boxes;
  }
}

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

  // ------------------------------------------------------------------ M-30 --
  group('M-30 — the text font escape hatch actually reaches the painter', () {
    // The re-audit measured the hatch INERT on the four prose kinds this score
    // carries: the same raster with and without `MusicTextFont.use` produced
    // **76,120 px of ink in BOTH cases**. Cause: ten sites in
    // `symbol_and_text_renderer.dart` set `fontFamilyFallback` themselves
    // BEFORE calling `withMusicTextFallback()`, and the extension's contract is
    // that a caller-supplied chain always wins — so the injection point was
    // unreachable by construction.

    Staff prose() => Staff(measures: [
          _bar([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            TempoMark(
              text: 'Allegro con brio',
              bpm: 132,
              beatUnit: DurationType.quarter,
            ),
            MusicText(text: 'espressivo dolce', type: TextType.expression),
            Dynamic(
              type: DynamicType.crescendo,
              customText: 'cresc. poco a poco',
            ),
            RepeatMark(type: RepeatType.dalSegnoAlFine),
            _n('C', 5),
            _n('D', 5),
            _n('E', 5),
            _n('F', 5),
          ])
        ]);

    Future<_Ink> render({MusicScoreTheme? theme}) async => _Ink.of(
          await ScoreRasterizer.renderStaffToImage(
            staff: prose(),
            metadata: metadata,
            width: 900,
            staffSpace: 12,
            pixelRatio: 1.0,
            theme: theme ?? const MusicScoreTheme(),
          ),
        );

    test('an injected family changes the ink and clears the .notdef boxes',
        () async {
      if (!probeTextFontAvailable) {
        markTestSkipped('no system text face to register as '
            '$_probeTextFamily; the injection cannot be observed');
        return;
      }

      MusicTextFont.use(null);
      final without = await render();
      MusicTextFont.use(_probeTextFamily);
      final with_ = await render();
      MusicTextFont.use(null);

      // Measured after the fix at staffSpace 12, 900 px, pixelRatio 1:
      // 14 942 px / 2 boxes without the injection, 6 886 px / 0 boxes with it.
      expect(with_.totalInk, isNot(without.totalInk),
          reason: 'the score rasterised to the SAME ${without.totalInk} px of '
              'ink with and without MusicTextFont.use, which is exactly the '
              'M-30 symptom (the audit measured 76 120 px both ways)');
      expect(without.notdefBoxes, greaterThan(0),
          reason: 'with no text face registered under any name the package '
              'knows, this score is expected to draw .notdef boxes — if it no '
              'longer does, the control below proves nothing');
      expect(with_.notdefBoxes, 0,
          reason: 'an injected REAL face must resolve every prose glyph; '
              '${with_.notdefBoxes} .notdef box(es) survived');
    }, timeout: const Timeout.factor(30));

    test('a theme that supplies its OWN chain still wins, and stays inert',
        () async {
      if (!probeTextFontAvailable) {
        markTestSkipped('no system text face to register as '
            '$_probeTextFamily');
        return;
      }

      // This is the pre-fix behaviour, reproduced on demand: a caller that
      // hands `withMusicTextFallback()` a chain of its own is making a
      // deliberate choice, the extension leaves it alone, and the process-wide
      // injection cannot override it. That contract is unchanged and correct —
      // the bug was that the RENDERER was that caller.
      const owned = MusicScoreTheme(
        expressionTextStyle: TextStyle(
          fontSize: 14,
          fontFamilyFallback: kMusicTextFontFallback,
        ),
        tempoTextStyle: TextStyle(
          fontSize: 16,
          fontFamilyFallback: kMusicTextFontFallback,
        ),
        repeatTextStyle: TextStyle(
          fontSize: 15,
          fontFamilyFallback: kMusicTextFontFallback,
        ),
        dynamicTextStyle: TextStyle(
          fontSize: 14,
          fontFamilyFallback: kMusicTextFontFallback,
        ),
      );

      MusicTextFont.use(null);
      final without = await render(theme: owned);
      MusicTextFont.use(_probeTextFamily);
      final with_ = await render(theme: owned);
      MusicTextFont.use(null);

      // Measured: 14 079 px / 5 boxes, both ways.
      expect(with_.totalInk, without.totalInk,
          reason: 'a caller-supplied chain must survive the injection');
    }, timeout: const Timeout.factor(30));

    test('no style built by SymbolAndTextRenderer pre-supplies the chain', () {
      // The structural half, and the one that fails FIRST if anyone puts the
      // shortcut back. `withMusicTextFallback()` is only reachable by a style
      // that names neither a family nor a chain of its own, so the ten sites
      // must not name one.
      final source =
          File('lib/src/rendering/renderers/symbol_and_text_renderer.dart')
              .readAsStringSync();
      final offenders = <int>[];
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains('fontFamilyFallback')) continue;
        // Prose about the rule is not the rule being broken: the dartdoc on
        // `smuflTextFontFallback` explains at length why the chain is no longer
        // applied here, and naming the field is how it explains it.
        if (line.trimLeft().startsWith('//')) continue;
        offenders.add(i + 1);
      }
      expect(offenders, isEmpty,
          reason: 'symbol_and_text_renderer.dart sets fontFamilyFallback at '
              'line(s) ${offenders.join(', ')}; a style that already carries a '
              'chain makes MusicTextFont.use unreachable (M-30)');
    });
  });

  // ------------------------------------------------------------------ M-23 --
  group('M-23 — a tuplet never draws past the edge of its own canvas', () {
    // Measured before the fix: a 5:4 on C6-G6 rasterised through
    // `ScoreRasterizer.renderStaffToImage` put **74 px of ink on row y = 0**
    // (the E6 ledger lines of the last three notes) and lost the G6 notehead
    // and its ledger line off the top edge entirely.
    //
    // `contentTopOverflow` was never the problem: it reported 38.40 px for that
    // score, correctly and with room to spare, and the image WAS sized 900x231
    // to match. The origin simply never moved with the height —
    // `renderStaffToImage` passed `topLogicalY: 0`, so the extra headroom was
    // appended to the BOTTOM. `renderStaffPages` (and therefore
    // `renderStaffToPng` and `PdfExporter`) never had the bug because it passes
    // `bandHeight * first - extraTop`, which is why the finding only ever
    // reproduced on the single-image path.

    Staff tupletAt(int octave) => Staff(measures: [
          _bar([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            Tuplet(
              actualNotes: 5,
              normalNotes: 4,
              elements: [
                for (final step in ['C', 'D', 'E', 'F', 'G'])
                  _n(step, octave, d: DurationType.eighth),
              ],
            ),
          ])
        ]);

    for (final octave in [6, 3]) {
      test('5:4 on C$octave-G$octave clears both canvas edges', () async {
        final ink = _Ink.of(
          await ScoreRasterizer.renderStaffToImage(
            staff: tupletAt(octave),
            metadata: metadata,
            width: 900,
            staffSpace: 12,
            pixelRatio: 1.0,
          ),
        );
        final image = await ink;
        expect(image.rowInk(0), 0,
            reason: 'row 0 carries ${image.rowInk(0)} px of ink, so the top of '
                'the music is cut off (the audit measured 74 px here for '
                'octave 6)');
        expect(image.rowInk(image.height - 1), 0,
            reason: 'row ${image.height - 1} carries '
                '${image.rowInk(image.height - 1)} px of ink, so the bottom of '
                'the music is cut off');
      }, timeout: const Timeout.factor(30));
    }

    test('the single-image path agrees with the paginated one', () async {
      // The two entry points must reserve the same headroom, or a score looks
      // one way on screen and another in the PDF.
      final staff = tupletAt(6);
      final single = await _Ink.of(
        await ScoreRasterizer.renderStaffToImage(
          staff: staff,
          metadata: metadata,
          width: 900,
          staffSpace: 12,
          pixelRatio: 1.0,
        ),
      );
      final png = await ScoreRasterizer.renderStaffToPng(
        staff: staff,
        metadata: metadata,
        width: 900,
        staffSpace: 12,
        pixelRatio: 1.0,
      );
      final codec = await ui.instantiateImageCodec(png!);
      final paginated = await _Ink.of((await codec.getNextFrame()).image);

      expect(single.rowInk(0), 0);
      expect(paginated.rowInk(0), 0);
      // Both paths must hold the SAME music: the ink totals agree even though
      // the single-image canvas is taller (it also carries the layout's top and
      // bottom page margins).
      expect(single.totalInk, paginated.totalInk,
          reason: 'the two rasterisation paths drew different amounts of ink '
              '(${single.totalInk} vs ${paginated.totalInk}), so one of them '
              'is still clipping');
    }, timeout: const Timeout.factor(30));
  });

  // ------------------------------------------------------------ M-08/M-31 --
  group('M-08/M-31 — the tuplet proportion holds BETWEEN groups too', () {
    Tuplet triplet(DurationType d, String step) => Tuplet(
          actualNotes: 3,
          normalNotes: 2,
          elements: [for (var i = 0; i < 3; i++) _n(step, 5, d: d)],
        );

    test('an eighth group is exactly sqrt(2) wider per note than a sixteenth '
        'group in the same bar', () {
      final eighths = triplet(DurationType.eighth, 'C');
      final sixteenths = triplet(DurationType.sixteenth, 'C');
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          eighths,
          sixteenths,
        ])
      ]);

      final engine = LayoutEngine(staff,
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      engine.layout();
      final xs = engine.noteXPositions;

      double slotSpaces(Tuplet tuplet) {
        final positions =
            tuplet.elements.whereType<Note>().map((n) => xs[n]!).toList();
        return (positions.last - positions.first) /
            ((positions.length - 1) * 12.0);
      }

      final eighthSlot = slotSpaces(eighths);
      final sixteenthSlot = slotSpaces(sixteenths);

      // Measured BEFORE: 1.9000 / 1.9000, ratio 1.0000 — the reader could not
      // tell an eighth triplet from a sixteenth triplet in the same bar.
      // Measured AFTER: 2.6870 / 1.9000, ratio 1.4142.
      expect(eighthSlot, greaterThan(sixteenthSlot + 0.5),
          reason: 'eighth slot ${eighthSlot.toStringAsFixed(4)} SS against '
              'sixteenth ${sixteenthSlot.toStringAsFixed(4)} SS — the two '
              'groups were flattened onto the same legibility floor again');
      expect(eighthSlot / sixteenthSlot, closeTo(1.4142, 0.01));

      // The floor still binds where it must: the NARROWEST group in the bar
      // sits exactly on `minimumSlotSpaces`, which is what makes the scale a
      // legibility guarantee and not just a stretch.
      expect(sixteenthSlot, closeTo(TupletGrid.minimumSlotSpaces, 0.01));
    });

    test('a lone tuplet is unchanged — the context is its own group', () {
      // Nothing that already worked may move. A measure with exactly one
      // tuplet has a context equal to that tuplet, so the scale is byte-for-
      // byte the pre-existing one and no golden shifts.
      final lone = triplet(DurationType.sixteenth, 'C');
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          lone,
        ])
      ]);
      final engine = LayoutEngine(staff,
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      engine.layout();

      expect(engine.tupletContextFloorFor(lone),
          TupletGrid.smallestRawLeafSpaces(lone));
      expect(
        TupletGrid.slotWidths(lone, 12.0,
            contextSmallestLeafSpaces: engine.tupletContextFloorFor(lone)),
        TupletGrid.slotWidths(lone, 12.0),
      );
    });

    test('the rasterised ink gap inside each group stays above minGap',
        () async {
      // The floor exists for LEGIBILITY, so the acceptance is measured in ink,
      // not in slot arithmetic. `SpacingPreferences.normal.minGap` is
      // 0.25 staff spaces.
      final eighths = triplet(DurationType.eighth, 'C');
      final sixteenths = triplet(DurationType.sixteenth, 'C');
      final staff = Staff(measures: [
        _bar([
          Clef(clefType: ClefType.treble),
          TimeSignature(numerator: 4, denominator: 4),
          eighths,
          sixteenths,
        ])
      ]);

      final engine = LayoutEngine(staff,
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      engine.layout();
      final noteY = engine.noteYPositions[eighths.elements.first as Note]!;

      final ink = await _Ink.of(
        await ScoreRasterizer.renderStaffToImage(
          staff: staff,
          metadata: metadata,
          width: 900,
          staffSpace: 12,
          pixelRatio: 1.0,
          theme: const MusicScoreTheme(
            staffLineColor: Color(0x00000000),
            barlineColor: Color(0x00000000),
          ),
        ),
      );

      // All six noteheads sit on one row (every note is a C5), so the last six
      // runs of that row are the noteheads and the gaps between them are the
      // white the reader has to see.
      final runs = ink.runsInRow(noteY.round());
      expect(runs.length, greaterThanOrEqualTo(6));
      final heads = runs.sublist(runs.length - 6);

      // Within the eighth group (heads 0-2) and within the sixteenth group
      // (heads 3-5). Measured: 19 px = 1.583 SS inside the eighths, 9 px =
      // 0.750 SS and 10 px = 0.833 SS inside the sixteenths.
      for (final pair in [[0, 1], [1, 2], [3, 4], [4, 5]]) {
        final gap = heads[pair[1]].start - heads[pair[0]].end - 1;
        expect(gap / 12.0, greaterThanOrEqualTo(0.25),
            reason: 'noteheads ${pair[0]}->${pair[1]} are only $gap px apart '
                '(${(gap / 12.0).toStringAsFixed(3)} SS), under the package\'s '
                'own SpacingPreferences.normal.minGap of 0.25 SS');
      }
    }, timeout: const Timeout.factor(30));
  });

  // ------------------------------------------------------------------ M-46 --
  group('M-46 — an over-full bar is reported, not silently overflowed', () {
    Staff overFull() => Staff(measures: [
          _bar([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            for (var i = 0; i < 40; i++) _n('C', 5, d: DurationType.whole),
          ])
        ]);

    test('the engine names the measure and quotes the overflow factor', () {
      final engine = LayoutEngine(overFull(),
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      final elements = engine.layout();

      // The finding's own measurement: 43 elements on ONE system, reaching
      // maxX = 1865.2 px in a 900 px viewport.
      expect(elements.length, 43);
      expect(elements.map((e) => e.system).toSet(), {0});
      expect(engine.overflowsAvailableWidth(elements), isTrue);

      expect(engine.warnings, hasLength(1));
      final warning = engine.warnings.single;
      expect(warning, contains('measure 1'));
      expect(warning, contains('index 0'));

      // The factor is asserted as a NUMBER with a floor, not as a literal
      // string. It was `contains('2.03x')` and that was brittle in exactly the
      // way this suite exists to prevent: the moment `_getElementWidthSimple`
      // started reserving each duration's REAL notehead advance instead of
      // `noteheadBlack` for everything (Bravura gives `noteheadWhole` 1.688
      // staff spaces against 1.18), forty semibreves legitimately got wider and
      // the factor moved 2.03x -> 2.30x. The old assertion failed for a
      // CORRECTION. What the warning has to prove is that it quotes a real,
      // large overflow — not that the engraving never improves.
      final factor = RegExp(r'\(([0-9.]+)x\)').firstMatch(warning);
      expect(factor, isNotNull, reason: 'the warning must quote a factor: $warning');
      expect(double.parse(factor!.group(1)!), greaterThan(2.0), reason: warning);
    });

    test('the list belongs to ONE pass and stays empty for music that fits',
        () {
      final engine = LayoutEngine(overFull(),
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      engine.layout();
      engine.layout();
      engine.layout();
      expect(engine.warnings, hasLength(1),
          reason: 'warnings accumulated across layout passes; a widget rebuilds '
              'many times a second and would grow the list without bound');

      final ordinary = LayoutEngine(
        Staff(measures: [
          _bar([
            Clef(clefType: ClefType.treble),
            TimeSignature(numerator: 4, denominator: 4),
            _n('C', 5, d: DurationType.whole),
          ])
        ]),
        availableWidth: 900,
        staffSpace: 12,
        metadata: metadata,
      );
      ordinary.layout();
      expect(ordinary.warnings, isEmpty);
    });

    test('the diagnostic does not change the layout', () {
      // M-46 is explicitly a report, not a fix: the geometry must be identical
      // to what it was before the warning existed, or the "no behaviour change"
      // claim in the CHANGELOG is false.
      final quiet = LayoutEngine(overFull(),
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      final loud = LayoutEngine(overFull(),
          availableWidth: 900, staffSpace: 12, metadata: metadata);
      final a = quiet.layoutWithSignature();
      final b = loud.layoutWithSignature();
      expect(a.signature, b.signature);
      expect(loud.warnings, isNotEmpty);
    });
  });
}
