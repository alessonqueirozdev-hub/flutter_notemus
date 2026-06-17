// Golden for the Gregorian (neume) renderer — Tier A.
// Generate:  flutter test --update-goldens test/golden/chant_golden_test.dart
// Check:     flutter test test/golden/chant_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the music Duration so const Duration(milliseconds:) is the time Duration.
import 'package:flutter_notemus/flutter_notemus.dart' hide Duration;

import '_harness.dart';

void main() {
  setUpAll(loadNotemusFonts);

  NeumeComponent nc(String step, int octave, [NcForm form = NcForm.punctum]) =>
      NeumeComponent(pitchName: step, octave: octave, form: form);

  testWidgets('golden chant_kyrie_tierA', (tester) async {
    final elements = <MusicalElement>[
      // punctum
      Neume(type: NeumeType.punctum, components: [nc('C', 4)], syllable: 'Ký'),
      // pes (ascending C->E)
      Neume(
        type: NeumeType.pes,
        components: [nc('C', 4), nc('E', 4)],
        syllable: 'ri',
      ),
      // clivis (descending G->F)
      Neume(
        type: NeumeType.clivis,
        components: [nc('G', 4), nc('F', 4)],
        syllable: 'e',
      ),
      // climacus (virga G, then descending F, E)
      Neume(
        type: NeumeType.climacus,
        components: [nc('G', 4, NcForm.virga), nc('F', 4), nc('E', 4)],
        syllable: 'lé',
      ),
      // scandicus (ascending D->F->A)
      Neume(
        type: NeumeType.scandicus,
        components: [nc('D', 4), nc('F', 4), nc('A', 4)],
        syllable: 'i',
      ),
      // quilisma group + final divisio
      Neume(
        type: NeumeType.quilismaGroup,
        components: [nc('F', 4, NcForm.quilisma), nc('G', 4)],
        syllable: 'son',
      ),
      NeumeDivision(type: NeumeDivisionType.finalis),
    ];

    await tester.binding.setSurfaceSize(const Size(720, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: textFontAvailable ? ThemeData(fontFamily: kTextFontFamily) : null,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: kGoldenBoundaryKey,
              child: Container(
                width: 720,
                height: 260,
                color: Colors.white,
                child: ChantScore(
                  elements: elements,
                  clef: const ChantClef(
                    type: ChantClefType.doClef,
                    line: 4,
                  ),
                  theme: GregorianTheme(
                    lyricSize: 15,
                    color: const Color(0xFF101010),
                    lyricTextFamily:
                        textFontAvailable ? kTextFontFamily : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byKey(kGoldenBoundaryKey),
      matchesGoldenFile('goldens/chant_kyrie_tierA.png'),
    );
  });
}
