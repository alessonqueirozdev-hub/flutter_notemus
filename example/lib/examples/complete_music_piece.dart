// example/lib/examples/complete_music_piece.dart
// Ode to Joy - Ludwig van Beethoven (Sinfonia nº 9)

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class CompleteMusicPieceExample extends StatelessWidget {
  const CompleteMusicPieceExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildPieceInfo(),
            const SizedBox(height: 24),
            _createFullScore(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ode to Joy',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ludwig van Beethoven - Symphony No. 9 in D minor, Op. 125',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildPieceInfo() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note, color: Colors.deepPurple, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ode to Joy',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ludwig van Beethoven (1770-1827)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Key:', 'D major'),
            _buildInfoRow('Compass:', '4/4'),
            _buildInfoRow('Tempo:', 'Allegro assai ♩= 120'),
            _buildInfoRow('Ano:', '1824'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _createFullScore() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complete Sheet Music',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.all(16),
              child: _createMusicScore(),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _createMusicScore() {
    final staff = Staff();

    // === COMPASSO 1: F# F# G A ===
    final measure1 = Measure();
    measure1.add(Clef(clefType: ClefType.treble));
    measure1.add(KeySignature(2)); // D major (F#, C#)
    measure1.add(TimeSignature(numerator: 4, denominator: 4));
    measure1.add(TempoMark(
      text: 'Allegro assai',
      beatUnit: DurationType.quarter,
      bpm: 120,
    ));

    // F# F# G A (F# F# G A) - F# is already in the armature!
    measure1.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito (armadura)
      duration: const Duration(DurationType.quarter),
      dynamicElement: Dynamic(type: DynamicType.mezzoForte),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure1.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 2: A G F# E ===
    final measure2 = Measure();

    // A G F# E (Lá Sol Fá# Mi)
    measure2.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));

    measure2.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 3: D D E F# ===
    final measure3 = Measure();

    // D D E F# (Re Re Mi Fá#)
    measure3.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure3.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure3.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    measure3.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 4: F#. AND AND ===
    final measure4 = Measure();

    // F#. (F# dotted - dotted quarter note)
    measure4.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter, dots: 1),
    ));

    // E (Mi - eighth note)
    measure4.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));

    // E (E - half note)
    measure4.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    
    // BREATH (comma) - as in the reference score
    measure4.add(Breath(type: BreathType.comma));

    // === BAR 5: F# F# G A (repeat) ===
    final measure5 = Measure();
    
    measure5.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure5.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure5.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure5.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 6: A G F# E ===
    final measure6 = Measure();
    
    measure6.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure6.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure6.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure6.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 7: D D E F# ===
    final measure7 = Measure();
    
    measure7.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure7.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure7.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure7.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));

    // === METER 8: E. D D (ends in D) ===
    final measure8 = Measure();
    
    // E. (E dotted - dotted quarter note)
    measure8.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter, dots: 1),
    ));
    
    // D (Re - eighth note)
    measure8.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    
    // D (D - half note)
    measure8.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.half),
    ));
    
    // BREATH MARK (comma)
    measure8.add(Breath(type: BreathType.comma));

    // === METER 9: E E F# D (contrasting section) ===
    // REPEAT BAR - Start of section B (as in sheet music)
    final measure9 = Measure();
    measure9.add(Barline(type: BarlineType.repeatForward)); // ‖:
    
    measure9.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure9.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure9.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure9.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 10: E F# G F# D ===
    final measure10 = Measure();
    
    measure10.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    // F# G (eighth notes ligadas)
    measure10.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.eighth),
    ));
    
    measure10.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    
    measure10.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure10.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 11: E F# G F# E ===
    final measure11 = Measure();
    
    measure11.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    // F# G (eighth notes)
    measure11.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.eighth),
    ));
    
    measure11.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    
    measure11.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure11.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 12: D E A (low note) ===
    final measure12 = Measure();
    
    measure12.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure12.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    // A bass (octave 4)
    measure12.add(Note(
      pitch: const Pitch(step: 'A', octave: 4),
      duration: const Duration(DurationType.half),
    ));
    
    // BREATH MARK (comma)
    measure12.add(Breath(type: BreathType.comma));

    // === BAR 13: F# F# G A (return to theme) ===
    final measure13 = Measure();
    
    measure13.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure13.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure13.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure13.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 14: A G F# E ===
    final measure14 = Measure();
    
    measure14.add(Note(
      pitch: const Pitch(step: 'A', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure14.add(Note(
      pitch: const Pitch(step: 'G', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure14.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));
    
    measure14.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 15: D D E F# ===
    final measure15 = Measure();
    
    measure15.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure15.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure15.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    
    measure15.add(Note(
      pitch: const Pitch(step: 'F', octave: 5), // F# implícito
      duration: const Duration(DurationType.quarter),
    ));

    // === COMPASS 16: E. D D (final) ===
    final measure16 = Measure();
    
    // E. (E dotted - dotted quarter note)
    measure16.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter, dots: 1),
      articulations: const [ArticulationType.accent],
    ));
    
    // D (Re - eighth note)
    measure16.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.eighth),
    ));
    
    // D (D - half note FINAL)
    measure16.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.half),
      dynamicElement: Dynamic(type: DynamicType.forte),
    ));
    
    // FINAL BREATH MARK (comma)
    measure16.add(Breath(type: BreathType.comma));

    staff.add(measure1);
    staff.add(measure2);
    staff.add(measure3);
    staff.add(measure4);
    staff.add(measure5);
    staff.add(measure6);
    staff.add(measure7);
    staff.add(measure8);
    staff.add(measure9);
    staff.add(measure10);
    staff.add(measure11);
    staff.add(measure12);
    staff.add(measure13);
    staff.add(measure14);
    staff.add(measure15);
    staff.add(measure16);

    return SizedBox(
      height: 800, // Aumentar altura para comportar 16 compassos
      child: MusicScore(
        staff: staff,
        staffSpace: 14,
        theme: const MusicScoreTheme(
          noteheadColor: Colors.black,
          stemColor: Colors.black87,
          staffLineColor: Colors.black54,
          clefColor: Colors.black,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Elements Demonstrated:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildLegendRow('🎼', 'Treble Clef in D Major (2 sharps)'),
          _buildLegendRow('🎵', 'COMPLETE theme of the 9th Symphony (16 measures)'),
          _buildLegendRow('📝', '4/4 Time (Common)'),
          _buildLegendRow('⏱️', 'Allegro assai ♩= 120'),
          _buildLegendRow('🎹', '4 phrases: A A B A (classical form)'),
          _buildLegendRow('🎻', 'Complete melody with dynamics'),
          _buildLegendRow('✨', 'Professional SMuFL spacing'),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String emoji, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
