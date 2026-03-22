// lib/src/export/pdf_exporter.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/core.dart';

/// Exports music scores to PDF format
///
/// Converts [Score] or [Staff] objects to high-quality PDF documents
/// suitable for printing and professional distribution.
///
/// Example:
/// ```dart
/// final score = Score.grandStaff(trebleStaff, bassStaff);
/// final exporter = PdfExporter(score);
/// final pdfBytes = await exporter.export();
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

  PdfExporter({
    required this.score,
    this.pageFormat = PdfPageFormat.a4,
    this.includeMetadata = true,
    this.quality = const PdfQualitySettings(),
  });

  /// Export score to PDF bytes
  ///
  /// Returns [Uint8List] containing the PDF document.
  /// Can be saved to file or shared.
  Future<Uint8List> export() async {
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
    await _addMusicPages(pdf);

    return pdf.save();
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

  /// Add music notation pages to PDF
  Future<void> _addMusicPages(pw.Document pdf) async {
    // TODO: Implement actual music rendering
    // For now, add placeholder pages showing staff groups

    for (var groupIndex = 0; groupIndex < score.staffGroups.length; groupIndex++) {
      final group = score.staffGroups[groupIndex];

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Group name
                if (group.name != null)
                  pw.Text(
                    group.name!,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                pw.SizedBox(height: 16),

                // Placeholder for each staff
                ...group.staves.asMap().entries.map((entry) {
                  final staffIndex = entry.key;
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 40),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Staff ${staffIndex + 1}'),
                        pw.SizedBox(height: 8),

                        // Draw 5 staff lines
                        ...List.generate(5, (lineIndex) {
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(top: 8),
                            width: pageFormat.width - 80,
                            height: 1,
                            color: PdfColors.black,
                          );
                        }),
                      ],
                    ),
                  );
                }),

                // Bracket type indicator
                pw.Text(
                  'Bracket: ${group.bracket.name}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  /// Factory: Create exporter for single staff
  factory PdfExporter.fromStaff(
    Staff staff, {
    String? title,
    String? composer,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) {
    final score = Score.singleStaff(
      staff,
      title: title,
      composer: composer,
    );

    return PdfExporter(
      score: score,
      pageFormat: pageFormat,
    );
  }

  /// Factory: Create exporter with custom page format
  factory PdfExporter.withFormat(
    Score score,
    PdfPageFormat format,
  ) {
    return PdfExporter(
      score: score,
      pageFormat: format,
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
  /// Export this score to PDF
  Future<Uint8List> toPdf({
    PdfPageFormat format = PdfPageFormat.a4,
    bool includeMetadata = true,
  }) async {
    final exporter = PdfExporter(
      score: this,
      pageFormat: format,
      includeMetadata: includeMetadata,
    );
    return exporter.export();
  }
}

extension StaffPdfExtensions on Staff {
  /// Export this staff to PDF
  Future<Uint8List> toPdf({
    String? title,
    String? composer,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final exporter = PdfExporter.fromStaff(
      this,
      title: title,
      composer: composer,
      pageFormat: format,
    );
    return exporter.export();
  }
}
