// JSON import of free and additive time signatures.
//
// `JsonMusicExporter` writes `isFreeTime: true` for a free meter and
// `additiveGroups` (the group numerators) for an additive one such as
// (3+2+2)/8. The importer has to read both back, or a round trip turns them
// into a plain fraction.

import 'package:flutter_notemus/flutter_notemus.dart';
import 'package:flutter_test/flutter_test.dart';

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

TimeSignature _roundTrip(TimeSignature time) => _timeOf(
  JsonMusicParser.parseStaff(JsonMusicExporter.staffToJson(_staffWith(time))),
);

void main() {
  group('JSON round trip', () {
    test('keeps a free meter free', () {
      final back = _roundTrip(TimeSignature.free());

      expect(back.isFreeTime, isTrue);
      expect(back.measureValue, double.infinity);
    });

    test('keeps the groups of an additive meter', () {
      final back = _roundTrip(
        TimeSignature.additive(groups: [3, 2, 2], denominator: 8),
      );

      expect(back.isAdditive, isTrue);
      expect(back.additiveGroups!.map((g) => g.numerator), [3, 2, 2]);
      expect((back.numerator, back.denominator), (7, 8));
    });

    test('leaves a plain meter plain', () {
      final back = _roundTrip(TimeSignature(numerator: 6, denominator: 8));

      expect(back.isFreeTime, isFalse);
      expect(back.additiveGroups, isNull);
    });
  });

  test('a bar-level "timeSignature" reads the same keys', () {
    const json = '''
{
  "measures": [
    {
      "clef": "treble",
      "timeSignature": { "numerator": 7, "denominator": 8, "additiveGroups": [2, 2, 3] },
      "elements": [
        { "type": "note", "step": "C", "octave": 5, "duration": "quarter" }
      ]
    }
  ]
}
''';
    final time = _timeOf(JsonMusicParser.parseStaff(json));

    expect(time.additiveGroups!.map((g) => g.numerator), [2, 2, 3]);
  });

  test('additiveGroups entries that are not positive numbers are skipped', () {
    const json = '''
{
  "measures": [
    {
      "elements": [
        { "type": "timesignature", "numerator": 5, "denominator": 8, "additiveGroups": [3, "x", 0, 2] }
      ]
    }
  ]
}
''';
    final time = _timeOf(JsonMusicParser.parseStaff(json));

    expect(time.additiveGroups!.map((g) => g.numerator), [3, 2]);
  });
}
