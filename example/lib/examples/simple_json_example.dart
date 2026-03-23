// example/lib/examples/simple_json_example.dart

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';
// ignore: implementation_imports
import 'package:flutter_notemus/src/parsers/simple_json_parser.dart';

class SimpleJsonExample extends StatelessWidget {
  const SimpleJsonExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🎵 SEU JSON COM LETRAS (LYRICS)!
    const jsonString = '''
    [
      {"note": "C4", "lyric": "Do", "duration": "quarter"},
      {"note": "D4", "lyric": "Re", "duration": "quarter"},
      {"note": "C4", "lyric": "Do", "duration": "quarter"},
      {"note": "D4", "lyric": "Re", "duration": "quarter"},
      {"note": "D4", "lyric": "Re", "duration": "quarter"},
      {"note": "C4", "lyric": "Do", "duration": "quarter"},
      {"note": "D4", "lyric": "Re", "duration": "quarter"},
      {"note": "C4", "lyric": "Do", "duration": "quarter"},
      {"note": "C4", "lyric": "Do", "duration": "quarter"},
      {"note": "C4", "lyric": "Do", "duration": "quarter"},
      {"note": "D4", "lyric": "Re", "duration": "quarter"},
      {"note": "D4", "lyric": "Re", "duration": "quarter"},
      {"note": "C4", "lyric": "Do", "duration": "half"},
      {"note": "D4", "lyric": "Re", "duration": "half"}
    ]
    ''';

    // 📊 PARSEAR JSON → STAFF
    final staff = SimpleJsonParser.parseSimpleNotes(
      jsonString,
      clefType: ClefType.treble, // Clave de Sol
      keySignatureFifths: 0, // Do Maior (sem sustenidos/bemóis)
      timeSignatureNumerator: 4, // 4/4
      timeSignatureDenominator: 4,
      autoBarlines: true, // Automatic barlines
    );

    return Column(
        children: [
          // 📋 Informações
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎵 Music created from simplified JSON',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Compasses: ${staff.measures.length}',
                  style: const TextStyle(fontSize: 14),
                ),
                const Text(
                  'Ratings: 14',
                  style: TextStyle(fontSize: 14),
                ),
                Text(
                  'Format: {"note": "C4", "lyric": "Do", "duration": "quarter"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // 🎼 RENDERING
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: MusicScore(
                    staff: staff,
                    theme: const MusicScoreTheme(
                      noteheadColor: Colors.black,
                      stemColor: Colors.black,
                      staffLineColor: Colors.black87,
                      barlineColor: Colors.black,
                    ),
                    staffSpace: 14.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
  }
}
