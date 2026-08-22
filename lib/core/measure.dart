// lib/core/measure.dart

import 'musical_element.dart';
import 'note.dart';
import 'rest.dart';
import 'time_signature.dart';
import 'duration.dart';

/// Represents a single bar of music containing an ordered list of
/// [MusicalElement]s.
///
/// Use [add] to append elements. When a [TimeSignature] is present (or
/// inherited from a previous measure) the [add] method enforces capacity:
/// adding a note that would exceed the bar's rhythmic value throws a
/// [MeasureCapacityException].
///
/// Capacity is **voice aware**. A bar is full when a *single* voice fills it,
/// not when the sum of every voice does: in polyphonic music each voice runs
/// in parallel and independently spans the whole bar. Elements are grouped by
/// `Note.voice` / `Chord.voice` (`null` means voice [defaultVoice]) and the
/// rhythmic value of the measure is the **maximum** of the per-voice sums —
/// see [musicalValueByVoice] and [musicalValueOfVoice].
///
/// Example:
/// ```dart
/// final measure = Measure()
///   ..add(TimeSignature(numerator: 4, denominator: 4))
///   ..add(Note(pitch: const Pitch(step: 'C', octave: 4),
///             duration: const Duration(DurationType.whole)));
/// ```
///
/// Two-voice example (both voices legally fill the same 4/4 bar):
/// ```dart
/// final measure = Measure()..add(TimeSignature(numerator: 4, denominator: 4));
/// for (var i = 0; i < 4; i++) {
///   measure.add(Note(pitch: soprano, duration: quarter, voice: 1));
/// }
/// for (var i = 0; i < 4; i++) {
///   measure.add(Note(pitch: bass, duration: quarter, voice: 2));
/// }
/// ```
///
/// Subclasses that store elements elsewhere (such as `MultiVoiceMeasure`,
/// which keeps its content inside `Voice` objects) override
/// [musicalValueByVoice] and [allElements]; iterate a measure through
/// [allElements] to stay correct for every subclass.
class Measure {
  /// All musical elements in this measure, in order.
  ///
  /// The list itself is mutable on purpose: importers append to it directly so
  /// they can build a bar that is momentarily incomplete (a `<backup>` in
  /// MusicXML rewinds the cursor, a malformed file may overfill a bar). That
  /// also means writing here **bypasses the capacity check in [add]** — which
  /// is exactly what the package's own parsers do.
  ///
  /// Use [add] when you are authoring music and want the bar validated; write
  /// to [elements] only when you are reconstructing one from an external
  /// source and will validate it yourself (see `MeasureValidator`).
  final List<MusicalElement> elements = [];

  /// Controls whether notes should be automatically grouped with beams.
  /// true = auto-beaming active (default)
  /// false = use individual flags
  bool autoBeaming;

  /// Specific beaming strategy for special cases.
  BeamingMode beamingMode;

  /// Manual beam groups — list of note index groups to be beamed together.
  /// Example: [[0, 1, 2], [3, 4]] groups notes 0,1,2 into one beam and 3,4 into another.
  List<List<int>> manualBeamGroups;

  /// Time signature inherited from a previous measure (used for preventive validation).
  TimeSignature? inheritedTimeSignature;

  /// Measure number, corresponding to the MEI `<measure @n>` attribute.
  /// null = automatic numbering by the layout engine.
  int? number;

  /// Creates a new [Measure].
  ///
  /// [autoBeaming] defaults to `true` so that eighth notes and smaller are
  /// automatically grouped with beams. Set to `false` to use individual flags.
  ///
  /// [beamingMode] controls the beaming strategy; normally [BeamingMode.automatic].
  ///
  /// [manualBeamGroups] is a list of index groups for explicit beam control.
  /// Example: `[[0, 1, 2], [3, 4]]` groups the first three notes and the
  /// next two notes into separate beams.
  ///
  /// [inheritedTimeSignature] is set automatically by [LayoutEngine] when no
  /// [TimeSignature] is present in the measure but one was declared earlier.
  Measure({
    this.autoBeaming = true,
    this.beamingMode = BeamingMode.automatic,
    this.manualBeamGroups = const [],
    this.inheritedTimeSignature,
    this.number,
  });

