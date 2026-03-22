// lib/src/smufl/smufl_coordinates.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/core.dart'; // 🆕 Tipos do core
import 'smufl_metadata_loader.dart';

/// Sistema de coordenadas SMuFL (Staff Music Font Layout)
///
/// O SMuFL define um sistema de coordenadas baseado em unidades de staff space.
/// 1 staff space = distância entre duas linhas do pentagrama
/// Valores em metadata SMuFL são expressos em staff spaces (1.0 = 1 staff space)
/// CORREÇÃO: Metadados SMuFL usam staff spaces diretos, não 1/4 de staff space
class SmuflCoordinates {
  /// Converte unidades SMuFL para pixels
  /// @param smuflUnits Valor em unidades SMuFL (staff spaces)
  /// @param staffSpace Tamanho do staff space em pixels
  static double smuflToPixels(double smuflUnits, double staffSpace) {
    return smuflUnits * staffSpace;
  }

  /// Converte pixels para unidades SMuFL
  /// @param pixels Valor em pixels
  /// @param staffSpace Tamanho do staff space em pixels
  static double pixelsToSmufl(double pixels, double staffSpace) {
    return pixels / staffSpace;
  }

  /// Calcula o staff space baseado na fonte
  /// @param fontSize Tamanho da fonte em pixels
  static double getStaffSpaceFromFontSize(double fontSize) {
    // CORREÇÃO: Para fontes SMuFL como Bravura, o staff space é 1/4 do tamanho da fonte
    // Esta relação é definida na especificação SMuFL
    return fontSize / 4.0;
  }

  /// Valores oficiais do metadata Bravura conforme especificação SMuFL
  /// Estes valores devem ser obtidos do metadata, mas fornecemos defaults seguros

  /// Calcula a espessura de uma linha do pentagrama
  /// @param staffSpace Tamanho do staff space
  static double getStaffLineThickness(double staffSpace) {
    // Valor oficial Bravura: staffLineThickness = 0.13 staff spaces
    return staffSpace * 0.13;
  }

  /// Calcula a espessura de uma haste
  /// @param staffSpace Tamanho do staff space
  static double getStemThickness(double staffSpace) {
    // Valor oficial Bravura: stemThickness = 0.12 staff spaces
    return staffSpace * 0.12;
  }

  /// Calcula a altura padrão de uma haste
  /// @param staffSpace Tamanho do staff space
  static double getStemHeight(double staffSpace) {
    // Valor oficial SMuFL: stemLength = 3.5 staff spaces
    return staffSpace * 3.5;
  }

  /// Calcula a espessura das linhas suplementares
  /// @param staffSpace Tamanho do staff space
  static double getLedgerLineThickness(double staffSpace) {
    // Valor oficial Bravura: legerLineThickness = 0.16 staff spaces
    return staffSpace * 0.16;
  }

  /// Calcula a extensão das linhas suplementares além da nota
  /// @param staffSpace Tamanho do staff space
  static double getLedgerLineExtension(double staffSpace) {
    // Valor oficial Bravura: legerLineExtension = 0.4 staff spaces
    return staffSpace * 0.4;
  }

  /// Calcula a espessura das barras de compasso
  /// @param staffSpace Tamanho do staff space
  static double getBarlineThickness(double staffSpace) {
    // Valor oficial Bravura: thinBarlineThickness = 0.16 staff spaces
    return staffSpace * 0.16;
  }

  /// Calcula a espessura das barras grossas
  /// @param staffSpace Tamanho do staff space
  static double getThickBarlineThickness(double staffSpace) {
    // Valor oficial Bravura: thickBarlineThickness = 0.5 staff spaces
    return staffSpace * 0.5;
  }
}

/// Classe para gerenciar bounding boxes de glifos
class GlyphBoundingBox {
  final double bBoxNeX; // Nordeste X
  final double bBoxNeY; // Nordeste Y
  final double bBoxSwX; // Sudoeste X
  final double bBoxSwY; // Sudoeste Y

  const GlyphBoundingBox({
    required this.bBoxNeX,
    required this.bBoxNeY,
    required this.bBoxSwX,
    required this.bBoxSwY,
  });

