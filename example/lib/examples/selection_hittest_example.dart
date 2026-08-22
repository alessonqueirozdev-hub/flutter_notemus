// example/lib/examples/selection_hittest_example.dart
//
// Selection and hit-testing over a laid-out score, using the public
// [ScoreHitTester].
//
// This demo only became possible once the layout stopped replacing the
// caller's `Note` objects with clones: a hit now returns THE SAME object that
// was put into the model, so it can be highlighted, inspected and (in a real
// editor) edited. Every hit also carries the four selection axes the engine
// exposes today — system, measure index, voice number and musical onset.

import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

import '../widgets/showcase_shell.dart';

/// Catalog entry: tap-to-select, plus structural selection by bar and by voice.
class SelectionHitTestExample extends StatelessWidget {
  const SelectionHitTestExample({super.key});

  static const _accent = Color(0xFF1D4ED8);

  @override
  Widget build(BuildContext context) {
    return const ExampleShowcasePage(
      title: 'Selection & Hit-Testing',
      subtitle:
          'Tap any glyph to select it. The engine answers with the element '
          'itself, the bar it belongs to, its voice and its musical onset.',
      accentColor: _accent,
      children: [
        ShowcaseInfoBanner(
          title: 'Editor infrastructure',
          description:
              'ScoreHitTester works on the PositionedElement list returned by '
              'LayoutEngine.layout(). Because the layout preserves object '
              'identity, hitTest() hands back the very Note you wrote into the '
              'Measure — not a copy — which is what makes selection, '
              'highlighting and editing possible at all.',
          accentColor: _accent,
        ),
        ExampleSectionCard(
          title: 'Tap the score',
          description:
              'Point at a notehead, a rest, the clef or the time signature. '
              'The panel below reports what was hit and where it sits in '
              'musical time. The buttons select a whole bar or a whole voice '
              'through the same tester.',
          accentColor: _accent,
          child: _InteractiveScore(),
        ),
      ],
    );
  }
}

/// A score canvas wired to [ScoreHitTester].
///
/// The layout is run here (instead of inside [MusicScore]) so that the widget
/// owns the exact coordinate space the painter draws in; hit-testing against a
/// different layout pass than the one on screen would drift.
class _InteractiveScore extends StatefulWidget {
  const _InteractiveScore();

  @override
  State<_InteractiveScore> createState() => _InteractiveScoreState();
}

class _InteractiveScoreState extends State<_InteractiveScore> {
  static const double _staffSpace = 15.0;
  static const Color _accent = SelectionHitTestExample._accent;

  final SmuflMetadata _metadata = SmuflMetadata();
  late final Future<void> _metadataFuture = _metadata.load();
  late final Staff _staff = _buildStaff();

  // Unattached controllers: MusicScorePainter only listens to them and guards
  // every read with `hasClients`, so this canvas can scroll on its own.
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  // Memoized layout pass, keyed by the width it was laid out for.
  double? _layoutWidth;
  LayoutEngine? _engine;
  List<PositionedElement> _elements = const <PositionedElement>[];
  ScoreHitTester? _tester;
  double _totalHeight = 0;
  double _contentWidth = 0;

  List<ScoreHit> _selection = const <ScoreHit>[];
  ScoreHit? _focus;
  String _status = 'Nothing selected yet — tap a glyph on the staff.';

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  // --- Model ----------------------------------------------------------------

  static Note _note(
    String step,
    int octave,
    DurationType type, {
    int? voice,
  }) {
    return Note(
      pitch: Pitch(step: step, octave: octave),
      duration: Duration(type),
      voice: voice,
    );
  }

  /// Three bars: a plain one, a genuinely polyphonic one, and one with a chord
  /// and a rest, so every selection axis has something to show.
  static Staff _buildStaff() {
    final staff = Staff();

    final bar1 = Measure();
    bar1.add(Clef(clefType: ClefType.treble));
    bar1.add(TimeSignature(numerator: 4, denominator: 4));
    bar1.add(_note('C', 5, DurationType.quarter));
    bar1.add(_note('B', 4, DurationType.quarter));
    bar1.add(_note('A', 4, DurationType.quarter));
    bar1.add(_note('G', 4, DurationType.quarter));
    staff.add(bar1);

    // Voice-aware measure: both voices legally fill the same 4/4 bar.
    final bar2 = MultiVoiceMeasure();
    final upper = Voice.voice1();
    upper.add(_note('E', 5, DurationType.quarter, voice: 1));
    upper.add(_note('F', 5, DurationType.quarter, voice: 1));
    upper.add(_note('E', 5, DurationType.quarter, voice: 1));
    upper.add(_note('D', 5, DurationType.quarter, voice: 1));
    final lower = Voice.voice2();
    lower.add(_note('G', 4, DurationType.half, voice: 2));
    lower.add(_note('F', 4, DurationType.half, voice: 2));
    bar2.addVoice(upper);
    bar2.addVoice(lower);
    staff.add(bar2);

    final bar3 = Measure();
    bar3.add(Chord(
      notes: [
        _note('C', 4, DurationType.half),
        _note('E', 4, DurationType.half),
        _note('G', 4, DurationType.half),
      ],
      duration: const Duration(DurationType.half),
    ));
    bar3.add(Rest(duration: const Duration(DurationType.quarter)));
    bar3.add(_note('C', 5, DurationType.quarter));
    bar3.add(Barline(type: BarlineType.final_));
    staff.add(bar3);

    return staff;
  }

