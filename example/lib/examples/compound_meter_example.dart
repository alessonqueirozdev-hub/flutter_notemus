// example/lib/examples/compound_meter_example.dart
//
// Compound meters and their beam grouping.
//
// Regression demo for F-03: eighth notes in 6/8, 9/8 and 12/8 must be beamed
// in groups of THREE (the dotted-quarter macro-beat), not in the groups of two
// a simple meter would produce. 3/8 is the deliberate exception — it is a
// single beat, so all three eighths share one beam.
//
// The grouping is derived by `BeamGrouper` from the time signature alone;
// none of the notes below carry an explicit `BeamType`.

import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Catalog entry: 3/8, 6/8, 9/8 and 12/8 side by side.
class CompoundMeterExample extends StatelessWidget {
  const CompoundMeterExample({super.key});

  static const _accent = Color(0xFF0369A1);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Compound Meters',
      subtitle:
          'Automatic beam grouping in 3/8, 6/8, 9/8 and 12/8 — the 3+3 macro '
          'beat of compound time, resolved from the meter alone.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'Why this matters',
          description:
              'A compound meter groups its units in threes: 6/8 is 3+3, 9/8 is '
              '3+3+3 and 12/8 is 3+3+3+3. Beaming them like a simple meter '
              '(2+2+2) hides the beat from the reader. 3/8 is the exception — '
              'a single beat, therefore a single beam.',
          accentColor: _accent,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth &&
                    constraints.maxWidth.isFinite &&
                    constraints.maxWidth > 0
                ? constraints.maxWidth
                : 640.0;
            final columns = width >= 900 ? 2 : 1;
            final tileWidth = (width - (columns - 1) * 16) / columns;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final meter in _meters)
                  SizedBox(
                    width: tileWidth,
                    child: _MeterTile(
                      meter: meter,
                      accent: _accent,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        ExampleSectionCard(
          title: 'Same six eighths, two different meters',
          description:
              'Six eighth notes in 6/8 are beamed 3+3 (two dotted-quarter '
              'beats). The very same six notes in 3/4 are beamed 2+2+2 (three '
              'quarter-note beats). Only the time signature changed.',
          accentColor: _accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CaptionLabel('6/8 — compound duple, 3+3'),
              _ScoreFrame(staff: _eighthRun(6, 8)),
              const SizedBox(height: 16),
              const _CaptionLabel('3/4 — simple triple, 2+2+2'),
              _ScoreFrame(staff: _eighthRun(3, 4, eighths: 6)),
            ],
          ),
        ),
      ],
    );
  }

  static const List<_Meter> _meters = <_Meter>[
    _Meter(
      numerator: 3,
      denominator: 8,
      title: '3/8',
      description:
          'One beat per bar: the three eighths share a single beam group.',
      groups: '3',
    ),
    _Meter(
      numerator: 6,
      denominator: 8,
      title: '6/8',
      description: 'Compound duple: two dotted-quarter beats.',
      groups: '3 + 3',
    ),
    _Meter(
      numerator: 9,
      denominator: 8,
      title: '9/8',
      description: 'Compound triple: three dotted-quarter beats.',
      groups: '3 + 3 + 3',
    ),
    _Meter(
      numerator: 12,
      denominator: 8,
      title: '12/8',
      description: 'Compound quadruple: four dotted-quarter beats.',
      groups: '3 + 3 + 3 + 3',
    ),
  ];

  /// A diatonic ladder used to draw the runs; groups alternate between the
  /// lower and the upper tetrachord so the beam groups are easy to count.
  static const List<(String, int)> _ladder = <(String, int)>[
    ('G', 4),
    ('A', 4),
    ('B', 4),
    ('C', 5),
    ('D', 5),
    ('E', 5),
    ('F', 5),
  ];

  /// One bar of [eighths] eighth notes (defaults to a full bar) in
  /// [numerator]/[denominator], with auto-beaming left to the engine.
  static Staff _eighthRun(int numerator, int denominator, {int? eighths}) {
    final count = eighths ?? numerator;
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(
      TimeSignature(numerator: numerator, denominator: denominator),
    );

    for (int i = 0; i < count; i++) {
      final group = i ~/ 3;
      final start = group.isEven ? 0 : 3;
      final step = _ladder[(start + (i % 3)) % _ladder.length];
      measure.add(
        Note(
          pitch: Pitch(step: step.$1, octave: step.$2),
          duration: const Duration(DurationType.eighth),
        ),
      );
    }

    staff.add(measure);
    return staff;
  }
}

class _Meter {
  final int numerator;
  final int denominator;
  final String title;
  final String description;
  final String groups;

  const _Meter({
    required this.numerator,
    required this.denominator,
    required this.title,
    required this.description,
    required this.groups,
  });
}

class _MeterTile extends StatelessWidget {
  final _Meter meter;
  final Color accent;

  const _MeterTile({required this.meter, required this.accent});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                meter.title,
                style: textTheme.navTitleTextStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  meter.groups,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            meter.description,
            style: textTheme.textStyle.copyWith(
              fontSize: 15,
              color: const Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _ScoreFrame(
            staff: CompoundMeterExample._eighthRun(
              meter.numerator,
              meter.denominator,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionLabel extends StatelessWidget {
  final String text;

  const _CaptionLabel(this.text);

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

class _ScoreFrame extends StatelessWidget {
  final Staff staff;

  const _ScoreFrame({required this.staff});

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
        height: 150,
        child: MusicScore(
          staff: staff,
          staffSpace: 14,
          theme: const MusicScoreTheme(
            staffLineColor: Color(0xFF1F2937),
            noteheadColor: Color(0xFF111827),
            stemColor: Color(0xFF111827),
            clefColor: Color(0xFF111827),
            barlineColor: Color(0xFF111827),
            beamColor: Color(0xFF111827),
            showMeasureNumbers: false,
          ),
        ),
      ),
    );
  }
}
