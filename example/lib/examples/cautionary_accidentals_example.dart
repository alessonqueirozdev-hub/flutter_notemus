// example/lib/examples/cautionary_accidentals_example.dart
//
// Cautionary (parenthesised) and editorial (bracketed) accidentals.
//
// `Note.accidentalParenthesis` selects the enclosure; the SMuFL glyphs
// `accidentalParensLeft/Right` and `accidentalBracketLeft/Right` are drawn
// around the accidental and their width is reserved by the layout, so the
// enclosure never collides with the previous note.
//
// The other half of the feature lives in `AccidentalResolver`: an accidental
// already in force inside the bar is normally suppressed, but a cautionary or
// editorial accidental is NEVER suppressed — that is the whole point of
// writing one.

import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Catalog entry: cautionary and editorial accidentals.
class CautionaryAccidentalsExample extends StatelessWidget {
  const CautionaryAccidentalsExample({super.key});

  static const _accent = Color(0xFF9333EA);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Cautionary Accidentals',
      subtitle:
          'Reminder accidentals in parentheses and editorial accidentals in '
          'brackets, with the extra width reserved by the spacing engine.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'Two enclosures, one field',
          description:
              'AccidentalParenthesis.parentheses marks a cautionary reminder '
              '— “yes, this note really is natural again”. '
              'AccidentalParenthesis.brackets marks an editorial addition — a '
              'sign the editor supplied, not the composer. Both are always '
              'engraved, even where the bar rule would hide a plain '
              'accidental.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Cautionary reminder after a bar line',
          description:
              'Bar 1 raises F to F♯. The alteration expires at the bar line, '
              'so bar 2 opens with a parenthesised natural reminding the '
              'player that F is plain again.',
          accentColor: _accent,
          child: _Frame(staff: _reminderStaff()),
        ),
        ExampleSectionCard(
          title: 'Editorial accidental in brackets',
          description:
              'The bracketed sharp on the leading note is the editor speaking, '
              'not the source. Square brackets are the conventional way to say '
              'so, and the layout reserves their width just like parentheses.',
          accentColor: _accent,
          child: _Frame(staff: _editorialStaff()),
        ),
        ExampleSectionCard(
          title: 'Never suppressed inside the bar',
          description:
              'All four notes are F♯. The second one repeats the alteration '
              'and is correctly hidden by the bar rule. The third carries '
              'AccidentalParenthesis.parentheses and the fourth '
              'AccidentalParenthesis.brackets — both are drawn anyway, because '
              'a cautionary sign that the resolver could silence would be '
              'useless.',
          accentColor: _accent,
          child: _Frame(staff: _neverSuppressedStaff()),
        ),
        ExampleSectionCard(
          title: 'Enclosure gallery',
          description:
              'Sharp, flat, natural, double sharp and double flat — first '
              'bare, then parenthesised, then bracketed. Compare the optical '
              'spacing to the left of each notehead.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Caption('Bare accidentals'),
              _Frame(staff: _galleryStaff(AccidentalParenthesis.none)),
              const SizedBox(height: 16),
              const _Caption('Cautionary — parentheses'),
              _Frame(staff: _galleryStaff(AccidentalParenthesis.parentheses)),
              const SizedBox(height: 16),
              const _Caption('Editorial — brackets'),
              _Frame(staff: _galleryStaff(AccidentalParenthesis.brackets)),
            ],
          ),
        ),
      ],
    );
  }

  // --- Score builders -------------------------------------------------------

  static Note _note(
    String step,
    int octave,
    AccidentalType? accidental, {
    DurationType duration = DurationType.quarter,
    AccidentalParenthesis paren = AccidentalParenthesis.none,
  }) {
    final pitch = accidental == null
        ? Pitch(step: step, octave: octave)
        : Pitch.withAccidental(
            step: step,
            octave: octave,
            accidentalType: accidental,
          );
    return Note(
      pitch: pitch,
      duration: Duration(duration),
      accidentalParenthesis: paren,
    );
  }

  static Measure _openingBar() {
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    return measure;
  }

  /// Bar 1 sharpens F; bar 2 reminds the player with a parenthesised natural.
  static Staff _reminderStaff() {
    final staff = Staff();

    final bar1 = _openingBar();
    bar1.add(_note('D', 5, null));
    bar1.add(_note('F', 5, AccidentalType.sharp));
    bar1.add(_note('A', 5, null));
    bar1.add(_note('F', 5, null));
    staff.add(bar1);

    final bar2 = Measure();
    bar2.add(_note(
      'F',
      5,
      AccidentalType.natural,
      paren: AccidentalParenthesis.parentheses,
    ));
    bar2.add(_note('E', 5, null));
    bar2.add(_note('D', 5, null));
    bar2.add(_note('C', 5, null));
    staff.add(bar2);

    return staff;
  }

  /// A bracketed (editorial) leading note.
  static Staff _editorialStaff() {
    final staff = Staff();

    final bar = _openingBar();
    bar.add(_note('A', 4, null));
    bar.add(_note('B', 4, null));
    bar.add(_note(
      'C',
      5,
      AccidentalType.sharp,
      paren: AccidentalParenthesis.brackets,
    ));
    bar.add(_note('D', 5, null));
    staff.add(bar);

    return staff;
  }

  /// Four F♯: plain, suppressed repeat, parenthesised, bracketed.
  static Staff _neverSuppressedStaff() {
    final staff = Staff();

    final bar = _openingBar();
    bar.add(_note('F', 5, AccidentalType.sharp));
    bar.add(_note('F', 5, AccidentalType.sharp));
    bar.add(_note(
      'F',
      5,
      AccidentalType.sharp,
      paren: AccidentalParenthesis.parentheses,
    ));
    bar.add(_note(
      'F',
      5,
      AccidentalType.sharp,
      paren: AccidentalParenthesis.brackets,
    ));
    staff.add(bar);

    return staff;
  }

  /// Five accidentals on five different degrees (so no bar rule interferes),
  /// all wearing the same enclosure.
  static Staff _galleryStaff(AccidentalParenthesis paren) {
    final staff = Staff();

    final bar1 = _openingBar();
    bar1.add(_note('F', 4, AccidentalType.sharp, paren: paren));
    bar1.add(_note('B', 4, AccidentalType.flat, paren: paren));
    bar1.add(_note('G', 4, AccidentalType.natural, paren: paren));
    bar1.add(_note('C', 5, AccidentalType.doubleSharp, paren: paren));
    staff.add(bar1);

    final bar2 = Measure();
    bar2.add(_note(
      'E',
      5,
      AccidentalType.doubleFlat,
      duration: DurationType.whole,
      paren: paren,
    ));
    staff.add(bar2);

    return staff;
  }
}

class _Caption extends StatelessWidget {
  final String text;

  const _Caption(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  final Staff staff;

  const _Frame({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7DDE5)),
        color: const Color(0xFFFFFFFF),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: SizedBox(
        width: double.infinity,
        height: 160,
        child: MusicScore(
          staff: staff,
          staffSpace: 15,
          theme: const MusicScoreTheme(
            staffLineColor: Color(0xFF1F2937),
            noteheadColor: Color(0xFF111827),
            stemColor: Color(0xFF111827),
            clefColor: Color(0xFF111827),
            barlineColor: Color(0xFF111827),
            accidentalColor: Color(0xFF6D28D9),
            showMeasureNumbers: false,
          ),
        ),
      ),
    );
  }
}
