// lib/src/rendering/renderers/slur_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../engraving/engraving_rules.dart';
import '../../layout/layout_engine.dart';
import '../../layout/skyline_calculator.dart';
import '../../layout/slur_calculator.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../grace_note_geometry.dart';
import '../staff_position_calculator.dart';
import 'chord_renderer.dart';

class SlurRenderer {
  final EngravingRules rules;
  final SmuflMetadata metadata;
  final double staffSpace;
  final double staffBaselineY;
  final SkyBottomLineCalculator? skylineCalculator;

  SlurRenderer({
    required this.staffSpace,
    required this.metadata,
    required this.staffBaselineY,
    EngravingRules? rules,
    this.skylineCalculator,
  }) : rules = rules ?? EngravingRules();

  _NoteheadMetrics _resolveNoteheadMetrics(
    Offset notePos,
    Note note, {
    double scaleFactor = 1.0,
  }) {
    final glyphName = note.duration.type.glyphName;
    final glyphInfo = metadata.getGlyphInfo(glyphName);
    final bbox = glyphInfo?.boundingBox;

    final leftEdge =
        notePos.dx + ((bbox?.bBoxSwX ?? 0.0) * staffSpace * scaleFactor);
    final rightEdge =
        notePos.dx +
        (((bbox?.bBoxNeX ?? metadata.getGlyphWidth(glyphName)) * staffSpace) *
            scaleFactor);
    final width = math.max(
      rightEdge - leftEdge,
      staffSpace * 0.7 * scaleFactor,
    );
    final halfHeight = math.max(
      (((bbox?.height ?? 0.88) * staffSpace * scaleFactor) * 0.5),
      staffSpace * 0.22 * scaleFactor,
    );

    Offset? toAbsoluteAnchor(String anchorName) {
      final anchor = metadata.getGlyphAnchor(glyphName, anchorName);
      if (anchor == null) return null;
      return Offset(
        notePos.dx + (anchor.dx * staffSpace * scaleFactor),
        notePos.dy - (anchor.dy * staffSpace * scaleFactor),
      );
    }

    return _NoteheadMetrics(
      leftEdge: leftEdge,
      rightEdge: rightEdge,
      width: width,
      halfHeight: halfHeight,
      stemUpAnchor: toAbsoluteAnchor('stemUpSE'),
      stemDownAnchor: toAbsoluteAnchor('stemDownNW'),
    );
  }

  void renderSlurs({
    required Canvas canvas,
    required Map<int, List<int>> slurGroups,
    required List<PositionedElement> positions,
    required Clef currentClef,
    Color color = Colors.black,
  }) {
    for (final group in slurGroups.values) {
      if (group.length < 2) {
        continue;
      }

      final startElement = positions[group.first];
      final endElement = positions[group.last];

      // Fix: skip grace-note slurs — now rendered by the grace-note renderer
      // automaticamente pelo OrnamentRenderer._renderGraceSlur
      if (_hasGraceOrnamentOnElement(startElement.element)) {
        continue;
      }

      final tempStart = _pickNoteFromElement(
        startElement,
        above: true,
        clef: currentClef,
        preferredSlurType: SlurType.start,
      );
      final tempEnd = _pickNoteFromElement(
        endElement,
        above: true,
        clef: currentClef,
        preferredSlurType: SlurType.end,
      );
      if (tempStart == null || tempEnd == null) {
        continue;
      }

      final direction = _calculateSlurDirection(tempStart, tempEnd);
      final slurAbove = direction == SlurDirection.up;

      final startNote = _pickNoteFromElement(
        startElement,
        above: slurAbove,
        clef: currentClef,
        preferredSlurType: SlurType.start,
      )!;
      final endNote = _pickNoteFromElement(
        endElement,
        above: slurAbove,
        clef: currentClef,
        preferredSlurType: SlurType.end,
      )!;
      final isGraceSlur = false; // Grace slurs handled by OrnamentRenderer

      final startPoint = _calculateSlurEndpoint(
        startNote.noteOrigin,
        startNote.note,
        currentClef,
        isStart: true,
        above: slurAbove,
        isGraceSlur: isGraceSlur,
        stemUp: startNote.stemUp,
      );

      final endPoint = _calculateSlurEndpoint(
        endNote.noteOrigin,
        endNote.note,
        currentClef,
        isStart: false,
        above: slurAbove,
        isGraceSlur: isGraceSlur,
        stemUp: endNote.stemUp,
      );

      final calculator = SlurCalculator(
        rules: rules,
        skylineCalculator: skylineCalculator,
      );

      final curve = calculator.calculateSlur(
        startPoint: startPoint,
        endPoint: endPoint,
        placement: slurAbove,
        staffSpace: staffSpace,
      );

      _drawVariableThicknessCurve(canvas, curve, color, isSlur: true);
    }
  }

