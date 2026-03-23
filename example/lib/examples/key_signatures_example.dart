// example/lib/examples/key_signatures_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// A page widget that demonstrates the rendering of all key signatures.
class KeySignaturesExample extends StatelessWidget {
  const KeySignaturesExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbol Family: Key Signatures'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildKeySignatureSection(
              title: 'Signatures with Sharps (#)',
              description:
                  'Displays key signatures with 1 to 7 sharps. The order of the sharps (F, C, G, D, A, E, B) and their vertical positioning must be correct.',
              isSharp: true,
            ),
            const SizedBox(height: 24),
            _buildKeySignatureSection(
              title: 'Signatures with Flats (♭)',
              description:
                  'Displays key signatures with 1 to 7 flats. The order of the flats (B, E, A, D, G, C, F) and their vertical positioning must be correct.',
              isSharp: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a test section for key signatures.
  Widget _buildKeySignatureSection({
    required String title,
    required String description,
    required bool isSharp,
  }) {
    // Generates a list of musical elements for each signature from 1 to 7 accidentals
    final List<List<MusicalElement>> allKeySignatures =
        List.generate(7, (index) {
      final count = index + 1;
      return [
        Clef(clefType: ClefType.treble),
        KeySignature(isSharp ? count : -count),
        Rest(duration: const Duration(DurationType.whole)),
      ];
    });

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            // Renders a staff for each armature
            ...allKeySignatures.map((elements) {
              final staff = Staff();
              final measure = Measure();
              for (final element in elements) {
                measure.add(element);
              }
              staff.add(measure);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: MusicScore(
                    staff: staff,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
