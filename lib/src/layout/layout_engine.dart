// lib/src/layout/layout_engine.dart
// Corrected implementation: Spacing melhorado and beaming corrigido
// Suporte a Hierarchical BoundingBox added
// Refactoring pass: Using tipos of the core/

import 'package:flutter/material.dart';
import 'package:flutter_notemus/core/core.dart';
import 'package:flutter_notemus/src/beaming/beam_analyzer.dart';
import 'package:flutter_notemus/src/beaming/beam_group.dart';
import 'package:flutter_notemus/src/layout/beam_grouper.dart';
import 'package:flutter_notemus/src/layout/measure_validator.dart'; // ✅ ADICIONADO
import 'package:flutter_notemus/src/rendering/accidental_resolver.dart';
import 'package:flutter_notemus/src/rendering/renderers/chord_renderer.dart';
import 'package:flutter_notemus/src/rendering/renderers/rest_renderer.dart';
import 'package:flutter_notemus/src/rendering/staff_position_calculator.dart';
import 'package:flutter_notemus/src/rendering/smufl_positioning_engine.dart';
import 'package:flutter_notemus/src/smufl/smufl_metadata_loader.dart'; // ✅ ADICIONADO
import 'package:flutter_notemus/src/rendering/text_font.dart';
import 'package:flutter_notemus/src/utils/lru_cache.dart';
import 'onset_grid.dart';
import 'tuplet_grid.dart';
import 'spacing/spacing.dart' as spacing;

class PositionedElement {
  final MusicalElement element;
  final Offset position;
  final int system;

  /// Voice number (1, 2, ...) in polyphonic contexts. Null = single voice.
  final int? voiceNumber;

  /// Musical onset of this element, measured in whole notes from the start of
  /// the staff (a quarter note is 0.25). Non-rhythmic elements inherit the
  /// onset of the position they occupy.
  ///
  /// This is the shared time coordinate that lets several staves be aligned on
  /// one grid (see `GrandStaffPainter`): two events with the same onset must
  /// end up at the same X, whatever their individual spacing needs.
  final double onset;

  /// Index of the measure this element belongs to, or -1 when unknown.
  /// Used for measure numbering and for future selection by bar.
  final int measureIndex;

  /// Y of the staff's MIDDLE LINE, **in the coordinate space of the
  /// [LayoutEngine] that produced this element**.
  ///
  /// [position] does not mean the same thing for every element: for a [Note] it
  /// is the NOTEHEAD (so the pitch is readable straight off it), while for a
  /// [Chord], a [Clef] or a [Barline] it is the staff baseline. That asymmetry
  /// is a genuine trap — `ScoreHitTester` built a chord's box around
  /// `position.dy` and so drew it around the STAFF while the chord's noteheads
  /// were an octave above it, making high chords unclickable.
  ///
  /// This field removes that ambiguity: whatever `position` means for a given
  /// element, the staff it belongs to is always right here.
  ///
  /// ## It is NOT a screen coordinate on a grand staff
  ///
  /// Under a plain `LayoutEngine` the value is the absolute Y of the system's
  /// middle line and [system] counts systems: measured on a 12-system staff,
  /// `staffBaselineY` steps 60 / 180 / 300 / … / 1380 while `system` goes
  /// 0..11.
  ///
  /// Under `GrandStaffPainter.alignedSystem()` it is neither. Each staff of
  /// each system is laid out by its OWN `LayoutEngine` over a one-system
  /// sub-staff, so every one of them reports `staffBaselineY == 60.0` and
  /// `system == 0` — 3 staves x 12 systems, 36 lists, all identical — and
  /// `paint()` then translates the canvas to put each list where it belongs.
  /// Measured consequence: a `ScoreHitTester` built over `alignedSystem(0)[1]`
  /// hits at the LOCAL point (116.2, 96.0) and misses at the SCREEN point
  /// (142.6, 228.0); the delta is exactly 132.0 px — one `staffGap`.
  ///
  /// So: a consumer that mixes several engines' output (hit-testing a grand
  /// staff, exporting a page) must add the same translation the painter
  /// applies before comparing this value — or any [position] — against a point
  /// in screen space.
  final double staffBaselineY;

  PositionedElement(
    this.element,
    this.position, {
    this.system = 0,
    this.voiceNumber,
    this.onset = 0.0,
    this.measureIndex = -1,
    this.staffBaselineY = 0.0,
  });

  /// A copy of this element placed at [newPosition], keeping every other field.
  ///
  /// The post-layout passes (justification, full-bar-rest centring, cross-voice
  /// displacement, multi-staff alignment) all move elements horizontally, and
  /// each used to spell the copy out by hand — so adding a field to this class
  /// meant finding every one of them or silently losing it.
  PositionedElement movedTo(Offset newPosition) => PositionedElement(
        element,
        newPosition,
        system: system,
        voiceNumber: voiceNumber,
        onset: onset,
        measureIndex: measureIndex,
        staffBaselineY: staffBaselineY,
      );

  /// Stable signature used to cheaply compare large positioned element lists.
  ///
  /// The signature is **structural**, not identity based: laying the same
  /// [Staff] out twice must produce the same number, otherwise `shouldRepaint`
  /// can never return false and viewport culling saves nothing. (It used to mix
  /// in `element.hashCode`, which is identity for musical elements, and the
  /// engine replaced beamed notes with fresh objects on every run.)
  static int computeSignature(List<PositionedElement> elements) {
    int hash = 17;
    for (final item in elements) {
      hash = Object.hash(
        hash,
        structuralHash(item.element),
        item.position.dx,
        item.position.dy,
        item.system,
        item.voiceNumber,
        item.onset,
        item.measureIndex,
      );
    }
    return Object.hash(hash, elements.length);
  }

  /// Content-based hash for a musical element, so two runs over the same model
  /// agree even though the objects are compared by identity elsewhere.
  static int structuralHash(MusicalElement element) {
    if (element is Note) {
      return Object.hash(
        'Note',
        element.pitch,
        element.duration.type,
        element.duration.dots,
        element.beam,
        element.tie,
        element.voice,
        element.articulations.length,
        element.ornaments.length,
        element.syllables?.length ?? 0,
      );
    }
    if (element is Rest) {
      return Object.hash('Rest', element.duration.type, element.duration.dots);
    }
    if (element is Chord) {
      var h = Object.hash('Chord', element.duration.type,
          element.duration.dots, element.beam, element.voice);
      for (final n in element.notes) {
        h = Object.hash(h, n.pitch);
      }
      return h;
    }
    if (element is Clef) {
      return Object.hash('Clef', element.clefType);
    }
    if (element is KeySignature) {
      return Object.hash('Key', element.count, element.previousCount);
    }
    if (element is TimeSignature) {
      return Object.hash('Time', element.numerator, element.denominator);
    }
    if (element is Barline) {
      return Object.hash('Barline', element.type);
    }
    if (element is Tuplet) {
      return Object.hash('Tuplet', element.actualNotes, element.normalNotes,
          element.elements.length);
    }
    // Fall back to the runtime type: enough to notice a structural change,
    // and still deterministic across runs.
    return element.runtimeType.hashCode;
  }
}

/// Layout output bundle with positioned elements and deterministic signature.
class LayoutResult {
  final List<PositionedElement> elements;
  final int signature;

  const LayoutResult({required this.elements, required this.signature});
}

class LayoutCursor {
  final double staffSpace;
  final double availableWidth;
  final double systemMargin;
  final double systemHeight;

  // Mapas for capturar positions das notes (for beaming)
  final Map<Note, double>? noteXPositions;
  final Map<Note, int>? noteStaffPositions;
  final Map<Note, double>? noteYPositions; // ✅ NOVO: Y absoluto em pixels

  /// 8va/8vb displacement applied to each note, so the renderers can reuse the
  /// engine's answer instead of re-walking the element stream. That matters
  /// because `StaffRenderer.renderStaff` is sometimes handed ONE SYSTEM at a
  /// time (`ScoreRasterizer` does exactly that): a tracker restarted per system
  /// would lose a span that opened on the previous one, and the notehead would
  /// then be drawn an octave away from the position layout gave it.
  final Map<Note, int>? noteOctaveShifts;

  /// Resolves a chord's horizontal geometry (cluster offsets + accidental
  /// column block) so a chord's notes are registered at the X they are DRAWN
  /// at, not all at the chord origin. Supplied by the engine, which owns the
  /// SMuFL metadata and the accidental decisions.
  ///
  /// Measured before this existed: `C5-D5-E5` (two seconds) and `C5-E5-G5` (no
  /// seconds) both put all three `noteXPositions` at the same X, while
  /// `ChordRenderer` displaced the second-cluster noteheads by a full notehead
  /// width — so beams, hit-testing and the public position API all pointed at
  /// a place with no notehead in it.
  final ChordGeometry Function(
    Chord chord,
    Clef clef,
    int extraOctaveShift,
    int? voiceNumber,
  )? chordGeometry;

  double _currentX;
  double _currentY;
  int _currentSystem;

  /// Index of the measure currently being laid out (set by the engine).
  int currentMeasureIndex = -1;
  bool _isFirstMeasureInSystem;
  Clef? _currentClef; // ✅ NOVO: Rastrear clave atual

  /// The 8va/8vb bracket span in force at the cursor, tracked exactly the
  /// way [_currentClef] is: both axes displace only WHERE a pitch is PRINTED
  /// (ADR-003), and both therefore have to be known at the moment a note is
  /// converted to a staff position. The clef axis was wired up; the bracket
  /// axis was not, so every one of 8va/8vb/15ma/15mb/22da/22db printed C6 at
  /// staffPosition 8 — identical to no mark at all.
  ///
  /// Used only when [octaveTimeline] is empty — i.e. when the caller built a
  /// cursor by hand without pre-scanning the staff for marks. The timeline is
  /// what the engine itself supplies, because a single-pass tracker gets a
  /// polyphonic bar wrong (see [OctaveSpanTimeline]).
  final OctaveSpanTracker _octaveSpan = OctaveSpanTracker();

  /// Staff-scoped bracket timeline, resolved by (measure, onset) rather than
  /// by document position.
  ///
  /// The bracket belongs to the STAFF, not to one voice, so it cannot be
  /// resolved by walking a serialised element stream: `MultiVoiceMeasure`
  /// emits voice 1 in full before voice 2, and a tracker therefore gave the
  /// same marking two different meanings depending on which voice it was typed
  /// in (measured: mark in voice 1 -> both voices +1; mark in voice 2 ->
  /// voice 1 got 0). [OctaveSpanTimeline] carries the reasoning and the
  /// MusicXML/MEI citations.
  final OctaveSpanTimeline octaveTimeline;

  /// Displacement resolved for the element most recently passed to
  /// [addElement], so [activeOctaveShift] answers for the same point the
  /// caller just placed.
  int _activeOctaveShift = 0;

  LayoutCursor({
    required this.staffSpace,
    required this.availableWidth,
    required this.systemMargin,
    this.systemHeight = 10.0,
    this.noteXPositions,
    this.noteStaffPositions,
    this.noteYPositions, // ✅ NOVO
    this.noteOctaveShifts,
    this.octaveTimeline = OctaveSpanTimeline.empty,
    this.chordGeometry,
  }) : _currentX = systemMargin,
       _currentY =
           staffSpace *
           5.0, // CORREÇÃO CRÃƒÂTICA: Baseline é staffSpace * 5, não * 4
       _currentSystem = 0,
       _isFirstMeasureInSystem = true;

  double get currentX => _currentX;
  double get currentY => _currentY;
  int get currentSystem => _currentSystem;
  bool get isFirstMeasureInSystem => _isFirstMeasureInSystem;
  double get usableWidth => availableWidth - (systemMargin * 2);

  /// Clef currently in force at the cursor, or null before the first clef.
  Clef? get activeClef => _currentClef;

  /// Octave displacement contributed by the active [OctaveMark] bracket at the
  /// point of the last [addElement] (0 outside every span). See
  /// [OctaveSpanTimeline] for the activation rule and for why an imported span
  /// ends at its own barline.
  int get activeOctaveShift => _activeOctaveShift;

  void advance(double width) {
    _currentX += width;
  }

  /// Set cursor X to an absolute position (used for multi-voice layout)
  void setX(double x) {
    _currentX = x;
  }

  bool needsSystemBreak(double measureWidth) {
    if (_isFirstMeasureInSystem) return false;
    return _currentX + measureWidth > systemMargin + usableWidth;
  }

  void startNewSystem() {
    _currentSystem++;
    _currentX = systemMargin;
    _currentY += systemHeight * staffSpace;
    _isFirstMeasureInSystem = true;
  }

  void addBarline(List<PositionedElement> elements, {double onset = 0.0}) {
    elements.add(
      PositionedElement(
        Barline(),
        Offset(_currentX, _currentY),
        system: _currentSystem,
        onset: onset,
        measureIndex: currentMeasureIndex,
        staffBaselineY: _currentY,
      ),
    );
    advance(LayoutEngine.barlineTrailingSpace * staffSpace);
  }

  /// Adds double barline final (end of the peça)
  void addDoubleBarline(List<PositionedElement> elements,
      {double onset = 0.0}) {
    elements.add(
      PositionedElement(
        Barline(type: BarlineType.final_),
        Offset(_currentX, _currentY),
        system: _currentSystem,
        onset: onset,
        measureIndex: currentMeasureIndex,
        staffBaselineY: _currentY,
      ),
    );
    advance(LayoutEngine.barlineTrailingSpace * staffSpace);
  }

  void endMeasure() {
    _isFirstMeasureInSystem = false;
    // Padding agora Applied Before of the barline no layout principal
  }

  void addElement(
    MusicalElement element,
    List<PositionedElement> elements, {
    int? voiceNumber,
    double onset = 0.0,
  }) {
    // Track the clef currently in force. Because system elements are now laid
    // out in document order (a mid-measure clef change stays where the author
    // put it), the notes before such a change keep the previous clef.
    if (element is Clef) {
      _currentClef = element;
    }

    // The bracket takes effect at the musical INSTANT the author put it at,
    // and from there it applies to every voice on the staff — so it is
    // resolved against [octaveTimeline] by (measure, onset), not by walking
    // this cursor's serialised element order. Notes sounding earlier in the
    // bar keep the previous displacement, exactly as before; what changes is
    // that a mark written in voice 2 now reaches voice 1 as well.
    //
    // The single-pass tracker remains as the fallback for a cursor built
    // without a timeline (a hand-made cursor in a test), where document order
    // is the only information available.
    final int extraOctaveShift;
    if (octaveTimeline.isEmpty) {
      extraOctaveShift = _octaveSpan.advance(
        element,
        measureIndex: currentMeasureIndex,
      );
    } else {
      extraOctaveShift = octaveTimeline.shiftAt(
        measureIndex: currentMeasureIndex,
        onset: onset,
      );
    }
    _activeOctaveShift = extraOctaveShift;

    // A plain (non-MultiVoice) measure can still carry voice-tagged notes —
    // that is exactly what the MusicXML importer produces. Derive the voice
    // from the element when the caller did not pass one, otherwise cross-voice
    // collision resolution and voice-based selection silently skip them.
    voiceNumber ??= element is Note
        ? element.voice
        : (element is Chord ? element.voice : null);

    if (element is Chord && _currentClef != null) {
      // Cluster displacement of each notehead, from the SAME resolver
      // `ChordRenderer.render` draws with. Registering every note at the chord
      // origin used to make beam geometry, the grand-staff onset aligner and
      // hit-testing all point one notehead width away from the note they meant
      // whenever the chord contained a second.
      final geometry = chordGeometry?.call(
        element,
        _currentClef!,
        extraOctaveShift,
        voiceNumber,
      );
      for (final note in element.notes) {
        final staffPosition = StaffPositionCalculator.calculate(
          note.pitch,
          _currentClef!,
          extraOctaveShift: extraOctaveShift,
        );
        final noteY = StaffPositionCalculator.toPixelY(
          staffPosition,
          staffSpace,
          _currentY,
        );
        noteXPositions?[note] = _currentX + (geometry?.offsetOf(note) ?? 0.0);
        noteStaffPositions?[note] = staffPosition;
        noteYPositions?[note] = noteY;
        noteOctaveShifts?[note] = extraOctaveShift;
      }
      elements.add(
        PositionedElement(
          element,
          Offset(_currentX, _currentY),
          system: _currentSystem,
          voiceNumber: voiceNumber,
          onset: onset,
          measureIndex: currentMeasureIndex,
          staffBaselineY: _currentY,
        ),
      );
      return;
    }

    double elementY = _currentY;

    if (element is Note && _currentClef != null) {
      noteXPositions?[element] = _currentX;
      final staffPosition = StaffPositionCalculator.calculate(
        element.pitch,
        _currentClef!,
        extraOctaveShift: extraOctaveShift,
      );
      noteStaffPositions?[element] = staffPosition;
      final noteY = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        _currentY,
      );
      noteYPositions?[element] = noteY;
      noteOctaveShifts?[element] = extraOctaveShift;
      elementY = noteY;
    }

    elements.add(
      PositionedElement(
        element,
        Offset(_currentX, elementY),
        system: _currentSystem,
        voiceNumber: voiceNumber,
        onset: onset,
        measureIndex: currentMeasureIndex,
        staffBaselineY: _currentY,
      ),
    );
  }
}

class LayoutEngine {
  final Staff staff;
  final double availableWidth;
  final double staffSpace;
  final SmuflMetadata? metadata; // ✅ Tipagem correta aplicada

  // System de Intelligent spacing
  late final spacing.IntelligentSpacingEngine _spacingEngine;
  late final spacing.SpacingPreferences _spacingPreferences;

  // System de Beaming Avançado
  late final BeamAnalyzer _beamAnalyzer;
  final Map<Note, double> _noteXPositions = {};
  final Map<Note, int> _noteOctaveShifts = {};
  final Map<Note, int> _noteStaffPositions = {};
  final Map<Note, double> _noteYPositions =
      {}; // ✅ NOVO: Y absoluto em pixels
  final List<AdvancedBeamGroup> _advancedBeamGroups = [];

  /// Within-measure accidental display decision per note (Behind Bars rule),
  /// resolved from the model so layout width and rendering agree.
  late final Map<Note, AccidentalDisplay> accidentalDecisions =
      AccidentalResolver.resolve(staff.measures);

  /// Beam membership of every note that lives INSIDE a [Tuplet], resolved from
  /// the model (identity-keyed). Notes outside a tuplet are absent — those live
  /// in the sibling map [beams] and reach the geometry through `BeamAnalyzer`.
  ///
  /// This is the layout's answer to finding M-26: the beam decision for a
  /// tuplet used to be taken by `TupletRenderer` DURING PAINT, and taken by
  /// writing [Note.beam] on the caller's own objects. Measured: a `Staff`
  /// holding a triplet of eighths exported 1620 characters of MusicXML with 0
  /// `<beam>` tags; after a single `ScoreRasterizer.renderStaffToPng` the same
  /// `Staff` exported 1735 characters with 3 `<beam>` tags. The export a user
  /// got therefore depended on whether the score had been displayed first.
  ///
  /// The decision now belongs to the layout and is published as a VALUE. The
  /// renderer reads this map; nothing writes to the model, so painting a score
  /// leaves it byte-for-byte identical.
  late final Map<Note, BeamType> tupletBeams = _resolveTupletBeams();

