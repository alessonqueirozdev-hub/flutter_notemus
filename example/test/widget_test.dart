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
import 'package:flutter_notemus_example/examples/grand_staff_example.dart';
import 'package:flutter_notemus_example/examples/gregorian_chant_example.dart';
import 'package:flutter_notemus_example/examples/key_signatures_example.dart';
import 'package:flutter_notemus_example/examples/lyrics_text_example.dart';
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
    // Use a wide surface so the persistent catalog sidebar is shown
    // (the app collapses it behind a button below 1120px logical px).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Render the catalog screen directly. The app's bootstrap gate uses a
    // FutureBuilder over real asset I/O that does not resolve under the
    // fake-async test clock, so we exercise MainScreen itself here.
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pump();

    // The persistent catalog sidebar is shown with its header.
    expect(find.text('Curated Showcase'), findsOneWidget);
    // The first (selected) catalog entry is visible near the top.
    expect(find.text('Clefs'), findsWidgets);
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
    'Grand Staff & Scores': () => const GrandStaffExample(),
    'Gregorian Chant': () => const GregorianChantExample(),
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
