// test/parsers/anppom_paper_json_example_test.dart
//
// The JSON document printed as Quadro 2 of the ANPPOM 2026 paper
// ("Renderização nativa de partituras em Flutter"), verbatim.
//
// The paper says of it: "um documento completo nesse formato, processado pelo
// analisador, produz uma partitura como a da Figura 1." When it went to press
// that sentence was false twice over — the notes carry "step"/"octave" at the
// top level and the bar carries "clef"/"timeSignature"/"keySignature" as
// measure-level keys, and the importer read neither. The printed example
// yielded three middle Cs on a staff with no clef, no meter and no key.
//
// The paper cannot be edited. The importer can, so it was: both shapes are
// read now. This test exists so the published example keeps working — it is
// pinned to a document nobody can change, which is exactly the kind of input
// that must not regress.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Quadro 2, character for character.
  const paperExample = '''
{
  "measures": [
    {
      "clef": "treble",
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "keySignature": 0,
      "elements": [
        { "type": "note", "step": "C", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "E", "octave": 5, "duration": "quarter" },
        { "type": "note", "step": "G", "octave": 5, "duration": "quarter" },
        { "type": "rest", "duration": "quarter" }
      ]
    }
  ]
}
''';

  late Measure bar;
  late List<String> warnings;

  setUp(() {
    warnings = <String>[];
    bar = JsonMusicParser.parseStaff(paperExample, warnings: warnings)
        .measures
        .single;
  });

  test('the printed example parses without a single warning', () {
    expect(warnings, isEmpty);
  });

  test('the three pitches are the ones the paper prints', () {
    final notes = bar.elements.whereType<Note>().toList();
    expect(
      notes.map((n) => '${n.pitch.step}${n.pitch.octave}'),
      <String>['C5', 'E5', 'G5'],
      reason: 'before 2.8.1 every one of these came back as C4',
    );
    expect(notes.every((n) => n.duration.type == DurationType.quarter), isTrue);
  });

  test('the quarter rest survives', () {
    final rests = bar.elements.whereType<Rest>().toList();
    expect(rests, hasLength(1));
    expect(rests.single.duration.type, DurationType.quarter);
  });

  test('the measure-level clef, meter and key are all read', () {
    expect(bar.elements.whereType<Clef>().single.clefType, ClefType.treble);

    final time = bar.elements.whereType<TimeSignature>().single;
    expect(time.numerator, 4);
    expect(time.denominator, 4);

    expect(bar.elements.whereType<KeySignature>().single.count, 0);
  });

  test('the opening block comes out in score order: clef, key, meter', () {
    final opening = bar.elements
        .takeWhile((e) => e is Clef || e is KeySignature || e is TimeSignature)
        .map((e) => e.runtimeType.toString())
        .toList();
    expect(opening, <String>['Clef', 'KeySignature', 'TimeSignature']);
  });
}
