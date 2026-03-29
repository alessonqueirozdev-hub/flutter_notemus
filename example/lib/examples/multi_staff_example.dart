// example/lib/examples/multi_staff_example.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Example demonstrating multi-staff notetion
///
/// Shows:
/// 1. Piano (grand staff with brace)
/// 2. Choir SATB (with bracket)
/// 3. Orchestral score (multiple groups)
class MultiStaffExample {
  /// Create a simple piano score (grand staff)
  static Score createPianoScore() {
    // Treble staff (right hand)
    final trebleStaff = Staff();
    final trebleMeasure = Measure();

    trebleMeasure.add(Clef(type: 'treble'));
    trebleMeasure.add(KeySignature(0)); // C major
    trebleMeasure.add(TimeSignature(numerator: 4, denominator: 4));

    // Right hand melody: C D And F (quarter notes)
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'C', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'D', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'E', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));
    trebleMeasure.add(Note(
      pitch: const Pitch(step: 'F', octave: 5),
      duration: const Duration(DurationType.quarter),
    ));

    trebleStaff.add(trebleMeasure);

    // Bass staff (left hand)
    final bassStaff = Staff();
    final bassMeasure = Measure();

    bassMeasure.add(Clef(type: 'bass'));
    bassMeasure.add(KeySignature(0)); // C major
    bassMeasure.add(TimeSignature(numerator: 4, denominator: 4));

    // Left hand accompaniment: C chord (whole note)
    bassMeasure.add(Chord(
      notes: [
        Note(
          pitch: const Pitch(step: 'C', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'E', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
        Note(
          pitch: const Pitch(step: 'G', octave: 3),
          duration: const Duration(DurationType.whole),
        ),
      ],
      duration: const Duration(DurationType.whole),
    ));

    bassStaff.add(bassMeasure);

    // Create piano score with grand staff
    return Score.grandStaff(
      trebleStaff,
      bassStaff,
      title: 'Piano Example',
      composer: 'Flutter Notemus',
    );
  }

  /// Create a choir SATB score
  static Score createChoirScore() {
    // Soprano staff
    final soprano = _createVoiceStaff('treble', 5, 'Soprano');

    // Alto staff
    final alto = _createVoiceStaff('treble', 4, 'Alto');

    // Tenor staff (treble clef, sounds octave lower)
    final tenor = _createVoiceStaff('treble', 4, 'Tenor');

    // Bass staff
    final bass = _createVoiceStaff('bass', 3, 'Bass');

    return Score.choir(
      soprano,
      alto,
      tenor,
      bass,
      title: 'Ave Maria',
      composer: 'Various',
    );
  }

  /// Create an orchestral score with multiple groups
  static Score createOrchestralScore() {
    // Woodwind section
    final flute = _createInstrumentStaff('Flute', 'treble', 5);
    final clarinet = _createInstrumentStaff('Clarinet', 'treble', 5);
    final woodwindGroup = StaffGroup.woodwinds([flute, clarinet]);

    // Brass section
    final trumpet = _createInstrumentStaff('Trumpet', 'treble', 5);
    final trombone = _createInstrumentStaff('Trombone', 'bass', 3);
    final brassGroup = StaffGroup.brass([trumpet, trombone]);

    // String section
    final violin1 = _createInstrumentStaff('Violin I', 'treble', 5);
    final violin2 = _createInstrumentStaff('Violin II', 'treble', 5);
    final viola = _createInstrumentStaff('Viola', 'alto', 4);
    final cello = _createInstrumentStaff('Cello', 'bass', 3);
    final stringsGroup = StaffGroup.strings([violin1, violin2, viola, cello]);

    return Score.orchestral(
      title: 'Symphony No. 1',
      composer: 'Example Composer',
      groups: [woodwindGroup, brassGroup, stringsGroup],
    );
  }

  /// Helper: Create a voice staff for choir
  static Staff _createVoiceStaff(String clefType, int octave, String voice) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(type: clefType));
    measure.add(KeySignature(0));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Simple quarter notes
    for (int i = 0; i < 4; i++) {
      final steps = ['C', 'D', 'E', 'F'];
      measure.add(Note(
        pitch: Pitch(step: steps[i], octave: octave),
        duration: const Duration(DurationType.quarter),
      ));
    }

    staff.add(measure);
    return staff;
  }

  /// Helper: Create an instrument staff
  static Staff _createInstrumentStaff(
    String name,
    String clefType,
    int octave,
  ) {
    final staff = Staff();
    final measure = Measure();

    measure.add(Clef(type: clefType));
    measure.add(KeySignature(0));
    measure.add(TimeSignature(numerator: 4, denominator: 4));

    // Whole note
    measure.add(Note(
      pitch: Pitch(step: 'C', octave: octave),
      duration: const Duration(DurationType.whole),
    ));

    staff.add(measure);
    return staff;
  }
}

/// Flutter widget to display multi-staff examples
class MultiStaffExampleWidget extends StatelessWidget {
  final Score score;