  Map<Note, BeamType> _resolveTupletBeams() {
    final result = Map<Note, BeamType>.identity();

    void walk(List<MusicalElement> elements) {
      for (final element in elements) {
        if (element is! Tuplet) continue;
        final plan = TupletBeamPlan.of(element.elements);
        for (var i = 0; i < element.elements.length; i++) {
          final child = element.elements[i];
          final beam = i < plan.beams.length ? plan.beams[i] : null;
          if (child is Note && beam != null) result[child] = beam;
        }
        walk(element.elements); // nested tuplets decide their own group
      }
    }

    for (final measure in staff.measures) {
      walk(measure.elements);
      if (measure is MultiVoiceMeasure) {
        for (final voice in measure.sortedVoices) {
          walk(voice.elements);
        }
      }
    }
    return result;
  }

  /// Denominator of the tuplet legibility scale, per [Tuplet]
  /// (identity-keyed), computed over the whole MEASURE the tuplet lives in.
  ///
  /// The value is `min` of [TupletGrid.smallestRawLeafSpaces] over every tuplet
  /// of that measure, and it is what `TupletGrid.slotWidths` divides
  /// `TupletGrid.minimumSlotSpaces` by. Nested tuplets are keyed too, with
  /// their parent's number, so a recursive call cannot pick a different scale.
  ///
  /// Findings M-08 / M-31. The grid used to take that minimum over ONE group,
  /// which meant the legibility floor was reached by every group independently
  /// and no two groups in a bar could be told apart. Measured at
  /// `staffSpace = 12` on a 4/4 bar holding a 3:2 triplet of eighths and a 3:2
  /// triplet of sixteenths: both came out at **1.9000 SS per slot, ratio
  /// 1.0000**, where the eighths should be √2 = 1.4142 wider per note. With one
  /// scale per measure they measure **2.6870 SS** and **1.9000 SS**, ratio
  /// **1.4142**, and the narrowest slot is still exactly on the floor so the
  /// ink gap between adjacent noteheads is unchanged at 0.750 SS.
  ///
  /// This is published as a VALUE for the same reason [tupletBeams] is
  /// (ADR-005): `TupletRenderer` cannot see the measure — it is handed one
  /// tuplet at a time — so if it re-derived a scale it would derive the
  /// per-group one and draw a different grid from the one the layout reserved
  /// space for. `StaffRenderer` passes this map's entry into
  /// `TupletRenderer.render`.
  ///
  /// A measure whose narrowest tuplet note is a quarter or longer maps to a
  /// value at or above [TupletGrid.minimumSlotSpaces], which makes the scale
  /// exactly 1.0 — the raw law, untouched.
  late final Map<Tuplet, double> tupletContextFloor =
      _resolveTupletContextFloors();

  /// The measure-wide legibility denominator for [tuplet], or null when the
  /// tuplet is not part of this staff (a renderer driven without a layout for
  /// this exact model). Null means "no context": the grid then falls back to
  /// the tuplet's own smallest leaf.
  double? tupletContextFloorFor(Tuplet tuplet) => tupletContextFloor[tuplet];

  Map<Tuplet, double> _resolveTupletContextFloors() {
    final result = Map<Tuplet, double>.identity();

    void collect(List<MusicalElement> elements, List<Tuplet> into) {
      for (final element in elements) {
        if (element is! Tuplet) continue;
        into.add(element);
        collect(element.elements, into);
      }
    }

    for (final measure in staff.measures) {
      final tuplets = <Tuplet>[];
      collect(measure.elements, tuplets);
      if (measure is MultiVoiceMeasure) {
        for (final voice in measure.sortedVoices) {
          collect(voice.elements, tuplets);
        }
      }
      if (tuplets.isEmpty) continue;

      var smallest = double.infinity;
      for (final tuplet in tuplets) {
        final own = TupletGrid.smallestRawLeafSpaces(tuplet);
        if (own < smallest) smallest = own;
      }
      if (!smallest.isFinite) continue;
      for (final tuplet in tuplets) {
        result[tuplet] = smallest;
      }
    }
    return result;
  }

  /// Beam membership of every note OUTSIDE a tuplet, resolved from the model
  /// (identity-keyed) - the sibling of [tupletBeams] for ordinary beam groups.
  ///
  /// This is the other half of finding M-26. `_processBeamsWithAnacrusis` used
  /// to stamp the answer onto the caller's own [Note] objects with
  /// `note.beam = ...`. Two things were measured on that:
  ///
  /// * the MEASURING (dry-run) pass writes every note a second time - 32 writes
  ///   for 16 notes, measure 0 written in full again before measure 1 starts;
  /// * a `Staff` exported differently depending on whether it had been laid out
  ///   or displayed. Two bars of loose eighths: MusicXML **3346 -> 3970
  ///   characters**, `<beam>` tags **0 -> 16**, and the JSON export moved with
  ///   it. Whether a user got beam tags in their file depended on whether the
  ///   score happened to have been rendered first.
  ///
  /// The decision is a VALUE now. Nothing writes to the model, so
  /// `staffToMusicXML` and `staffToJson` are byte-identical before and after
  /// [layout] and before and after `ScoreRasterizer.renderStaffToPng`.
  ///
  /// [Note.beam] is still honoured on INPUT - that is ADR-001's contract and
  /// `BeamingMode.manual` rests on it. Read the effective beam through
  /// [beamOf], never off the model directly: the map holds only the notes that
  /// landed in a VALID group, and everything else keeps the author's own hint,
  /// exactly as the in-place version left it.
  late final Map<Note, BeamType> beams = _resolveOrdinaryBeams();

  /// The beam in force for [note]: the engine's decision when it made one, the
  /// author's [Note.beam] hint otherwise.
  ///
  /// Renderers MUST go through here. `note.beam` alone is the author hint only
  /// and no longer carries the engine's answer.
  ///
  /// BOTH engine maps are consulted, and the [tupletBeams] half was missing
  /// until the 2.7.2 sign-off. While it was, this method — advertised as "the
  /// only supported read" — returned `null` for exactly the notes
  /// [tupletBeams] exists to describe. Measured on a 3:2 triplet of eighths
  /// after [layout]: `beams[first]` `null`, `tupletBeams[first]`
  /// `BeamType.start`, `beamOf(first)` `null`. Nothing looked broken only
  /// because `TupletRenderer` reads [tupletBeams] directly; every other caller
  /// — `TupletBracket.shouldShow`, `ScoreHitTester`, user code — silently got
  /// the wrong answer, and `shouldShow(notes, beamOf: engine.beamOf)` printed a
  /// bracket over a fully beamed triplet because of it.
  ///
  /// The two maps are DISJOINT by construction: [_resolveOrdinaryBeams] walks
  /// measure/voice elements and [_resolveTupletBeams] walks only `Tuplet`
  /// children, so no note is in both and the order between them is arbitrary.
  /// Folding the tuplet map in therefore changes no answer for a note outside a
  /// tuplet — verified against the full suite and all 53 goldens, none of which
  /// moved.
  BeamType? beamOf(Note note) => beams[note] ?? tupletBeams[note] ?? note.beam;

  /// The meter a bar INHERITS from an earlier bar, keyed by identity — the
  /// sibling of [beams] and [tupletBeams] for time signatures.
  ///
  /// A map entry exists only for a measure that declares no [TimeSignature] of
  /// its own but follows one that does; a bar with its own meter, and every bar
  /// before the first meter of the staff, is absent. Read the effective meter
  /// through [timeSignatureOf], never off the model.
  ///
  /// **This is ADR-005 action item 8, and it was the worst engine-writes-the-
  /// model defect in the package because it changed whether a public API
  /// throws.** `layout()` used to do `measure.inheritedTimeSignature =
  /// timeSignatureToUse` on the CALLER'S OWN [Measure], and [Measure.add] reads
  /// that field to decide the bar's capacity. Measured on a two-bar staff whose
  /// bar 2 declares no meter of its own and already holds four quarters under
  /// an inherited 4/4:
  ///
  /// | | `m2.inheritedTimeSignature` | `m2.add(<fifth quarter>)` |
  /// |---|---|---|
  /// | fresh | `null` | accepted (5 elements) |
  /// | after `layout()` | `TimeSignature(4/4)` | **threw `MeasureCapacityException`** |
  ///
  /// So whether *building* a score succeeded depended on whether it had been
  /// *displayed* — the same category of defect as `Note.beam` (items 1-7), one
  /// layer more dangerous. The derivation is a VALUE now and nothing writes to
  /// the model, so a [Measure] is field-for-field identical before and after
  /// [layout] and after `ScoreRasterizer.renderStaffToPng`, and the fifth
  /// quarter is accepted in all three states.
  ///
  /// [Measure.inheritedTimeSignature] is still honoured on INPUT, exactly as
  /// [Note.beam] is: a caller may set it to opt a bar into preventive
  /// validation, and `GrandStaffPainter` sets it on the sub-measures IT builds
  /// so a system that starts mid-score keeps the meter declared before it. The
  /// walk therefore seeds itself from the first such hint it meets (see
  /// [_resolveInheritedTimeSignatures]).
  late final Map<Measure, TimeSignature> inheritedTimeSignatures =
      _resolveInheritedTimeSignatures();

  /// The meter in force for [measure]: its own [TimeSignature] when it declares
  /// one, otherwise the meter it inherits from an earlier bar.
  ///
  /// Every internal consumer goes through here. Returns `null` for a bar that
  /// is not under any meter (nothing has been declared yet), which is the
  /// signal to skip capacity validation rather than to assume 4/4.
  TimeSignature? timeSignatureOf(Measure measure) =>
      measure.timeSignature ?? inheritedTimeSignatures[measure];

  /// Walks the staff once and records, for each bar without its own meter, the
  /// meter last declared before it.
  ///
  /// Scans `Measure.elements` — not `allElements` — because that is exactly
  /// what the layout loop has always scanned for a [TimeSignature]: a meter is
  /// a measure-level attribute, never a per-voice one, so a `MultiVoiceMeasure`
  /// declares it in the shared `elements` list like any other bar. Keeping the
  /// same scan is what makes this refactor move ZERO ink.
  ///
  /// The `??=` seed is what keeps `GrandStaffPainter` correct. Its
  /// `_systemStaff` builds a sub-[Staff] that starts at measure `a`, so a meter
  /// declared BEFORE `a` is simply not in the sub-staff and cannot be
  /// re-derived from it; the painter restates it on the sub-measure's
  /// [Measure.inheritedTimeSignature] and this line picks it up as the running
  /// meter for the rest of the system. Without the seed, every wrapped system
  /// after the one holding the meter would validate nothing at all.
  Map<Measure, TimeSignature> _resolveInheritedTimeSignatures() {
    final result = Map<Measure, TimeSignature>.identity();
    TimeSignature? running;
    for (final measure in staff.measures) {
      final own = measure.timeSignature;
      if (own != null) {
        running = own;
        continue;
      }
      // Author/painter-supplied hint, honoured only while nothing has been
      // derived yet — a meter actually declared in the staff always wins.
      running ??= measure.inheritedTimeSignature;
      if (running != null) result[measure] = running;
    }
    return result;
  }

  Map<Note, BeamType> _resolveOrdinaryBeams() {
    final result = Map<Note, BeamType>.identity();
    for (final measure in staff.measures) {
      // Mirrors how layout consumes a bar: a `MultiVoiceMeasure` beams each
      // voice on its own (`_layoutMultiVoiceMeasure`) and never its shared
      // `elements`; a plain measure beams `elements`.
      if (measure is MultiVoiceMeasure) {
        for (final voice in measure.sortedVoices) {
          _resolveBeamsInto(result, voice.elements, measure);
        }
      } else {
        _resolveBeamsInto(result, measure.elements, measure);
      }
    }
    return result;
  }

  /// Per-child slot widths of [tuplet], in pixels.
  ///
  /// Always routed through here so the grid is asked for with the SAME
  /// accidental-aware context everywhere in the engine — and so `StaffRenderer`
  /// can hand [elementLeftExtent] to `TupletRenderer` and get the identical
  /// numbers. A grid queried without the left-extent callback in one place and
  /// with it in another is the divergence M-10 and M-11 are made of.
  List<double> _tupletSlots(Tuplet tuplet) => TupletGrid.slotWidths(
        tuplet,
        staffSpace,
        leftExtent: _leftExtent,
        noteheadAdvanceSpaces: noteheadBlackWidth,
        // The legibility scale is a property of the MEASURE, not of one
        // bracket — see [tupletContextFloor].
        contextSmallestLeafSpaces: tupletContextFloor[tuplet],
      );

  /// Horizontal compression applied to the rhythmic spacing of the measure
  /// currently being laid out.
  ///
  /// 1.0 = natural spacing. A measure whose natural width exceeds the usable
  /// line width is squeezed instead of being allowed to run off the canvas
  /// (F-05: a bar of 32 sixteenths at 400 px used to reach x = 1222 px, and the
  /// widget clipped everything past the viewport with no way to scroll to it).
  double _spacingScale = 1.0;

  /// True while a measure is being MEASURED into a throw-away cursor rather
  /// than laid out for real. Side effects on the engine's own state must be
  /// suppressed while it is set.
  bool _measuring = false;

  /// Resolved horizontal geometry of every chord seen in this pass, keyed by
  /// identity.
  ///
  /// The layout has to reserve exactly what `ChordRenderer` draws — the
  /// accidental COLUMNS (not one column) and the seconds displacement — and
  /// that depends on the clef and the 8va span in force, which
  /// [_getElementWidthSimple] and [_leftExtent] do not receive. The cache is
  /// therefore filled authoritatively by [LayoutCursor.addElement], which does
  /// know both, and read by everything else. Cleared at the top of every
  /// layout run.
  final Map<Chord, ChordGeometry> _chordGeometryCache = {};

  /// Clef and bracket displacement in force at the point widths are currently
  /// being asked for, used only to seed [_chordGeometryCache] on the FIRST
  /// query for a chord — the leading gap is measured just before the chord is
  /// placed, so no authoritative entry exists yet.
  Clef? _widthClef;
  int _widthOctaveShift = 0;

  /// Staff-wide bracket timeline for the run in progress. Rebuilt from the
  /// model at the top of [_layoutInternal], BEFORE anything is positioned —
  /// which is the whole point: a mark written in voice 2 has to be known
  /// before voice 1 is laid out.
  OctaveSpanTimeline _octaveTimeline = OctaveSpanTimeline.empty;

  /// Resolves and caches a chord's geometry. See [_chordGeometryCache].
  ChordGeometry _resolveChordGeometry(
    Chord chord,
    Clef clef,
    int extraOctaveShift,
    int? voiceNumber,
  ) {
    final geometry = ChordRenderer.resolveGeometry(
      chord: chord,
      clef: clef,
      metadata: metadata!,
      staffSpace: staffSpace,
      extraOctaveShift: extraOctaveShift,
      voiceNumber: voiceNumber,
      accidentalDecisions: accidentalDecisions,
    );
    _chordGeometryCache[chord] = geometry;
    return geometry;
  }

  /// Geometry of [chord], from the cache when the cursor has already placed it.
  ///
  /// The fallback resolves against [_widthClef] (treble before the first clef)
  /// and `chord.voice`; `Voice.validate` already requires a chord's own voice
  /// number to match its container, so the two agree wherever a
  /// `MultiVoiceMeasure` is well formed.
  ChordGeometry _chordGeometryOf(Chord chord) {
    final cached = _chordGeometryCache[chord];
    if (cached != null) return cached;
    return _resolveChordGeometry(
      chord,
      _widthClef ?? Clef(clefType: ClefType.treble),
      _widthOctaveShift,
      chord.voice,
    );
  }

  /// Collects the staff-wide [OctaveMark] activations from the MODEL.
  ///
  /// Onsets are absolute (whole notes from the start of the staff), matching
  /// the onset the layout stamps onto every `PositionedElement` — so the
  /// renderer can rebuild the identical timeline from a positioned list.
  ///
  /// A `MultiVoiceMeasure` contributes its shared block (marks written into
  /// `Measure.elements`, which the layout co-positions with the start of the
  /// bar's music) plus every voice, each on its own clock. That is what makes
  /// the bracket staff-scoped: whichever voice carries the mark, its onset
  /// lands on the one timeline all voices read.
  OctaveSpanTimeline _buildOctaveTimeline() {
    // Almost no score carries an 8va/8vb bracket, and building the timeline is
    // not free: it walks every element of every bar accumulating musical time
    // and asks each bar for its voice-aware duration. Measured on 12 800 bars
    // of eighths (119 468 elements) that walk cost 29 ms per layout pass and
    // produced an EMPTY timeline. The scan below is the same walk with the
    // arithmetic removed — a type test per element — and it exits at the first
    // mark, so a staff that does carry one pays for it twice at worst.
    if (!_staffHasOctaveMark()) return OctaveSpanTimeline.empty;

    final events = <OctaveSpanEvent>[];
    var base = 0.0;
    for (var i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      void collect(Iterable<MusicalElement> elements) {
        var onset = base;
        for (final element in elements) {
          if (element is OctaveMark) {
            events.add(OctaveSpanEvent(i, onset, element));
          }
          onset += _getRhythmicValue(element);
        }
      }

      collect(measure.elements);
      if (measure is MultiVoiceMeasure) {
        for (final voice in measure.sortedVoices) {
          collect(voice.elements);
        }
      }
      base += _measureMusicalDuration(measure);
    }
    return OctaveSpanTimeline(events);
  }

  /// Whether any bar of [staff] carries an [OctaveMark], in any voice.
  bool _staffHasOctaveMark() {
    for (final measure in staff.measures) {
      for (final element in measure.elements) {
        if (element is OctaveMark) return true;
      }
      if (measure is MultiVoiceMeasure) {
        for (final voice in measure.sortedVoices) {
          for (final element in voice.elements) {
            if (element is OctaveMark) return true;
          }
        }
      }
    }
    return false;
  }

  /// Lower bound for [_spacingScale]; past this the notes would collide, so the
  /// measure is allowed to overflow (the canvas is horizontally scrollable).
  static const double minimumSpacingScale = 0.35;

  /// Non-fatal layout problems recorded by the last [layout] /
  /// [layoutWithSignature] call. Empty when everything fitted.
  ///
  /// Same shape — a plain `List<String>` that the run clears and refills — as
  /// `MidiMapper`'s `MidiConversionResult.warnings`, `PdfExporter.warnings` and
  /// the parsers' `warnings`, so a host can surface all four the same way.
  ///
  /// Today it carries exactly one kind of entry: a measure whose natural width
  /// exceeded the line, whose compression therefore bottomed out at
  /// [minimumSpacingScale], and which STILL does not fit. That combination is
  /// the only case where the engine knowingly produces geometry wider than the
  /// viewport it was given.
  ///
  /// Why a diagnostic and not a behaviour change (finding M-46). Measured: 40
  /// whole notes written into a single 4/4 bar lay out as 43 elements on ONE
  /// system reaching `maxX = 1865.2 px` in a 900 px viewport — 2.07x. The
  /// engine used to THROW on that bar; it no longer does, and `MusicScore` and
  /// `GrandStaff` both scroll horizontally, so every note is reachable. Nothing
  /// better is available: compressing further would overlap noteheads (the
  /// floor exists for that reason) and breaking mid-measure is not something
  /// this engine does. What was still missing is that the engine had no way to
  /// SAY so — [overflowsAvailableWidth] answers "did it overflow" for the whole
  /// staff, with no measure named and no magnitude. A host that lays music out
  /// for a fixed-width medium (a PDF page, a printed part) needs to know which
  /// bar to re-bar or re-scale, and needs to know it without rasterising.
  ///
  /// The list is diagnostic ONLY: nothing in the engine reads it back, and the
  /// laid-out geometry is byte-for-byte what it was before this existed.
  final List<String> warnings = <String>[];

