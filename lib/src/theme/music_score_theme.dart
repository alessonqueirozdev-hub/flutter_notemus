// lib/src/theme/music_score_theme.dart
import 'package:flutter/material.dart';

import '../rendering/text_font.dart';

// `MusicTextFont` is the runtime switch behind [MusicScoreTheme.textFontFamily]
// and an app cannot use the theme field without it, so it is re-exported from
// the one theme library the public barrel already exports. (The permanent home
// for this line is the barrel itself; see the sprint notes.)
export '../rendering/text_font.dart' show MusicTextFont, kMusicTextFontFallback;

class MusicScoreTheme {
  // Cores básicas
  final Color staffLineColor;
  final Color noteheadColor;
  final Color stemColor;
  final Color clefColor;
  final Color barlineColor;
  final Color timeSignatureColor;
  final Color keySignatureColor;
  final Color restColor;
  final Color articulationColor;

  // Cores for elementos avançados
  final Color? ornamentColor;
  final Color? dynamicColor;
  final Color? tupletColor;
  final Color? breathColor;
  final Color? slurColor;
  final Color? tieColor;
  final Color? beamColor;
  final Color? accidentalColor;
  final Color? harmonicColor;
  final Color? textColor;

  // Cores for news elementos
  final Color? repeatColor;
  final Color? octaveColor;
  final Color? clusterColor;
  final Color? caesuraColor;
  final Color? metronomeColor;

  // Styles de text
  final TextStyle? textStyle;
  final TextStyle? dynamicTextStyle;
  final TextStyle? tupletTextStyle;
  final TextStyle? tempoTextStyle;
  final TextStyle? expressionTextStyle;
  final TextStyle? lyricTextStyle;
  final TextStyle? chordTextStyle;
  final TextStyle? rehearsalTextStyle;

  // News styles de text
  final TextStyle? repeatTextStyle;
  final TextStyle? octaveTextStyle;
  final TextStyle? metronomeTextStyle;

  // configurações de Rendering
  final double? defaultStaffSpace;
  final double? defaultFontSize;
  final bool showLedgerLines;

  /// Draw the measure number above the first measure of every system
  /// (Behind Bars: system-start numbering is the default convention).
  /// Measure 1 is never numbered.
  final bool showMeasureNumbers;

  /// Text style for measure numbers. Defaults to a small italic-free label
  /// sized from the staff space when null.
  final TextStyle? measureNumberTextStyle;
  final bool antiAlias;
  final double strokeWidth;

  /// Primary text face for every non-SMuFL string the engine draws — measure
  /// numbers, lyrics, tempo/expression marks, tuplet numerals, rehearsal marks,
  /// Gregorian syllables, Jianpu numerals.
  ///
  /// **Why you may need this.** The package ships no text face at all: its
  /// `pubspec.yaml` declares only the two music fonts (Bravura, Greciliae), and
  /// the built-in chain `kMusicTextFontFallback` names four faces
  /// (`Academico`, `Century Schoolbook`, `Edwin`, `serif`) that the HOST is
  /// expected to provide. Measured on 2.7.1: a score rasterised headlessly with
  /// only Bravura and Greciliae registered produced 16 solid `.notdef` boxes in
  /// the CMN path, and registering a real face literally named `serif` produced
  /// a byte-identical PNG — the terminal generic is not a resolution guarantee.
  /// Naming your own bundled face here is the supported fix.
  ///
  /// Setting the field is a DECLARATION; it does not install itself, because
  /// [MusicScoreTheme] has a `const` constructor and the headless export path
  /// never sees a widget tree. Call [installTextFont] once at startup (or
  /// `MusicTextFont.use(...)` directly).
  final String? textFontFamily;

  /// Package that declares [textFontFamily], for a face shipped by another
  /// package (the way `Bravura` is shipped by `flutter_notemus`). Null when the
  /// family is declared by the application's own `pubspec.yaml`.
  final String? textFontPackage;

