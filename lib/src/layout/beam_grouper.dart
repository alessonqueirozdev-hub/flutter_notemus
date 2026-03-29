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
        final strategy = _getGroupingStrategy(timeSignature);
        switch (strategy) {
          case BeamingStrategy.simple:
            return _groupSimpleTime(items, timeSignature);
          case BeamingStrategy.compound:
            return _groupCompoundTime(items, timeSignature);
          case BeamingStrategy.irregular:
            return _groupIrregularTime(items, timeSignature);
        }
    }
  }

  static bool _isBeamable(Note note) {
    return note.duration.type.value <= 0.125;
  }

  static BeamingStrategy _getGroupingStrategy(TimeSignature timeSignature) {
    final denominator = timeSignature.denominator;
    final numerator = timeSignature.numerator;

    if (denominator == 8 && numerator % 3 == 0) {
      return BeamingStrategy.compound;
    }

    if ([2, 3, 4].contains(numerator) && [2, 4, 8].contains(denominator)) {
      return BeamingStrategy.simple;
    }

    return BeamingStrategy.irregular;
  }

  static List<BeamGroup> _groupSimpleTime(
    List<_BeamingItem> items,
    TimeSignature timeSignature,
  ) {
    final groups = <BeamGroup>[];
    final beatUnit = 1.0 / timeSignature.denominator;

    var currentGroup = <Note>[];
    var currentPosition = 0.0;

    for (final item in items) {
      if (item.note == null || !item.isBeamable) {
        _addGroupIfValid(groups, currentGroup);
        currentGroup = <Note>[];
        currentPosition += item.duration;
        continue;
      }

      final note = item.note!;
      final noteEnd = currentPosition + item.duration;
      final startBeat = (currentPosition / beatUnit).floor();
      final endBeat = ((noteEnd - 0.0001) / beatUnit).floor();

      if (startBeat != endBeat && currentGroup.isNotEmpty) {
        _addGroupIfValid(groups, currentGroup);
        currentGroup = [note];
      } else {
        currentGroup.add(note);
      }

      currentPosition = noteEnd;
    }

    _addGroupIfValid(groups, currentGroup);
    return groups;
  }

  static List<BeamGroup> _groupCompoundTime(
    List<_BeamingItem> items,
    TimeSignature timeSignature,
  ) {
    final groups = <BeamGroup>[];
    final beatUnit = 3.0 / timeSignature.denominator;

    var currentGroup = <Note>[];
    var currentBeatPosition = 0.0;

    for (final item in items) {
      if (item.note == null || !item.isBeamable) {
        _addGroupIfValid(groups, currentGroup);
        currentGroup = <Note>[];
        currentBeatPosition += item.duration;
        continue;
      }

      final note = item.note!;
      final nextBeatPosition = currentBeatPosition + item.duration;
      final currentBeat = (currentBeatPosition / beatUnit).floor();
      final nextBeat = (nextBeatPosition / beatUnit).floor();

      if (currentBeat != nextBeat && currentGroup.isNotEmpty) {
        _addGroupIfValid(groups, currentGroup);
        currentGroup = <Note>[];
      }

      currentGroup.add(note);
      currentBeatPosition = nextBeatPosition;

      if (_isEndOfCompoundBeat(nextBeatPosition, beatUnit) &&
          currentGroup.length >= 2) {
        groups.add(BeamGroup(notes: List<Note>.from(currentGroup)));
        currentGroup.clear();
      }
    }

    _addGroupIfValid(groups, currentGroup);
    return groups;
  }

  static List<BeamGroup> _groupIrregularTime(
    List<_BeamingItem> items,
    TimeSignature timeSignature,
  ) {
    final groups = <BeamGroup>[];
    final subdivisions = _getIrregularSubdivisions(timeSignature);

    var currentGroup = <Note>[];
    var currentPosition = 0.0;
    var subdivisionIndex = 0;
    var subdivisionStart = 0.0;

    for (final item in items) {
      if (item.note == null || !item.isBeamable) {
        _addGroupIfValid(groups, currentGroup);
        currentGroup = <Note>[];
        currentPosition += item.duration;

        while (subdivisionIndex < subdivisions.length &&
            currentPosition >
                subdivisionStart + subdivisions[subdivisionIndex]) {
          subdivisionStart += subdivisions[subdivisionIndex];
          subdivisionIndex++;
        }
        continue;
      }

      final note = item.note!;
      final nextPosition = currentPosition + item.duration;

      if (subdivisionIndex < subdivisions.length) {
        final subdivisionEnd =
            subdivisionStart + subdivisions[subdivisionIndex];

        if (nextPosition > subdivisionEnd && currentGroup.isNotEmpty) {
          _addGroupIfValid(groups, currentGroup);
          currentGroup.clear();
          subdivisionStart = subdivisionEnd;
          subdivisionIndex++;
        }
      }

      currentGroup.add(note);
      currentPosition = nextPosition;
    }

    _addGroupIfValid(groups, currentGroup);
    return groups;
  }

  static List<double> _getIrregularSubdivisions(TimeSignature timeSignature) {
    final numerator = timeSignature.numerator;
    final denominator = timeSignature.denominator;
    final eighthNote = 1.0 / 8;

    switch ('$numerator/$denominator') {
      case '5/8':
        return [2 * eighthNote, 3 * eighthNote];
      case '7/8':
        return [2 * eighthNote, 2 * eighthNote, 3 * eighthNote];
      case '5/4':
        return [1.0, 1.0];
      default:
        final subdivisions = <double>[];
        var remaining = numerator;
        final unit = 1.0 / denominator;

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
  }

  static bool _isEndOfCompoundBeat(double position, double beatUnit) {
    const tolerance = 0.0001;
    return (position % beatUnit).abs() < tolerance;
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
