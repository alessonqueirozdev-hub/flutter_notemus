// Common and cut time symbols through the importers and exporters (#64).
//
// `TimeSignature.displayCommonTimeSignatureGlyphs` decides whether 4/4 and
// 2/2 are drawn as C and cut C or as fractions. MusicXML spells it as
// `<time symbol="common|cut">` (no `@symbol` means `normal`, a fraction), MEI
// as `@sym` on `<meterSig>` and `@meter.sym` on `<staffDef>`/`<scoreDef>`.

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

String _musicXml(String time) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>P</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        $time
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><type>whole</type></note>
    </measure>
  </part>
</score-partwise>
''';

String _mei({String staffDef = '', String meterSig = ''}) =>
    '''
<mei xmlns="http://www.music-encoding.org/ns/mei">
  <music><body><mdiv><score>
    <scoreDef><staffGrp><staffDef n="1" lines="5" clef.shape="G" clef.line="2" $staffDef/></staffGrp></scoreDef>
    <section><measure n="1"><staff n="1">
      $meterSig
      <layer n="1"><note pname="c" oct="5" dur="1"/></layer>
    </staff></measure></section>
  </score></mdiv></body></music>
</mei>
''';

TimeSignature _timeOf(Staff staff) =>
    staff.measures.expand((m) => m.elements).whereType<TimeSignature>().single;

Staff _staffWith(TimeSignature time) => Staff(
  measures: [
    Measure()
      ..add(Clef(clefType: ClefType.treble))
      ..add(time)
      ..add(
        Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const Duration(DurationType.quarter),
        ),
      ),
  ],
);

void main() {
  group('MusicXML import reads <time @symbol>', () {
    TimeSignature parse(String time, [List<String>? warnings]) => _timeOf(
      MusicXMLParser.parseMusicXML(_musicXml(time), warnings: warnings),
    );

    test('symbol="common" and symbol="cut" draw the C glyphs', () {
      final common = parse(
        '<time symbol="common"><beats>4</beats><beat-type>4</beat-type></time>',
      );
      expect(common.displayCommonTimeSignatureGlyphs, isTrue);

      final cut = parse(
        '<time symbol="cut"><beats>2</beats><beat-type>2</beat-type></time>',
      );
      expect(cut.displayCommonTimeSignatureGlyphs, isTrue);
    });

    test('no @symbol means normal, so 4/4 and 2/2 stay fractions', () {
      final fourFour = parse(
        '<time><beats>4</beats><beat-type>4</beat-type></time>',
      );
      expect(fourFour.displayCommonTimeSignatureGlyphs, isFalse);

      final twoTwo = parse(
        '<time symbol="normal"><beats>2</beats><beat-type>2</beat-type></time>',
      );
      expect(twoTwo.displayCommonTimeSignatureGlyphs, isFalse);
    });

    test('a symbol the engine cannot draw is reported, not dropped', () {
      final warnings = <String>[];
      final time = parse(
        '<time symbol="single-number"><beats>4</beats><beat-type>4</beat-type></time>',
        warnings,
      );
      expect(time.displayCommonTimeSignatureGlyphs, isFalse);
      expect(time.numerator, 4);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('single-number'));
    });

    test('common and cut symbols raise no warning', () {
      final warnings = <String>[];
      parse(
        '<time symbol="common"><beats>4</beats><beat-type>4</beat-type></time>',
        warnings,
      );
      expect(warnings, isEmpty);
    });
  });

  group('MusicXML export writes <time @symbol>', () {
    test('4/4 and 2/2 shown as C write common and cut', () {
      final common = MusicXMLParser.staffToMusicXML(
        _staffWith(TimeSignature(numerator: 4, denominator: 4)),
      );
      expect(common, contains('<time symbol="common">'));

      final cut = MusicXMLParser.staffToMusicXML(
        _staffWith(TimeSignature(numerator: 2, denominator: 2)),
      );
      expect(cut, contains('<time symbol="cut">'));
    });

    test('fractions and other meters write no @symbol', () {
      final fraction = MusicXMLParser.staffToMusicXML(
        _staffWith(
          TimeSignature(
            numerator: 4,
            denominator: 4,
            displayCommonTimeSignatureGlyphs: false,
          ),
        ),
      );
      expect(fraction, contains('<time>'));
      expect(fraction, isNot(contains('symbol=')));

      final threeFour = MusicXMLParser.staffToMusicXML(
        _staffWith(TimeSignature(numerator: 3, denominator: 4)),
      );
      expect(threeFour, isNot(contains('symbol=')));
    });

    test('a round trip keeps the glyph choice in both states', () {
      for (final shown in [true, false]) {
        for (final (n, d) in [(4, 4), (2, 2)]) {
          final xml = MusicXMLParser.staffToMusicXML(
            _staffWith(
              TimeSignature(
                numerator: n,
                denominator: d,
                displayCommonTimeSignatureGlyphs: shown,
              ),
            ),
          );
          final back = _timeOf(MusicXMLParser.parseMusicXML(xml));
          expect(back.numerator, n);
          expect(back.denominator, d);
          expect(
            back.displayCommonTimeSignatureGlyphs,
            shown,
            reason: '$n/$d shown as C: $shown',
          );
        }
      }
    });
  });

  group('MEI import reads @sym and @meter.sym', () {
    test('<meterSig @sym> common and cut draw the C glyphs', () {
      final common = _timeOf(
        MEIParser.parseMEI(
          _mei(meterSig: '<meterSig count="4" unit="4" sym="common"/>'),
        ),
      );
      expect(common.displayCommonTimeSignatureGlyphs, isTrue);

      final cut = _timeOf(
        MEIParser.parseMEI(
          _mei(meterSig: '<meterSig count="2" unit="2" sym="cut"/>'),
        ),
      );
      expect(cut.displayCommonTimeSignatureGlyphs, isTrue);
    });

    test('<meterSig> without @sym is a fraction', () {
      final time = _timeOf(
        MEIParser.parseMEI(_mei(meterSig: '<meterSig count="4" unit="4"/>')),
      );
      expect(time.displayCommonTimeSignatureGlyphs, isFalse);
    });

    test('<staffDef @meter.sym> is read, and its absence is a fraction', () {
      final cut = _timeOf(
        MEIParser.parseMEI(
          _mei(staffDef: 'meter.count="2" meter.unit="2" meter.sym="cut"'),
        ),
      );
      expect(cut.displayCommonTimeSignatureGlyphs, isTrue);

      final fraction = _timeOf(
        MEIParser.parseMEI(_mei(staffDef: 'meter.count="4" meter.unit="4"')),
      );
      expect(fraction.displayCommonTimeSignatureGlyphs, isFalse);
    });
    test('a symbol with no count or unit is read as 4/4 or 2/2', () {
      final common = _timeOf(
        MEIParser.parseMEI(_mei(staffDef: 'meter.sym="common"')),
      );
      expect((common.numerator, common.denominator), (4, 4));
      expect(common.displayCommonTimeSignatureGlyphs, isTrue);

      final cut = _timeOf(
        MEIParser.parseMEI(_mei(meterSig: '<meterSig sym="cut"/>')),
      );
      expect((cut.numerator, cut.denominator), (2, 2));
      expect(cut.displayCommonTimeSignatureGlyphs, isTrue);
    });
  });

  group('JSON keeps displayCommonTimeSignatureGlyphs', () {
    test('the key is written only when it is false', () {
      final shown = JsonMusicExporter.staffToJson(
        _staffWith(TimeSignature(numerator: 4, denominator: 4)),
      );
      expect(shown, isNot(contains('displayCommonTimeSignatureGlyphs')));

      final fraction = JsonMusicExporter.staffToJson(
        _staffWith(
          TimeSignature(
            numerator: 4,
            denominator: 4,
            displayCommonTimeSignatureGlyphs: false,
          ),
        ),
      );
      expect(fraction, contains('"displayCommonTimeSignatureGlyphs": false'));
    });

    test('a round trip keeps the flag in both states', () {
      for (final shown in [true, false]) {
        final json = JsonMusicExporter.staffToJson(
          _staffWith(
            TimeSignature(
              numerator: 2,
              denominator: 2,
              displayCommonTimeSignatureGlyphs: shown,
            ),
          ),
        );
        final back = _timeOf(JsonMusicParser.parseStaff(json));
        expect(back.displayCommonTimeSignatureGlyphs, shown);
      }
    });
  });
}
