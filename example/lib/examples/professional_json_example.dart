// example/lib/examples/professional_json_example.dart
// Ode à Alegria - JSON Profissional Completo

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/parsers/json_parser.dart';

class ProfessionalJsonExample extends StatelessWidget {
  const ProfessionalJsonExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🎵 ODE À ALEGRIA - JSON PROFISSIONAL COMPLETO
    // This JSON is equivalent to the complete_music_piece.dart example
    const jsonString = '''
    {
      "measures": [
        {
          "elements": [
            {"type": "clef", "clefType": "treble"},
            {"type": "keySignature", "count": 2},
            {"type": "timeSignature", "numerator": 4, "denominator": 4},
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "G", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "A", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
          ]
        },
        {
          "elements": [
            {"type": "note", "pitch": {"step": "A", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "G", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
          ]
        },
        {
          "elements": [
            {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
          ]
        },
        {
          "elements": [
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter", "dots": 1}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "eighth"}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "half"}}
          ]
        },
        {
          "elements": [
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "G", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "A", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
          ]
        },
        {
          "elements": [
            {"type": "note", "pitch": {"step": "A", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "G", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
          ]
        },
        {
          "elements": [
            {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}}
          ]
        },
        {
          "elements": [
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter", "dots": 1}},
            {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "eighth"}},
            {"type": "note", "pitch": {"step": "D", "octave": 5, "alter": 0.0}, "duration": {"type": "half"}},
            {"type": "barline", "barlineType": "final_"}
          ]
        }
      ]
    }
    ''';

    // 📊 PARSEAR JSON → STAFF
    print('🎵 Parseando JSON profissional...');
    final staff = JsonMusicParser.parseStaff(jsonString);
    print('✅ Staff created with ${staff.measures.length} measures');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('JSON Profissional - Ode à Alegria'),
        backgroundColor: Colors.deepPurple,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 HEADER
            _buildHeader(),
            const SizedBox(height: 24),

            // 📊 INFO CARD
            _buildInfoCard(staff),
            const SizedBox(height: 24),

            // 🎼SCORE
            _buildScoreCard(staff),
            const SizedBox(height: 24),

            // 📝 EXPLICAÇÃO
            _buildExplanationCard(),
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
          'Ode à Alegria',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ludwig van Beethoven - Sinfonia nº 9 em Ré menor, Op. 125',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
            fontStyle: FontStyle.italic,
          ),
        ),
        const Divider(height: 32, thickness: 2),
      ],
    );
  }

  Widget _buildInfoCard(Staff staff) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.deepPurple[50]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JSON Profissional',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Complete format with all features',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow('📊 Compasses', '${staff.measures.length}'),
            _buildInfoRow('🎼 Tonalidade', 'D major (2 sharps)'),
            _buildInfoRow('⏱️ Compass', '4/4'),
            _buildInfoRow('🎵 Formato', 'JSON Profissional (JsonMusicParser)'),
            _buildInfoRow(
                '✨ Recursos', 'Clefs, Armor, Boost Points, Barlines'),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(Staff staff) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.piano, color: Colors.deepPurple, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Rendered score',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple[100]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: MusicScore(
                staff: staff,
                theme: MusicScoreTheme(
                  noteheadColor: Colors.black,
                  stemColor: Colors.black,
                  staffLineColor: Colors.black87,
                  barlineColor: Colors.black,
                ),
                staffSpace: 15.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Colors.deepPurple, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'About this Example',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildExplanationPoint(
              '✅ JSON Profissional',
              'This example uses JsonMusicParser, which supports ALL Flutter Notemus features.',
            ),
            _buildExplanationPoint(
              '🎼 Estrutura Completa',
              'Clefs, key signatures, time signatures, notes with augmentation points, barlines.',
            ),
            _buildExplanationPoint(
              '🔄 Equivalent to Manual Example',
              'This score is identical to the complete_music_piece.dart example, but created from JSON!',
            ),
            _buildExplanationPoint(
              '📊 Formato Robusto',
              'Compatible with MusicXML and ideal for integration with databases.',
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is the recommended format for professional sheet music!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
