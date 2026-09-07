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

  test('pitch fields at the top level are READ, not defaulted', () {
    final warnings = <String>[];
    final notes = notesOf(
      doc('{"type":"note","step":"C","octave":6,"duration":"quarter"}'),
      warnings,
    );
    // Reported was the 2.8.0 behaviour; read is 2.8.1. The octave the document
    // asked for is the octave that comes back, and nothing is warned about.
    expect(notes.single.pitch.step, 'C');
    expect(notes.single.pitch.octave, 6);
    expect(warnings, isEmpty);
  });

  test('the flat shape carries its accidental too', () {
    final warnings = <String>[];
    final notes = notesOf(
      doc('{"type":"note","step":"F","octave":5,"accidental":"sharp",'
          '"duration":"quarter"}'),
      warnings,
    );
    expect(notes.single.pitch.step, 'F');
    expect(notes.single.pitch.octave, 5);
    expect(notes.single.pitch.alter, 1.0);
    expect(warnings, isEmpty);
  });

  test('a nested "pitch" still wins over top-level fields', () {
    final warnings = <String>[];
    final notes = notesOf(
      doc('{"type":"note","step":"C","octave":4,'
          '"pitch":{"step":"G","octave":5},"duration":"quarter"}'),
      warnings,
    );
    expect(notes.single.pitch.step, 'G');
    expect(notes.single.pitch.octave, 5);
    expect(warnings, isEmpty);
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
