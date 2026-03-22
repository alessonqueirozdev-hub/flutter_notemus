// example/lib/examples/key_signatures_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Um widget de página que demonstra a renderização de todas as armaduras de clave.
class KeySignaturesExample extends StatelessWidget {
  const KeySignaturesExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Armaduras de Clave'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildKeySignatureSection(
              title: 'Armaduras com Sustenidos (#)',
              description:
                  'Exibe as armaduras de clave com 1 a 7 sustenidos. A ordem dos sustenidos (Fá, Dó, Sol, Ré, Lá, Mi, Si) e seu posicionamento vertical devem estar corretos.',
              isSharp: true,
            ),
            const SizedBox(height: 24),
            _buildKeySignatureSection(
              title: 'Armaduras com Bemóis (♭)',
              description:
                  'Exibe as armaduras de clave com 1 a 7 bemóis. A ordem dos bemóis (Si, Mi, Lá, Ré, Sol, Dó, Fá) e seu posicionamento vertical devem estar corretos.',
              isSharp: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói uma seção de teste para armaduras de clave.
  Widget _buildKeySignatureSection({
    required String title,
    required String description,
    required bool isSharp,
  }) {
    // Gera uma lista de elementos musicais para cada armadura de 1 a 7 acidentes
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
            // Renderiza uma pauta para cada armadura
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
