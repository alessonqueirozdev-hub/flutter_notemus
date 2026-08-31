// test/parsers/overfull_measure_warning_test.dart
//
// `Measure.add` has refused an over-full bar since the model was written:
// adding a fifth quarter to a 4/4 bar throws `MeasureCapacityException`.
// **None of the three importers used it.** They build measures by writing
// straight into `measure.elements`, which that field's own dartdoc warns
// "bypasses the capacity check in add" — so a document declaring five quarters
// in a 4/4 bar imported cleanly, rendered as five crammed events, and reported
// nothing at all.
//
// Reported from the Live Editor, where typing a fifth quarter into the seed bar
// produced exactly that: no guard, no complaint. The rule was implemented,
// tested, and never consulted on the path where documents actually arrive.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

String json(String notes) => '''
{"measures":[{"elements":[
 {"type":"clef","clefType":"treble"},
 {"type":"timesignature","numerator":4,"denominator":4},
 $notes
]}]}''';

const _quarter = '{"type":"note","pitch":"C5","duration":"quarter"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Measure.add still refuses — the rule itself is intact', () {
    final m = Measure()
      ..elements.add(TimeSignature(numerator: 4, denominator: 4));
    for (var i = 0; i < 4; i++) {
      m.add(Note(
          pitch: const Pitch(step: 'C', octave: 5),
          duration: const MusicDuration(DurationType.quarter)));
    }
    expect(
      () => m.add(Note(
          pitch: const Pitch(step: 'D', octave: 5),
          duration: const MusicDuration(DurationType.quarter))),
      throwsA(isA<MeasureCapacityException>()),
    );
  });

  test('a full bar imports silently', () {
    final warnings = <String>[];
    JsonMusicParser.parseStaff(
        json([for (var i = 0; i < 4; i++) _quarter].join(',')),
        warnings: warnings);
    expect(warnings, isEmpty);
  });

  test('a SHORT bar is not reported — a pickup is legitimate', () {
    final warnings = <String>[];
    JsonMusicParser.parseStaff(json(_quarter), warnings: warnings);
    expect(warnings, isEmpty,
        reason: 'warning about short bars would train the reader to ignore '
            'this channel, and an anacrusis is not an error');
  });

  test('an over-full bar is reported, with the excess measured', () {
    final warnings = <String>[];
    final staff = JsonMusicParser.parseStaff(
        json([for (var i = 0; i < 5; i++) _quarter].join(',')),
        warnings: warnings);

    expect(warnings, hasLength(1));
    expect(warnings.single, contains('Measure 1'));
    expect(warnings.single, contains('1.2500'));
    expect(warnings.single, contains('4/4'));
    expect(warnings.single, contains('excess of 0.2500'));

    // The music is imported as written. Nothing is dropped and nothing is
    // moved: re-barring is a separate feature, and silently restructuring
    // somebody's document would be worse than the defect this replaces.
    final notes =
        staff.measures.expand((m) => m.elements).whereType<Note>().length;
    expect(notes, 5);
    expect(staff.measures, hasLength(1));
  });
}
