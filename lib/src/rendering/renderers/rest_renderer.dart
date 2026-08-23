// lib/src/rendering/renderers/rest_renderer.dart
// Refactored implementation: Herda de BaseGlyphRenderer
//
// MELHORIAS IMPLEMENTADAS (Fase 2):
// ✅ Herda de BaseGlyphRenderer for Rendering consistente
// ✅ Uses drawGlyphWithBBox for 100% conformidade SMuFL
// ✅ Cache automático de TextPainters for melhor performance
// ✅ Elimina method _drawGlyph duplicado (30 lines)

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../layout/collision_detector.dart'; // CORREÇÃO: Import collision detector
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';
import 'base_glyph_renderer.dart';
import 'ornament_renderer.dart';

class RestRenderer extends BaseGlyphRenderer {
  final MusicScoreTheme theme;
  final OrnamentRenderer ornamentRenderer;

  // ignore: use_super_parameters
  RestRenderer({
    required StaffCoordinateSystem coordinates,
    required SmuflMetadata metadata,
    required this.theme,
    required double glyphSize,
    required this.ornamentRenderer,
    CollisionDetector? collisionDetector, // CORREÇÃO: Adicionar collision detector
  }) : super(
         coordinates: coordinates,
         metadata: metadata,
         glyphSize: glyphSize,
         collisionDetector: collisionDetector, // CORREÇÃO: Passar para super
       );

  /// SMuFL glyph this renderer draws for a rest of [durationType].
  ///
  /// Exposed as a pure function because `LayoutEngine` has to reserve the
  /// advance width of the glyph that will ACTUALLY be drawn. It used to give
  /// every rest a flat 1.5 staff spaces whatever its duration, while Bravura's
  /// measured advances are `restWhole` 1.132, `restHalf` 1.132,
  /// `restQuarter` 1.08, `rest8th` 1.0, `rest16th` 1.28, `rest32nd` 1.452,
  /// `rest64th` 1.696 — so an eighth rest was over-reserved by half a staff
  /// space (6.00 px at staffSpace 12) while a 64th, which is wider than the
  /// flat constant, was under-reserved.
  ///
  /// Durations below a 64th fall back to `restQuarter`, which is what this
  /// renderer has always drawn for them; the reservation matches the drawing
  /// by construction, and adding the missing `rest128th`/`rest256th`/… glyphs
  /// is a rendering change, not a spacing one.
  static String glyphNameFor(DurationType durationType) {
    switch (durationType) {
      case DurationType.whole:
        return 'restWhole';
      case DurationType.half:
        return 'restHalf';
      case DurationType.quarter:
        return 'restQuarter';
      case DurationType.eighth:
        return 'rest8th';
      case DurationType.sixteenth:
        return 'rest16th';
      case DurationType.thirtySecond:
        return 'rest32nd';
      case DurationType.sixtyFourth:
        return 'rest64th';
      default:
        return 'restQuarter';
    }
  }

  /// Staff position the rest glyph hangs from / sits on, per Behind Bars
  /// (Gould p.109-110) and the SMuFL baseline convention documented in
  /// [render]. Even voice numbers are placed below the middle line.
  static int staffPositionFor(DurationType durationType, {int? voiceNumber}) {
    final isVoiceDown = voiceNumber != null && voiceNumber.isEven;
    switch (durationType) {
      case DurationType.whole:
        return isVoiceDown ? -2 : 2;
      case DurationType.half:
        return isVoiceDown ? -4 : 0;
      default:
        return isVoiceDown ? -4 : 0;
    }
  }

  void render(Canvas canvas, Rest rest, Offset position, {int? voiceNumber}) {
    String glyphName;
    int staffPosition;

    // Posicionamento according to Behind Bars (Gould, p. 109-110) and SMuFL:
    //
    // A correção de baseline in drawGlyphWithBBox posiciona o SMuFL Y=0 exatamente
    // in restY (= toPixelY(staffPosition)). By isso:
    //
    //   restWhole: top of the glifo in Y=0, corpo descends → restY = line from which hangs
    //     Voice 1: hangs of the line \1  → staffPos = +2  (toPixelY(2) = baseline − ss)
    //     Voice 2: hangs of the line \1  → staffPos = −2  (toPixelY(−2) = baseline + ss)
    //
    //   restHalf: base of the glifo in Y=0, corpo rises → restY = line on/about a qual sits
    //     Voice 1: sits na line \1  → staffPos =  0  (toPixelY(0)  = baseline)
    //     Voice 2: sits na line \1  → staffPos = −4  (toPixelY(−4) = baseline + 2ss)
    //
    //   PaUsess curtas (quarter, 8th…): glifo centred in Y=0
    //     Voice 1: centre of the staff   → staffPos =  0
    //     Voice 2: lower half → staffPos = −4 (2 spaces below centre)
    //
    // Convenção: voices pares = for bottom, voices ímpares = for top (default)
    glyphName = glyphNameFor(rest.duration.type);
    staffPosition =
        staffPositionFor(rest.duration.type, voiceNumber: voiceNumber);

    final restY =
        coordinates.staffBaseline.dy -
        (staffPosition * coordinates.staffSpace * 0.5);

    final restPosition = Offset(position.dx, restY);

    // MELHORIA: Use drawGlyphWithBBox inherited de BaseGlyphRenderer
    // Isso automaticamente applies o ajuste de bounding box SMuFL
    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: restPosition,
      color: theme.restColor,
      options: GlyphDrawOptions.restDefault,
    );

    // Augmentation dot(s): to the right of the rest, in the space above its
    // body (one half-space up), spaced apart for multiple dots.
    if (rest.duration.dots > 0) {
      final advance =
          (metadata.getGlyphAdvanceWidth(glyphName) ?? 1.0) *
              coordinates.staffSpace;
      var dotX = position.dx + advance + coordinates.staffSpace * 0.25;
      final dotY = restY - coordinates.staffSpace * 0.5;
      for (var d = 0; d < rest.duration.dots; d++) {
        drawGlyphWithBBox(
          canvas,
          glyphName: 'augmentationDot',
          position: Offset(dotX, dotY),
          color: theme.restColor,
          options: const GlyphDrawOptions(),
        );
        dotX += coordinates.staffSpace * 0.45;
      }
    }

    // renderizar ornaments if presentes
    if (rest.ornaments.isNotEmpty) {
      final placeholderNote = Note(
        pitch: Pitch(step: 'B', octave: 4), // Posição central da pauta
        duration: rest.duration,
        ornaments: rest.ornaments,
      );
      ornamentRenderer.renderForNote(canvas, placeholderNote, restPosition, 0);
    }
  }
}
