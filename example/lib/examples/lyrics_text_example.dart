import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

class LyricsTextExample extends StatelessWidget {
  const LyricsTextExample({super.key});

  static const _accent = Color(0xFF2563EB);
  static const _scoreTheme = MusicScoreTheme(
    staffLineColor: Color(0xFF1F2937),
    noteheadColor: Color(0xFF111827),
    stemColor: Color(0xFF111827),
    clefColor: Color(0xFF111827),
    barlineColor: Color(0xFF111827),
    accidentalColor: Color(0xFF111827),
    textColor: Color(0xFF0F172A),
    textStyle: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    lyricTextStyle: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
    tempoTextStyle: TextStyle(
      color: Color(0xFF0F172A),
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Lyrics and Text',
      subtitle:
          'Examples for syllabification, multi-verse text, and expressive annotations that were missing from the old public gallery.',
      accentColor: _accent,
      children: [
        ExampleSectionCard(
          title: 'Single Verse with Syllabification',
          description:
              'Each note carries its lyric syllable directly, including initial and terminal syllabic states.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaffWithMeasures([
              [
                Clef(clefType: ClefType.treble),
                TimeSignature(numerator: 4, denominator: 4),
                Note(
                  pitch: const Pitch(step: 'C', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  syllables: const [
                    Syllable(text: 'Glo', type: SyllableType.initial),
                  ],
                ),
                Note(
                  pitch: const Pitch(step: 'D', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  syllables: const [
                    Syllable(text: 'ri', type: SyllableType.middle),
                  ],
                ),
                Note(
                  pitch: const Pitch(step: 'E', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  syllables: const [
                    Syllable(text: 'a', type: SyllableType.terminal),
                  ],
                ),
                Note(
                  pitch: const Pitch(step: 'F', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  syllables: const [
                    Syllable(text: 'in', type: SyllableType.single),
                  ],
                ),
              ],
              [
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  syllables: const [
                    Syllable(text: 'ex', type: SyllableType.initial),
                  ],
                ),
                Note(
                  pitch: const Pitch(step: 'A', octave: 4),
                  duration: const Duration(DurationType.quarter),
                  syllables: const [
                    Syllable(text: 'cel', type: SyllableType.middle),
                  ],
                ),
                Note(
                  pitch: const Pitch(step: 'G', octave: 4),
                  duration: const Duration(DurationType.half),
                  syllables: const [
                    Syllable(text: 'sis', type: SyllableType.terminal),
                  ],
                ),
              ],
            ]),
            accentColor: _accent,
            minHeight: 290,
            staffSpace: 18,
            theme: _scoreTheme,
          ),
        ),
        ExampleSectionCard(
          title: 'Two Verses',
          description:
              'Verse stacking helps validate vertical rhythm spacing and text readability on smaller devices.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(text: 'A', type: SyllableType.single),
                  Syllable(text: 'How', type: SyllableType.single),
                ],
              ),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(text: 've', type: SyllableType.single, italic: true),
                  Syllable(text: 'sweet', type: SyllableType.single),
                ],
              ),
              Note(
                pitch: const Pitch(step: 'B', octave: 4),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(text: 'Ma', type: SyllableType.initial),
                  Syllable(text: 'the', type: SyllableType.single),
                ],
              ),
              Note(
                pitch: const Pitch(step: 'C', octave: 5),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(text: 'ri-a', type: SyllableType.terminal),
                  Syllable(text: 'sound', type: SyllableType.single),
                ],
              ),
            ]),
            accentColor: _accent,
            minHeight: 290,
            staffSpace: 18,
            theme: _scoreTheme,
          ),
        ),
        ExampleSectionCard(
          title: 'Tempo and Expression Text',
          description:
              'A score can mix textual tempo markings, expression text, and lyrics without sacrificing readability.',
          accentColor: _accent,
          child: ScorePreviewFrame(
            staff: _buildStaff([
              Clef(clefType: ClefType.treble),
              TempoMark(
                beatUnit: DurationType.quarter,
                bpm: 84,
                text: 'Andante cantabile',
              ),
              MusicText(
                text: 'dolce',
                type: TextType.expression,
                placement: TextPlacement.above,
                italic: true,
              ),
              Note(
                pitch: const Pitch(step: 'E', octave: 4),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(text: 'Ky', type: SyllableType.initial),
                ],
              ),
              Note(
                pitch: const Pitch(step: 'F', octave: 4),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(text: 'ri', type: SyllableType.middle),
                ],
              ),
              Note(
                pitch: const Pitch(step: 'G', octave: 4),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(
                      text: 'e', type: SyllableType.terminal, italic: true),
                ],
              ),
              Breath(type: BreathType.comma),
              Note(
                pitch: const Pitch(step: 'A', octave: 4),
                duration: const Duration(DurationType.quarter),
                syllables: const [
                  Syllable(text: 'e', type: SyllableType.single),
                ],
              ),
            ]),
            accentColor: _accent,
            minHeight: 290,
            staffSpace: 18,
            theme: _scoreTheme,
          ),
        ),
      ],
    );
  }

  Staff _buildStaff(List<MusicalElement> elements) {
    final staff = Staff();
    final measure = Measure();
    for (final element in elements) {
      measure.add(element);
    }
    staff.add(measure);
    return staff;
  }

  Staff _buildStaffWithMeasures(List<List<MusicalElement>> measures) {
    final staff = Staff();
    for (final elements in measures) {
      final measure = Measure();
      for (final element in elements) {
        measure.add(element);
      }
      staff.add(measure);
    }
    return staff;
  }
}
