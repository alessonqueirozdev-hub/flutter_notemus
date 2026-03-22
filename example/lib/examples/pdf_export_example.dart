// example/lib/examples/pdf_export_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';
import 'package:flutter_notemus/src/export/export.dart';
import 'package:pdf/pdf.dart';

/// Example demonstrating PDF export functionality
///
/// Shows:
/// 1. Export score to PDF
/// 2. Preview PDF before printing
/// 3. Print directly
/// 4. Share PDF
/// 5. Save PDF to file
class PdfExportExample {
  /// Create a sample score for export
  static Score createSampleScore() {
    // Create a simple melody
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(type: 'treble'));
    measure.add(KeySignature(0)); // C major
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Add some notes
    final notes = [
      ('C', 5),
      ('D', 5),
      ('E', 5),
      ('F', 5),
    ];

    for (final (step, octave) in notes) {
      measure.add(Note(
        pitch: Pitch(step: step, octave: octave),
        duration: const Duration(DurationType.quarter),
      ));
    }

    staff.add(measure);

    return Score.singleStaff(
      staff,
      title: 'Simple Melody',
      composer: 'Flutter Notemus',
    );
  }

  /// Create a piano score for export
  static Score createPianoScore() {
    // Treble staff
    final trebleStaff = Staff();
    final trebleMeasure = Measure();

    trebleMeasure.add(Clef(type: 'treble'));
    trebleMeasure.add(KeySignature(0));
    trebleMeasure.add(TimeSignature(numerator: 4, denominator: 4));

    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.whole),
    ));

    trebleStaff.add(trebleMeasure);

    // Bass staff
    final bassStaff = Staff();
    final bassMeasure = Measure();

    bassMeasure.add(Clef(type: 'bass'));
    bassMeasure.add(KeySignature(0));
    bassMeasure.add(TimeSignature(numerator: 4, denominator: 4));

    bassMeasure.add(Chord(
      notes: [
        Note(
          pitch: const Pitch(step: 'C', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'G', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
      ],
      duration: const Duration(DurationType.whole),
    ));

    bassStaff.add(bassMeasure);

    return Score.grandStaff(
      trebleStaff,
      bassStaff,
      title: 'Piano Score',
      composer: 'Example Composer',
    );
  }
}

/// Flutter widget demonstrating PDF export
class PdfExportExampleWidget extends StatelessWidget {
  const PdfExportExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleScore = PdfExportExample.createSampleScore();
    final pianoScore = PdfExportExample.createPianoScore();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Export Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Simple Score Export
          const Text(
            'Simple Score',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => _showPreview(context, sampleScore),
            icon: const Icon(Icons.preview),
            label: const Text('Preview PDF'),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () => _print(context, sampleScore),
            icon: const Icon(Icons.print),
            label: const Text('Print Directly'),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () => _share(context, sampleScore),
            icon: const Icon(Icons.share),
            label: const Text('Share PDF'),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () => _exportToFile(context, sampleScore),
            icon: const Icon(Icons.download),
            label: const Text('Save to File'),
          ),

          const Divider(height: 48),

          // Section: Piano Score Export
          const Text(
            'Piano Score (Grand Staff)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => _showPreview(context, pianoScore),
            icon: const Icon(Icons.preview),
            label: const Text('Preview Piano Score'),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () => _print(context, pianoScore),
            icon: const Icon(Icons.print),
            label: const Text('Print Piano Score'),
          ),

          const Divider(height: 48),

          // Section: Export Options
          const Text(
            'Export Options',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => _exportA4Portrait(context, sampleScore),
            icon: const Icon(Icons.description),
            label: const Text('Export A4 Portrait'),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () => _exportA4Landscape(context, sampleScore),
            icon: const Icon(Icons.description),
            label: const Text('Export A4 Landscape'),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () => _exportLetterSize(context, sampleScore),
            icon: const Icon(Icons.description),
            label: const Text('Export Letter Size (US)'),
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            onPressed: () => _exportHighQuality(context, pianoScore),
            icon: const Icon(Icons.high_quality),
            label: const Text('Export High Quality (Print)'),
          ),
        ],
      ),
    );
  }

  /// Show PDF preview
  void _showPreview(BuildContext context, Score score) {
    score.showPreview(context);
  }

  /// Print score
  Future<void> _print(BuildContext context, Score score) async {
    await score.printScore(context);
  }

  /// Share score
  Future<void> _share(BuildContext context, Score score) async {
    await score.shareScore(context);
  }

  /// Export to file
  Future<void> _exportToFile(BuildContext context, Score score) async {
    final fileName = await ScorePrintDialog.save(
      context,
      score: score,
    );

    if (fileName != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as $fileName')),
      );
    }
  }

  /// Export A4 Portrait
  void _exportA4Portrait(BuildContext context, Score score) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewWidget(
          score: score,
          format: PdfPageLayouts.a4Portrait,
        ),
      ),
    );
  }

  /// Export A4 Landscape
  void _exportA4Landscape(BuildContext context, Score score) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewWidget(
          score: score,
          format: PdfPageLayouts.a4Landscape,
        ),
      ),
    );
  }

  /// Export Letter Size
  void _exportLetterSize(BuildContext context, Score score) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewWidget(
          score: score,
          format: PdfPageLayouts.letterPortrait,
        ),
      ),
    );
  }

  /// Export High Quality
  void _exportHighQuality(BuildContext context, Score score) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewWidget(
          score: score,
          format: PdfPageFormat.a4,
          quality: PdfQualitySettings.print(), // 600 DPI
        ),
      ),
    );
  }
}

/// Demo app for PDF export
class PdfExportDemoApp extends StatelessWidget {
  const PdfExportDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Export Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PdfExportExampleWidget(),
    );
  }
}
