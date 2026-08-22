// lib/src/export/export.dart

/// Export system for Flutter Notemus
///
/// Provides PDF generation and printing capabilities. The exported PDF carries
/// the real engraved notation: `ScoreRasterizer` runs the same
/// layout + rendering pipeline as the on-screen `MusicScore` widget and the
/// resulting raster is embedded page by page (see [PdfExporter]).
///
/// Rasterization requires a live Flutter engine (a running app or
/// `flutter_test`) and loaded SMuFL metadata; without them the export degrades
/// to metadata-only pages and says so in `PdfExporter.warnings`.
library;

export 'pdf_exporter.dart';
export 'pdf_preview_widget.dart';
export 'score_rasterizer.dart';