  /// Musical time, in whole notes, at which the measure being laid out starts.
  double _measureOnsetBase = 0.0;

  // Validation configuration (silent by default).
  final bool verboseValidation;

  /// Number of measures that precede this [staff] in the real score.
  ///
  /// A wrapped system is laid out from a SUB-staff, so its measure indices
  /// restart at 0. Rather than stamping the absolute number onto the caller's
  /// `Measure` objects (a surprising mutation of the model, and one that gets
  /// anacrusis numbering wrong), the offset is passed here and applied only
  /// when the measure carries no explicit `Measure.number`.
  final int measureNumberOffset;

  // Fix: SMuFL: Larguras agora consultadas dinamicamente of the metadata
  // Valores de fallback mantidos for compatibilidade
  static const double _gClefWidthFallback = 2.684;
  static const double _fClefWidthFallback = 2.756;
  static const double _cClefWidthFallback = 2.796;
  static const double _noteheadBlackWidthFallback = 1.18;
  static const double _accidentalSharpWidthFallback = 1.116;
  static const double _accidentalFlatWidthFallback = 1.18;

  /// Bravura advance widths of the rest glyphs, used only when the metadata is
  /// missing. Read off `bravura_metadata.json` (`glyphAdvanceWidths`).
  static const Map<String, double> _restAdvanceFallbacks = <String, double>{
    'restWhole': 1.132,
    'restHalf': 1.132,
    'restQuarter': 1.08,
    'rest8th': 1.0,
    'rest16th': 1.28,
    'rest32nd': 1.452,
    'rest64th': 1.696,
  };
  /// Space left AFTER a barline before the next measure's content, in staff
  /// spaces.
  ///
  /// NOTE: this is NOT SMuFL's `barlineSeparation` engraving default (0.4),
  /// which describes the gap BETWEEN the two strokes of a double/final barline
  /// and is read straight from the metadata by `BarlineRenderer`. The name
  /// collision was misleading, so the constant is now [barlineTrailingSpace];
  /// [barlineSeparation] stays as a deprecated alias.
  static const double barlineTrailingSpace = 2.5;

  @Deprecated(
    'Renamed to barlineTrailingSpace: this is not SMuFL barlineSeparation',
  )
  static const double barlineSeparation = barlineTrailingSpace;
  static const double legerLineExtension = 0.4;

  /// Size factor applied to a clef/key/meter change that happens INSIDE a bar
  /// (Behind Bars / Verovio draw those at cue size). Matches the 0.72 used by
  /// `StaffRenderer` when it detects a mid-system clef.
  static const double midMeasureCueScale = 0.72;

  /// Slot width, in staff spaces, of a quarter note inside a tuplet.
  ///
  /// Kept for source compatibility; the real grid is
  /// [TupletGrid], which BOTH this engine and `TupletRenderer` read. It used to
  /// be a flat step applied to every child regardless of duration, which is why
  /// a quarter and an eighth in the same triplet were 30.00 px apart each.
  @Deprecated('Use TupletGrid.quarterSlotSpaces; the grid is proportional now')
  static const double tupletInnerSpacing = TupletGrid.quarterSlotSpaces;

  // Intelligent spacing: Valores balanceados
  static const double systemMargin = 2.5;
  static const double measureMinWidth = 5.0;
  static const double noteMinSpacing =
      3.5; // Base para espaçamento entre notas
  static const double measureEndPadding =
      3.0; // Espaço adequado ANTES da barline (agora corrigido!)

  LayoutEngine(
    this.staff, {
    required this.availableWidth,
    this.staffSpace = 12.0,
    this.metadata,
    this.verboseValidation = false, // Silencioso por padrão
    this.measureNumberOffset = 0,
    spacing.SpacingPreferences? spacingPreferences,
  }) {
    // Initialise spacing engine
    _spacingPreferences = spacingPreferences ?? spacing.SpacingPreferences.normal;
    _spacingEngine = spacing.IntelligentSpacingEngine(
      preferences: _spacingPreferences,
    );
    _spacingEngine.initializeOpticalCompensator(staffSpace);

    // Initialise positioning engine for beaming
    // Validation: metadata can be null in some context
    if (metadata == null) {
      throw ArgumentError(
        'metadata é obrigatório para beaming avançado',
      );
    }
    final positioningEngine = SMuFLPositioningEngine(metadataLoader: metadata!);

    // Initialise system de beaming avançado
    _beamAnalyzer = BeamAnalyzer(
      staffSpace: staffSpace,
      noteheadWidth: noteheadBlackWidth * staffSpace,
      positioningEngine: positioningEngine,
    );
  }

  /// Effective accidental glyph after within-measure resolution: null = hide
  /// (alteration already in force), the natural glyph when reverting, else the
  /// note's own accidental.
  String? _effectiveAccidentalGlyph(Note note) {
    switch (accidentalDecisions[note] ?? AccidentalDisplay.show) {
      case AccidentalDisplay.hide:
        return null;
      case AccidentalDisplay.natural:
        return 'accidentalNatural';
      case AccidentalDisplay.show:
        return note.pitch.accidentalGlyph;
    }
  }

  /// Gets width de glifo dinamicamente of the metadata or Returns fallback
  double _getGlyphWidth(String glyphName, double fallback) {
    if (metadata != null && metadata!.hasGlyph(glyphName)) {
      return metadata!.getGlyphWidth(glyphName);
    }
    return fallback;
  }

  /// Width of the treble clef (G clef)
  double get gClefWidth => _getGlyphWidth('gClef', _gClefWidthFallback);

  /// Width of the bass clef (F clef)
  double get fClefWidth => _getGlyphWidth('fClef', _fClefWidthFallback);

  /// Width of the C clef (C clef)
  double get cClefWidth => _getGlyphWidth('cClef', _cClefWidthFallback);

  /// Width of the notehead preta
  double get noteheadBlackWidth =>
      _getGlyphWidth('noteheadBlack', _noteheadBlackWidthFallback);

  /// Advance width, in staff spaces, of the notehead a note of [type] is drawn
  /// with — straight from the SMuFL metadata, keyed on the same
  /// `DurationType.glyphName` the renderers pass to the glyph painter.
  ///
  /// This used to be `noteheadBlackWidth` for EVERY duration. Bravura's
  /// `noteheadBlack` advance is 1.18 staff spaces, but `noteheadWhole` is 1.688
  /// and `noteDoubleWhole` 2.396, so a semibreve and a breve were reserved a
  /// black notehead's worth of room and painted well past it. Measured at
  /// `staffSpace = 48`: a whole note painted 81 px into a 56.6 px reservation
  /// (24.5 px over, 0.51 staff spaces) and a breve 125 px (68.5 px over, 1.43
  /// staff spaces). Under compression that overrun becomes a collision, and
  /// because `elementWidth` is also the hit-test box and the raster's content
  /// width, the right edge of a whole note was unclickable and could be clipped
  /// at the page edge.
  ///
  /// Long values normally receive far more proportional space than their glyph
  /// needs, which is why this went unnoticed: it only bites when the bar is
  /// compressed, or at the two places that read the advance rather than the
  /// spacing.
  double _noteheadAdvance(DurationType type) =>
      _getGlyphWidth(type.glyphName, _noteheadBlackWidthFallback);

  /// Width of the sharp
  double get accidentalSharpWidth =>
      _getGlyphWidth('accidentalSharp', _accidentalSharpWidthFallback);

  /// Width of the flat
  double get accidentalFlatWidth =>
      _getGlyphWidth('accidentalFlat', _accidentalFlatWidthFallback);

  /// Display number for each measure index, honouring `Measure.number`
  /// (MEI `<measure @n>`) and falling back to 1-based position.
  ///
  /// The model has carried `Measure.number` since 2.x but nothing ever drew it;
  /// measure numbers are part of any professional score, so `StaffRenderer`
  /// now reads this map.
  Map<int, int> get measureNumbers {
    final result = <int, int>{};
    for (var i = 0; i < staff.measures.length; i++) {
      result[i] = staff.measures[i].number ?? (i + 1 + measureNumberOffset);
    }
    return result;
  }

  /// Returns os Advanced Beam Groups Calculados pelo last layout
  List<AdvancedBeamGroup> get advancedBeamGroups =>
      List.unmodifiable(_advancedBeamGroups);

  /// ✅ Expor positions X das notes for Rendering needs
  Map<Note, double> get noteXPositions => Map.unmodifiable(_noteXPositions);

  /// ✅ Expor positions Y das notes for Rendering de stems
  Map<Note, double> get noteYPositions => Map.unmodifiable(_noteYPositions);

  /// 8va/8vb bracket displacement the layout applied to each note.
  ///
  /// This is the SAME number that produced [noteStaffPositions], so a renderer
  /// that re-derives a notehead's Y from its pitch (they all do — a positioned
  /// element carries the system baseline, not the note's own Y) can look it up
  /// here and be guaranteed to agree with the layout, even when it is handed a
  /// single system whose bracket opened on an earlier one.
  Map<Note, int> get noteOctaveShifts => Map.unmodifiable(_noteOctaveShifts);

  /// Staff position of each note (0 = middle line, +1 per diatonic step up).
  ///
  /// Exposed so consumers that need to reason about a note's DRAWN geometry —
  /// stem direction, ledger lines, hit-test boxes — can do it from the same
  /// numbers the renderers use instead of re-deriving them and drifting.
  Map<Note, int> get noteStaffPositions =>
      Map.unmodifiable(_noteStaffPositions);

  /// Overrides a note's horizontal position after layout (used by the
  /// multi-staff aligner so beams follow re-aligned noteheads). No-op for notes
  /// the engine never positioned.
  void overrideNoteX(Note note, double x) {
    if (_noteXPositions.containsKey(note)) _noteXPositions[note] = x;
  }

  /// Re-anchors every note inside [tuplet] after the tuplet itself has moved.
  ///
  /// The multi-staff aligner remaps X for `Note` and `Chord` elements, but a
  /// tuplet is positioned as one element and its children live on their own
  /// grid, so they kept their PRE-ALIGNMENT coordinates on a grand staff — and
  /// beams, hit-testing and the public position API all read those.
  void overrideTupletX(Tuplet tuplet, double x) => _reanchorTupletX(tuplet, x);

  List<PositionedElement> layout() {
    return _layoutInternal();
  }

  LayoutResult layoutWithSignature() {
    final elements = _layoutInternal();
    return LayoutResult(
      elements: elements,
      signature: PositionedElement.computeSignature(elements),
    );
  }

  /// Whether [measure] states a matching attribute IN FRONT of its first
  /// rhythmic event, i.e. at the bar's head where a system restatement would
  /// go. A clef that appears after a note is a mid-measure CHANGE and says
  /// nothing about what the bar opens with.
  ///
  /// This is the SAME rule `GrandStaffPainter._statesAtHead` applies to the
  /// grand-staff path; the two must not diverge, or a piece laid out as a
  /// single staff and the same piece laid out as one staff of a system would
  /// open their wrapped lines differently.
  ///
  /// The old test — `measure.elements.any((e) => e is Clef)` — answered "yes"
  /// for a bar whose ONLY clef is a mid-measure change, and so suppressed the
  /// head restatement. Measured on twelve bars at 300 px, bar 1 carrying a
  /// bass clef AFTER its first note: `sys1 clefs=[bass@56]` — the system
  /// opened with no clef at all at x = 30.
  static bool _statesAtHead(
    Measure measure,
    bool Function(MusicalElement) matches,
  ) {
    for (final element in measure.allElements) {
      if (matches(element)) return true;
      if (element is Note ||
          element is Rest ||
          element is Chord ||
          element is Tuplet) {
        return false;
      }
    }
    return false;
  }

  List<PositionedElement> _layoutInternal() {
    // Limpar mapas de positions
    _noteXPositions.clear();
    _noteStaffPositions.clear();
    _noteYPositions.clear(); // ✅ NOVO
    _noteOctaveShifts.clear();
    // Diagnostics belong to ONE pass. `layout()` is called again on every
    // rebuild, so an accumulating list would report the same over-full bar once
    // per frame.
    warnings.clear();
    _advancedBeamGroups.clear();
    _chordGeometryCache.clear();
    _widthClef = null;
    _widthOctaveShift = 0;
    _octaveTimeline = _buildOctaveTimeline();

    final cursor = LayoutCursor(
      staffSpace: staffSpace,
      availableWidth: availableWidth,
      systemMargin: systemMargin * staffSpace,
      noteXPositions: _noteXPositions,
      noteStaffPositions: _noteStaffPositions,
      noteYPositions: _noteYPositions, // ✅ NOVO
      noteOctaveShifts: _noteOctaveShifts,
      octaveTimeline: _octaveTimeline,
      chordGeometry: _resolveChordGeometry,
    );

    final List<PositionedElement> positionedElements = [];

    // Armazenar measures by system for justificação
    final systemMeasures = <int, List<int>>{};
    final measureStartIndices = <int, int>{};

    // System de inheritance de TimeSignature
    TimeSignature? currentTimeSignature;
    // Running clef/key, restated at the start of each new system.
    Clef? currentClef;
    KeySignature? currentKey;

    // Musical time, in whole notes, consumed by the measures laid out so far.
    // Carried onto every PositionedElement so several staves can later be
    // aligned on one shared time grid.
    double onsetCursor = 0.0;

    // Contador de validação (only for estatísticas)
    int validMeasures = 0;
    int invalidMeasures = 0;

    for (int i = 0; i < staff.measures.length; i++) {
      final measure = staff.measures[i];
      final isFirst = cursor.isFirstMeasureInSystem;
      final isLast = i == staff.measures.length - 1;
      // Running meter that LEAVES the staff — the only thing this scan is
      // still for. `_analyzeBeamGroups` below takes it; the per-bar answer now
      // comes from [timeSignatureOf].
      final declaredHere = measure.timeSignature;
      if (declaredHere != null) currentTimeSignature = declaredHere;

      // The meter in force for this bar, read from the VALUE the engine
      // publishes ([inheritedTimeSignatures]) instead of being stamped onto the
      // caller's own `Measure`. The old line here —
      // `measure.inheritedTimeSignature = timeSignatureToUse` — made
      // `Measure.add` throw for an element it had accepted moments earlier
      // (ADR-005 action item 8); see [inheritedTimeSignatures] for the numbers.
      // `currentTimeSignature` is still tracked because `_analyzeBeamGroups`
      // below needs the meter that leaves the staff.
      final timeSignatureToUse = timeSignatureOf(measure);

      // ✅ Validação de measure (silenciosa - only estatísticas)
      if (timeSignatureToUse != null) {
        final validation = MeasureValidator.validateWithTimeSignature(
          measure,
          timeSignatureToUse,
          allowAnacrusis: isFirst && i == 0,
        );
        if (validation.isValid) {
          validMeasures++;
        } else {
          invalidMeasures++;
        }
      }

      // The measuring pass resolves onsets the same way the real pass does, so
      // the bar's onset base has to be current BEFORE it runs — otherwise a
      // chord under an 8va is measured against the previous bar's clock.
      _measureOnsetBase = onsetCursor;
      final measureWidth = _calculateMeasureWidthCursor(
        measure,
        isFirst,
        measureIndex: i,
      );

      // QUEBRA INTELIGENTE: A each N measures Or if not couber
      if (!isFirst && cursor.needsSystemBreak(measureWidth)) {
        final measureStartsWithBarline =
            measure.elements.isNotEmpty && measure.elements.first is Barline;
        final previousSystemAlreadyEndsWithBarline =
            positionedElements.isNotEmpty &&
            positionedElements.last.system == cursor.currentSystem &&
            positionedElements.last.element is Barline;

        // If the next system starts with a barline (for example a repeat
        // start), the previous system still needs a normal closing barline.
        if (measureStartsWithBarline && !previousSystemAlreadyEndsWithBarline) {
          cursor.addBarline(positionedElements, onset: onsetCursor);
        }
        cursor.startNewSystem();
      }

      // The restated clef/key below belong to the measure ABOUT to be laid
      // out, so stamp the index first — otherwise the restatement carried the
      // PREVIOUS bar's index and the measure-number pass read the wrong number
      // (and picked the wrong left-most element) at every system start.
      cursor.currentMeasureIndex = i;

      // Restate the running clef (and key signature) at the start of every
      // system after the first, when this measure does not carry its own — so
      // each wrapped line begins with its prevailing clef/key (Gould/Verovio).
      if (cursor.isFirstMeasureInSystem && i > 0) {
        final hasClef = _statesAtHead(measure, (e) => e is Clef);
        final hasKey = _statesAtHead(measure, (e) => e is KeySignature);
        var restated = false;
        final clef = currentClef;
        if (!hasClef && clef != null) {
          cursor.addElement(clef, positionedElements, onset: onsetCursor);
          cursor.advance(_getElementWidthSimple(clef));
          restated = true;
        }
        final key = currentKey;
        if (!hasKey && key != null && key.count != 0) {
          cursor.addElement(key, positionedElements, onset: onsetCursor);
          cursor.advance(_getElementWidthSimple(key));
          restated = true;
        }
        if (restated) cursor.advance(staffSpace * 1.0);
      }
      // Update the running clef/key from this measure (used by later systems).
      //
      // `allElements`, NOT `elements`: ADR-004 puts a mid-measure attribute
      // change INSIDE the voice it belongs to, so a `Clef` written half way
      // through voice 1 of a polyphonic bar is invisible to `Measure.elements`.
      // Measured on ten polyphonic bars with a bass clef in the middle of
      // voice 1 of bar 3, laid out at 400 px (one bar per system): systems 3
      // through 9 restated `treble@30` while BASS was in force — every note
      // from bar 3 on drawn a twelfth out of place, silently.
      for (final e in measure.allElements) {
        if (e is Clef) currentClef = e;
        if (e is KeySignature) currentKey = e;
      }

      // Guardar index initial of the measure for justificação
      final measureStartIndex = positionedElements.length;
      measureStartIndices[i] = measureStartIndex;

      // Registrar measure no system
      final currentSystem = cursor.currentSystem;
      systemMeasures[currentSystem] = systemMeasures[currentSystem] ?? [];
      systemMeasures[currentSystem]!.add(i);

      // A measure that cannot fit the line is COMPRESSED instead of being let
      // run off the canvas. `needsSystemBreak` never fires for the first
      // measure of a system (there is nowhere to break to), so without this a
      // dense bar simply overflowed and the widget clipped it.
      final usable = cursor.usableWidth;
      final headroom = usable - (cursor.currentX - cursor.systemMargin);
      var overflowingMeasure = false;
      if (measureWidth > headroom && headroom > 0) {
        _spacingScale =
            (headroom / measureWidth).clamp(minimumSpacingScale, 1.0);
        // The compression bottomed out: remember it, and report only after the
        // bar has actually been laid out, so the factor quoted is the REAL
        // overflow and not the pre-pass estimate. Measured on the 40-whole-note
        // bar: the estimate says 1.64x where the laid-out music says 2.03x.
        overflowingMeasure = measureWidth * minimumSpacingScale > headroom;
      }

      _measureOnsetBase = onsetCursor;
      _layoutMeasureCursor(
        measure,
        cursor,
        positionedElements,
        cursor.isFirstMeasureInSystem,
      );
      _spacingScale = 1.0;
      if (overflowingMeasure && !_measuring) {
        _recordOverflowWarning(
          measureIndex: i,
          positionedElements: positionedElements,
          measureStartIndex: measureStartIndex,
        );
      }
      onsetCursor += _measureMusicalDuration(measure);

      // Check if current measure ends with barline
      final currentMeasureEndsWithBarline =
          measure.elements.isNotEmpty && measure.elements.last is Barline;

      // Check if Next measure começa with barline (ex: repeat)
      final nextMeasure = (i < staff.measures.length - 1)
          ? staff.measures[i + 1]
          : null;
      final nextMeasureStartsWithBarline =
          nextMeasure != null &&
          nextMeasure.elements.isNotEmpty &&
          nextMeasure.elements.first is Barline;

      // add barline apropriada SOMENTE if:
      // 1. Next measure not começar with a
      // 2. Current measure not terminar with a
      if (!nextMeasureStartsWithBarline && !currentMeasureEndsWithBarline) {
        if (isLast) {
          // Double barline Final
          cursor.advance(measureEndPadding * staffSpace);
          cursor.addDoubleBarline(positionedElements, onset: onsetCursor);
        } else {
          // BARLINE NORMAL between measures
          cursor.advance(measureEndPadding * staffSpace);
          cursor.addBarline(positionedElements, onset: onsetCursor);
        }
      } else {
        // Measure ends with barline Or next começa with barline - only add padding
        cursor.advance(measureEndPadding * staffSpace);
      }

      cursor.endMeasure();
    }

    // Relatório resumido (only if verbose)
    if (verboseValidation && (validMeasures + invalidMeasures) > 0) {}

    // JUSTIFICAÇÃO HORIZONTAL: Esticar measures for preencher width
    _justifyHorizontally(positionedElements, systemMeasures);

    // Center a lone full-measure rest within its bar (Behind Bars p.158).
    _centerFullMeasureRests(positionedElements, measureStartIndices);

    // Displace cross-voice noteheads that would overlap (seconds/unisons).
    _resolveCrossVoiceCollisions(positionedElements);

    // Re-sync `_noteXPositions` with the post-justification positions.
    // Justification moves `positionedElements` but not the note map, and beams
    // read the map — so without this the beam and its noteheads drift apart.
    // The old loop only handled top-level `Note`s, leaving every note INSIDE a
    // Chord holding its pre-justification X.
    for (final positioned in positionedElements) {
      final element = positioned.element;
      final x = positioned.position.dx;
      if (element is Note) {
        if (_noteXPositions.containsKey(element)) {
          _noteXPositions[element] = x;
        }
      } else if (element is Chord) {
        // Keep the per-notehead cluster displacement: a chord containing a
        // second draws one of its heads a full notehead width off the chord
        // origin, and re-syncing every note to the chord's X would silently
        // undo that for beams and hit-testing.
        final geometry = _chordGeometryCache[element];
        for (final note in element.notes) {
          if (_noteXPositions.containsKey(note)) {
            _noteXPositions[note] = x + (geometry?.offsetOf(note) ?? 0.0);
          }
        }
      } else if (element is Tuplet) {
        // Inner notes sit on the renderer's grid, anchored on the tuplet.
        _reanchorTupletX(element, x);
      }
    }

    // ANÃƒÂLISE DE BEAMING AVANÇADO: criar AdvancedBeamGroups
    _analyzeBeamGroups(currentTimeSignature, positionedElements);

    _assignAboveStaffLevels(positionedElements);
    return positionedElements;
  }