  /// Cria um bounding box a partir dos dados de metadata SMuFL
  factory GlyphBoundingBox.fromMetadata(Map<String, dynamic> bboxData) {
    final bBoxNE = bboxData['bBoxNE'] as List<dynamic>?;
    final bBoxSW = bboxData['bBoxSW'] as List<dynamic>?;

    return GlyphBoundingBox(
      bBoxNeX: (bBoxNE?[0] as num?)?.toDouble() ?? 0.0,
      bBoxNeY: (bBoxNE?[1] as num?)?.toDouble() ?? 0.0,
      bBoxSwX: (bBoxSW?[0] as num?)?.toDouble() ?? 0.0,
      bBoxSwY: (bBoxSW?[1] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Largura do glifo em unidades SMuFL
  double get width => bBoxNeX - bBoxSwX;

  /// Altura do glifo em unidades SMuFL
  double get height => bBoxNeY - bBoxSwY;

  /// Largura em pixels
  double widthInPixels(double staffSpace) {
    return SmuflCoordinates.smuflToPixels(width, staffSpace);
  }

  /// Altura em pixels
  double heightInPixels(double staffSpace) {
    return SmuflCoordinates.smuflToPixels(height, staffSpace);
  }

  /// Centro X do glifo
  double get centerX => (bBoxNeX + bBoxSwX) / 2;

  /// Centro Y do glifo
  double get centerY => (bBoxNeY + bBoxSwY) / 2;
}

/// Pontos de ancoragem para posicionamento preciso de glifos
class GlyphAnchors {
  final Map<String, Offset> anchors;

  GlyphAnchors(this.anchors);

  /// Cria anchors a partir dos dados de metadata SMuFL
  factory GlyphAnchors.fromMetadata(Map<String, dynamic>? anchorsData) {
    final anchors = <String, Offset>{};

    if (anchorsData != null) {
      for (final entry in anchorsData.entries) {
        final coords = entry.value as List<dynamic>?;
        if (coords != null && coords.length >= 2) {
          anchors[entry.key] = Offset(
            (coords[0] as num).toDouble(),
            (coords[1] as num).toDouble(),
          );
        }
      }
    }

    return GlyphAnchors(anchors);
  }

  /// Obtém um ponto de ancoragem específico
  Offset? getAnchor(String anchorName) => anchors[anchorName];

  /// Converte um anchor para pixels
  Offset? getAnchorInPixels(String anchorName, double staffSpace) {
    final anchor = getAnchor(anchorName);
    if (anchor == null) return null;

    return Offset(
      SmuflCoordinates.smuflToPixels(anchor.dx, staffSpace),
      SmuflCoordinates.smuflToPixels(anchor.dy, staffSpace),
    );
  }

  /// Anchors comuns para diferentes tipos de glifos
  static const Map<String, List<String>> commonAnchors = {
    'noteheads': ['stemUpSE', 'stemDownNW', 'opticalCenter'],
    'clefs': ['opticalCenter'],
    'accidentals': ['opticalCenter'],
    'articulations': ['opticalCenter'],
    'dynamics': ['opticalCenter'],
    'ornaments': ['opticalCenter'],
  };
}

/// Classe para informações completas de um glifo SMuFL
class SmuflGlyphInfo {
  final String name;
  final String codepoint;
  final String description;
  final GlyphBoundingBox? boundingBox;
  final GlyphAnchors? anchors;

  const SmuflGlyphInfo({
    required this.name,
    required this.codepoint,
    required this.description,
    this.boundingBox,
    this.anchors,
  });

  /// Verifica se o glifo tem informações de bounding box
  bool get hasBoundingBox => boundingBox != null;

  /// Verifica se o glifo tem pontos de ancoragem
  bool get hasAnchors => anchors != null && anchors!.anchors.isNotEmpty;
}

/// Utilitários para posicionamento baseado em SMuFL
class SmuflPositioning {
  /// Calcula a posição vertical de uma nota no pentagrama
  /// @param staffPosition Posição na pauta (0 = linha central)
  /// @param staffSpace Tamanho do staff space
  static double noteYPosition(int staffPosition, double staffSpace) {
    return -staffPosition * (staffSpace / 2);
  }

  /// Calcula se uma nota precisa de linhas suplementares
  /// @param staffPosition Posição na pauta
  static bool needsLedgerLines(int staffPosition) {
    return staffPosition.abs() > 4; // Fora das 5 linhas do pentagrama
  }

  /// Calcula as posições das linhas suplementares necessárias
  /// @param staffPosition Posição da nota
  static List<int> getLedgerLinePositions(int staffPosition) {
    final lines = <int>[];

    if (staffPosition > 4) {
      // Linhas acima do pentagrama
      for (int line = 6; line <= staffPosition; line += 2) {
        lines.add(line);
      }
    } else if (staffPosition < -4) {
      // Linhas abaixo do pentagrama
      for (int line = -6; line >= staffPosition; line -= 2) {
        lines.add(line);
      }
    }

    return lines;
  }

  /// Calcula o espaçamento horizontal entre elementos
  /// @param elementType Tipo de elemento musical
  /// @param staffSpace Tamanho do staff space
  static double getElementSpacing(String elementType, double staffSpace) {
    const spacingRatios = {
      'clef': 1.5,
      'keySignature': 0.8,
      'timeSignature': 1.0,
      'note': 1.0,
      'rest': 1.0,
      'barline': 0.5,
    };

    final ratio = spacingRatios[elementType] ?? 1.0;
    return staffSpace * ratio;
  }

  /// Calcula a rotação necessária para um glifo
  /// @param angle Ângulo em graus
  static Matrix4 getRotationMatrix(double angle) {
    final radians = angle * (math.pi / 180);
    return Matrix4.identity()..rotateZ(radians);
  }

  /// Calcula a escala necessária para um glifo
  /// @param scaleX Escala horizontal
  /// @param scaleY Escala vertical
  static Matrix4 getScaleMatrix(double scaleX, double scaleY) {
    return Matrix4.identity()..scale(scaleX, scaleY);
  }
}

/// Classe para posicionamento avançado baseado nos metadados SMuFL
class SmuflAdvancedCoordinates {
  final double staffSpace;
  final SmuflMetadata metadata;

  SmuflAdvancedCoordinates({required this.staffSpace, required this.metadata});

  /// Retorna a posição Y para ornamentos baseado em âncoras SMuFL
  double getOrnamentY(
    String noteGlyph,
    String ornamentGlyph,
    double baseY,
    bool above,
  ) {
    // Usar anchors do metadata para posicionamento preciso
    final anchors = metadata.getGlyphAnchors(noteGlyph);

    if (above) {
      // Posição acima da nota usando âncora "above" se disponível
      if (anchors != null) {
        final anchor = anchors.getAnchor('above');
        if (anchor != null) {
          return baseY + (anchor.dy * staffSpace) - (staffSpace * 0.5);
        }
      }
      // Posição padrão acima
      return baseY - (staffSpace * 2.5);
    } else {
      // Posição abaixo da nota usando âncora "below" se disponível
      if (anchors != null) {
        final anchor = anchors.getAnchor('below');
        if (anchor != null) {
          return baseY + (anchor.dy * staffSpace) + (staffSpace * 0.5);
        }
      }
      // Posição padrão abaixo
      return baseY + (staffSpace * 2.5);
    }
  }

  /// Retorna a posição Y para dinâmicas baseado em âncoras SMuFL
  double getDynamicY(String noteGlyph, double baseY) {
    // Dinâmicas sempre ficam abaixo da pauta
    final anchors = metadata.getGlyphAnchors(noteGlyph);

    if (anchors != null) {
      final anchor = anchors.getAnchor('below');
      if (anchor != null) {
        return baseY + (anchor.dy * staffSpace) + (staffSpace * 3.0);
      }
    }

    // Posição padrão para dinâmicas (abaixo da pauta)
    return baseY + (staffSpace * 4.0);
  }

  /// Retorna a posição para articulações baseado em âncoras SMuFL
  double getArticulationY(
    String noteGlyph,
    String articulationGlyph,
    double baseY,
    bool above,
  ) {
    final anchors = metadata.getGlyphAnchors(noteGlyph);

    if (above) {
      if (anchors != null) {
        final anchor = anchors.getAnchor('above');
        if (anchor != null) {
          return baseY + (anchor.dy * staffSpace) - (staffSpace * 1.0);
        }
      }
      return baseY - (staffSpace * 1.5);
    } else {
      if (anchors != null) {
        final anchor = anchors.getAnchor('below');
        if (anchor != null) {
          return baseY + (anchor.dy * staffSpace) + (staffSpace * 1.0);
        }
      }
      return baseY + (staffSpace * 1.5);
    }
  }

  /// Retorna a altura da beam baseado na duração
  double getBeamHeight(DurationType durationType) {
    switch (durationType) {
      case DurationType.eighth:
        return staffSpace * 0.5;
      case DurationType.sixteenth:
        return staffSpace * 0.6;
      case DurationType.thirtySecond:
        return staffSpace * 0.7;
      case DurationType.sixtyFourth:
        return staffSpace * 0.8;
      default:
        return staffSpace * 0.5;
    }
  }

  /// Calcula posições para beam groups seguindo regras musicais
  List<double> calculateBeamPositions(
    List<double> notePositionsY,
    bool stemUp,
  ) {
    if (notePositionsY.isEmpty) return [];

    // Calcular inclinação baseada na diferença de altura
    final firstY = notePositionsY.first;
    final lastY = notePositionsY.last;
    final slope = stemUp
        ? (lastY - firstY) * 0.3
        : // Beam sobe suavemente
          (lastY - firstY) * 0.3; // Beam desce suavemente

    // Gerar posições interpoladas
    final positions = <double>[];
    for (int i = 0; i < notePositionsY.length; i++) {
      final ratio = notePositionsY.length > 1
          ? i / (notePositionsY.length - 1)
          : 0.0;
      final beamY = firstY + (slope * ratio);
      positions.add(beamY);
    }

    return positions;
  }
}

/// Classe para posicionamento preciso baseado em anchors SMuFL
class SmuflGlyphPositioner {
  final SmuflMetadata metadata;
  final double staffSpace;

  SmuflGlyphPositioner({required this.metadata, required this.staffSpace});

  /// Calcula a posição precisa de uma haste usando anchors SMuFL
  Offset getStemPosition(
    String noteheadGlyph,
    bool stemUp,
    Offset notePosition,
  ) {
    final anchors = metadata.getGlyphAnchors(noteheadGlyph);
    if (anchors == null) {
      // Fallback para posicionamento tradicional se não há anchors
      return _getFallbackStemPosition(notePosition, stemUp);
    }

    // Usar anchors oficiais SMuFL
    final anchorName = stemUp ? 'stemUpSE' : 'stemDownNW';
    final anchor = anchors.getAnchor(anchorName);

    if (anchor != null) {
      // Converter anchor para pixels e aplicar à posição da nota
      final anchorPixels = anchor.toPixels(staffSpace);
      return Offset(
        notePosition.dx + anchorPixels.dx,
        notePosition.dy + anchorPixels.dy,
      );
    }

    return _getFallbackStemPosition(notePosition, stemUp);
  }

  /// Posicionamento de fallback quando não há anchors
  Offset _getFallbackStemPosition(Offset notePosition, bool stemUp) {
    // Usar largura padrão estimada da cabeça de nota
    final noteWidth = staffSpace * 1.18;
    final halfNoteWidth = noteWidth * 0.5;
    final stemThickness = SmuflCoordinates.getStemThickness(staffSpace);

    final stemX = stemUp
        ? notePosition.dx + halfNoteWidth - (stemThickness * 0.5)
        : notePosition.dx - halfNoteWidth + (stemThickness * 0.5);

    return Offset(stemX, notePosition.dy);
  }

  /// Calcula a posição de um acidente usando anchors SMuFL
  Offset getAccidentalPosition(
    String noteheadGlyph,
    String accidentalGlyph,
    Offset notePosition,
  ) {
    // final noteAnchors = metadata.getGlyphAnchors(noteheadGlyph);
    final accidentalBBox = metadata.getGlyphBoundingBox(accidentalGlyph);

    // Posição padrão: à esquerda da nota com espaçamento adequado
    double accidentalX = notePosition.dx;

    if (accidentalBBox != null) {
      // Usar largura real do acidente
      final accidentalWidth = accidentalBBox.widthInPixels(staffSpace);
      final spacing = staffSpace * 0.2; // Espaçamento mínimo
      accidentalX -= accidentalWidth + spacing;
    } else {
      // Fallback
      accidentalX -= staffSpace * 1.0;
    }

    return Offset(accidentalX, notePosition.dy);
  }

  /// Calcula a posição de ornamentos usando anchors SMuFL
  Offset getOrnamentPosition(
    String noteheadGlyph,
    String ornamentGlyph,
    Offset notePosition,
    bool above,
  ) {
    final noteAnchors = metadata.getGlyphAnchors(noteheadGlyph);

    if (noteAnchors != null) {
      final anchorName = above ? 'above' : 'below';
      final anchor = noteAnchors.getAnchor(anchorName);

      if (anchor != null) {
        final anchorPixels = anchor.toPixels(staffSpace);
        return Offset(
          notePosition.dx + anchorPixels.dx,
          notePosition.dy + anchorPixels.dy,
        );
      }
    }

    // Fallback para posicionamento tradicional
    final offset = above ? -staffSpace * 2.0 : staffSpace * 2.0;
    return Offset(notePosition.dx, notePosition.dy + offset);
  }

  /// Calcula a posição de articulações usando anchors SMuFL
  Offset getArticulationPosition(
    String noteheadGlyph,
    String articulationGlyph,
    Offset notePosition,
    bool above,
  ) {
    final noteAnchors = metadata.getGlyphAnchors(noteheadGlyph);

    if (noteAnchors != null) {
      final anchorName = above ? 'above' : 'below';
      final anchor = noteAnchors.getAnchor(anchorName);

      if (anchor != null) {
        final anchorPixels = anchor.toPixels(staffSpace);
        final spacing = above ? -staffSpace * 0.5 : staffSpace * 0.5;
        return Offset(
          notePosition.dx + anchorPixels.dx,
          notePosition.dy + anchorPixels.dy + spacing,
        );
      }
    }

    // Fallback para posicionamento tradicional
    final offset = above ? -staffSpace * 1.5 : staffSpace * 1.5;
    return Offset(notePosition.dx, notePosition.dy + offset);
  }

  /// Calcula a posição central óptica de um glifo
  Offset getOpticalCenter(String glyphName, Offset basePosition) {
    final anchors = metadata.getGlyphAnchors(glyphName);

    if (anchors != null) {
      final opticalCenter = anchors.getAnchor('opticalCenter');
      if (opticalCenter != null) {
        final centerPixels = opticalCenter.toPixels(staffSpace);
        return Offset(
          basePosition.dx + centerPixels.dx,
          basePosition.dy + centerPixels.dy,
        );
      }
    }

    // Se não há center óptico, usar o centro geométrico
    final boundingBox = metadata.getGlyphBoundingBox(glyphName);
    if (boundingBox != null) {
      final centerX = SmuflCoordinates.smuflToPixels(
        boundingBox.centerX,
        staffSpace,
      );
      final centerY = SmuflCoordinates.smuflToPixels(
        boundingBox.centerY,
        staffSpace,
      );
      return Offset(basePosition.dx + centerX, basePosition.dy + centerY);
    }

    return basePosition;
  }
}

/// Extensão para facilitar conversões
extension OffsetSmuflExtension on Offset {
  /// Converte um Offset de unidades SMuFL para pixels
  Offset toPixels(double staffSpace) {
    return Offset(
      SmuflCoordinates.smuflToPixels(dx, staffSpace),
      SmuflCoordinates.smuflToPixels(dy, staffSpace),
    );
  }

  /// Converte um Offset de pixels para unidades SMuFL
  Offset toSmufl(double staffSpace) {
    return Offset(
      SmuflCoordinates.pixelsToSmufl(dx, staffSpace),
      SmuflCoordinates.pixelsToSmufl(dy, staffSpace),
    );
  }
}
