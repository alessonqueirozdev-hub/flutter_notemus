// lib/src/theme/music_score_theme.dart
import 'package:flutter/material.dart';

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

  // Cores para elementos avançados
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

  // Cores para novos elementos
  final Color? repeatColor;
  final Color? octaveColor;
  final Color? clusterColor;
  final Color? caesuraColor;
  final Color? metronomeColor;

  // Estilos de texto
  final TextStyle? textStyle;
  final TextStyle? dynamicTextStyle;
  final TextStyle? tupletTextStyle;
  final TextStyle? tempoTextStyle;
  final TextStyle? expressionTextStyle;
  final TextStyle? lyricTextStyle;
  final TextStyle? chordTextStyle;
  final TextStyle? rehearsalTextStyle;

  // Novos estilos de texto
  final TextStyle? repeatTextStyle;
  final TextStyle? octaveTextStyle;
  final TextStyle? metronomeTextStyle;

  // Configurações de renderização
  final double? defaultStaffSpace;
  final double? defaultFontSize;
  final bool showLedgerLines;
  final bool antiAlias;
  final double strokeWidth;

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

    // Cores avançadas (null = usar cor padrão)
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

    // Cores para novos elementos
    this.repeatColor,
    this.octaveColor,
    this.clusterColor,
    this.caesuraColor,
    this.metronomeColor,

    // Estilos de texto
    this.textStyle,
    this.dynamicTextStyle,
    this.tupletTextStyle,
    this.tempoTextStyle,
    this.expressionTextStyle,
    this.lyricTextStyle,
    this.chordTextStyle,
    this.rehearsalTextStyle,

    // Novos estilos de texto
    this.repeatTextStyle,
    this.octaveTextStyle,
    this.metronomeTextStyle,

    // Configurações
    this.defaultStaffSpace,
    this.defaultFontSize,
    this.showLedgerLines = true,
    this.antiAlias = true,
    this.strokeWidth = 1.0,
  });

  /// Cria um tema padrão
  factory MusicScoreTheme.standard() {
    return const MusicScoreTheme();
  }

  /// Cria um tema escuro
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

  /// Cria um tema colorido
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

  /// Cria uma cópia do tema com valores alterados
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
    bool? antiAlias,
    double? strokeWidth,
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
      antiAlias: antiAlias ?? this.antiAlias,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }
}
