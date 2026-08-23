// Regression suite for the grand-staff export path (findings M-12 / M-13).
//
// Before this wave the group path had neither pagination nor a width guard:
//   * `PdfExporter._addGrandStaffPages` put EVERY system in one image on ONE
//     page and clamped the image box to the usable page height, so a 40-bar
//     two-staff piano score (14 systems, 3552 logical px) was drawn into
//     706.5 pt of a page that needed 1776 pt — 39.8% of the music, the rest
//     cropped by `BoxFit.fitWidth`;
//   * `ScoreRasterizer.renderGroupToPage` used the REQUESTED width verbatim
//     while the single-staff path widens to the content width, so an over-wide
//     bar requested at 200 px rasterized to a 200 px canvas although the
//     painter had placed its last element at x = 679.99;
//   * and it banded nothing, so a 60-bar group asked for a 10128 px tall
//     texture (the audit measured 15168 px on a 30-system group), past the
//     limit of every mobile GPU.
//
// Every assertion below is anchored on a number measured by executing the code.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:flutter_notemus/flutter_notemus.dart';

Measure _bar(List<MusicalElement> elements) =>
    Measure()..elements.addAll(elements);

Note _note(
  String step,
  int octave, [
  DurationType type = DurationType.quarter,
]) => Note(
  pitch: Pitch(step: step, octave: octave, alter: 0.0),
  duration: Duration(type),
);

/// One hand of a piano part: [bars] bars of four quarters.
Staff _pianoStaff({required int bars, required bool bass}) {
  final measures = <Measure>[];
  for (var i = 0; i < bars; i++) {
    final elements = <MusicalElement>[
      if (i == 0) ...[
        Clef(clefType: bass ? ClefType.bass : ClefType.treble),
        KeySignature(0),
        TimeSignature(numerator: 4, denominator: 4),
      ],
      for (var beat = 0; beat < 4; beat++)
        _note(const ['C', 'D', 'E', 'F', 'G'][(i + beat) % 5], bass ? 3 : 4),
      Barline(type: i == bars - 1 ? BarlineType.final_ : BarlineType.single),
    ];
    measures.add(_bar(elements));
  }
  return Staff(measures: measures);
}

StaffGroup _pianoGroup({required int bars}) => StaffGroup(
  staves: [
    _pianoStaff(bars: bars, bass: false),
    _pianoStaff(bars: bars, bass: true),
  ],
  bracket: BracketType.brace,
  name: 'Piano',
);

/// A single bar whose music is far wider than the width it is laid out for:
/// sixteen sixteenths against a requested 200 logical px.
StaffGroup _overWideGroup() {
  final treble = <MusicalElement>[
    Clef(clefType: ClefType.treble),
    KeySignature(0),
    TimeSignature(numerator: 4, denominator: 4),
    for (var i = 0; i < 16; i++)
      _note(const ['C', 'D', 'E', 'F'][i % 4], 4, DurationType.sixteenth),
    Barline(type: BarlineType.final_),
  ];
  final bass = <MusicalElement>[
    Clef(clefType: ClefType.bass),
    KeySignature(0),
    TimeSignature(numerator: 4, denominator: 4),
    for (var i = 0; i < 16; i++)
      _note(const ['C', 'D', 'E', 'F'][i % 4], 3, DurationType.sixteenth),
    Barline(type: BarlineType.final_),
  ];
  return StaffGroup(
    staves: [
      Staff(measures: [_bar(treble)]),
      Staff(measures: [_bar(bass)]),
    ],
    bracket: BracketType.brace,
  );
}

