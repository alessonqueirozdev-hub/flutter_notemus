import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_notemus_example/examples/accidentals_example.dart';
import 'package:flutter_notemus_example/examples/articulations_example.dart';
import 'package:flutter_notemus_example/examples/beaming_showcase.dart';
import 'package:flutter_notemus_example/examples/chords_example.dart';
import 'package:flutter_notemus_example/examples/clefs_example.dart';
import 'package:flutter_notemus_example/examples/complete_music_piece.dart';
import 'package:flutter_notemus_example/examples/dots_and_ledgers_example.dart';
import 'package:flutter_notemus_example/examples/dynamics_example.dart';
import 'package:flutter_notemus_example/examples/grace_notes_example.dart';
import 'package:flutter_notemus_example/examples/key_signatures_example.dart';
import 'package:flutter_notemus_example/examples/lyrics_text_example.dart';
import 'package:flutter_notemus_example/examples/multi_staff_example.dart';
import 'package:flutter_notemus_example/examples/octave_marks_example.dart';
import 'package:flutter_notemus_example/examples/ornaments_example.dart';
import 'package:flutter_notemus_example/examples/polyphony_example.dart';
import 'package:flutter_notemus_example/examples/professional_json_example.dart';
import 'package:flutter_notemus_example/examples/repeats_example.dart';
import 'package:flutter_notemus_example/examples/rhythmic_figures_example.dart';
import 'package:flutter_notemus_example/examples/slurs_ties_example.dart';
import 'package:flutter_notemus_example/examples/tempo_agogics_example.dart';
import 'package:flutter_notemus_example/examples/tuplets_example.dart';
import 'package:flutter_notemus_example/examples/volta_brackets_example.dart';
import 'package:flutter_notemus_example/main.dart';
import 'package:flutter_notemus_example/showcase_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureShowcaseAssetsLoaded();
  });

  testWidgets('example app shows the initial score gallery screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MusicNotationApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Curated Showcase'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.sidebar_left), findsOneWidget);
  });

  final pages = <String, Widget Function()>{
    'Clefs': () => const ClefsExample(),
    'Key Signatures': () => const KeySignaturesExample(),
    'Rhythmic Figures': () => const RhythmicFiguresExample(),
    'Dots and Ledger Lines': () => const DotsAndLedgersExample(),
    'Accidentals': () => const AccidentalsExample(),
    'Chords': () => const ChordsExample(),
    'Beaming': () => const BeamingShowcase(),
    'Tuplets': () => const TupletsExample(),
    'Articulations': () => const ArticulationsExample(),
    'Ornaments': () => const OrnamentsExample(),
    'Grace Notes': () => const GraceNotesExample(),
    'Slurs and Ties': () => const SlursTiesExample(),
    'Dynamics': () => const DynamicsExample(),
    'Tempo and Agogics': () => const TempoAgogicsExample(),
    'Lyrics and Text': () => const LyricsTextExample(),
    'Repeats': () => const RepeatsExample(),
    'Polyphony': () => const PolyphonyExampleWidget(),
    'Multi-Staff': () => const MultiStaffDemoApp(),
    'Octave Marks': () => const OctaveMarksExample(),
    'Volta Brackets': () => const VoltaBracketsExample(),
    'Complete Piece': () => const CompleteMusicPieceExample(),
    'JSON Import': () => const ProfessionalJsonExample(),
  };

  for (final entry in pages.entries) {
    testWidgets('smoke test: ${entry.key} builds without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: entry.value()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
