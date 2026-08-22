// lib/src/layout/beam_grouper.dart

import '../../core/core.dart';

/// Responsible for grouping rhythmic figures into beam groups.
class BeamGrouper {
  /// Groups notes into beams from a note-only timeline.
  ///
  /// This entry point is kept for compatibility. It now respects
  /// non-beamable notes as hard barriers, but cannot see rests because they are
  /// not part of the input collection.
  static List<BeamGroup> groupNotesForBeaming(
    List<Note> notes,
    TimeSignature timeSignature, {
    bool autoBeaming = true,
    BeamingMode beamingMode = BeamingMode.automatic,
    List<List<int>> manualBeamGroups = const [],
  }) {
    final items = notes
        .map(
          (note) => _BeamingItem.note(
            note: note,
            duration: note.duration.realValue,
            isBeamable: _isBeamable(note),
          ),
        )
        .toList();

    return _groupTimelineItems(
      items,
      timeSignature,
      autoBeaming: autoBeaming,
      beamingMode: beamingMode,
      manualBeamGroups: manualBeamGroups,
    );
  }

  /// Groups beams while respecting the full rhythmic timeline of the measure,
  /// including rests and non-beamable notes as real boundaries.
  static List<BeamGroup> groupElementsForBeaming(
    List<MusicalElement> elements,
    TimeSignature timeSignature, {
    bool autoBeaming = true,
    BeamingMode beamingMode = BeamingMode.automatic,
    List<List<int>> manualBeamGroups = const [],
  }) {
    final items = <_BeamingItem>[];

    for (final element in elements) {
      if (element is Note) {
        items.add(
          _BeamingItem.note(
            note: element,
            duration: element.duration.realValue,
            isBeamable: _isBeamable(element),
          ),
        );
      } else if (element is Rest) {
        items.add(_BeamingItem.rest(duration: element.duration.realValue));
      }
    }

    return _groupTimelineItems(
      items,
      timeSignature,
      autoBeaming: autoBeaming,
      beamingMode: beamingMode,
      manualBeamGroups: manualBeamGroups,
    );
  }

  static List<BeamGroup> _groupTimelineItems(
    List<_BeamingItem> items,
    TimeSignature timeSignature, {
    bool autoBeaming = true,
    BeamingMode beamingMode = BeamingMode.automatic,
    List<List<int>> manualBeamGroups = const [],
  }) {
    final groups = <BeamGroup>[];
    final notes = items.map((item) => item.note).whereType<Note>().toList();

    if (notes.isEmpty) return groups;

    if (!autoBeaming || beamingMode == BeamingMode.forceFlags) {
      return groups;
    }

    switch (beamingMode) {
      case BeamingMode.forceBeamAll:
        return _groupAllRuns(_collectBeamableRuns(items));
      case BeamingMode.conservative:
        return _groupConservativeRuns(_collectBeamableRuns(items));
      case BeamingMode.manual:
        return _groupManual(notes, manualBeamGroups);
      case BeamingMode.automatic:
      default:
        return _groupBySubdivisions(
          items,
          _beamGroupSubdivisions(timeSignature),
        );
    }
  }

  /// A note can carry a beam when it is an eighth note or shorter.
  ///
  /// [DurationType.value] is measured in whole notes, so every value from
  /// 1/8 down to 1/2048 satisfies this test.
  static bool _isBeamable(Note note) {
    return note.duration.type.value <= 0.125;
  }

