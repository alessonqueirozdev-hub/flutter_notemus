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
            _buildScoreCard(),
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
                const Icon(Icons.music_note,
                    color: Colors.deepPurple, size: 32),
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
            _buildInfoRow('Time signature:', '4/4'),
            _buildInfoRow('Tempo:', 'Allegro assai (quarter = 120)'),
            _buildInfoRow('Year:', '1824'),
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

  Widget _buildScoreCard() {
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
              child: _buildMusicScore(),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicScore() {
    final staff = _buildOdeToJoyStaff();

    return SizedBox(
      height: 800,
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

  Staff _buildOdeToJoyStaff() {
    final staff = Staff();

    final measure1 = Measure()
      ..add(Clef(clefType: ClefType.treble))
      ..add(KeySignature(2))
      ..add(TimeSignature(numerator: 4, denominator: 4))
      ..add(
        TempoMark(
          text: 'Allegro assai',
          beatUnit: DurationType.quarter,
          bpm: 120,
        ),
      )
      ..add(
          _note('F', 5, DurationType.quarter, dynamic: DynamicType.mezzoForte))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('G', 5, DurationType.quarter))
      ..add(_note('A', 5, DurationType.quarter));

    final measure2 = Measure()
      ..add(_note('A', 5, DurationType.quarter))
      ..add(_note('G', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter));

    final measure3 = Measure()
      ..add(_note('D', 5, DurationType.quarter))
      ..add(_note('D', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter));

    final measure4 = Measure()
      ..add(_note('F', 5, DurationType.quarter, dots: 1))
      ..add(_note('E', 5, DurationType.eighth))
      ..add(_note('E', 5, DurationType.half))
      ..add(Breath(type: BreathType.comma));

    final measure5 = Measure()
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('G', 5, DurationType.quarter))
      ..add(_note('A', 5, DurationType.quarter));

    final measure6 = Measure()
      ..add(_note('A', 5, DurationType.quarter))
      ..add(_note('G', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter));

    final measure7 = Measure()
      ..add(_note('D', 5, DurationType.quarter))
      ..add(_note('D', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter));

    final measure8 = Measure()
      ..add(_note('E', 5, DurationType.quarter, dots: 1))
      ..add(_note('D', 5, DurationType.eighth))
      ..add(_note('D', 5, DurationType.half))
      ..add(Breath(type: BreathType.comma));

    final measure9 = Measure()
      ..add(Barline(type: BarlineType.repeatForward))
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('D', 5, DurationType.quarter));

    final measure10 = Measure(
      beamingMode: BeamingMode.manual,
      manualBeamGroups: const [
        [1, 2],
      ],
    )
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.eighth))
      ..add(_note('G', 5, DurationType.eighth))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('D', 5, DurationType.quarter));

    final measure11 = Measure(
      beamingMode: BeamingMode.manual,
      manualBeamGroups: const [
        [1, 2],
      ],
    )
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.eighth))
      ..add(_note('G', 5, DurationType.eighth))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter));

    final measure12 = Measure()
      ..add(_note('D', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('A', 4, DurationType.half))
      ..add(Breath(type: BreathType.comma));

    final measure13 = Measure()
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('G', 5, DurationType.quarter))
      ..add(_note('A', 5, DurationType.quarter));

    final measure14 = Measure()
      ..add(_note('A', 5, DurationType.quarter))
      ..add(_note('G', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter));

    final measure15 = Measure()
      ..add(_note('D', 5, DurationType.quarter))
      ..add(_note('D', 5, DurationType.quarter))
      ..add(_note('E', 5, DurationType.quarter))
      ..add(_note('F', 5, DurationType.quarter));

    final measure16 = Measure()
      ..add(
        _note(
          'E',
          5,
          DurationType.quarter,
          dots: 1,
          articulations: const [ArticulationType.accent],
        ),
      )
      ..add(_note('D', 5, DurationType.eighth))
      ..add(_note('D', 5, DurationType.half, dynamic: DynamicType.forte))
      ..add(Barline(type: BarlineType.final_));

    staff
      ..add(measure1)
      ..add(measure2)
      ..add(measure3)
      ..add(measure4)
      ..add(measure5)
      ..add(measure6)
      ..add(measure7)
      ..add(measure8)
      ..add(measure9)
      ..add(measure10)
      ..add(measure11)
      ..add(measure12)
      ..add(measure13)
      ..add(measure14)
      ..add(measure15)
      ..add(measure16);

    return staff;
  }

  Note _note(
    String step,
    int octave,
    DurationType type, {
    int dots = 0,
    DynamicType? dynamic,
    List<ArticulationType> articulations = const [],
  }) {
    return Note(
      pitch: Pitch(step: step, octave: octave),
      duration: Duration(type, dots: dots),
      articulations: articulations,
      dynamicElement: dynamic == null ? null : Dynamic(type: dynamic),
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
            'Elements demonstrated:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildLegendRow('Clef', 'Treble clef in D major (2 sharps)'),
          _buildLegendRow('Theme', 'Complete 16-measure melody'),
          _buildLegendRow('Meter', '4/4 throughout the piece'),
          _buildLegendRow('Tempo', 'Allegro assai with metronome marking'),
          _buildLegendRow('Form', 'Four phrases in A A B A structure'),
          _buildLegendRow('Detail', 'Manual beams in the two eighth-note bars'),
          _buildLegendRow('Finish', 'Explicit final double barline'),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