  /// Analisa beam groups and Creates AdvancedBeamGroups for Rendering
  /// ✅ CORREÇÃO: Use notes ProcessesDAS de positionedElements, not de measure.elements
  void _analyzeBeamGroups(
    TimeSignature? timeSignature,
    List<PositionedElement> positionedElements,
  ) {
    // A staff with no explicit meter still gets beams: [_resolveBeamsInto]
    // already defaults to 4/4 and resolves them. Bailing out here left those
    // beams with NO geometry — no stem lengths, no slope, no secondary-beam
    // segments —
    // and `advancedBeamGroups` empty, so `StaffRenderer` fell through to the
    // crude fallback drawer. The README's own quick-start snippet
    // (`Measure()..add(Note(...))`, no TimeSignature) hit this path.
    timeSignature ??= TimeSignature(numerator: 4, denominator: 4);

    // Read the beam types RESOLVED into [beams], falling back through [beamOf]
    // to the author's own hint. Do NOT call BeamGrouper again here: it would
    // process every note of the staff in one run, ignoring bar lines, and group
    // across measures.
    // The notes are read straight out of [positionedElements] in ONE pass:
    // `where().map().toList()` materialised a second list as long as the score
    // (119 468 elements on the 12 800-bar fixture) only to walk it once and
    // throw it away.
    List<Note>? currentGroup;
    for (final positioned in positionedElements) {
      final element = positioned.element;
      if (element is! Note) continue;
      final note = element;
      switch (beamOf(note)) {
        case BeamType.start:
          currentGroup = [note];
        case BeamType.inner:
          currentGroup?.add(note);
        case BeamType.end:
          if (currentGroup != null) {
            currentGroup.add(note);
            if (currentGroup.length >= 2) {
              try {
                final advancedGroup = _beamAnalyzer.analyzeAdvancedBeamGroup(
                  currentGroup,
                  timeSignature,
                  noteXPositions: _noteXPositions,
                  noteStaffPositions: _noteStaffPositions,
                  noteYPositions: _noteYPositions,
                );
                _advancedBeamGroups.add(advancedGroup);
              } catch (_) {
                // Ignore beam analysis errors for individual groups
              }
            }
            currentGroup = null;
          }
        case null:
          currentGroup = null;
      }
    }
  }

  /// Justifica horizontalmente os measures for preencher a width disponível
  /// Stretches each system (except the last) so its music reaches the right
  /// margin.
  ///
  /// Two things were wrong before:
  ///
  /// * the offset was proportional to the element's absolute X, which scales
  ///   EVERY gap by the same factor — including the fixed opening block
  ///   (clef -> key -> meter), which by convention must never be stretched.
  ///   Only the region from the first rhythmic event onwards is elastic now.
  /// * a `fillThreshold` of 0.7 left any system filling less than 70% of the
  ///   line ragged. That is a last-system rule, not a mid-score one: a 1400 px
  ///   viewport measured 69% fill and produced a ragged right edge in the
  ///   MIDDLE of the piece.
  void _justifyHorizontally(
    List<PositionedElement> elements,
    Map<int, List<int>> systemMeasures,
  ) {
    final rightEdge = availableWidth - (systemMargin * staffSpace);
    final int lastSystem = systemMeasures.keys.isEmpty
        ? -1
        : systemMeasures.keys.reduce((a, b) => a > b ? a : b);

    // Index the elements by system ONCE.
    //
    // This loop used to scan the whole `elements` list twice per system, which
    // is O(systems x elements) — and since the number of systems grows with the
    // number of elements, that is quadratic in the size of the score. Measured
    // before: 400 bars 160 ms, 1600 bars 262 ms, 3200 bars 1156 ms, 6400 bars
    // 5991 ms; the same 3200 bars laid out as ONE system (where justification
    // is skipped, because the last system keeps its natural spacing) took
    // 115 ms. Justification alone accounted for a 6.3x slowdown.
    final bySystem = <int, List<int>>{};
    for (var i = 0; i < elements.length; i++) {
      (bySystem[elements[i].system] ??= <int>[]).add(i);
    }

    for (final entry in systemMeasures.entries) {
      final system = entry.key;
      if (system == lastSystem) continue; // Behind Bars: last line stays natural
      if (entry.value.isEmpty) continue;

      final indices = bySystem[system];
      if (indices == null || indices.isEmpty) continue;

      // Elastic region = from the first rhythmic event of the system to the
      // right-most element on it.
      double? contentStartX;
      double maxX = double.negativeInfinity;
      for (final i in indices) {
        final positioned = elements[i];
        final e = positioned.element;
        final isRhythmic =
            e is Note || e is Rest || e is Chord || e is Tuplet;
        if (isRhythmic &&
            (contentStartX == null || positioned.position.dx < contentStartX)) {
          contentStartX = positioned.position.dx;
        }
        if (positioned.position.dx > maxX) maxX = positioned.position.dx;
      }
      if (contentStartX == null || maxX <= contentStartX) continue;

      final extraSpace = rightEdge - maxX;
      if (extraSpace <= 0) continue; // already full (or compressed)

      final span = maxX - contentStartX;
      for (final i in indices) {
        final positioned = elements[i];
        final dx = positioned.position.dx;
        if (dx <= contentStartX) continue; // opening block stays put

        final ratio = (dx - contentStartX) / span;
        elements[i] = positioned
            .movedTo(Offset(dx + extraSpace * ratio, positioned.position.dy));
      }
    }
  }

  /// Centers a measure that contains a single full-bar rest between its left
  /// content edge and its closing barline (Behind Bars p.158: a whole-measure
  /// rest sits centered regardless of meter). Runs after justification so the
  /// barline X is final.
  void _centerFullMeasureRests(
    List<PositionedElement> elements,
    Map<int, int> measureStartIndices,
  ) {
    final keys = measureStartIndices.keys.toList()..sort();
    for (var ki = 0; ki < keys.length; ki++) {
      final i = keys[ki];
      final measure = staff.measures[i];
      if (measure is MultiVoiceMeasure) continue;

      final musical = measure.elements
          .where((e) => e is Note || e is Rest || e is Chord)
          .toList();
      if (musical.length != 1 || musical.first is! Rest) continue;
      final rest = musical.first as Rest;

      // Only a true full-bar rest: a whole rest (used as a measure rest in any
      // meter) or a rest whose value fills the measure.
      final ts = timeSignatureOf(measure);
      final isFullBar = rest.duration.type == DurationType.whole ||
          (ts != null &&
              !ts.isFreeTime &&
              rest.duration.realValue >= ts.measureValue - 1e-6);
      if (!isFullBar) continue;

      final start = measureStartIndices[i]!;
      final end =
          ki + 1 < keys.length ? measureStartIndices[keys[ki + 1]]! : elements.length;

      var restIdx = -1;
      double? barlineX;
      for (var j = start; j < end; j++) {
        final el = elements[j].element;
        if (el is Rest && restIdx < 0) restIdx = j;
        if (el is Barline) barlineX = elements[j].position.dx;
      }
      if (restIdx < 0 || barlineX == null) continue;

      final positioned = elements[restIdx];
      final restWidth = _getElementWidthSimple(positioned.element);
      final leftBound = positioned.position.dx;
      final available = barlineX - leftBound;
      if (available <= restWidth) continue;

      final newX = leftBound + (available - restWidth) / 2;
      elements[restIdx] =
          positioned.movedTo(Offset(newX, positioned.position.dy));
    }
  }

  /// When two voices place noteheads a second or unison apart at the same
  /// onset, the heads overlap. Displace the lower voice's head(s) by one
  /// notehead width so the interval reads clearly (Gould p.39-46). Runs after
  /// justification; only handles the two-voice case.
  void _resolveCrossVoiceCollisions(List<PositionedElement> elements) {
    final noteW = noteheadBlackWidth * staffSpace;

    // Group notes by system + MUSICAL ONSET.
    //
    // The grouping key used to be the rounded X. Voices 2+ are placed by linear
    // interpolation on voice 1's timeline, so two simultaneous notes routinely
    // landed on 123.4 and 123.6 -> keys '123' and '124' -> no group at all and
    // the collision went unresolved. Onset is exact and is what "simultaneous"
    // actually means.
    final groups = <String, List<int>>{};
    for (var i = 0; i < elements.length; i++) {
      final pe = elements[i];
      if (pe.element is! Note || pe.voiceNumber == null) continue;
      final onsetKey = (pe.onset * kOnsetGrid).round();
      final key = '${pe.system}_$onsetKey';
      (groups[key] ??= <int>[]).add(i);
    }

    for (final idxs in groups.values) {
      if (idxs.length < 2) continue;

      // (positioned-index, voice, staffPosition) for each note in the group.
      final infos = <({int idx, int voice, int pos})>[];
      for (final i in idxs) {
        final sp = _noteStaffPositions[elements[i].element as Note];
        if (sp == null) continue;
        infos.add((idx: i, voice: elements[i].voiceNumber!, pos: sp));
      }
      if (infos.length < 2) continue;
      if (infos.map((n) => n.voice).toSet().length < 2) continue;

      // Closest cross-voice interval.
      var minDiff = 9999;
      for (final a in infos) {
        for (final b in infos) {
          if (a.voice == b.voice) continue;
          final d = (a.pos - b.pos).abs();
          if (d < minDiff) minDiff = d;
        }
      }
      if (minDiff > 1) continue; // only seconds and unisons collide

      // A UNISON is not displaced.
      //
      // Behind Bars p.44: when two voices meet on the same pitch with the same
      // note value, they share ONE notehead carrying two stems — the heads are
      // coincident on purpose, and pushing one aside by a full head width turns
      // a unison into what reads as a second. Only a genuine SECOND is offset.
      // (Two voices on the same pitch with DIFFERENT values do need separate
      // heads, so those are still displaced.)
      if (minDiff == 0) {
        final durations = <DurationType>{};
        for (final n in infos) {
          final element = elements[n.idx].element;
          if (element is Note) durations.add(element.duration.type);
        }
        if (durations.length <= 1) continue;
      }

      // Pick the lower voice (smallest staff position; tie -> larger voice id).
      int? lowerVoice;
      int? lowerPos;
      for (final n in infos) {
        if (lowerVoice == null ||
            n.pos < lowerPos! ||
            (n.pos == lowerPos && n.voice > lowerVoice)) {
          lowerVoice = n.voice;
          lowerPos = n.pos;
        }
      }

      // Shift that voice's note(s) in this onset group left by one head width.
      for (final n in infos) {
        if (n.voice != lowerVoice) continue;
        final pe = elements[n.idx];
        elements[n.idx] =
            pe.movedTo(Offset(pe.position.dx - noteW, pe.position.dy));
      }
    }
  }

  /// Exact width the measure will occupy, obtained by laying it out into a
  /// throw-away cursor.
  ///
  /// This used to be an independent estimate: sum of glyph widths plus a FLAT
  /// `3.5 staff spaces` per note gap, while the real layout advanced by a
  /// duration-proportional amount. The two numbers disagreed by up to 2x, so
  /// system breaks were decided with a figure that did not describe the
  /// drawing. Measuring by dry-run makes the two agree by construction — they
  /// cannot drift apart again because there is only one implementation.
  ///
  /// ## What the dry run does and does NOT touch
  ///
  /// The probe cursor is created WITHOUT the note position maps, and
  /// [_measuring] suppresses [_registerTupletGeometry], so the POSITION MAPS
  /// ([_noteXPositions], [_noteStaffPositions], [_noteYPositions],
  /// [_noteOctaveShifts]) come out of the measuring pass untouched.
  ///
  /// The comment here used to claim the dry run "leaves no trace", and that was
  /// false while `_layoutMeasureCursor` still resolved beams by writing
  /// [Note.beam] on the CALLER'S OWN `Note` objects: measured on a 16-note
  /// staff, 32 writes for 16 notes — two per note, measure 0 written in full a
  /// second time before measure 1 started, because the dry run walks the same
  /// code the real pass does. It is true again now. Beam membership is resolved
  /// ONCE, up front, into the [beams] value map (M-26), so the dry run has no
  /// beam side effect left to have: it neither writes the model nor re-runs
  /// `BeamGrouper` per measure.
  ///
  /// [_measuring] and [_spacingScale] are saved and restored in a `finally`:
  /// without it, any throw from inside the dry run (a malformed measure
  /// reaching a renderer-side estimate, say) leaked `_measuring == true` and
  /// `_spacingScale == 1.0` into the REAL layout, which then silently skipped
  /// every tuplet's geometry registration and ignored compression.
  double _calculateMeasureWidthCursor(
    Measure measure,
    bool isFirstInSystem, {
    required int measureIndex,
  }) {
    final probe = LayoutCursor(
      staffSpace: staffSpace,
      availableWidth: availableWidth,
      systemMargin: 0,
      octaveTimeline: _octaveTimeline,
      chordGeometry: _resolveChordGeometry,
    );
    // The probe must resolve the same bracket span and the same chord geometry
    // the real pass will, or a chord under an 8va would be MEASURED with one
    // stem direction and DRAWN with another.
    probe.currentMeasureIndex = measureIndex;
    final scrap = <PositionedElement>[];
    final savedScale = _spacingScale;
    try {
      _spacingScale = 1.0;
      _measuring = true;
      _layoutMeasureCursor(measure, probe, scrap, isFirstInSystem);
    } finally {
      _measuring = false;
      _spacingScale = savedScale;
    }

    final width = probe.currentX;
    final minWidth = measureMinWidth * staffSpace;
    return width < minWidth ? minWidth : width;
  }