/// Counts `/Type /Page` objects in raw PDF bytes.
///
/// The `pdf` package writes page dictionaries uncompressed even when it
/// compresses streams, so a byte scan is enough and avoids pulling in a PDF
/// parser just to count pages.
int _countPdfPages(Uint8List bytes) {
  final text = String.fromCharCodes(bytes.where((b) => b < 128));
  return RegExp(r'/Type\s*/Page(?![s])').allMatches(text).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmuflMetadata metadata;

  setUpAll(() async {
    metadata = SmuflMetadata();
    await metadata.load();
    final bytes = await File('assets/smufl/Bravura.otf').readAsBytes();
    await (FontLoader('packages/flutter_notemus/Bravura')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
  });

  group('M-12 grand-staff pagination', () {
    test(
      'a 40-bar piano score reaches the PDF whole, one band of whole systems '
      'per page',
      () async {
        final group = _pianoGroup(bars: 40);
        final usableWidth = PdfPageFormat.a4.availableWidth;
        final usableHeight = PdfPageFormat.a4.availableHeight;
        // Same internal resolution `PdfExporter` uses
        // (`usableWidth * _logicalPixelsPerPoint`).
        final layoutWidth = usableWidth * 2.0;

        final layout = ScoreRasterizer.layoutGroup(
          group: group,
          metadata: metadata,
          width: layoutWidth,
          staffSpace: 12.0,
        );

        // Measured: 14 systems, 3552 logical px tall. Guard the shape of the
        // fixture rather than the exact count, which legitimate spacing work
        // may move.
        expect(layout.systemCount, greaterThan(1));
        expect(layout.logicalHeight, greaterThan(usableHeight));

        final scale = usableWidth / layout.logicalWidth;
        final systemsPerPage =
            ((usableHeight - 22.0) / (layout.systemBandHeight * scale)).floor();
        expect(systemsPerPage, greaterThanOrEqualTo(1));

        final pages = await ScoreRasterizer.renderGroupPages(
          group: group,
          metadata: metadata,
          width: layoutWidth,
          systemsPerPage: systemsPerPage,
          staffSpace: 12.0,
          pixelRatio: 2.0,
          precomputedLayout: layout,
        );

        expect(pages, isNotEmpty);

        // 1. Every system is drawn exactly once, and the bands are contiguous:
        //    no system is dropped, duplicated, or cut in half.
        var drawn = 0;
        var expectedFirst = 0;
        for (final page in pages) {
          expect(page.firstSystem, expectedFirst);
          expect(page.systemCount, greaterThan(0));
          expect(page.systemCount, lessThanOrEqualTo(systemsPerPage));
          expectedFirst += page.systemCount;
          drawn += page.systemCount;
        }
        expect(drawn, layout.systemCount);

        // 2. Each band is a whole number of system blocks; only the outer
        //    edges grow, by the measured overflow above the first system and
        //    below the last.
        for (final page in pages) {
          final extraTop = page.firstSystem == 0 ? layout.topInset : 0.0;
          final extraBottom =
              page.firstSystem + page.systemCount >= layout.systemCount
              ? layout.bottomInset
              : 0.0;
          expect(
            page.logicalHeight,
            closeTo(
              layout.systemBandHeight * page.systemCount +
                  extraTop +
                  extraBottom,
              1e-6,
            ),
          );
          // 3. And the band actually FITS the page it will be drawn on — the
          //    old single-image path wanted 1776 pt on a 706.5 pt box.
          expect(
            page.logicalHeight * scale,
            lessThanOrEqualTo(usableHeight + 1e-6),
          );
        }

        // 4. End to end: the exporter emits one PDF page per band (plus the
        //    title page) and reports no warning.
        final score = Score(staffGroups: [group], title: 'Piano');
        final exporter = PdfExporter(score: score, metadata: metadata);
        final pdfBytes = await exporter.export();
        expect(exporter.warnings, isEmpty);

        expect(
          _countPdfPages(pdfBytes),
          pages.length + 1,
          reason: 'title page + one page per band of systems',
        );
      },
      timeout: const Timeout.factor(30),
    );
  });

  group('M-13 grand-staff rasterizer guards', () {
    test(
      'the canvas is widened to the painter content width, not the requested '
      'width',
      () async {
        final group = _overWideGroup();
        const requestedWidth = 200.0;

        final painter = GrandStaffPainter(
          staffGroup: group,
          staffSpace: 12.0,
          metadata: metadata,
          theme: const MusicScoreTheme(),
          availableWidth: requestedWidth,
        );
        final contentWidth = ScoreRasterizer.measureGroupContentWidth(
          painter,
          staffSpace: 12.0,
          metadata: metadata,
        );

        // Measured: the painter places its last element at x = 679.99 and the
        // content edge (brace pad + element + trailing air) lands at 718.39.
        expect(contentWidth, greaterThan(requestedWidth * 3));

        final layout = ScoreRasterizer.layoutGroup(
          group: group,
          metadata: metadata,
          width: requestedWidth,
          staffSpace: 12.0,
        );
        expect(layout.logicalWidth, greaterThanOrEqualTo(contentWidth));

        final page = await ScoreRasterizer.renderGroupToPage(
          group: group,
          metadata: metadata,
          width: requestedWidth,
          staffSpace: 12.0,
          pixelRatio: 2.0,
        );
        expect(page, isNotNull);
        expect(page!.logicalWidth, greaterThanOrEqualTo(contentWidth));
        // Before the fix this was 400 px (200 logical x pixelRatio 2).
        expect(
          page.pixelWidth,
          greaterThanOrEqualTo((contentWidth * 2).floor()),
        );
      },
      timeout: const Timeout.factor(30),
    );

    test(
      'no rasterized page exceeds the documented maximum texture dimension',
      () async {
        // 60 bars wrap into 20 systems: measured 5064 logical px, which the
        // unguarded path turned into a 10128 px tall texture at pixelRatio 2.
        final group = _pianoGroup(bars: 60);

        final single = await ScoreRasterizer.renderGroupToPage(
          group: group,
          metadata: metadata,
          width: 1000,
          staffSpace: 12.0,
          pixelRatio: 2.0,
        );
        expect(single, isNotNull);
        expect(
          single!.logicalHeight * 2,
          greaterThan(ScoreRasterizer.maxPageDimension),
          reason: 'the fixture must be big enough to trip the guard',
        );
        expect(
          single.pixelWidth,
          lessThanOrEqualTo(ScoreRasterizer.maxPageDimension),
        );
        expect(
          single.pixelHeight,
          lessThanOrEqualTo(ScoreRasterizer.maxPageDimension),
        );

        // Paginated, the same music keeps its full resolution AND stays under
        // the cap on every page.
        final banded = await ScoreRasterizer.renderGroupPages(
          group: group,
          metadata: metadata,
          width: 1000,
          systemsPerPage: 3,
          staffSpace: 12.0,
          pixelRatio: 2.0,
        );
        expect(banded, isNotEmpty);
        var drawn = 0;
        for (final page in banded) {
          expect(
            page.pixelWidth,
            lessThanOrEqualTo(ScoreRasterizer.maxPageDimension),
          );
          expect(
            page.pixelHeight,
            lessThanOrEqualTo(ScoreRasterizer.maxPageDimension),
          );
          // Full resolution kept: 2 device pixels per logical pixel.
          expect(page.pixelHeight, (page.logicalHeight * 2).ceil());
          drawn += page.systemCount;
        }
        expect(drawn, banded.last.firstSystem + banded.last.systemCount);
      },
      timeout: const Timeout.factor(30),
    );
  });
}
