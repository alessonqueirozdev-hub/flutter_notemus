// lib/core/voice.dart

import 'musical_element.dart';
import 'measure.dart';
import 'note.dart';
import 'rest.dart';
import 'chord.dart';

/// Represents a voice in polyphonic notation.
///
/// In polyphonic music, multiple independent melodic lines (voices)
/// are notated on the same staff. Each voice is typically distinguished by:
/// - Stem direction (voice 1: up, voice 2: down)
/// - Horizontal offset (the stem-down voice shifted right on unisons/seconds)
/// - Different beaming groups
///
/// Examples:
/// - Bach fugues (3-4 voices on one staff)
/// - Piano music (2 voices per hand)
/// - Guitar fingerstyle (melody + accompaniment)
/// - Counterpoint exercises
///
/// Convention (Gould, *Behind Bars*, "Two or more parts on a staff"):
/// - Odd voices (1, 3): stems up, no horizontal offset
/// - Even voices (2, 4): stems down, offset to the right when they collide
///
/// A [Voice] does not mutate the elements it receives: `Note.voice` is
/// `final`, so the voice number must be set when the note is constructed.
/// Use [elementsCarryVoiceNumber] / [validate] to check that this was done.
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

  /// Add element to this voice.
  ///
  /// The element is stored as-is. `Note.voice` and `Chord.voice` are `final`,
  /// so this method cannot back-fill the voice number: it has to be supplied
  /// at construction time, e.g. `Note(pitch: ..., duration: ..., voice: 2)`.
  /// [validate] reports elements whose voice number disagrees with [number].
  void add(MusicalElement element) {
    elements.add(element);
  }

  /// True when every [Note]/[Chord] in this voice already declares
  /// `voice == number`.
  ///
  /// A `null` voice does **not** count as carrying the number, not even for
  /// voice 1: it only means "unassigned". Returns `true` for a voice that
  /// contains no notes or chords.
  bool get elementsCarryVoiceNumber => validate().isEmpty;

  /// Checks that the voice number was propagated to the elements.
  ///
  /// Returns one human-readable message per inconsistency, in element order:
  /// `element at index i has voice=X but belongs to Voice Y`. An empty list
  /// means the voice is internally consistent.
  ///
  /// Propagation must happen when the note is built (`Note.voice` is final);
  /// this method exists so callers can detect a mismatch instead of silently
  /// rendering notes in the wrong voice.
  List<String> validate() {
    final problems = <String>[];
    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      int? elementVoice;
      if (element is Note) {
        elementVoice = element.voice;
      } else if (element is Chord) {
        elementVoice = element.voice;
      } else {
        continue; // Rests and other elements do not carry a voice number.
      }
      if (elementVoice != number) {
        problems.add(
          'element at index $i has voice=${elementVoice ?? 'null'} '
          'but belongs to Voice $number',
        );
      }
    }
    return problems;
  }

  /// Get stem direction for this voice.
  ///
  /// Uses [forcedStemDirection] when set. Otherwise follows the standard
  /// convention (Gould, *Behind Bars*): odd-numbered voices point up and
  /// even-numbered voices point down, i.e. voices 1 and 3 up, voices 2 and 4
  /// down. This pairing is what lets voice 1 sit above voice 2 (and voice 3
  /// above voice 4) without extra layout information.
  StemDirection getStemDirection() {
    if (forcedStemDirection != null) return forcedStemDirection!;

    return number.isEven ? StemDirection.down : StemDirection.up;
  }

  /// Get horizontal offset for this voice, in pixels.
  ///
  /// Uses [horizontalOffset] (expressed in staff spaces) when set.
  ///
  /// Otherwise the offset follows the stem direction of the voice, per Gould,
  /// *Behind Bars*: when noteheads of opposing voices collide, the stem-down
  /// voice is displaced to the right of the stem-up voice so the noteheads
  /// stay legible. The offset therefore pairs with [getStemDirection]:
  ///
  /// | Voice | Stems | Offset               |
  /// |-------|-------|----------------------|
  /// | 1     | up    | none                 |
  /// | 2     | down  | 0.6 staff spaces     |
  /// | 3     | up    | none                 |
  /// | 4     | down  | 0.6 staff spaces     |
  ///
  /// Limitation: this is a static, per-voice rule. Real engraving only
  /// displaces a notehead when the voices actually collide (unison or an
  /// interval of a second at the same rhythmic position), and it keeps the
  /// column aligned everywhere else. Voices beyond 4 reuse the same odd/even
  /// rule; they are rare and usually need manual [horizontalOffset].
  double getHorizontalOffset(double staffSpace) {
    if (horizontalOffset != null) {
      return horizontalOffset! * staffSpace;
    }

    // Stem-up voices (odd) keep the reference column; stem-down voices (even)
    // move right by one notehead width minus the stem, ~0.6 staff spaces.
    return number.isEven ? staffSpace * 0.6 : 0.0;
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

/// Measure with multiple independent voices.
///
/// Used for polyphonic notation where multiple melodic lines
/// appear on the same staff simultaneously.
///
/// This is a **specialization** of [Measure]: instead of keeping its notes in
/// the inherited [Measure.elements] list, it stores them inside [Voice]
/// objects. [Measure.elements] is therefore normally limited to the shared
/// attributes of the bar (clef, time signature, key signature, barlines).
///
/// Because of that, **[allElements] is the correct way to iterate a measure**
/// — it is overridden here to yield the shared elements followed by the
/// elements of every voice in voice order. Reading `elements` directly on a
/// [MultiVoiceMeasure] silently skips all the music.
///
/// The inherited capacity API ([currentMusicalValue], [musicalValueOfVoice],
/// [isValidlyFilled], [canAddDuration], [remainingValue]) is voice-aware here
/// as well: it is all derived from [musicalValueByVoice], which this class
/// overrides to account for the voices. Without that override a polyphonic
/// measure reported a rhythmic value of ~0 and was rejected by every
/// measure validator.
///
/// Example:
/// ```dart
/// final measure = MultiVoiceMeasure();
///
/// // Voice 1 (melody, stems up)
/// final voice1 = Voice.voice1();
/// voice1.add(Note(pitch: Pitch(step: 'E', octave: 5), duration: ..., voice: 1));
/// measure.addVoice(voice1);
///
/// // Voice 2 (accompaniment, stems down)
/// final voice2 = Voice.voice2();
/// voice2.add(Note(pitch: Pitch(step: 'C', octave: 4), duration: ..., voice: 2));
/// measure.addVoice(voice2);
/// ```
class MultiVoiceMeasure extends Measure {
  MultiVoiceMeasure();

  /// Collection of voices (order not guaranteed).
  ///
  /// Kept as a convenience for iteration and collection queries; use
  /// [sortedVoices] when voice order matters.
  Iterable<Voice> get voices => _voicesByNumber.values;

  /// Map of voice number to Voice object
  final Map<int, Voice> _voicesByNumber = {};

  /// Shared elements of the bar followed by the elements of every voice,
  /// voices taken in ascending voice-number order.
  ///
  /// This is the only iteration path that sees the whole content of a
  /// polyphonic measure.
  @override
  Iterable<MusicalElement> get allElements sync* {
    yield* elements;
    for (final voice in sortedVoices) {
      yield* voice.elements;
    }
  }

  /// Rhythmic value per voice, counting both the inherited
  /// [Measure.elements] list and the elements held by each [Voice].
  ///
  /// A voice contributes to its own voice number ([Voice.number]) regardless
  /// of the `voice` field of the notes it holds, since the container is the
  /// authoritative assignment here.
  @override
  Map<int, double> get musicalValueByVoice {
    final byVoice = Map<int, double>.from(super.musicalValueByVoice);
    for (final entry in _voicesByNumber.entries) {
      double total = 0.0;
      for (final element in entry.value.elements) {
        total += Measure.musicalValueOf(element);
      }
      if (total <= 0.0) continue;
      byVoice[entry.key] = (byVoice[entry.key] ?? 0.0) + total;
    }
    return byVoice;
  }

  /// Add a voice to this measure
  void addVoice(Voice voice) {
    _voicesByNumber[voice.number] = voice;
  }

  /// Get voice by number
  Voice? getVoice(int number) => _voicesByNumber[number];

  /// Get list of voice numbers (sorted)
  List<int> get voiceNumbers => _voicesByNumber.keys.toList()..sort();

  /// Get number of voices in this measure
  int get voiceCount => _voicesByNumber.length;

  /// Check if measure has multiple voices (is polyphonic)
  bool get isPolyphonic => _voicesByNumber.length > 1;

  /// Get all voices sorted by voice number
  List<Voice> get sortedVoices {
    return voiceNumbers.map((n) => _voicesByNumber[n]!).toList();
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

  /// Factory: Create measure with 3 voices
  factory MultiVoiceMeasure.threeVoices({
    required List<MusicalElement> voice1Elements,
    required List<MusicalElement> voice2Elements,
    required List<MusicalElement> voice3Elements,
  }) {
    final measure = MultiVoiceMeasure();

    measure.addVoice(Voice.voice1(elements: voice1Elements));
    measure.addVoice(Voice.voice2(elements: voice2Elements));
    measure.addVoice(Voice(number: 3, elements: voice3Elements));

    return measure;
  }
}
