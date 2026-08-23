// lib/core/measure.dart

import 'chord.dart';
import 'musical_element.dart';
import 'note.dart';
import 'rest.dart';
import 'time_signature.dart';
import 'tuplet.dart';
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

  /// A meter this bar inherits from an earlier one, so that [add] can enforce
  /// capacity on a bar that declares no [TimeSignature] of its own.
  ///
  /// **This is an INPUT you set, never something the engine writes.** It used
  /// to say "set automatically by `LayoutEngine`", and that was the package's
  /// most dangerous engine-writes-the-model defect (ADR-005 action item 8):
  /// [add] reads this field to compute the bar's capacity, so laying a score
  /// out changed whether a public method THREW. Measured on a two-bar staff
  /// whose bar 2 declares no meter and already holds four quarters under an
  /// inherited 4/4:
  ///
  /// | | `m2.inheritedTimeSignature` | `m2.add(<fifth quarter>)` |
  /// |---|---|---|
  /// | fresh | `null` | accepted |
  /// | after `LayoutEngine.layout()` | `TimeSignature(4/4)` | **threw [MeasureCapacityException]** |
  ///
  /// `LayoutEngine` now DERIVES the inheritance as a value it owns and leaves
  /// every [Measure] field-for-field identical; read it from
  /// `LayoutEngine.timeSignatureOf(measure)`, or validate a whole staff with
  /// `MeasureValidator.validateStaff(staff)`. Set this field yourself only to
  /// opt a stand-alone bar into preventive validation — and note that doing so
  /// makes [add] throw where it otherwise would not, which is the point.
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
  /// [inheritedTimeSignature] opts a bar that declares no [TimeSignature] of
  /// its own into capacity checking in [add]. Nothing in the package writes it
  /// for you — see the field's own documentation for why that changed.
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
  /// ## Grace notes take no time
  ///
  /// A [Note] with `isGraceNote == true` returns 0.0. A grace note is an
  /// ornament: it is printed small, it is drawn, it occupies horizontal WIDTH,
  /// but it does not advance the musical clock — it is stolen from the
  /// neighbouring note, not added to the bar (Behind Bars p.125; MusicXML
  /// `<grace>` notes carry no `<duration>` at all, and MEI `@grace` likewise
  /// excludes the note from the layer's rhythmic total).
  ///
  /// Measured before this rule existed: a 4/4 bar of four quarters plus two
  /// eighth grace notes reported `currentMusicalValue = 1.1875` instead of
  /// 1.0, and the layout onsets came out
  /// `[0, 0.125, 0.1875, 0.4375, 0.6875, 0.9375]` while `MidiMapper` (which
  /// already skipped grace notes) produced a correct 3840 ticks at 960 ppq.
  /// Layout and playback therefore disagreed, and the ADR-002 shared onset
  /// grid — the thing that makes a grand staff line up — broke for any staff
  /// containing a grace note.
  ///
  /// `Chord` and `Tuplet` used to be resolved through
  /// `runtimeType.toString()` "to avoid circular imports". Verified: there is
  /// no cycle. `chord.dart` imports musical_element/note/duration/ornament/
  /// dynamic/bounding_box_support and `tuplet.dart` imports musical_element/
  /// note/rest/chord/time_signature/tuplet_bracket/tuplet_number — neither
  /// reaches `measure.dart`, and nothing in their transitive closure does. The
  /// string comparison was also silently wrong for any subclass of `Chord` or
  /// `Tuplet`, so both are matched with `is` now.
  static double musicalValueOf(MusicalElement element) {
    if (element is Note) {
      return element.isGraceNote ? 0.0 : element.duration.realValue;
    } else if (element is Rest) {
      return element.duration.realValue;
    } else if (element is Chord) {
      return element.duration.realValue;
    } else if (element is Tuplet) {
      double tupletValue = 0.0;
      for (final tupletElement in element.elements) {
        tupletValue += musicalValueOf(tupletElement);
      }
      // Apply the tuplet ratio
      if (element.actualNotes > 0) {
        tupletValue = tupletValue * (element.normalNotes / element.actualNotes);
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
    } else if (element is Chord) {
      return element.voice ?? defaultVoice;
    } else if (element is Tuplet) {
      for (final tupletElement in element.elements) {
        final voice = voiceNumberOf(tupletElement);
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
