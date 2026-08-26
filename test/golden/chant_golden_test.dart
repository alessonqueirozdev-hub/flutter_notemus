@Tags(['golden'])
// Pixel goldens are NOT portable across platforms: font rasterisation, hinting
// and anti-aliasing differ between operating systems, so an image recorded on
// one and checked on another fails for reasons that have nothing to do with the
// engraving. They are therefore tagged and run only on the platform they were
// recorded on (see .github/workflows/ci.yml and dart_test.yaml).
library;

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
                    line: 1,
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
                      type: ChantClefType.doClef, line: 1),
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

  testWidgets('golden chant_compound', (tester) async {
    // Four-note compound neumes and the salicus, which Greciliae ships as
    // single precomposed glyphs.
    final elements = <MusicalElement>[
      // salicus: three rising notes, oriscus in the middle (F-G-A)
      Neume(type: NeumeType.salicus, components: [
        nc('F', 4),
        nc('G', 4, NcForm.oriscus),
        nc('A', 4),
      ], syllable: 'sa'),
      // torculus resupinus: up-down-up (F-A-G-B)
      Neume(type: NeumeType.torculusResupinus, components: [
        nc('F', 4),
        nc('A', 4),
        nc('G', 4),
        nc('B', 4),
      ], syllable: 'tor-res'),
      // porrectus flexus: down-up-down (A-F-G-E)
      Neume(type: NeumeType.porrectusFlexus, components: [
        nc('A', 4),
        nc('F', 4),
        nc('G', 4),
        nc('E', 4),
      ], syllable: 'por-fl'),
      NeumeDivision(type: NeumeDivisionType.finalis),
    ];

    await tester.binding.setSurfaceSize(const Size(480, 300));
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
                width: 480,
                height: 300,
                color: Colors.white,
                child: ChantScore(
                  elements: elements,
                  clef: const ChantClef(
                      type: ChantClefType.doClef, line: 1),
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
      matchesGoldenFile('goldens/chant_compound.png'),
    );
  });

  testWidgets('golden chant_repeated', (tester) async {
    // Repeated-pitch neumes: bivirga, distropha, tristropha (assembled from
    // side-by-side virga/stropha glyphs).
    final elements = <MusicalElement>[
      Neume(type: NeumeType.bivirga, components: [
        nc('G', 4, NcForm.virga),
        nc('G', 4, NcForm.virga),
      ], syllable: 'bi'),
      Neume(type: NeumeType.custom, components: [
        nc('G', 4, NcForm.stropha),
        nc('G', 4, NcForm.stropha),
      ], syllable: 'di'),
      Neume(type: NeumeType.custom, components: [
        nc('G', 4, NcForm.stropha),
        nc('G', 4, NcForm.stropha),
        nc('G', 4, NcForm.stropha),
      ], syllable: 'tri'),
      NeumeDivision(type: NeumeDivisionType.finalis),
    ];

    await tester.binding.setSurfaceSize(const Size(480, 300));
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
                width: 480,
                height: 300,
                color: Colors.white,
                child: ChantScore(
                  elements: elements,
                  clef: const ChantClef(
                      type: ChantClefType.doClef, line: 1),
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
      matchesGoldenFile('goldens/chant_repeated.png'),
    );
  });

  testWidgets('golden chant_special_neumes', (tester) async {
    // Liquescent climacus -> precomposed Ancus; ordinary climacus assembles;
    // quilisma keeps its wavy glyph in a pes and a 3-note rising group.
    NeumeComponent liq(String s, int o) =>
        NeumeComponent(pitchName: s, octave: o, isLiquescent: true);
    final elements = <MusicalElement>[
      // ordinary climacus C4-B3-A3 (assembles: virga + diamonds)
      Neume(type: NeumeType.climacus, components: [
        nc('C', 4, NcForm.virga),
        nc('B', 3),
        nc('A', 3),
      ], syllable: 'cli'),
      // liquescent climacus -> Ancus
      Neume(type: NeumeType.climacus, components: [
        nc('C', 4, NcForm.virga),
        nc('B', 3),
        liq('A', 3),
      ], syllable: 'an'),
      // quilisma pes (low quilisma rising)
      Neume(type: NeumeType.pes, components: [
        nc('A', 3, NcForm.quilisma),
        nc('B', 3),
      ], syllable: 'qui'),
      // quilisma in a 3-note rising group (assembles, wavy glyph shows)
      Neume(type: NeumeType.scandicus, components: [
        nc('G', 3),
        nc('A', 3, NcForm.quilisma),
        nc('B', 3),
      ], syllable: 'sca'),
      NeumeDivision(type: NeumeDivisionType.finalis),
    ];

    await tester.binding.setSurfaceSize(const Size(520, 300));
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
                height: 300,
                color: Colors.white,
                child: ChantScore(
                  elements: elements,
                  clef: const ChantClef(
                      type: ChantClefType.doClef, line: 2),
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
      matchesGoldenFile('goldens/chant_special_neumes.png'),
    );
  });

  testWidgets('golden chant_repeated_hyphen', (tester) async {
    // Two syllables of one word ("Ký-ri") separated by a long melisma. A single
    // centred dash would leave a big blank that splits the word, so the
    // word-internal hyphen is repeated across the gap (GregorioTeX behaviour).
    Neume mel(String s, int o) =>
        Neume(type: NeumeType.punctum, components: [nc(s, o)]);
    final elements = <MusicalElement>[
      // first syllable, then a run of text-less melisma notes
      Neume(
        type: NeumeType.punctum,
        components: [nc('G', 4)],
        syllable: 'Ký',
        hyphenAfter: true,
      ),
      mel('A', 4), mel('G', 4), mel('F', 4), mel('G', 4), mel('A', 4),
      mel('G', 4),
      // second syllable of the same word, far to the right
      Neume(type: NeumeType.punctum, components: [nc('G', 4)], syllable: 'ri'),
      // a separate word for contrast (normal single hyphen would not apply)
      Neume(type: NeumeType.punctum, components: [nc('F', 4)], syllable: 'e'),
      NeumeDivision(type: NeumeDivisionType.finalis),
    ];

    // Wide enough to keep everything on one row so the hyphen run is exercised.
    await tester.binding.setSurfaceSize(const Size(760, 240));
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
                width: 760,
                height: 240,
                color: Colors.white,
                child: ChantScore(
                  elements: elements,
                  clef: const ChantClef(
                      type: ChantClefType.doClef, line: 2),
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
      matchesGoldenFile('goldens/chant_repeated_hyphen.png'),
    );
  });

  testWidgets('golden chant_clef_flat', (tester) async {
    // A clef-flat (cb4): a soft B-flat drawn just after the do-clef.
    const gabc = '''
name: Clef flat test;
%%
(cb4) Ve(h)ni(hi)te(i) ad(hg)o(h)re(g)mus.(g) (::)
''';

    await tester.binding.setSurfaceSize(const Size(520, 300));
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
                height: 300,
                color: Colors.white,
                child: ChantScore.fromGabc(
                  gabc,
                  theme: GregorianTheme(
                    lyricSize: 14,
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
      matchesGoldenFile('goldens/chant_clef_flat.png'),
    );
  });

  testWidgets('golden chant_accidentals', (tester) async {
    // Standalone accidental signs (flat/natural/sharp) preceding their notes,
    // parsed end-to-end from GABC (ix = flat at i, etc.).
    const gabc = '''
name: Accidental test;
%%
(c4) fl(ixi)at(h) na(gyg)tu(h) sh(g#g)arp(h) (::)
''';

    await tester.binding.setSurfaceSize(const Size(520, 300));
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
                height: 300,
                color: Colors.white,
                child: ChantScore.fromGabc(
                  gabc,
                  theme: GregorianTheme(
                    lyricSize: 14,
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
      matchesGoldenFile('goldens/chant_accidentals.png'),
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