  // --- Layout ---------------------------------------------------------------

  void _ensureLayout(double width) {
    final previous = _layoutWidth;
    if (previous != null && (previous - width).abs() < 0.5) return;

    final engine = LayoutEngine(
      _staff,
      availableWidth: width,
      staffSpace: _staffSpace,
      metadata: _metadata,
    );
    final elements = engine.layout();

    _engine = engine;
    _elements = elements;
    _tester = ScoreHitTester(
      elements: elements,
      staffSpace: _staffSpace,
      engine: engine,
    );
    _totalHeight = engine.calculateTotalHeight(elements);
    _contentWidth = engine.contentWidth(elements);
    _layoutWidth = width;

    // The cached hits belong to the previous pass; drop them.
    _selection = const <ScoreHit>[];
    _focus = null;
  }

  // --- Selection ------------------------------------------------------------

  void _handleTap(Offset point) {
    final tester = _tester;
    if (tester == null) return;

    final hit = tester.hitTest(point, tolerance: _staffSpace * 1.5);
    setState(() {
      if (hit == null) {
        _selection = const <ScoreHit>[];
        _focus = null;
        _status = 'Nothing within reach of that point.';
        return;
      }
      _selection = <ScoreHit>[hit];
      _focus = hit;
      final time = tester.timeAt(point);
      _status = time == null
          ? 'Selected ${describe(hit.element)}.'
          : 'Selected ${describe(hit.element)} — caret would land in bar '
              '${time.measureIndex + 1} at onset '
              '${time.onset.toStringAsFixed(3)}.';
    });
  }

  void _selectMeasure(int index) {
    final tester = _tester;
    if (tester == null) return;
    final hits = tester.selectMeasure(index);
    setState(() {
      _selection = hits;
      _focus = hits.isEmpty ? null : hits.first;
      _status = 'Bar ${index + 1}: ${hits.length} element(s) selected.';
    });
  }

  void _selectVoice(int voice) {
    final tester = _tester;
    if (tester == null) return;
    final hits = tester.selectVoice(voice);
    setState(() {
      _selection = hits;
      _focus = hits.isEmpty ? null : hits.first;
      _status = 'Voice $voice: ${hits.length} element(s) selected '
          '(elements without a voice count as voice 1).';
    });
  }

  void _clear() {
    setState(() {
      _selection = const <ScoreHit>[];
      _focus = null;
      _status = 'Selection cleared.';
    });
  }

