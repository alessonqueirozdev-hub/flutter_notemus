// example/lib/examples/multi_staff_example.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

/// Example demonstrating multi-staff notation
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

    // Right hand melody: C D E F (quarter notes)
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

/// Widget principal para demonstração de multi-pauta
/// Renderiza duas pautas (clave de sol + clave de fá) com timeline compartilhada.
///
/// Esta implementação evita o desalinhamento de figuras e conecta visualmente as
/// barras de compasso entre as duas pautas, como no grand staff de piano.
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
              'Erro ao carregar metadados: ${snapshot.error}',
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

            return ClipRect(
              child: CustomPaint(
                size: Size(availableWidth, canvasHeight),
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
            );
          },
        );
      },
    );
  }

  _GrandStaffAlignedData _alignByMeasureBoundaries({
    required List<PositionedElement> trebleElements,
    required List<PositionedElement> bassElements,
  }) {
    final trebleTimeline = _buildTimeline(trebleElements);
    final bassTimeline = _buildTimeline(bassElements);

    final sharedAnchorsByKey = <String, _SharedTimelineAnchor>{};
    void mergeAnchors(List<_TimedElementData> timeline) {
      for (final item in timeline) {
        final key = _timeKey(item.time);
        final existing = sharedAnchorsByKey[key];
        if (existing == null) {
          sharedAnchorsByKey[key] = _SharedTimelineAnchor(
            key: key,
            time: item.time,
            x: item.positioned.position.dx,
            isBarline: item.isBarline,
            barlineType: item.barlineType,
          );
          continue;
        }

        final mergedX = math.max(existing.x, item.positioned.position.dx);
        final mergedIsBarline = existing.isBarline || item.isBarline;
        final mergedBarlineType = _preferBarlineType(
          existing.barlineType,
          item.barlineType,
        );

        sharedAnchorsByKey[key] = _SharedTimelineAnchor(
          key: key,
          time: existing.time,
          x: mergedX,
          isBarline: mergedIsBarline,
          barlineType: mergedBarlineType,
        );
      }
    }

    mergeAnchors(trebleTimeline);
    mergeAnchors(bassTimeline);

    final sharedAnchors = sharedAnchorsByKey.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    if (sharedAnchors.isEmpty) {
      return _GrandStaffAlignedData(
        trebleElements: trebleElements,
        bassElements: bassElements,
        sharedBarlines: const [],
      );
    }

    const minAnchorGap = 0.25;
    for (int i = 1; i < sharedAnchors.length; i++) {
      final previous = sharedAnchors[i - 1];
      final current = sharedAnchors[i];
      if (current.x <= previous.x + minAnchorGap) {
        sharedAnchors[i] = current.copyWith(x: previous.x + minAnchorGap);
      }
    }

    final maxAllowedX = math.min(
      _maxElementX(trebleElements),
      _maxElementX(bassElements),
    );
    final firstAnchorX = sharedAnchors.first.x;
    final lastAnchorX = sharedAnchors.last.x;

    if (lastAnchorX > maxAllowedX && lastAnchorX > firstAnchorX) {
      final oldSpan = lastAnchorX - firstAnchorX;
      final newSpan = math.max(1.0, maxAllowedX - firstAnchorX);
      final scale = newSpan / oldSpan;
      for (int i = 0; i < sharedAnchors.length; i++) {
        final anchor = sharedAnchors[i];
        sharedAnchors[i] = anchor.copyWith(
          x: firstAnchorX + ((anchor.x - firstAnchorX) * scale),
        );
      }
    }

    final sharedXByKey = <String, double>{
      for (final anchor in sharedAnchors) anchor.key: anchor.x,
    };

    final alignedTreble = _remapByTimeline(
      elements: trebleElements,
      timeline: trebleTimeline,
      sharedXByKey: sharedXByKey,
    );
    final alignedBass = _remapByTimeline(
      elements: bassElements,
      timeline: bassTimeline,
      sharedXByKey: sharedXByKey,
    );

    final sharedBarlines = sharedAnchors
        .where((anchor) => anchor.isBarline)
        .map(
          (anchor) => _AlignedBarline(
            x: anchor.x,
            type: anchor.barlineType ?? BarlineType.single,
          ),
        )
        .toList();

    return _GrandStaffAlignedData(
      trebleElements: alignedTreble,
      bassElements: alignedBass,
      sharedBarlines: sharedBarlines,
    );
  }

  List<_TimedElementData> _buildTimeline(List<PositionedElement> elements) {
    final timeline = <_TimedElementData>[];
    double measureStartTime = 0.0;
    double elapsedInMeasure = 0.0;
    double currentMeasureDuration = 1.0;

    for (int i = 0; i < elements.length; i++) {
      final positioned = elements[i];
      final element = positioned.element;

      if (element is TimeSignature) {
        currentMeasureDuration = element.measureValue;
      }

      final duration = _elementDuration(element);
      if (duration > 0.0) {
        final onsetTime = measureStartTime + elapsedInMeasure;
        timeline.add(
          _TimedElementData(
            index: i,
            positioned: positioned,
            time: onsetTime,
            isBarline: false,
          ),
        );
        elapsedInMeasure += duration;
      }

      if (element is Barline) {
        final boundaryTime = measureStartTime +
            (elapsedInMeasure > 0.0
                ? elapsedInMeasure
                : currentMeasureDuration);
        timeline.add(
          _TimedElementData(
            index: i,
            positioned: positioned,
            time: boundaryTime,
            isBarline: true,
            barlineType: element.type,
          ),
        );
        measureStartTime = boundaryTime;
        elapsedInMeasure = 0.0;
      }
    }

    return timeline;
  }

  List<PositionedElement> _remapByTimeline({
    required List<PositionedElement> elements,
    required List<_TimedElementData> timeline,
    required Map<String, double> sharedXByKey,
  }) {
    if (timeline.isEmpty) return elements;

    final xByIndex = <int, double>{};
    for (final item in timeline) {
      final mappedX = sharedXByKey[_timeKey(item.time)];
      if (mappedX != null) {
        xByIndex[item.index] = mappedX;
      }
    }

    if (xByIndex.isEmpty) return elements;

    final remapped = <PositionedElement>[];
    for (int i = 0; i < elements.length; i++) {
      final positioned = elements[i];
      final mappedX = xByIndex[i];
      if (mappedX == null) {
        remapped.add(positioned);
        continue;
      }

      remapped.add(
        PositionedElement(
          positioned.element,
          Offset(mappedX, positioned.position.dy),
          system: positioned.system,
          voiceNumber: positioned.voiceNumber,
        ),
      );
    }

    return remapped;
  }

  String _timeKey(double time) => time.toStringAsFixed(6);

  double _maxElementX(List<PositionedElement> elements) {
    return elements
        .map((element) => element.position.dx)
        .fold<double>(double.negativeInfinity, math.max);
  }

  double _elementDuration(MusicalElement element) {
    if (element is Note) return element.duration.realValue;
    if (element is Rest) return element.duration.realValue;
    if (element is Chord) return element.duration.realValue;
    return 0.0;
  }

  BarlineType? _preferBarlineType(BarlineType? a, BarlineType? b) {
    if (a == BarlineType.final_ || b == BarlineType.final_) {
      return BarlineType.final_;
    }
    return b ?? a;
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
    );
    bassRenderer.renderStaff(
      canvas,
      bassElements,
      size,
      layoutEngine: bassLayout,
    );

    final thinThickness =
        metadata.getEngravingDefault('thinBarlineThickness') * staffSpace;
    final thickThickness =
        metadata.getEngravingDefault('thickBarlineThickness') * staffSpace;
    final finalBarlineWidth =
        metadata.getGlyphWidth('barlineFinal') * staffSpace;
    final doubleBarlineWidth =
        metadata.getGlyphWidth('barlineDouble') * staffSpace;
    final connectorTopY = topCoordinates.getStaffLineY(5);
    final connectorBottomY = bottomCoordinates.getStaffLineY(1);

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
  bool shouldRepaint(covariant _GrandStaffPainter oldDelegate) {
    return oldDelegate.trebleElements.length != trebleElements.length ||
        oldDelegate.bassElements.length != bassElements.length ||
        oldDelegate.barlines.length != barlines.length ||
        oldDelegate.staffSpace != staffSpace ||
        oldDelegate.theme != theme;
  }
}

