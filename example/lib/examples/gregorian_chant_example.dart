// example/lib/examples/gregorian_chant_example.dart
//
// Showcases Gregorian square-notation rendering with the Greciliae font:
// GABC import (ChantScore.fromGabc), divisiones, episema/mora, and a custos.

import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Catalog entry: Gregorian chant in square notation (Greciliae).
class GregorianChantExample extends StatelessWidget {
  const GregorianChantExample({super.key});

  static const _accent = Color(0xFF92400E);

  @override
  Widget build(BuildContext context) {
    return const ExampleShowcasePage(
      title: 'Gregorian Chant',
      subtitle:
          'Square notation rendered with the Greciliae font (SIL OFL) — '
          'precomposed neumes, divisiones, episema/mora, and a custos, not '
          'shapes built from common-music noteheads.',
      accentColor: _accent,
      children: [
        ShowcaseInfoBanner(
          title: 'GABC in, neumes out',
          description:
              'ChantScore.fromGabc parses the Gregorio plain-text format: '
              '(c4) is the clef, letters are pitches, (,)/(::) are breath '
              'marks and the final divisio, and modifiers encode episema, '
              'mora, quilisma and liquescence.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Kyrie (Cunctipotens Genitor)',
          description:
              'A do-clef chant on the 4th line with podatus/clivis neumes and '
              'divisiones between the phrases.',
          accentColor: _accent,
          child: _ChantFrame(
            gabc: '(c4) Ký(h)ri(hg)e(hgh) *(,) e(hg)lé(hi)i(hg)son.(g) (::)',
          ),
        ),
        ExampleSectionCard(
          title: 'Episema & mora (held notes)',
          description:
              'The horizontal episema (_) lengthens a note and the mora (.) '
              'adds an augmentation dot — both drawn with shape-specific '
              'Greciliae glyphs.',
          accentColor: _accent,
          child: _ChantFrame(
            gabc: '(c4) Sanc(g)tus,(h_) *(,) Sanc(hi)tus(h.) (::)',
          ),
        ),
        ExampleSectionCard(
          title: 'Quilisma & compound neume',
          description:
              'A quilisma (w) inside an ascending group and a torculus over a '
              'single syllable.',
          accentColor: _accent,
          child: _ChantFrame(
            gabc: '(c4) Al(gwh)le(hgh)lú(gh~)ia.(g) (::)',
          ),
        ),
        ExampleSectionCard(
          title: 'Fa-clef with flat (custos at line end)',
          description:
              'A fa-clef chant; the custos (end-of-line guide) is sized by the '
              'leap to the next system.',
          accentColor: _accent,
          child: _ChantFrame(
            gabc: '(cb3) Ve(f)ni(gh) *(,) cre(hg)á(gf)tor(f) (::)',
          ),
        ),
      ],
    );
  }
}

/// A cream-colored framed canvas for a [ChantScore] (chant traditionally sits
/// on a warm parchment ground).
class _ChantFrame extends StatelessWidget {
  final String gabc;

  const _ChantFrame({required this.gabc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3D8C4)),
        color: const Color(0xFFFBF6EC),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: ChantScore.fromGabc(gabc),
      ),
    );
  }
}
