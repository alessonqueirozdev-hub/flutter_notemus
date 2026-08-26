// lib/core/octave.dart

import 'musical_element.dart';

/// Tipos de marcações de oitava
enum OctaveType {
  va8,      // 8va (uma oitava acima)
  vb8,      // 8vb (uma oitava abaixo)  
  va15,     // 15ma (duas oitavas acima)
  vb15,     // 15mb (duas oitavas abaixo)
  va22,     // 22da (três oitavas acima)
  vb22,     // 22db (três oitavas abaixo)
}

/// Marca de oitava (8va, 8vb, 15ma, etc.)
class OctaveMark extends MusicalElement {
  final OctaveType type;
  final int startMeasure;
  final int endMeasure;
  final int? startNote;
  final int? endNote;
  final double length; // Comprimento da linha em pixels
  final bool showBracket; // Mostrar colchete no final

  OctaveMark({
    required this.type,
    required this.startMeasure,
    required this.endMeasure,
    this.startNote,
    this.endNote,
    this.length = 100.0,
    this.showBracket = true,
  });

  /// Returns o deslocamento in oitavas
  int get octaveShift {
    switch (type) {
      case OctaveType.va8:
        return 1;
      case OctaveType.vb8:
        return -1;
      case OctaveType.va15:
        return 2;
      case OctaveType.vb15:
        return -2;
      case OctaveType.va22:
        return 3;
      case OctaveType.vb22:
        return -3;
    }
  }

  /// Returns o text of the marca
  String get text {
    switch (type) {
      case OctaveType.va8:
        return '8va';
      case OctaveType.vb8:
        return '8vb';
      case OctaveType.va15:
        return '15ma';
      case OctaveType.vb15:
        return '15mb';
      case OctaveType.va22:
        return '22da';
      case OctaveType.vb22:
        return '22db';
    }
  }
}

/// Resolves WHICH [OctaveMark] is in force at each point of an element stream.
///
/// ADR-003 fixed the meaning of [Pitch]: it is always the SOUNDING pitch, and an
/// octave displacement changes only WHERE THE NOTE IS PRINTED. That rule already
/// lived in exactly one place for the clef axis
/// (`StaffPositionCalculator.calculate` subtracting `clef.octaveShift * 7`); the
/// bracket axis — 8va/8vb/15ma/15mb/22da/22db — was never wired up at all.
/// Measured before this class existed: C6 printed at staffPosition 8 / Y 12.0
/// with NO mark, and at staffPosition 8 / Y 12.0 under every one of the six
/// bracket types — all six identical, i.e. `OctaveMark.octaveShift` had zero
/// consumers. After: C6 under 8va prints at staffPosition 1 / Y 54.0 and under
/// 8vb at staffPosition 15 / Y -30.0.
///
/// ## Activation rule (this is the contract every consumer relies on)
///
/// 1. A mark becomes active **at the point it appears in the element stream** —
///    not at the head of its measure. Notes written before the bracket in the
///    same bar keep the previous displacement, exactly the way a mid-measure
///    [Clef] change is handled by the layout engine.
/// 2. A mark stays active until the END of its [OctaveMark.endMeasure], or until
///    another [OctaveMark] appears (the new one simply replaces it — there is no
///    nesting in the model).
/// 3. **Degenerate spans.** Both MusicXML and MEI importers build the mark with
///    `startMeasure: 0, endMeasure: 0` because neither format carries the span
///    length on the START element: MusicXML closes an `<octave-shift>` with a
///    separate `type="stop"` direction (which `_musicXmlOctaveShift` deliberately
///    maps to `null`, so no element is emitted) and MEI puts the end in `@endid`.
///    When `endMeasure <= startMeasure` the span is therefore treated as ending
///    at the end of the measure the mark was found in — the conservative choice,
///    since over-extending a bracket silently transposes music the author never
///    marked. Widening that to true multi-measure spans requires the importers to
///    record the stop; until they do, an imported 8va displaces its own bar only.
///
/// The tracker is single-pass and order-sensitive: feed it every element of the
/// staff exactly once, in document order, and call [reset] before re-walking.
///
/// **It is only correct for a MONOPHONIC element stream.** A polyphonic bar
/// serialises voice 1 in full before voice 2, so a single-pass walk gives the
/// same marking a different meaning depending on which voice the author typed
/// it in — see [OctaveSpanTimeline], which is what the layout engine and the
/// renderers use, and which resolves the span by musical TIME instead.
class OctaveSpanTracker {
  OctaveMark? _active;
  int? _activeEndMeasure;

