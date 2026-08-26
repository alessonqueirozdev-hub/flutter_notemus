// lib/core/tuplet_bracket.dart

import 'musical_element.dart'; // BeamType
import 'note.dart';  // ✅ Import needed for Note type

/// Lado of the bracket de tuplet
enum BracketSide {
  /// Lado of the stem (default)
  stem,

  /// Lado of the cabeça of the note (used in music vocal)
  notehead,
}

/// configuração of the bracket de tuplet
class TupletBracket {
  /// Thickness of the line of the bracket (0.125 staff spaces by default)
  final double thickness;

  /// Length dos ganchos nas extremidades
  final double hookLength;

  /// Mostrar bracket
  final bool show;

  /// Lado where o bracket aparece
  final BracketSide side;

  /// Slope of the bracket (0 = horizontal)
  /// Máximo recomendado: 1.75 staff spaces de diferença vertical
  final double slope;

  /// Distance mínima of the bracket às notes (0.75 staff spaces)
  final double minDistanceFromNotes;

  /// Force the bracket ON, overriding the automatic Behind Bars rule.
  ///
  /// [show] is the force-OFF half of the pair and always was; this is the
  /// force-ON half, and it did not exist before 2.7.2 because it had nothing to
  /// override — [shouldShow] had no production caller, so every tuplet was
  /// bracketed unconditionally by `TupletRenderer` and "force on" was simply
  /// what happened. Now that the renderer asks the rule, an author who wants a
  /// bracket over a beamed group anyway (a common editorial choice in
  /// pedagogical and orchestral parts, where the group is easier to read
  /// bracketed) needs a way to say so on the STEM side. [BracketSide.notehead]
  /// also forces the bracket, but it means "vocal music, bracket by the
  /// noteheads" and moves the bracket; this does not move anything.
  ///
  /// [show] `= false` still wins over this: an explicit "never" beats an
  /// explicit "always", because suppression is the narrower request.
  final bool alwaysShow;

  /// Máxima slope permitida (1.75 staff spaces)
  static const double maxSlope = 1.75;

  const TupletBracket({
    this.thickness = 0.125,
    this.hookLength = 0.9,
    this.show = true,
    this.side = BracketSide.stem,
    this.slope = 0.0,
    this.minDistanceFromNotes = 0.75,
    this.alwaysShow = false,
  });

