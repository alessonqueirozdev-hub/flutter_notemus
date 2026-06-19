// Tier B: GABC (Gregorio) import. Verifies header, clef, neume contour
// classification, divisiones, and rhythmic marks.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  group('GabcParser', () {
    test('parses header, clef, neumes, marks and divisiones', () {
      const gabc = '''
name: Kyrie test;
mode: 1;
%%
(c4) Ký(h)ri(h)e(g.) *(,) e(hi)lé(hg)i(g)son.(g) (::)
''';
      final r = GabcParser.parse(gabc);

      // Header
      expect(r.headers['name'], 'Kyrie test');
      expect(r.headers['mode'], '1');

      // Clef: do clef on line 4
      expect(r.clef.type, ChantClefType.doClef);
      expect(r.clef.line, 4);

      final neumes = r.elements.whereType<Neume>().toList();
      final divs = r.elements.whereType<NeumeDivision>().toList();

      // Ký(h) ri(h) e(g.) e(hi) lé(hg) i(g) son(g) = 7 neumes
      expect(neumes.length, 7);
      // , and :: = 2 divisiones
      expect(divs.length, 2);
      expect(divs.last.type, NeumeDivisionType.finalis);

      // First syllable attaches to the first neume.
      expect(neumes[0].syllable, 'Ký');
      expect(neumes[0].type, NeumeType.punctum);

      // e(g.) carries a mora dot.
      expect(neumes[2].components.single.morae, 1);

      // e(hi) is a pes (ascending), lé(hg) is a clivis (descending).
      expect(neumes[3].type, NeumeType.pes);
      expect(neumes[4].type, NeumeType.clivis);
    });

    test('classifies three-note neumes by contour', () {
      // torculus (low-high-low), porrectus (high-low-high), climacus (descending)
      const gabc = '(c4) a(fgf)b(hgh)c(hgf)';
      final neumes = GabcParser.parse(gabc).elements.whereType<Neume>().toList();
      expect(neumes[0].type, NeumeType.torculus);
      expect(neumes[1].type, NeumeType.porrectus);
      expect(neumes[2].type, NeumeType.climacus);
    });

    test('recognizes virga and quilisma shapes', () {
      const gabc = '(c4) a(gv)b(gwh)';
      final neumes = GabcParser.parse(gabc).elements.whereType<Neume>().toList();
      expect(neumes[0].type, NeumeType.virga);
      expect(neumes[1].components.first.form, NcForm.quilisma);
    });

    test('emits standalone accidental signs (flat/natural/sharp)', () {
      // `ix` = flat sign at i, then a note i; `gy` = natural at g, then note g.
      const gabc = '(c4) Do(ixi)mi(g#g)ne(gy)';
      final neumes = GabcParser.parse(gabc).elements.whereType<Neume>().toList();

      // ix -> flat sign (accidental-only, no sung note); i -> note.
      expect(neumes[0].components.single.accidental, NeumeAccidental.flat);
      expect(neumes[1].components.single.accidental, NeumeAccidental.none);
      // g# -> sharp sign; g -> note.
      expect(neumes[2].components.single.accidental, NeumeAccidental.sharp);
      expect(neumes[3].components.single.accidental, NeumeAccidental.none);
      // gy -> natural sign (last token, no following note).
      expect(neumes[4].components.single.accidental, NeumeAccidental.natural);
      // The syllable attaches to the first SUNG note, not the accidental sign.
      expect(neumes[0].syllable, isNull);
      expect(neumes[1].syllable, 'Do');
    });

    test('classifies salicus (oriscus middle) vs scandicus', () {
      const gabc = '(c4) a(fgh)b(fgoh)';
      final neumes = GabcParser.parse(gabc).elements.whereType<Neume>().toList();
      expect(neumes[0].type, NeumeType.scandicus); // plain three rising
      expect(neumes[1].type, NeumeType.salicus); // oriscus on middle note
    });

    test('classifies four-note compound neumes by contour', () {
      // up-down-up = torculus resupinus; down-up-down = porrectus flexus.
      const gabc = '(c4) a(fhgi)b(hfgf)';
      final neumes = GabcParser.parse(gabc).elements.whereType<Neume>().toList();
      expect(neumes[0].type, NeumeType.torculusResupinus);
      expect(neumes[1].type, NeumeType.porrectusFlexus);
    });

    test('classifies repeated unison notes (bivirga vs repeated puncta)', () {
      const gabc = '(c4) a(gvgv)b(gg)';
      final neumes = GabcParser.parse(gabc).elements.whereType<Neume>().toList();
      expect(neumes[0].type, NeumeType.bivirga); // two virgae, same pitch
      expect(neumes[0].components.length, 2);
      expect(neumes[1].type, NeumeType.custom); // two puncta, same pitch
    });

    test('resolves absolute pitch relative to the clef (do-clef line = C)', () {
      NeumeComponent single(String gabc) => GabcParser.parse(gabc)
          .elements
          .whereType<Neume>()
          .first
          .components
          .single;
      // c4: line 4 = do = C; slot 'j' sits on line 4.
      final c4 = single('(c4) a(j)');
      expect(c4.pitchName, 'C');
      expect(c4.octave, 4);
      // Re-clefing to c3 maps the same letter to a different pitch (the clef
      // shifts where do — and the semitones — fall).
      final c3 = single('(c3) a(j)');
      expect(c3.pitchName, 'E');
    });

    test('fa-clef line resolves to F, and clef-flat (cb/fb) is recorded', () {
      final r = GabcParser.parse('(fb3) a(h)');
      expect(r.clef.type, ChantClefType.faClef);
      expect(r.clef.line, 3);
      expect(r.clef.flat, isTrue);
      final n = r.elements.whereType<Neume>().first.components.single;
      expect(n.pitchName, 'F'); // slot 'h' is on line 3 = fa = F
    });

    test('marks word-internal syllable hyphens', () {
      // 'Ky','ri','e' are one word (contiguous tokens); a space starts a new
      // word, so the last syllable before the space is not hyphenated.
      const gabc = '(c4) Ky(g)ri(h)e(g) e(h)le(g)';
      final neumes =
          GabcParser.parse(gabc).elements.whereType<Neume>().toList();
      expect(neumes[0].syllable, 'Ky');
      expect(neumes[0].hyphenAfter, isTrue); // Ky-
      expect(neumes[1].hyphenAfter, isTrue); // ri-
      expect(neumes[2].hyphenAfter, isFalse); // e (word-final, space follows)
      expect(neumes[3].syllable, 'e');
      expect(neumes[3].hyphenAfter, isTrue); // e-le
      expect(neumes[4].hyphenAfter, isFalse); // le (end)
    });

    test('fa clef and pitch contour are relative to the clef', () {
      const gabc = '(f3) a(g)b(h)';
      final r = GabcParser.parse(gabc);
      expect(r.clef.type, ChantClefType.faClef);
      expect(r.clef.line, 3);
      final neumes = r.elements.whereType<Neume>().toList();
      // h is one diatonic step above g.
      final g = neumes[0].components.single;
      final h = neumes[1].components.single;
      final gIdx = g.octave! * 7 + 'CDEFGAB'.indexOf(g.pitchName!);
      final hIdx = h.octave! * 7 + 'CDEFGAB'.indexOf(h.pitchName!);
      expect(hIdx - gIdx, 1);
    });
  });
}
