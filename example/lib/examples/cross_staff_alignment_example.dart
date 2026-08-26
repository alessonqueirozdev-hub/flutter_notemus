// example/lib/examples/cross_staff_alignment_example.dart
//
// Vertical alignment of a grand staff by MUSICAL ONSET.
//
// `PositionedElement.onset` (whole notes since the start of the staff) is the
// shared time coordinate the multi-staff painter aligns on: two events with the
// same onset must land on the same X, whatever each staff's own rhythmic
// spacing would have wanted. The canonical stress case is four quarters
// against two halves — beat 3 of the right hand and beat 3 of the left hand
// have to line up exactly.

import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Catalog entry: grand staff with different rhythms per hand.
class CrossStaffAlignmentExample extends StatelessWidget {
  const CrossStaffAlignmentExample({super.key});

  static const _accent = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return ExampleShowcasePage(
      title: 'Cross-Staff Alignment',
      subtitle:
          'Two hands, two rhythms, one time grid: the staves are aligned on '
          'musical onset instead of on each staff’s own spacing.',
      accentColor: _accent,
      children: [
        const ShowcaseInfoBanner(
          title: 'The shared time grid',
          description:
              'Each staff is laid out independently first, then the systems '
              'are merged on a shared onset grid. Without that merge the two '
              'hands drift apart: with four quarters against two halves, beat '
              '3 used to land more than three staff spaces off.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Four quarters against two halves',
          description:
              'Right hand: four quarter notes (onsets 0, 0.25, 0.50, 0.75). '
              'Left hand: two half notes (onsets 0 and 0.50). The second half '
              'note must sit exactly under the third quarter note.',
          accentColor: _accent,
          child: _GrandStaffFrame(
            child: GrandStaff(
              group: StaffGroup.piano(
                _quarterHand(),
                _halfHand(),
              ),
              staffSpace: 14,
              theme: _theme,
            ),
          ),
        ),
        ExampleSectionCard(
          title: 'Eighths against quarters',
          description:
              'Eight eighth notes over four quarter notes. Every quarter of '
              'the left hand shares an onset with an eighth of the right hand '
              'and therefore shares its column.',
          accentColor: _accent,
          child: _GrandStaffFrame(
            child: GrandStaff(
              group: StaffGroup.piano(
                _eighthHand(),
                _quarterHand(bass: true),
              ),
              staffSpace: 14,
              theme: _theme,
            ),
          ),
        ),
        ExampleSectionCard(
          title: 'Dotted rhythm against a whole note',
          description:
              'A dotted-quarter/eighth figure against a single whole note. '
              'The left hand has one event at onset 0; every right-hand onset '
              'in between still keeps its own square-root spacing.',
          accentColor: _accent,
          child: _GrandStaffFrame(
            child: GrandStaff(
              group: StaffGroup.piano(
                _dottedHand(),
                _wholeHand(),
              ),
              staffSpace: 14,
              theme: _theme,
            ),
          ),
        ),
        const ExampleSectionCard(
          title: 'The onsets behind the alignment',
          description:
              'The same two staves as the first example, laid out through '
              'LayoutEngine and listed by PositionedElement.onset. Rows that '
              'share an onset are the rows the painter forces onto one column.',
          accentColor: _accent,
          child: _OnsetTable(),
        ),
      ],
    );
  }

  static const MusicScoreTheme _theme = MusicScoreTheme(
    staffLineColor: Color(0xFF1F2937),
    noteheadColor: Color(0xFF111827),
    stemColor: Color(0xFF111827),
    clefColor: Color(0xFF111827),
    barlineColor: Color(0xFF111827),
    beamColor: Color(0xFF111827),
    showMeasureNumbers: false,
  );

  // --- Score builders -------------------------------------------------------

  static Note _n(String step, int octave, DurationType type, {int dots = 0}) {
    return Note(
      pitch: Pitch(step: step, octave: octave),
      duration: Duration(type, dots: dots),
    );
  }

  static Staff _staffOf(ClefType clef, List<MusicalElement> body) {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: clef));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    for (final element in body) {
      measure.add(element);
    }
    staff.add(measure);
    return staff;
  }

  /// Right hand (or left hand when [bass]): four quarter notes.
  static Staff _quarterHand({bool bass = false}) {
    if (bass) {
      return _staffOf(ClefType.bass, [
        _n('C', 3, DurationType.quarter),
        _n('E', 3, DurationType.quarter),
        _n('G', 3, DurationType.quarter),
        _n('E', 3, DurationType.quarter),
      ]);
    }
    return _staffOf(ClefType.treble, [
      _n('C', 5, DurationType.quarter),
      _n('B', 4, DurationType.quarter),
      _n('A', 4, DurationType.quarter),
      _n('G', 4, DurationType.quarter),
    ]);
  }

  /// Left hand: two half notes.
  static Staff _halfHand() {
    return _staffOf(ClefType.bass, [
      _n('C', 3, DurationType.half),
      _n('G', 2, DurationType.half),
    ]);
  }

  static Staff _eighthHand() {
    return _staffOf(ClefType.treble, [
      _n('C', 5, DurationType.eighth),
      _n('D', 5, DurationType.eighth),
      _n('E', 5, DurationType.eighth),
      _n('F', 5, DurationType.eighth),
      _n('G', 5, DurationType.eighth),
      _n('F', 5, DurationType.eighth),
      _n('E', 5, DurationType.eighth),
      _n('D', 5, DurationType.eighth),
    ]);
  }

  static Staff _dottedHand() {
    return _staffOf(ClefType.treble, [
      _n('G', 4, DurationType.quarter, dots: 1),
      _n('A', 4, DurationType.eighth),
      _n('B', 4, DurationType.quarter, dots: 1),
      _n('C', 5, DurationType.eighth),
    ]);
  }

  static Staff _wholeHand() {
    return _staffOf(ClefType.bass, [
      _n('C', 3, DurationType.whole),
    ]);
  }
}

