// example/lib/examples/json_ode_example.dart
// Ode à Alegria renderizada a partir de JSON simplificado

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_notemus/src/parsers/json_parser.dart';

class JsonOdeExample extends StatelessWidget {
  const JsonOdeExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🎵 Ode à Alegria em JSON COMPLETO (igual ao exemplo profissional)
    final jsonString = '''
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
            {"type": "note", "pitch": {"step": "F", "octave": 5, "alter": 0.0}, "duration": {"type": "quarter"}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "eighth"}},
            {"type": "note", "pitch": {"step": "E", "octave": 5, "alter": 0.0}, "duration": {"type": "half"}}
          ]
        }
      ]
    }
    ''';

    // 📊 PARSEAR JSON → STAFF
    final staff = JsonMusicParser.parseStaff(jsonString);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 Header
            const Text(
              'Ode à Alegria',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ludwig van Beethoven - Renderizado a partir de JSON',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const Divider(height: 32),

            // 📊 Info Card
            Card(
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
                              'Informações da Peça',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Criado a partir de JSON completo',
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
                    _buildInfoRow('Tonalidade:', 'Ré Maior (2 sustenidos)'),
                    _buildInfoRow('Compasso:', '4/4'),
                    _buildInfoRow('Compassos:', '${staff.measures.length}'),
                    _buildInfoRow('Formato:', 'JSON Completo (compatível com MusicXML)'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 🎼 PARTITURA
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partitura',
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
                      padding: const EdgeInsets.all(24),
                      child: MusicScore(
                        staff: staff,
                        theme: MusicScoreTheme(
                          noteheadColor: Colors.black,
                          stemColor: Colors.black,
                          staffLineColor: Colors.black87,
                          barlineColor: Colors.black,
                        ),
                        staffSpace: 14.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
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
}