  /// Short human label for an element of the model.
  static String describe(MusicalElement element) {
    if (element is Note) return 'Note ${element.pitch}';
    if (element is Chord) {
      final pitches = element.notes.map((n) => '${n.pitch}').join(' ');
      return 'Chord [$pitches]';
    }
    if (element is Rest) return 'Rest (${element.duration.type.name})';
    if (element is Clef) return 'Clef (${element.clefType.name})';
    if (element is TimeSignature) {
      return 'Time signature ${element.numerator}/${element.denominator}';
    }
    if (element is KeySignature) return 'Key signature';
    if (element is Barline) return 'Barline (${element.type.name})';
    return element.runtimeType.toString();
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 200,
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCanvas(),
            const SizedBox(height: 16),
            _buildControls(),
            const SizedBox(height: 16),
            _buildReadout(context),
          ],
        );
      },
    );
  }

  Widget _buildCanvas() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7DDE5)),
        color: const Color(0xFFFFFFFF),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth &&
                  constraints.maxWidth.isFinite &&
                  constraints.maxWidth > 0
              ? constraints.maxWidth
              : 640.0;
          _ensureLayout(width);

          if (_elements.isEmpty) {
            return const SizedBox(height: 120);
          }

          final canvasWidth = _contentWidth > width ? _contentWidth : width;
          final canvasSize = Size(canvasWidth, _totalHeight);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontal,
            child: SizedBox(
              width: canvasWidth,
              height: _totalHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handleTap(details.localPosition),
                child: CustomPaint(
                  size: canvasSize,
                  painter: MusicScorePainter(
                    positionedElements: _elements,
                    metadata: _metadata,
                    theme: _scoreTheme,
                    staffSpace: _staffSpace,
                    layoutEngine: _engine,
                    viewportSize: canvasSize,
                    horizontalController: _horizontal,
                    verticalController: _vertical,
                  ),
                  foregroundPainter: _SelectionOverlayPainter(
                    selection: _selection,
                    focus: _focus,
                    accent: _accent,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static const MusicScoreTheme _scoreTheme = MusicScoreTheme(
    staffLineColor: Color(0xFF1F2937),
    noteheadColor: Color(0xFF111827),
    stemColor: Color(0xFF111827),
    clefColor: Color(0xFF111827),
    barlineColor: Color(0xFF111827),
    accidentalColor: Color(0xFF111827),
    showMeasureNumbers: true,
    measureNumberTextStyle: TextStyle(
      color: Color(0xFF6B7280),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildControls() {
    final measureCount = _staff.measures.length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < measureCount; i++)
          _PillButton(
            label: 'Select bar ${i + 1}',
            accent: _accent,
            onPressed: () => _selectMeasure(i),
          ),
        _PillButton(
          label: 'Select voice 1',
          accent: _accent,
          onPressed: () => _selectVoice(1),
        ),
        _PillButton(
          label: 'Select voice 2',
          accent: _accent,
          onPressed: () => _selectVoice(2),
        ),
        _PillButton(
          label: 'Clear',
          accent: const Color(0xFF6B7280),
          onPressed: _clear,
        ),
      ],
    );
  }

  Widget _buildReadout(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;
    final focus = _focus;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _status,
            style: textTheme.textStyle.copyWith(
              fontSize: 15,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (focus != null) ...[
            const SizedBox(height: 12),
            _readoutRow('Element', describe(focus.element)),
            _readoutRow('Measure', '${focus.measureIndex + 1}'),
            _readoutRow('Voice', '${focus.voiceNumber ?? 1}'),
            _readoutRow(
              'Onset (whole notes)',
              focus.onset.toStringAsFixed(4),
            ),
            _readoutRow('System', '${focus.system}'),
            _readoutRow(
              'Anchor',
              '(${focus.position.dx.toStringAsFixed(1)}, '
                  '${focus.position.dy.toStringAsFixed(1)})',
            ),
          ],
          if (_selection.length > 1) ...[
            const SizedBox(height: 12),
            _readoutRow('Selected elements', '${_selection.length}'),
            _readoutRow(
              'Sounding elements',
              '${_selectionSummary().soundingCount}',
            ),
            _readoutRow(
              'Onset range',
              '${_selectionSummary().start.toStringAsFixed(3)} .. '
                  '${_selectionSummary().end.toStringAsFixed(3)}',
            ),
          ],
        ],
      ),
    );
  }

  ({double start, double end, int soundingCount}) _selectionSummary() {
    if (_selection.isEmpty) {
      return (start: 0.0, end: 0.0, soundingCount: 0);
    }
    var start = _selection.first.onset;
    var end = _selection.first.onset;
    var sounding = 0;
    for (final hit in _selection) {
      if (hit.onset < start) start = hit.onset;
      if (hit.onset > end) end = hit.onset;
      final element = hit.element;
      if (element is Note || element is Chord || element is Tuplet) {
        sounding++;
      }
    }
    return (start: start, end: end, soundingCount: sounding);
  }

  Widget _readoutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the selection boxes returned by [ScoreHitTester] on top of the score.
class _SelectionOverlayPainter extends CustomPainter {
  final List<ScoreHit> selection;
  final ScoreHit? focus;
  final Color accent;

  const _SelectionOverlayPainter({
    required this.selection,
    required this.focus,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selection.isEmpty) return;

    final fill = Paint()..color = accent.withValues(alpha: 0.12);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: 0.55);

    for (final hit in selection) {
      final rect = RRect.fromRectAndRadius(
        hit.bounds,
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, stroke);
    }

    final focused = focus;
    if (focused != null) {
      final rect = RRect.fromRectAndRadius(
        focused.bounds.inflate(1.5),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionOverlayPainter oldDelegate) {
    return !identical(oldDelegate.selection, selection) ||
        !identical(oldDelegate.focus, focus) ||
        oldDelegate.accent != accent;
  }
}

/// Small rounded action button used by the demo controls.
class _PillButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  const _PillButton({
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: BorderRadius.circular(999),
      color: accent.withValues(alpha: 0.12),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}
