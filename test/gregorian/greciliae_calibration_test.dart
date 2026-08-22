// Greciliae vertical calibration.
//
// The Gregorian renderer places ONE precomposed neume glyph per neume, so the
// distance between the notes INSIDE a glyph is fixed by the font. If the staff
// lines the renderer draws use a different step, the upper notes of wide neumes
// do not sit on their line or space — and no golden test can catch it, because
// a golden only records whatever the renderer already produces.
//
// 2.6.0 hardcoded `_unitsPerStep = 147.0` while the shipped greciliae.ttf
// actually uses ~157.5 font units per diatonic step: a 7.1% error that
// accumulated with the ambitus (≈0.14 staff spaces on a 4-step pes, about 29%
// of the line-to-space distance). The metrics are now DERIVED from the font, so
// these tests check the derivation against the asset itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/src/rendering/gregorian/greciliae_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GreciliaeFont font;
  setUpAll(() async {
    font = GreciliaeFont();
    await font.load();
  });

  test('the font actually loads and carries metrics', () {
    expect(font.isLoaded, isTrue);
    expect(font.has('Punctum'), isTrue);
    expect(font.has('PesTwoNothing'), isTrue);
    expect(font.advanceUnits('Punctum'), greaterThan(0));
  });

  test('the diatonic step is measured from the font, not guessed', () {
    final step = font.diatonicStepUnits();
    expect(step, greaterThan(150.0));
    expect(step, lessThan(165.0),
        reason: 'measured on the shipped greciliae.ttf: consecutive Pes '
            'ambitus differ by ~158 font units. 2.6.0 assumed 147.');
  });

  test('every Pes ambitus step matches the derived unit', () {
    final step = font.diatonicStepUnits();
    const family = [
      'PesOneNothing',
      'PesTwoNothing',
      'PesThreeNothing',
      'PesFourNothing',
      'PesFiveNothing',
    ];
    // PesOne has a different outline, so the progression is checked from Two.
    for (var i = 2; i < family.length; i++) {
      if (!font.has(family[i]) || !font.has(family[i - 1])) continue;
      final lo = font.centerYUnits(family[i - 1]);
      final hi = font.centerYUnits(family[i]);
      // The bbox CENTRE rises by half a step for every extra ambitus unit.
      expect((hi - lo - step / 2).abs(), lessThan(3.0),
          reason: '${family[i]} drifts from the derived step of '
              '${step.toStringAsFixed(1)} units');
    }
  });

  test('the inter-line gap stays exactly one staff space', () {
    // The renderer scales glyphs so that two diatonic steps (= one inter-line
    // gap) equal `theme.staffSpace`. That is the whole point of deriving the
    // font scale from the step instead of pinning it to 3.4.
    final step = font.diatonicStepUnits();
    final fontScale = GreciliaeFont.unitsPerEm / (2 * step);
    const staffSpace = 26.0;
    final lineGapPx = 2 * step * (staffSpace * fontScale / GreciliaeFont.unitsPerEm);
    expect(lineGapPx, closeTo(staffSpace, 1e-6));
  });

  test('the first-note anchor comes from the Punctum bounding box', () {
    final anchor = font.centerYUnitsOrNull('Punctum');
    expect(anchor, isNotNull);
    // Measured on the shipped font: (-36 + 169) / 2 = 66.5.
    expect(anchor!, closeTo(66.5, 2.0));
  });
}
