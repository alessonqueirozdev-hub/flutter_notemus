// lib/src/layout/beam_grouper.dart

import '../../core/core.dart';

/// Responsible for grouping rhythmic figures into beam groups.
class BeamGrouper {
  /// Widest ambitus, in diatonic steps, that a single beam may span.
  ///
  /// "Behind Bars" (Gould), pp. 17-18 ("Beamed stems"): a beamed group keeps
  /// stems of about 3.5 staff spaces and the beam follows the contour of the
  /// group; where the ambitus is extreme the group is BROKEN rather than
  /// stretched, because the stem of the outer note grows by one staff space
  /// for every two diatonic steps of ambitus.
  ///
  /// MEASURED on this engine (two eighths, stem-up, `BeamAnalyzer`), stem
  /// length of the outer note against the ambitus of the group, before the
  /// maximum-stem pass existed:
  ///
  /// ```text
  /// steps  0     4     7     8     10    12    14
  /// stem   3.50  4.50  5.50  6.00  7.00  8.00  9.00   (staff spaces)
  /// ```
  ///
  /// The staff itself is 4 staff spaces tall, so a two-octave group drew a stem
  /// more than twice the height of the staff.
  ///
  /// Twelve steps is the ambitus that still fits between one ledger line below
  /// and one ledger line above the staff (staff positions -6 to +6): the group
  /// stays inside a single readable band. It is deliberately NOT the octave.
  /// Two-note leaps of a ninth or a tenth are ordinary engraving and are now
  /// brought back inside the stem cap by the steepening pass of `BeamAnalyzer`
  /// (measured: 14 steps, 9.00 staff spaces before, 5.50 after). What that pass
  /// cannot rescue is a group whose EXTREME NOTE IS AN INNER ONE, because no
  /// slope shortens it: C3-C5-C3-C5 in 2/4 measured 10.00 / 3.50 / 11.00 / 4.50
  /// staff spaces with the beam crossing the staff diagonally, and that is the
  /// shape this limit removes.
  ///
  /// The split is applied to the modes where the engine chooses the grouping
  /// ([BeamingMode.automatic], [BeamingMode.conservative]). `forceBeamAll` and
  /// `manual` are explicit author decisions and are left untouched.
  static const int kMaximumBeamAmbitusSteps = 12;

  /// Longest compound beat, in whole notes, that still reads as ONE beat.
  ///
  /// A compound beat is three denominator units, which is a dotted crotchet in
  /// x/8 (fine), a dotted minim in x/4 (the limit — 6/4 is engraved in two
  /// beams of six quavers) and a dotted BREVE in x/2. The last one is not a
  /// beat at all: measured, 6/2 filled with quavers produced two beams of
  /// TWELVE notes, 9/2 three of twelve, 12/2 four and 15/2 five. Behind Bars
  /// p. 160 groups by the beat; in x/2 the beat is the minim, so those meters
  /// must not take the compound branch.
  ///
  /// 0.75 = a dotted minim.
  static const double kMaximumCompoundBeatWholeNotes = 0.75;
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

    // Only the `manual` branch needs the notes as a LIST; every other branch
    // wants to know whether there is at least one. Materialising it up front
    // built one `List<Note>` per bar for nothing on the automatic path, which
    // is the path essentially every bar of every score takes — 12 800 lists
    // per layout pass on the 12 800-bar fixture.
    var hasNote = false;
    for (final item in items) {
      if (item.note != null) {
        hasNote = true;
        break;
      }
    }
    if (!hasNote) return groups;

    if (!autoBeaming || beamingMode == BeamingMode.forceFlags) {
      return groups;
    }

