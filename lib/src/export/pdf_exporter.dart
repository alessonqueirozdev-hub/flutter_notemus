// lib/src/export/pdf_exporter.dart

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/core.dart';
import '../smufl/smufl_metadata_loader.dart';
import '../theme/music_score_theme.dart';
import 'score_rasterizer.dart';

/// Exports music scores to PDF format.
///
/// ## What the produced PDF contains
/// 1. An optional title page (title / subtitle / composer / arranger /
///    copyright) when [includeMetadata] is true and the score carries any of
///    those fields.
/// 2. One or more **notation pages per staff**: the staff is laid out by
///    [LayoutEngine] and painted by `StaffRenderer` — the very same pipeline
///    the on-screen `MusicScore` widget uses — then rasterized to a PNG that is
///    embedded in the page. Engraving (noteheads, stems, beams, accidentals,
///    slurs, articulations, dynamics, lyrics, barlines, measure numbers) is
///    therefore identical to what is shown on screen. Pages are cut on system
///    boundaries, so a system is never split in half across two pages.
///
/// The notation is embedded as a raster image, not as vector glyphs or
/// selectable text: it prints at the DPI configured in [quality]
/// ([PdfQualitySettings.dpi], 300 by default) and does not scale losslessly
/// beyond that.
///
/// ## Requirements and fallback
/// Rasterization goes through `dart:ui` (`Picture.toImage`), which needs a live
/// Flutter engine — a running app or a `flutter_test` environment. It also
/// needs loaded SMuFL metadata. When either is missing, the exporter does
/// **not** fake a score: it emits the metadata page plus a short page stating
/// that the notation could not be rendered, and appends an explanation to
/// [warnings].
///
/// Example:
/// ```dart
/// final metadata = SmuflMetadata();
/// await metadata.load();
///
/// final exporter = PdfExporter(score: myScore, metadata: metadata);
/// final pdfBytes = await exporter.export();
/// if (exporter.warnings.isNotEmpty) {
///   debugPrint(exporter.warnings.join('\n')); // notation may be missing
/// }
/// ```
class PdfExporter {
  /// The score to export
  final Score score;

  /// PDF page format (default: A4)
  final PdfPageFormat pageFormat;

  /// Whether to include metadata in PDF
  final bool includeMetadata;

  /// Quality settings for PDF rendering
  final PdfQualitySettings quality;

  /// SMuFL metadata used to engrave the notation.
  ///
  /// When null, the process-wide `SmuflMetadata()` instance is used and loaded
  /// on demand. If it still cannot be loaded, the export degrades to
  /// metadata-only pages and records the reason in [warnings].
  final SmuflMetadata? metadata;

  /// Visual theme applied while rendering the notation.
  final MusicScoreTheme theme;

  /// Staff space, in logical pixels, used for the layout pass.
  ///
  /// This is the internal rendering resolution; the rasterized result is scaled
  /// to the page width, so this mostly controls how much music fits per line.
  final double staffSpace;

  /// Non-fatal problems recorded by the last [export] call.
  ///
  /// Empty when the notation was engraved successfully. A non-empty list means
  /// part (or all) of the music is missing from the PDF — the exporter reports
  /// it here instead of silently shipping an empty score.
  final List<String> warnings = <String>[];

  /// Logical pixels per PDF point used when laying the music out.
  ///
  /// The rasterized image is scaled back down by this factor when embedded, so
  /// it only affects the internal layout resolution (and, through
  /// [staffSpace], the resulting music size on the page).
  static const double _logicalPixelsPerPoint = 2.0;

  PdfExporter({
    required this.score,
    this.pageFormat = PdfPageFormat.a4,
    this.includeMetadata = true,
    this.quality = const PdfQualitySettings(),
    this.metadata,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
  });

