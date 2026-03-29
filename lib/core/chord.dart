// lib/core/chord.dart

import 'musical_element.dart';
import 'note.dart';
import 'duration.dart';
import 'ornament.dart';
import 'dynamic.dart';
import '../src/music_model/bounding_box_support.dart';

/// Representa a chord (conjunto de notes tocadas simultaneamente)
class Chord extends MusicalElement with BoundingBoxSupport {
  final List<Note> notes;
  final Duration duration;
  final List<ArticulationType> articulations;
  final TieType? tie;
  final SlurType? slur;
  final BeamType? beam;
  final List<Ornament> ornaments;
  final Dynamic? dynamic;

  /// Number of the voice for noteção polifônica (1 = soprano, 2 = contralto, etc.)
  /// null = voice única (default)
  final int? voice;

  Chord({
    required this.notes,
    required this.duration,
    this.articulations = const [],
    this.tie,
    this.slur,
    this.beam,
    this.ornaments = const [],
    this.dynamic,
    this.voice,
  });

  Note get highestNote {
    return notes.reduce(
      (a, b) => a.pitch.midiNumber > b.pitch.midiNumber ? a : b,
    );
  }

  Note get lowestNote {
    return notes.reduce(
      (a, b) => a.pitch.midiNumber < b.pitch.midiNumber ? a : b,
    );
  }
}
