// lib/core/rest.dart

import 'musical_element.dart';
import 'duration.dart';
import 'ornament.dart';
import '../src/music_model/bounding_box_support.dart';

/// Representa a pausa.
class Rest extends MusicalElement with BoundingBoxSupport {
  final Duration duration;

  /// List of ornaments aplicados to the pausa (ex: fermata)
  final List<Ornament> ornaments;

  Rest({required this.duration, this.ornaments = const []});
}
