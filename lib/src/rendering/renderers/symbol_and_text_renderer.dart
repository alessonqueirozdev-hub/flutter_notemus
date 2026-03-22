// lib/src/rendering/renderers/symbol_and_text_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../layout/collision_detector.dart'; // CORREÇÃO: Import collision detector
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';

class SymbolAndTextRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final CollisionDetector? collisionDetector; // CORREÇÃO: Adicionar collision detector

  SymbolAndTextRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    this.collisionDetector, // CORREÇÃO: Parâmetro opcional
  });

  void renderRepeatMark(
    Canvas canvas,
    RepeatMark repeatMark,
    Offset basePosition,
  ) {
    final glyphName = _getRepeatMarkGlyph(repeatMark.type);
    if (glyphName == null) return;

    // CORREÇÃO SMuFL: Usar opticalCenter do metadata ao invés de valor hardcoded
    // Posição tipográfica: acima da pauta (linha 5 + espaço adicional)
    final signY = coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.5);

    // CORREÇÃO SMuFL: Usar opticalCenter anchor se disponível
    final glyphInfo = metadata.getGlyphInfo(glyphName);
    double verticalAdjust = 0;
    if (glyphInfo != null && glyphInfo.hasAnchors) {
      final opticalCenter = glyphInfo.anchors?.getAnchor('opticalCenter');
      if (opticalCenter != null) {
        verticalAdjust = opticalCenter.dy * coordinates.staffSpace;
      }
    }

    _drawGlyph(
      canvas,
      glyphName: glyphName,
      position: Offset(basePosition.dx, signY - verticalAdjust),
      size: glyphSize * 1.1,
      color: theme.repeatColor ?? theme.noteheadColor,
      centerVertically: glyphInfo == null,
      centerHorizontally: true,
    );
  }

  String? _getRepeatMarkGlyph(RepeatType type) {
    const repeatGlyphs = {RepeatType.segno: 'segno', RepeatType.coda: 'coda'};
    return repeatGlyphs[type];
  }

  void renderDynamic(Canvas canvas, Dynamic dynamic, Offset basePosition, {double verticalOffset = 0.0}) {
    if (dynamic.isHairpin) {
      _renderHairpin(canvas, dynamic, basePosition, verticalOffset: verticalOffset);
      return;
    }

    final glyphName = _getDynamicGlyph(dynamic.type);
    // CORREÇÃO TIPOGRÁFICA SMuFL: Dinâmicas devem ficar 2.5 staff spaces abaixo da última linha
    // CORREÇÃO LACERDA: Adicionar verticalOffset para evitar sobreposição
    final dynamicY =
        coordinates.getStaffLineY(1) + (coordinates.staffSpace * 2.5) + verticalOffset;

    if (glyphName != null) {
      // CORREÇÃO SMuFL: Escala de dinâmicas não deveria ser hardcoded (0.9)
      // Usar tamanho base e deixar a fonte SMuFL definir proporções
      _drawGlyph(
        canvas,
        glyphName: glyphName,
        position: Offset(basePosition.dx, dynamicY),
        size: glyphSize, // Remover escala arbitrária de 0.9
        color: theme.dynamicColor ?? theme.noteheadColor,
        centerVertically: true,
        centerHorizontally: true,
      );
    } else if (dynamic.customText != null) {
      _drawText(
        canvas,
        text: dynamic.customText!,
        position: Offset(basePosition.dx, dynamicY),
        style:
            theme.dynamicTextStyle ??
            TextStyle(
              fontSize: glyphSize * 0.4,
              fontStyle: FontStyle.italic,
              color: theme.dynamicColor ?? theme.noteheadColor,
            ),
      );
    }
  }

  void _renderHairpin(Canvas canvas, Dynamic dynamic, Offset basePosition, {double verticalOffset = 0.0}) {
    final length = dynamic.length ?? coordinates.staffSpace * 4;
    // CORREÇÃO: Usar mesma posição Y que dinâmicas
    // CORREÇÃO LACERDA: Adicionar verticalOffset para evitar sobreposição
    final hairpinY =
        coordinates.getStaffLineY(1) + (coordinates.staffSpace * 2.5) + verticalOffset;
    // CORREÇÃO TIPOGRÁFICA SMuFL: Altura recomendada de 0.75-1.0 staff spaces
    final height = coordinates.staffSpace * 0.75;

    // CORREÇÃO CRÍTICA SMuFL: Usar hairpinThickness ao invés de thinBarlineThickness
    final hairpinThickness = metadata.getEngravingDefault('hairpinThickness');
    final paint = Paint()
      ..color = theme.dynamicColor ?? theme.noteheadColor
      ..strokeWidth = hairpinThickness * coordinates.staffSpace;

    if (dynamic.type == DynamicType.crescendo) {
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY + height),
        Offset(basePosition.dx + length, hairpinY),
        paint,
      );
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY - height),
        Offset(basePosition.dx + length, hairpinY),
        paint,
      );
    } else if (dynamic.type == DynamicType.diminuendo) {
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY),
        Offset(basePosition.dx + length, hairpinY + height),
        paint,
      );
      canvas.drawLine(
        Offset(basePosition.dx, hairpinY),
        Offset(basePosition.dx + length, hairpinY - height),
        paint,
      );
    }
  }

  String? _getDynamicGlyph(DynamicType type) {
    const dynamicGlyphs = {
      DynamicType.p: 'dynamicPiano',
      DynamicType.mp: 'dynamicMezzoPiano',
      DynamicType.mf: 'dynamicMezzoForte',
      DynamicType.f: 'dynamicForte',
      DynamicType.pp: 'dynamicPP',
      DynamicType.ff: 'dynamicFF',
      DynamicType.sforzando: 'dynamicSforzando1',
    };
    return dynamicGlyphs[type];
  }

  void renderMusicText(Canvas canvas, MusicText text, Offset basePosition) {
    double yOffset = 0;
    switch (text.placement) {
      case TextPlacement.above:
        yOffset = -coordinates.staffSpace * 2.5;
        break;
      case TextPlacement.below:
        yOffset = coordinates.staffSpace * 2.5;
        break;
      case TextPlacement.inside:
        yOffset = 0;
        break;
    }
    _drawText(
      canvas,
      text: text.text,
      position: Offset(basePosition.dx, coordinates.staffBaseline.dy + yOffset),
      style: text.type == TextType.tempo
          ? (theme.tempoTextStyle ?? const TextStyle())
          : (theme.textStyle ?? const TextStyle()),
    );
  }

  void renderTempoMark(Canvas canvas, TempoMark tempo, Offset basePosition) {
    String text = tempo.text ?? '';
    if (tempo.bpm != null) {
      text += ' (♩ = ${tempo.bpm})';
    }
    _drawText(
      canvas,
      text: text,
      position: Offset(
        basePosition.dx,
        coordinates.staffBaseline.dy - (coordinates.staffSpace * 3.5),
      ),
      style:
          theme.tempoTextStyle ?? const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  void renderBreath(Canvas canvas, Breath breath, Offset basePosition) {
    final glyphName = 'breathMarkComma';
    // CORREÇÃO MUSICOLÓGICA: Respiração deve ficar ACIMA da pauta, não na 4ª linha
    // Posição correta: acima da 5ª linha (linha superior)
    _drawGlyph(
      canvas,
      glyphName: glyphName,
      position: Offset(
        basePosition.dx,
        coordinates.getStaffLineY(5) - (coordinates.staffSpace * 0.5),
      ),
      size: glyphSize * 0.7,
      color: theme.breathColor ?? theme.noteheadColor,
      centerHorizontally: true,
      centerVertically: true,
    );
  }

  void renderCaesura(Canvas canvas, Caesura caesura, Offset basePosition) {
    // CORREÇÃO MUSICOLÓGICA: Cesura deve atravessar toda a pauta
    // Usar linha central (3ª linha/baseline) como referência, não a 5ª linha
    _drawGlyph(
      canvas,
      glyphName: caesura.glyphName,
      position: Offset(basePosition.dx, coordinates.staffBaseline.dy),
      size: glyphSize,
      color: theme.caesuraColor ?? theme.noteheadColor,
      centerHorizontally: true,
      centerVertically: true,
    );
  }

  void renderOctaveMark(
    Canvas canvas,
    OctaveMark octaveMark,
    Offset basePosition,
  ) {
    // CORREÇÃO: Considerar se é 8va (acima) ou 8vb (abaixo)
    final isAbove = octaveMark.type == OctaveType.va8 || octaveMark.type == OctaveType.va15 || octaveMark.type == OctaveType.va22;
    final yPosition = isAbove
        ? coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.5) // Acima da pauta
        : coordinates.getStaffLineY(1) + (coordinates.staffSpace * 1.5); // Abaixo da pauta

    _drawText(
      canvas,
      text: octaveMark.text,
      position: Offset(
        basePosition.dx,
        yPosition,
      ),
      style:
          theme.octaveTextStyle ??
          const TextStyle(
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  void _drawText(
    Canvas canvas, {
    required String text,
    required Offset position,
    required TextStyle style,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawGlyph(
    Canvas canvas, {
    required String glyphName,
    required Offset position,
    required double size,
    required Color color,
    bool centerVertically = false,
    bool centerHorizontally = false,
  }) {
    final character = metadata.getCodepoint(glyphName);
    if (character.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: character,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: size,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    double yOffset = centerVertically ? -textPainter.height * 0.5 : 0;
    double xOffset = centerHorizontally ? -textPainter.width * 0.5 : 0;
    textPainter.paint(
      canvas,
      Offset(position.dx + xOffset, position.dy + yOffset),
    );
  }
}
