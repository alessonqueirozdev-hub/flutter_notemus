// lib/core/voice.dart

import 'musical_element.dart';
import 'measure.dart';
import 'note.dart';
import 'rest.dart';
import 'chord.dart';

/// Represents a voice in polyphonic notation
///
/// In polyphonic music, multiple independent melodic lines (voices)
/// are notated on the same staff. Each voice is typically distinguished by:
/// - Stem direction (voice 1: up, voice 2: down)
/// - Horizontal offset (voice 2 shifted right)
/// - Different beaming groups
///
/// Examples:
/// - Bach fugues (3-4 voices on one staff)
/// - Piano music (2 voices per hand)
/// - Guitar fingerstyle (melody + accompaniment)
/// - Counterpoint exercises
///
/// Convention:
/// - Voice 1 (top voice): Stems up, no offset
/// - Voice 2 (bottom voice): Stems down, shifted right
/// - Voice 3+: Additional voices as needed
class Voice {
  /// Voice number (1-based)
  ///
  /// Voice 1 is typically the top/principal voice
  final int number;

  /// Musical elements in this voice (notes, rests, chords)
  final List<MusicalElement> elements;

  /// Optional name for the voice (e.g., "Soprano", "Melody")
  final String? name;

  /// Preferred stem direction for this voice
  ///
  /// If null, determined automatically based on voice number:
  /// - Voice 1: stems up
  /// - Voice 2: stems down
  /// - Voice 3+: alternating or based on position
  final StemDirection? forcedStemDirection;

  /// Horizontal offset for collision avoidance (in staff spaces)
  ///
  /// Typically voice 2 is offset 0.5-1.0 staff spaces to the right
  final double? horizontalOffset;

  /// Color for this voice (optional, for visual distinction)
  final String? color;

  Voice({
    required this.number,
    List<MusicalElement>? elements,
    this.name,
    this.forcedStemDirection,
    this.horizontalOffset,
    this.color,
  }) : elements = elements ?? [];

  /// Add element to this voice
  void add(MusicalElement element) {
    elements.add(element);

    // Set voice number on notes
    if (element is Note) {
      // Note: This would require modifying Note class to have mutable voiceNumber
      // For now, voice tracking is manual
    }
  }

  /// Get stem direction for this voice
  ///
  /// Uses forced direction if set, otherwise follows convention:
  /// - Voice 1: up
  /// - Voice 2: down
  /// - Voice 3+: up (or based on position)
  StemDirection getStemDirection() {
    if (forcedStemDirection != null) return forcedStemDirection!;

    switch (number) {
      case 1:
        return StemDirection.up;
      case 2:
        return StemDirection.down;
      default:
        return StemDirection.up; // Default for voice 3+
    }
  }

  /// Get horizontal offset for this voice
  ///
  /// Voice 2 is typically offset to avoid collision with voice 1
  double getHorizontalOffset(double staffSpace) {
    if (horizontalOffset != null) return horizontalOffset!;

    switch (number) {
      case 1:
        return 0.0; // No offset for voice 1
      case 2:
        return staffSpace * 0.6; // Offset right for voice 2
      default:
        return staffSpace * 0.3 * (number - 1); // Incremental offset
    }
  }

  /// Check if this voice contains any notes (not just rests)
  bool get hasNotes {
    return elements.any((e) => e is Note || e is Chord);
  }

  /// Get all notes in this voice
  List<Note> get notes {
    return elements.whereType<Note>().toList();
  }

  /// Get all rests in this voice
  List<Rest> get rests {
    return elements.whereType<Rest>().toList();
  }

  /// Get all chords in this voice
  List<Chord> get chords {
    return elements.whereType<Chord>().toList();
  }

  /// Factory: Create voice 1 (top voice, stems up)
  factory Voice.voice1({List<MusicalElement>? elements, String? name}) {
    return Voice(
      number: 1,
      elements: elements,
      name: name ?? 'Voice 1',
      forcedStemDirection: StemDirection.up,
    );
  }

  /// Factory: Create voice 2 (bottom voice, stems down, offset right)
  factory Voice.voice2({List<MusicalElement>? elements, String? name}) {
    return Voice(
      number: 2,
      elements: elements,
      name: name ?? 'Voice 2',
      forcedStemDirection: StemDirection.down,
      horizontalOffset: 0.6, // Will be multiplied by staffSpace
    );
  }
}

/// Stem direction for notes
enum StemDirection {
  up,
  down,
  auto, // Determined by position on staff
}

/// Measure with multiple independent voices
///
/// Used for polyphonic notation where multiple melodic lines
/// appear on the same staff simultaneously.
///
/// Example:
/// ```dart
/// final measure = MultiVoiceMeasure();
///
/// // Voice 1 (melody, stems up)
/// final voice1 = Voice.voice1();
/// voice1.add(Note(pitch: Pitch(step: 'E', octave: 5), duration: ...));
/// measure.addVoice(voice1);
///
/// // Voice 2 (accompaniment, stems down)
/// final voice2 = Voice.voice2();
/// voice2.add(Note(pitch: Pitch(step: 'C', octave: 4), duration: ...));
/// measure.addVoice(voice2);
/// ```
class MultiVoiceMeasure extends Measure {
  /// Map of voice number to Voice object
  final Map<int, Voice> voices = {};

  /// Add a voice to this measure
  void addVoice(Voice voice) {
    voices[voice.number] = voice;
  }

  /// Get voice by number
  Voice? getVoice(int number) => voices[number];

  /// Get list of voice numbers (sorted)
  List<int> get voiceNumbers => voices.keys.toList()..sort();

  /// Get number of voices in this measure
  int get voiceCount => voices.length;

  /// Check if measure has multiple voices (is polyphonic)
  bool get isPolyphonic => voices.length > 1;

  /// Get all voices sorted by voice number
  List<Voice> get sortedVoices {
    return voiceNumbers.map((n) => voices[n]!).toList();
  }

  /// Get voice 1 (top voice)
  Voice? get voice1 => getVoice(1);

  /// Get voice 2 (bottom voice)
  Voice? get voice2 => getVoice(2);

  /// Factory: Create measure with 2 voices
  factory MultiVoiceMeasure.twoVoices({
    required List<MusicalElement> voice1Elements,
    required List<MusicalElement> voice2Elements,
  }) {
    final measure = MultiVoiceMeasure();

    measure.addVoice(Voice.voice1(elements: voice1Elements));
    measure.addVoice(Voice.voice2(elements: voice2Elements));

    return measure;
  }
}