  void _layoutMultiVoiceMeasure(
    MultiVoiceMeasure measure,
    LayoutCursor cursor,
    List<PositionedElement> positionedElements,
    bool isFirstInSystem,
  ) {
    double startX = cursor.currentX;

    // The measure's OWN elements are its opening block.
    //
    // This method used to walk `measure.sortedVoices` and nothing else, so a
    // clef, key, meter or dynamic written into `MultiVoiceMeasure.elements` —
    // the inherited, public, documented list that `Measure.add` writes to — was
    // dropped without a word. Worse, because the cursor never saw a Clef it had
    // no active clef, so EVERY note in the bar was placed on the staff baseline
    // instead of at its pitch (measured: a C6 and a C4 both at y = 60.0) and
    // none of them was registered in the note-position maps, which silently
    // disabled beams, hit-testing and the public position API for that bar.
    //
    // Polyphonic music imported from MusicXML/MEI escaped the bug only because
    // the parsers wrote every system element TWICE — once here and once into
    // voice 1. That duplication is removed in the parsers now that this path
    // reads the measure's own elements.
    final opening = canonicalOpeningBlock(
      measure.elements.where(_isSystemElement).toList(),
    );
    final measureExtras =
        measure.elements.where((e) => !_isSystemElement(e)).toList();

    double onsetBase = _measureOnsetBase;
    for (final element in opening) {
      cursor.addElement(element, positionedElements, onset: onsetBase);
      cursor.advance(_getElementWidthSimple(element));
    }
    if (opening.isNotEmpty) {
      cursor.advance(
        _calculateSpacingAfterSystemElementsCorrected(
          opening,
          measure.sortedVoices.isEmpty
              ? const <MusicalElement>[]
              : measure.sortedVoices.first.elements
                  .where((e) => !_isSystemElement(e))
                  .toList(),
        ),
      );
      startX = cursor.currentX;
    }

    // Non-system extras (dynamics, texts, octave marks) are co-positioned with
    // the start of the bar's music and must not advance the cursor.
    for (final element in measureExtras) {
      cursor.addElement(element, positionedElements, onset: onsetBase);
    }

    double maxAdvanceX = startX;
    // Tracks where musical elements (post clef/key/time) start in voice 1.
    // voices 2+ must start at this X so notes align with voice 1.
    double firstMusicX = startX;
    final leadTimelineAnchors = <({double time, double x})>[];
    double leadTotalTime = 0.0;

    final sortedVoices = measure.sortedVoices;

    for (int voiceIdx = 0; voiceIdx < sortedVoices.length; voiceIdx++) {
      final voice = sortedVoices[voiceIdx];

      // voices 2+ skip system elements and start where voice 1's music begins
      final isLeadVoice = voiceIdx == 0;
      cursor.setX(isLeadVoice ? startX : firstMusicX);

      // Beams are resolved once, up front, into the [beams] value map: they are
      // a pure function of the model and no longer a side effect of laying a
      // bar out, so this path just renders the voice's own elements.
      final processedElements = voice.elements;

      // Voice 2+ never renders system elements (clef/key/time sig belong to
      // voice 1). The lead voice renders every system element it carries —
      // those are author-placed openings or genuine mid-line changes.
      final elementsToRender = processedElements.where((element) {
        if (!isLeadVoice && _isSystemElement(element)) return false;
        return true;
      }).toList();

      bool seenFirstMusicElement =
          !isLeadVoice; // voice 2+ already positioned past system elements
      double voiceTime = 0.0;

      // FLOATING ELEMENTS (dynamics, expression texts, octave marks, tempo
      // marks, voltas, breaths) must not advance the cursor — exactly as in
      // `_layoutMeasureCursor`. This path used to charge every one of them a
      // full `_getElementWidthSimple`, so the SAME direction reserved advance
      // in voice 1 and none in voice 2. Measured, X of the bar's first note in
      // a two-voice measure at `staffSpace = 12`: `OctaveMark` 158.21 in v1 vs
      // 116.21 in v2 (42.00 px apart), `Dynamic` 182.21 vs 116.21 (66.00 px),
      // `MusicText` 207.29 vs 116.21 (91.08 px). In a MONOPHONIC bar all four
      // tested directions moved the first note by 0.00 px, so it was the
      // multi-voice path that was the odd one out, and its voice 2 that was
      // already right.
      final pendingFloating = <MusicalElement>[];
      MusicalElement? previousInFlow;

      for (int i = 0; i < elementsToRender.length; i++) {
        final element = elementsToRender[i];
        final elementOnset =
            _measureOnsetBase + (isLeadVoice ? leadTotalTime : voiceTime);
        // Seed for the chord-geometry fallback (see `_layoutMeasureCursor`).
        _widthClef = cursor.activeClef;
        _widthOctaveShift = _octaveTimeline.isEmpty
            ? cursor.activeOctaveShift
            : _octaveTimeline.shiftAt(
                measureIndex: cursor.currentMeasureIndex,
                onset: elementOnset,
              );

        if (_isAboveOrBelowStaffElement(element)) {
          pendingFloating.add(element);
          continue;
        }

        if (previousInFlow != null && isLeadVoice) {
          cursor.advance(_calculateRhythmicSpacing(element, previousInFlow));
        } else if (previousInFlow != null &&
            !isLeadVoice &&
            leadTimelineAnchors.isEmpty) {
          // Fallback if not houver âncoras of the voice principal.
          cursor.advance(_calculateRhythmicSpacing(element, previousInFlow));
        }

        // Record where voice 1's first non-system element lands so other voices align
        if (isLeadVoice &&
            !seenFirstMusicElement &&
            !_isSystemElement(element)) {
          seenFirstMusicElement = true;
          firstMusicX = cursor.currentX;
        }

        if (isLeadVoice && !_isSystemElement(element)) {
          _addTimelineAnchor(
            leadTimelineAnchors,
            leadTotalTime,
            cursor.currentX,
          );
        }

        if (!isLeadVoice &&
            !_isSystemElement(element) &&
            leadTimelineAnchors.isNotEmpty) {
          final alignedX = _interpolateTimelineX(
            leadTimelineAnchors,
            voiceTime,
            fallbackX: cursor.currentX,
          );
          cursor.setX(alignedX);
        }

        // Apply the voice's horizontal offset to the X position.
        final savedX = cursor.currentX;
        // Directions collected since the previous note are co-positioned with
        // the element that follows them, the same rule the single-voice path
        // uses, so they land on the note they belong to instead of on a column
        // of their own.
        for (final floating in pendingFloating) {
          cursor.addElement(
            floating,
            positionedElements,
            voiceNumber: voice.number,
            onset: elementOnset,
          );
        }
        pendingFloating.clear();
        cursor.addElement(
          element,
          positionedElements,
          voiceNumber: voice.number,
          onset: elementOnset,
        );
        cursor.setX(savedX);

        cursor.advance(_getElementWidthSimple(element));
        previousInFlow = element;

        if (!_isSystemElement(element)) {
          final rhythmicValue = _getRhythmicValue(element);
          if (isLeadVoice) {
            leadTotalTime += rhythmicValue;
          } else {
            voiceTime += rhythmicValue;
          }
        }

        if (cursor.currentX > maxAdvanceX) {
          maxAdvanceX = cursor.currentX;
        }
      }

      // Directions trailing at the end of the voice have no following element
      // to attach to, so they take the last cursor position.
      for (final floating in pendingFloating) {
        cursor.addElement(
          floating,
          positionedElements,
          voiceNumber: voice.number,
          onset: _measureOnsetBase + (isLeadVoice ? leadTotalTime : voiceTime),
        );
      }
      pendingFloating.clear();

      if (isLeadVoice && leadTimelineAnchors.isNotEmpty) {
        _addTimelineAnchor(leadTimelineAnchors, leadTotalTime, cursor.currentX);
      }
    }

    cursor.setX(maxAdvanceX);
  }

  void _addTimelineAnchor(
    List<({double time, double x})> anchors,
    double time,
    double x,
  ) {
    if (anchors.isEmpty) {
      anchors.add((time: time, x: x));
      return;
    }

    final last = anchors.last;
    if ((last.time - time).abs() < 0.000001) {
      anchors[anchors.length - 1] = (time: time, x: x);
    } else {
      anchors.add((time: time, x: x));
    }
  }

  double _interpolateTimelineX(
    List<({double time, double x})> anchors,
    double time, {
    required double fallbackX,
  }) {
    if (anchors.isEmpty) return fallbackX;

    if (time <= anchors.first.time) {
      return anchors.first.x;
    }

    if (time >= anchors.last.time) {
      return anchors.last.x;
    }

    for (int i = 0; i < anchors.length - 1; i++) {
      final left = anchors[i];
      final right = anchors[i + 1];
      if (time < left.time || time > right.time) continue;

      final span = right.time - left.time;
      if (span.abs() < 0.000001) return left.x;
      final ratio = (time - left.time) / span;
      return left.x + ((right.x - left.x) * ratio);
    }

    return fallbackX;
  }

  /// Musical time [element] consumes, in whole notes.
  ///
  /// This delegates to [Measure.musicalValueOf] instead of re-deriving the
  /// answer, because the two implementations HAD diverged: this one counted a
  /// grace note's written duration while `MidiMapper` (correctly) did not, so
  /// a 4/4 bar of four quarters plus two eighth grace notes laid its four real
  /// notes out at onsets `[0, 0.1875, 0.4375, 0.6875]` instead of
  /// `[0, 0.25, 0.5, 0.75]` — while the MIDI it played back was a correct
  /// 3840 ticks at 960 ppq. The ADR-002 shared onset grid, which is the only
  /// reason two staves of a grand staff line up, was therefore wrong for every
  /// staff containing a grace note.
  ///
  /// A grace note still occupies horizontal WIDTH (see
  /// [_getElementWidthSimple], which is untouched) — it is drawn. Only its
  /// contribution to the CLOCK is zero.
  ///
  /// The one behavioural difference from the old body is `Tuplet`: it used to
  /// read `Tuplet.totalDuration`, which sums every child including grace
  /// notes. `Measure.musicalValueOf` recurses through itself, so a grace note
  /// inside a tuplet is excluded too — the same rule at every depth.
  double _getRhythmicValue(MusicalElement element) =>
      Measure.musicalValueOf(element);

  void _layoutMeasureCursor(
    Measure measure,
    LayoutCursor cursor,
    List<PositionedElement> positionedElements,
    bool isFirstInSystem,
  ) {
    // Handle MultiVoiceMeasure: layout each voice independently.
    if (measure is MultiVoiceMeasure) {
      _layoutMultiVoiceMeasure(
        measure,
        cursor,
        positionedElements,
        isFirstInSystem,
      );
      return;
    }

    // See [beams]: beam membership is resolved once from the model, not stamped
    // onto it while the bar is laid out.
    final elementsToRender = measure.elements;

    if (elementsToRender.isEmpty) return;

    // Only the LEADING run of clef/key/time is the measure's opening block.
    //
    // The engine used to hoist EVERY system element to the head of the bar.
    // That moved a genuine mid-measure clef change to the barline AND — because
    // the cursor tracks the clef in the order it receives elements — made every
    // note in the bar be positioned with the LAST clef of the bar. A measure
    // `[treble, C4, bass, C4]` drew both C4s at the bass-clef position: a
    // twelfth off for the first one. System elements now stay in document
    // order, so notes before a change keep the previous clef.
    int lead = 0;
    while (lead < elementsToRender.length &&
        _isSystemElement(elementsToRender[lead])) {
      lead++;
    }
    final openingBlock =
        canonicalOpeningBlock(elementsToRender.sublist(0, lead));
    final body = elementsToRender.sublist(lead);

    double onset = _measureOnsetBase;

    for (final element in openingBlock) {
      cursor.addElement(element, positionedElements, onset: onset);
      cursor.advance(_getElementWidthSimple(element));
    }

    if (openingBlock.isNotEmpty) {
      cursor.advance(
        _calculateSpacingAfterSystemElementsCorrected(
          openingBlock,
          body.where((e) => !_isSystemElement(e)).toList(),
        ),
      );
    }

    // FLOATING ELEMENTS (tempo marks, segno/coda, dynamics, expression texts,
    // octave marks, ...) must NOT advance the cursor. They are co-positioned
    // with the rhythmic element that follows them (or with the last element in
    // the measure if they trail at the end), so extra-staff symbols never widen
    // the inter-note spacing inside the staff.
    final pendingFloating = <MusicalElement>[];
    MusicalElement? previousRhythmic;

    for (int i = 0; i < body.length; i++) {
      final element = body[i];
      // Seed for the chord-geometry fallback: the widths below are asked for
      // BEFORE the element is placed, so the cursor's own clef/bracket state is
      // the best information available at that instant.
      _widthClef = cursor.activeClef;
      _widthOctaveShift = _octaveTimeline.isEmpty
          ? cursor.activeOctaveShift
          : _octaveTimeline.shiftAt(
              measureIndex: cursor.currentMeasureIndex,
              onset: onset,
            );

      if (_isAboveOrBelowStaffElement(element)) {
        pendingFloating.add(element);
        continue;
      }

      // A mid-measure clef / key / meter change sits in the flow: it needs a
      // little air on both sides but carries no rhythmic value.
      if (_isSystemElement(element)) {
        if (previousRhythmic != null) {
          cursor.advance(staffSpace * 0.8);
        }
        for (final floating in pendingFloating) {
          cursor.addElement(floating, positionedElements, onset: onset);
        }
        pendingFloating.clear();
        cursor.addElement(element, positionedElements, onset: onset);
        cursor.advance(_getElementWidthSimple(element) * midMeasureCueScale);
        cursor.advance(staffSpace * 0.6);
        // The cue's own advance IS the gap the following note needs, so the
        // rhythmic chain has to be BROKEN here. Leaving `previousRhythmic` set
        // made the next note pay twice: the whole clef block, and then a full
        // duration-proportional gap measured against the note BEFORE the clef
        // — a note the eye no longer has to travel from.
        //
        // Measured on `[treble, C4, bass, D4]` at staffSpace 12: the C4 -> D4
        // distance was 100.92 px (C4 at 82.61, cue clef at 106.37, D4 at
        // 183.53). After the reset it is 58.92 px (D4 at 141.53) — the clef
        // block plus the 0.8 and 0.6 staff spaces of air the change itself
        // asks for on either side. The 42.00 px removed is exactly the
        // phantom note-to-note gap.
        previousRhythmic = null;
        continue;
      }

      if (previousRhythmic != null) {
        cursor.advance(_calculateRhythmicSpacing(element, previousRhythmic));
      } else {
        // First rhythmic element of the bar: there is no preceding gap to
        // charge its left extent to, so reserve it explicitly. Without this an
        // opening note's accidental leans back into the barline — the accidental
        // width moved OUT of the trailing advance when it was reassigned to the
        // leading gap, and the first note is the one element that has no
        // leading gap.
        cursor.advance(_leftExtent(element));
      }

      for (final floating in pendingFloating) {
        cursor.addElement(floating, positionedElements, onset: onset);
      }
      pendingFloating.clear();

      cursor.addElement(element, positionedElements, onset: onset);
      _registerTupletGeometry(element, cursor, onset);
      cursor.advance(_rightExtent(element));
      onset += _getRhythmicValue(element);
      previousRhythmic = element;
    }

    for (final floating in pendingFloating) {
      cursor.addElement(floating, positionedElements, onset: onset);
    }
  }

  /// Records X / staff position / Y for the notes INSIDE a tuplet.
  ///
  /// A [Tuplet] is positioned as one opaque element, so its inner notes used to
  /// get no geometry at all (`noteXPositions` returned null for every one of
  /// them) and were therefore invisible to beam analysis, to the public
  /// position API and to anything doing hit-testing. The renderer lays the
  /// inner notes out on an even grid of `tupletInnerSpacing` staff spaces; the
  /// same grid is mirrored here so the two agree.
  void _registerTupletGeometry(
    MusicalElement element,
    LayoutCursor cursor,
    double onset,
  ) {
    if (element is! Tuplet) return;
    if (_measuring) return; // a dry run must not touch the position maps
    final clef = cursor.activeClef;
    if (clef == null) return;
    // `cursor.addElement` already ran for this tuplet, so the bracket span is
    // current; the inner notes must use the SAME displacement as the outer
    // stream or the tuplet would print an octave away from its neighbours.
    _registerTupletNotes(
      element,
      clef,
      cursor.currentX,
      cursor.currentY,
      cursor.activeOctaveShift,
    );
  }

  /// Re-anchors the X of every note inside [tuplet] (recursively) after the
  /// tuplet itself has moved — justification, cross-staff alignment, and the
  /// full-bar-rest centring all move elements after the fact, and beams read
  /// these positions.
  double _reanchorTupletX(Tuplet tuplet, double startX) {
    var x = startX;
    final slots = _tupletSlots(tuplet);
    for (var index = 0; index < tuplet.elements.length; index++) {
      final inner = tuplet.elements[index];
      final step = slots[index];
      if (inner is Note) {
        if (_noteXPositions.containsKey(inner)) _noteXPositions[inner] = x;
      } else if (inner is Chord) {
        for (final note in inner.notes) {
          if (_noteXPositions.containsKey(note)) _noteXPositions[note] = x;
        }
      } else if (inner is Tuplet) {
        _reanchorTupletX(inner, x);
      }
      x += step;
    }
    return x - startX;
  }

  /// Recursive worker for [_registerTupletGeometry]. Returns the width consumed,
  /// so a NESTED tuplet advances the outer grid by its own content rather than
  /// by a single slot.
  double _registerTupletNotes(
    Tuplet tuplet,
    Clef clef,
    double startX,
    double baselineY,
    int extraOctaveShift,
  ) {
    void place(Note note, double x) {
      final staffPosition = StaffPositionCalculator.calculate(
        note.pitch,
        clef,
        extraOctaveShift: extraOctaveShift,
      );
      _noteXPositions[note] = x;
      _noteStaffPositions[note] = staffPosition;
      _noteOctaveShifts[note] = extraOctaveShift;
      _noteYPositions[note] = StaffPositionCalculator.toPixelY(
        staffPosition,
        staffSpace,
        baselineY,
      );
    }

    var x = startX;
    final slots = _tupletSlots(tuplet);
    for (var index = 0; index < tuplet.elements.length; index++) {
      final inner = tuplet.elements[index];
      final step = slots[index];
      if (inner is Note) {
        place(inner, x);
      } else if (inner is Chord) {
        for (final note in inner.notes) {
          place(note, x);
        }
      } else if (inner is Tuplet) {
        // Nested tuplet: mirrors TupletRenderer, which recurses the same way
        // through the shared [TupletGrid].
        _registerTupletNotes(inner, clef, x, baselineY, extraOctaveShift);
      }
      x += step;
    }
    return x - startX;
  }

  bool _isSystemElement(MusicalElement element) {
    return element is Clef ||
        element is KeySignature ||
        element is TimeSignature;
  }

  /// Sorts a measure's OPENING run of system elements into engraving order:
  /// clef, then key signature, then time signature (Behind Bars p.78; the same
  /// order Verovio, Finale, Sibelius and MuseScore all emit).
  ///
  /// Why this is not "document order"
  /// --------------------------------
  /// F-01 made the engine keep system elements where the author wrote them,
  /// which is REQUIRED for a mid-measure change: `[treble, C4, bass, C4]` must
  /// draw the bass clef after the first C4. But it also applied to the opening
  /// block, and MusicXML's `<attributes>` has a FIXED child order of
  /// `divisions, key, time, ..., clef` — the clef comes LAST in the file. So
  /// every imported score drew its key signature and meter before its clef.
  /// Measured on a 3-flat 4/4 import: KeySignature@30.0, TimeSignature@69.6,
  /// Clef@105.6.
  ///
  /// The distinction is positional, not textual: elements BEFORE the first
  /// rhythmic event describe the start of the system and have a canonical
  /// order; elements after it are events in time and keep document order.
  ///
  /// The sort is stable, so two elements of the same kind (a courtesy meter
  /// change written twice, say) keep their relative order.
  static List<MusicalElement> canonicalOpeningBlock(
    List<MusicalElement> leading,
  ) {
    if (leading.length < 2) return leading;
    int rank(MusicalElement e) {
      if (e is Clef) return 0;
      if (e is KeySignature) return 1;
      if (e is TimeSignature) return 2;
      return 3;
    }

    final indexed = <({int order, MusicalElement element})>[
      for (var i = 0; i < leading.length; i++)
        (order: i, element: leading[i]),
    ];
    indexed.sort((a, b) {
      final byKind = rank(a.element).compareTo(rank(b.element));
      return byKind != 0 ? byKind : a.order.compareTo(b.order);
    });
    return [for (final item in indexed) item.element];
  }

