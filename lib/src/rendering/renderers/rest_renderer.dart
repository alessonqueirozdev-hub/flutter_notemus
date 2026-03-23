// lib/src/rendering/renderers/rest_renderer.dart
// VERSÃO REFATORADA: Herda de BaseGlyphRenderer
//
// MELHORIAS IMPLEMENTADAS (Fase 2):
// ✅ Herda de BaseGlyphRenderer para renderização consistente
// ✅ Usa drawGlyphWithBBox para 100% conformidade SMuFL
// ✅ Cache automático de TextPainters para melhor performance
// ✅ Elimina método _drawGlyph duplicado (30 linhas)

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

    // Posicionamento conforme Behind Bars (Gould, p. 109-110) e SMuFL:
    //
    // A correção de baseline em drawGlyphWithBBox posiciona o SMuFL Y=0 exatamente
    // em restY (= toPixelY(staffPosition)). Por isso:
    //
    //   restWhole: topo do glifo em Y=0, corpo desce → restY = linha da qual pende
    //     Voz 1: pende da linha 4  → staffPos = +2  (toPixelY(2) = baseline − ss)
    //     Voz 2: pende da linha 2  → staffPos = −2  (toPixelY(−2) = baseline + ss)
    //
    //   restHalf: base do glifo em Y=0, corpo sobe → restY = linha sobre a qual senta
    //     Voz 1: senta na linha 3  → staffPos =  0  (toPixelY(0)  = baseline)
    //     Voz 2: senta na linha 1  → staffPos = −4  (toPixelY(−4) = baseline + 2ss)
    //
    //   Pausas curtas (quarter, 8th…): glifo centrado em Y=0
    //     Voz 1: centro da pauta   → staffPos =  0
    //     Voz 2: metade inferior   → staffPos = −4 (2 espaços abaixo do centro)
    //
    // Convenção: vozes pares = para baixo, vozes ímpares = para cima (padrão)
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

    // MELHORIA: Usar drawGlyphWithBBox herdado de BaseGlyphRenderer
    // Isso automaticamente aplica o ajuste de bounding box SMuFL
    drawGlyphWithBBox(
      canvas,
      glyphName: glyphName,
      position: restPosition,
      color: theme.restColor,
      options: GlyphDrawOptions.restDefault,
    );

    // Renderizar ornamentos se presentes
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
