// lib/core/beam.dart

import 'musical_element.dart';
import 'note.dart';

/// Representa a viga (beam) that connects notes
class Beam extends MusicalElement {
  final List<Note> notes;
  final int beamCount;
  final bool primary;
  
  Beam({
    required this.notes,
    this.beamCount = 1,
    this.primary = true,
  });
}