  /// Returns true for elements that render above or below the staff and must
  /// Not affect the horizontal spacing between notes inside the staff.
  ///
  /// These elements are "co-positioned" with their associated rhythmic element
  /// (the one that immediately follows in the measure) instead of advancing
  /// the layout cursor.
  bool _isAboveOrBelowStaffElement(MusicalElement element) {
    if (element is TempoMark) return true;
    if (element is Dynamic) return true;
    if (element is OctaveMark) return true;
    if (element is VoltaBracket) return true;
    if (element is Verse) return true;
    if (element is Breath) return true;
    if (element is MusicText) {
      // Lyrics can affect note spacing (syllable width); everything else floats.
      return element.type != TextType.lyrics;
    }
    if (element is RepeatMark) {
      // Bar-repeat and simile marks are part of the staff layout and of the affect
      // spacing. Navigation/text marks (segno, coda, D.C., D.S.) float above.
      return !_isBarRepeatMark(element);
    }
    return false;
  }

  /// Navigation/text repeat marks float above the staff (no spacing impact).
  /// Bar-repeat marks (double-bar repeats, simile strokes) stay in the flow.
  bool _isBarRepeatMark(RepeatMark mark) {
    switch (mark.type) {
      case RepeatType.repeatLeft:
      case RepeatType.repeatRight:
      case RepeatType.repeatBoth:
      case RepeatType.start:
      case RepeatType.end:
      case RepeatType.repeat1Bar:
      case RepeatType.repeat2Bars:
      case RepeatType.repeat4Bars:
      case RepeatType.simile:
      case RepeatType.percentRepeat:
      case RepeatType.repeatDots:
        return true;
      default:
        return false;
    }
  }

  // ESPAÇAMENTO APÓS ELEMENTOS DE System: MÃƒÂNIMO necessário
  double _calculateSpacingAfterSystemElementsCorrected(
    List<MusicalElement> systemElements,
    List<MusicalElement> musicalElements,
  ) {
    // Espaço MÃƒÂNIMO após elementos de system
    double baseSpacing = staffSpace * 1.2; // MUITO REDUZIDO!

    bool hasClef = systemElements.any((e) => e is Clef);
    bool hasTimeSignature = systemElements.any((e) => e is TimeSignature);

    if (hasClef && hasTimeSignature) {
      // If tem clef And fórmula de measure, reduzir still more
      baseSpacing = staffSpace * 1.0; // MÃƒÂNIMO!
    } else if (hasClef) {
      baseSpacing = staffSpace * 1.2;
    }

    // Armadura with muitos accidentals needs de a pouco more
    for (final element in systemElements) {
      if (element is KeySignature && element.count.abs() >= 4) {
        baseSpacing += staffSpace * 0.3; // Pequeno incremento
      }
    }

    // CORREÇÃO: Check if primeira note tem accidental EXPLÃƒÂCITO
    if (musicalElements.isNotEmpty) {
      final firstMusicalElement = musicalElements.first;

      if (firstMusicalElement is Note &&
          firstMusicalElement.pitch.accidentalGlyph != null) {
        baseSpacing += staffSpace * 0.8; // Espaço para acidente explícito
      } else if (firstMusicalElement is Chord) {
        bool hasAccidental = firstMusicalElement.notes.any(
          (note) => note.pitch.accidentalGlyph != null,
        );
        if (hasAccidental) {
          baseSpacing += staffSpace * 0.8;
        }
      }
    }

    return baseSpacing.clamp(
      staffSpace * 1.0,
      staffSpace * 3.0,
    ); // Limites reduzidos
  }

  /// Horizontal advance this element occupies, in pixels.
  ///
  /// Public so hit-testing and export can build the same boxes the layout used
  /// (they must not re-derive them, or selection drifts from what is drawn).
  /// Width an element hangs to the LEFT of its own origin (the accidental).
  ///
  /// Exposed so hit-testing and collision code can build a box that matches
  /// what is drawn instead of assuming the whole width lies to the right.
  double elementLeftExtent(MusicalElement element) => _leftExtent(element);

  double elementWidth(MusicalElement element) =>
      _getElementWidthSimple(element);

  /// How far this element's INK reaches to the right of its own origin, in
  /// pixels — which is not the same thing as [elementWidth].
  ///
  /// [elementWidth] is the horizontal ADVANCE: how far the cursor moves on, and
  /// therefore what spacing is built from. A flag deliberately hangs over the
  /// gap that follows its note rather than widening it (Gould), so the advance
  /// correctly ignores it.
  ///
  /// Two consumers do not want the advance, though — they want the ink:
  ///
  ///  * `ScoreHitTester`, because a box built from the advance stops at the
  ///    stem and the flag is unclickable;
  ///  * the raster/PDF content width, because a page sized to the advance clips
  ///    the flag of the last note on a system.
  ///
  /// Measured at `staffSpace = 48` before this existed: a stem-up eighth painted
  /// 101 px into a 56.6 px reservation — 44.5 px, 0.93 staff spaces, of flag
  /// outside every box built from the advance. `flag8thUp` alone advances 1.056
  /// staff spaces past the stem.
  ///
  /// The flag is only counted when the stem points UP: SMuFL draws the down
  /// flag on the left of a down stem, which sits at the notehead's left edge, so
  /// a down flag adds nothing to the right of the origin. Stem direction is
  /// taken from the layout's own [noteStaffPositions] when the note was laid out
  /// by this engine, so the answer matches what was drawn rather than guessing.
  double elementPaintedRightExtent(MusicalElement element) {
    final advance = _rightExtent(element);
    final flag = _flagOverhang(element);
    return flag > advance ? flag : advance;
  }

  /// Ink the flag adds to the right of the element's origin, or 0.0 when the
  /// element carries no flag or its flag points the other way.
  double _flagOverhang(MusicalElement element) {
    final Note? note = element is Note
        ? element
        : (element is Chord && element.notes.isNotEmpty
            ? element.notes.first
            : null);
    if (note == null) return 0.0;
    if (!note.duration.type.needsFlag) return 0.0;
    // A beamed note has no flag: the beam replaces it.
    if (beamOf(note) != null) return 0.0;

    final position = _noteStaffPositions[note];
    final stemUp = position == null ? true : position < 0;
    if (!stemUp) return 0.0;

    final glyph = switch (note.duration.type) {
      DurationType.eighth => 'flag8thUp',
      DurationType.sixteenth => 'flag16thUp',
      DurationType.thirtySecond => 'flag32ndUp',
      DurationType.sixtyFourth => 'flag64thUp',
      _ => null,
    };
    if (glyph == null) return 0.0;

    // The flag hangs off the stem, and the stem of an up-stemmed note sits at
    // the RIGHT edge of the notehead.
    final stemX = _noteheadAdvance(note.duration.type) * staffSpace;
    return stemX + _getGlyphWidth(glyph, 1.056) * staffSpace;
  }

  /// Advance width of an accidental glyph, in staff spaces, straight from the
  /// SMuFL metadata.
  ///
  /// This replaces a chain of `glyphName.contains(...)` tests whose branch
  /// order made the double-flat case UNREACHABLE ('accidentalDoubleFlat'
  /// contains 'Flat', so it matched the first branch and reserved 1.18 instead
  /// of Bravura's real 1.652 — the accidental then collided with the previous
  /// note). The natural was hardcoded at 0.92 against a real 0.672, and the
  /// flat fallback had been copied from `noteheadBlack`. All of those numbers
  /// were already sitting in `bravura_metadata.json`.
  double _accidentalAdvanceWidth(String glyphName) {
    if (metadata != null && metadata!.hasGlyph(glyphName)) {
      return metadata!.getGlyphWidth(glyphName);
    }
    // Fallbacks are the Bravura values, used only when metadata is missing.
    const fallbacks = <String, double>{
      'accidentalSharp': 0.996,
      'accidentalFlat': 0.904,
      'accidentalNatural': 0.672,
      'accidentalDoubleSharp': 1.0,
      'accidentalDoubleFlat': 1.652,
    };
    return fallbacks[glyphName] ?? _accidentalSharpWidthFallback;
  }

  /// Width an element occupies to the LEFT of its own origin, in pixels.
  ///
  /// An accidental is drawn BEFORE its notehead, so the space it needs belongs
  /// to the gap that precedes the note — not to the gap that follows it. The
  /// engine used to charge the whole of [_getElementWidthSimple] (accidental
  /// included) to the advance AFTER the note and put a flat `0.15` staff spaces
  /// in front of it. Measured on `C4, E4-sharp, G4, B4` at unbounded width:
  /// the gap BEFORE the sharp grew by 6.30 px and the gap AFTER it by 15.55 px,
  /// with a baseline gap of 56.16 px. The reservation was on the wrong side, so
  /// the accidental leaned into the previous note while an equal amount of
  /// empty space opened up on its right.
  double _leftExtent(MusicalElement element) {
    if (element is Note) {
      final glyph = _effectiveAccidentalGlyph(element);
      if (glyph == null) return 0.0;
      // SMuFL advises 0.25-0.3 staff spaces between accidental and notehead.
      return (_accidentalAdvanceWidth(glyph) + 0.3) * staffSpace;
    }
    if (element is Rest) {
      // A rest is DRAWN CENTRED on its origin (`RestRenderer` passes
      // `GlyphDrawOptions.restDefault`, i.e. `centerHorizontally: true`) while
      // every other element is drawn from its origin rightwards. So half of a
      // rest's glyph lives to the LEFT of the point the layout placed it at, and
      // that half belongs to the gap BEFORE it — exactly like an accidental.
      //
      // It used to report 0, so the reservation was `[x, x + advance]` against
      // ink at `[x - advance/2, x + advance/2]`: measured at staffSpace 48, a
      // rest painted 0.6-0.9 staff spaces outside its reserved band on the left,
      // which under compression is a collision with the preceding note. The
      // painted WIDTH always matched the reservation to within a pixel (52.0
      // against 51.9 for a quarter rest) — it was only ever in the wrong place.
      return _getElementWidthSimple(element) / 2;
    }
    if (element is Chord) {
      // The reservation is whatever `ChordRenderer` actually draws to the left
      // of the chord's origin: the packed accidental COLUMNS plus a stem-down
      // cluster's displaced notehead. It used to be "the widest accidental +
      // 0.5", i.e. exactly one column: measured, a chord with 2, 3, 4 OR 5
      // accidentals all reported the same 25.82 px while the renderer drew as
      // many columns as the vertical packing needed, each offset left by the
      // previous column's width — so the stack ran back into the previous
      // element.
      return _chordGeometryOf(element).leftExtent;
    }
    if (element is Tuplet) {
      // A tuplet is placed as ONE element at the X of its first child, so an
      // accidental on that child hangs to the LEFT of the tuplet's own origin
      // exactly as it would for a bare note. This returned 0, so a triplet
      // opening on a double flat reserved nothing and the accidental leaned
      // into the previous note.
      for (final inner in element.elements) {
        final extent = _leftExtent(inner);
        if (extent > 0) return extent;
        // Only the FIRST child sits at the tuplet's origin; a later child is
        // already past it on the inner grid and pays for itself there.
        if (inner is Note || inner is Chord || inner is Rest) return 0.0;
      }
      return 0.0;
    }
    return 0.0;
  }

  /// Width an element occupies to the RIGHT of its own origin, in pixels:
  /// the total width minus whatever hangs to the left. This is what the cursor
  /// advances by once the element has been placed.
  double _rightExtent(MusicalElement element) =>
      _getElementWidthSimple(element) - _leftExtent(element);

  double _getElementWidthSimple(MusicalElement element) {
    if (element is Clef) {
      double clefWidth;
      switch (element.actualClefType) {
        case ClefType.treble:
        case ClefType.treble8va:
        case ClefType.treble8vb:
        case ClefType.treble15ma:
        case ClefType.treble15mb:
          clefWidth = gClefWidth;
          break;
        case ClefType.bass:
        case ClefType.bassThirdLine:
        case ClefType.bass8va:
        case ClefType.bass8vb:
        case ClefType.bass15ma:
        case ClefType.bass15mb:
          clefWidth = fClefWidth;
          break;
        default:
          clefWidth = cClefWidth;
      }
      return (clefWidth + 0.5) * staffSpace;
    }

    if (element is KeySignature) {
      // Reserve width for cancellation naturals of the outgoing key, which the
      // renderer draws before the new accidentals: previousCount.abs() naturals
      // at 0.8 SS each + a 0.5 SS gap (mirrors bar_element_renderer).
      double width = 0;
      final prev = element.previousCount;
      if (prev != null && prev != 0) {
        width += (prev.abs() * 0.8 + 0.5) * staffSpace;
      }
      if (element.count == 0) {
        // C major: only the cancellation naturals (if any), else a small pad.
        return width == 0 ? 0.5 * staffSpace : width;
      }
      final accidentalWidth = element.count > 0
          ? accidentalSharpWidth
          : accidentalFlatWidth;
      width += (element.count.abs() * 0.8 + accidentalWidth) * staffSpace;
      return width;
    }

    if (element is TimeSignature) {
      // Free time draws nothing, so it reserves no width.
      if (element.isFreeTime) return 0;
      // Width scales with the widest of the numerator/denominator digit counts
      // so multi-digit meters (12/8, 16, …) reserve enough room.
      final denDigits = element.denominator.toString().length;
      int numDigits;
      if (element.isAdditive) {
        // Group digits + one '+' separator slot per inter-group gap.
        final groups = element.additiveGroups!;
        numDigits = groups.fold<int>(0, (a, g) => a + g.numerator.toString().length) +
            (groups.length - 1);
      } else {
        numDigits = element.numerator.toString().length;
      }
      final digits = numDigits > denDigits ? numDigits : denDigits;
      return (1.6 + 1.4 * digits) * staffSpace;
    }

    if (element is Note) {
      double width = _noteheadAdvance(element.duration.type) * staffSpace;
      final accGlyph = _effectiveAccidentalGlyph(element);
      if (accGlyph != null) {
        // SMuFL advises 0.25-0.3 staff spaces between accidental and notehead.
        width += (_accidentalAdvanceWidth(accGlyph) + 0.3) * staffSpace;
      }
      // Augmentation dots sit to the right of the notehead (DotRenderer: first
      // dot at centre + 1.0 SS, each further +0.6 SS), extending ~0.7 SS past
      // the notehead's right edge. Reserve it so dots never crowd the next note.
      if (element.duration.dots > 0) {
        width += (0.7 + (element.duration.dots - 1) * 0.6) * staffSpace;
      }
      return width;
    }

    if (element is Rest) {
      // The real advance of the rest glyph the renderer will draw, from the
      // metadata — the same way the note path reads `noteheadBlack`. Every
      // rest used to reserve a flat 1.5 staff spaces regardless of duration,
      // while Bravura measures `restWhole` 1.132, `restQuarter` 1.08,
      // `rest8th` 1.0 and `rest64th` 1.696: the short rests were
      // over-reserved and the heavily flagged ones under-reserved.
      final glyph = RestRenderer.glyphNameFor(element.duration.type);
      var width = (metadata?.getGlyphAdvanceWidth(glyph) ??
              _restAdvanceFallbacks[glyph] ??
              1.5) *
          staffSpace;
      // Augmentation dots sit to the right of the rest body: `RestRenderer`
      // puts the first at `advance + 0.25 SS` and each further one 0.45 further
      // right, and a dot glyph is ~0.3 SS wide.
      if (element.duration.dots > 0) {
        width += (0.55 + (element.duration.dots - 1) * 0.45) * staffSpace;
      }
      return width;
    }

    if (element is Chord) {
      // Same single geometry the renderer draws with — see [_leftExtent].
      return _chordGeometryOf(element).width;
    }

    if (element is RepeatMark) {
      return _estimateRepeatMarkWidth(element);
    }

    if (element is MusicText) {
      return _estimateMusicTextWidth(element);
    }

    if (element is Dynamic) return 2.0 * staffSpace;
    if (element is Ornament) return 1.0 * staffSpace;

    if (element is Tuplet) {
      // Width comes from the inner content laid out on the SHARED grid, so the
      // measure width, the note positions and the drawing all agree.
      //
      // `TupletGrid.totalWidth` measures the grid span from the tuplet's
      // ORIGIN rightwards, so the first child's accidental — which hangs to
      // the left of that origin — has to be added on top. Without it
      // `_rightExtent` (total minus left extent) would come out short by the
      // accidental and the following element would be pulled into the tuplet.
      return _tupletSlots(element).fold<double>(0.0, (a, b) => a + b) +
          _leftExtent(element);
    }

    if (element is TempoMark) {
      return _estimateTempoMarkWidth(element);
    }

    if (element is VoltaBracket) {
      return 0.0; // VoltaBracket renderizado acima, sem largura
    }

    if (element is OctaveMark) {
      return 0.0; // OctaveMark renderizado acima, sem largura
    }

    return staffSpace;
  }

  double _estimateMusicTextWidth(MusicText text) {
    final trimmedText = text.text.trim();
    if (trimmedText.isEmpty) {
      return 0.0;
    }

    final fontSize = text.fontSize ?? _defaultMusicTextFontSize(text.type);
    return _estimatePlainTextWidth(
      trimmedText,
      fontSize: fontSize,
      averageCharacterFactor: 0.58,
      horizontalPadding: coordinatesTextPaddingFor(text.type),
    );
  }

  double _estimateRepeatMarkWidth(RepeatMark repeatMark) {
    final fallbackText = _repeatMarkFallbackTextForLayout(repeatMark.type);
    if (fallbackText != null) {
      return _estimatePlainTextWidth(
        fallbackText,
        fontSize: staffSpace * 1.25,
        averageCharacterFactor: 0.62,
        horizontalPadding: staffSpace,
      );
    }

    final glyphName = _getRepeatMarkGlyphNameForLayout(repeatMark.type);
    final scale = _getRepeatMarkScaleForLayout(repeatMark.type);
    double width = staffSpace * 1.8;

    if (glyphName != null) {
      width =
          (_getGlyphWidth(glyphName, noteheadBlackWidth) * staffSpace * scale) +
          (staffSpace * 0.75);
    } else {
      switch (repeatMark.type) {
        case RepeatType.repeat4Bars:
          width = staffSpace * 2.6;
          break;
        case RepeatType.repeat2Bars:
        case RepeatType.simile:
        case RepeatType.percentRepeat:
          width = staffSpace * 2.2;
          break;
        default:
          break;
      }
    }

    if (_getRepeatCountLabelForLayout(repeatMark) != null) {
      width += staffSpace * 0.65;
    }

    if (width < staffSpace * 1.6) {
      width = staffSpace * 1.6;
    }

    return width;
  }

  double _estimatePlainTextWidth(
    String text, {
    required double fontSize,
    required double averageCharacterFactor,
    required double horizontalPadding,
  }) {
    return (text.length * fontSize * averageCharacterFactor) +
        horizontalPadding;
  }

  double _defaultMusicTextFontSize(TextType type) {
    switch (type) {
      case TextType.tempo:
        return staffSpace * 1.3;
      case TextType.expression:
      case TextType.instruction:
      case TextType.dynamics:
        return staffSpace * 1.1;
      default:
        return staffSpace;
    }
  }

  double coordinatesTextPaddingFor(TextType type) {
    switch (type) {
      case TextType.tempo:
        return staffSpace * 1.1;
      case TextType.expression:
      case TextType.instruction:
      case TextType.dynamics:
        return staffSpace * 0.9;
      default:
        return staffSpace * 0.7;
    }
  }

