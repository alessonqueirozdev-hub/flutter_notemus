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

    // Posições padrão (voz única ou voz 1):
    //   whole  → staffPos 3  (pende da linha 4)
    //   half   → staffPos 1  (assenta na linha 3)
    //   outras → staffPos 0  (centro)
    //
    // Voz 2 (par): deslocar para baixo (-4 semi-espaços = 2 espaços):
    //   whole  → staffPos -1 (assenta na linha 2)
    //   half   → staffPos -3 (pende da linha 1)
    //   outras → staffPos -4 (abaixo do centro)
    //
    // Convenção: vozes pares = para baixo, vozes ímpares = para cima (padrão)
    final isVoiceDown = voiceNumber != null && voiceNumber.isEven;

    switch (rest.duration.type) {
      case DurationType.whole:
        glyphName = 'restWhole';
        staffPosition = isVoiceDown ? -1 : 3;
        break;
      case DurationType.half:
        glyphName = 'restHalf';
        staffPosition = isVoiceDown ? -3 : 1;
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