  /// Returns the beam-group boundaries of [timeSignature] as a list of
  /// durations measured in whole notes (a quarter note is `0.25`).
  ///
  /// Each entry is one macro-beat that a beam must not cross. Simple, compound
  /// and irregular meters all describe themselves through this single list, so
  /// there is only one grouping algorithm to keep correct.
  static List<double> _beamGroupSubdivisions(TimeSignature timeSignature) {
    if (timeSignature.isFreeTime) return const <double>[];

    final numerator = timeSignature.numerator;
    final denominator = timeSignature.denominator;
    if (numerator <= 0 || denominator <= 0) return const <double>[];

    final unit = 1.0 / denominator;

    // Additive meters carry their own grouping, e.g. (3+2+2)/8.
    final additiveGroups = timeSignature.additiveGroups;
    if (additiveGroups != null && additiveGroups.isNotEmpty) {
      return additiveGroups.map((group) => group.numerator * unit).toList();
    }

    // Compound meters (6/8, 9/8, 12/8, 6/16, ...): groups of three units.
    // 3/8 is deliberately excluded - it is a single beat, not a compound bar.
    if ((denominator == 8 || denominator == 16) &&
        numerator > 3 &&
        numerator % 3 == 0) {
      return List<double>.filled(numerator ~/ 3, 3 * unit);
    }

    // Simple ternary written in eighths or sixteenths (3/8, 3/16): one group.
    if (numerator == 3 && (denominator == 8 || denominator == 16)) {
      return <double>[3 * unit];
    }

    // 4/4 beams across the half bar (the Behind Bars preference).
    if (numerator == 4 && denominator == 4) {
      return const <double>[0.5, 0.5];
    }

    // Other simple meters, including 2/2 (alla breve): one group per unit.
    if ([2, 3, 4].contains(numerator) && [2, 4, 8].contains(denominator)) {
      return List<double>.filled(numerator, unit);
    }

    // Known irregular meters.
    switch ('$numerator/$denominator') {
      case '5/8':
        return <double>[2 * unit, 3 * unit];
      case '7/8':
        return <double>[2 * unit, 2 * unit, 3 * unit];
      case '8/8':
        return <double>[3 * unit, 3 * unit, 2 * unit];
      case '5/4':
        return const <double>[0.5, 0.5];
    }

    // Fallback: groups of three units while three units remain.
    final subdivisions = <double>[];
    var remaining = numerator;
    while (remaining > 0) {
      if (remaining >= 3) {
        subdivisions.add(3 * unit);
        remaining -= 3;
      } else {
        subdivisions.add(remaining * unit);
        remaining = 0;
      }
    }
    return subdivisions;
  }

  /// Groups a rhythmic timeline into beams, breaking only at [subdivisions].
  ///
  /// A note belongs to the subdivision it STARTS in. Grouping by the start
  /// (instead of by the end) is what keeps the note that completes a beat
  /// inside that beat rather than pushing it into the next group.
  ///
  /// A note that crosses a boundary — it lasts longer than what is left of its
  /// subdivision — closes the group before it and opens a new group with it.
  ///
  /// Rests and non-beamable notes are hard barriers. The subdivision pattern
  /// repeats if the timeline is longer than one measure, so overfull measures
  /// keep grouping instead of collapsing into one beam.
  static List<BeamGroup> _groupBySubdivisions(
    List<_BeamingItem> items,
    List<double> subdivisions,
  ) {
    const tolerance = 0.0001;

    final pattern = subdivisions
        .where((subdivision) => subdivision > tolerance)
        .toList();
    final totalDuration = items.fold<double>(
      0.0,
      (sum, item) => sum + item.duration,
    );

    // Cumulative boundary positions, in whole notes.
    final boundaries = <double>[];
    if (pattern.isNotEmpty) {
      var boundary = 0.0;
      var index = 0;
      while (boundary < totalDuration - tolerance) {
        boundary += pattern[index % pattern.length];
        boundaries.add(boundary);
        index++;
      }
    }

    final groups = <BeamGroup>[];
    var currentGroup = <Note>[];
    int? currentGroupIndex;
    var position = 0.0;

    for (final item in items) {
      if (item.note == null || !item.isBeamable) {
        _addGroupIfValid(groups, currentGroup);
        currentGroup = <Note>[];
        currentGroupIndex = null;
        position += item.duration;
        continue;
      }

      final note = item.note!;
      final nextPosition = position + item.duration;
      final startIndex = _subdivisionIndexAt(boundaries, position);

      var endIndex = startIndex;
      while (endIndex < boundaries.length &&
          boundaries[endIndex] + tolerance < nextPosition) {
        endIndex++;
      }
      final crossesBoundary = endIndex != startIndex;

      if (currentGroup.isNotEmpty &&
          (startIndex != currentGroupIndex || crossesBoundary)) {
        _addGroupIfValid(groups, currentGroup);
        currentGroup = <Note>[];
      }

      currentGroup.add(note);
      // A crossing note carries its new group into the subdivision it ends in.
      currentGroupIndex = endIndex;
      position = nextPosition;
    }

    _addGroupIfValid(groups, currentGroup);
    return groups;
  }