  /// The mark currently in force, or null outside every span.
  OctaveMark? get active => _active;

  /// Displacement in octaves in force right now (0 outside every span).
  ///
  /// Sign convention is IDENTICAL to `Clef.octaveShift`: 8va is `+1` and must
  /// print 7 half-space positions LOWER, because the printed note sits an octave
  /// below the pitch it sounds.
  int get octaveShift => _active?.octaveShift ?? 0;

  /// Clears all span state. Call before re-walking the same staff.
  void reset() {
    _active = null;
    _activeEndMeasure = null;
  }

  /// Advances the tracker to [element] (which lives in measure [measureIndex])
  /// and returns the displacement in force AT that element.
  ///
  /// An [OctaveMark] displaces itself too — the returned value for the mark
  /// element is the new span's shift — but the mark has no printed pitch, so
  /// that is inconsequential; what matters is that every following note in the
  /// span sees it.
  int advance(MusicalElement element, {int measureIndex = 0}) {
    final end = _activeEndMeasure;
    if (_active != null && end != null && measureIndex > end) {
      _active = null;
      _activeEndMeasure = null;
    }
    if (element is OctaveMark) {
      _active = element;
      _activeEndMeasure = element.endMeasure > element.startMeasure
          ? element.endMeasure
          : measureIndex;
    }
    return octaveShift;
  }
}

/// One staff-scoped activation of an [OctaveMark] on the musical timeline.
///
/// [onset] is measured in whole notes from the start of the staff — the same
/// absolute clock `PositionedElement.onset` carries, so `LayoutEngine` (which
/// builds the timeline from the model, before anything is positioned) and
/// `StaffRenderer` (which rebuilds it from a positioned list) produce
/// identical events for the same music.
///
/// A producer using a per-measure clock instead would still be self-consistent:
/// [OctaveSpanTimeline] only ever compares onsets of events sharing the same
/// [measureIndex], and within one bar the two conventions differ by a constant.
/// Do not MIX the two in one timeline.
class OctaveSpanEvent {
  /// Index of the measure the mark was written in.
  final int measureIndex;

  /// Musical time at which the bracket starts, on the clock described above.
  final double onset;

  /// The mark itself.
  final OctaveMark mark;

  const OctaveSpanEvent(this.measureIndex, this.onset, this.mark);

  @override
  String toString() =>
      'OctaveSpanEvent(m$measureIndex @ $onset: ${mark.text})';
}

/// Resolves WHICH [OctaveMark] is in force at a given point of MUSICAL TIME on
/// a staff, for every voice at once.
///
/// ## Why this exists: the octave bracket is a property of the STAFF
///
/// Wave 1 gave [OctaveMark] its first reader by walking the element stream in
/// document order with an [OctaveSpanTracker]. That is exact for a monophonic
/// staff and WRONG for a polyphonic one, because `MultiVoiceMeasure`
/// serialises voice 1 entirely before voice 2. Measured on a two-voice bar
/// whose voices both hold a C5 (staff position 1 under a treble clef):
///
/// | mark written in | voice 1 shift | voice 2 shift |
/// |-----------------|---------------|---------------|
/// | voice 1         | +1            | +1            |
/// | voice 2         | 0             | +1            |
///
/// The same musical marking produced two different engravings depending only
/// on which voice the author happened to type it in.
///
/// **The semantics chosen here is (b): the bracket belongs to the STAFF.**
/// A mark written in any voice displaces every voice of that staff, from the
/// musical instant it starts. That is what both interchange formats say:
///
/// * **MusicXML.** `<octave-shift>` is a `<direction-type>`, and a
///   `<direction>` is placed on a STAFF (`<staff>`); its optional `<voice>`
///   child exists to say which voice the direction is *typeset with* — the
///   spec's own wording is that it is used "for cases where the direction
///   applies to a specific voice", and every mainstream exporter (Finale,
///   Sibelius, MuseScore) emits an 8va without one. A reader that scoped the
///   bracket to a voice would move the notes of one hand and leave the other
///   behind on the same staff.
/// * **MEI.** `<octave>` is a `controlEvent` whose `@staff` is what anchors
///   it; `@layer` is optional and, when absent, the event applies to ALL
///   layers of that staff (MEI Guidelines, "Control events"). Our [OctaveMark]
///   carries no voice/layer field at all, so it cannot express the narrowed
///   form even in principle — it is unambiguously the staff-wide case.
///
/// Scoping it to a voice (option (a)) was rejected for a third reason: it
/// would make a bracket un-writable for the common case. A pianist's 8va over
/// a two-voice right hand is one bracket over both voices; under (a) the
/// author would have to duplicate the mark into every voice, and forgetting
/// one would print half the texture an octave away from the other half.
///
/// ## The rule
///
/// 1. A mark takes effect at the ONSET where it appears in its own voice and
///    stays in force for **every** voice from that instant on. Notes sounding
///    strictly earlier in the bar — in any voice — keep the previous
///    displacement, which preserves the mid-measure behaviour
///    [OctaveSpanTracker] documents for a monophonic staff.
/// 2. A later mark simply replaces the earlier one (the model has no nesting).
/// 3. A span ends after [OctaveMark.endMeasure], or at the end of the measure
///    it was written in when `endMeasure <= startMeasure` — the degenerate
///    span both importers produce. See [OctaveSpanTracker] for why.
///
/// The timeline is immutable and can be queried in any order, which is what
/// lets a polyphonic bar be laid out voice by voice and still agree with
/// itself.
class OctaveSpanTimeline {
  /// Events sorted by (measureIndex, onset), stable in insertion order for
  /// ties — so two marks starting on the same beat in different voices resolve
  /// to the LAST one collected, exactly as a document-order walk would.
  final List<OctaveSpanEvent> _events;

