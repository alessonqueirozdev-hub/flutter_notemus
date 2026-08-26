// lib/src/rendering/renderers/symbol_and_text_renderer.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/core.dart'; // 🆕 Tipos do core
import '../../layout/collision_detector.dart'; // CORREÇÃO: Import collision detector
import '../../smufl/smufl_metadata_loader.dart';
import '../../theme/music_score_theme.dart';
import '../staff_coordinate_system.dart';
import '../text_font.dart';

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
  /// Text (non-music) font families recommended by SMuFL for the prose that
  /// accompanies a score — dynamics words, tempo marks, instructions.
  ///
  /// These are the families listed by `engravingDefaults.textFontFamily` in the
  /// SMuFL reference metadata; they are *text* faces, unrelated to the music
  /// font, which is never named here (see BaseGlyphRenderer, "Font
  /// independence") and always comes from `metadata.font`.
  ///
  /// Canonical list lives in `lib/src/rendering/text_font.dart` so every text
  /// site in the package shares one chain; this stays as the published name.
  ///
  /// DELIBERATELY NOT APPLIED INSIDE THIS CLASS ANY MORE (2.7.2, finding M-30).
  /// Every style built here now ends in [MusicTextFallback.withMusicTextFallback]
  /// and nothing else touches `fontFamilyFallback`. The reason is the extension's
  /// documented contract — *"a caller-supplied family or fallback chain always
  /// wins"* — which makes pre-supplying this chain self-defeating: the style
  /// arrived at the injection point already carrying a chain, so
  /// `withMusicTextFallback()` treated it as a deliberate caller choice, returned
  /// it untouched, and [MusicTextFont.use] could never promote an app face to
  /// primary. Ten sites in this file did exactly that.
  ///
  /// Measured before the fix: the same score rasterised with and without
  /// `MusicTextFont.use('AppSerif')` produced **76,120 px of ink in BOTH cases**
  /// (byte-identical PNGs) for tempo marks, expression text, word dynamics and
  /// repeat instructions — the escape hatch was inert on every prose string this
  /// class draws. After the fix the two rasters differ (see
  /// `test/invariants/w5_text_font_hatch_test.dart`, which asserts the ink
  /// changes and that the `.notdef` box count drops to 0 once a real face is
  /// injected).
  ///
  /// The constant stays public and unchanged because apps reference it when
  /// building their own [MusicScoreTheme] text styles; it is simply no longer
  /// the mechanism this class uses.
  static const List<String> smuflTextFontFallback = kMusicTextFontFallback;

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

    // Position depende of the família of the symbol:
    // - navegação (segno/coda): above the staff
    // - repeats/simile/percent: centralizados na staff
    final signY = _getRepeatMarkY(repeatMark.type);

    // SMuFL: use the opticalCenter anchor when the font provides one.
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
            ))
        .copyWith(color: baseColor)
        .withMusicTextFallback();
  }

  TextStyle _repeatCountStyle() {
    final baseColor = theme.repeatColor ?? theme.noteheadColor;
    return (theme.repeatTextStyle ??
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
        .copyWith(color: baseColor)
        .withMusicTextFallback();
  }

  void renderDynamic(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition, {
    double verticalOffset = 0.0,
    double? lengthOverride,
  }) {
    if (dynamic.isHairpin) {
      _renderHairpin(
        canvas,
        dynamic,
        basePosition,
        verticalOffset: verticalOffset,
        lengthOverride: lengthOverride,
      );
      return;
    }

    final glyphName = _getDynamicGlyph(dynamic.type);
    // CORREÇÃO TIPOGRÃIs SMuFL: DinÃ¢micas must be placed 2.5 staff spaces below the Ãºltima line
    // Fix: LACERDA: Add verticalOffset for avoid overlap
    final dynamicY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;

    if (glyphName != null) {
      // Fix: SMuFL: Escala de dynamic not deveria ser hardcoded (0.9)
      // Use size base and deixar a fonte SMuFL Define proporções
      _drawGlyph(
        canvas,
        glyphName: glyphName,
        position: Offset(basePosition.dx, dynamicY),
        size: glyphSize, // Remover escala arbitrária de 0.9
        color: theme.dynamicColor ?? theme.noteheadColor,
        centerVertically: true,
        centerHorizontally: true,
      );
    } else {
      // No combined glyph (word-based dynamic): fall back to explicit custom
      // text, then to a standard textual abbreviation (cresc., dim., …).
      final text = dynamic.customText ?? _getDynamicText(dynamic.type);
      if (text != null) {
        _drawText(
          canvas,
          text: text,
          position: Offset(basePosition.dx, dynamicY),
          style: _dynamicTextStyle(),
        );
      }
    }
  }

  void _renderHairpin(
    Canvas canvas,
    Dynamic dynamic,
    Offset basePosition, {
    double verticalOffset = 0.0,
    double? lengthOverride,
  }) {
    // Precedence: explicit model length, then the computed span to the next
    // dynamic/barline, then a 6-SS default stub.
    final length =
        dynamic.length ?? lengthOverride ?? coordinates.staffSpace * 6;
    // Fix: Use same Y position that dynamic
    // Fix: LACERDA: Add verticalOffset for avoid overlap
    final hairpinY =
        coordinates.getStaffLineY(1) +
        (coordinates.staffSpace * 2.5) +
        verticalOffset;
    // SMuFL typography: recommended height is 0.75-1.0 staff spaces.
    final height = coordinates.staffSpace * 0.5;

    // CRITICAL SMuFL fix: use hairpinThickness, not thinBarlineThickness.
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

  /// Maps a [DynamicType] to its SMuFL combined-dynamic glyph name.
  ///
  /// Covers both the full-word spellings (`piano`, `forte`, …) and the
  /// abbreviations (`p`, `f`, …); previously only a handful of abbreviations
  /// were mapped, so `DynamicType.piano`/`.forte`/`.mezzoForte`/`.fff`/… — the
  /// spellings used throughout the README and public API — returned null and
  /// rendered nothing. Word-based dynamics (crescendo, subito, …) have no single
  /// glyph and fall through to [_getDynamicText].
  String? _getDynamicGlyph(DynamicType type) {
    const dynamicGlyphs = <DynamicType, String>{
      // Full-word spellings
      DynamicType.pianississimo: 'dynamicPPP',
      DynamicType.pianissimo: 'dynamicPP',
      DynamicType.piano: 'dynamicPiano',
      DynamicType.mezzoPiano: 'dynamicMP',
      DynamicType.mezzoForte: 'dynamicMF',
      DynamicType.forte: 'dynamicForte',
      DynamicType.fortissimo: 'dynamicFF',
      DynamicType.fortississimo: 'dynamicFFF',
      // Extremes
      DynamicType.pppp: 'dynamicPPPP',
      DynamicType.ppppp: 'dynamicPPPPP',
      DynamicType.pppppp: 'dynamicPPPPPP',
      DynamicType.ffff: 'dynamicFFFF',
      DynamicType.fffff: 'dynamicFFFFF',
      DynamicType.ffffff: 'dynamicFFFFFF',
      // Abbreviations
      DynamicType.ppp: 'dynamicPPP',
      DynamicType.pp: 'dynamicPP',
      DynamicType.p: 'dynamicPiano',
      DynamicType.mp: 'dynamicMP',
      DynamicType.mf: 'dynamicMF',
      DynamicType.f: 'dynamicForte',
      DynamicType.ff: 'dynamicFF',
      DynamicType.fff: 'dynamicFFF',
      // Special accents
      DynamicType.sforzando: 'dynamicSforzando1',
      DynamicType.sforzandoFF: 'dynamicSforzatoFF',
      DynamicType.sforzandoPiano: 'dynamicSforzandoPiano',
      DynamicType.sforzandoPianissimo: 'dynamicSforzandoPianissimo',
      DynamicType.rinforzando: 'dynamicRinforzando2',
      DynamicType.fortePiano: 'dynamicFortePiano',
      DynamicType.niente: 'dynamicNiente',
    };
    return dynamicGlyphs[type];
  }

  /// Text fallback for word-based dynamics that have no single SMuFL glyph.
  String? _getDynamicText(DynamicType type) {
    switch (type) {
      case DynamicType.crescendo:
        return 'cresc.';
      case DynamicType.diminuendo:
        return 'dim.';
      case DynamicType.subito:
        return 'sub.';
      case DynamicType.possibile:
        return 'poss.';
      case DynamicType.menoMosso:
        return 'meno mosso';
      case DynamicType.piuMosso:
        return 'più mosso';
      default:
        return null;
    }
  }

  TextStyle _dynamicTextStyle({double fontScale = 0.4}) {
    final baseColor = theme.dynamicColor ?? theme.noteheadColor;
    return (theme.dynamicTextStyle ??
            theme.expressionTextStyle ??
            TextStyle(
              fontSize: glyphSize * fontScale,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ))
        .copyWith(
          color: baseColor,
          fontSize:
              (theme.dynamicTextStyle?.fontSize ??
              theme.expressionTextStyle?.fontSize ??
              (glyphSize * fontScale)),
        )
        .withMusicTextFallback();
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
            );
        break;
      case TextType.rehearsal:
        // Behind Bars: rehearsal marks are UPRIGHT and BOLD (never italic, so
        // they never read as an expression mark), set larger than surrounding
        // text and enclosed in a box.
        // Merge rather than replace, so a theme that only sets a font family
        // keeps the staff-derived size and the upright/bold convention.
        baseStyle = TextStyle(
          fontSize: coordinates.staffSpace * 1.5,
          fontStyle: FontStyle.normal,
          fontWeight: FontWeight.w700,
        ).merge(theme.rehearsalTextStyle);
        break;
      default:
        baseStyle =
            theme.textStyle ??
            TextStyle(
              fontSize: coordinates.staffSpace,
              fontWeight: FontWeight.w500,
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

    return baseStyle
        .copyWith(
          color: baseStyle.color ?? baseColor,
          fontFamily: text.fontFamily ?? baseStyle.fontFamily,
          fontSize: text.fontSize ?? baseStyle.fontSize,
          fontStyle: fontStyle,
          fontWeight: fontWeight,
        )
        .withMusicTextFallback();
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
          case TextType.rehearsal:
            // Highest layer above the staff: a rehearsal mark outranks tempo
            // and expression text (Gould).
            return coordinates.getStaffLineY(5) -
                (coordinates.staffSpace * 3.2);
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
    final position = Offset(basePosition.dx, yPosition);

    if (text.type == TextType.rehearsal) {
      _drawRehearsalEnclosure(canvas, text.text, position, style);
    }

    _drawText(
      canvas,
      text: text.text,
      position: position,
      style: style,
      centerHorizontally: false,
    );
  }

  /// Boxes a rehearsal mark.
  ///
  /// `TextType.rehearsal` was imported from MusicXML `<rehearsal>` since 2.x
  /// and then fell through the default branch of every text switch — modelled,
  /// never drawn. A rehearsal mark without its enclosure is just bold text and
  /// is not what a player scans for, so the box is part of the feature.
  ///
  /// Behind Bars: a thin rectangle with a small, even margin around the glyphs;
  /// the SMuFL `textEnclosureThickness` engraving default gives the line width.
  void _drawRehearsalEnclosure(
    Canvas canvas,
    String label,
    Offset position,
    TextStyle style,
  ) {
    if (label.trim().isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final pad = coordinates.staffSpace * 0.32;
    final rect = Rect.fromLTWH(
      position.dx - pad,
      position.dy - painter.height / 2 - pad,
      painter.width + pad * 2,
      painter.height + pad * 2,
    );

    final thickness =
        metadata.getEngravingDefault('textEnclosureThickness', 0.16) *
            coordinates.staffSpace;

    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = style.color ?? theme.textColor ?? theme.noteheadColor,
    );
  }

  void renderTempoMark(
    Canvas canvas,
    TempoMark tempo,
    Offset basePosition, {
    /// Pixels to lift this mark clear of the ones already occupying the space
    /// above the staff. Computed by `LayoutEngine.aboveStaffLevels`, because a
    /// direction has no horizontal advance and so cannot get out of another
    /// one's way sideways.
    double levelOffset = 0.0,
  }) {
    final style = _tempoTextStyle();
    final tempoCenterY = _tempoMarkCenterY() - levelOffset;
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
              letterSpacing: 0.15,
            ))
        .copyWith(
          color: theme.tempoTextStyle?.color ?? baseColor,
        )
        .withMusicTextFallback();
  }

  double _tempoMarkCenterY() {
    return coordinates.getStaffLineY(5) - (coordinates.staffSpace * 1.95);
  }

  void renderBreath(Canvas canvas, Breath breath, Offset basePosition) {
    final glyphName = 'breathMarkComma';
    // Fix: MUSICOLÓGICA: Respiração must be placed Above the staff, not na 4ª line
    // Position correct: above the 5ª line (line upper)
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
    // Fix: MUSICOLÓGICA: Cesura must atravessar toda a staff
    // Use middle line (3ª line/baseline) as reference, not a 5ª line
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

    // Ajusta Y dinamicamente if notes in ledger lines conflitam with a marcacao
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
        // The 8va/8vb label is TEXT, not a SMuFL glyph, and was one of two
        // sites in this file still handing a bare style to a TextPainter.
        style: style.copyWith(color: octaveColor).withMusicTextFallback(),
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

    // Label text. Named no family before 2.7.1, so an analysis bracket exported
    // headlessly rendered its label as `.notdef` boxes.
    final tp = TextPainter(
      text: TextSpan(
        text: bracket.displayLabel,
        style: TextStyle(
          fontSize: coordinates.staffSpace * 1.1,
          color: theme.barlineColor,
        ).withMusicTextFallback(),
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
          // Font independence: the family comes from the loaded descriptor.
          fontFamily: metadata.font.fontFamily,
          package: metadata.font.fontPackage,
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