  /// Index of the subdivision a note starting at [position] belongs to.
  ///
  /// A note landing exactly on a boundary (within tolerance) starts the next
  /// subdivision.
  static int _subdivisionIndexAt(List<double> boundaries, double position) {
    const tolerance = 0.0001;
    var index = 0;

    while (index < boundaries.length &&
        position >= boundaries[index] - tolerance) {
      index++;
    }

    return index;
  }

  static List<BeamGroup> _groupAllRuns(List<List<Note>> runs) {
    return runs
        .where((run) => run.length >= 2)
        .map((run) => BeamGroup(notes: List<Note>.from(run)))
        .toList();
  }

  static List<BeamGroup> _groupConservative(List<Note> notes) {
    final groups = <BeamGroup>[];

    for (int i = 0; i < notes.length - 1; i += 2) {
      final currentNote = notes[i];
      final nextNote = notes[i + 1];

      if (currentNote.duration.type == nextNote.duration.type) {
        groups.add(BeamGroup(notes: [currentNote, nextNote]));
      }
    }

    return groups;
  }

  static List<BeamGroup> _groupConservativeRuns(List<List<Note>> runs) {
    final groups = <BeamGroup>[];

    for (final run in runs) {
      groups.addAll(_groupConservative(run));
    }

    return groups;
  }

  static List<List<Note>> _collectBeamableRuns(List<_BeamingItem> items) {
    final runs = <List<Note>>[];
    var currentRun = <Note>[];

    for (final item in items) {
      if (item.note != null && item.isBeamable) {
        currentRun.add(item.note!);
        continue;
      }

      if (currentRun.isNotEmpty) {
        runs.add(List<Note>.from(currentRun));
        currentRun = <Note>[];
      }
    }

    if (currentRun.isNotEmpty) {
      runs.add(List<Note>.from(currentRun));
    }

    return runs;
  }

  static void _addGroupIfValid(List<BeamGroup> groups, List<Note> notes) {
    if (notes.length >= 2) {
      groups.add(BeamGroup(notes: List<Note>.from(notes)));
    }
  }

  static List<BeamGroup> _groupManual(
    List<Note> notes,
    List<List<int>> manualGroups,
  ) {
    final groups = <BeamGroup>[];

    for (final groupIndices in manualGroups) {
      if (groupIndices.length < 2) continue;

      final groupNotes = <Note>[];
      for (final index in groupIndices) {
        if (index >= 0 && index < notes.length) {
          groupNotes.add(notes[index]);
        }
      }

      if (groupNotes.length >= 2 && groupNotes.every(_isBeamable)) {
        groups.add(BeamGroup(notes: groupNotes));
      }
    }

    return groups;
  }
}

/// Coarse classification of a time signature's beaming behaviour.
///
/// Kept for callers that describe a meter; grouping itself no longer branches
/// on it — every meter is expressed as a list of beam-group subdivisions.
enum BeamingStrategy { simple, compound, irregular }

class BeamGroup {
  final List<Note> notes;
  final BeamGroupType type;

  BeamGroup({required this.notes, this.type = BeamGroupType.primary});

  bool get isValid => notes.length >= 2;

  DurationType get shortestDuration {
    return notes.map((n) => n.duration.type).reduce((a, b) {
      return a.value < b.value ? a : b;
    });
  }

  int get numberOfBeams {
    switch (shortestDuration) {
      case DurationType.eighth:
        return 1;
      case DurationType.sixteenth:
        return 2;
      case DurationType.thirtySecond:
        return 3;
      case DurationType.sixtyFourth:
        return 4;
      default:
        return 1;
    }
  }

  bool get hasUniformDuration {
    if (notes.isEmpty) return true;
    final firstDuration = notes.first.duration.type;
    return notes.every((note) => note.duration.type == firstDuration);
  }
}

enum BeamGroupType { primary, secondary, partial }

class _BeamingItem {
  final Note? note;
  final double duration;
  final bool isBeamable;

  const _BeamingItem.note({
    required this.note,
    required this.duration,
    required this.isBeamable,
  });

  const _BeamingItem.rest({required this.duration})
    : note = null,
      isBeamable = false;
}
