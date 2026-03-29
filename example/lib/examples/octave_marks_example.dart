import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

class OctaveMarksExample extends StatelessWidget {
  const OctaveMarksExample({super.key});

  static const _accent = Color(0xFF4338CA);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Octave Marks and Ottava Lines',
      subtitle:
          'Examples tuned for visibility, with larger score frames and stronger text contrast so the ottava text, dashed line, and closing hook remain easy to inspect.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'About Octave Markings',
          description:
              'Ottava markings move a passage by octave without forcing excessive ledger lines. The dashed extension shows the active span, and the closing vertical hook marks where the transposition stops.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: '8va - One Octave Higher',
          description:
              'A treble phrase carried upward by one octave, with the line kept clear of the note field and rendered with stronger contrast.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _build8va(),
            accentColor: _accent,
            minHeight: 260,
            staffSpace: 16,
            theme: _scoreTheme,
          ),
        ),
        ExampleSectionCard(
          title: '8vb - One Octave Lower',
          description:
              'The lower ottava line is placed beneath the staff and remains readable even when the passage sits in the bass register.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _build8vb(),
            accentColor: _accent,
            minHeight: 250,
            staffSpace: 15,
            theme: _scoreTheme,
          ),
        ),
        ExampleSectionCard(
          title: '15ma and 15mb',
          description:
              'Two-octave transpositions need especially strong labeling, so this example keeps both variants large enough to inspect in the public gallery.',
          accentColor: _accent,
          child: Column(
            children: [
              ScorePreviewFrame(
                staff: _build15ma(),
                accentColor: _accent,
                minHeight: 240,
                staffSpace: 15,
                theme: _scoreTheme,
              ),
              const SizedBox(height: 16),
              ScorePreviewFrame(
                staff: _build15mb(),
                accentColor: _accent,
                minHeight: 240,
                staffSpace: 15,
                theme: _scoreTheme,
              ),
            ],
          ),
        ),
        ExampleSectionCard(
          title: 'Extended Span Across the Phrase',
          description:
              'A longer ottava span demonstrates the bracket hook, the dashed line length, and the balance between the label and the noteheads underneath.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildExtendedSpan(),
            accentColor: _accent,
            minHeight: 255,
            staffSpace: 15,
            theme: _scoreTheme,
          ),
        ),
      ],
    );
  }

  MusicScoreTheme get _scoreTheme => const MusicScoreTheme(
        staffLineColor: Color(0xFF1F2937),
        noteheadColor: Color(0xFF111827),
        stemColor: Color(0xFF111827),
        clefColor: Color(0xFF111827),
        barlineColor: Color(0xFF111827),
        accidentalColor: Color(0xFF111827),
        textColor: Color(0xFF0F172A),
        octaveColor: Color(0xFF0F172A),
        octaveTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
        ),
        textStyle: TextStyle(
          color: Color(0xFF334155),
          fontSize: 14,
        ),
      );

  Staff _build8va() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(
      OctaveMark(
        type: OctaveType.va8,
        startMeasure: 0,
        endMeasure: 0,
        length: 190.0,
        showBracket: true,
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'E', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'G', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'B', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    staff.add(measure);
    return staff;
  }

  Staff _build8vb() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.bass));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(
      OctaveMark(
        type: OctaveType.vb8,
        startMeasure: 0,
        endMeasure: 0,
        length: 190.0,
        showBracket: true,
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'E', octave: 3),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'D', octave: 3),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'C', octave: 3),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'G', octave: 2),
        duration: const Duration(DurationType.quarter),
      ),
    );
    staff.add(measure);
    return staff;
  }

  Staff _build15ma() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(
      OctaveMark(
        type: OctaveType.va15,
        startMeasure: 0,
        endMeasure: 0,
        length: 185.0,
        showBracket: true,
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'C', octave: 4),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'E', octave: 4),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    staff.add(measure);
    return staff;
  }

  Staff _build15mb() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.bass));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(
      OctaveMark(
        type: OctaveType.vb15,
        startMeasure: 0,
        endMeasure: 0,
        length: 185.0,
        showBracket: true,
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'C', octave: 3),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'B', octave: 2),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'A', octave: 2),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'G', octave: 2),
        duration: const Duration(DurationType.quarter),
      ),
    );
    staff.add(measure);
    return staff;
  }

  Staff _buildExtendedSpan() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(
      OctaveMark(
        type: OctaveType.va8,
        startMeasure: 0,
        endMeasure: 0,
        length: 230.0,
        showBracket: true,
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'G', octave: 4),
        duration: const Duration(DurationType.eighth),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'B', octave: 4),
        duration: const Duration(DurationType.eighth),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'F', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    measure.add(
      Note(
        pitch: const Pitch(step: 'A', octave: 5),
        duration: const Duration(DurationType.quarter),
      ),
    );
    staff.add(measure);
    return staff;
  }
}