  /// Voice number attributed to elements that do not declare one.
  ///
  /// `Note.voice == null` and `Chord.voice == null` mean "the only voice",
  /// which by convention is voice 1. Rests, tuplets and every element without
  /// a voice field are attributed to this voice as well.
  static const int defaultVoice = 1;

  /// Tolerance used when comparing rhythmic values (floating-point safety).
  static const double capacityTolerance = 0.0001;

  /// Adds a musical element to the measure.
  ///
  /// When a time signature is present, validates capacity before adding to
  /// ensure the bar's rhythmic value is not exceeded. The check is done
  /// against the value already written **in the voice the element belongs
  /// to** ([voiceNumberOf]), so independent voices may each fill the bar.
  ///
  /// Throws [MeasureCapacityException] if the element would exceed the
  /// capacity of its own voice.
  void add(MusicalElement element) {
    // Check if the element occupies musical time
    final elementDuration = musicalValueOf(element);

    if (elementDuration > 0) {
      // Retrieve the time signature from the measure or use the inherited one
      final ts = timeSignature ?? inheritedTimeSignature;

      if (ts != null) {
        // Only the incoming element's own voice competes for the bar's space.
        final voice = voiceNumberOf(element);
        final currentValue = musicalValueOfVoice(voice);
        final measureCapacity = ts.measureValue;
        final afterAdding = currentValue + elementDuration;

        if (afterAdding > measureCapacity + capacityTolerance) {
          final excess = afterAdding - measureCapacity;
          throw MeasureCapacityException(
            'Cannot add ${element.runtimeType} to voice $voice of the measure!\n'
            'Measure ${ts.numerator}/${ts.denominator} (capacity: $measureCapacity units per voice)\n'
            'Current value of voice $voice: $currentValue units\n'
            'Attempting to add: $elementDuration units\n'
            'Total would be: $afterAdding units\n'
            'EXCESS: ${excess.toStringAsFixed(4)} units\n'
            'OPERATION BLOCKED — Remove elements from voice $voice, move the '
            'element to another voice, or create a new measure!'
          );
        }
      }
    }

    // Add the element
    elements.add(element);
  }

  /// All the elements of this measure as a single stream.
  ///
  /// For a plain [Measure] this is exactly [elements]. Subclasses that keep
  /// content outside of [elements] — notably `MultiVoiceMeasure`, which stores
  /// its notes inside `Voice` objects — override this getter so that consumers
  /// have one correct way to walk any measure regardless of its concrete type.
  Iterable<MusicalElement> get allElements => elements;

  /// Rhythmic value written in each voice of this measure, keyed by voice
  /// number.
  ///
  /// Elements without an explicit voice are accumulated under [defaultVoice].
  /// Voices with no rhythmic content are omitted from the map.
  ///
  /// This is the single source of truth for [currentMusicalValue],
  /// [musicalValueOfVoice], [isValidlyFilled], [canAddDuration] and
  /// [remainingValue]; subclasses only need to override this getter to make
  /// the whole capacity API behave correctly for them.
  Map<int, double> get musicalValueByVoice {
    final byVoice = <int, double>{};
    for (final element in elements) {
      final value = musicalValueOf(element);
      if (value <= 0) continue;
      final voice = voiceNumberOf(element);
      byVoice[voice] = (byVoice[voice] ?? 0.0) + value;
    }
    return byVoice;
  }

  /// Rhythmic value already written in [voice] (0.0 when the voice is empty).
  double musicalValueOfVoice(int voice) => musicalValueByVoice[voice] ?? 0.0;

  /// The current rhythmic value of the measure.
  ///
  /// Voices sound simultaneously, so this is the **largest** per-voice sum
  /// (see [musicalValueByVoice]) and not the total of every element. For a
  /// single-voice measure both definitions coincide.
  double get currentMusicalValue {
    double maxValue = 0.0;
    for (final value in musicalValueByVoice.values) {
      if (value > maxValue) maxValue = value;
    }
    return maxValue;
  }

