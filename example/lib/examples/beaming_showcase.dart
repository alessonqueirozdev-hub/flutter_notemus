// example/lib/examples/beaming_showcase.dart
// Exemplo visual do Sistema de Beaming Avançado
// Mostra primary beams, secondary beams, e broken beams (fractional)

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Showcase do Sistema de Beaming Avançado
/// Demonstra primary, secondary, broken e tertiary beams
class BeamingShowcase extends StatelessWidget {
  const BeamingShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('🎵 Advanced Beaming System'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle('Sistema de Beaming Avançado'),
            const SizedBox(height: 8),
            _buildDescription(
              'Demonstração de beams profissionais seguindo especificações SMuFL e Behind Bars',
            ),
            const SizedBox(height: 24),
            
            // Exemplo 1: Primary Beams (Colcheias)
            _buildExampleSection(
              title: '1️⃣ Primary Beams - Colcheias (8th notes)',
              description: '4 colcheias conectadas por um beam primário',
              staff: _createPrimaryBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Exemplo 2: Secondary Beams (Semicolcheias)
            _buildExampleSection(
              title: '2️⃣ Secondary Beams - Semicolcheias (16th notes)',
              description: '4 semicolcheias com primary e secondary beams',
              staff: _createSecondaryBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Exemplo 3: Broken Beams (Ritmo pontuado)
            _buildExampleSection(
              title: '3️⃣ Broken Beams - Ritmo Pontuado',
              description: 'Colcheia pontuada + semicolcheia (beam fracionado)',
              staff: _createBrokenBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Exemplo 4: Tertiary Beams (Fusas)
            _buildExampleSection(
              title: '4️⃣ Tertiary Beams - Fusas (32nd notes)',
              description: '8 fusas com três níveis de beams',
              staff: _createTertiaryBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Exemplo 5: Beams Complexos
            _buildExampleSection(
              title: '5️⃣ Padrões Complexos',
              description: 'Combinação de diferentes durações',
              staff: _createComplexBeamsExample(),
            ),
            
            const SizedBox(height: 48),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDescription(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildExampleSection({
    required String title,
    required String description,
    required Staff staff,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: MusicScore(
                staff: staff,
                staffSpace: 14.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✨ Características do Sistema',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFeature('✅ Beam thickness: 0.5 staff spaces (SMuFL)'),
          _buildFeature('✅ Beam gap: 0.25 staff spaces (SMuFL)'),
          _buildFeature('✅ Inclinação automática baseada em intervalos'),
          _buildFeature('✅ Quebra automática (regra "dois níveis acima")'),
          _buildFeature('✅ Broken beams para ritmos pontuados'),
          _buildFeature('✅ Suporte até 5 níveis de beams (128th notes)'),
        ],
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  // EXEMPLO 1: Primary Beams (4 colcheias)
  Staff _createPrimaryBeamsExample() {
    print('\n📊 CRIANDO EXEMPLO 1: Primary Beams');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado
    
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    print('   ✓ Adicionado: Clef + TimeSignature 4/4');
    print('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');
    
    // 4 colcheias ascendentes
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    print('   ✓ Adicionado: 4 colcheias (eighth notes)');
    
    measure.add(Rest(duration: const Duration(DurationType.half)));
    print('   ✓ Adicionado: Rest (half note)');
    
    staff.add(measure);
    print('   ✓ Staff criado com ${staff.measures.length} compasso(s)');
    print('   ✓ Total de elementos no compasso: ${measure.elements.length}');
    return staff;
  }

  // EXEMPLO 2: Secondary Beams (4 semicolcheias)
  Staff _createSecondaryBeamsExample() {
    print('\n📊 CRIANDO EXEMPLO 2: Secondary Beams');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado
    
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    print('   ✓ Adicionado: Clef + TimeSignature 4/4');
    print('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');
    
    // 4 semicolcheias
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    print('   ✓ Adicionado: 4 semicolcheias (sixteenth notes)');
    
    measure.add(Rest(duration: const Duration(DurationType.half)));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    print('   ✓ Adicionado: Rests (half + quarter)');
    
    staff.add(measure);
    print('   ✓ Staff criado com ${staff.measures.length} compasso(s)');
    print('   ✓ Total de elementos no compasso: ${measure.elements.length}');
    return staff;
  }

  // EXEMPLO 3: Broken Beams (ritmo pontuado)
  Staff _createBrokenBeamsExample() {
    print('\n📊 CRIANDO EXEMPLO 3: Broken Beams (RITMO PONTUADO)');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado
    
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    print('   ✓ Adicionado: Clef + TimeSignature 4/4');
    print('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');
    
    // Colcheia pontuada + semicolcheia (broken beam)
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.eighth, dots: 1),
    ));
    print('   ✓ Adicionado: Colcheia PONTUADA (eighth note with dot)');
    
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    print('   ✓ Adicionado: Semicolcheia (sixteenth note)');
    print('   ⚠️  ESPERADO: Broken beam entre estas 2 notas!');
    
    measure.add(Rest(duration: const Duration(DurationType.half)));
    measure.add(Rest(duration: const Duration(DurationType.eighth)));
    print('   ✓ Adicionado: Rests (half + eighth)');
    
    staff.add(measure);
    print('   ✓ Staff criado com ${staff.measures.length} compasso(s)');
    print('   ✓ Total de elementos no compasso: ${measure.elements.length}');
    return staff;
  }

  // EXEMPLO 4: Tertiary Beams (8 fusas)
  Staff _createTertiaryBeamsExample() {
    print('\n📊 CRIANDO EXEMPLO 4: Tertiary Beams');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado
    
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    print('   ✓ Adicionado: Clef + TimeSignature 4/4');
    print('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');
    
    // 8 fusas (32nd notes)
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 5),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 6),
      duration: const Duration(DurationType.thirtySecond),
    ));
    measure.add(Rest(duration: const Duration(DurationType.half)));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    print('   ✓ Adicionado: 8 fusas (32nd notes)');
    
    staff.add(measure);
    print('   ✓ Staff criado com ${staff.measures.length} compasso(s)');
    print('   ✓ Total de elementos no compasso: ${measure.elements.length}');
    return staff;
  }

  // EXEMPLO 5: Padrões Complexos
  Staff _createComplexBeamsExample() {
    print('\n📊 CRIANDO EXEMPLO 5: Padrões Complexos');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado
    
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    print('   ✓ Adicionado: Clef + TimeSignature 4/4');
    print('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');
    
    // 2 colcheias
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    
    // 4 semicolcheias
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    
    // Colcheia pontuada + semicolcheia
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.eighth, dots: 1),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.sixteenth),
    ));
    print('   ✓ Adicionado: Mix de durações (2 eighth + 4 sixteenth + dotted eighth + sixteenth)');
    
    staff.add(measure);
    print('   ✓ Staff criado com ${staff.measures.length} compasso(s)');
    print('   ✓ Total de elementos no compasso: ${measure.elements.length}');
    print('\n' + '='*60);
    return staff;
  }
}