  /// Export score to PDF bytes
  ///
  /// Returns [Uint8List] containing the PDF document: the optional title page
  /// followed by the engraved notation, one or more pages per staff.
  ///
  /// Always inspect [warnings] afterwards — a non-empty list means the notation
  /// could not be rasterized (see the class documentation) and the PDF holds
  /// metadata only.
  Future<Uint8List> export() async {
    warnings.clear();

    final pdf = pw.Document(
      title: score.title,
      author: score.composer,
      creator: 'Flutter Notemus',
      subject: score.subtitle,
    );

    // Add metadata page if enabled
    if (includeMetadata && (score.title != null || score.composer != null)) {
      pdf.addPage(
        _buildMetadataPage(),
      );
    }

    // Add music pages
    final rendered = await _addMusicPages(pdf);

    if (!rendered) {
      // Honest degradation: never emit fake staff lines that suggest the music
      // was exported when it was not.
      pdf.addPage(_buildNotationUnavailablePage());
    }

    return pdf.save();
  }

  /// Resolves loaded SMuFL metadata, or null when the notation cannot be
  /// engraved (recording the reason in [warnings]).
  Future<SmuflMetadata?> _resolveMetadata() async {
    final resolved = metadata ?? SmuflMetadata();
    if (resolved.isNotLoaded) {
      try {
        await resolved.load();
      } catch (e) {
        warnings.add(
          'SMuFL metadata could not be loaded ($e); the PDF contains metadata '
          'only, not the notation.',
        );
        return null;
      }
    }
    if (resolved.isNotLoaded) {
      warnings.add(
        'SMuFL metadata is not loaded; the PDF contains metadata only, not '
        'the notation.',
      );
      return null;
    }
    return resolved;
  }