  void renderTies({
    required Canvas canvas,
    required Map<int, List<int>> tieGroups,
    required List<PositionedElement> positions,
    required Clef currentClef,
    Color color = Colors.black,
  }) {
    for (final group in tieGroups.values) {
      final startElement = positions[group.first];
      final endElement = positions[group.last];
      final tiePairs = _resolveTiePairs(startElement, endElement, currentClef);

      for (final pair in tiePairs) {
        final tieAbove = !pair.start.stemUp;
        final (startPoint, endPoint) = _calculateTieEndpoints(
          pair.start.noteOrigin,
          pair.start.note,
          pair.end.noteOrigin,
          pair.end.note,
          tieAbove: tieAbove,
          clef: currentClef,
          startStemUp: pair.start.stemUp,
          endStemUp: pair.end.stemUp,
        );

        final calculator = SlurCalculator(rules: rules);
        final curve = calculator.calculateTie(
          startPoint: startPoint,
          endPoint: endPoint,
          placement: tieAbove,
          staffSpace: staffSpace,
        );

        _drawVariableThicknessCurve(canvas, curve, color, isSlur: false);
      }
    }
  }

  _ElementNotePlacement? _pickNoteFromElement(
    PositionedElement element, {
    required bool above,
    required Clef clef,
    SlurType? preferredSlurType,
  }) {
    final placements = _resolveElementPlacements(element, clef);
    if (placements.isEmpty) {
      return null;
    }

    final preferredPlacements = preferredSlurType == null
        ? placements
        : placements
              .where(
                (placement) =>
                    placement.note.slur == preferredSlurType ||
                    placement.note.slur == SlurType.inner,
              )
              .toList();
    final candidates = preferredPlacements.isNotEmpty
        ? preferredPlacements
        : placements;

    candidates.sort(
      (left, right) => right.staffPosition.compareTo(left.staffPosition),
    );
    return above ? candidates.first : candidates.last;
  }

  List<_ElementNotePlacement> _resolveElementPlacements(
    PositionedElement element,
    Clef clef,
  ) {
    final placements = <_ElementNotePlacement>[];
    if (element.element is Note) {
      final note = element.element as Note;
      final staffPosition = StaffPositionCalculator.calculate(note.pitch, clef);
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        staffBaselineY,
      );
      placements.add(
        _ElementNotePlacement(
          note: note,
          noteOrigin: Offset(element.position.dx, noteY),
          staffPosition: staffPosition,
          stemUp: _resolveStemUp(note, staffPosition, element.voiceNumber),
        ),
      );
      return placements;
    }

    if (element.element is! Chord) {
      return placements;
    }

    final chord = element.element as Chord;
    final sortedNotes = [...chord.notes]
      ..sort(
        (left, right) => StaffPositionCalculator.calculate(
          right.pitch,
          clef,
        ).compareTo(StaffPositionCalculator.calculate(left.pitch, clef)),
      );
    final positions = sortedNotes
        .map((note) => StaffPositionCalculator.calculate(note.pitch, clef))
        .toList();
    final stemUp = ChordRenderer.resolveStemDirection(
      chord: chord,
      positions: positions,
      voiceNumber: element.voiceNumber,
    );
    final noteheadBox = metadata
        .getGlyphInfo(chord.duration.type.glyphName)
        ?.boundingBox;
    final noteheadWidth =
        ((noteheadBox?.width ?? metadata.getGlyphWidth('noteheadBlack')).clamp(
          0.7,
          2.2,
        )).toDouble();
    final clusterOffset = noteheadWidth * staffSpace * 1.04;
    final clusterOffsets = ChordRenderer.calculateClusterOffsets(
      positions: positions,
      stemUp: stemUp,
      clusterOffset: clusterOffset,
    );

