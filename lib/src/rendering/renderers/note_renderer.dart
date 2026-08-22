// lib/src/rendering/renderers/note_renderer.dart
// Refactored implementation: uses StaffPositionCalculator and BaseGlyphRenderer.
//
// What this buys us:
//  * one unified StaffPositionCalculator for every position computation;
//  * BaseGlyphRenderer.drawGlyphWithBBox for consistent SMuFL rendering — it
//    also caches TextPainters, so no glyph allocates a painter per frame;
//  * no duplicated staff-position code and no ad-hoc, inconsistent use of
//    centerVertically / centerHorizontally.

import 'package:flutter/material.dart';
import '../../../core/core.dart';
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../accidental_resolver.dart';
import '../smufl_positioning_engine.dart';
import '../staff_coordinate_system.dart';
import '../staff_position_calculator.dart';
import 'articulation_renderer.dart';
import 'base_glyph_renderer.dart';
import 'ornament_renderer.dart';
import 'primitives/accidental_renderer.dart';
import 'primitives/dot_renderer.dart';
import 'primitives/flag_renderer.dart';
import 'primitives/ledger_line_renderer.dart';
import 'primitives/stem_renderer.dart';
import 'symbol_and_text_renderer.dart';

class NoteRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final ArticulationRenderer articulationRenderer;
  final OrnamentRenderer ornamentRenderer;
  final SMuFLPositioningEngine positioningEngine;

  // Specialized sub-renderers (single-responsibility split).
  late final DotRenderer dotRenderer;
  late final LedgerLineRenderer ledgerLineRenderer;
  late final StemRenderer stemRenderer;
  late final FlagRenderer flagRenderer;
  late final AccidentalRenderer accidentalRenderer;
  late final SymbolAndTextRenderer symbolAndTextRenderer;

  NoteRenderer({
    required StaffCoordinateSystem coordinates,
    required SmuflMetadata metadata,
    required this.theme,
    required double glyphSize,
    required double staffLineThickness,
    required double stemThickness,
    required this.articulationRenderer,
    required this.ornamentRenderer,
    required this.positioningEngine,
  }) : super(
         coordinates: coordinates,
         metadata: metadata,
         glyphSize: glyphSize,
       ) {
    // Initialise the specialized sub-renderers.
    dotRenderer = DotRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
    );

    ledgerLineRenderer = LedgerLineRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      staffLineThickness: staffLineThickness,
    );

    stemRenderer = StemRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      stemThickness: stemThickness,
      positioningEngine: positioningEngine,
    );

    flagRenderer = FlagRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      positioningEngine: positioningEngine,
    );

    accidentalRenderer = AccidentalRenderer(
      metadata: metadata,
      theme: theme,
      coordinates: coordinates,
      glyphSize: glyphSize,
      positioningEngine: positioningEngine,
    );

    symbolAndTextRenderer = SymbolAndTextRenderer(
      coordinates: coordinates,
      metadata: metadata,
      theme: theme,
      glyphSize: glyphSize,
    );
  }

  void render(
    Canvas canvas,
    Note note,
    Offset basePosition,
    Clef currentClef, {
    bool renderOnlyNotehead = false,
    int? voiceNumber,
    AccidentalDisplay accidentalDisplay = AccidentalDisplay.show,
  }) {
    final staffPosition = StaffPositionCalculator.calculate(
      note.pitch,
      currentClef,
    );

    // The voice's horizontal offset is already baked into basePosition by the
    // layout engine; do NOT apply it a second time here.
    final noteY = StaffPositionCalculator.toPixelY(
      staffPosition,
      coordinates.staffSpace,
      coordinates.staffBaseline.dy,
    );
    final stemUp = _getStemDirectionByVoice(note, staffPosition, voiceNumber);

    final noteheadGlyph = note.duration.type.glyphName;

    ledgerLineRenderer.render(
      canvas,
      basePosition.dx,
      staffPosition,
      noteheadGlyph,
    );

    final notePos = Offset(basePosition.dx, noteY);

    final noteheadInfo = metadata.getGlyphInfo(noteheadGlyph);
    final bbox = noteheadInfo?.boundingBox;

    final centerX = bbox != null
        ? ((bbox.bBoxSwX + bbox.bBoxNeX) / 2) * coordinates.staffSpace
        : (1.18 / 2) * coordinates.staffSpace;

    final centerY = bbox != null
        ? (bbox.centerY * coordinates.staffSpace)
        : 0.0;

    final noteCenter = Offset(basePosition.dx + centerX, noteY + centerY);

    // F-02: the accidental ALWAYS goes through the resolved [accidentalDisplay]
    // (show / hide / natural) decided by the layout engine — never straight from
    // Pitch.accidentalGlyph. F-16: the cautionary/editorial enclosure travels
    // with it.
    accidentalRenderer.render(
      canvas,
      note,
      notePos,
      staffPosition.toDouble(),
      display: accidentalDisplay,
      parenthesis: note.accidentalParenthesis,
    );

    drawGlyphWithBBox(
      canvas,
      glyphName: noteheadGlyph,
      position: notePos,
      color: theme.noteheadColor,
      options: GlyphDrawOptions.noteheadDefault,
    );

    if (!renderOnlyNotehead &&
        note.duration.type != DurationType.whole &&
        note.beam == null) {
      // Stem direction: forced by voice in a polyphonic context, otherwise by
      // staff position.
      final beamCount = _getBeamCount(note.duration.type);

      final stemEnd = stemRenderer.render(
        canvas,
        notePos,
        noteheadGlyph,
        staffPosition,
        stemUp,
        beamCount,
      );

      // Draw the flag when the duration needs one.
      if (note.duration.type.value < 0.25) {
        flagRenderer.render(canvas, stemEnd, note.duration.type, stemUp);
      }

      // Tremolo strokes
      if (note.tremoloStrokes > 0 && note.tremoloStrokes <= 5) {
        final tremoloGlyph = 'tremolo${note.tremoloStrokes}';
        final tremoloY = stemUp
            ? stemEnd.dy - coordinates.staffSpace * 0.8
            : stemEnd.dy + coordinates.staffSpace * 0.8;
        drawGlyphWithBBox(
          canvas,
          glyphName: tremoloGlyph,
          position: Offset(notePos.dx, tremoloY),
          color: theme.noteheadColor,
          options: const GlyphDrawOptions(
            centerHorizontally: true,
            centerVertically: true,
          ),
        );
      }
    }

    // Render articulations against the centre of the notehead.
    articulationRenderer.render(
      canvas,
      note.articulations,
      noteCenter,
      stemUp: stemUp,
    );

    // Render ornaments against the centre of the notehead.
    ornamentRenderer.renderForNote(
      canvas,
      note,
      noteCenter,
      staffPosition,
      voiceNumber: voiceNumber,
    );

    // Render the dynamic marking, if present.
    if (note.dynamicElement != null) {
      _renderDynamic(canvas, note.dynamicElement!, basePosition, staffPosition);
    }

    // Augmentation dots are delegated to DotRenderer.
    if (note.duration.dots > 0) {
      dotRenderer.render(canvas, note, noteCenter, staffPosition);
    }

    // Render lyric syllables below the staff.
    if (note.syllables != null && note.syllables!.isNotEmpty) {
      _renderSyllables(canvas, note.syllables!, noteCenter.dx);
    }
  }

  // Helper: number of beams/flags required by a duration.
  int _getBeamCount(DurationType duration) {
    return switch (duration) {
      DurationType.eighth => 1,
      DurationType.sixteenth => 2,
      DurationType.thirtySecond => 3,
      DurationType.sixtyFourth => 4,
      _ => 0,
    };
  }

  /// Renders the dynamic marking attached to the note.
  void _renderDynamic(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition,
    int staffPosition,
  ) {
    symbolAndTextRenderer.renderDynamic(canvas, dynamic, basePosition);
  }

  /// Renders lyric syllables below the staff, centered at [centerX].
  ///
  /// Placement: 1.5 staff spaces below the bottom staff line; each verse gets
  /// its own line (line height = 1.3 * font size).
  ///
  /// Typographic conventions:
  /// - [SyllableType.initial] / [SyllableType.middle]: the connecting hyphen is
  ///   drawn centered BETWEEN syllables by StaffRenderer's post-layout pass,
  ///   not glued to the text here;
  /// - [SyllableType.hyphen]: draws just "-";
  /// - melismas get a horizontal extension line, also drawn post-layout so it
  ///   can reach the actual end of the melisma.
  ///
  /// Public so that
  /// ChordRenderer can render `Note.syllables` for chords (issue #12),
  /// reusing the same typographic rules as single notes.
  void renderSyllables(
    Canvas canvas,
    List<Syllable> syllables,
    double centerX,
  ) {
    _renderSyllables(canvas, syllables, centerX);
  }

  void _renderSyllables(Canvas canvas, List<Syllable> syllables, double noteX) {
    // Bottom staff line: baseline.dy + 2 * staffSpace.
    final staffBottomY =
        coordinates.staffBaseline.dy + 2 * coordinates.staffSpace;
    final fontSize = coordinates.staffSpace * 0.85;
    final lineHeight = fontSize * 1.3;
    // Clearance between the bottom staff line and the first lyric line.
    final firstLineY = staffBottomY + coordinates.staffSpace * 1.5;

    for (int verseIndex = 0; verseIndex < syllables.length; verseIndex++) {
      final syllable = syllables[verseIndex];
      final lyricY = firstLineY + verseIndex * lineHeight;
      _renderSyllable(canvas, syllable, noteX, lyricY, fontSize);
    }
  }

  void _renderSyllable(
    Canvas canvas,
    Syllable syllable,
    double noteX,
    double y,
    double fontSize,
  ) {
    final color = theme.noteheadColor.withValues(alpha: 0.85);

    String displayText;
    switch (syllable.type) {
      case SyllableType.initial:
      case SyllableType.middle:
        // The connecting hyphen is drawn CENTERED between this syllable and the
        // next by StaffRenderer's post-layout lyric-hyphen pass (#14), not glued
        // to the syllable text.
        displayText = syllable.text;
      case SyllableType.hyphen:
        displayText = '-';
      case SyllableType.single:
      case SyllableType.terminal:
        displayText = syllable.text;
    }

    // Respect theme.lyricTextStyle (font family/weight/etc.) when provided,
    // falling back to size-aware defaults. Previously this field was ignored.
    final base = theme.lyricTextStyle ?? const TextStyle();
    final textStyle = base.copyWith(
      fontSize: base.fontSize ?? fontSize,
      color: base.color ?? color,
      fontStyle: syllable.italic
          ? FontStyle.italic
          : (base.fontStyle ?? FontStyle.normal),
      height: 1.0,
    );

    final painter = TextPainter(
      text: TextSpan(text: displayText, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    // Centre the text on the note's X position.
    final textX = noteX - painter.width * 0.5;
    painter.paint(canvas, Offset(textX, y - painter.height * 0.5));

    // Melisma extension lines are drawn by StaffRenderer's post-layout pass
    // (_renderMelismaLines, #13), which has the X of the following notes and can
    // extend the line to the actual end of the melisma instead of a fixed stub.
  }

  /// Determines the stem direction from the voice (polyphony) or, failing that,
  /// from the staff position.
  ///
  /// In a polyphonic context (voiceNumber != null):
  ///   - odd voices (1, 3, ...): stem always up;
  ///   - even voices (2, 4, ...): stem always down.
  ///
  /// Without a voice, the traditional rule applies: stem up when the note sits
  /// below the middle line.
  bool _getStemDirectionByVoice(
    Note note,
    int staffPosition,
    int? voiceNumber,
  ) {
    // Voice passed explicitly by the layout engine.
    if (voiceNumber != null) {
      return voiceNumber.isOdd; // odd = stem up, even = stem down
    }

    // Voice declared directly on the note.
    if (note.voice != null) {
      return note.voice!.isOdd;
    }

    // Positional rule (single voice, Gould): notes above the middle line get a
    // downward stem, notes below get an upward stem, and a note ON the middle
    // line takes a downward stem by convention.
    return staffPosition < 0;
  }
}
