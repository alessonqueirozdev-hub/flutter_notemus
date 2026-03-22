// example/lib/examples/ornaments_example.dart
// ARQUIVO UNIFICADO E CORRIGIDO

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Widget que demonstra a renderização de todos os ornamentos musicais,
/// seguindo as regras tipográficas profissionais.
/// Este arquivo é a fonte única da verdade para exemplos de ornamentos.
class OrnamentsExample extends StatelessWidget {
  const OrnamentsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guia Completo de Ornamentos'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              'Guia de Ornamentos SMuFL',
              'Demonstração do posicionamento correto de ornamentos conforme as regras de notação profissional.',
            ),
            _buildSection(
              title: 'Regra Fundamental: Posicionamento em Voz Única',
              description:
                  'Em música de voz única, ornamentos como trilos e mordentes são SEMPRE posicionados ACIMA da pauta, independentemente da direção da haste da nota.',
              staff: _createSingleVoiceStaff(),
            ),
            _buildSection(
              title: 'Regra de Polifonia: Múltiplas Vozes',
              description:
                  'Em pautas com múltiplas vozes, os ornamentos são posicionados na parte externa: acima para a voz superior (soprano) e abaixo para a voz inferior (contralto).',
              staff: _createDoubleVoiceStaff(),
            ),
            _buildSection(
              title: 'Trilos (Trills)',
              description:
                  'Trinados simples e com alterações cromáticas. O posicionamento é sempre acima em voz única.',
              staff: _createTrillsStaff(),
            ),
            _buildSection(
              title: 'Mordentes (Mordents)',
              description:
                  'Mordentes superiores e inferiores. O posicionamento segue a mesma regra dos trilos.',
              staff: _createMordentsStaff(),
            ),
            _buildSection(
              title: 'Grupetos (Turns)',
              description: 'Grupetos simples, invertidos e com corte.',
              staff: _createTurnsStaff(),
            ),
            _buildSection(
              title: 'Apojaturas e Acciaccaturas (Grace Notes)',
              description:
                  'Notas de ornamento que precedem a nota principal. A ligadura para a nota principal é essencial.',
              staff: _createGraceNotesStaff(),
            ),
            _buildSection(
              title: 'Fermatas',
              description:
                  'A fermata padrão é sempre acima. Versões específicas como a "fermataBelow" são usadas para posicionamento inferior explícito.',
              staff: _createFermatasStaff(),
            ),
            _buildSection(
              title: 'Arpejos e Glissandos',
              description:
                  'Arpejos são posicionados à esquerda do acorde. Glissandos são representados por linhas entre as notas.',
              staff: _createArpeggiosAndGlissandosStaff(),
            ),
            _buildSection(
              title: 'Efeitos de Articulação (Jazz/Moderno)',
              description:
                  'Scoop, Fall, Doit e Plop, comuns em notação de jazz.',
              staff: _createJazzEffectsStaff(),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o cabeçalho da página.
  Widget _buildHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  /// Constrói uma seção de exemplo com título, descrição e partitura.
  Widget _buildSection({
    required String title,
    required String description,
    required Staff staff,
  }) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            Container(
              height: 120,
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

  /// Exemplo da regra fundamental para voz única.
  Staff _createSingleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Nota com haste para CIMA -> Ornamento ACIMA
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));
    // Nota com haste para BAIXO -> Ornamento ACIMA
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));
    // Nota muito grave (haste para CIMA) -> Ornamento ACIMA
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 3),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));
    // Nota muito aguda (haste para BAIXO) -> Ornamento ACIMA
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.shortTrill)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Exemplo da regra para múltiplas vozes.
  Staff _createDoubleVoiceStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 2, denominator: 4));

    // Voz 1 (Soprano) - Hastes para CIMA, Ornamentos ACIMA
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 1,
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));

    // Voz 2 (Contralto) - Hastes para BAIXO, Ornamentos ABAIXO
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      voice: 2,
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Exemplo focado em Trilos.
  Staff _createTrillsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trill)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trillSharp)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.trillFlat)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.shortTrill)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Exemplo focado em Mordentes.
  Staff _createMordentsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordent)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.invertedMordent)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordentUpperPrefix)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.mordentLowerPrefix)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Exemplo focado em Grupetos.
  Staff _createTurnsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turn)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turnInverted)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.turnSlash)],
    ));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));

    staff.add(measure);
    return staff;
  }

  /// Exemplo focado em Notas de Graça.
  Staff _createGraceNotesStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Acciaccatura (com corte)
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.eighth),
      ornaments: [Ornament(type: OrnamentType.acciaccatura)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // Appoggiatura (sem corte)
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.eighth),
      ornaments: [Ornament(type: OrnamentType.appoggiaturaUp)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.half),
    ));

    staff.add(measure);
    return staff;
  }

  /// Exemplo focado em Fermatas.
  Staff _createFermatasStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Fermata padrão acima
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermata)],
    ));

    // Fermata explícita abaixo
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.half),
      ornaments: [Ornament(type: OrnamentType.fermataBelow)],
    ));

    staff.add(measure);
    return staff;
  }

  /// Exemplo focado em Arpejos e Glissandos.
  Staff _createArpeggiosAndGlissandosStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    // Arpejo
    measure.add(Chord(
      notes: [
        Note(
            pitch: const Pitch(step: 'C', octave: 4),
            duration: const Duration(DurationType.quarter)),
        Note(
            pitch: const Pitch(step: 'E', octave: 4),
            duration: const Duration(DurationType.quarter)),
        Note(
            pitch: const Pitch(step: 'G', octave: 4),
            duration: const Duration(DurationType.quarter)),
      ],
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.arpeggio)],
    ));

    // Glissando (requer duas notas para desenhar a linha)
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.glissando)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure.add(Rest(duration: const Duration(DurationType.quarter)));

    staff.add(measure);
    return staff;
  }

  /// Exemplo focado em efeitos de jazz e música moderna.
  Staff _createJazzEffectsStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));

    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.scoop)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.fall)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.doit)],
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.quarter),
      ornaments: [Ornament(type: OrnamentType.plop)],
    ));

    staff.add(measure);
    return staff;
  }
}