  const MusicScoreTheme({
    // Cores básicas
    this.staffLineColor = Colors.black,
    this.noteheadColor = Colors.black,
    this.stemColor = Colors.black,
    this.clefColor = Colors.black,
    this.barlineColor = Colors.black,
    this.timeSignatureColor = Colors.black,
    this.keySignatureColor = Colors.black,
    this.restColor = Colors.black,
    this.articulationColor = Colors.black,

    // Cores avançadas (null = Use cor default)
    this.ornamentColor,
    this.dynamicColor,
    this.tupletColor,
    this.breathColor,
    this.slurColor,
    this.tieColor,
    this.beamColor,
    this.accidentalColor,
    this.harmonicColor,
    this.textColor,

    // Cores for news elementos
    this.repeatColor,
    this.octaveColor,
    this.clusterColor,
    this.caesuraColor,
    this.metronomeColor,

    // Styles de text
    this.textStyle,
    this.dynamicTextStyle,
    this.tupletTextStyle,
    this.tempoTextStyle,
    this.expressionTextStyle,
    this.lyricTextStyle,
    this.chordTextStyle,
    this.rehearsalTextStyle,

    // News styles de text
    this.repeatTextStyle,
    this.octaveTextStyle,
    this.metronomeTextStyle,

    // configurações
    this.defaultStaffSpace,
    this.defaultFontSize,
    this.showLedgerLines = true,
    this.showMeasureNumbers = true,
    this.measureNumberTextStyle,
    this.antiAlias = true,
    this.strokeWidth = 1.0,
    this.textFontFamily,
    this.textFontPackage,
  });

  /// Installs [textFontFamily] as the primary of the package-wide text chain.
  ///
  /// Process-global on purpose: `ScoreRasterizer`/`PdfExporter` render with no
  /// `Theme` ancestor and, when driven from a background isolate, no widget
  /// tree at all, so an inherited value could not reach them. Call once before
  /// the first render. Passing a theme whose [textFontFamily] is null CLEARS
  /// any previous injection, which is what makes this idempotent when an app
  /// swaps themes.
  void installTextFont() =>
      MusicTextFont.use(textFontFamily, package: textFontPackage);

  /// Creates a tema default
  factory MusicScoreTheme.standard() {
    return const MusicScoreTheme();
  }

