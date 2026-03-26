import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../smufl/smufl_metadata_loader.dart';

String? resolveGraceGlyphNameFromOrnaments(Iterable<Ornament> ornaments) {
  for (final ornament in ornaments) {
    switch (ornament.type) {
      case OrnamentType.appoggiaturaUp:
        return 'graceNoteAppoggiaturaStemUp';
      case OrnamentType.appoggiaturaDown:
        return 'graceNoteAppoggiaturaStemDown';
      case OrnamentType.acciaccatura:
      case OrnamentType.grace:
        return 'graceNoteAcciaccaturaStemUp';
      default:
        continue;
    }
  }
  return null;
}

String? resolveGraceGlyphName(Note note) {
  return resolveGraceGlyphNameFromOrnaments(note.ornaments);
}

bool hasGraceOrnament(Note note) => resolveGraceGlyphName(note) != null;

bool hasGraceOrnamentInOrnaments(Iterable<Ornament> ornaments) =>
    resolveGraceGlyphNameFromOrnaments(ornaments) != null;

double graceGlyphSize(double glyphSize) => glyphSize * 0.6;

double graceLead({required bool hasAccidental, required double staffSpace}) {
  return staffSpace * (hasAccidental ? 2.8 : 1.5);
}

double graceLeadFor(Note note, double staffSpace) {
  final hasAccidental = note.pitch.accidentalType != null;
  return graceLead(hasAccidental: hasAccidental, staffSpace: staffSpace);
}

Offset graceGlyphOrigin({
  required double anchorX,
  required double anchorY,
  required double staffSpace,
  required bool hasAccidental,
}) {
  return Offset(
    anchorX - graceLead(hasAccidental: hasAccidental, staffSpace: staffSpace),
    anchorY,
  );
}

Offset graceGlyphOriginForNote(Note note, Offset notePos, double staffSpace) {
  return graceGlyphOrigin(
    anchorX: notePos.dx,
    anchorY: notePos.dy,
    staffSpace: staffSpace,
    hasAccidental: note.pitch.accidentalType != null,
  );
}

Offset graceGlyphOriginForChord(
  Chord chord,
  Offset chordPos,
  double anchorY,
  double staffSpace,
) {
  return graceGlyphOrigin(
    anchorX: chordPos.dx,
    anchorY: anchorY,
    staffSpace: staffSpace,
    hasAccidental: chord.notes.any((note) => note.pitch.accidentalType != null),
  );
}

Offset graceSlurStartPointForNote({
  required Note note,
  required Offset notePos,
  required bool above,
  required double staffSpace,
  required double glyphSize,
  required SmuflMetadata metadata,
}) {
  final origin = graceGlyphOriginForNote(note, notePos, staffSpace);
  final scaleFactor = graceGlyphSize(glyphSize) / glyphSize;
  final noteheadBox = metadata.getGlyphBoundingBox('noteheadBlack');
  final noteheadWidth = (noteheadBox?.width ?? 1.18) * staffSpace * scaleFactor;
  final noteheadHeight =
      (noteheadBox?.height ?? 0.88) * staffSpace * scaleFactor;
  final edgeInset = math.min(noteheadWidth * 0.16, staffSpace * 0.08);
  final clearance = math.max(noteheadHeight * 0.22, staffSpace * 0.12);

  return Offset(
    origin.dx + noteheadWidth - edgeInset,
    notePos.dy + (above ? -clearance : clearance),
  );
}