  /// Build metadata/title page
  pw.Page _buildMetadataPage() {
    return pw.Page(
      pageFormat: pageFormat,
      build: (context) {
        return pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (score.title != null)
                pw.Text(
                  score.title!,
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (score.subtitle != null) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  score.subtitle!,
                  style: const pw.TextStyle(fontSize: 20),
                ),
              ],
              if (score.composer != null) ...[
                pw.SizedBox(height: 32),
                pw.Text(
                  'by ${score.composer}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
              if (score.arranger != null) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'arranged by ${score.arranger}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
              if (score.copyright != null) ...[
                pw.SizedBox(height: 64),
                pw.Text(
                  score.copyright!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Adds the engraved notation pages to [pdf].
  ///
  /// Every staff of the score is laid out with [LayoutEngine], painted with
  /// `StaffRenderer` and embedded as a raster image, paginated on system
  /// boundaries.
  ///
  /// Returns true when at least one notation page was added; false means the
  /// music could not be engraved and [warnings] explains why.
  Future<bool> _addMusicPages(pw.Document pdf) async {
    final resolvedMetadata = await _resolveMetadata();
    if (resolvedMetadata == null) return false;

    final usableWidth = pageFormat.availableWidth;
    final usableHeight = pageFormat.availableHeight;
    if (!usableWidth.isFinite ||
        !usableHeight.isFinite ||
        usableWidth <= 0 ||
        usableHeight <= 0) {
      warnings.add(
        'The page format leaves no usable area (${usableWidth}x$usableHeight '
        'pt); no notation was rendered.',
      );
      return false;
    }

    final layoutWidth = usableWidth * _logicalPixelsPerPoint;
    // Once the raster is scaled back to the page width, the effective print
    // resolution is `72 * _logicalPixelsPerPoint * pixelRatio` DPI.
    final pixelRatio = (quality.dpi / (72.0 * _logicalPixelsPerPoint)).clamp(
      1.0,
      4.0,
    );

    var addedAnyPage = false;
    for (var groupIndex = 0;
        groupIndex < score.staffGroups.length;
        groupIndex++) {
      final group = score.staffGroups[groupIndex];

      // A group of two or more staves is ONE instrument on a braced system, not
      // a sequence of independent staves.
      //
      // This loop used to rasterize each staff separately through the
      // single-staff path, so a piano part was exported as two one-line staves
      // with headings: no brace, no system barlines, hands not aligned. The
      // grand-staff path reuses `GrandStaffPainter`, the same painter the
      // widget draws with, so the page and the screen agree by construction.
      if (group.staves.length > 1) {
        final added = await _addGrandStaffPages(
          pdf,
          group: group,
          metadata: resolvedMetadata,
          heading: group.name,
          label: group.name ?? 'Group ${groupIndex + 1}',
          layoutWidth: layoutWidth,
          usableWidth: usableWidth,
          usableHeight: usableHeight,
          pixelRatio: pixelRatio,
        );
        addedAnyPage = addedAnyPage || added;
        continue;
      }

      for (var staffIndex = 0; staffIndex < group.staves.length; staffIndex++) {
        final added = await _addStaffPages(
          pdf,
          staff: group.staves[staffIndex],
          metadata: resolvedMetadata,
          heading: _staffHeading(group, groupIndex, staffIndex),
          label: _staffLabel(group, groupIndex, staffIndex),
          layoutWidth: layoutWidth,
          usableWidth: usableWidth,
          usableHeight: usableHeight,
          pixelRatio: pixelRatio,
        );
        addedAnyPage = addedAnyPage || added;
      }
    }

    return addedAnyPage;
  }

  /// Engraves a multi-staff [group] as a braced grand staff and appends it.
  ///
  /// The whole group is rendered in one image so the brace, the system barlines
  /// and the shared horizontal time grid survive into the PDF.
  Future<bool> _addGrandStaffPages(
    pw.Document pdf, {
    required StaffGroup group,
    required SmuflMetadata metadata,
    required String? heading,
    required String label,
    required double layoutWidth,
    required double usableWidth,
    required double usableHeight,
    required double pixelRatio,
  }) async {
    final page = await ScoreRasterizer.renderGroupToPage(
      group: group,
      metadata: metadata,
      width: layoutWidth,
      staffSpace: staffSpace,
      theme: theme,
      pixelRatio: pixelRatio,
    );
    if (page == null) {
      warnings.add(
        '$label could not be rasterized. Rendering notation to PDF requires a '
        'live Flutter engine (a running app or flutter_test); it is not '
        'available in a plain Dart VM.',
      );
      return false;
    }

    final scale = usableWidth / page.logicalWidth;
    final headingHeight = heading == null ? 0.0 : 22.0;
    final imageHeight = math.min(
      page.logicalHeight * scale,
      usableHeight - headingHeight,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: [
            if (heading != null)
              pw.Container(
                height: headingHeight,
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  heading,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            pw.Image(
              pw.MemoryImage(page.pngBytes),
              width: usableWidth,
              height: imageHeight,
              fit: pw.BoxFit.fitWidth,
              alignment: pw.Alignment.topLeft,
            ),
          ],
        ),
      ),
    );
    return true;
  }

  /// Engraves one [staff] and appends its pages to [pdf].
  Future<bool> _addStaffPages(
    pw.Document pdf, {
    required Staff staff,
    required SmuflMetadata metadata,
    required String? heading,
    required String label,
    required double layoutWidth,
    required double usableWidth,
    required double usableHeight,
    required double pixelRatio,
  }) async {
    final layout = ScoreRasterizer.layoutStaff(
      staff: staff,
      metadata: metadata,
      width: layoutWidth,
      staffSpace: staffSpace,
    );

    if (layout.isEmpty) {
      warnings.add('$label contains no renderable elements; it was skipped.');
      return false;
    }

    // Points per logical pixel once the raster is fitted to the page width.
    final scale = usableWidth / layout.logicalWidth;
    final headingHeight = heading == null ? 0.0 : 22.0;
    final systemHeightPt = layout.systemBandHeight * scale;
    if (!systemHeightPt.isFinite || systemHeightPt <= 0) {
      warnings.add('$label produced an invalid system height; it was skipped.');
      return false;
    }

    // Whole systems only: a system is never cut in half across two pages.
    final systemsPerPage = math.max(
      1,
      ((usableHeight - headingHeight) / systemHeightPt).floor(),
    );

    final pages = await ScoreRasterizer.renderStaffPages(
      staff: staff,
      metadata: metadata,
      width: layoutWidth,
      systemsPerPage: systemsPerPage,
      staffSpace: staffSpace,
      theme: theme,
      pixelRatio: pixelRatio,
      precomputedLayout: layout,
    );

    if (pages.isEmpty) {
      warnings.add(
        '$label could not be rasterized. Rendering notation to PDF requires a '
        'live Flutter engine (a running app or flutter_test); it is not '
        'available in a plain Dart VM.',
      );
      return false;
    }

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final page = pages[pageIndex];
      final showHeading = heading != null && pageIndex == 0;
      final maxImageHeight = usableHeight - (showHeading ? headingHeight : 0.0);
      final imageHeight = math.min(page.logicalHeight * scale, maxImageHeight);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                if (showHeading)
                  pw.Container(
                    height: headingHeight,
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      heading,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                pw.Image(
                  pw.MemoryImage(page.pngBytes),
                  width: usableWidth,
                  height: imageHeight,
                  fit: pw.BoxFit.contain,
                  alignment: pw.Alignment.topCenter,
                ),
              ],
            );
          },
        ),
      );
    }

    return true;
  }

