// lib/core/articulation.dart

import 'musical_element.dart';
import 'note.dart'; // Para ArticulationType

/// Representa a articulation Appliesda a a note
class Articulation extends MusicalElement {
  final ArticulationType type;
  final bool above;

  Articulation({
    required this.type,
    this.above = true,
  });
}
