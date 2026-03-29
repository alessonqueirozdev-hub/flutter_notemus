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
/// Example:
/// ```dart
/// final measure = Measure()
///   ..add(TimeSignature(numerator: 4, denominator: 4))
///   ..add(Note(pitch: const Pitch(step: 'C', octave: 4),
///             duration: const Duration(DurationType.whole)));
/// ```
class Measure {
  /// All musical elements in this measure, in order.
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

  /// Adds a musical element to the measure.
  ///
  /// When a time signature is present, validates capacity before adding to
  /// ensure the bar's rhythmic value is not exceeded.
  ///
  /// Throws [MeasureCapacityException] if the element would exceed the measure capacity.
  void add(MusicalElement element) {
    // Check if the element occupies musical time
    final elementDuration = _getElementDuration(element);

    if (elementDuration > 0) {
      // Retrieve the time signature from the measure or use the inherited one
      final ts = timeSignature ?? inheritedTimeSignature;

      if (ts != null) {
        // calculateTeste available space
        final currentValue = currentMusicalValue;
        final measureCapacity = ts.measureValue;
        final afterAdding = currentValue + elementDuration;

        // Tolerance for floating-point errors
        const tolerance = 0.0001;

        if (afterAdding > measureCapacity + tolerance) {
          final excess = afterAdding - measureCapacity;
          throw MeasureCapacityException(
            'Cannot add ${element.runtimeType} to the measure!\n'
            'Measure ${ts.numerator}/${ts.denominator} (capacity: $measureCapacity units)\n'
            'Current value: $currentValue units\n'
            'Attempting to add: $elementDuration units\n'
            'Total would be: $afterAdding units\n'
            'EXCESS: ${excess.toStringAsFixed(4)} units\n'
            'OPERATION BLOCKED — Remove elements or create a new measure!'
          );
        }
      }
    }

    // Add the element
    elements.add(element);
  }

  /// calculateTestes the total current rhythmic value of elements in the measure.
  double get currentMusicalValue {
    double total = 0.0;
    for (final element in elements) {
      if (element is Note) {
        total += element.duration.realValue;
      } else if (element is Rest) {
        total += element.duration.realValue;
      } else if (element.runtimeType.toString() == 'Chord') {
        // Use reflection to avoid circular imports
        final dynamic chord = element;
        if (chord.duration != null) {
          total += chord.duration.realValue;
        }
      } else if (element.runtimeType.toString() == 'Tuplet') {
        // calculateTeste the tuplet value based on its ratio
        final dynamic tuplet = element;
        double tupletValue = 0.0;

        // Sum the duration of all notes in the tuplet
        for (final tupletElement in tuplet.elements) {
          if (tupletElement is Note) {
            tupletValue += tupletElement.duration.realValue;
          } else if (tupletElement.runtimeType.toString() == 'Chord') {
            final dynamic chord = tupletElement;
            if (chord.duration != null) {
              tupletValue += chord.duration.realValue;
            }
          }
        }

        // Apply the tuplet ratio (normalNotes / actualNotes)
        if (tuplet.actualNotes > 0) {
          tupletValue = tupletValue * (tuplet.normalNotes / tuplet.actualNotes);
        }

        total += tupletValue;
      }
    }
    return total;
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
  bool get isValidlyFilled {
    final ts = timeSignature;
    if (ts == null) return true; // No time signature = no validation
    return currentMusicalValue == ts.measureValue;
  }

  /// Returns true if there is room to add the given duration.
  bool canAddDuration(Duration duration) {
    final ts = timeSignature;
    if (ts == null) return true; // No time signature = always can add
    return currentMusicalValue + duration.realValue <= ts.measureValue;
  }

  /// Returns how much rhythmic time remains in the measure.
  double get remainingValue {
    final ts = timeSignature;
    if (ts == null) return double.infinity;
    return ts.measureValue - currentMusicalValue;
  }

  /// calculateTestes the duration of a musical element (private helper).
  double _getElementDuration(MusicalElement element) {
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
        tupletValue += _getElementDuration(tupletElement);
      }
      // Apply the tuplet ratio
      if (tuplet.actualNotes > 0) {
        tupletValue = tupletValue * (tuplet.normalNotes / tuplet.actualNotes);
      }
      return tupletValue;
    }
    return 0.0; // Elements without duration (clef, key signature, etc.)
  }
}

/// Exception thrown when trying to add an element that exceeds the measure capacity.
class MeasureCapacityException implements Exception {
  final String message;

  MeasureCapacityException(this.message);

  @override
  String toString() => 'MeasureCapacityException: $message';
}
