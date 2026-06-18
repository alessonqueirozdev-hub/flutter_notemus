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
      // quilisma group
      Neume(
        type: NeumeType.quilismaGroup,
        components: [nc('F', 4, NcForm.quilisma), nc('G', 4)],
        syllable: 'son',
      ),
      // rhythmic marks: episema + ictus on one note, mora dot on the next
      Neume(
        type: NeumeType.punctum,
        components: [
          NeumeComponent(pitchName: 'G', octave: 4, episema: true, ictus: true),
        ],
        syllable: 'A',
      ),
      Neume(
        type: NeumeType.punctum,
        components: [NeumeComponent(pitchName: 'F', octave: 4, morae: 1)],
        syllable: 'men',
      ),
      NeumeDivision(type: NeumeDivisionType.finalis),
    ];

    // Narrow width forces wrapping to two systems, exercising the end-of-line
    // custos and per-row clef repetition.
    await tester.binding.setSurfaceSize(const Size(540, 430));
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
                width: 540,
                height: 430,
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
                        serifFontAvailable ? kSerifFamily : null,
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

  testWidgets('golden chant_liquescence', (tester) async {
    // Liquescent (deminutus) neumes: epiphonus (liquescent pes), cephalicus
    // (liquescent clivis), and a liquescent torculus, beside their full forms.
    NeumeComponent liq(String step, int octave) => NeumeComponent(
        pitchName: step, octave: octave, isLiquescent: true);
    final elements = <MusicalElement>[
      Neume(type: NeumeType.pes, components: [nc('F', 4), nc('G', 4)],
          syllable: 'pes'),
      Neume(type: NeumeType.pes, components: [nc('F', 4), liq('G', 4)],
          syllable: 'e-pi'),
      Neume(type: NeumeType.clivis, components: [nc('A', 4), nc('G', 4)],
          syllable: 'cli'),
      Neume(type: NeumeType.clivis, components: [nc('A', 4), liq('G', 4)],
          syllable: 'ce-pha'),
      Neume(type: NeumeType.torculus,
          components: [nc('F', 4), nc('A', 4), nc('G', 4)], syllable: 'tor'),
      Neume(type: NeumeType.torculus,
          components: [nc('F', 4), nc('A', 4), liq('G', 4)], syllable: 'liq'),
      NeumeDivision(type: NeumeDivisionType.finalis),
    ];

    await tester.binding.setSurfaceSize(const Size(540, 300));
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
                width: 540,
                height: 300,
                color: Colors.white,
                child: ChantScore(
                  elements: elements,
                  clef: const ChantClef(
                      type: ChantClefType.doClef, line: 4),
                  theme: GregorianTheme(
                    lyricSize: 14,
                    color: const Color(0xFF101010),
                    lyricTextFamily: serifFontAvailable ? kSerifFamily : null,
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
      matchesGoldenFile('goldens/chant_liquescence.png'),
    );
  });

  testWidgets('golden chant_from_gabc', (tester) async {
    // A real GABC incipit parsed end-to-end via ChantScore.fromGabc.
    const gabc = '''
name: Salve Regina;
%%
(c4) Sal(g)ve(gh) Re(h)gí(hgh)na(g) *(,) ma(g)ter(hg)
mi(g)se(f)ri(gh)cór(g)di(f)ae(f) (::)
''';

    await tester.binding.setSurfaceSize(const Size(520, 470));
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
                width: 520,
                height: 430,
                color: Colors.white,
                child: ChantScore.fromGabc(
                  gabc,
                  theme: GregorianTheme(
                    lyricSize: 14,
                    lyricTextFamily:
                        serifFontAvailable ? kSerifFamily : null,
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
      matchesGoldenFile('goldens/chant_from_gabc.png'),
    );
  });
}
