// example/lib/examples/beaming_showcase.dart
// Visual example of the Advanced Beaming System
// Mostra primary beams, secondary beams, e broken beams (fractional)

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Showcase do Advanced Beaming System
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
            _buildTitle('Advanced Beaming System'),
            const SizedBox(height: 8),
            _buildDescription(
              'Demonstration of professional beams following SMuFL and Behind Bars specifications',
            ),
            const SizedBox(height: 24),
            
            // Example 1: Primary Beams (Eighth Notes)
            _buildExampleSection(
              title: '1️⃣ Primary Beams - Eighth Notes (8th notes)',
              description: '4 eighth notes connected by a primary beam',
              staff: _createPrimaryBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Example 2: Secondary Beams (Sixteenth Notes)
            _buildExampleSection(
              title: '2️⃣ Secondary Beams - Sixteenth Notes (16th notes)',
              description: '4 sixteenth notes with primary and secondary beams',
              staff: _createSecondaryBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Example 3: Broken Beams (Dotted rhythm)
            _buildExampleSection(
              title: '3️⃣ Broken Beams - Ritmo Pontuado',
              description: 'Dotted eighth + sixteenth (broken beam)',
              staff: _createBrokenBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Example 4: Tertiary Beams (Spindles)
            _buildExampleSection(
              title: '4️⃣ Tertiary Beams - Thirty-second Notes (32nd notes)',
              description: '8 thirty-second notes with three beam levels',
              staff: _createTertiaryBeamsExample(),
            ),
            
            const SizedBox(height: 32),
            
            // Example 5: Complex Beams
            _buildExampleSection(
              title: '5️⃣ Complex Patterns',
              description: 'Combination of different durations',
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
            '✨ System Features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFeature('✅ Beam thickness: 0.5 staff spaces (SMuFL)'),
          _buildFeature('✅ Beam gap: 0.25 staff spaces (SMuFL)'),
          _buildFeature('✅ Automatic slope based on intervals'),
          _buildFeature('✅ Automatic breaking ("two levels up" rule)'),
          _buildFeature('✅ Broken beams for dotted rhythms'),
          _buildFeature('✅ Support for up to 5 beam levels (128th notes)'),
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

  // EXAMPLE 1: Primary Beams (4 eighth notes)
  Staff _createPrimaryBeamsExample() {
    debugPrint('\\n📊 CREATING EXAMPLE 1: Primary Beams');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    debugPrint('   ✓ Added: Clef + TimeSignature 4/4');
    debugPrint('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');

    // 4 eighth notes ascendentes
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
    debugPrint('   ✓ Added: 4 eighth notes (eighth notes)');

    measure.add(Rest(duration: const Duration(DurationType.half)));
    debugPrint('   ✓ Added: Rest (half note)');

    staff.add(measure);
    debugPrint('✓ Staff created with ${staff.measures.length} measure(s)');
    debugPrint('✓ Total elements in the measure: ${measure.elements.length}');
    return staff;
  }

  // EXAMPLE 2: Secondary Beams (4 sixteenth notes)
  Staff _createSecondaryBeamsExample() {
    debugPrint('\\n📊 CREATING EXAMPLE 2: Secondary Beams');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    debugPrint('   ✓ Added: Clef + TimeSignature 4/4');
    debugPrint('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');

    // 4 semieighth notes
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
    debugPrint('   ✓ Added: 4 semieighth notes (sixteenth notes)');

    measure.add(Rest(duration: const Duration(DurationType.half)));
    measure.add(Rest(duration: const Duration(DurationType.quarter)));
    debugPrint('   ✓ Added: Rests (half + quarter)');

    staff.add(measure);
    debugPrint('✓ Staff created with ${staff.measures.length} measure(s)');
    debugPrint('✓ Total elements in the measure: ${measure.elements.length}');
    return staff;
  }

  // EXAMPLE 3: Broken Beams (dotted rhythm)
  Staff _createBrokenBeamsExample() {
    debugPrint('\\n📊 CREATING EXAMPLE 3: Broken Beams (PUNCTUATED RHYTHM)');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    debugPrint('   ✓ Added: Clef + TimeSignature 4/4');
    debugPrint('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');

    // Eighth Note pontuada + semieighth note (broken beam)
    measure.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.eighth, dots: 1),
    ));
    debugPrint('   ✓ Added: Eighth Note PONTUADA (eighth note with dot)');

    measure.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.sixteenth),
    ));
    debugPrint('   ✓ Added: Sixteenth note (sixteenth note)');
    debugPrint('⚠️ EXPECTED: Broken beam between these 2 notes!');

    measure.add(Rest(duration: const Duration(DurationType.half)));
    measure.add(Rest(duration: const Duration(DurationType.eighth)));
    debugPrint('   ✓ Added: Rests (half + eighth)');

    staff.add(measure);
    debugPrint('✓ Staff created with ${staff.measures.length} measure(s)');
    debugPrint('✓ Total elements in the measure: ${measure.elements.length}');
    return staff;
  }

  // EXAMPLE 4: Tertiary Beams (8 spindles)
  Staff _createTertiaryBeamsExample() {
    debugPrint('\\n📊 CREATING EXAMPLE 4: Tertiary Beams');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    debugPrint('   ✓ Added: Clef + TimeSignature 4/4');
    debugPrint('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');

    // 8 thirty-second notes (32nd notes)
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
    debugPrint('   ✓ Added: 8 thirty-second notes (32nd notes)');

    staff.add(measure);
    debugPrint('✓ Staff created with ${staff.measures.length} measure(s)');
    debugPrint('✓ Total elements in the measure: ${measure.elements.length}');
    return staff;
  }

  // EXAMPLE 5: Complex Patterns
  Staff _createComplexBeamsExample() {
    debugPrint('\\n📊 CREATING EXAMPLE 5: Complex Patterns');
    final staff = Staff();
    final measure = Measure(); // AUTO-BEAMING ativado

    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    debugPrint('   ✓ Added: Clef + TimeSignature 4/4');
    debugPrint('   ✓ AUTO-BEAMING ativo (BeamGrouper corrigido!)');

    // 2 eighth notes
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));

    // 4 semieighth notes
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

    // Eighth Note pontuada + semieighth note
    measure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.eighth, dots: 1),
    ));
    measure.add(Note(
      pitch: const Pitch(step: 'B', octave: 4),
      duration: const Duration(DurationType.sixteenth),
    ));
    debugPrint('   ✓ Added: Mixed durations (2 eighth + 4 sixteenth + dotted eighth + sixteenth)');

    staff.add(measure);
    debugPrint('✓ Staff created with ${staff.measures.length} measure(s)');
    debugPrint('✓ Total elements in the measure: ${measure.elements.length}');
    debugPrint('\\n${'=' * 60}');
    return staff;
  }
}