  /// Creates a tema escuro
  factory MusicScoreTheme.dark() {
    const darkColor = Color(0xFFE0E0E0);
    return MusicScoreTheme(
      staffLineColor: darkColor,
      noteheadColor: darkColor,
      stemColor: darkColor,
      clefColor: darkColor,
      barlineColor: darkColor,
      timeSignatureColor: darkColor,
      keySignatureColor: darkColor,
      restColor: darkColor,
      articulationColor: darkColor,
      ornamentColor: darkColor,
      dynamicColor: darkColor,
      tupletColor: darkColor,
      breathColor: darkColor,
      slurColor: darkColor,
      tieColor: darkColor,
      beamColor: darkColor,
      accidentalColor: darkColor,
      harmonicColor: darkColor,
      textColor: darkColor,
      textStyle: const TextStyle(color: darkColor),
      dynamicTextStyle: const TextStyle(
        color: darkColor,
        fontStyle: FontStyle.italic,
        fontSize: 14,
      ),
      tupletTextStyle: const TextStyle(
        color: darkColor,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      tempoTextStyle: const TextStyle(
        color: darkColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Creates a tema colorido
  factory MusicScoreTheme.colorful() {
    return const MusicScoreTheme(
      staffLineColor: Colors.black,
      noteheadColor: Color(0xFF1976D2), // Azul
      stemColor: Color(0xFF1976D2),
      clefColor: Color(0xFF8E24AA), // Roxo
      barlineColor: Colors.black,
      timeSignatureColor: Color(0xFF00695C), // Verde escuro
      keySignatureColor: Color(0xFF00695C),
      restColor: Color(0xFF5D4037), // Marrom
      articulationColor: Color(0xFFD32F2F), // Vermelho
      ornamentColor: Color(0xFFFF8F00), // Laranja
      dynamicColor: Color(0xFF388E3C), // Verde
      tupletColor: Color(0xFF7B1FA2), // Roxo escuro
      breathColor: Color(0xFF455A64), // Azul acinzentado
      slurColor: Color(0xFF303F9F), // Azul escuro
      tieColor: Color(0xFF303F9F),
      beamColor: Color(0xFF1976D2),
      accidentalColor: Color(0xFFE64A19), // Laranja escuro
      harmonicColor: Color(0xFF00BCD4), // Ciano
    );
  }

  /// Creates a cópia of the tema with valores alterados
  MusicScoreTheme copyWith({
    Color? staffLineColor,
    Color? noteheadColor,
    Color? stemColor,
    Color? clefColor,
    Color? barlineColor,
    Color? timeSignatureColor,
    Color? keySignatureColor,
    Color? restColor,
    Color? articulationColor,
    Color? ornamentColor,
    Color? dynamicColor,
    Color? tupletColor,
    Color? breathColor,
    Color? slurColor,
    Color? tieColor,
    Color? beamColor,
    Color? accidentalColor,
    Color? harmonicColor,
    Color? textColor,
    TextStyle? textStyle,
    TextStyle? dynamicTextStyle,
    TextStyle? tupletTextStyle,
    TextStyle? tempoTextStyle,
    TextStyle? expressionTextStyle,
    TextStyle? lyricTextStyle,
    TextStyle? chordTextStyle,
    TextStyle? rehearsalTextStyle,
    double? defaultStaffSpace,
    double? defaultFontSize,
    bool? showLedgerLines,
    bool? showMeasureNumbers,
    TextStyle? measureNumberTextStyle,
    bool? antiAlias,
    double? strokeWidth,
    String? textFontFamily,
    String? textFontPackage,
  }) {
    return MusicScoreTheme(
      staffLineColor: staffLineColor ?? this.staffLineColor,
      noteheadColor: noteheadColor ?? this.noteheadColor,
      stemColor: stemColor ?? this.stemColor,
      clefColor: clefColor ?? this.clefColor,
      barlineColor: barlineColor ?? this.barlineColor,
      timeSignatureColor: timeSignatureColor ?? this.timeSignatureColor,
      keySignatureColor: keySignatureColor ?? this.keySignatureColor,
      restColor: restColor ?? this.restColor,
      articulationColor: articulationColor ?? this.articulationColor,
      ornamentColor: ornamentColor ?? this.ornamentColor,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      tupletColor: tupletColor ?? this.tupletColor,
      breathColor: breathColor ?? this.breathColor,
      slurColor: slurColor ?? this.slurColor,
      tieColor: tieColor ?? this.tieColor,
      beamColor: beamColor ?? this.beamColor,
      accidentalColor: accidentalColor ?? this.accidentalColor,
      harmonicColor: harmonicColor ?? this.harmonicColor,
      textColor: textColor ?? this.textColor,
      textStyle: textStyle ?? this.textStyle,
      dynamicTextStyle: dynamicTextStyle ?? this.dynamicTextStyle,
      tupletTextStyle: tupletTextStyle ?? this.tupletTextStyle,
      tempoTextStyle: tempoTextStyle ?? this.tempoTextStyle,
      expressionTextStyle: expressionTextStyle ?? this.expressionTextStyle,
      lyricTextStyle: lyricTextStyle ?? this.lyricTextStyle,
      chordTextStyle: chordTextStyle ?? this.chordTextStyle,
      rehearsalTextStyle: rehearsalTextStyle ?? this.rehearsalTextStyle,
      defaultStaffSpace: defaultStaffSpace ?? this.defaultStaffSpace,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      showLedgerLines: showLedgerLines ?? this.showLedgerLines,
      showMeasureNumbers: showMeasureNumbers ?? this.showMeasureNumbers,
      measureNumberTextStyle:
          measureNumberTextStyle ?? this.measureNumberTextStyle,
      antiAlias: antiAlias ?? this.antiAlias,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      textFontFamily: textFontFamily ?? this.textFontFamily,
      textFontPackage: textFontPackage ?? this.textFontPackage,
    );
  }
}