  /// Returns the active time signature for this measure.
  TimeSignature? get timeSignature {
    for (final element in elements) {
      if (element is TimeSignature) {
        return element;
      }
    }
    return null;
  }

  /// Returns true if the measure is correctly filled.
  ///
  /// Uses the same voice-aware value as [currentMusicalValue]: the bar is
  /// complete as soon as its longest voice matches the time signature.
  bool get isValidlyFilled {
    final ts = timeSignature;
    if (ts == null) return true; // No time signature = no validation
    return (currentMusicalValue - ts.measureValue).abs() <= capacityTolerance;
  }

  /// Returns true if there is room to add [duration] to [voice].
  ///
  /// Each voice is measured independently, so a full voice 1 does not prevent
  /// writing into voice 2.
  bool canAddDuration(Duration duration, {int voice = defaultVoice}) {
    final ts = timeSignature;
    if (ts == null) return true; // No time signature = always can add
    return musicalValueOfVoice(voice) + duration.realValue <=
        ts.measureValue + capacityTolerance;
  }

  /// Returns how much rhythmic time remains in the measure.
  ///
  /// Computed from the fullest voice: `capacity - currentMusicalValue`. Use
  /// `ts.measureValue - musicalValueOfVoice(n)` for the room left in a
  /// specific voice.
  double get remainingValue {
    final ts = timeSignature;
    if (ts == null) return double.infinity;
    return ts.measureValue - currentMusicalValue;
  }

  /// Calculates the rhythmic value occupied by [element].
  ///
  /// Returns 0.0 for elements that do not occupy musical time (clefs, key
  /// signatures, barlines, ...). Tuplets are scaled by their
  /// `normalNotes / actualNotes` ratio.
  ///
  /// `Chord` and `Tuplet` are resolved dynamically to avoid circular imports.
  static double musicalValueOf(MusicalElement element) {
    if (element is Note) {
      return element.duration.realValue;
    } else if (element is Rest) {
      return element.duration.realValue;
    } else if (element.runtimeType.toString() == 'Chord') {
      final dynamic chord = element;
      return chord.duration?.realValue ?? 0.0;
    } else if (element.runtimeType.toString() == 'Tuplet') {
      final dynamic tuplet = element;
      double tupletValue = 0.0;
      for (final tupletElement in tuplet.elements) {
        tupletValue += musicalValueOf(tupletElement as MusicalElement);
      }
      // Apply the tuplet ratio
      if (tuplet.actualNotes > 0) {
        tupletValue = tupletValue * (tuplet.normalNotes / tuplet.actualNotes);
      }
      return tupletValue;
    }
    return 0.0; // Elements without duration (clef, key signature, etc.)
  }

  /// Returns the voice number [element] belongs to.
  ///
  /// `Note.voice` / `Chord.voice` are honoured; `null` and elements without a
  /// voice field (rests, tuplets, clefs, ...) fall back to [defaultVoice].
  /// For a tuplet the voice of its first voiced child is used, so that a
  /// triplet written in voice 2 is not accounted against voice 1.
  static int voiceNumberOf(MusicalElement element) {
    if (element is Note) {
      return element.voice ?? defaultVoice;
    } else if (element.runtimeType.toString() == 'Chord') {
      final dynamic chord = element;
      final dynamic voice = chord.voice;
      return voice is int ? voice : defaultVoice;
    } else if (element.runtimeType.toString() == 'Tuplet') {
      final dynamic tuplet = element;
      for (final tupletElement in tuplet.elements) {
        final child = tupletElement as MusicalElement;
        final voice = voiceNumberOf(child);
        if (voice != defaultVoice) return voice;
      }
      return defaultVoice;
    }
    return defaultVoice;
  }
}

/// Exception thrown when trying to add an element that exceeds the measure capacity.
class MeasureCapacityException implements Exception {
  final String message;

  MeasureCapacityException(this.message);

  @override
  String toString() => 'MeasureCapacityException: $message';
}
