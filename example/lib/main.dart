// example/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import 'examples/clefs_example.dart';
import 'examples/key_signatures_example.dart';
import 'examples/rhythmic_figures_example.dart';
import 'examples/accidentals_example.dart';
import 'examples/articulations_example.dart';
import 'examples/dots_and_ledgers_example.dart';
import 'examples/chords_example.dart';
import 'examples/beams_example.dart';
import 'examples/beaming_showcase.dart';
import 'examples/ornaments_example.dart';
import 'examples/dynamics_example.dart';
import 'examples/tempo_agogics_example.dart';
import 'examples/repeats_example.dart';
import 'examples/grace_notes_example.dart';
import 'examples/slurs_ties_example.dart';
import 'examples/tuplets_example.dart';
import 'examples/tuplets_professional_example.dart';
import 'examples/flags_vs_beams_example.dart';
import 'examples/professional_ornaments_example.dart';
import 'examples/corrected_ornaments_example.dart';
import 'examples/test_pitch_accuracy.dart';
import 'examples/test_augmentation_dots.dart';
import 'examples/rests_showcase.dart';
import 'examples/polyphony_example.dart';
import 'examples/multi_staff_example.dart';
import 'examples/octave_marks_example.dart';
import 'examples/volta_brackets_example.dart';

// New full examples
import 'examples/complete_clefs_demo.dart';
import 'examples/complete_articulations_ornaments.dart';
import 'examples/complete_advanced_elements.dart';
import 'examples/complete_music_piece.dart';
import 'examples/complete_improvements_demo.dart';

// JSON Examples
import 'examples/simple_json_example.dart';
import 'examples/json_ode_example.dart';
import 'examples/professional_json_example.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final fontLoader = FontLoader('Bravura');
  fontLoader.addFont(
      rootBundle.load('packages/flutter_notemus/assets/smufl/Bravura.otf'));
  await fontLoader.load();

  await SmuflMetadata().load();

  runApp(const MusicNotationApp());
}

class MusicNotationApp extends StatelessWidget {
  const MusicNotationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Note Examples',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    '🔍 TESTE: Precisão de Alturas',
    '🎯 TESTE: Augmentation Dots',
    'Keys',
    'Key Signatures',
    'Figuras Rítmicas',
    'Accidents',
    'Articulações',
    'Supplementary Points and Lines',
    'Chords',
    'Barras de Ligação (Beams)',
    '🎵 Beaming Avançado (Showcase)',
    'Ornaments',
    'Dinâmicas',
    'Tempo e Agógica',
    'Repetições',
    'Apogiaturas and Grace Notes',
    'Ligatures',
    'Quiálteras (Tuplets)',
    '🎼 Quiálteras Profissionais',
    'Bandeiras vs Barras',
    'Professional Ornaments',
    'Fixed Ornaments',
    'Rests Showcase',
    'Polifonia (Múltiplas Vozes)',
    'Multi-Pauta (Grand Staff)',
    '🎵 Octave markings (8va/8vb)',
    '🎵 Volta Brackets (1ª/2ª Vez)',
    '🎼 DEMO: All Clefs',
    '🎵 DEMO: Articulações Completas',
    '🎸 DEMO: Elementos Avançados',
    '🎹 DEMO: Peça Musical Completa',
    '⚙️ DEMO: Complete Improvements',
    '📄 JSON: Simple Example',
    '📄 JSON: Ode à Alegria',
    '📄 JSON: Profissional Completo',
  ];

  final List<Widget> _pages = const [
    TestPitchAccuracy(),
    TestAugmentationDots(),
    ClefsExample(),
    KeySignaturesExample(),
    RhythmicFiguresExample(),
    AccidentalsExample(),
    ArticulationsExample(),
    DotsAndLedgersExample(),
    ChordsExample(),
    BeamsExample(),
    BeamingShowcase(),
    OrnamentsExample(),
    DynamicsExample(),
    TempoAgogicsExample(),
    RepeatsExample(),
    GraceNotesExample(),
    SlursTiesExample(),
    TupletsExample(),
    TupletsProfessionalExample(),
    FlagsVsBeamsExample(),
    ProfessionalOrnamentsExample(),
    CorrectedOrnamentsExample(),
    RestsShowcaseExample(),
    PolyphonyExampleWidget(),
    MultiStaffDemoApp(),
    OctaveMarksExample(),
    VoltaBracketsExample(),
    // New full examples
    CompleteClefsDemoExample(),
    CompleteArticulationsOrnamentsExample(),
    CompleteAdvancedElementsExample(),
    CompleteMusicPieceExample(),
    ImprovementsDemoPage(),
    // JSON Examples
    SimpleJsonExample(),
    JsonOdeExample(),
    ProfessionalJsonExample(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // MUDANÇA AQUI: Adicionada a AppBar
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]), // O título muda com a seleção
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: _pages[_selectedIndex],
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Flutter Notemus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Examples by Symbol Family',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(_titles.length, (index) {
              return ListTile(
                leading: _getIconForIndex(index),
                title: Text(_titles[index]),
                selected: _selectedIndex == index,
                selectedTileColor: Colors.blue[50],
                onTap: () {
                  setState(() => _selectedIndex = index);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Icon _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return const Icon(Icons.vpn_key_outlined); // Claves
      case 1:
        return const Icon(Icons.tag); // Armaduras
      case 2:
        return const Icon(Icons.hourglass_empty); // Figuras Rítmicas
      case 3:
        return const Icon(Icons.superscript_outlined); // Acidentes
      case 4:
        return const Icon(
            Icons.arrow_drop_down_circle_outlined); // Articulações
      case 5:
        return const Icon(Icons.more_horiz); // Pontos e Linhas
      case 6:
        return const Icon(Icons.view_module_outlined); // Acordes
      case 7:
        return const Icon(Icons.link); // Beams
      case 8:
        return const Icon(Icons.auto_awesome); // Ornamentos
      case 9:
        return const Icon(Icons.volume_up); // Dinâmicas
      case 10:
        return const Icon(Icons.speed); // Tempo e Agógica
      case 11:
        return const Icon(Icons.repeat); // Repetições
      case 12:
        return const Icon(Icons.scatter_plot); // Grace Notes
      case 13:
        return const Icon(Icons.trending_up); // Ligaduras
      default:
        return const Icon(Icons.music_note);
    }
  }
}
