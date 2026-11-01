// lib/src/playback/playback_plan.dart
//
// The transport model a player UI needs: where the music is at a given
// elapsed time, which written notes are sounding there, and when a bar
// starts. It is read off the `MidiSequence` the mapper already builds, so the
// cursor, the highlighting and the audio can never disagree about timing.
//
// Ported from @zamvar's fork (`codex/note-tap`, `PlaybackPlan`); the fork
// re-derived the measure timeline and the note mapping on its own, while this
// reads both from `MidiMapper` (`MidiSequence.playedMeasures` / `noteSpans`).

import '../../core/core.dart' hide Duration;
import '../midi/midi_mapper.dart';
import '../midi/midi_models.dart';

/// Where playback is at one instant.
class PlaybackPosition {
  /// MIDI tick, at the sequence's `ticksPerQuarter`.
  final int tick;

  /// Wall-clock time from the start, through every tempo change.
  final Duration elapsed;

  /// Index into [PlaybackPlan.measures]: which played bar (a repeated bar
  /// has one entry per pass).
  final int occurrenceIndex;

  /// Zero-based index of the bar in its [Staff].
  final int measureIndex;

  /// 1 on the first pass through a repeat, 2 on the second, …
  final int repeatPass;

  /// Whole notes from the start of the bar — the unit of
  /// `PositionedElement.onset`, so a playhead can find its x in the layout.
  final double offsetInMeasure;

  /// Length of the bar as it plays, in whole notes (a pickup's is its
  /// content, not its meter). A playhead spreads [offsetInMeasure] over it.
  final double measureLength;

  /// Fraction of the whole piece played, 0.0 to 1.0.
  final double progress;

  const PlaybackPosition({
    required this.tick,
    required this.elapsed,
    required this.occurrenceIndex,
    required this.measureIndex,
    required this.repeatPass,
    required this.offsetInMeasure,
    this.measureLength = 1.0,
    required this.progress,
  });

  @override
  String toString() => 'PlaybackPosition(bar index $measureIndex, pass '
      '$repeatPass, +$offsetInMeasure, ${elapsed.inMilliseconds} ms)';
}

/// Timing of a score as it plays, repeats expanded: a transport for a player
/// UI built on the same [MidiSequence] that produces the sound.
///
/// ```dart
/// final plan = PlaybackPlan.fromStaff(staff);
/// final where = plan.positionAt(stopwatch.elapsed);
/// final sounding = plan.notesAt(stopwatch.elapsed); // highlight these
/// player.seek(plan.timeOfMeasure(tap.measureIndex)!);
/// ```
class PlaybackPlan {
  /// The sequence the plan was read from; play it to hear what the plan
  /// describes.
  final MidiSequence sequence;

  /// Bars in the order they play.
  List<MidiPlayedMeasure> get measures => sequence.playedMeasures;

  /// Tempo changes in tick order, the first at tick 0.
  final List<({int tick, int bpm, Duration at})> tempoChanges;

  /// Length of the piece, through every tempo change.
  final Duration duration;

  /// The last tick of music (the end of the last played bar, or the last
  /// event when that is later).
  final int totalTicks;

  /// Note spans sorted by start tick, for the lookups below.
  final List<MidiNoteSpan> _spans;

  PlaybackPlan._(this.sequence, this.tempoChanges, this.totalTicks,
      this.duration, this._spans);

  /// Plans [staff] as `MidiMapper.fromStaff` plays it with [options].
  factory PlaybackPlan.fromStaff(
    Staff staff, {
    MidiGenerationOptions options = const MidiGenerationOptions(),
  }) =>
      PlaybackPlan.fromSequence(MidiMapper.fromStaff(staff, options: options));

  /// Plans [score] as `MidiMapper.fromScore` plays it with [options].
  factory PlaybackPlan.fromScore(
    Score score, {
    MidiGenerationOptions options = const MidiGenerationOptions(),
  }) =>
      PlaybackPlan.fromSequence(MidiMapper.fromScore(score, options: options));