  String? _repeatMarkFallbackTextForLayout(RepeatType type) {
    switch (type) {
      case RepeatType.dalSegno:
        return 'D.S.';
      case RepeatType.dalSegnoAlCoda:
        return 'D.S. al Coda';
      case RepeatType.dalSegnoAlFine:
        return 'D.S. al Fine';
      case RepeatType.daCapo:
        return 'D.C.';
      case RepeatType.daCapoAlCoda:
        return 'D.C. al Coda';
      case RepeatType.daCapoAlFine:
        return 'D.C. al Fine';
      case RepeatType.fine:
        return 'Fine';
      case RepeatType.toCoda:
        return 'To Coda';
      default:
        return null;
    }
  }

  String? _getRepeatMarkGlyphNameForLayout(RepeatType type) {
    for (final glyph in _repeatGlyphCandidatesForLayout(type)) {
      if (metadata != null && metadata!.hasGlyph(glyph)) {
        return glyph;
      }
    }
    return null;
  }

  List<String> _repeatGlyphCandidatesForLayout(RepeatType type) {
    switch (type) {
      case RepeatType.segno:
        return const ['segno'];
      case RepeatType.coda:
        return const ['coda'];
      case RepeatType.segnoSquare:
        return const ['segnoSerpent1', 'segno'];
      case RepeatType.codaSquare:
        return const ['codaSquare', 'coda'];
      case RepeatType.repeat1Bar:
        return const ['repeat1Bar'];
      case RepeatType.repeat2Bars:
        return const ['repeat2Bars'];
      case RepeatType.repeat4Bars:
        return const ['repeat4Bars'];
      case RepeatType.simile:
        return const ['simile', 'repeatBarSlash'];
      case RepeatType.percentRepeat:
        return const ['percent', 'repeatSlash'];
      case RepeatType.repeatDots:
        return const ['repeatDots'];
      case RepeatType.repeatLeft:
      case RepeatType.start:
        return const ['repeatLeft'];
      case RepeatType.repeatRight:
      case RepeatType.end:
        return const ['repeatRight'];
      case RepeatType.repeatBoth:
        return const ['repeatLeftRight'];
      case RepeatType.dalSegno:
      case RepeatType.dalSegnoAlCoda:
      case RepeatType.dalSegnoAlFine:
      case RepeatType.daCapo:
      case RepeatType.daCapoAlCoda:
      case RepeatType.daCapoAlFine:
      case RepeatType.fine:
      case RepeatType.toCoda:
        return const [];
    }
  }

  double _getRepeatMarkScaleForLayout(RepeatType type) {
    switch (type) {
      case RepeatType.segno:
      case RepeatType.coda:
      case RepeatType.segnoSquare:
      case RepeatType.codaSquare:
        return 0.64;
      case RepeatType.repeat1Bar:
      case RepeatType.simile:
      case RepeatType.percentRepeat:
        return 0.92;
      case RepeatType.repeat2Bars:
      case RepeatType.repeat4Bars:
        return 0.9;
      case RepeatType.repeatDots:
      case RepeatType.repeatLeft:
      case RepeatType.repeatRight:
      case RepeatType.repeatBoth:
      case RepeatType.start:
      case RepeatType.end:
        return 1.0;
      case RepeatType.dalSegno:
      case RepeatType.dalSegnoAlCoda:
      case RepeatType.dalSegnoAlFine:
      case RepeatType.daCapo:
      case RepeatType.daCapoAlCoda:
      case RepeatType.daCapoAlFine:
      case RepeatType.fine:
      case RepeatType.toCoda:
        return 0.9;
    }
  }

  String? _getRepeatCountLabelForLayout(RepeatMark repeatMark) {
    if (repeatMark.times != null) {
      return repeatMark.times!.toString();
    }

    switch (repeatMark.type) {
      case RepeatType.repeat2Bars:
        return '2';
      case RepeatType.repeat4Bars:
        return '4';
      default:
        return null;
    }
  }

  double _estimateTempoMarkWidth(TempoMark tempo) {
    double width = 0.0;
    final tempoText = tempo.text?.trim();

    if (tempoText != null && tempoText.isNotEmpty) {
      // MEASURED, not counted. This was `tempoText.length * 0.38 * staffSpace`
      // — a character-count estimate against a renderer that lays the string
      // out with a real TextPainter at `staffSpace * 1.3`, semi-bold, italic,
      // with letter spacing. The estimate came out narrower than the ink, so
      // two tempo marks a few notes apart were reserved as clear of each other
      // and then drawn overlapping: "Quarter = Eighth (metronome 120)" ran
      // straight into "Range 120-132" on the tempo page.
      //
      // The style below mirrors `SymbolAndTextRenderer._tempoTextStyle`. A
      // theme that overrides `tempoTextStyle` can still widen the text past
      // this, which is the same limitation every measured element here has.
      final measured = _measuredTextWidth(
        tempoText,
        staffSpace * 1.3,
        true,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      );
      final floor = 2.4 * staffSpace;
      width += measured > floor ? measured : floor;
    }

    if (tempo.bpm != null && tempo.showMetronome) {
      width +=
          (tempoText == null || tempoText.isEmpty ? 0.8 : 1.1) * staffSpace;

      final metronomeGlyphName = _getTempoMetronomeGlyphName(tempo.beatUnit);
      final metronomeGlyphWidth = _getGlyphWidth(
        metronomeGlyphName,
        noteheadBlackWidth,
      );
      width += metronomeGlyphWidth * staffSpace * 0.46;

      final bpmDigits = tempo.bpm!.abs().toString().length;
      width += (2.6 + (bpmDigits * 0.55)) * staffSpace;
    }

    return width;
  }

  String _getTempoMetronomeGlyphName(DurationType durationType) {
    switch (durationType) {
      case DurationType.maxima:
      case DurationType.long:
      case DurationType.breve:
        return 'metNoteDoubleWhole';
      case DurationType.whole:
        return 'metNoteWhole';
      case DurationType.half:
        return 'metNoteHalfUp';
      case DurationType.quarter:
        return 'metNoteQuarterUp';
      case DurationType.eighth:
        return 'metNote8thUp';
      case DurationType.sixteenth:
        return 'metNote16thUp';
      case DurationType.thirtySecond:
        return 'metNote32ndUp';
      case DurationType.sixtyFourth:
        return 'metNote64thUp';
      case DurationType.oneHundredTwentyEighth:
      case DurationType.twoHundredFiftySixth:
      case DurationType.fiveHundredTwelfth:
      case DurationType.thousandTwentyFourth:
      case DurationType.twoThousandFortyEighth:
        return 'metNote128thUp';
    }
  }

  /// Fix: calculates rhythmic spacing based on note duration
  ///
  /// Implementa spacing proporcional to the duração das notes according to
  /// práticas profissionais de music engraving (Behind Bars, Ted Ross)
  ///
  /// @param currentElement Elemento current
  /// @param previousElement Elemento previous (opcional)
  /// @return Spacing in pixels
  /// Horizontal gap to leave BEFORE [currentElement], given the element that
  /// precedes it.
  ///
  /// Gould's square-root law: the space an event occupies grows with the square
  /// root of its duration, normalised to the quarter note. The factor is
  /// COMPUTED, not looked up: the old table only covered `whole`..`sixtyFourth`
  /// and fell back to `1.0` for everything else, so a breve was spaced like a
  /// quarter (narrower than a whole note!) and a 128th got 2.3x the space of a
  /// 64th — the rhythmic proportion inverted at both ends of the range. It also
  /// ignored augmentation dots; `absoluteValue` includes them.
  double _calculateRhythmicSpacing(
    MusicalElement currentElement,
    MusicalElement? previousElement,
  ) {
    const double baseSpacing = noteMinSpacing;

    Duration? durationOf(MusicalElement? e) {
      if (e is Note) return e.duration;
      if (e is Chord) return e.duration;
      if (e is Rest) return e.duration;
      return null;
    }

    final prevDuration = durationOf(previousElement);

    // No previous rhythmic element (start of measure/system): use base spacing.
    if (prevDuration == null) {
      return baseSpacing * staffSpace * _spacingScale;
    }

    // The law itself lives in IntelligentSpacingEngine: sqrt(duration/quarter),
    // normalised to the quarter note, times the rest ratio when the previous
    // event was a rest. Calling it here is what puts that engine on the
    // production path — it used to be constructed, covered by 390 lines of
    // green tests, and never invoked, so those tests proved nothing about what
    // the renderer actually did.
    double spacing = _spacingEngine.interNoteSpacing(
      previousDuration: prevDuration,
      previousIsRest: previousElement is Rest,
      staffSpace: staffSpace,
      baseSpacing: baseSpacing,
    );

    // Context-sensitive optical compensation (alternating stems, rest before a
    // stem-up note, duration transitions). Returns 0.0 unless the caller
    // enabled it in SpacingPreferences.
    spacing += _spacingEngine.opticalAdjustment(
      previous: previousElement,
      current: currentElement,
      staffSpace: staffSpace,
      previousIsBeamed: _isBeamedForSpacing(previousElement),
      currentIsBeamed: _isBeamedForSpacing(currentElement),
    );

    // Leading space for the CURRENT element's accidental, which hangs to the
    // left of its notehead into THIS gap. The real metadata advance is used,
    // not a flat constant: `accidentalDoubleFlat` is 1.652 staff spaces wide
    // against `accidentalNatural`'s 0.672, and a constant cannot serve both.
    spacing += _leftExtent(currentElement);

    // A lyric syllable is centred on its notehead, so its left half hangs into
    // this gap. Without this a long syllable simply overlapped the previous
    // note (measured: "Extraordinarily" produced exactly the same spacing as no
    // syllable at all).
    final leadIn = _syllableOverhang(currentElement) +
        _syllableOverhang(previousElement);
    if (leadIn > 0) spacing += leadIn;

    spacing *= _spacingScale;

    // Never let compression (or an ultra-short duration) push two noteheads
    // into each other.
    final minimum = _minimumInterNoteGap(currentElement, previousElement);
    return spacing < minimum ? minimum : spacing;
  }

  /// Half of the width a note's widest lyric syllable sticks out past its
  /// notehead, in pixels. Zero when the element carries no syllable.
  double _syllableOverhang(MusicalElement? element) {
    final syllables = element is Note
        ? element.syllables
        : (element is Chord
            ? element.notes
                .map((n) => n.syllables)
                .firstWhere((s) => s != null && s.isNotEmpty,
                    orElse: () => null)
            : null);
    if (syllables == null || syllables.isEmpty) return 0.0;

    double widest = 0;
    for (final syllable in syllables) {
      final w = _syllableWidth(syllable);
      if (w > widest) widest = w;
    }
    final head = noteheadBlackWidth * staffSpace;
    final overhang = (widest - head) / 2;
    return overhang > 0 ? overhang : 0.0;
  }

  /// Rendered width of one lyric syllable, matching `NoteRenderer` metrics
  /// (font size = 0.85 staff spaces; ~0.5 em average advance per character).
  double _syllableWidth(Syllable syllable) {
    var text = syllable.text;
    if (syllable.type == SyllableType.initial ||
        syllable.type == SyllableType.middle) {
      text = '$text-';
    }
    if (text.isEmpty) return 0.0;

    const double lyricFontFactor = 0.85;
    final fontSize = staffSpace * lyricFontFactor;
    return _measuredTextWidth(text, fontSize, syllable.italic);
  }

  /// Rendered width of [text], measured with the same font stack and metrics
  /// `NoteRenderer._renderSyllable` draws with.
  ///
  /// This used to be `text.length * staffSpace * 0.85 * 0.5` — a character
  /// COUNT with an assumed half-em advance. "WWWWW" and "iiiii" reserved the
  /// same room, an ideograph reserved a third of what it needs, and the number
  /// never agreed with what the renderer actually painted. Layout and rendering
  /// disagreeing about a width is the F-12 pattern; measuring both with the
  /// same `TextPainter` makes them agree by construction.
  ///
  /// The measurement is cached: a syllable is re-measured on every relayout
  /// otherwise, and a `TextPainter.layout()` is not free.
  static final LruCache<String, double> _textWidthCache = LruCache(512);

  double _measuredTextWidth(
    String text,
    double fontSize,
    bool italic, {
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    final key = '${fontSize.toStringAsFixed(2)}|${italic ? 'i' : 'r'}'
        '|${fontWeight?.value ?? -1}|${letterSpacing ?? 0}|$text';
    final cached = _textWidthCache.get(key);
    if (cached != null) return cached;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
          height: 1.0,
        ).withMusicTextFallback(),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    _textWidthCache.put(key, width);
    return width;
  }

  /// Absolute floor for the gap between two consecutive rhythmic events.
  ///
  /// It has to clear whatever the PREVIOUS element leaves behind to its right
  /// plus whatever the CURRENT element hangs to its left, with a hair of air
  /// between them. Compression may squeeze the proportional spacing away, but
  /// it may never squeeze this.
  ///
  /// The accidental term used to be a flat `staffSpace * 0.6`, which is smaller
  /// than most accidentals and less than a third of a double flat. Measured: 32
  /// sixteenths each carrying a double flat, compressed into 400 px, came out
  /// 26.90 px apart — a 14.16 px notehead leaves 12.74 px of free space, and
  /// `accidentalDoubleFlat` is 19.82 px wide, so it drove 7.08 px into the
  /// previous notehead. The floor now asks the metadata.
  double _minimumInterNoteGap(
    MusicalElement currentElement,
    MusicalElement? previousElement,
  ) {
    final head = noteheadBlackWidth * staffSpace;
    // The cursor has already advanced past the previous element's right extent
    // when this gap is applied, so the floor only has to cover what the CURRENT
    // element hangs to its left, plus air. Adding the previous extent here
    // would double-count it.
    return _leftExtent(currentElement) + head * 0.9;
  }

  /// Meter assumed for a bar that states none, shared across every such bar.
  ///
  /// `Measure.timeSignature` only reports a meter the bar CARRIES, so on a
  /// staff that states 4/4 once and inherits it everywhere else this default is
  /// what every remaining bar beams against — and it used to be a fresh
  /// `TimeSignature` per bar (12 799 of them on the 12 800-bar fixture) purely
  /// to be read twice and dropped. One shared instance is also what lets
  /// `BeamGrouper` recognise the meter it just computed a beat table for.
  static final TimeSignature _defaultBeamingMeter =
      TimeSignature(numerator: 4, denominator: 4);

  /// Resolves beam membership for one run of [elements] into [out], keyed by
  /// note identity. **Nothing is written to the model.**
  ///
  /// The engine originally built replacement [Note] objects here so it could
  /// store the resolved [BeamType]. That silently broke every identity-keyed
  /// map built before this point (accidental decisions, note X/Y positions),
  /// made the layout signature differ between two identical runs, and dropped a
  /// note whenever the same instance appeared twice in a measure. The fix was
  /// to stamp the caller's own objects — which kept identity but made LAYOUT a
  /// mutation of the caller's music (M-26). The answer is a value map now; see
  /// [beams] for the measured export drift that motivated it.
  ///
  /// Notes that end up in no valid group are simply absent from [out], and
  /// [beamOf] then falls back to whatever beam the author set — the same
  /// behaviour the in-place version had.
  ///
  /// [beamingContext] supplies the bar's meter and beaming policy; for a
  /// `MultiVoiceMeasure` the run is one voice but the policy is still the
  /// measure's, exactly as `_layoutMultiVoiceMeasure` used it.
  void _resolveBeamsInto(
    Map<Note, BeamType> out,
    List<MusicalElement> elements,
    Measure beamingContext,
  ) {
    if (!elements.any((e) => e is Note)) return;

    final beamGroups = BeamGrouper.groupElementsForBeaming(
      elements,
      beamingContext.timeSignature ?? _defaultBeamingMeter,
      autoBeaming: beamingContext.autoBeaming,
      beamingMode: beamingContext.beamingMode,
      manualBeamGroups: beamingContext.manualBeamGroups,
    );

    for (final group in beamGroups) {
      if (!group.isValid) continue;
      final last = group.notes.length - 1;
      for (int i = 0; i <= last; i++) {
        out[group.notes[i]] = i == 0
            ? BeamType.start
            : (i == last ? BeamType.end : BeamType.inner);
      }
    }
  }

  /// Whether the spacing engine should treat [element] as beamed — the
  /// ENGINE-RESOLVED answer, not the one on the model. `null` for anything that
  /// is not a [Note], which leaves `IntelligentSpacingEngine` reading the
  /// element's own `beam` field exactly as it did before.
  ///
  /// `IntelligentSpacingEngine._opticalContextFor` fills
  /// `OpticalContext.beamCount` from the beam flag, and the optical compensator
  /// spaces a BEAMED neighbour differently from a flagged one. The engine no
  /// longer writes its answer back into the caller's notes (see [beams]), so
  /// without this the spacing engine would see `null` for every automatically
  /// beamed note and space the staff as if nothing were beamed at all.
  /// Measured on two bars of loose eighths at 900 px, pixelRatio 2: the ink ran
  /// to x = 1742 instead of x = 1732 and 17 647 pixels of the raster changed.
  ///
  /// This used to be a `_spacingProxy` that built a throw-away [Note] carrying
  /// the resolved beam and cached it in an identity map, because the spacing
  /// engine could only be told about a beam through a model object. It can be
  /// told directly now (`opticalAdjustment(previousIsBeamed:, currentIsBeamed:)`),
  /// and the difference is not small: on 12 800 bars of eighths (119 468
  /// elements, 1200 px, staffSpace 12) the proxies were 102 400 surplus [Note]
  /// objects plus a 102 400-entry identity map held live for the whole layout,
  /// measured at **714 ms with them and 611 ms without** — 1.17x, for zero
  /// pixels of difference.
  bool? _isBeamedForSpacing(MusicalElement? element) =>
      element is Note ? beamOf(element) != null : null;

  /// Total musical duration of [measure] in whole notes, voice aware: two
  /// voices sounding together occupy the same time, so the bar lasts as long as
  /// its longest voice, not as long as the sum of every note in it.
  double _measureMusicalDuration(Measure measure) {
    double durationOf(Iterable<MusicalElement> els) {
      double total = 0;
      for (final e in els) {
        total += _getRhythmicValue(e);
      }
      return total;
    }

    if (measure is MultiVoiceMeasure) {
      double longest = durationOf(measure.elements);
      for (final voice in measure.sortedVoices) {
        final v = durationOf(voice.elements);
        if (v > longest) longest = v;
      }
      return longest;
    }

    // Single-voice measures may still carry `Note.voice` tags (MusicXML import
    // writes them), so bucket by voice before summing.
    //
    // The bucket map is only built once a SECOND voice number actually shows
    // up, which for a monophonic bar is never. This is called twice per bar
    // (once to advance the onset clock, once from the octave timeline) on a
    // path that sees every bar of the score, so on the 12 800-bar fixture the
    // unconditional map was 25 600 hash maps per layout pass, each holding one
    // entry.
    int? soleVoice;
    var soleTotal = 0.0;
    Map<int, double>? byVoice;
    for (final e in measure.elements) {
      final value = _getRhythmicValue(e);
      if (value <= 0) continue;
      final v = e is Note ? (e.voice ?? 1) : (e is Chord ? (e.voice ?? 1) : 1);
      if (byVoice == null) {
        if (soleVoice == null || soleVoice == v) {
          soleVoice = v;
          soleTotal += value;
          continue;
        }
        byVoice = <int, double>{soleVoice: soleTotal};
      }
      byVoice[v] = (byVoice[v] ?? 0) + value;
    }
    if (byVoice == null) return soleVoice == null ? 0.0 : soleTotal;
    return byVoice.values.reduce((a, b) => a > b ? a : b);
  }