    for (int index = 0; index < sortedNotes.length; index++) {
      final staffPosition = positions[index];
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        staffBaselineY,
      );
      placements.add(
        _ElementNotePlacement(
          note: sortedNotes[index],
          noteOrigin: Offset(
            element.position.dx + clusterOffsets[index],
            noteY,
          ),
          staffPosition: staffPosition,
          stemUp: stemUp,
        ),
      );
    }

    return placements;
  }

  List<_TiePair> _resolveTiePairs(
    PositionedElement startElement,
    PositionedElement endElement,
    Clef clef,
  ) {
    final startCandidates = _resolveElementPlacements(startElement, clef)
        .where(
          (placement) =>
              placement.note.tie == TieType.start ||
              placement.note.tie == TieType.inner,
        )
        .toList();
    final endCandidates = _resolveElementPlacements(endElement, clef)
        .where(
          (placement) =>
              placement.note.tie == TieType.end ||
              placement.note.tie == TieType.inner,
        )
        .toList();

    if (startCandidates.isEmpty || endCandidates.isEmpty) {
      return const [];
    }

    final pairs = <_TiePair>[];
    final claimedEnds = <int>{};
    for (final start in startCandidates) {
      for (int index = 0; index < endCandidates.length; index++) {
        if (claimedEnds.contains(index)) {
          continue;
        }

        final end = endCandidates[index];
        if (!_sameWrittenPitch(start.note, end.note)) {
          continue;
        }

        pairs.add(_TiePair(start: start, end: end));
        claimedEnds.add(index);
        break;
      }
    }

    return pairs;
  }

  bool _sameWrittenPitch(Note left, Note right) {
    return left.pitch.step == right.pitch.step &&
        left.pitch.octave == right.pitch.octave &&
        left.pitch.alter == right.pitch.alter;
  }

  SlurDirection _calculateSlurDirection(
    _ElementNotePlacement startNote,
    _ElementNotePlacement endNote,
  ) {
    if (startNote.stemUp == endNote.stemUp) {
      return startNote.stemUp ? SlurDirection.down : SlurDirection.up;
    }

    final avgPos = (startNote.staffPosition + endNote.staffPosition) / 2;
    return avgPos > 0 ? SlurDirection.up : SlurDirection.down;
  }

  Offset _calculateSlurEndpoint(
    Offset notePos,
    Note note,
    Clef clef, {
    required bool isStart,
    required bool above,
    bool isGraceSlur = false,
    bool? stemUp,
  }) {
    final metrics = _resolveNoteheadMetrics(notePos, note);
    final effectiveGraceSlur = isGraceSlur || hasGraceOrnament(note);

    final staffPos = StaffPositionCalculator.calculate(note.pitch, clef);
    final noteY = StaffPositionCalculator.toPixelY(
      staffPos,
      staffSpace,
      staffBaselineY,
    );

    if (isStart && effectiveGraceSlur) {
      return graceSlurStartPointForNote(
        note: note,
        notePos: Offset(notePos.dx, noteY),
        above: above,
        staffSpace: staffSpace,
        glyphSize: staffSpace * 4.0,
        metadata: metadata,
      );
    }

    final resolvedStemUp = stemUp ?? _resolveStemUp(note, staffPos);

    // Slurs anchor to the notehead surface, not the stem.
    final noteheadClearance = math.max(
      metrics.halfHeight + staffSpace * 0.15,
      staffSpace * 0.4,
    );
    final yOffset = noteheadClearance * (above ? -1 : 1);
    final x = _resolveStemSafeAnchorX(
      metrics,
      stemUp: resolvedStemUp,
      above: above,
      isStart: isStart,
    );
    return Offset(x, noteY + yOffset);
  }

  (Offset, Offset) _calculateTieEndpoints(
    Offset startPos,
    Note startNote,
    Offset endPos,
    Note endNote, {
    required bool tieAbove,
    required Clef clef,
    bool? startStemUp,
    bool? endStemUp,
  }) {
    final startMetrics = _resolveNoteheadMetrics(startPos, startNote);
    final endMetrics = _resolveNoteheadMetrics(endPos, endNote);

    // Compute ACTUAL notehead Y from pitch (positions carry system-baseline Y).
    final startStaffPos = StaffPositionCalculator.calculate(
      startNote.pitch,
      clef,
    );
    final endStaffPos = StaffPositionCalculator.calculate(endNote.pitch, clef);
    final startNoteY = StaffPositionCalculator.toPixelY(
      startStaffPos,
      staffSpace,
      staffBaselineY,
    );
    final endNoteY = StaffPositionCalculator.toPixelY(
      endStaffPos,
      staffSpace,
      staffBaselineY,
    );

    // Tie sits just outside the notehead surface (Behind Bars: 0.25 SS clearance).
    final clearance = math.max(
      math.max(startMetrics.halfHeight, endMetrics.halfHeight) +
          staffSpace * 0.1,
      staffSpace * 0.35,
    );

    return (
      Offset(
        _resolveStemSafeAnchorX(
          startMetrics,
          stemUp: startStemUp ?? _resolveStemUp(startNote, startStaffPos),
          above: tieAbove,
          isStart: true,
        ),
        startNoteY + (tieAbove ? -clearance : clearance),
      ),
      Offset(
        _resolveStemSafeAnchorX(
          endMetrics,
          stemUp: endStemUp ?? _resolveStemUp(endNote, endStaffPos),
          above: tieAbove,
          isStart: false,
        ),
        endNoteY + (tieAbove ? -clearance : clearance),
      ),
    );
  }

  double _resolveStemSafeAnchorX(
    _NoteheadMetrics metrics, {
    required bool stemUp,
    required bool above,
    required bool isStart,
  }) {
    final centerX = (metrics.leftEdge + metrics.rightEdge) * 0.5;
    final stemSafeInset = math.min(metrics.width * 0.18, staffSpace * 0.22);
    final directionalInset = math.min(metrics.width * 0.08, staffSpace * 0.12);

    if (above && !stemUp) {
      return centerX + (isStart ? stemSafeInset : directionalInset);
    }

    if (!above && stemUp) {
      return centerX - (isStart ? directionalInset : stemSafeInset);
    }

    final edgeInset = math.min(metrics.width * 0.16, staffSpace * 0.14);
    return isStart
        ? metrics.rightEdge - edgeInset
        : metrics.leftEdge + edgeInset;
  }

  bool _resolveStemUp(Note note, int staffPosition, [int? voiceNumber]) {
    final effectiveVoice = voiceNumber ?? note.voice;
    if (effectiveVoice != null) {
      return effectiveVoice.isOdd;
    }
    return staffPosition <= 0;
  }

  Offset calculateSlurEndpointForTesting(
    Offset notePos,
    Note note,
    Clef clef, {
    required bool isStart,
    required bool above,
    bool isGraceSlur = false,
    bool? stemUp,
  }) {
    return _calculateSlurEndpoint(
      notePos,
      note,
      clef,
      isStart: isStart,
      above: above,
      isGraceSlur: isGraceSlur,
      stemUp: stemUp,
    );
  }

  (Offset, Offset) calculateTieEndpointsForTesting(
    Offset startPos,
    Note startNote,
    Offset endPos,
    Note endNote, {
    required bool tieAbove,
    required Clef clef,
    bool? startStemUp,
    bool? endStemUp,
  }) {
    return _calculateTieEndpoints(
      startPos,
      startNote,
      endPos,
      endNote,
      tieAbove: tieAbove,
      clef: clef,
      startStemUp: startStemUp,
      endStemUp: endStemUp,
    );
  }

  bool _hasGraceOrnamentOnElement(dynamic element) {
    if (element is Note) {
      return hasGraceOrnament(element);
    }
    if (element is Chord) {
      return hasGraceOrnamentInOrnaments(element.ornaments);
    }
    return false;
  }

  void _drawVariableThicknessCurve(
    Canvas canvas,
    CubicBezierCurve curve,
    Color color, {
    required bool isSlur,
  }) {
    final endpointThickness = isSlur
        ? metadata.getEngravingDefaultValue('slurEndpointThickness') ?? 0.1
        : metadata.getEngravingDefaultValue('tieEndpointThickness') ?? 0.1;

    final midpointThickness = isSlur
        ? metadata.getEngravingDefaultValue('slurMidpointThickness') ?? 0.22
        : metadata.getEngravingDefaultValue('tieMidpointThickness') ?? 0.22;

    final endpointThicknessPx = endpointThickness * staffSpace;
    final midpointThicknessPx = midpointThickness * staffSpace;

    final pathTop = Path();
    final pathBottom = Path();

    const numPoints = 50;
    final points = <Offset>[];
    final thicknesses = <double>[];

    for (int i = 0; i <= numPoints; i++) {
      final t = i / numPoints;
      final point = curve.pointAt(t);
      points.add(point);

      final tCentered = 2 * t - 1;
      final factor = 1 - tCentered * tCentered;
      final thickness =
          endpointThicknessPx +
          (midpointThicknessPx - endpointThicknessPx) * factor;
      thicknesses.add(thickness);
    }

    for (int i = 0; i <= numPoints; i++) {
      final point = points[i];
      final thickness = thicknesses[i];
      final t = i / numPoints;
      final tangent = curve.derivativeAt(t);
      final tangentAngle = math.atan2(tangent.dy, tangent.dx);

      final perpAngle = tangentAngle + math.pi / 2;
      final perpDx = math.cos(perpAngle) * thickness / 2;
      final perpDy = math.sin(perpAngle) * thickness / 2;

      final topPoint = Offset(point.dx + perpDx, point.dy + perpDy);
      final bottomPoint = Offset(point.dx - perpDx, point.dy - perpDy);

      if (i == 0) {
        pathTop.moveTo(topPoint.dx, topPoint.dy);
        pathBottom.moveTo(bottomPoint.dx, bottomPoint.dy);
      } else {
        pathTop.lineTo(topPoint.dx, topPoint.dy);
        pathBottom.lineTo(bottomPoint.dx, bottomPoint.dy);
      }
    }

    final closedPath = Path()..addPath(pathTop, Offset.zero);

    for (int i = numPoints; i >= 0; i--) {
      final t = i / numPoints;
      final point = curve.pointAt(t);
      final thickness = thicknesses[i];
      final tangent = curve.derivativeAt(t);
      final tangentAngle = math.atan2(tangent.dy, tangent.dx);
      final perpAngle = tangentAngle + math.pi / 2;
      final perpDx = math.cos(perpAngle) * thickness / 2;
      final perpDy = math.sin(perpAngle) * thickness / 2;
      final bottomPoint = Offset(point.dx - perpDx, point.dy - perpDy);
      closedPath.lineTo(bottomPoint.dx, bottomPoint.dy);
    }

    closedPath.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(closedPath, paint);
  }
}

class _NoteheadMetrics {
  final double leftEdge;
  final double rightEdge;
  final double width;
  final double halfHeight;
  final Offset? stemUpAnchor;
  final Offset? stemDownAnchor;

  const _NoteheadMetrics({
    required this.leftEdge,
    required this.rightEdge,
    required this.width,
    required this.halfHeight,
    required this.stemUpAnchor,
    required this.stemDownAnchor,
  });
}

class _ElementNotePlacement {
  final Note note;
  final Offset noteOrigin;
  final int staffPosition;
  final bool stemUp;

  const _ElementNotePlacement({
    required this.note,
    required this.noteOrigin,
    required this.staffPosition,
    required this.stemUp,
  });
}

class _TiePair {
  final _ElementNotePlacement start;
  final _ElementNotePlacement end;

  const _TiePair({required this.start, required this.end});
}