  /// Plans an already mapped [sequence].
  ///
  /// [fallbackBpm] is the tempo of a sequence that carries no tempo event at
  /// all — a hand-built one. Pass the same value the player uses (the
  /// native bridge's `fallbackTempoBpm`), or positions drift from what plays.
  factory PlaybackPlan.fromSequence(
    MidiSequence sequence, {
    int fallbackBpm = 120,
  }) {
    final tpq = sequence.ticksPerQuarter;
    // Every track's tempo events, one per tick (the last one at a tick wins,
    // as a MIDI player applies them).
    final byTick = <int, int>{};
    for (final track in sequence.tracks) {
      for (final event in track.events) {
        if (event.type == MidiEventType.tempo && event.bpm != null) {
          byTick[event.tick] = event.bpm!;
        }
      }
    }
    if (!byTick.containsKey(0)) {
      final first = byTick.keys.isEmpty
          ? null
          : byTick.keys.reduce((a, b) => a < b ? a : b);
      byTick[0] = first == null ? fallbackBpm : byTick[first]!;
    }
    final ticks = byTick.keys.toList()..sort();
    final changes = <({int tick, int bpm, Duration at})>[];
    var at = Duration.zero;
    for (var i = 0; i < ticks.length; i++) {
      if (i > 0) {
        at += _span(ticks[i] - ticks[i - 1], byTick[ticks[i - 1]]!, tpq);
      }
      changes.add((tick: ticks[i], bpm: byTick[ticks[i]]!, at: at));
    }

    final played = sequence.playedMeasures;
    var total = played.isEmpty ? 0 : played.last.endTick;
    if (sequence.totalTicks > total) total = sequence.totalTicks;

    final spans = [...sequence.noteSpans]
      ..sort((a, b) => a.startTick.compareTo(b.startTick));
    final plan = PlaybackPlan._(
        sequence, List.unmodifiable(changes), total, Duration.zero, spans);
    return PlaybackPlan._(sequence, plan.tempoChanges, total,
        plan.timeAtTick(total), spans);
  }

  static Duration _span(int ticks, int bpm, int tpq) => Duration(
      microseconds: (ticks * 60000000 / (bpm * tpq)).round());

  int get _tpq => sequence.ticksPerQuarter;

  /// Wall-clock time at [tick].
  Duration timeAtTick(int tick) {
    final change = _changeAtTick(tick);
    return change.at + _span(tick - change.tick, change.bpm, _tpq);
  }

  /// Tick at wall-clock [elapsed], clamped to the piece.
  int tickAt(Duration elapsed) {
    if (elapsed <= Duration.zero) return 0;
    var change = tempoChanges.first;
    for (final c in tempoChanges) {
      if (c.at > elapsed) break;
      change = c;
    }
    final ticks = ((elapsed - change.at).inMicroseconds *
            change.bpm *
            _tpq /
            60000000)
        .round();
    final tick = change.tick + ticks;
    return tick > totalTicks ? totalTicks : tick;
  }

  ({int tick, int bpm, Duration at}) _changeAtTick(int tick) {
    var change = tempoChanges.first;
    for (final c in tempoChanges) {
      if (c.tick > tick) break;
      change = c;
    }
    return change;
  }

  /// Where playback is at [elapsed] (clamped to the piece), or null for a
  /// piece with no bars.
  PlaybackPosition? positionAt(Duration elapsed) {
    if (measures.isEmpty) return null;
    final tick = tickAt(elapsed);
    final occurrence = _occurrenceAtTick(tick);
    final bar = measures[occurrence];
    final clamped = tick < bar.startTick
        ? bar.startTick
        : (tick > bar.endTick ? bar.endTick : tick);
    return PlaybackPosition(
      tick: tick,
      elapsed: timeAtTick(tick),
      occurrenceIndex: occurrence,
      measureIndex: bar.measureIndex,
      repeatPass: bar.repeatPass,
      offsetInMeasure: (clamped - bar.startTick) / (_tpq * 4),
      measureLength: bar.durationTicks / (_tpq * 4),
      progress: totalTicks == 0 ? 0.0 : tick / totalTicks,
    );
  }

  /// The played bar containing [tick]: the last one starting at or before it.
  int _occurrenceAtTick(int tick) {
    var lo = 0;
    var hi = measures.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (measures[mid].startTick <= tick) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The written notes sounding at [elapsed]: every audible span with
  /// `startTick <= tick < endTick`. Ready for "highlight what is playing".
  ///
  /// A note muted (or not soloed) by the plan's options is silent in the
  /// sequence and left out; pass [includeSilent] to get it too, e.g. to show
  /// the cursor passing through a muted part.
  List<MidiNoteSpan> notesAt(Duration elapsed, {bool includeSilent = false}) {
    final tick = tickAt(elapsed);
    final sounding = <MidiNoteSpan>[];
    for (final span in _spans) {
      if (span.startTick > tick) break; // sorted by start
      if (span.endTick > tick && (includeSilent || span.audible)) {
        sounding.add(span);
      }
    }
    return sounding;
  }

  /// When bar [measureIndex] starts playing on pass [repeatPass], or null
  /// when it never plays (a bar skipped by a volta, or out of range).
  Duration? timeOfMeasure(int measureIndex, {int repeatPass = 1}) {
    for (final bar in measures) {
      if (bar.measureIndex == measureIndex && bar.repeatPass == repeatPass) {
        return timeAtTick(bar.startTick);
      }
    }
    return null;
  }
}