  /// Total horizontal extent of [elements], including the right-hand glyph of
  /// the last element and the right margin.
  ///
  /// The widget sizes its canvas from this number. If it under-reports, music
  /// is clipped away with no way to scroll to it (F-05b).
  /// The right edge of an element is `dx + width - leftExtent`, not
  /// `dx + width`: [_getElementWidthSimple] is the TOTAL advance and part of it
  /// (an accidental, a chord's accidental column block, a stem-down cluster
  /// notehead) hangs to the LEFT of `dx`. Measured: a note carrying a double
  /// flat placed at x = 115.63 has a true right edge of 129.79 px but
  /// contributed 153.21 px — 23.42 px of phantom width, exactly the accidental
  /// it draws BEHIND itself, reported once again in front.
  double contentWidth(List<PositionedElement> elements) {
    if (elements.isEmpty) return systemMargin * 2 * staffSpace;
    var maxRight = 0.0;
    for (final positioned in elements) {
      final element = positioned.element;
      // Painted extent, not advance. A flag hangs past its note's advance on
      // purpose (Gould) — sizing the canvas to the advance clips the flag of
      // the last note on the system.
      final right =
          positioned.position.dx + elementPaintedRightExtent(element);
      if (right > maxRight) maxRight = right;
    }
    // Justification already parks the last element on the right margin, so only
    // a hair of trailing air is added here — adding a full margin again would
    // report a phantom overflow for every justified system.
    return maxRight + staffSpace * 0.5;
  }

  /// Whether the laid-out music is wider than the line it was given, i.e. the
  /// host must provide horizontal scrolling for all of it to be reachable.
  bool overflowsAvailableWidth(List<PositionedElement> elements) =>
      contentWidth(elements) > availableWidth + 0.5;

  /// Appends one [warnings] entry for a measure that bottomed out at
  /// [minimumSpacingScale] and still does not fit.
  ///
  /// Called AFTER the bar is positioned, on purpose: the pre-pass
  /// `measureWidth` is an estimate built by a throw-away cursor, and quoting it
  /// understates the damage. Measured on the 40-whole-notes bar of finding
  /// M-46 at 900 px — the exact case the audit filed — the estimate-based
  /// factor was **1.64x** while the bar as positioned reaches
  /// `x = 1829.2 px`, i.e. **2.03x** the viewport. The audit's own number,
  /// 2.07x, is the same overflow measured from the staff-wide
  /// `maxX = 1865.2 px` (which includes the closing barline, laid out after
  /// this measure's slice ends); `contentWidth` for the whole staff is
  /// 1883.2 px.
  ///
  /// The right edge is computed exactly as [contentWidth] computes it —
  /// `dx + width - leftExtent` — because an accidental hangs to the LEFT of its
  /// note's origin and a naive `dx + width` reports phantom width for it.
  void _recordOverflowWarning({
    required int measureIndex,
    required List<PositionedElement> positionedElements,
    required int measureStartIndex,
  }) {
    var right = 0.0;
    for (var k = measureStartIndex; k < positionedElements.length; k++) {
      final positioned = positionedElements[k];
      final edge = positioned.position.dx +
          _getElementWidthSimple(positioned.element) -
          _leftExtent(positioned.element);
      if (edge > right) right = edge;
    }
    if (right <= availableWidth) return;

    final number = measureIndex < staff.measures.length
        ? (staff.measures[measureIndex].number ??
            (measureIndex + 1 + measureNumberOffset))
        : measureIndex + 1 + measureNumberOffset;
    warnings.add(
      'measure $number (index $measureIndex) does not fit: spacing compression '
      'bottomed out at the ${minimumSpacingScale.toStringAsFixed(2)} floor and '
      'the bar still reaches x = ${right.toStringAsFixed(1)} px in a '
      '${availableWidth.toStringAsFixed(1)} px line '
      '(${(right / availableWidth).toStringAsFixed(2)}x). The music is not '
      'lost — the host must scroll horizontally — but for a fixed-width medium '
      'the bar has to be re-barred or the staff space reduced.',
    );
  }

  /// Vertical distance, in staff spaces, from the top of a system's block to
  /// its staff baseline. The painter places system N's baseline at
  /// `N * systemHeightSpaces + firstBaselineSpaces` staff spaces.
  static const double firstBaselineSpaces = 5.0;
  static const double systemHeightSpaces = 10.0;

  /// How much taller than the default headroom this score needs above the first
  /// staff line, in pixels. Zero when everything fits.
  ///
  /// The canvas used to start exactly [firstBaselineSpaces] staff spaces above
  /// the first baseline, whatever the music did. Anything reaching higher was
  /// simply cut off with no scroll and no warning: a C9 in treble clef landed at
  /// y = -114 on a canvas 192 px tall, and a boxed rehearsal mark sat entirely
  /// above the top edge. Callers add this to their canvas height and translate
  /// the origin down by the same amount.
  double contentTopOverflow(List<PositionedElement> elements) {
    if (elements.isEmpty) return 0.0;

    final headroom = firstBaselineSpaces * staffSpace;
    var worst = 0.0;

    for (final positioned in elements) {
      final baseline =
          (positioned.system * systemHeightSpaces + firstBaselineSpaces) *
              staffSpace;
      final reach =
          (baseline - positioned.position.dy) + _aboveStaffExtent(positioned);
      final overflow = reach - headroom;
      if (overflow > worst) worst = overflow;
    }
    return worst;
  }

  /// How much taller than the default bottom margin this score needs below the
  /// last staff line, in pixels. Zero when everything fits.
  ///
  /// The mirror of [contentTopOverflow]: a C0 in treble clef lands 264 px down
  /// on a canvas the old formula sized at 192 px, so it was cut off exactly the
  /// same way — the bug simply had two sides.
  double contentBottomOverflow(List<PositionedElement> elements) {
    if (elements.isEmpty) return 0.0;

    var maxSystem = 0;
    for (final positioned in elements) {
      if (positioned.system > maxSystem) maxSystem = positioned.system;
    }

    // Space the default formula already leaves below the LAST system's
    // baseline: the rest of its block plus the bottom margin.
    final lastBaseline =
        (maxSystem * systemHeightSpaces + firstBaselineSpaces) * staffSpace;
    final defaultBottom =
        (systemHeightSpaces - firstBaselineSpaces) * staffSpace +
            staffSpace * 2.0;

    var worst = 0.0;
    for (final positioned in elements) {
      if (positioned.system != maxSystem) continue;
      final reach = (positioned.position.dy - lastBaseline) +
          _belowStaffExtent(positioned);
      final overflow = reach - defaultBottom;
      if (overflow > worst) worst = overflow;
    }
    return worst;
  }

  /// Vertical reach of a [Tuplet], in pixels above and below its own anchor
  /// (the staff baseline it was positioned on).
  ///
  /// A bar containing nothing but a triplet used to report
  /// `contentTopOverflow = 0.00` and `contentBottomOverflow = 0.00`, because
  /// the fall-through branch of [_aboveStaffExtent] gave a `Tuplet` a flat
  /// 2.0 staff spaces — it knew nothing about the bracket, its ratio numeral,
  /// or even that the tuplet's noteheads may sit far off the staff. The
  /// bracket and its number were therefore CLIPPED out of the raster and the
  /// PDF.
  ///
  /// The reach is derived from the same rule `TupletRenderer._bracketLine`
  /// draws by — stem length + beam stack depth + clearance, measured from the
  /// extreme notehead on the stem side — plus the numeral, which sits 0.95
  /// staff spaces beyond the bracket line and is backed by an opaque mask
  /// whose height comes from a representative digit's bounding box.
  ///
  /// Nested tuplets recurse: an inner group draws its own bracket one level
  /// further out.
  ({double above, double below}) _tupletVerticalReach(
    Tuplet tuplet,
    double baselineY,
  ) {
    final noteYs = <double>[];
    var nestedAbove = 0.0;
    var nestedBelow = 0.0;

    void collect(MusicalElement element) {
      if (element is Note) {
        noteYs.add(_noteYPositions[element] ?? baselineY);
      } else if (element is Chord) {
        for (final note in element.notes) {
          noteYs.add(_noteYPositions[note] ?? baselineY);
        }
      } else if (element is Tuplet) {
        final inner = _tupletVerticalReach(element, baselineY);
        if (inner.above > nestedAbove) nestedAbove = inner.above;
        if (inner.below > nestedBelow) nestedBelow = inner.below;
      }
    }

    for (final element in tuplet.elements) {
      collect(element);
    }

    if (noteYs.isEmpty) {
      return (above: nestedAbove, below: nestedBelow);
    }

    // `TupletRenderer._stemUp`: Y grows downward, so an average BELOW the
    // middle line (larger Y) means stems — and therefore the bracket — go up.
    final averageY = noteYs.reduce((a, b) => a + b) / noteYs.length;
    final stemUp = averageY >= baselineY;

    // The beam stack the bracket has to clear comes from the SAME plan the
    // renderer draws from, so the reserved headroom and the drawn ink cannot
    // disagree. It used to be re-derived here from the FIRST note's duration
    // under a private copy of the old whitelist: an eighth followed by two
    // sixteenths reserved one beam's worth of height and drew two.
    final beamCount = TupletBeamPlan.of(tuplet.elements).beamCount;
    final beamThickness = staffSpace * 0.5;
    final beamGap = staffSpace * 0.25;
    final beamStackDepth = beamCount <= 0
        ? 0.0
        : beamThickness + ((beamCount - 1) * (beamThickness + beamGap));
    final clearance = staffSpace * (beamCount > 0 ? 0.95 : 0.75);
    final off = (staffSpace * 3.5) + beamStackDepth + clearance;

    // The numeral sits 0.95 SS past the bracket line, behind an opaque mask
    // 0.55 SS taller than the digit's own bounding box.
    final digitHeight =
        metadata?.getGlyphBoundingBox('tuplet3')?.height ?? 1.16;
    final numberReach =
        (staffSpace * 0.95) + ((digitHeight * staffSpace) + staffSpace * 0.55) / 2;

    // Signed distances from the anchor to the extreme noteheads. NOT clamped
    // at zero: a triplet sitting entirely below the middle line has a negative
    // `up`, and the bracket above it starts from THERE — clamping would report
    // a headroom demand for a bracket that never reaches the top of the block.
    var up = baselineY - noteYs.first;
    var down = noteYs.first - baselineY;
    for (final y in noteYs) {
      final aboveBaseline = baselineY - y;
      if (aboveBaseline > up) up = aboveBaseline;
      if (-aboveBaseline > down) down = -aboveBaseline;
    }
    // Notehead half-height on the side the bracket does NOT take.
    const noteheadHalfSpaces = 2.2;
    final above = stemUp
        ? up + off + numberReach
        : up + staffSpace * noteheadHalfSpaces;
    final below = stemUp
        ? down + staffSpace * noteheadHalfSpaces
        : down + off + numberReach;

    return (
      above: above > nestedAbove ? above : nestedAbove,
      below: below > nestedBelow ? below : nestedBelow,
    );
  }

  /// How far below its own anchor an element draws, in pixels.
  double _belowStaffExtent(PositionedElement positioned) {
    final element = positioned.element;
    if (element is Tuplet) {
      return _tupletVerticalReach(element, positioned.position.dy).below;
    }
    if (element is Note) {
      // Notehead half-height, plus the lyric block when the note is sung.
      var extent = staffSpace * 2.2;
      final syllables = element.syllables;
      if (syllables != null && syllables.isNotEmpty) {
        extent = staffSpace * (4.0 + 1.1 * syllables.length);
      }
      return extent + _curveAllowance(element);
    }
    if (element is Chord) {
      final sung = element.notes
          .map((n) => n.syllables?.length ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      return sung > 0 ? staffSpace * (4.0 + 1.1 * sung) : staffSpace * 2.2;
    }
    if (element is Dynamic) return staffSpace * 4.5;
    if (element is Rest) return staffSpace * 2.2;
    return staffSpace * 2.0;
  }

  /// Extra vertical room a note needs because a slur or tie arches off it.
  ///
  /// The layout could not see curves AT ALL. A slur is drawn BETWEEN two notes
  /// by `SlurRenderer`; it is not a positioned element, so it never appeared in
  /// the list `contentTopOverflow` walks, and the canvas was sized as if the
  /// arc were not there. Measured on a seven-note rising phrase under one slur
  /// at `staffSpace = 12`: the raster came back 219 px tall with **12 px of ink
  /// hard against row 0** — the apex of the arc, cut off by the top edge.
  ///
  /// The allowance is the bound `SlurCalculator` itself draws by rather than a
  /// number invented here: the arc height is
  /// `0.55 * sqrt(lengthInStaffSpaces)` **clamped to 2.8 staff spaces**, and
  /// the curve starts `EngravingRules.slurNoteHeadYOffset` (0.5) clear of the
  /// notehead. So 3.3 staff spaces is the most a curve can reach past the note
  /// it hangs from, and reserving that is exact at the clamp and generous
  /// below it.
  ///
  /// Added on BOTH sides deliberately. Which side a curve takes is decided by
  /// the renderer from stem direction and chord geometry, and duplicating that
  /// decision here would be a second source of truth for it — the same defect
  /// class as the clef that reported treble while drawing bass. Over-reserving
  /// by 3.3 staff spaces on the unused side costs vertical whitespace; getting
  /// it wrong costs the arc.
  static const double curveReachSpaces = 2.8 + 0.5;

  double _curveAllowance(MusicalElement element) {
    if (element is Note) {
      final carries = element.tie != null ||
          element.slur != null ||
          element.slurs.isNotEmpty;
      return carries ? staffSpace * curveReachSpaces : 0.0;
    }
    if (element is Chord) {
      for (final note in element.notes) {
        if (note.tie != null || note.slur != null || note.slurs.isNotEmpty) {
          return staffSpace * curveReachSpaces;
        }
      }
    }
    return 0.0;
  }


  /// Stacking level for each mark that floats ABOVE the staff, per system.
  ///
  /// Level 0 is the row nearest the staff; each level above it is one text
  /// line further out. Empty for anything that does not float.
  ///
  /// Marks like tempo text and rehearsal letters are deliberately given NO
  /// horizontal advance — they are co-positioned with the rhythmic element
  /// that follows, so that adding a direction never changes where the notes
  /// sit. That invariant is right, and it has a consequence nobody handled:
  /// two directions close together have nothing keeping them apart, and they
  /// were simply drawn on top of each other. Reported from the tempo page,
  /// where "Quarter = Eighth (metronome 120)" ran straight through
  /// "Range 120-132".
  ///
  /// Since they cannot move sideways, they move OUT. This packs them into
  /// rows: each mark takes the lowest row whose previous occupant has already
  /// finished, which is the standard interval-packing answer and gives the
  /// minimum number of rows.
  final Map<MusicalElement, int> aboveStaffLevels = {};

  /// Height of one stacking row, in pixels.
  double get aboveStaffLevelHeight => staffSpace * 1.9;

  void _assignAboveStaffLevels(List<PositionedElement> positioned) {
    aboveStaffLevels.clear();

    final bySystem = <int, List<PositionedElement>>{};
    for (final pe in positioned) {
      if (!_floatsAboveStaff(pe.element)) continue;
      bySystem.putIfAbsent(pe.system, () => []).add(pe);
    }

    for (final entry in bySystem.entries) {
      final marks = entry.value
        ..sort((a, b) => a.position.dx.compareTo(b.position.dx));
      // Right edge currently occupied by each row.
      final rowEnds = <double>[];
      for (final pe in marks) {
        final left = pe.position.dx;
        final right = left + elementWidth(pe.element);
        var row = 0;
        while (row < rowEnds.length && rowEnds[row] > left) {
          row++;
        }
        if (row == rowEnds.length) {
          rowEnds.add(right);
        } else {
          rowEnds[row] = right;
        }
        aboveStaffLevels[pe.element] = row;
      }
    }
  }

  /// Marks drawn above the staff that have to share the space up there.
  ///
  /// Deliberately NOT every floating element: dynamics and hairpins live below
  /// the staff, and an octave bracket spans rather than sits.
  bool _floatsAboveStaff(MusicalElement element) {
    if (element is TempoMark) return true;
    if (element is MusicText) {
      switch (element.type) {
        case TextType.lyrics:
        case TextType.dynamics:
          return false;
        default:
          return true;
      }
    }
    return false;
  }

  /// How far above its own anchor an element draws, in pixels.
  ///
  /// Floating elements are positioned by the RENDERER relative to the staff, not
  /// by the layout, so their reach is expressed here as an allowance measured
  /// from the staff baseline (the top staff line is 2 staff spaces above it).
  double _aboveStaffExtent(PositionedElement positioned) {
    final element = positioned.element;
    if (element is Tuplet) {
      return _tupletVerticalReach(element, positioned.position.dy).above;
    }
    if (element is MusicText) {
      final stack =
          (aboveStaffLevels[element] ?? 0) * aboveStaffLevelHeight;
      switch (element.type) {
        case TextType.rehearsal:
          // centre 3.2 SS above the top line, plus half the box.
          return staffSpace * 6.4 + stack;
        case TextType.tempo:
          return staffSpace * 5.0 + stack;
        default:
          return staffSpace * 4.6 + stack;
      }
    }
    if (element is TempoMark) {
      // 5.0 was not enough and never had been: a tempo mark's centre sits 3.95
      // staff spaces above the top line, and the metronome NOTE GLYPH drawn
      // beside the text is taller than the text is. Measured before this, on a
      // single tempo mark with no stacking at all: 1 px of ink hard against row
      // 0 of the canvas. 6.2 clears it with room to spare and still costs
      // nothing on a score that has no tempo mark.
      final base = element.bpm != null && element.showMetronome ? 6.2 : 5.0;
      return staffSpace * base +
          (aboveStaffLevels[element] ?? 0) * aboveStaffLevelHeight;
    }
    if (element is OctaveMark) return staffSpace * 4.6;
    if (element is Note || element is Chord) {
      // Notehead half-height plus a stem's worth of clearance; ledger lines and
      // articulations live inside this.
      return staffSpace * 2.2 + _curveAllowance(element);
    }
    if (element is Rest) return staffSpace * 2.2;
    return staffSpace * 2.0;
  }

  double calculateTotalHeight(List<PositionedElement> elements) {
    if (elements.isEmpty) {
      return staffSpace * 8;
    }

    int maxSystem = 0;
    for (final element in elements) {
      if (element.system > maxSystem) {
        maxSystem = element.system;
      }
    }

    final double systemHeight = staffSpace * systemHeightSpaces;
    final double topMargin = staffSpace * 4.0;
    final double bottomMargin = staffSpace * 2.0;

    return topMargin +
        contentTopOverflow(elements) +
        ((maxSystem + 1) * systemHeight) +
        bottomMargin +
        contentBottomOverflow(elements);
  }
}
