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

class SlurRenderer {
  final EngravingRules rules;
  final SmuflMetadata metadata;
  final double staffSpace;
  final SkyBottomLineCalculator? skylineCalculator;

  SlurRenderer({
    required this.staffSpace,
    required this.metadata,
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

      final tempStart = _pickNoteFromElement(
        startElement.element,
        above: true,
        clef: currentClef,
      );
      final tempEnd = _pickNoteFromElement(
        endElement.element,
        above: true,
        clef: currentClef,
      );
      if (tempStart == null || tempEnd == null) {
        continue;
      }

      final direction = _calculateSlurDirection(
        tempStart,
        tempEnd,
        currentClef,
      );
      final slurAbove = direction == SlurDirection.up;

      final startNote = _pickNoteFromElement(
        startElement.element,
        above: slurAbove,
        clef: currentClef,
      )!;
      final endNote = _pickNoteFromElement(
        endElement.element,
        above: slurAbove,
        clef: currentClef,
      )!;
      final isGraceSlur = _hasGraceOrnamentOnElement(startElement.element);

      final startPoint = _calculateSlurEndpoint(
        startElement.position,
        startNote,
        currentClef,
        isStart: true,
        above: slurAbove,
        isGraceSlur: isGraceSlur,
      );

      final endPoint = _calculateSlurEndpoint(
        endElement.position,
        endNote,
        currentClef,
        isStart: false,
        above: slurAbove,
        isGraceSlur: isGraceSlur,
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

      if (startElement.element is! Note || endElement.element is! Note) {
        continue;
      }

      final startNote = startElement.element as Note;
      final staffPos = StaffPositionCalculator.calculate(
        startNote.pitch,
        currentClef,
      );
      final tieAbove = staffPos > 0;
      final endNote = endElement.element as Note;

      final (startPoint, endPoint) = _calculateTieEndpoints(
        startElement.position,
        startNote,
        endElement.position,
        endNote,
        tieAbove: tieAbove,
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

  Note? _pickNoteFromElement(
    dynamic element, {
    required bool above,
    required Clef clef,
  }) {
    if (element is Note) {
      return element;
    }
    if (element is Chord) {
      final sorted = [...element.notes]
        ..sort(
          (a, b) => StaffPositionCalculator.calculate(
            b.pitch,
            clef,
          ).compareTo(StaffPositionCalculator.calculate(a.pitch, clef)),
        );
      return above ? sorted.first : sorted.last;
    }
    return null;
  }

  SlurDirection _calculateSlurDirection(
    Note startNote,
    Note endNote,
    Clef clef,
  ) {
    final startStaffPos = StaffPositionCalculator.calculate(
      startNote.pitch,
      clef,
    );
    final endStaffPos = StaffPositionCalculator.calculate(endNote.pitch, clef);
    final avgPos = (startStaffPos + endStaffPos) / 2;
    return avgPos > 0 ? SlurDirection.down : SlurDirection.up;
  }

  Offset _calculateSlurEndpoint(
    Offset notePos,
    Note note,
    Clef clef, {
    required bool isStart,
    required bool above,
    bool isGraceSlur = false,
  }) {
    final metrics = _resolveNoteheadMetrics(notePos, note);
    final noteY = notePos.dy;
    final effectiveGraceSlur = isGraceSlur || hasGraceOrnament(note);

    if (isStart && effectiveGraceSlur) {
      return graceSlurStartPointForNote(
        note: note,
        notePos: notePos,
        above: above,
        staffSpace: staffSpace,
        glyphSize: staffSpace * 4.0,
        metadata: metadata,
      );
    }

    final staffPos = StaffPositionCalculator.calculate(note.pitch, clef);
    final stemUp = staffPos <= 0;
    final noteClearance = math.max(
      metrics.halfHeight * 0.28,
      staffSpace * 0.14,
    );
    final stemLength =
        (metadata.getEngravingDefaultValue('stemLength') ?? 3.5) * staffSpace;
    final clearanceFromStem = staffSpace * 0.08;

    double yOffset;
    if (effectiveGraceSlur && !isStart) {
      yOffset = noteClearance * (above ? -1 : 1);
    } else if (above && stemUp) {
      yOffset = -(stemLength + clearanceFromStem);
    } else if (!above && !stemUp) {
      yOffset = stemLength + clearanceFromStem;
    } else {
      yOffset = noteClearance * (above ? -1 : 1);
    }

    if (above && stemUp) {
      final stemAnchor =
          metrics.stemUpAnchor ?? Offset(metrics.rightEdge, noteY);
      return Offset(stemAnchor.dx + (staffSpace * 0.04), noteY + yOffset);
    }

    if (!above && !stemUp) {
      final stemAnchor =
          metrics.stemDownAnchor ?? Offset(metrics.leftEdge, noteY);
      return Offset(stemAnchor.dx - (staffSpace * 0.04), noteY + yOffset);
    }

    final edgeInset = math.min(metrics.width * 0.16, staffSpace * 0.14);
    final x = isStart
        ? metrics.rightEdge - edgeInset
        : metrics.leftEdge + edgeInset;

    return Offset(x, noteY + yOffset);
  }

  (Offset, Offset) _calculateTieEndpoints(
    Offset startPos,
    Note startNote,
    Offset endPos,
    Note endNote, {
    required bool tieAbove,
  }) {
    final startMetrics = _resolveNoteheadMetrics(startPos, startNote);
    final endMetrics = _resolveNoteheadMetrics(endPos, endNote);
    final clearance = math.max(
      math.max(startMetrics.halfHeight, endMetrics.halfHeight) * 0.55,
      staffSpace * 0.28,
    );
    final edgePadding = staffSpace * 0.08;

    return (
      Offset(
        startMetrics.rightEdge - edgePadding,
        startPos.dy + (tieAbove ? -clearance : clearance),
      ),
      Offset(
        endMetrics.leftEdge + edgePadding,
        endPos.dy + (tieAbove ? -clearance : clearance),
      ),
    );
  }

  Offset calculateSlurEndpointForTesting(
    Offset notePos,
    Note note,
    Clef clef, {
    required bool isStart,
    required bool above,
    bool isGraceSlur = false,
  }) {
    return _calculateSlurEndpoint(
      notePos,
      note,
      clef,
      isStart: isStart,
      above: above,
      isGraceSlur: isGraceSlur,
    );
  }

  (Offset, Offset) calculateTieEndpointsForTesting(
    Offset startPos,
    Note startNote,
    Offset endPos,
    Note endNote, {
    required bool tieAbove,
  }) {
    return _calculateTieEndpoints(
      startPos,
      startNote,
      endPos,
      endNote,
      tieAbove: tieAbove,
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
