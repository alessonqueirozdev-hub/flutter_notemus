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
    final isVoiceDown = voiceNumber != null && voiceNumber.isEven;

    switch (rest.duration.type) {
      case DurationType.whole:
        glyphName = 'restWhole';
        staffPosition = isVoiceDown ? -2 : 2;
        break;
      case DurationType.half:
        glyphName = 'restHalf';
        staffPosition = isVoiceDown ? -4 : 0;
        break;
      case DurationType.quarter:
        glyphName = 'restQuarter';
        staffPosition = isVoiceDown ? -4 : 0;
        break;
      case DurationType.eighth:
        glyphName = 'rest8th';
        staffPosition = isVoiceDown ? -4 : 0;
        break;
      case DurationType.sixteenth:
        glyphName = 'rest16th';
        staffPosition = isVoiceDown ? -4 : 0;
        break;
      case DurationType.thirtySecond:
        glyphName = 'rest32nd';
        staffPosition = isVoiceDown ? -4 : 0;
        break;
      case DurationType.sixtyFourth:
        glyphName = 'rest64th';
        staffPosition = isVoiceDown ? -4 : 0;
        break;
      default:
        glyphName = 'restQuarter';
        staffPosition = isVoiceDown ? -4 : 0;
    }

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

    // Rendersr ornaments if presentes
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