  const MultiStaffExampleWidget({
    super.key,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(score.title ?? 'Multi-Staff Example'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Score metadata
            if (score.title != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  score.title!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (score.composer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  score.composer!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // TODO: Render score using MultiStaffRenderer
            // For now, show staff groups info
            ...score.staffGroups.asMap().entries.map((entry) {
              final index = entry.key;
              final group = entry.value;
              return Card(
                margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group ${index + 1}: ${group.name ?? 'Unnamed'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Bracket Type: ${group.bracket.name}'),
                      Text('Staff Count: ${group.staffCount}'),
                      Text('Connect Barlines: ${group.connectBarlines}'),
                      if (group.abbreviation != null)
                        Text('Abbreviation: ${group.abbreviation}'),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TimelineAnchor {
  final double time;
  final double x;

  const _TimelineAnchor({
    required this.time,
    required this.x,
  });
}

class _StaffTimelineData {
  final List<_TimelineAnchor> anchors;
  final double prefixStart;
  final Map<double, double> explicitNoteXByTime;
  final Map<double, BarlineType> barlineTypesByTime;

  const _StaffTimelineData({
    required this.anchors,
    required this.prefixStart,
    required this.explicitNoteXByTime,
    required this.barlineTypesByTime,
  });
}

bool _isTimelineElement(MusicalElement element) {
  return element is Note ||
      element is Rest ||
      element is Chord ||
      element is Tuplet;
}

double _timelineDurationOf(MusicalElement element) {
  if (element is Note) return element.duration.realValue;
  if (element is Rest) return element.duration.realValue;
  if (element is Chord) return element.duration.realValue;
  if (element is Tuplet) return element.totalDuration;
  return 0.0;
}

double _minElementXFromElements(List<PositionedElement> elements) {
  return elements
      .map((element) => element.position.dx)
      .fold<double>(double.infinity, math.min);
}

double _maxElementXFromElements(List<PositionedElement> elements) {
  return elements
      .map((element) => element.position.dx)
      .fold<double>(double.negativeInfinity, math.max);
}

double _firstMusicXFromElements(List<PositionedElement> elements) {
  final musicalElements = elements
      .where(
        (positioned) =>
            !_isTimelineSystemElement(positioned.element) &&
            positioned.element is! Barline,
      )
      .toList();
  if (musicalElements.isNotEmpty) {
    return musicalElements
        .map((positioned) => positioned.position.dx)
        .reduce(math.min);
  }
  return _minElementXFromElements(elements);
}

bool _isTimelineSystemElement(MusicalElement element) {
  return element is Clef || element is KeySignature || element is TimeSignature;
}

void _appendTimelineAnchor(
  List<_TimelineAnchor> anchors, {
  required double time,
  required double x,
}) {
  if (!x.isFinite) return;

  if (anchors.isNotEmpty && (anchors.last.time - time).abs() < 0.0001) {
    final current = anchors.last;
    anchors[anchors.length - 1] = _TimelineAnchor(
      time: time,
      x: math.max(current.x, x),
    );
    return;
  }

  anchors.add(_TimelineAnchor(time: time, x: x));
}

void _recordExplicitTimelineX(
  Map<double, double> positionsByTime, {
  required double time,
  required double x,
}) {
  if (!x.isFinite) return;

  final current = positionsByTime[time];
  if (current == null) {
    positionsByTime[time] = x;
    return;
  }

  positionsByTime[time] = math.min(current, x);
}

_StaffTimelineData _buildStaffTimeline({
  required Staff staff,
  required List<PositionedElement> elements,
}) {
  final anchors = <_TimelineAnchor>[];
  final explicitNoteXByTime = <double, double>{};
  final barlineTypesByTime = <double, BarlineType>{};
  final positionedRhythmic = elements
      .where((positioned) => _isTimelineElement(positioned.element))
      .toList();
  final positionedBarlines =
      elements.where((positioned) => positioned.element is Barline).toList();

  var rhythmicIndex = 0;
  var barlineIndex = 0;
  var cumulativeTime = 0.0;

  for (final measure in staff.measures) {
    final rhythmicElements =
        measure.elements.where(_isTimelineElement).toList();

    for (final element in rhythmicElements) {
      if (rhythmicIndex >= positionedRhythmic.length) {
        break;
      }

      _recordExplicitTimelineX(
        explicitNoteXByTime,
        time: cumulativeTime,
        x: positionedRhythmic[rhythmicIndex].position.dx,
      );
      _appendTimelineAnchor(
        anchors,
        time: cumulativeTime,
        x: positionedRhythmic[rhythmicIndex].position.dx,
      );
      cumulativeTime += _timelineDurationOf(element);
      rhythmicIndex++;
    }

    if (barlineIndex < positionedBarlines.length) {
      final positionedBarline = positionedBarlines[barlineIndex];
      _appendTimelineAnchor(
        anchors,
        time: cumulativeTime,
        x: positionedBarline.position.dx,
      );
      barlineTypesByTime[cumulativeTime] =
          (positionedBarline.element as Barline).type;
      barlineIndex++;
    }
  }

  if (anchors.isEmpty) {
    final firstMusicX = _firstMusicXFromElements(elements);
    _appendTimelineAnchor(anchors, time: 0.0, x: firstMusicX);
    final maxX = _maxElementXFromElements(elements);
    if (maxX.isFinite && maxX > firstMusicX) {
      _appendTimelineAnchor(anchors, time: 1.0, x: maxX);
    }
  }

  return _StaffTimelineData(
    anchors: anchors,
    prefixStart: _minElementXFromElements(elements),
    explicitNoteXByTime: explicitNoteXByTime,
    barlineTypesByTime: barlineTypesByTime,
  );
}

double _interpolateTimelineXByTime(
  List<_TimelineAnchor> anchors,
  double time,
) {
  if (anchors.isEmpty) return 0.0;

  if (time <= anchors.first.time) {
    return anchors.first.x;
  }
  if (time >= anchors.last.time) {
    return anchors.last.x;
  }

  for (int i = 0; i < anchors.length - 1; i++) {
    final left = anchors[i];
    final right = anchors[i + 1];
    if (time > right.time) continue;

    final span = right.time - left.time;
    if (span.abs() < 0.0001) {
      return right.x;
    }

    final ratio = ((time - left.time) / span).clamp(0.0, 1.0).toDouble();
    return left.x + ((right.x - left.x) * ratio);
  }

  return anchors.last.x;
}

List<_TimelineAnchor> _buildSharedTimeline(List<_StaffTimelineData> timelines) {
  final times = timelines
      .expand((timeline) => timeline.explicitNoteXByTime.keys)
      .toSet()
      .toList()
    ..sort();

  final shared = <_TimelineAnchor>[];
  for (int index = 0; index < times.length; index++) {
    final time = times[index];
    final explicitXs = timelines
        .map((timeline) => timeline.explicitNoteXByTime[time])
        .whereType<double>()
        .toList();
    if (explicitXs.isEmpty) {
      continue;
    }

    var targetX =
        index == 0 ? explicitXs.reduce(math.min) : explicitXs.reduce(math.max);
    if (shared.isNotEmpty && targetX <= shared.last.x + 0.01) {
      targetX = shared.last.x + 0.01;
    }
    shared.add(_TimelineAnchor(time: time, x: targetX));
  }

  return shared;
}

List<PositionedElement> _remapElementsWithTimeline({
  required List<PositionedElement> elements,
  required double prefixStart,
  required double targetPrefixStart,
  required List<_TimelineAnchor> sourceAnchors,
  required List<_TimelineAnchor> sharedAnchors,
}) {
  if (elements.isEmpty || sourceAnchors.isEmpty || sharedAnchors.isEmpty) {
    return elements;
  }

  final targetAnchors = sourceAnchors
      .map(
        (anchor) => _TimelineAnchor(
          time: anchor.time,
          x: _interpolateTimelineXByTime(sharedAnchors, anchor.time),
        ),
      )
      .toList();

  if (sourceAnchors.length == 1) {
    final deltaX = targetAnchors.first.x - sourceAnchors.first.x;
    return elements
        .map(
          (positioned) => PositionedElement(
            positioned.element,
            Offset(positioned.position.dx + deltaX, positioned.position.dy),
            system: positioned.system,
            voiceNumber: positioned.voiceNumber,
          ),
        )
        .toList();
  }

  double mapX(double x) {
    final firstSourceX = sourceAnchors.first.x;
    final firstTargetX = targetAnchors.first.x;

    if (x <= firstSourceX) {
      final sourcePrefixSpan = firstSourceX - prefixStart;
      final targetPrefixSpan = firstTargetX - targetPrefixStart;
      if (sourcePrefixSpan.abs() < 0.0001) {
        return firstTargetX;
      }

      final ratio = ((x - prefixStart) / sourcePrefixSpan).clamp(0.0, 1.0);
      return targetPrefixStart + (targetPrefixSpan * ratio);
    }

    for (int i = 0; i < sourceAnchors.length - 1; i++) {
      final sourceLeft = sourceAnchors[i];
      final sourceRight = sourceAnchors[i + 1];
      if (x > sourceRight.x && i < sourceAnchors.length - 2) {
        continue;
      }

      final targetLeft = targetAnchors[i];
      final targetRight = targetAnchors[i + 1];
      final sourceSpan = sourceRight.x - sourceLeft.x;
      if (sourceSpan.abs() < 0.0001) {
        return targetLeft.x;
      }

      final ratio = ((x - sourceLeft.x) / sourceSpan).clamp(0.0, 1.0);
      return targetLeft.x + ((targetRight.x - targetLeft.x) * ratio);
    }

    final overflowAfterEnd = x - sourceAnchors.last.x;
    return targetAnchors.last.x + overflowAfterEnd;
  }

  return elements
      .map(
        (positioned) => PositionedElement(
          positioned.element,
          Offset(mapX(positioned.position.dx), positioned.position.dy),
          system: positioned.system,
          voiceNumber: positioned.voiceNumber,
        ),
      )
      .toList();
}

/// Main widget for multi-story demo
/// Renders two staves (treble clef + bass clef) with shared timeline.
///
/// This implementation avoids note misalignment and visually connects the
/// bars between the two staves, as in the grand piano staff.
class GrandStaffScore extends StatefulWidget {
  final Staff trebleStaff;
  final Staff bassStaff;
  final MusicScoreTheme theme;
  final double staffSpace;
  final double interStaffSpacing;

  const GrandStaffScore({
    super.key,
    required this.trebleStaff,
    required this.bassStaff,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.interStaffSpacing = 8.0,
  });

  @override
  State<GrandStaffScore> createState() => _GrandStaffScoreState();
}

class _GrandStaffScoreState extends State<GrandStaffScore> {
  late final SmuflMetadata _metadata;
  late final Future<void> _metadataFuture;

  @override
  void initState() {
    super.initState();
    _metadata = SmuflMetadata();
    _metadataFuture = _metadata.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load metadata: ${snapshot.error}',
              style: const TextStyle(fontSize: 12),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;

            final trebleLayout = LayoutEngine(
              widget.trebleStaff,
              availableWidth: availableWidth,
              staffSpace: widget.staffSpace,
              metadata: _metadata,
            );
            final bassLayout = LayoutEngine(
              widget.bassStaff,
              availableWidth: availableWidth,
              staffSpace: widget.staffSpace,
              metadata: _metadata,
            );

            final trebleElements = trebleLayout.layout();
            final bassElements = bassLayout.layout();

            if (trebleElements.isEmpty || bassElements.isEmpty) {
              return const SizedBox.shrink();
            }

            final aligned = _alignByMeasureBoundaries(
              trebleElements: trebleElements,
              bassElements: bassElements,
              viewportWidth: availableWidth,
            );

            final topBaselineY = widget.staffSpace * 5;
            final bottomBaselineY =
                topBaselineY + (widget.interStaffSpacing * widget.staffSpace);
            final bassVerticalShift = bottomBaselineY - (widget.staffSpace * 5);

            final shiftedBass = _offsetElementsY(
              aligned.bassElements,
              bassVerticalShift,
            );

            final canvasHeight = bottomBaselineY + (widget.staffSpace * 5);
            final canvasWidth = _resolveGrandStaffCanvasWidth(
              availableWidth: availableWidth,
              trebleElements: aligned.trebleElements,
              bassElements: shiftedBass,
              sharedBarlines: aligned.sharedBarlines,
            );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ClipRect(
                child: CustomPaint(
                  size: Size(canvasWidth, canvasHeight),
                  painter: _GrandStaffPainter(
                    metadata: _metadata,
                    theme: widget.theme,
                    staffSpace: widget.staffSpace,
                    topBaselineY: topBaselineY,
                    bottomBaselineY: bottomBaselineY,
                    trebleElements: aligned.trebleElements,
                    bassElements: shiftedBass,
                    barlines: aligned.sharedBarlines,
                    trebleLayout: trebleLayout,
                    bassLayout: bassLayout,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  _GrandStaffAlignedData _alignByMeasureBoundaries({
    required List<PositionedElement> trebleElements,
    required List<PositionedElement> bassElements,
    required double viewportWidth,
  }) {
    final timelines = [
      _buildStaffTimeline(
        staff: widget.trebleStaff,
        elements: trebleElements,
      ),
      _buildStaffTimeline(
        staff: widget.bassStaff,
        elements: bassElements,
      ),
    ];
    final sharedAnchors = _buildSharedTimeline(timelines);
    if (sharedAnchors.isEmpty) {
      return _GrandStaffAlignedData(
        trebleElements: trebleElements,
        bassElements: bassElements,
        sharedBarlines: const [],
      );
    }

    final sharedPrefixStart =
        timelines.map((timeline) => timeline.prefixStart).reduce(math.min);

    final alignedTreble = _remapElementsWithTimeline(
      elements: trebleElements,
      prefixStart: timelines[0].prefixStart,
      targetPrefixStart: sharedPrefixStart,
      sourceAnchors: timelines[0].anchors,
      sharedAnchors: sharedAnchors,
    );
    final alignedBass = _remapElementsWithTimeline(
      elements: bassElements,
      prefixStart: timelines[1].prefixStart,
      targetPrefixStart: sharedPrefixStart,
      sourceAnchors: timelines[1].anchors,
      sharedAnchors: sharedAnchors,
    );
    final alignedSystemElements = _alignTimeSignatures(
      trebleElements: alignedTreble,
      bassElements: alignedBass,
      firstBoundaryX: sharedAnchors.first.x,
    );
    final alignedBarlines = _alignSharedBarlines(
      trebleElements: alignedSystemElements.treble,
      bassElements: alignedSystemElements.bass,
      timelines: timelines,
      sharedAnchors: sharedAnchors,
      viewportWidth: viewportWidth,
    );

    return _GrandStaffAlignedData(
      trebleElements: alignedBarlines.treble,
      bassElements: alignedBarlines.bass,
      sharedBarlines: alignedBarlines.barlines,
    );
  }

  ({List<PositionedElement> treble, List<PositionedElement> bass})
      _alignTimeSignatures({
    required List<PositionedElement> trebleElements,
    required List<PositionedElement> bassElements,
    required double firstBoundaryX,
  }) {
    final trebleIndices = _matchingElementIndices(
        trebleElements, (element) => element is TimeSignature);
    final bassIndices = _matchingElementIndices(
        bassElements, (element) => element is TimeSignature);
    if (trebleIndices.isEmpty || bassIndices.isEmpty) {
      return (treble: trebleElements, bass: bassElements);
    }

    final adjustedTreble = List<PositionedElement>.from(trebleElements);
    final adjustedBass = List<PositionedElement>.from(bassElements);
    final pairCount = math.min(trebleIndices.length, bassIndices.length);
    final minAllowedX = _maxFirstXByType<Clef>([
          adjustedTreble,
          adjustedBass,
        ]) +
        (widget.staffSpace * 1.8);
    final maxAllowedX = firstBoundaryX - (widget.staffSpace * 3.8);

    for (int i = 0; i < pairCount; i++) {
      final trebleIndex = trebleIndices[i];
      final bassIndex = bassIndices[i];
      final desiredX = (adjustedTreble[trebleIndex].position.dx +
              adjustedBass[bassIndex].position.dx) /
          2;
      final alignedX = maxAllowedX > minAllowedX
          ? desiredX.clamp(minAllowedX, maxAllowedX).toDouble()
          : minAllowedX;
      adjustedTreble[trebleIndex] =
          _withX(adjustedTreble[trebleIndex], alignedX);
      adjustedBass[bassIndex] = _withX(adjustedBass[bassIndex], alignedX);
    }

    return (treble: adjustedTreble, bass: adjustedBass);
  }

  ({
    List<PositionedElement> treble,
    List<PositionedElement> bass,
    List<_AlignedBarline> barlines,
  }) _alignSharedBarlines({
    required List<PositionedElement> trebleElements,
    required List<PositionedElement> bassElements,
    required List<_StaffTimelineData> timelines,
    required List<_TimelineAnchor> sharedAnchors,
    required double viewportWidth,
  }) {
    final adjustedTreble = List<PositionedElement>.from(trebleElements);
    final adjustedBass = List<PositionedElement>.from(bassElements);
    final trebleIndices = _matchingElementIndices(
        adjustedTreble, (element) => element is Barline);
    final bassIndices =
        _matchingElementIndices(adjustedBass, (element) => element is Barline);
    final barlineTimes = timelines
        .expand((timeline) => timeline.barlineTypesByTime.keys)
        .toSet()
        .toList()
      ..sort();
    final pairCount = [
      trebleIndices.length,
      bassIndices.length,
      barlineTimes.length,
    ].reduce(math.min);
    if (pairCount == 0) {
      return (
        treble: adjustedTreble,
        bass: adjustedBass,
        barlines: const <_AlignedBarline>[],
      );
    }

    final alignedBarlines = <_AlignedBarline>[];
    for (int i = 0; i < pairCount; i++) {
      final trebleIndex = trebleIndices[i];
      final bassIndex = bassIndices[i];
      final barlineTime = barlineTimes[i];
      final trebleBarline = adjustedTreble[trebleIndex].element as Barline;
      final bassBarline = adjustedBass[bassIndex].element as Barline;
      final preferredType =
          _preferBarlineType(trebleBarline.type, bassBarline.type);
      var alignedX = _preferredSharedBarlineX(
        time: barlineTime,
        timelines: timelines,
        sharedAnchors: sharedAnchors,
        fallbackX: math.max(
          adjustedTreble[trebleIndex].position.dx,
          adjustedBass[bassIndex].position.dx,
        ),
      );
      final previousMusicX = [
        _previousTimelineElementX(adjustedTreble, trebleIndex),
        _previousTimelineElementX(adjustedBass, bassIndex),
      ].whereType<double>().toList();
      final nextMusicX = [
        _nextTimelineElementX(adjustedTreble, trebleIndex),
        _nextTimelineElementX(adjustedBass, bassIndex),
      ].whereType<double>().toList();
      final minAllowedX = previousMusicX.isEmpty
          ? double.negativeInfinity
          : previousMusicX.reduce(math.max) + (widget.staffSpace * 2.8);
      final visualWidth = _barlineVisualWidth(preferredType);
      final maxAllowedX = nextMusicX.isEmpty
          ? viewportWidth - visualWidth - (widget.staffSpace * 1.8)
          : nextMusicX.reduce(math.min) -
              visualWidth -
              (widget.staffSpace * 2.8);
      if (maxAllowedX.isFinite && maxAllowedX > minAllowedX) {
        alignedX = alignedX.clamp(minAllowedX, maxAllowedX).toDouble();
      } else {
        alignedX = math.max(alignedX, minAllowedX);
      }
      if (alignedBarlines.isNotEmpty &&
          alignedX <= alignedBarlines.last.x + 0.01) {
        alignedX = alignedBarlines.last.x + 0.01;
      }

      adjustedTreble[trebleIndex] =
          _withX(adjustedTreble[trebleIndex], alignedX);
      adjustedBass[bassIndex] = _withX(adjustedBass[bassIndex], alignedX);
      alignedBarlines.add(
        _AlignedBarline(
          x: alignedX,
          type: preferredType,
        ),
      );
    }

    return (
      treble: adjustedTreble,
      bass: adjustedBass,
      barlines: alignedBarlines,
    );
  }

  double _resolveGrandStaffCanvasWidth({
    required double availableWidth,
    required List<PositionedElement> trebleElements,
    required List<PositionedElement> bassElements,
    required List<_AlignedBarline> sharedBarlines,
  }) {
    final maxElementX = [
      _maxElementXFromElements(trebleElements),
      _maxElementXFromElements(bassElements),
    ].reduce(math.max);
    final maxBarlineExtent = sharedBarlines.isEmpty
        ? 0.0
        : sharedBarlines
            .map((barline) => barline.x + _barlineVisualWidth(barline.type))
            .reduce(math.max);
    final requiredWidth =
        math.max(maxElementX, maxBarlineExtent) + (widget.staffSpace * 2);
    return math.max(availableWidth, requiredWidth);
  }

  double _preferredSharedBarlineX({
    required double time,
    required List<_StaffTimelineData> timelines,
    required List<_TimelineAnchor> sharedAnchors,
    required double fallbackX,
  }) {
    final previousSharedAnchors =
        sharedAnchors.where((anchor) => anchor.time < time).toList();
    if (previousSharedAnchors.isEmpty) {
      return fallbackX;
    }

    final referenceAnchor = previousSharedAnchors.last;
    final candidateGaps = <double>[];
    for (final timeline in timelines) {
      final previousAnchor = _lastTimelineAnchorBefore(timeline.anchors, time);
      final barlineAnchor = _timelineAnchorAt(timeline.anchors, time);
      if (previousAnchor == null || barlineAnchor == null) {
        continue;
      }
      if ((previousAnchor.time - referenceAnchor.time).abs() > 0.0001) {
        continue;
      }

      final gap = barlineAnchor.x - previousAnchor.x;
      if (gap.isFinite && gap > 0) {
        candidateGaps.add(gap);
      }
    }

    if (candidateGaps.isEmpty) {
      return fallbackX;
    }

    return referenceAnchor.x + candidateGaps.reduce(math.max);
  }

  _TimelineAnchor? _lastTimelineAnchorBefore(
    List<_TimelineAnchor> anchors,
    double time,
  ) {
    for (int index = anchors.length - 1; index >= 0; index--) {
      if (anchors[index].time < time - 0.0001) {
        return anchors[index];
      }
    }
    return null;
  }

  _TimelineAnchor? _timelineAnchorAt(
    List<_TimelineAnchor> anchors,
    double time,
  ) {
    for (final anchor in anchors) {
      if ((anchor.time - time).abs() < 0.0001) {
        return anchor;
      }
    }
    return null;
  }

  double? _previousTimelineElementX(
    List<PositionedElement> elements,
    int fromIndex,
  ) {
    for (int index = fromIndex - 1; index >= 0; index--) {
      if (_isTimelineElement(elements[index].element)) {
        return elements[index].position.dx;
      }
    }
    return null;
  }

  double? _nextTimelineElementX(
    List<PositionedElement> elements,
    int fromIndex,
  ) {
    for (int index = fromIndex + 1; index < elements.length; index++) {
      if (_isTimelineElement(elements[index].element)) {
        return elements[index].position.dx;
      }
    }
    return null;
  }

  double _barlineVisualWidth(BarlineType type) {
    final thinThickness =
        _metadata.getEngravingDefault('thinBarlineThickness') *
            widget.staffSpace;
    final thickThickness =
        _metadata.getEngravingDefault('thickBarlineThickness') *
            widget.staffSpace;

    if (type == BarlineType.final_) {
      return _metadata.getGlyphWidth('barlineFinal') * widget.staffSpace;
    }
    if (type == BarlineType.double || type == BarlineType.lightLight) {
      return _metadata.getGlyphWidth('barlineDouble') * widget.staffSpace;
    }

    return math.max(thinThickness, thickThickness * 0.5);
  }

  List<int> _matchingElementIndices(
    List<PositionedElement> elements,
    bool Function(MusicalElement element) predicate,
  ) {
    final indices = <int>[];
    for (int i = 0; i < elements.length; i++) {
      if (predicate(elements[i].element)) {
        indices.add(i);
      }
    }
    return indices;
  }

  PositionedElement _withX(PositionedElement positioned, double x) {
    return PositionedElement(
      positioned.element,
      Offset(x, positioned.position.dy),
      system: positioned.system,
      voiceNumber: positioned.voiceNumber,
    );
  }

  double _maxFirstXByType<T extends MusicalElement>(
    List<List<PositionedElement>> staffs,
  ) {
    var maxX = double.negativeInfinity;
    for (final elements in staffs) {
      for (final positioned in elements) {
        if (positioned.element is T) {
          maxX = math.max(maxX, positioned.position.dx);
          break;
        }
      }
    }
    return maxX.isFinite ? maxX : 0;
  }

  BarlineType _preferBarlineType(BarlineType? a, BarlineType? b) {
    if (a == BarlineType.final_ || b == BarlineType.final_) {
      return BarlineType.final_;
    }
    if (a == BarlineType.double || a == BarlineType.lightLight) {
      return a!;
    }
    if (b == BarlineType.double || b == BarlineType.lightLight) {
      return b!;
    }
    return b ?? a ?? BarlineType.single;
  }

  List<PositionedElement> _offsetElementsY(
    List<PositionedElement> elements,
    double deltaY,
  ) {
    return elements
        .map(
          (positioned) => PositionedElement(
            positioned.element,
            Offset(positioned.position.dx, positioned.position.dy + deltaY),
            system: positioned.system,
            voiceNumber: positioned.voiceNumber,
          ),
        )
        .toList();
  }
}

class _GrandStaffAlignedData {
  final List<PositionedElement> trebleElements;
  final List<PositionedElement> bassElements;
  final List<_AlignedBarline> sharedBarlines;

  const _GrandStaffAlignedData({
    required this.trebleElements,
    required this.bassElements,
    required this.sharedBarlines,
  });
}

class _GrandStaffPainter extends CustomPainter {
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double staffSpace;
  final double topBaselineY;
  final double bottomBaselineY;
  final List<PositionedElement> trebleElements;
  final List<PositionedElement> bassElements;
  final List<_AlignedBarline> barlines;
  final LayoutEngine trebleLayout;
  final LayoutEngine bassLayout;

  const _GrandStaffPainter({
    required this.metadata,
    required this.theme,
    required this.staffSpace,
    required this.topBaselineY,
    required this.bottomBaselineY,
    required this.trebleElements,
    required this.bassElements,
    required this.barlines,
    required this.trebleLayout,
    required this.bassLayout,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded ||
        trebleElements.isEmpty ||
        bassElements.isEmpty) {
      return;
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final topCoordinates = StaffCoordinateSystem(
      staffSpace: staffSpace,
      staffBaseline: Offset(0, topBaselineY),
    );
    final bottomCoordinates = StaffCoordinateSystem(
      staffSpace: staffSpace,
      staffBaseline: Offset(0, bottomBaselineY),
    );

    final trebleRenderer = StaffRenderer(
      coordinates: topCoordinates,
      metadata: metadata,
      theme: theme,
    );
    final bassRenderer = StaffRenderer(
      coordinates: bottomCoordinates,
      metadata: metadata,
      theme: theme,
    );

    trebleRenderer.renderStaff(
      canvas,
      trebleElements,
      size,
      layoutEngine: trebleLayout,
      renderBarlines: true,
    );
    bassRenderer.renderStaff(
      canvas,
      bassElements,
      size,
      layoutEngine: bassLayout,
      renderBarlines: true,
    );

    final thinThickness =
        metadata.getEngravingDefault('thinBarlineThickness') * staffSpace;
    final thickThickness =
        metadata.getEngravingDefault('thickBarlineThickness') * staffSpace;
    final finalBarlineWidth =
        metadata.getGlyphWidth('barlineFinal') * staffSpace;
    final doubleBarlineWidth =
        metadata.getGlyphWidth('barlineDouble') * staffSpace;
    final connectorTopY = topCoordinates.getStaffLineY(1);
    final connectorBottomY = bottomCoordinates.getStaffLineY(5);

    void drawConnector({
      required double x,
      required double thickness,
    }) {
      final paint = Paint()
        ..color = theme.barlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness;
      canvas.drawLine(
        Offset(x, connectorTopY),
        Offset(x, connectorBottomY),
        paint,
      );
    }

    BarlineType preferBarlineType(BarlineType? a, BarlineType? b) {
      if (a == BarlineType.final_ || b == BarlineType.final_) {
        return BarlineType.final_;
      }
      if (a == BarlineType.double || a == BarlineType.lightLight) {
        return a!;
      }
      if (b == BarlineType.double || b == BarlineType.lightLight) {
        return b!;
      }
      return a ?? b ?? BarlineType.single;
    }

    final effectiveBarlines = <_AlignedBarline>[...barlines];
    void mergeElementBarlines(List<PositionedElement> elements) {
      for (final positioned in elements) {
        if (positioned.element is! Barline ||
            !positioned.position.dx.isFinite) {
          continue;
        }

        final barline = positioned.element as Barline;
        final existingIndex = effectiveBarlines.indexWhere(
          (candidate) => (candidate.x - positioned.position.dx).abs() < 0.01,
        );
        if (existingIndex == -1) {
          effectiveBarlines.add(
            _AlignedBarline(
              x: positioned.position.dx,
              type: barline.type,
            ),
          );
          continue;
        }

        effectiveBarlines[existingIndex] = _AlignedBarline(
          x: effectiveBarlines[existingIndex].x,
          type: preferBarlineType(
            effectiveBarlines[existingIndex].type,
            barline.type,
          ),
        );
      }
    }

    mergeElementBarlines(trebleElements);
    mergeElementBarlines(bassElements);
    effectiveBarlines.sort((a, b) => a.x.compareTo(b.x));

    for (final barline in effectiveBarlines) {
      if (!barline.x.isFinite) continue;

      final primaryCenterX = barline.x + (thinThickness * 0.5);
      drawConnector(x: primaryCenterX, thickness: thinThickness);

      if (barline.type == BarlineType.final_) {
        final secondaryCenterX =
            barline.x + finalBarlineWidth - (thickThickness * 0.5);
        drawConnector(x: secondaryCenterX, thickness: thickThickness);
      } else if (barline.type == BarlineType.double ||
          barline.type == BarlineType.lightLight) {
        final secondaryCenterX =
            barline.x + doubleBarlineWidth - (thinThickness * 0.5);
        drawConnector(x: secondaryCenterX, thickness: thinThickness);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GrandStaffPainter oldDelegate) {
    return oldDelegate.trebleElements.length != trebleElements.length ||
        oldDelegate.bassElements.length != bassElements.length ||
        oldDelegate.barlines.length != barlines.length ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.theme != theme;
  }
}

class _AlignedBarline {
  final double x;
  final BarlineType type;

  const _AlignedBarline({
    required this.x,
    required this.type,
  });
}

class LabeledStaff {
  final String label;
  final Staff staff;

  const LabeledStaff({
    required this.label,
    required this.staff,
  });
}

class _MultiStaffAlignedData {
  final List<List<PositionedElement>> elementsByStaff;
  final List<_AlignedBarline> sharedBarlines;

  const _MultiStaffAlignedData({
    required this.elementsByStaff,
    required this.sharedBarlines,
  });
}

class ConnectedMultiStaffScore extends StatefulWidget {
  final List<LabeledStaff> staves;
  final MusicScoreTheme theme;
  final double staffSpace;
  final double interStaffSpacing;

  const ConnectedMultiStaffScore({
    super.key,
    required this.staves,
    this.theme = const MusicScoreTheme(),
    this.staffSpace = 12.0,
    this.interStaffSpacing = 7.0,
  });

  @override
  State<ConnectedMultiStaffScore> createState() =>
      _ConnectedMultiStaffScoreState();
}

class _ConnectedMultiStaffScoreState extends State<ConnectedMultiStaffScore> {
  late final SmuflMetadata _metadata;
  late final Future<void> _metadataFuture;

  @override
  void initState() {
    super.initState();
    _metadata = SmuflMetadata();
    _metadataFuture = _metadata.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load metadata: ${snapshot.error}',
              style: const TextStyle(fontSize: 12),
            ),
          );
        }

        if (widget.staves.isEmpty) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;

            final layouts = widget.staves
                .map(
                  (entry) => LayoutEngine(
                    entry.staff,
                    availableWidth: availableWidth,
                    staffSpace: widget.staffSpace,
                    metadata: _metadata,
                  ),
                )
                .toList();

            final elementsByStaff =
                layouts.map((layout) => layout.layout()).toList();
            if (elementsByStaff.any((elements) => elements.isEmpty)) {
              return const SizedBox.shrink();
            }

            final aligned = _alignByMeasureBoundaries(elementsByStaff);
            final firstBaselineY = widget.staffSpace * 5;
            final baselineStride = widget.interStaffSpacing * widget.staffSpace;
            final baselineYs = List<double>.generate(
              widget.staves.length,
              (index) => firstBaselineY + (baselineStride * index),
            );

            final shifted = <List<PositionedElement>>[];
            for (int i = 0; i < aligned.elementsByStaff.length; i++) {
              final deltaY = baselineYs[i] - firstBaselineY;
              shifted.add(_offsetElementsY(aligned.elementsByStaff[i], deltaY));
            }

            final canvasHeight = baselineYs.last + (widget.staffSpace * 5);
            return ClipRect(
              child: CustomPaint(
                size: Size(availableWidth, canvasHeight),
                painter: _ConnectedMultiStaffPainter(
                  metadata: _metadata,
                  theme: widget.theme,
                  staffSpace: widget.staffSpace,
                  labels: widget.staves.map((entry) => entry.label).toList(),
                  baselineYs: baselineYs,
                  elementsByStaff: shifted,
                  barlines: aligned.sharedBarlines,
                  layouts: layouts,
                ),
              ),
            );
          },
        );
      },
    );
  }

  _MultiStaffAlignedData _alignByMeasureBoundaries(
    List<List<PositionedElement>> staffs,
  ) {
    final boundariesByStaff = staffs.map(_extractMeasureBoundaries).toList();
    final barlinesByStaff = staffs.map(_extractBarlines).toList();
    final minBoundaryCount = boundariesByStaff
        .map((boundaries) => boundaries.length)
        .reduce(math.min);
    if (minBoundaryCount < 2) {
      return _MultiStaffAlignedData(
        elementsByStaff: staffs,
        sharedBarlines: const [],
      );
    }

    final segmentCount = math.max(1, minBoundaryCount - 1);
    final sourceBoundariesByStaff = boundariesByStaff
        .map((boundaries) => boundaries.take(segmentCount + 1).toList())
        .toList();

    final starts =
        sourceBoundariesByStaff.map((boundaries) => boundaries.first);
    final ends = sourceBoundariesByStaff.map((boundaries) => boundaries.last);

    final sharedStart = starts.reduce(math.min);
    var sharedEnd = ends.reduce(math.min);
    if (sharedEnd <= sharedStart) {
      sharedEnd = ends.reduce(math.max);
    }

    final sharedBoundaries = <double>[sharedStart];
    if (segmentCount > 1) {
      for (int i = 1; i < segmentCount; i++) {
        final targetProgress = sourceBoundariesByStaff
            .map(
              (boundaries) => _safeProgress(
                value: boundaries[i],
                start: boundaries.first,
                end: boundaries.last,
              ),
            )
            .reduce(math.max);
        var targetX =
            sharedStart + ((sharedEnd - sharedStart) * targetProgress);
        if (targetX <= sharedBoundaries.last + 0.01) {
          targetX = sharedBoundaries.last + 0.01;
        }
        sharedBoundaries.add(targetX);
      }
    }
    sharedBoundaries.add(sharedEnd);

    final prefixStarts = staffs.map(_minElementX).toList();
    final sharedPrefixStart = prefixStarts.reduce(math.min);

    final remapped = <List<PositionedElement>>[];
    for (int i = 0; i < staffs.length; i++) {
      remapped.add(
        _remapElementsX(
          elements: staffs[i],
          prefixStart: prefixStarts[i],
          targetPrefixStart: sharedPrefixStart,
          originalBoundaries: sourceBoundariesByStaff[i],
          targetBoundaries: sharedBoundaries,
        ),
      );
    }

    final alignedSystemElements =
        _alignTimeSignaturesAcrossStaves(remapped, sharedBoundaries.first);

    final sharedBarlines = <_AlignedBarline>[];
    for (int i = 1; i < sharedBoundaries.length; i++) {
      final barlineIndex = i - 1;
      final barlineTypes = barlinesByStaff
          .map(
            (barlines) => barlineIndex < barlines.length
                ? barlines[barlineIndex].type
                : null,
          )
          .toList();
      sharedBarlines.add(
        _AlignedBarline(
          x: sharedBoundaries[i],
          type: _preferBarlineTypeList(barlineTypes),
        ),
      );
    }

    return _MultiStaffAlignedData(
      elementsByStaff: alignedSystemElements,
      sharedBarlines: sharedBarlines,
    );
  }

  List<List<PositionedElement>> _alignTimeSignaturesAcrossStaves(
    List<List<PositionedElement>> staffs,
    double firstBoundaryX,
  ) {
    final indicesByStaff = staffs
        .map(
          (elements) => _matchingElementIndices(
            elements,
            (element) => element is TimeSignature,
          ),
        )
        .toList();
    final timeSigPairCount =
        indicesByStaff.map((indices) => indices.length).reduce(math.min);
    if (timeSigPairCount == 0) {
      return staffs;
    }

    final adjusted = staffs
        .map((elements) => List<PositionedElement>.from(elements))
        .toList();
    final minAllowedX =
        _maxFirstXByType<Clef>(adjusted) + (widget.staffSpace * 1.8);
    final maxAllowedX = firstBoundaryX - (widget.staffSpace * 3.8);

    for (int pair = 0; pair < timeSigPairCount; pair++) {
      var sum = 0.0;
      for (int staffIndex = 0; staffIndex < adjusted.length; staffIndex++) {
        final elementIndex = indicesByStaff[staffIndex][pair];
        sum += adjusted[staffIndex][elementIndex].position.dx;
      }
      final desiredX = sum / adjusted.length;
      final alignedX = maxAllowedX > minAllowedX
          ? desiredX.clamp(minAllowedX, maxAllowedX).toDouble()
          : minAllowedX;

      for (int staffIndex = 0; staffIndex < adjusted.length; staffIndex++) {
        final elementIndex = indicesByStaff[staffIndex][pair];
        adjusted[staffIndex][elementIndex] =
            _withX(adjusted[staffIndex][elementIndex], alignedX);
      }
    }

    return adjusted;
  }

  List<int> _matchingElementIndices(
    List<PositionedElement> elements,
    bool Function(MusicalElement element) predicate,
  ) {
    final indices = <int>[];
    for (int i = 0; i < elements.length; i++) {
      if (predicate(elements[i].element)) {
        indices.add(i);
      }
    }
    return indices;
  }

  PositionedElement _withX(PositionedElement positioned, double x) {
    return PositionedElement(
      positioned.element,
      Offset(x, positioned.position.dy),
      system: positioned.system,
      voiceNumber: positioned.voiceNumber,
    );
  }

  List<double> _extractMeasureBoundaries(List<PositionedElement> elements) {
    final firstMusicX = _firstMusicX(elements);
    final barlineXs = _extractBarlines(elements).map((barline) => barline.x);
    final boundaries = <double>[firstMusicX];

    for (final x in barlineXs) {
      if ((x - boundaries.last).abs() > 0.01) {
        boundaries.add(x);
      }
    }

    if (boundaries.length < 2) {
      boundaries.add(_maxElementX(elements));
    }

    return boundaries;
  }

  List<_AlignedBarline> _extractBarlines(List<PositionedElement> elements) {
    final barlines = elements
        .where((positioned) => positioned.element is Barline)
        .map(
          (positioned) => _AlignedBarline(
            x: positioned.position.dx,
            type: (positioned.element as Barline).type,
          ),
        )
        .where((barline) => barline.x.isFinite)
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
    return barlines;
  }

  double _firstMusicX(List<PositionedElement> elements) {
    final musicalElements = elements
        .where(
          (positioned) =>
              !_isSystemElement(positioned.element) &&
              positioned.element is! Barline,
        )
        .toList();
    if (musicalElements.isNotEmpty) {
      return musicalElements
          .map((positioned) => positioned.position.dx)
          .reduce(math.min);
    }
    return _minElementX(elements);
  }

  double _safeProgress({
    required double value,
    required double start,
    required double end,
  }) {
    final span = end - start;
    if (span.abs() < 0.0001) {
      return 1.0;
    }
    return ((value - start) / span).clamp(0.0, 1.0).toDouble();
  }

  bool _isSystemElement(MusicalElement element) {
    return element is Clef ||
        element is KeySignature ||
        element is TimeSignature;
  }

  List<PositionedElement> _remapElementsX({
    required List<PositionedElement> elements,
    required double prefixStart,
    required double targetPrefixStart,
    required List<double> originalBoundaries,
    required List<double> targetBoundaries,
  }) {
    if (elements.isEmpty ||
        originalBoundaries.length < 2 ||
        targetBoundaries.length < 2) {
      return elements;
    }

    final segmentCount = math.min(
          originalBoundaries.length,
          targetBoundaries.length,
        ) -
        1;
    final sourceStart = originalBoundaries.first;
    final sourceEnd = originalBoundaries.last;

    double mapX(double x) {
      if (x <= sourceStart) {
        final sourcePrefixSpan = sourceStart - prefixStart;
        final targetPrefixSpan = targetBoundaries.first - targetPrefixStart;
        if (sourcePrefixSpan.abs() < 0.0001) {
          return targetBoundaries.first;
        }
        final ratio = ((x - prefixStart) / sourcePrefixSpan).clamp(0.0, 1.0);
        return targetPrefixStart + (targetPrefixSpan * ratio);
      }

      for (int i = 0; i < segmentCount; i++) {
        final sourceSegmentStart = originalBoundaries[i];
        final sourceSegmentEnd = originalBoundaries[i + 1];
        if (x <= sourceSegmentEnd || i == segmentCount - 1) {
          final targetSegmentStart = targetBoundaries[i];
          final targetSegmentEnd = targetBoundaries[i + 1];
          final sourceSpan = sourceSegmentEnd - sourceSegmentStart;
          if (sourceSpan.abs() < 0.0001) {
            return targetSegmentStart;
          }
          final ratio = ((x - sourceSegmentStart) / sourceSpan).clamp(0.0, 1.0);
          return targetSegmentStart +
              ((targetSegmentEnd - targetSegmentStart) * ratio);
        }
      }

      final overflowAfterEnd = x - sourceEnd;
      return targetBoundaries.last + overflowAfterEnd;
    }

    return elements
        .map(
          (positioned) => PositionedElement(
            positioned.element,
            Offset(mapX(positioned.position.dx), positioned.position.dy),
            system: positioned.system,
            voiceNumber: positioned.voiceNumber,
          ),
        )
        .toList();
  }

  double _minElementX(List<PositionedElement> elements) {
    return elements
        .map((element) => element.position.dx)
        .fold<double>(double.infinity, math.min);
  }

  double _maxElementX(List<PositionedElement> elements) {
    return elements
        .map((element) => element.position.dx)
        .fold<double>(double.negativeInfinity, math.max);
  }

  double _maxFirstXByType<T extends MusicalElement>(
    List<List<PositionedElement>> staffs,
  ) {
    var maxX = double.negativeInfinity;
    for (final elements in staffs) {
      for (final positioned in elements) {
        if (positioned.element is T) {
          maxX = math.max(maxX, positioned.position.dx);
          break;
        }
      }
    }
    return maxX.isFinite ? maxX : 0;
  }

  BarlineType _preferBarlineTypeList(List<BarlineType?> barlineTypes) {
    if (barlineTypes.contains(BarlineType.final_)) {
      return BarlineType.final_;
    }
    if (barlineTypes.contains(BarlineType.double)) {
      return BarlineType.double;
    }
    if (barlineTypes.contains(BarlineType.lightLight)) {
      return BarlineType.lightLight;
    }
    for (final type in barlineTypes) {
      if (type != null) {
        return type;
      }
    }
    return BarlineType.single;
  }

  List<PositionedElement> _offsetElementsY(
    List<PositionedElement> elements,
    double deltaY,
  ) {
    return elements
        .map(
          (positioned) => PositionedElement(
            positioned.element,
            Offset(positioned.position.dx, positioned.position.dy + deltaY),
            system: positioned.system,
            voiceNumber: positioned.voiceNumber,
          ),
        )
        .toList();
  }
}

class _ConnectedMultiStaffPainter extends CustomPainter {
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double staffSpace;
  final List<String> labels;
  final List<double> baselineYs;
  final List<List<PositionedElement>> elementsByStaff;
  final List<_AlignedBarline> barlines;
  final List<LayoutEngine> layouts;

  const _ConnectedMultiStaffPainter({
    required this.metadata,
    required this.theme,
    required this.staffSpace,
    required this.labels,
    required this.baselineYs,
    required this.elementsByStaff,
    required this.barlines,
    required this.layouts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (metadata.isNotLoaded ||
        elementsByStaff.isEmpty ||
        baselineYs.isEmpty ||
        layouts.length != elementsByStaff.length) {
      return;
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final coordinates = <StaffCoordinateSystem>[];
    for (int i = 0; i < baselineYs.length; i++) {
      final coordinate = StaffCoordinateSystem(
        staffSpace: staffSpace,
        staffBaseline: Offset(0, baselineYs[i]),
      );
      coordinates.add(coordinate);

      final renderer = StaffRenderer(
        coordinates: coordinate,
        metadata: metadata,
        theme: theme,
      );
      renderer.renderStaff(
        canvas,
        elementsByStaff[i],
        size,
        layoutEngine: layouts[i],
        renderBarlines: false,
      );

      if (i < labels.length) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelY =
            coordinate.getStaffLineY(3) - (labelPainter.height * 0.5);
        labelPainter.paint(canvas, Offset(2, labelY));
      }
    }

    final thinThickness =
        metadata.getEngravingDefault('thinBarlineThickness') * staffSpace;
    final thickThickness =
        metadata.getEngravingDefault('thickBarlineThickness') * staffSpace;
    final finalBarlineWidth =
        metadata.getGlyphWidth('barlineFinal') * staffSpace;
    final doubleBarlineWidth =
        metadata.getGlyphWidth('barlineDouble') * staffSpace;
    final connectorTopY = coordinates.first.getStaffLineY(5);
    final connectorBottomY = coordinates.last.getStaffLineY(1);

    void drawConnector({
      required double x,
      required double thickness,
    }) {
      final paint = Paint()
        ..color = theme.barlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness;
      canvas.drawLine(
        Offset(x, connectorTopY),
        Offset(x, connectorBottomY),
        paint,
      );
    }

    for (final barline in barlines) {
      if (!barline.x.isFinite) continue;

      final primaryCenterX = barline.x + (thinThickness * 0.5);
      drawConnector(x: primaryCenterX, thickness: thinThickness);

      if (barline.type == BarlineType.final_) {
        final secondaryCenterX =
            barline.x + finalBarlineWidth - (thickThickness * 0.5);
        drawConnector(x: secondaryCenterX, thickness: thickThickness);
      } else if (barline.type == BarlineType.double ||
          barline.type == BarlineType.lightLight) {
        final secondaryCenterX =
            barline.x + doubleBarlineWidth - (thinThickness * 0.5);
        drawConnector(x: secondaryCenterX, thickness: thinThickness);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ConnectedMultiStaffPainter oldDelegate) {
    return oldDelegate.staffSpace != staffSpace ||
        oldDelegate.theme != theme ||
        oldDelegate.barlines.length != barlines.length ||
        oldDelegate.elementsByStaff.length != elementsByStaff.length ||
        oldDelegate.labels.length != labels.length;
  }
}

class MultiStaffDemoApp extends StatelessWidget {
  const MultiStaffDemoApp({super.key});

  Staff _buildTrebleStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.treble));
    measure.add(KeySignature(0));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.quarter)));
    measure.add(Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const Duration(DurationType.quarter)));
    measure.add(Note(
        pitch: const Pitch(step: 'E', octave: 5),
        duration: const Duration(DurationType.quarter)));
    measure.add(Note(
        pitch: const Pitch(step: 'F', octave: 5),
        duration: const Duration(DurationType.quarter)));

    final measure2 = Measure();
    measure2.add(Note(
        pitch: const Pitch(step: 'E', octave: 5),
        duration: const Duration(DurationType.quarter)));
    measure2.add(Note(
        pitch: const Pitch(step: 'D', octave: 5),
        duration: const Duration(DurationType.quarter)));
    measure2.add(Note(
        pitch: const Pitch(step: 'C', octave: 5),
        duration: const Duration(DurationType.half)));

    staff.add(measure);
    staff.add(measure2);
    return staff;
  }

  Staff _buildBassStaff() {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: ClefType.bass));
    measure.add(KeySignature(0));
    measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Note(
        pitch: const Pitch(step: 'C', octave: 3),
        duration: const Duration(DurationType.whole)));

    final measure2 = Measure();
    measure2.add(Note(
        pitch: const Pitch(step: 'G', octave: 2),
        duration: const Duration(DurationType.half)));
    measure2.add(Note(
        pitch: const Pitch(step: 'C', octave: 3),
        duration: const Duration(DurationType.half)));

    staff.add(measure);
    staff.add(measure2);
    return staff;
  }

  Staff _buildSATBStaff({
    required ClefType clef,
    required List<Pitch> measure1,
    required List<Pitch> measure2,
    required List<Pitch> measure3,
  }) {
    final staff = Staff();

    final m1 = Measure();
    m1.add(Clef(clefType: clef));
    m1.add(KeySignature(0));
    m1.add(TimeSignature(numerator: 4, denominator: 4));
    m1.add(Note(
        pitch: measure1[0], duration: const Duration(DurationType.quarter)));
    m1.add(Note(
        pitch: measure1[1], duration: const Duration(DurationType.quarter)));
    m1.add(
        Note(pitch: measure1[2], duration: const Duration(DurationType.half)));

    final m2 = Measure();
    m2.add(Note(
        pitch: measure2[0], duration: const Duration(DurationType.quarter)));
    m2.add(Note(
        pitch: measure2[1], duration: const Duration(DurationType.quarter)));
    m2.add(Note(
        pitch: measure2[2], duration: const Duration(DurationType.quarter)));
    m2.add(Note(
        pitch: measure2[3], duration: const Duration(DurationType.quarter)));

    final m3 = Measure();
    m3.add(
        Note(pitch: measure3[0], duration: const Duration(DurationType.half)));
    m3.add(
        Note(pitch: measure3[1], duration: const Duration(DurationType.half)));

    staff.add(m1);
    staff.add(m2);
    staff.add(m3);
    return staff;
  }

  Staff _buildSopranoStaff() {
    return _buildSATBStaff(
      clef: ClefType.treble,
      measure1: const [
        Pitch(step: 'C', octave: 5),
        Pitch(step: 'B', octave: 4),
        Pitch(step: 'C', octave: 5),
      ],
      measure2: const [
        Pitch(step: 'C', octave: 5),
        Pitch(step: 'D', octave: 5),
        Pitch(step: 'D', octave: 5),
        Pitch(step: 'C', octave: 5),
      ],
      measure3: const [
        Pitch(step: 'B', octave: 4),
        Pitch(step: 'C', octave: 5),
      ],
    );
  }

  Staff _buildAltoStaff() {
    return _buildSATBStaff(
      clef: ClefType.treble,
      measure1: const [
        Pitch(step: 'E', octave: 4),
        Pitch(step: 'D', octave: 4),
        Pitch(step: 'E', octave: 4),
      ],
      measure2: const [
        Pitch(step: 'E', octave: 4),
        Pitch(step: 'F', octave: 4),
        Pitch(step: 'F', octave: 4),
        Pitch(step: 'E', octave: 4),
      ],
      measure3: const [
        Pitch(step: 'F', octave: 4),
        Pitch(step: 'E', octave: 4),
      ],
    );
  }

  Staff _buildTenorStaff() {
    return _buildSATBStaff(
      clef: ClefType.treble8vb,
      measure1: const [
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'G', octave: 4),
      ],
      measure2: const [
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'G', octave: 4),
      ],
      measure3: const [
        Pitch(step: 'G', octave: 4),
        Pitch(step: 'G', octave: 4),
      ],
    );
  }

  Staff _buildBassSATBStaff() {
    return _buildSATBStaff(
      clef: ClefType.bass,
      measure1: const [
        Pitch(step: 'C', octave: 3),
        Pitch(step: 'G', octave: 2),
        Pitch(step: 'C', octave: 3),
      ],
      measure2: const [
        Pitch(step: 'G', octave: 3),
        Pitch(step: 'G', octave: 3),
        Pitch(step: 'G', octave: 2),
        Pitch(step: 'G', octave: 2),
      ],
      measure3: const [
        Pitch(step: 'G', octave: 2),
        Pitch(step: 'C', octave: 3),
      ],
    );
  }

  Widget _buildGrandStaffSection() {
    return _buildSection(
      title: '🎹 Grand Staff (Piano)',
      description: 'Treble clef (right hand) + bass clef (left hand)',
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Colors.grey.shade400, width: 2),
              top: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: GrandStaffScore(
            trebleStaff: _buildTrebleStaff(),
            bassStaff: _buildBassStaff(),
          ),
        ),
      ],
    );
  }

  Widget _buildSATBSection() {
    final satbStaves = [
      LabeledStaff(label: 'S', staff: _buildSopranoStaff()),
      LabeledStaff(label: 'A', staff: _buildAltoStaff()),
      LabeledStaff(label: 'T', staff: _buildTenorStaff()),
      LabeledStaff(label: 'B', staff: _buildBassSATBStaff()),
    ];

    return _buildSection(
      title: 'SATB Choir',
      description:
          'Four staves aligned, tenor clef octave downwards and connected bars',
      children: [
        Container(
          height: 360,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Colors.grey.shade400, width: 2),
              top: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: ConnectedMultiStaffScore(
            staves: satbStaves,
            interStaffSpacing: 7.0,
          ),
        ),
      ],
    );
  }

  String _normalizeSectionTitle(String title) {
    if (title.contains('Grand Staff (Piano)')) {
      return 'Grand Staff (Piano)';
    }
    return title;
  }

  Widget _buildSection(
      {required String title,
      required String description,
      required List<Widget> children}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_normalizeSectionTitle(title),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, color: Colors.indigo.shade700),
                      const SizedBox(width: 8),
                      Text('About Multi-Staff',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade800,
                              fontSize: 16)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                        'Multi-staff notation uses several simultaneous staffs for different instruments or voices. The grand piano staff is the most common example.',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildGrandStaffSection(),
            _buildSATBSection(),
          ],
        ),
      ),
    );
  }
}