  /// Heading printed above the first page of a staff, or null for a
  /// single-staff score (where a heading would only add noise).
  String? _staffHeading(StaffGroup group, int groupIndex, int staffIndex) {
    if (score.staffCount <= 1) return null;
    final base = group.name ?? 'Group ${groupIndex + 1}';
    if (group.staves.length <= 1) return base;
    return '$base - staff ${staffIndex + 1}';
  }

  /// Human-readable identification of a staff, used in [warnings].
  String _staffLabel(StaffGroup group, int groupIndex, int staffIndex) {
    final base = group.name ?? 'Group ${groupIndex + 1}';
    return '$base (staff ${staffIndex + 1})';
  }

  /// Page emitted when the notation could not be engraved.
  ///
  /// States the limitation plainly instead of drawing empty staff lines that
  /// would look like an exported (but silent) score.
  pw.Page _buildNotationUnavailablePage() {
    final outline = <String>[
      for (var i = 0; i < score.staffGroups.length; i++)
        '${score.staffGroups[i].name ?? 'Group ${i + 1}'}: '
            '${score.staffGroups[i].staves.length} staff/staves, '
            '${score.staffGroups[i].staves.fold<int>(0, (sum, s) => sum + s.measures.length)} measures',
    ];

    return pw.Page(
      pageFormat: pageFormat,
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Notation not rendered',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'This PDF contains score metadata only. Rendering the notation '
              'requires loaded SMuFL metadata and a live Flutter engine.',
              style: const pw.TextStyle(fontSize: 11),
            ),
            if (warnings.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              ...warnings.map(
                (w) => pw.Bullet(
                  text: w,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
            if (outline.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Score contents',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              ...outline.map(
                (line) => pw.Bullet(
                  text: line,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Factory: Create exporter for single staff
  factory PdfExporter.fromStaff(
    Staff staff, {
    String? title,
    String? composer,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    SmuflMetadata? metadata,
    MusicScoreTheme theme = const MusicScoreTheme(),
    double staffSpace = 12.0,
  }) {
    final score = Score.singleStaff(
      staff,
      title: title,
      composer: composer,
    );

    return PdfExporter(
      score: score,
      pageFormat: pageFormat,
      metadata: metadata,
      theme: theme,
      staffSpace: staffSpace,
    );
  }

  /// Factory: Create exporter with custom page format
  factory PdfExporter.withFormat(
    Score score,
    PdfPageFormat format, {
    SmuflMetadata? metadata,
  }) {
    return PdfExporter(
      score: score,
      pageFormat: format,
      metadata: metadata,
    );
  }
}

/// Quality settings for PDF export
class PdfQualitySettings {
  /// DPI (dots per inch) for rendering
  final int dpi;

  /// Whether to embed fonts
  final bool embedFonts;

  /// Whether to compress images
  final bool compressImages;

  /// JPEG quality (1-100) if compressing
  final int jpegQuality;

  const PdfQualitySettings({
    this.dpi = 300, // Print quality
    this.embedFonts = true,
    this.compressImages = true,
    this.jpegQuality = 85,
  });

  /// Factory: Print quality (high DPI, no compression)
  factory PdfQualitySettings.print() {
    return const PdfQualitySettings(
      dpi: 600,
      embedFonts: true,
      compressImages: false,
    );
  }

  /// Factory: Screen quality (lower DPI, compressed)
  factory PdfQualitySettings.screen() {
    return const PdfQualitySettings(
      dpi: 150,
      embedFonts: false,
      compressImages: true,
      jpegQuality: 75,
    );
  }

  /// Factory: Balanced quality
  factory PdfQualitySettings.balanced() {
    return const PdfQualitySettings(
      dpi: 300,
      embedFonts: true,
      compressImages: true,
      jpegQuality: 85,
    );
  }
}

/// Helper class for PDF page layouts
class PdfPageLayouts {
  /// A4 portrait (210 x 297 mm)
  static PdfPageFormat get a4Portrait => PdfPageFormat.a4;

  /// A4 landscape (297 x 210 mm)
  static PdfPageFormat get a4Landscape => PdfPageFormat.a4.landscape;

  /// Letter portrait (8.5 x 11 inches)
  static PdfPageFormat get letterPortrait => PdfPageFormat.letter;

  /// Letter landscape (11 x 8.5 inches)
  static PdfPageFormat get letterLandscape => PdfPageFormat.letter.landscape;

  /// Legal (8.5 x 14 inches)
  static PdfPageFormat get legal => PdfPageFormat.legal;

  /// Custom page format
  static PdfPageFormat custom({
    required double width,
    required double height,
    double marginLeft = 72, // 1 inch = 72 points
    double marginTop = 72,
    double marginRight = 72,
    double marginBottom = 72,
  }) {
    return PdfPageFormat(
      width,
      height,
      marginLeft: marginLeft,
      marginTop: marginTop,
      marginRight: marginRight,
      marginBottom: marginBottom,
    );
  }
}

/// Utility functions for PDF export
extension PdfExportExtensions on Score {
  /// Export this score to PDF, with the notation engraved (see [PdfExporter]).
  ///
  /// Needs a live Flutter engine and loaded SMuFL metadata; without them the
  /// PDF degrades to metadata-only pages.
  Future<Uint8List> toPdf({
    PdfPageFormat format = PdfPageFormat.a4,
    bool includeMetadata = true,
    SmuflMetadata? metadata,
    MusicScoreTheme theme = const MusicScoreTheme(),
  }) async {
    final exporter = PdfExporter(
      score: this,
      pageFormat: format,
      includeMetadata: includeMetadata,
      metadata: metadata,
      theme: theme,
    );
    return exporter.export();
  }
}

extension StaffPdfExtensions on Staff {
  /// Export this staff to PDF, with the notation engraved (see [PdfExporter]).
  ///
  /// Needs a live Flutter engine and loaded SMuFL metadata; without them the
  /// PDF degrades to metadata-only pages.
  Future<Uint8List> toPdf({
    String? title,
    String? composer,
    PdfPageFormat format = PdfPageFormat.a4,
    SmuflMetadata? metadata,
    MusicScoreTheme theme = const MusicScoreTheme(),
  }) async {
    final exporter = PdfExporter.fromStaff(
      this,
      title: title,
      composer: composer,
      pageFormat: format,
      metadata: metadata,
      theme: theme,
    );
    return exporter.export();
  }
}
