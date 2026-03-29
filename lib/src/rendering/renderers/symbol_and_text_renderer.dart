// lib/src/rendering/renderers/symbol_and_text_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../layout/collision_detector.dart'; // CORREÇÃO: Import collision detector
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';

class HairpinGeometry {
  final Offset upperStart;
  final Offset upperEnd;
  final Offset lowerStart;
  final Offset lowerEnd;

  const HairpinGeometry({
    required this.upperStart,
    required this.upperEnd,
    required this.lowerStart,
    required this.lowerEnd,
  });
}

class SymbolAndTextRenderer {
  /// SMuFL/Bravura recommended text font families (engravingDefaults.textFontFamily)
  static const List<String> smuflTextFontFallback = [
    'Academico',
    'Century Schoolbook',
    'Edwin',
    'serif',
  ];

  final StaffCoordinateSystem coordinates;
  final SmuflMetadata metadata;
  final MusicScoreTheme theme;
  final double glyphSize;
  final CollisionDetector?
  collisionDetector; // CORREÇÃO: Adicionar collision detector

  SymbolAndTextRenderer({
    required this.coordinates,
    required this.metadata,
    required this.theme,
    required this.glyphSize,
    this.collisionDetector, // CORREÇÃO: Parâmetro opcional
  });

  static Offset calculateTextPaintOrigin(
    Offset position,
    Size textSize, {
    bool centerHorizontally = true,
    bool centerVertically = true,
  }) {
    return Offset(
      position.dx - (centerHorizontally ? textSize.width * 0.5 : 0.0),
      position.dy - (centerVertically ? textSize.height * 0.5 : 0.0),
    );
  }

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
          coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.9),
        ),
        style: _repeatInstructionStyle(),
        centerHorizontally: false,
      );
      return;
    }

    // Position depende of the família of the símbolo:
    // - navegação (segno/coda): acima of the staff
    // - repeats/simile/percent: centralizados na staff
    final signY = _getRepeatMarkY(repeatMark.type);

    // Fix: SMuFL: Use opticalCenter anchor se disponível
    _drawGlyph(
      canvas,
      glyphName: glyphName,
      position: Offset(basePosition.dx, signY),
      size: glyphSize * _getRepeatMarkScale(repeatMark.type),
      color: theme.repeatColor ?? theme.noteheadColor,
      centerVertically: true,
      centerHorizontally: true,
    );

    final countLabel = _getRepeatCountLabel(repeatMark);
    if (countLabel != null) {
      _drawText(
        canvas,
        text: countLabel,
        position: Offset(
          basePosition.dx,
          signY - (coordinates.staffSpace * 1.7),
        ),
        style: _repeatCountStyle(),
      );
    }
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
        // Segno/Coda: escala reduzida for not quebrar spacing of the measure
        return 0.45;
      case RepeatType.repeat1Bar:
      case RepeatType.simile:
      case RepeatType.percentRepeat:
        return 0.92;
      case RepeatType.repeat2Bars:
      case RepeatType.repeat4Bars:
        return 0.92;
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
        return 0.92;
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
        return coordinates.staffBaseline.dy - (coordinates.staffSpace * 0.05);
      default:
        return coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.8);
    }
  }

  String? _getRepeatCountLabel(RepeatMark repeatMark) {
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

  TextStyle _repeatInstructionStyle() {
    final baseColor =
        theme.repeatColor ?? theme.textColor ?? theme.noteheadColor;
    return (theme.repeatTextStyle ??
            theme.expressionTextStyle ??
            const TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              fontFamilyFallback: smuflTextFontFallback,
            ))
        .copyWith(color: baseColor, fontFamilyFallback: smuflTextFontFallback);
  }

  TextStyle _repeatCountStyle() {
    final baseColor = theme.repeatColor ?? theme.noteheadColor;
    return (theme.repeatTextStyle ??
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
        .copyWith(color: baseColor);
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
    // CORREÃ‡ÃƒO TIPOGRÃFICA SMuFL: DinÃ¢micas devem ficar 2.5 staff spaces abaixo of the Ãºltima linha
    // Fix: LACERDA: Add verticalOffset for evitar sobreposição
    final dynamicY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;

    if (glyphName != null) {
      // Fix: SMuFL: Escala de dynamic not deveria ser hardcoded (0.9)
      // Usesr size base e deixar a fonte SMuFL Define proporções
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
        style: _dynamicTextStyle(),
      );
    }
  }

  void _renderHairpin(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition, {
    double verticalOffset = 0.0,
  }) {
    final length = dynamic.length ?? coordinates.staffSpace * 6;
    // Fix: Use mesma Y position that dynamic
    // Fix: LACERDA: Add verticalOffset for evitar sobreposição
    final hairpinY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;
    // CORREÃ‡ÃƒO TIPOGRÃFICA SMuFL: Height recomendada de 0.75-1.0 staff spaces
    final height = coordinates.staffSpace * 0.5;

    // CORREÃ‡ÃƒO CRÃTICA SMuFL: Usesr hairpinThickness ao invÃ©s de thinBarlineThickness
    final hairpinThickness = metadata.getEngravingDefault('hairpinThickness');
    final paint = Paint()
      ..color = theme.dynamicColor ?? theme.noteheadColor
      ..strokeWidth = hairpinThickness * coordinates.staffSpace
      ..strokeCap = StrokeCap.butt;

    final geometry = calculateHairpinGeometry(
      dynamic.type,
      basePosition,
      length,
      hairpinY,
      height,
    );

    canvas.drawLine(geometry.upperStart, geometry.upperEnd, paint);
    canvas.drawLine(geometry.lowerStart, geometry.lowerEnd, paint);

    // Render custom text label centered over the hairpin
    if (dynamic.customText != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: dynamic.customText!,
          style: _dynamicTextStyle(fontScale: 0.32),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(
          basePosition.dx + length / 2 - tp.width / 2,
          hairpinY - coordinates.staffSpace * 1.25 - tp.height / 2,
        ),
      );
    }
  }

  static HairpinGeometry calculateHairpinGeometry(
    DynamicType type,
    Offset basePosition,
    double length,
    double centerY,
    double halfHeight,
  ) {
    final leftX = basePosition.dx;
    final rightX = basePosition.dx + length;

    if (type == DynamicType.diminuendo) {
      return HairpinGeometry(
        upperStart: Offset(leftX, centerY - halfHeight),
        upperEnd: Offset(rightX, centerY),
        lowerStart: Offset(leftX, centerY + halfHeight),
        lowerEnd: Offset(rightX, centerY),
      );
    }

    return HairpinGeometry(
      upperStart: Offset(leftX, centerY),
      upperEnd: Offset(rightX, centerY - halfHeight),
      lowerStart: Offset(leftX, centerY),
      lowerEnd: Offset(rightX, centerY + halfHeight),
    );
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

  TextStyle _dynamicTextStyle({double fontScale = 0.4}) {
    final baseColor = theme.dynamicColor ?? theme.noteheadColor;
    return (theme.dynamicTextStyle ??
            theme.expressionTextStyle ??
            TextStyle(
              fontSize: glyphSize * fontScale,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              fontFamilyFallback: smuflTextFontFallback,
            ))
        .copyWith(
          color: baseColor,
          fontFamilyFallback: smuflTextFontFallback,
          fontSize:
              (theme.dynamicTextStyle?.fontSize ??
              theme.expressionTextStyle?.fontSize ??
              (glyphSize * fontScale)),
        );
  }

  TextStyle _resolveMusicTextStyle(MusicText text) {
    final Color baseColor = theme.textColor ?? theme.noteheadColor;
    TextStyle baseStyle;

    switch (text.type) {
      case TextType.tempo:
        baseStyle = _tempoTextStyle();
        break;
      case TextType.expression:
      case TextType.instruction:
      case TextType.dynamics:
        baseStyle =
            theme.expressionTextStyle ??
            theme.textStyle ??
            TextStyle(
              fontSize: coordinates.staffSpace * 1.1,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              fontFamilyFallback: smuflTextFontFallback,
            );
        break;
      default:
        baseStyle =
            theme.textStyle ??
            TextStyle(
              fontSize: coordinates.staffSpace,
              fontWeight: FontWeight.w500,
              fontFamilyFallback: smuflTextFontFallback,
            );
        break;
    }

    FontStyle? fontStyle = baseStyle.fontStyle;
    if (text.italic == true) {
      fontStyle = FontStyle.italic;
    } else if (text.italic == false) {
      fontStyle = FontStyle.normal;
    }

    FontWeight? fontWeight = baseStyle.fontWeight;
    if (text.bold == true) {
      fontWeight = FontWeight.w700;
    }

    return baseStyle.copyWith(
      color: baseStyle.color ?? baseColor,
      fontFamily: text.fontFamily ?? baseStyle.fontFamily,
      fontFamilyFallback: smuflTextFontFallback,
      fontSize: text.fontSize ?? baseStyle.fontSize,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
    );
  }

  double _resolveMusicTextY(MusicText text) {
    switch (text.placement) {
      case TextPlacement.above:
        switch (text.type) {
          case TextType.tempo:
            return _tempoMarkCenterY();
          case TextType.expression:
          case TextType.instruction:
          case TextType.dynamics:
            return coordinates.getStaffLineY(5) -
                (coordinates.staffSpace * 1.75);
          default:
            return coordinates.getStaffLineY(5) -
                (coordinates.staffSpace * 1.55);
        }
      case TextPlacement.below:
        return coordinates.getStaffLineY(1) + (coordinates.staffSpace * 2.0);
      case TextPlacement.inside:
        return coordinates.staffBaseline.dy;
    }
  }

  void renderMusicText(Canvas canvas, MusicText text, Offset basePosition) {
    final style = _resolveMusicTextStyle(text);
    final yPosition = _resolveMusicTextY(text);

    _drawText(
      canvas,
      text: text.text,
      position: Offset(basePosition.dx, yPosition),
      style: style,
      centerHorizontally: false,
    );
  }

  void renderTempoMark(Canvas canvas, TempoMark tempo, Offset basePosition) {
    final style = _tempoTextStyle();
    final tempoCenterY = _tempoMarkCenterY();
    var cursorX = basePosition.dx;

    final tempoText = tempo.text?.trim();
    if (tempoText != null && tempoText.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: tempoText, style: style),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cursorX, tempoCenterY - tp.height / 2));
      cursorX += tp.width + (coordinates.staffSpace * 0.12);
    }

    if (tempo.bpm == null || !tempo.showMetronome) {
      return;
    }

    final spacing = TextPainter(
      text: TextSpan(
        text: tempoText == null || tempoText.isEmpty ? '(' : ' (',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    spacing.paint(canvas, Offset(cursorX, tempoCenterY - spacing.height / 2));
    cursorX += spacing.width;

    final glyphName = _getMetronomeGlyphName(tempo.beatUnit);
    if (glyphName != null) {
      final metronomeGlyphSize = glyphSize * 0.46;
      _drawGlyph(
        canvas,
        glyphName: glyphName,
        position: Offset(cursorX, tempoCenterY),
        size: metronomeGlyphSize,
        color:
            theme.metronomeColor ??
            style.color ??
            theme.textColor ??
            Colors.black87,
        centerVertically: true,
      );
      final glyphAdvance =
          metadata.getGlyphWidth(glyphName) *
          coordinates.staffSpace *
          (metronomeGlyphSize / glyphSize);
      cursorX += glyphAdvance + (coordinates.staffSpace * 0.18);
    } else {
      final fallback = TextPainter(
        text: TextSpan(text: '\u2669', style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      fallback.paint(
        canvas,
        Offset(cursorX, tempoCenterY - fallback.height / 2),
      );
      cursorX += fallback.width + (coordinates.staffSpace * 0.18);
    }

    final equalsAndBpm = TextPainter(
      text: TextSpan(text: ' = ${tempo.bpm})', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    equalsAndBpm.paint(
      canvas,
      Offset(cursorX, tempoCenterY - equalsAndBpm.height / 2),
    );
  }

  String? _getMetronomeGlyphName(DurationType durationType) {
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
        return 'metNote128thUp';
      case DurationType.twoHundredFiftySixth:
        return 'metNote128thUp';
      default:
        return 'metNoteQuarterUp';
    }
  }

  TextStyle _tempoTextStyle() {
    final baseColor = theme.textColor ?? theme.noteheadColor;
    return (theme.tempoTextStyle ??
            TextStyle(
              fontSize: coordinates.staffSpace * 1.3,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              fontFamilyFallback: smuflTextFontFallback,
              letterSpacing: 0.15,
            ))
        .copyWith(
          color: theme.tempoTextStyle?.color ?? baseColor,
          fontFamilyFallback: smuflTextFontFallback,
        );
  }

  double _tempoMarkCenterY() {
    return coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.95);
  }

  void renderBreath(Canvas canvas, Breath breath, Offset basePosition) {
    final glyphName = 'breathMarkComma';
    // Fix: MUSICOLÓGICA: Respiração deve ficar ACIMA of the staff, not na 4ª linha
    // Position correta: acima of the 5ª linha (linha superior)
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
    // Fix: MUSICOLÓGICA: Cesura deve atravessar toda a staff
    // Usesr linha central (3ª linha/baseline) como reference, not a 5ª linha
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
    double?
    referenceNoteY, // Y da nota mais extrema no span (para evitar sobreposicao com linhas suplementares)
  }) {
    final isAbove =
        octaveMark.type == OctaveType.va8 ||
        octaveMark.type == OctaveType.va15 ||
        octaveMark.type == OctaveType.va22;

    final standardY = isAbove
        ? coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.8)
        : coordinates.getStaffLineY(1) + (coordinates.staffSpace * 1.8);

    // Ajusta Y dinamicamente se notes in linhas suplementares conflitam with a marcacao
    final double yPosition;
    if (referenceNoteY != null) {
      if (isAbove) {
        final clearanceY = referenceNoteY - coordinates.staffSpace * 1.0;
        yPosition = math.min(standardY, clearanceY);
      } else {
        final clearanceY = referenceNoteY + coordinates.staffSpace * 1.0;
        yPosition = math.max(standardY, clearanceY);
      }
    } else {
      yPosition = standardY;
    }
    final xStart =
        (startX ?? basePosition.dx) + (coordinates.staffSpace * 0.22);

    // 1. Draw the text label
    final style =
        theme.octaveTextStyle ??
        const TextStyle(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
        );
    final octaveColor = theme.octaveColor ?? style.color ?? Colors.black87;
    final tp = TextPainter(
      text: TextSpan(
        text: octaveMark.text,
        style: style.copyWith(color: octaveColor),
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final labelTopY = yPosition - (tp.height * (isAbove ? 0.58 : 0.46));
    tp.paint(canvas, Offset(xStart, labelTopY));
    final textEndX = xStart + tp.width;

    // 2. Draw a dashed horizontal line after the text
    final lineLength = octaveMark.length > 0
        ? octaveMark.length
        : coordinates.staffSpace * 3;
    final targetEndX = endX ?? (xStart + lineLength);
    final lineY = yPosition;

    final linePaint = Paint()
      ..color = octaveColor
      ..strokeWidth = coordinates.staffSpace * 0.12
      ..style = PaintingStyle.stroke;

    final lineStartX = textEndX + coordinates.staffSpace * 0.28;
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
    bool centerHorizontally = true,
    bool centerVertically = true,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: centerHorizontally ? TextAlign.center : TextAlign.left,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final origin = calculateTextPaintOrigin(
      position,
      Size(textPainter.width, textPainter.height),
      centerHorizontally: centerHorizontally,
      centerVertically: centerVertically,
    );
    textPainter.paint(canvas, origin);
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
