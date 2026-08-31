// test/parsers/json_silent_pitch_test.dart
//
// A JSON note with no readable pitch became a middle C, in silence.
//
// Found the hard way: the Live Editor shipped a seed document written in the
// wrong shape — `{"type": "note", "step": "C", "octave": 5}`, with the pitch
// fields at the TOP level instead of nested under `"pitch"`. Every note in the
// bar came back as C4 and `warnings` was empty. Four different pitches, one
// answer, nothing said. A reader editing the octave and seeing the staff not
// move would reasonably conclude the editor was broken rather than the
// document.
//
// It still falls back — losing one note is better than losing the document —
// but it says so, and names the shape it expected.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

String doc(String elements) => '{"measures":[{"elements":[$elements]}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<Note> notesOf(String source, List<String> warnings) =>
      JsonMusicParser.parseStaff(source, warnings: warnings)
          .measures
          .expand((m) => m.elements)
          .whereType<Note>()
          .toList();

  test('the canonical nested shape parses, and says nothing', () {
    final warnings = <String>[];
    final notes = notesOf(
      doc('{"type":"note","pitch":{"step":"D","octave":6},'
          '"duration":{"type":"quarter"}}'),
      warnings,
    );
    expect(notes.single.pitch.step, 'D');
    expect(notes.single.pitch.octave, 6);
    expect(warnings, isEmpty);
  });

  test('the "C5" shorthand parses, and says nothing', () {
    final warnings = <String>[];
    final notes = notesOf(
      doc('{"type":"note","pitch":"A4","duration":"half"}'),
      warnings,
    );
    expect(notes.single.pitch.step, 'A');
    expect(notes.single.pitch.octave, 4);
    expect(warnings, isEmpty);
  });

  test('pitch fields at the top level are REPORTED, not silently defaulted',
      () {
    final warnings = <String>[];
    final notes = notesOf(
      doc('{"type":"note","step":"C","octave":6,"duration":"quarter"}'),
      warnings,
    );
    // The fallback still happens; what changed is that it is audible.
    expect(notes.single.pitch.step, 'C');
    expect(notes.single.pitch.octave, 4);
    expect(warnings, hasLength(1));
    expect(warnings.single, contains('no readable pitch'));
    expect(warnings.single, contains('top level'),
        reason: 'the warning must name the mistake that was actually made, '
            'not just report a generic failure');
  });

  test('a missing duration is reported too', () {
    final warnings = <String>[];
    notesOf(doc('{"type":"note","pitch":"C5"}'), warnings);
    expect(warnings, hasLength(1));
    expect(warnings.single, contains('no "duration"'));
  });

  test('a note missing BOTH reports both', () {
    final warnings = <String>[];
    notesOf(doc('{"type":"note"}'), warnings);
    expect(warnings, hasLength(2));
  });
}