/// White frame used around every [GrandStaff] on this page.
class _GrandStaffFrame extends StatelessWidget {
  final Widget child;

  const _GrandStaffFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7DDE5)),
        color: const Color(0xFFFFFFFF),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// Lists the onsets the layout assigned to each staff of the first example.
///
/// The numbers come straight from [PositionedElement.onset]; equal onsets are
/// exactly the events the multi-staff painter pins to a shared column.
class _OnsetTable extends StatefulWidget {
  const _OnsetTable();

  @override
  State<_OnsetTable> createState() => _OnsetTableState();
}

class _OnsetTableState extends State<_OnsetTable> {
  final SmuflMetadata _metadata = SmuflMetadata();
  late final Future<void> _metadataFuture = _metadata.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 120,
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final upper = _onsetsOf(CrossStaffAlignmentExample._quarterHand());
        final lower = _onsetsOf(CrossStaffAlignmentExample._halfHand());
        final onsets = <double>{
          for (final row in upper) row.onset,
          for (final row in lower) row.onset,
        }.toList()
          ..sort();

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            color: const Color(0xFFF8FAFC),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _OnsetRow(
                onset: 'Onset',
                upper: 'Right hand',
                lower: 'Left hand',
                header: true,
              ),
              for (final onset in onsets)
                _OnsetRow(
                  onset: onset.toStringAsFixed(3),
                  upper: _labelAt(upper, onset),
                  lower: _labelAt(lower, onset),
                ),
            ],
          ),
        );
      },
    );
  }

  List<({double onset, String label})> _onsetsOf(Staff staff) {
    final engine = LayoutEngine(
      staff,
      availableWidth: 720,
      staffSpace: 14,
      metadata: _metadata,
    );
    final elements = engine.layout();
    return [
      for (final positioned in elements)
        if (positioned.element is Note)
          (
            onset: positioned.onset,
            label: '${(positioned.element as Note).pitch} '
                '(${(positioned.element as Note).duration.type.name})',
          ),
    ];
  }

  static String _labelAt(
    List<({double onset, String label})> rows,
    double onset,
  ) {
    for (final row in rows) {
      if ((row.onset - onset).abs() < 1e-9) return row.label;
    }
    return '—';
  }
}

class _OnsetRow extends StatelessWidget {
  final String onset;
  final String upper;
  final String lower;
  final bool header;

  const _OnsetRow({
    required this.onset,
    required this.upper,
    required this.lower,
    this.header = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      color: header ? const Color(0xFF64748B) : const Color(0xFF0F172A),
      fontWeight: header ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(onset, style: style)),
          Expanded(child: Text(upper, style: style)),
          Expanded(child: Text(lower, style: style)),
        ],
      ),
    );
  }
}
