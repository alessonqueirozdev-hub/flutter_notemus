// lib/src/rendering/renderers/symbol_and_text_renderer.dart

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // ðŸ†• Tipos do core
import '../../layout/collision_detector.dart'; // CORREÃ‡ÃƒO: Import collision detector
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';

class SymbolAndTextRenderer {
  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final CollisionDetector?
  collisionDetector; // CORREÃ‡ÃƒO: Adicionar collision detector

  SymbolAndTextRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    this.collisionDetector, // CORREÃ‡ÃƒO: ParÃ¢metro opcional
  });

  void renderRepeatMark(
    Canvas canvas,
    RepeatMark repeatMark,
    Offset basePosition,
  ) {
    final glyphName = _getRepeatMarkGlyph(repeatMark.type);
    if (glyphName == null) {
      final fallbackText = _getRepeatMarkFallbackText(repeatMark.type);
      if (fallbackText == null) return;
      _drawText(
        canvas,
        text: fallbackText,
        position: Offset(
          basePosition.dx,
          coordinates.getStaffLineY(5) - (coordinates.staffSpace * 2.2),
        ),
        style: theme.textStyle ??
            const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
      );
      return;
    }

    // PosiÃ§Ã£o depende da famÃ­lia do sÃ­mbolo:
    // - navegaÃ§Ã£o (segno/coda): acima da pauta
    // - repeats/simile/percent: centralizados na pauta
    final signY = _getRepeatMarkY(repeatMark.type);

    // CORREÃ‡ÃƒO SMuFL: Usar opticalCenter anchor se disponÃ­vel
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
      size: glyphSize * _getRepeatMarkScale(repeatMark.type),
      color: theme.repeatColor ?? theme.noteheadColor,
      centerVertically: glyphInfo == null,
      centerHorizontally: true,
    );
  }

  String? _getRepeatMarkGlyph(RepeatType type) {
    final candidates = _repeatGlyphCandidates(type);
    if (candidates.isEmpty) return null;
    for (final glyph in candidates) {
      if (metadata.getCodepoint(glyph).isNotEmpty) return glyph;
    }
    return null;
  }

  List<String> _repeatGlyphCandidates(RepeatType type) {
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

  String? _getRepeatMarkFallbackText(RepeatType type) {
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

  double _getRepeatMarkScale(RepeatType type) {
    switch (type) {
      case RepeatType.segno:
      case RepeatType.coda:
      case RepeatType.segnoSquare:
      case RepeatType.codaSquare:
        return 0.72; // proporcional ao pentagrama
      case RepeatType.repeat1Bar:
      case RepeatType.repeat2Bars:
      case RepeatType.repeat4Bars:
      case RepeatType.simile:
      case RepeatType.percentRepeat:
      case RepeatType.repeatDots:
      case RepeatType.repeatLeft:
      case RepeatType.repeatRight:
      case RepeatType.repeatBoth:
      case RepeatType.start:
      case RepeatType.end:
        return 0.95;
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

  double _getRepeatMarkY(RepeatType type) {
    switch (type) {
      case RepeatType.repeat1Bar:
      case RepeatType.repeat2Bars:
      case RepeatType.repeat4Bars:
      case RepeatType.simile:
      case RepeatType.percentRepeat:
      case RepeatType.repeatDots:
      case RepeatType.repeatLeft:
      case RepeatType.repeatRight:
      case RepeatType.repeatBoth:
      case RepeatType.start:
      case RepeatType.end:
        return coordinates.staffBaseline.dy;
      default:
        return coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.5);
    }
  }

  void renderDynamic(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition, {
    double verticalOffset = 0.0,
  }) {
    if (dynamic.isHairpin) {
      _renderHairpin(
        canvas,
        dynamic,
        basePosition,
        verticalOffset: verticalOffset,
      );
      return;
    }

    final glyphName = _getDynamicGlyph(dynamic.type);
    // CORREÃ‡ÃƒO TIPOGRÃFICA SMuFL: DinÃ¢micas devem ficar 2.5 staff spaces abaixo da Ãºltima linha
    // CORREÃ‡ÃƒO LACERDA: Adicionar verticalOffset para evitar sobreposiÃ§Ã£o
    final dynamicY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;

    if (glyphName != null) {
      // CORREÃ‡ÃƒO SMuFL: Escala de dinÃ¢micas nÃ£o deveria ser hardcoded (0.9)
      // Usar tamanho base e deixar a fonte SMuFL definir proporÃ§Ãµes
      _drawGlyph(
        canvas,
        glyphName: glyphName,
        position: Offset(basePosition.dx, dynamicY),
        size: glyphSize, // Remover escala arbitrÃ¡ria de 0.9
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

  void _renderHairpin(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition, {
    double verticalOffset = 0.0,
  }) {
    final length = dynamic.length ?? coordinates.staffSpace * 4;
    // CORREÃ‡ÃƒO: Usar mesma posiÃ§Ã£o Y que dinÃ¢micas
    // CORREÃ‡ÃƒO LACERDA: Adicionar verticalOffset para evitar sobreposiÃ§Ã£o
    final hairpinY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;
    // CORREÃ‡ÃƒO TIPOGRÃFICA SMuFL: Altura recomendada de 0.75-1.0 staff spaces
    final height = coordinates.staffSpace * 0.75;

    // CORREÃ‡ÃƒO CRÃTICA SMuFL: Usar hairpinThickness ao invÃ©s de thinBarlineThickness
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

    // Render custom text label centered over the hairpin
    if (dynamic.customText != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: dynamic.customText!,
          style: TextStyle(
            fontSize: glyphSize * 0.32,
            fontStyle: FontStyle.italic,
            color: theme.dynamicColor ?? Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(
          basePosition.dx + length / 2 - tp.width / 2,
          hairpinY - tp.height / 2,
        ),
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
      text += ' (â™© = ${tempo.bpm})';
    }
    final style =
        theme.tempoTextStyle ?? const TextStyle(fontWeight: FontWeight.bold);
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();

    final textTopY =
        coordinates.getStaffLineY(5) - (coordinates.staffSpace * 2.8);
    tp.paint(canvas, Offset(basePosition.dx, textTopY - tp.height));
  }

  void renderBreath(Canvas canvas, Breath breath, Offset basePosition) {
    final glyphName = 'breathMarkComma';
    // CORREÃ‡ÃƒO MUSICOLÃ“GICA: RespiraÃ§Ã£o deve ficar ACIMA da pauta, nÃ£o na 4Âª linha
    // PosiÃ§Ã£o correta: acima da 5Âª linha (linha superior)
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
    // CORREÃ‡ÃƒO MUSICOLÃ“GICA: Cesura deve atravessar toda a pauta
    // Usar linha central (3Âª linha/baseline) como referÃªncia, nÃ£o a 5Âª linha
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
    Offset basePosition, {
    double? startX,
    double? endX,
  }) {
    final isAbove =
        octaveMark.type == OctaveType.va8 ||
        octaveMark.type == OctaveType.va15 ||
        octaveMark.type == OctaveType.va22;
    final yPosition = isAbove
        ? coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.8)
        : coordinates.getStaffLineY(1) + (coordinates.staffSpace * 1.8);
    final xStart = startX ?? basePosition.dx;

    // 1. Draw the text label
    final style =
        theme.octaveTextStyle ??
        const TextStyle(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
        );
    final tp = TextPainter(
      text: TextSpan(text: octaveMark.text, style: style),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(xStart, yPosition - tp.height / 2));
    final textEndX = xStart + tp.width;

    // 2. Draw a dashed horizontal line after the text
    final lineLength = octaveMark.length > 0
        ? octaveMark.length
        : coordinates.staffSpace * 3;
    final targetEndX = endX ?? (xStart + lineLength);
    final lineY = yPosition;

    final linePaint = Paint()
      ..color = (style.color ?? Colors.black87)
      ..strokeWidth = coordinates.staffSpace * 0.1
      ..style = PaintingStyle.stroke;

    final lineStartX = textEndX + coordinates.staffSpace * 0.2;
    final lineEndX = targetEndX > lineStartX
        ? targetEndX
        : lineStartX + coordinates.staffSpace * 0.5;

    _drawDashedLine(
      canvas,
      Offset(lineStartX, lineY),
      Offset(lineEndX, lineY),
      linePaint,
      coordinates.staffSpace,
    );

    // 3. Draw a vertical hook at the end if showBracket is true
    if (octaveMark.showBracket) {
      final hookHeight = coordinates.staffSpace * 0.75;
      final hookEndY = isAbove ? lineY + hookHeight : lineY - hookHeight;
      canvas.drawLine(
        Offset(lineEndX, lineY),
        Offset(lineEndX, hookEndY),
        linePaint,
      );
    }
  }

  /// Renders a volta bracket (1st/2nd ending) above the staff
  void renderVoltaBracket(
    Canvas canvas,
    VoltaBracket bracket,
    Offset basePosition, {
    double? startX,
    double? endX,
  }) {
    final yTop = coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.8);
    final yBottom = coordinates.getStaffLineY(5);
    final xLeft = startX ?? basePosition.dx;
    final fallbackRight =
        basePosition.dx +
        (bracket.length > 0 ? bracket.length : coordinates.staffSpace * 4);
    final xRight = endX ?? fallbackRight;

    final paint = Paint()
      ..color = theme.barlineColor
      ..strokeWidth = coordinates.staffSpace * 0.12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Left vertical line
    canvas.drawLine(Offset(xLeft, yTop), Offset(xLeft, yBottom), paint);
    // Top horizontal line
    canvas.drawLine(Offset(xLeft, yTop), Offset(xRight, yTop), paint);
    // Right vertical line (only if not open end)
    if (!bracket.hasOpenEnd) {
      canvas.drawLine(Offset(xRight, yTop), Offset(xRight, yBottom), paint);
    }

    // Label text
    final tp = TextPainter(
      text: TextSpan(
        text: bracket.displayLabel,
        style: TextStyle(
          fontSize: coordinates.staffSpace * 1.1,
          color: theme.barlineColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(
        xLeft + coordinates.staffSpace * 0.3,
        yTop + coordinates.staffSpace * 0.1,
      ),
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double staffSpace,
  ) {
    final dashLen = staffSpace * 0.5;
    final gapLen = staffSpace * 0.3;
    double x = start.dx;
    while (x + dashLen < end.dx) {
      canvas.drawLine(
        Offset(x, start.dy),
        Offset(x + dashLen, start.dy),
        paint,
      );
      x += dashLen + gapLen;
    }
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
