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
    final trebleBoundaries = _extractMeasureBoundaries(trebleElements);
    final bassBoundaries = _extractMeasureBoundaries(bassElements);
    final trebleBarlines = _extractBarlines(trebleElements);
    final bassBarlines = _extractBarlines(bassElements);

    final segmentCount = math.max(
      1,
      math.min(trebleBoundaries.length, bassBoundaries.length) - 1,
    );
    final trebleSourceBoundaries =
        trebleBoundaries.take(segmentCount + 1).toList();
    final bassSourceBoundaries = bassBoundaries.take(segmentCount + 1).toList();

    final trebleStart = trebleSourceBoundaries.first;
    final bassStart = bassSourceBoundaries.first;
    final trebleEnd = trebleSourceBoundaries.last;
    final bassEnd = bassSourceBoundaries.last;

    final sharedStart = math.max(trebleStart, bassStart);
    double sharedEnd = math.min(trebleEnd, bassEnd);
    if (sharedEnd <= sharedStart) {
      sharedEnd = math.max(trebleEnd, bassEnd);
    }

    final sharedBoundaries = <double>[sharedStart];
    if (segmentCount > 1) {
      for (int i = 1; i < segmentCount; i++) {
        final trebleProgress = _safeProgress(
          value: trebleSourceBoundaries[i],
          start: trebleStart,
          end: trebleEnd,
        );
        final bassProgress = _safeProgress(
          value: bassSourceBoundaries[i],
          start: bassStart,
          end: bassEnd,
        );
        final targetProgress = math.max(trebleProgress, bassProgress);
        var targetX =
            sharedStart + ((sharedEnd - sharedStart) * targetProgress);
        if (targetX <= sharedBoundaries.last + 0.01) {
          targetX = sharedBoundaries.last + 0.01;
        }
        sharedBoundaries.add(targetX);
      }
    }
    sharedBoundaries.add(sharedEnd);

    final treblePrefixStart = _minElementX(trebleElements);
    final bassPrefixStart = _minElementX(bassElements);
    final sharedPrefixStart = math.max(treblePrefixStart, bassPrefixStart);

    final alignedTreble = _remapElementsX(
      elements: trebleElements,
      prefixStart: treblePrefixStart,
      targetPrefixStart: sharedPrefixStart,
      originalBoundaries: trebleSourceBoundaries,
      targetBoundaries: sharedBoundaries,
    );
    final alignedBass = _remapElementsX(
      elements: bassElements,
      prefixStart: bassPrefixStart,
      targetPrefixStart: sharedPrefixStart,
      originalBoundaries: bassSourceBoundaries,
      targetBoundaries: sharedBoundaries,
    );
    final alignedSystemElements = _alignTimeSignatures(
      trebleElements: alignedTreble,
      bassElements: alignedBass,
      firstBoundaryX: sharedBoundaries.first,
    );

    final sharedBarlines = <_AlignedBarline>[];
    for (int i = 1; i < sharedBoundaries.length; i++) {
      final barlineIndex = i - 1;
      final trebleType = barlineIndex < trebleBarlines.length
          ? trebleBarlines[barlineIndex].type
          : null;
      final bassType = barlineIndex < bassBarlines.length
          ? bassBarlines[barlineIndex].type
          : null;
      sharedBarlines.add(
        _AlignedBarline(
          x: sharedBoundaries[i],
          type: _preferBarlineType(trebleType, bassType),
        ),
      );
    }

    return _GrandStaffAlignedData(
      trebleElements: alignedSystemElements.treble,
      bassElements: alignedSystemElements.bass,
      sharedBarlines: sharedBarlines,
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
    final maxAllowedX = firstBoundaryX - (widget.staffSpace * 0.5);

    for (int i = 0; i < pairCount; i++) {
      final trebleIndex = trebleIndices[i];
      final bassIndex = bassIndices[i];
      final desiredX = math.max(
        adjustedTreble[trebleIndex].position.dx,
        adjustedBass[bassIndex].position.dx,
      );
      final alignedX = math.min(desiredX, maxAllowedX);
      adjustedTreble[trebleIndex] =
          _withX(adjustedTreble[trebleIndex], alignedX);
      adjustedBass[bassIndex] = _withX(adjustedBass[bassIndex], alignedX);
    }

    return (treble: adjustedTreble, bass: adjustedBass);
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
