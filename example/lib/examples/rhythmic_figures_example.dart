// example/lib/examples/rhythmic_figures_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

// Estrutura de dados para organizar cada figura
class RhythmicFigure {
  final String name;
  final DurationType durationType;

  const RhythmicFigure(this.name, this.durationType);
}

/// Um widget de página que demonstra a renderização de todas as figuras rítmicas
/// de forma organizada, pareando cada nota com sua respectiva pausa.
class RhythmicFiguresExample extends StatelessWidget {
  const RhythmicFiguresExample({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista organizada das figuras que queremos exibir
    const List<RhythmicFigure> figures = [
      RhythmicFigure('Semibreve (Whole Note)', DurationType.whole),
      RhythmicFigure('Mínima (Half Note)', DurationType.half),
      RhythmicFigure('Semínima (Quarter Note)', DurationType.quarter),
      RhythmicFigure('Colcheia (Eighth Note)', DurationType.eighth),
      RhythmicFigure('Semicolcheia (Sixteenth Note)', DurationType.sixteenth),
      RhythmicFigure('Fusa (Thirty-second Note)', DurationType.thirtySecond),
      RhythmicFigure('Semifusa (Sixty-fourth Note)', DurationType.sixtyFourth),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Família de Símbolos: Figuras Rítmicas'),
        backgroundColor: Colors.red.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
        // Mapeia a lista de figuras para criar uma seção para cada uma
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: figures.map((figure) {
            // Para cada figura, cria uma lista de elementos com a nota e a pausa
            final elements = [
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: Duration(figure.durationType),
              ),
              Rest(duration: Duration(figure.durationType)),
            ];

            return _buildSection(
              title: figure.name,
              elements: elements,
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Constrói uma seção de teste para cada par de nota/pausa.
  Widget _buildSection({
    required String title,
    required List<MusicalElement> elements,
  }) {
    final staff = Staff();
    final measure = Measure();
    for (final element in elements) {
      measure.add(element);
    }
    staff.add(measure);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 100, // Altura reduzida para uma única pauta
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: MusicScore(
                staff: staff,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