    switch (beamingMode) {
      case BeamingMode.forceBeamAll:
        return _groupAllRuns(_collectBeamableRuns(items));
      case BeamingMode.conservative:
        return _splitWideAmbitus(
          _groupConservativeRuns(_collectBeamableRuns(items)),
        );
      case BeamingMode.manual:
        return _groupManual(
          items.map((item) => item.note).whereType<Note>().toList(),
          manualBeamGroups,
        );
      case BeamingMode.automatic:
      default:
        return _splitWideAmbitus(
          _groupBySubdivisions(
            items,
            _beamGroupSubdivisions(
              timeSignature,
              shortestBeamedValue: _shortestBeamedValue(items),
            ),
          ),
        );
    }
  }

  /// Splits every group of [groups] whose ambitus exceeds
  /// [kMaximumBeamAmbitusSteps] into consecutive runs that stay inside it.
  ///
  /// The walk is greedy and forward: a note joins the run under construction
  /// while the run's own ambitus (its widest interval, not just the interval to
  /// the previous note) stays within the limit, and starts a new run
  /// otherwise. Runs that end up with a single note simply lose their beam and
  /// are engraved with a flag, which is the point of the rule: measured, a
  /// C3-C5-C3-C5 group in 2/4 produced stems of 10.00, 3.50, 11.00 and 4.50
  /// staff spaces with the beam crossing the staff diagonally.
  ///
  /// Ambitus is read from the PITCH (diatonic step + octave), not from a staff
  /// position, because `BeamGrouper` runs before clef resolution. The two agree
  /// for every clef; the one case where they do not is a note carrying an
  /// octave-shift bracket, which moves its staff position but not its pitch.
  ///
  /// The pass runs on EVERY beamed bar of every score, and the overwhelming
  /// majority of bars never trip the limit, so the no-split case allocates
  /// nothing at all: [groups] itself is handed back, and a group that survives
  /// intact keeps its own [BeamGroup] instance. Rebuilding unconditionally cost
  /// one `List<Note>` plus one `BeamGroup` per group — measured on 12 800 bars
  /// of eighths in 4/4, that was 25 600 surplus lists and 25 600 surplus
  /// [BeamGroup] objects per layout pass, thrown away one instruction later.
  static List<BeamGroup> _splitWideAmbitus(List<BeamGroup> groups) {
    List<BeamGroup>? result;

    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      final notes = group.notes;
      var lowest = _diatonicIndex(notes.first);
      var highest = lowest;

      // First pass: find the note that breaks the limit, without building
      // anything. Most groups never reach it.
      var breakAt = -1;
      for (var i = 1; i < notes.length; i++) {
        final index = _diatonicIndex(notes[i]);
        final newLowest = index < lowest ? index : lowest;
        final newHighest = index > highest ? index : highest;
        if (newHighest - newLowest > kMaximumBeamAmbitusSteps) {
          breakAt = i;
          break;
        }
        lowest = newLowest;
        highest = newHighest;
      }

      if (breakAt < 0) {
        // Group survives whole: keep the instance and, while nothing has split
        // yet, keep the caller's list too.
        result?.add(group);
        continue;
      }

      // Something splits: from here on the answer is a NEW list, seeded with
      // the groups already cleared.
      if (result == null) {
        result = <BeamGroup>[];
        for (var k = 0; k < g; k++) {
          result.add(groups[k]);
        }
      }

      var run = notes.sublist(0, breakAt);
      _addGroupIfValid(result, run);
      run = <Note>[notes[breakAt]];
      lowest = _diatonicIndex(notes[breakAt]);
      highest = lowest;

      for (var i = breakAt + 1; i < notes.length; i++) {
        final note = notes[i];
        final index = _diatonicIndex(note);
        final newLowest = index < lowest ? index : lowest;
        final newHighest = index > highest ? index : highest;

        if (newHighest - newLowest > kMaximumBeamAmbitusSteps) {
          _addGroupIfValid(result, run);
          run = <Note>[note];
          lowest = index;
          highest = index;
          continue;
        }

        run.add(note);
        lowest = newLowest;
        highest = newHighest;
      }

      _addGroupIfValid(result, run);
    }

    return result ?? groups;
  }

  /// Absolute diatonic index of [note]: C4 is 28, D4 is 29, C5 is 35.
  ///
  /// One unit is one diatonic step, which is also one staff position, so the
  /// difference between two indices is directly the interval that the beam has
  /// to span.
  ///
  /// The step is read one code unit at a time rather than through
  /// `Pitch.validSteps.indexOf(step.toUpperCase())`: that spelling allocated an
  /// upper-cased copy of the step string AND ran a linear list search for every
  /// note of every beamed group, on a path that sees the whole score (12 800
  /// bars of eighths = 102 400 notes per layout pass). The answer is identical
  /// — `Pitch.validSteps` is `['C','D','E','F','G','A','B']` and a step is one
  /// letter — and an unrecognised step still falls back to index 0, exactly as
  /// the `indexOf` returning `-1` did.
  static int _diatonicIndex(Note note) {
    final step = note.pitch.step;
    var index = 0;
    if (step.isNotEmpty) {
      // 'a'..'g' -> 'A'..'G'; anything else falls through to 0.
      var unit = step.codeUnitAt(0);
      if (unit >= 0x61 && unit <= 0x7A) unit -= 0x20;
      switch (unit) {
        case 0x43: // C
          index = 0;
        case 0x44: // D
          index = 1;
        case 0x45: // E
          index = 2;
        case 0x46: // F
          index = 3;
        case 0x47: // G
          index = 4;
        case 0x41: // A
          index = 5;
        case 0x42: // B
          index = 6;
      }
    }
    return index + note.pitch.octave * 7;
  }

  /// Shortest beamable value in [items], in whole notes (an eighth is `0.125`).
  ///
  /// Beam grouping is not a property of the meter alone: Behind Bars p.157
  /// allows quavers in 4/4 to be amalgamated across the half bar, but requires
  /// anything SHORTER to be grouped by the beat so the metre stays readable.
  /// The old table ignored this and applied the half-bar rule to every value,
  /// so a bar of sixteen semiquavers in 4/4 came out as two beams of eight
  /// instead of four beams of four — while 3/4, which has no half-bar rule,
  /// was already correct at four-per-beat. The inconsistency was the tell.
  ///
  /// Augmentation dots are deliberately ignored (`duration.type.value`, not
  /// `realValue`): a dotted quaver is still a quaver for grouping purposes.
  static double _shortestBeamedValue(List<_BeamingItem> items) {
    var shortest = 1.0;
    for (final item in items) {
      if (!item.isBeamable) continue;
      final note = item.note;
      if (note == null) continue;
      final value = note.duration.type.value;
      if (value < shortest) shortest = value;
    }
    return shortest;
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
  /// [shortestBeamedValue] is the shortest beamable value present in the bar,
  /// in whole notes; it decides whether the half-bar amalgamation of 4/4 and
  /// alla breve applies (see [_shortestBeamedValue]).
  ///
  /// INVARIANT: the returned subdivisions must sum to `timeSignature.measureValue`.
  /// The old table broke it for 5/4, where `[0.5, 0.5]` covered only four of the
  /// five crotchets; the fifth fell through the walker and produced a stray
  /// trailing group (measured: `4-4-2` for ten quavers instead of `2-2-2-2-2`).
  static List<double> _beamGroupSubdivisions(
    TimeSignature timeSignature, {
    required double shortestBeamedValue,
  }) {
    // The beat table is a pure function of (meter, shortest figure), and a
    // staff states its meter once and inherits it: on the 12 800-bar fixture
    // every single bar asks for the SAME table and got two freshly allocated
    // lists for it (the raw table, then the merged one), 25 600 lists per
    // layout pass. A one-entry memo answers all but the first.
    //
    // Keyed on the meter INSTANCE, not on its numbers: two `TimeSignature`
    // objects that read alike may still differ in `additiveGroups` or
    // `isFreeTime`, and comparing identity cannot be wrong — a miss just does
    // the work. The returned list is shared, so callers must treat it as
    // read-only; both of them already copy before touching it.
    if (identical(timeSignature, _cachedMeter) &&
        shortestBeamedValue == _cachedShortestBeamedValue) {
      return _cachedSubdivisions!;
    }

    final subdivisions = _rawBeamGroupSubdivisions(
      timeSignature,
      shortestBeamedValue: shortestBeamedValue,
    );

    // A beat that cannot hold two of the shortest figure in the bar can never
    // produce a group of two, so the bar comes out with NO beam at all. See
    // [_mergeUndersizedBeats].
    final result = shortestBeamedValue > 0.125
        ? subdivisions
        : _mergeUndersizedBeats(subdivisions, 2 * shortestBeamedValue);

    _cachedMeter = timeSignature;
    _cachedShortestBeamedValue = shortestBeamedValue;
    _cachedSubdivisions = result;
    return result;
  }

  static TimeSignature? _cachedMeter;
  static double _cachedShortestBeamedValue = double.nan;
  static List<double>? _cachedSubdivisions;

  /// Merges consecutive beats of [subdivisions] until each one is at least
  /// [minimumBeat] whole notes long, preserving the total (the INVARIANT of
  /// [_beamGroupSubdivisions]).
  ///
  /// This is the fix for the largest hole measured in the beam table: with one
  /// beat per denominator unit, a bar whose figure is worth exactly one unit
  /// puts exactly ONE note in every beat, and `_addGroupIfValid` needs two.
  /// Exhaustively measured before the fix, these meters produced ZERO beams —
  /// quavers in 1/8, 2/8, 4/8, 10/8, 13/8, 14/8, 16/8, 2/16, 4/16, 8/16,
  /// 10/16, 14/16, 16/16 and semiquavers in 1/16, 2/16, 4/16, 5/16, 7/16,
  /// 8/16, 10/16, 11/16, 13/16, 14/16, 16/16 — plus 6/16 and 12/16, where the
  /// compound beat of three semiquavers is shorter than the quaver it had to
  /// hold and only caught two of the three quavers in the bar.
  ///
  /// A trailing beat that is still too short is folded into the beat before it
  /// rather than left standing: measured on 13/8, that is the difference
  /// between `[2,2,2,2,2,2]` plus one orphan quaver and `[2,2,2,2,2,3]`.
  static List<double> _mergeUndersizedBeats(
    List<double> subdivisions,
    double minimumBeat,
  ) {
    const tolerance = 1e-9;
    if (subdivisions.isEmpty) return subdivisions;

    final merged = <double>[];
    var pending = 0.0;

    for (final subdivision in subdivisions) {
      pending += subdivision;
      if (pending + tolerance >= minimumBeat) {
        merged.add(pending);
        pending = 0.0;
      }
    }

    if (pending > tolerance) {
      if (merged.isEmpty) {
        merged.add(pending);
      } else {
        merged[merged.length - 1] += pending;
      }
    }

    return merged;
  }

  /// The metrical table itself: one entry per beat of [timeSignature],
  /// before [_mergeUndersizedBeats] checks that each beat can actually hold two
  /// of the figure being beamed.
  static List<double> _rawBeamGroupSubdivisions(
    TimeSignature timeSignature, {
    required double shortestBeamedValue,
  }) {
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

    const double eighth = 0.125;
    const double sixteenth = 0.0625;
    const double tolerance = 1e-9;

    // Compound meters (6/8, 9/8, 12/8, 6/16, 6/4, ...): the beat is three units.
    // 3/8 is deliberately excluded - it is a single beat, not a compound bar.
    if (numerator > 3 &&
        numerator % 3 == 0 &&
        3 * unit <= kMaximumCompoundBeatWholeNotes + tolerance) {
      // In 6/4 and 9/4 the compound beat is a DOTTED MINIM, so a beam of
      // twelve semiquavers would run for half a bar. Those meters fall back to
      // their unit (the crotchet) for short values. 6/8 and 6/16 keep their
      // groups of three units: six semiquavers to a dotted crotchet is the
      // standard grouping (Behind Bars p.160) and must not change.
      //
      // x/2 no longer reaches this branch at all: its compound beat is a dotted
      // BREVE (1.5 whole notes), rejected by [kMaximumCompoundBeatWholeNotes].
      // It falls through to the alla breve rules below, which give 6/2 six
      // beams of four quavers instead of the two beams of twelve measured
      // before, and twelve beams of four semiquavers instead of six of eight.
      if (denominator == 4 && shortestBeamedValue <= sixteenth + tolerance) {
        return List<double>.filled(numerator, unit);
      }
      return List<double>.filled(numerator ~/ 3, 3 * unit);
    }

    // Simple ternary written in eighths or sixteenths (3/8, 3/16): one group.
    if (numerator == 3 && (denominator == 8 || denominator == 16)) {
      return <double>[3 * unit];
    }

    // Known irregular meters written in eighths, where the accent pattern is
    // conventional rather than derivable.
    switch ('$numerator/$denominator') {
      case '5/8':
        return <double>[2 * unit, 3 * unit];
      case '7/8':
        return <double>[2 * unit, 2 * unit, 3 * unit];
      case '8/8':
        return <double>[3 * unit, 3 * unit, 2 * unit];
      case '11/8':
        return <double>[3 * unit, 3 * unit, 3 * unit, 2 * unit];
    }

    // ---- Simple and irregular meters: one group per BEAT ------------------
    //
    // This is the general case and it always covers the whole bar, which is
    // what the old per-meter table failed to guarantee. A beat of one unit can
    // still be too short for the figure being beamed; [_mergeUndersizedBeats]
    // aggregates it afterwards.
    //
    // Behind Bars p.157: in 4/4 quavers may be amalgamated across the half bar.
    // The amalgamation is a QUAVER licence only - semiquavers and shorter are
    // grouped by the crotchet so the beat stays visible.
    if (numerator == 4 &&
        denominator == 4 &&
        shortestBeamedValue >= eighth - tolerance) {
      return const <double>[0.5, 0.5];
    }

    // Alla breve family (x/2): the beat is the minim, which is right for
    // quavers, but semiquavers under one beam of eight are unreadable - split
    // each minim into its two crotchets.
    if (denominator == 2 && shortestBeamedValue <= sixteenth + tolerance) {
      return List<double>.filled(numerator * 2, unit / 2);
    }

    return List<double>.filled(numerator, unit);
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

    // The zero-length beats this drops are the exception, not the rule, so the
    // copy is only made when there is actually something to drop: the table
    // arrives from the memo in [_beamGroupSubdivisions] and is read-only here
    // either way.
    var hasEmptyBeat = false;
    for (final subdivision in subdivisions) {
      if (subdivision <= tolerance) {
        hasEmptyBeat = true;
        break;
      }
    }
    final pattern = hasEmptyBeat
        ? subdivisions.where((subdivision) => subdivision > tolerance).toList()
        : subdivisions;
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