class _TimedElementData {
  final int index;
  final PositionedElement positioned;
  final double time;
  final bool isBarline;
  final BarlineType? barlineType;

  const _TimedElementData({
    required this.index,
    required this.positioned,
    required this.time,
    required this.isBarline,
    this.barlineType,
  });
}

class _SharedTimelineAnchor {
  final String key;
  final double time;
  final double x;
  final bool isBarline;
  final BarlineType? barlineType;

  const _SharedTimelineAnchor({
    required this.key,
    required this.time,
    required this.x,
    required this.isBarline,
    this.barlineType,
  });

  _SharedTimelineAnchor copyWith({
    double? x,
    bool? isBarline,
    BarlineType? barlineType,
  }) {
    return _SharedTimelineAnchor(
      key: key,
      time: time,
      x: x ?? this.x,
      isBarline: isBarline ?? this.isBarline,
      barlineType: barlineType ?? this.barlineType,
    );
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

  Staff _buildSATBStaff(ClefType clef, String step, int octave,
      {bool isBottom = false}) {
    final staff = Staff();
    final measure = Measure();
    measure.add(Clef(clefType: clef));
    measure.add(KeySignature(0));
    if (!isBottom) measure.add(TimeSignature(numerator: 4, denominator: 4));
    measure.add(Note(
        pitch: Pitch(step: step, octave: octave),
        duration: const Duration(DurationType.quarter)));
    measure.add(Note(
        pitch: Pitch(step: step == 'C' ? 'D' : 'B', octave: octave),
        duration: const Duration(DurationType.quarter)));
    measure.add(Note(
        pitch: Pitch(step: step, octave: octave),
        duration: const Duration(DurationType.half)));
    staff.add(measure);
    return staff;
  }

  Widget _buildGrandStaffSection() {
    return _buildSection(
      title: '🎹 Grand Staff (Piano)',
      description: 'Clave de sol (mão direita) + clave de fá (mão esquerda)',
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
    return _buildSection(
      title: '🎤 Coral SATB',
      description: 'Soprano, Contralto, Tenor e Baixo em pautas separadas',
      children: [
        _buildStaffRow('S', _buildSATBStaff(ClefType.treble, 'E', 5)),
        _buildStaffRow('A', _buildSATBStaff(ClefType.treble, 'C', 5)),
        _buildStaffRow('T', _buildSATBStaff(ClefType.treble, 'A', 4)),
        _buildStaffRow(
            'B', _buildSATBStaff(ClefType.bass, 'C', 3, isBottom: true)),
      ],
    );
  }

  Widget _buildStaffRow(String label, Staff staff) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Container(
            height: 90,
            color: Colors.white,
            child: MusicScore(staff: staff),
          ),
        ),
      ],
    );
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
            Text(title,
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
                      Text('Sobre Multi-Pauta',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade800,
                              fontSize: 16)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                        'Notação multi-pauta usa várias pautas simultâneas para diferentes instrumentos ou vozes. O grand staff do piano é o exemplo mais comum.',
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