  /// Determina if o bracket must be mostrado with base nas notes
  ///
  /// Regras (Behind Bars standard):
  /// - Not mostrar if all as notes are beamed juntas
  /// - MOSTRAR if está of the lado of the cabeça (music vocal)
  /// - MOSTRAR if notes not têm beams or há rests
  /// - MOSTRAR if show=false (força escwherer)
  ///
  /// Pass the tuplet's FULL element list, not `Tuplet.notes`: the "a rest keeps
  /// its bracket" clause below is implemented by comparing how many of the
  /// given elements are [Note]s, so handing it the pre-filtered note list makes
  /// every rest invisible and a triplet of two beamed eighths around a rest
  /// silently loses its bracket. `Tuplet.shouldShowBracket` passes `elements`
  /// for exactly this reason (it passed `notes` until 2.7.2).
  ///
  /// [beamOf] is the LAYOUT'S beam decision for a note — pass
  /// `LayoutEngine.beamOf`, or anything else honouring the same contract.
  ///
  /// `LayoutEngine.beamOf` is enough on its own — pass it directly:
  ///
  /// ```dart
  /// bracket.shouldShow(tuplet.elements, beamOf: engine.beamOf);
  /// ```
  ///
  /// It did NOT used to be. Through 2.7.2 `beamOf` consulted
  /// `LayoutEngine.beams` (ordinary groups) and the author's hint but NOT
  /// `LayoutEngine.tupletBeams`, so for a note inside a tuplet — which is every
  /// note this method is ever asked about — it answered `null` even though the
  /// engine had decided. Measured on a 3:2 triplet of eighths BEFORE the fix:
  /// `engine.beamOf(first)` was `null` while `engine.tupletBeams[first]` was
  /// `BeamType.start`, so `shouldShow(notes, beamOf: engine.beamOf)` returned
  /// `true` — a bracket over a fully beamed triplet, against Behind Bars p.201,
  /// which is precisely the answer this parameter exists to prevent. `beamOf`
  /// now folds in the tuplet map and the same call returns `false`. The two
  /// maps are disjoint by construction (`beams` walks measure/voice elements,
  /// `tupletBeams` walks only `Tuplet` children), so the added lookup changes
  /// no answer for a note outside a tuplet.
  ///
  /// Why the beam decision had to become a parameter (ADR-005)
  /// ---------------------------------------------------------
  /// This method used to answer the "is everything beamed?" question itself,
  /// with `actualNotes.every((note) => note.beam != null)`. That was correct
  /// while the layout STAMPED its answer onto the model. ADR-005 stopped the
  /// stamping — the decision is now a value on `LayoutEngine.beams` /
  /// `LayoutEngine.tupletBeams` — so from 2.7.2 the expression read the
  /// AUTHOR'S hint and nothing else.
  ///
  /// Measured on an ordinary 3:2 triplet of three eighths, built with no
  /// hand-authored beams and laid out once: `note.beam` is `null` on all three
  /// notes while `LayoutEngine.tupletBeams` holds `start / inner / end`. So
  /// `allNotesBeamed` evaluated to `false` and `Tuplet.shouldShowBracket`
  /// returned `true` — a bracket printed across a fully beamed triplet, which
  /// is exactly the case Behind Bars (p.201) says must show the numeral ALONE.
  /// The defect was latent only because `TupletRenderer` still gates on the
  /// deprecated `Tuplet.showBracket`; the moment a caller routed the renderer
  /// through `shouldShowBracket` it would have printed.
  ///
  /// `core/` cannot see the layout — the dependency runs the other way, and
  /// making it run both ways to answer one boolean would be a far worse trade.
  /// That left two honest options: take the decision as a parameter, or move
  /// `shouldShow` out of `core` and into the layout. The parameter is chosen
  /// because `TupletBracket` is public, `const`-constructible configuration
  /// that users hold and pass in themselves; relocating the method would have
  /// deleted a documented API in order to fix a data-flow problem, and the
  /// caller that has the answer (`LayoutEngine`) is exactly the caller that
  /// wants to ask the question.
  ///
  /// With no [beamOf] the only thing this method can honestly consult is the
  /// author's own hint — which is precisely the fallback half of
  /// `LayoutEngine.beamOf`, so the two agree by construction. A hand-authored
  /// (`BeamingMode.manual`) score therefore behaves exactly as before, and a
  /// score whose beams were decided automatically gets the CONSERVATIVE answer
  /// (draw the bracket) instead of a confidently wrong one.
  bool shouldShow(
    List<dynamic> notes, {
    BeamType? Function(Note note)? beamOf,
  }) {
    // If está of the lado of the cabeça, always mostrar
    if (side == BracketSide.notehead) return true;

    // If show=false, forçar escwherer
    if (!show) return false;

    // Explicit editorial "always bracket", checked after the explicit "never".
    if (alwaysShow) return true;

    // ✅ CORREÇÃO P9: Check if all as notes têm beam
    // If sim, escwherer bracket (Behind Bars standard)
    // If not (rests, unbeamed notes), mostrar bracket

    // Filtrar only Notes (ignorar rests)
    final actualNotes = notes.whereType<Note>().toList();

    // If not há notes, or há rests misturados, mostrar bracket
    if (actualNotes.isEmpty || actualNotes.length < notes.length) {
      return true;
    }

    // Check if All as notes têm beam defined
    final resolve = beamOf ?? _authorBeamHint;
    final allNotesBeamed = actualNotes.every((note) => resolve(note) != null);

    // If all têm beam, escwherer bracket (only mostrar number)
    // If some not tem beam, mostrar bracket
    return !allNotesBeamed;
  }

  /// The author's own `Note.beam` hint.
  ///
  /// The single sanctioned read of the model's beam field in `core/`, used only
  /// when [shouldShow] was given no layout decision. It mirrors the fallback
  /// half of `LayoutEngine.beamOf` (`beams[note] ?? note.beam`) so the two
  /// cannot disagree about what "the author asked for" means.
  static BeamType? _authorBeamHint(Note note) => note.beam;
}
