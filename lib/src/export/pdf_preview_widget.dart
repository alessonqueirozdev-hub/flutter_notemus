// lib/src/export/pdf_preview_widget.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/core.dart';
import 'pdf_exporter.dart';

/// Widget for previewing and printing music scores as PDF
///
/// Provides a full-featured PDF preview with:
/// - Zoom controls
/// - Page navigation
/// - Print button
/// - Share button
/// - Save button
///
/// Example:
/// ```dart
/// // Show PDF preview
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => PdfPreviewWidget(score: myScore),
///   ),
/// );
/// ```
class PdfPreviewWidget extends StatelessWidget {
  /// The score to preview
  final Score score;

  /// PDF page format
  final PdfPageFormat format;

  /// Whether to include metadata page
  final bool includeMetadata;

  /// Quality settings
  final PdfQualitySettings quality;

  /// Title for the preview screen
  final String? title;

  const PdfPreviewWidget({
    super.key,
    required this.score,
    this.format = PdfPageFormat.a4,
    this.includeMetadata = true,
    this.quality = const PdfQualitySettings(),
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? score.title ?? 'Score Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF',
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: true,
        canChangePageFormat: true,
        canDebug: false,
        pdfFileName: _generateFileName(),
      ),
    );
  }

  /// Generate PDF for preview
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final exporter = PdfExporter(
      score: score,
      pageFormat: format,
      includeMetadata: includeMetadata,
      quality: quality,
    );
    return exporter.export();
  }

  /// Generate appropriate file name
  String _generateFileName() {
    final baseTitle = score.title ?? 'score';
    final safeName = baseTitle.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = safeName.isEmpty ? 'score' : safeName.toLowerCase().replaceAll(' ', '_');
    return '$fileName.pdf';
  }

  /// Share PDF
  Future<void> _sharePdf(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdf(format);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: _generateFileName(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }
}

/// Simple print dialog for scores
class ScorePrintDialog {
  /// Show print dialog for a score
  ///
  /// Example:
  /// ```dart
  /// await ScorePrintDialog.print(
  ///   context,
  ///   score: myScore,
  ///   format: PdfPageFormat.a4,
  /// );
  /// ```
  static Future<void> print(
    BuildContext context, {
    required Score score,
    PdfPageFormat format = PdfPageFormat.a4,
    bool includeMetadata = true,
    PdfQualitySettings quality = const PdfQualitySettings(),
  }) async {
    try {
      final exporter = PdfExporter(
        score: score,
        pageFormat: format,
        includeMetadata: includeMetadata,
        quality: quality,
      );

      final pdfBytes = await exporter.export();

      await Printing.layoutPdf(
        onLayout: (_) => Future.value(pdfBytes),
        name: score.title ?? 'Score',
        format: format,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print: $e')),
        );
      }
    }
  }

  /// Share PDF without showing preview
  static Future<void> share(
    BuildContext context, {
    required Score score,
    PdfPageFormat format = PdfPageFormat.a4,
    bool includeMetadata = true,
  }) async {
    try {
      final exporter = PdfExporter(
        score: score,
        pageFormat: format,
        includeMetadata: includeMetadata,
      );

      final pdfBytes = await exporter.export();

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${score.title?.replaceAll(' ', '_') ?? 'score'}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  /// Save PDF to file
  ///
  /// Returns the file path if successful, null otherwise
  static Future<String?> save(
    BuildContext context, {
    required Score score,
    PdfPageFormat format = PdfPageFormat.a4,
    bool includeMetadata = true,
    String? customFileName,
  }) async {
    try {
      final exporter = PdfExporter(
        score: score,
        pageFormat: format,
        includeMetadata: includeMetadata,
      );

      final pdfBytes = await exporter.export();

      final fileName = customFileName ??
          '${score.title?.replaceAll(' ', '_') ?? 'score'}.pdf';

      // On mobile/web, this will trigger download/share dialog
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

      return fileName;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
      return null;
    }
  }
}

/// Extension methods for easy PDF operations
extension ScorePdfOperations on Score {
  /// Show PDF preview for this score
  void showPreview(
    BuildContext context, {
    PdfPageFormat format = PdfPageFormat.a4,
    bool includeMetadata = true,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewWidget(
          score: this,
          format: format,
          includeMetadata: includeMetadata,
        ),
      ),
    );
  }

  /// Print this score
  Future<void> printScore(
    BuildContext context, {
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    await ScorePrintDialog.print(
      context,
      score: this,
      format: format,
    );
  }

  /// Share this score as PDF
  Future<void> shareScore(
    BuildContext context, {
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    await ScorePrintDialog.share(
      context,
      score: this,
      format: format,
    );
  }
}