  /// Empty timeline: [shiftAt] is always 0.
  static const OctaveSpanTimeline empty = OctaveSpanTimeline._(
    <OctaveSpanEvent>[],
  );

  const OctaveSpanTimeline._(this._events);

  /// Builds a timeline from [events], which may arrive in any order.
  factory OctaveSpanTimeline(Iterable<OctaveSpanEvent> events) {
    final list = List<OctaveSpanEvent>.from(events);
    if (list.isEmpty) return empty;
    // Stable sort: `List.sort` is not guaranteed stable, so ties are broken by
    // the original index to keep "last collected wins" deterministic.
    final indexed = <MapEntry<int, OctaveSpanEvent>>[
      for (var i = 0; i < list.length; i++) MapEntry(i, list[i]),
    ];
    indexed.sort((a, b) {
      final m = a.value.measureIndex.compareTo(b.value.measureIndex);
      if (m != 0) return m;
      final o = a.value.onset.compareTo(b.value.onset);
      if (o != 0) return o;
      return a.key.compareTo(b.key);
    });
    return OctaveSpanTimeline._([for (final e in indexed) e.value]);
  }

  /// True when no [OctaveMark] exists anywhere on the staff.
  bool get isEmpty => _events.isEmpty;

  /// Number of activations on the timeline (diagnostics and tests).
  int get length => _events.length;

  /// Tolerance for the onset comparison: a mark and the note it opens on carry
  /// the same onset, and both are accumulated by repeated addition of
  /// `Duration.realValue`, so an exact `<=` would be at the mercy of the last
  /// bit.
  static const double _onsetEpsilon = 1e-9;

  /// The mark in force at [onset] whole notes into measure [measureIndex], or
  /// null outside every span.
  OctaveMark? markAt({required int measureIndex, required double onset}) {
    OctaveSpanEvent? best;
    for (final event in _events) {
      if (event.measureIndex > measureIndex) break;
      if (event.measureIndex == measureIndex &&
          event.onset > onset + _onsetEpsilon) {
        break;
      }
      best = event;
    }
    if (best == null) return null;
    // Rule 3: the span dies at the end of its last measure. A dead span is not
    // replaced by an older one — a later mark REPLACED that older mark when it
    // started, so there is nothing to fall back to.
    final end = best.mark.endMeasure > best.mark.startMeasure
        ? best.mark.endMeasure
        : best.measureIndex;
    if (measureIndex > end) return null;
    return best.mark;
  }

  /// Displacement in octaves in force at that point (0 outside every span).
  ///
  /// Sign convention is identical to `Clef.octaveShift` and to
  /// [OctaveSpanTracker.octaveShift]: 8va is `+1` and prints 7 half-space
  /// positions LOWER.
  int shiftAt({required int measureIndex, required double onset}) =>
      markAt(measureIndex: measureIndex, onset: onset)?.octaveShift ?? 0;
}
