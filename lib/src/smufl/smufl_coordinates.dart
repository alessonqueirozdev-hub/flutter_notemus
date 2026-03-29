// lib/src/smufl/smufl_coordinates.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/core.dart'; // 🆕 Tipos do core
import 'smufl_metadata_loader.dart';

/// Coordinate system SMuFL (Staff Music Font Layout)
///
/// O SMuFL Definess um coordinate system based on unidades de staff space.
/// 1 staff space = distância entre duas linhas of the staff
/// Valores in metadata SMuFL are expressos in staff spaces (1.0 = 1 staff space)
/// Fix: Metadados SMuFL usam staff spaces diretos, not 1/4 de staff space
class SmuflCoordinates {
  /// Converts unidades SMuFL for pixels
  /// @param smuflUnits Value in SMuFL units (staff spaces)
  /// @param staffSpace Staff space size in pixels
  static double smuflToPixels(double smuflUnits, double staffSpace) {
    return smuflUnits * staffSpace;
  }

  /// Converts pixels for unidades SMuFL
  /// @param pixels Value in pixels
  /// @param staffSpace Staff space size in pixels
  static double pixelsToSmufl(double pixels, double staffSpace) {
    return pixels / staffSpace;
  }

  /// Calculatestes o staff space based na fonte
  /// @param fontSize Size of the fonte in pixels
  static double getStaffSpaceFromFontSize(double fontSize) {
    // Fix: For fontes SMuFL como Bravura, o staff space é 1/4 of the Size of the fonte
    // This relação é definida na especificação SMuFL
    return fontSize / 4.0;
  }

  /// Valores oficiais of the metadata Bravura according to especificação SMuFL
  /// Estes valores devem ser obtidos of the metadata, mas fornecemos defaults seguros

  /// Calculatestes a espessura de a linha of the staff
  /// @param staffSpace Staff space size
  static double getStaffLineThickness(double staffSpace) {
    // Value oficial Bravura: staffLineThickness = 0.13 staff spaces
    return staffSpace * 0.13;
  }

  /// Calculatestes a espessura de a stem
  /// @param staffSpace Staff space size
  static double getStemThickness(double staffSpace) {
    // Value oficial Bravura: stemThickness = 0.12 staff spaces
    return staffSpace * 0.12;
  }

  /// Calculatestes a height default de a stem
  /// @param staffSpace Staff space size
  static double getStemHeight(double staffSpace) {
    // Value oficial SMuFL: stemLength = 3.5 staff spaces
    return staffSpace * 3.5;
  }

  /// Calculatestes a espessura das linhas suplementares
  /// @param staffSpace Staff space size
  static double getLedgerLineThickness(double staffSpace) {
    // Value oficial Bravura: legerLineThickness = 0.16 staff spaces
    return staffSpace * 0.16;
  }

  /// Calculatestes a extensão das linhas suplementares além of the note
  /// @param staffSpace Staff space size
  static double getLedgerLineExtension(double staffSpace) {
    // Value oficial Bravura: legerLineExtension = 0.4 staff spaces
    return staffSpace * 0.4;
  }

  /// Calculatestes a espessura das barlines
  /// @param staffSpace Staff space size
  static double getBarlineThickness(double staffSpace) {
    // Value oficial Bravura: thinBarlineThickness = 0.16 staff spaces
    return staffSpace * 0.16;
  }

  /// Calculatestes a espessura das barras grossas
  /// @param staffSpace Staff space size
  static double getThickBarlineThickness(double staffSpace) {
    // Value oficial Bravura: thickBarlineThickness = 0.5 staff spaces
    return staffSpace * 0.5;
  }
}

/// Class for gerenciar bounding boxes de glifos
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

  /// Creates um bounding box a partir dos dados de metadata SMuFL
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

  /// Width of the glifo in SMuFL units
  double get width => bBoxNeX - bBoxSwX;

  /// Height of the glifo in SMuFL units
  double get height => bBoxNeY - bBoxSwY;

  /// Width in pixels
  double widthInPixels(double staffSpace) {
    return SmuflCoordinates.smuflToPixels(width, staffSpace);
  }

  /// Height in pixels
  double heightInPixels(double staffSpace) {
    return SmuflCoordinates.smuflToPixels(height, staffSpace);
  }

  /// Centro X of the glifo
  double get centerX => (bBoxNeX + bBoxSwX) / 2;

  /// Centro Y of the glifo
  double get centerY => (bBoxNeY + bBoxSwY) / 2;
}

/// Anchor points for posicionamento preciso de glifos
class GlyphAnchors {
  final Map<String, Offset> anchors;

  GlyphAnchors(this.anchors);

  /// Creates anchors a partir dos dados de metadata SMuFL
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

  /// Gets um anchor point específico
  Offset? getAnchor(String anchorName) => anchors[anchorName];

  /// Converts um anchor for pixels
  Offset? getAnchorInPixels(String anchorName, double staffSpace) {
    final anchor = getAnchor(anchorName);
    if (anchor == null) return null;

    return Offset(
      SmuflCoordinates.smuflToPixels(anchor.dx, staffSpace),
      SmuflCoordinates.smuflToPixels(anchor.dy, staffSpace),
    );
  }

  /// Anchors comuns for diferentes tipos de glifos
  static const Map<String, List<String>> commonAnchors = {
    'noteheads': ['stemUpSE', 'stemDownNW', 'opticalCenter'],
    'clefs': ['opticalCenter'],
    'accidentals': ['opticalCenter'],
    'articulations': ['opticalCenter'],
    'dynamics': ['opticalCenter'],
    'ornaments': ['opticalCenter'],
  };
}

/// Class for informações completas de um glifo SMuFL
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

  /// Checks se o glifo tem informações de bounding box
  bool get hasBoundingBox => boundingBox != null;

  /// Checks se o glifo tem anchor points
  bool get hasAnchors => anchors != null && anchors!.anchors.isNotEmpty;
}

/// Utilitários for posicionamento based on SMuFL
class SmuflPositioning {
  /// Calculatestes a position vertical de a note no staff
  /// @param staffPosition Staff position (0 = linha central)
  /// @param staffSpace Staff space size
  static double noteYPosition(int staffPosition, double staffSpace) {
    return -staffPosition * (staffSpace / 2);
  }

  /// Calculatestes se a note precisa de linhas suplementares
  /// @param staffPosition Staff position
  static bool needsLedgerLines(int staffPosition) {
    return staffPosition.abs() > 4; // Fora das 5 linhas do pentagrama
  }

  /// Calculatestes as positions das linhas suplementares necessárias
  /// @param staffPosition Position of the note
  static List<int> getLedgerLinePositions(int staffPosition) {
    final lines = <int>[];

    if (staffPosition > 4) {
      // Linhas acima of the staff
      for (int line = 6; line <= staffPosition; line += 2) {
        lines.add(line);
      }
    } else if (staffPosition < -4) {
      // Linhas abaixo of the staff
      for (int line = -6; line >= staffPosition; line -= 2) {
        lines.add(line);
      }
    }

    return lines;
  }

  /// Calculatestes o spacing horizontal entre elementos
  /// @param elementType Type de elemento musical
  /// @param staffSpace Staff space size
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

  /// Calculatestes a rotação necessária for um glifo
  /// @param angle Ângulo in graus
  static Matrix4 getRotationMatrix(double angle) {
    final radians = angle * (math.pi / 180);
    return Matrix4.identity()..rotateZ(radians);
  }

  /// Calculatestes a escala necessária for um glifo
  /// @param scaleX Escala horizontal
  /// @param scaleY Escala vertical
  static Matrix4 getScaleMatrix(double scaleX, double scaleY) {
    return Matrix4.diagonal3Values(scaleX, scaleY, 1.0);
  }
}

/// Class for posicionamento avançado based nos SMuFL metadata
class SmuflAdvancedCoordinates {
  final double staffSpace;
  final SmuflMetadata metadata;

  SmuflAdvancedCoordinates({required this.staffSpace, required this.metadata});

  /// Returns a Y position for ornaments based on âncoras SMuFL
  double getOrnamentY(
    String noteGlyph,
    String ornamentGlyph,
    double baseY,
    bool above,
  ) {
    // Usesr anchors of the metadata for posicionamento preciso
    final anchors = metadata.getGlyphAnchors(noteGlyph);

    if (above) {
      // Position acima of the note using âncora "above" se disponível
      if (anchors != null) {
        final anchor = anchors.getAnchor('above');
        if (anchor != null) {
          return baseY + (anchor.dy * staffSpace) - (staffSpace * 0.5);
        }
      }
      // Position default acima
      return baseY - (staffSpace * 2.5);
    } else {
      // Position abaixo of the note using âncora "below" se disponível
      if (anchors != null) {
        final anchor = anchors.getAnchor('below');
        if (anchor != null) {
          return baseY + (anchor.dy * staffSpace) + (staffSpace * 0.5);
        }
      }
      // Position default abaixo
      return baseY + (staffSpace * 2.5);
    }
  }

  /// Returns a Y position for dynamics based on âncoras SMuFL
  double getDynamicY(String noteGlyph, double baseY) {
    // Dynamics always ficam abaixo of the staff
    final anchors = metadata.getGlyphAnchors(noteGlyph);

    if (anchors != null) {
      final anchor = anchors.getAnchor('below');
      if (anchor != null) {
        return baseY + (anchor.dy * staffSpace) + (staffSpace * 3.0);
      }
    }

    // Position default for dynamics (abaixo of the staff)
    return baseY + (staffSpace * 4.0);
  }

  /// Returns a position for articulations based on âncoras SMuFL
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

  /// Returns a height of the beam based na duração
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

  /// Calculatestes positions for beam groups following regras musicais
  List<double> calculateBeamPositions(
    List<double> notePositionsY,
    bool stemUp,
  ) {
    if (notePositionsY.isEmpty) return [];

    // Calculatestesr inclinação baseada na diferença de height
    final firstY = notePositionsY.first;
    final lastY = notePositionsY.last;
    final slope = stemUp
        ? (lastY - firstY) * 0.3
        : // Beam sobe suavemente
          (lastY - firstY) * 0.3; // Beam desce suavemente

    // Generatesr positions interpoladas
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

/// Class for posicionamento preciso based on anchors SMuFL
class SmuflGlyphPositioner {
  final SmuflMetadata metadata;
  final double staffSpace;

  SmuflGlyphPositioner({required this.metadata, required this.staffSpace});

  /// Calculatestes a position precisa de a stem using anchors SMuFL
  Offset getStemPosition(
    String noteheadGlyph,
    bool stemUp,
    Offset notePosition,
  ) {
    final anchors = metadata.getGlyphAnchors(noteheadGlyph);
    if (anchors == null) {
      // Fallback for posicionamento tradded se not há anchors
      return _getFallbackStemPosition(notePosition, stemUp);
    }

    // Usesr anchors oficiais SMuFL
    final anchorName = stemUp ? 'stemUpSE' : 'stemDownNW';
    final anchor = anchors.getAnchor(anchorName);

    if (anchor != null) {
      // Convertsr anchor for pixels e Appliesr à position of the note
      final anchorPixels = anchor.toPixels(staffSpace);
      return Offset(
        notePosition.dx + anchorPixels.dx,
        notePosition.dy + anchorPixels.dy,
      );
    }

    return _getFallbackStemPosition(notePosition, stemUp);
  }

  /// Posicionamento de fallback when not há anchors
  Offset _getFallbackStemPosition(Offset notePosition, bool stemUp) {
    // Usesr width default estimada of the notehead
    final noteWidth = staffSpace * 1.18;
    final halfNoteWidth = noteWidth * 0.5;
    final stemThickness = SmuflCoordinates.getStemThickness(staffSpace);

    final stemX = stemUp
        ? notePosition.dx + halfNoteWidth - (stemThickness * 0.5)
        : notePosition.dx - halfNoteWidth + (stemThickness * 0.5);

    return Offset(stemX, notePosition.dy);
  }

  /// Calculatestes a position de um accidental using anchors SMuFL
  Offset getAccidentalPosition(
    String noteheadGlyph,
    String accidentalGlyph,
    Offset notePosition,
  ) {
    // final noteAnchors = metadata.getGlyphAnchors(noteheadGlyph);
    final accidentalBBox = metadata.getGlyphBoundingBox(accidentalGlyph);

    // Position default: à esquerda of the note with spacing adequado
    double accidentalX = notePosition.dx;

    if (accidentalBBox != null) {
      // Usesr width real of the accidental
      final accidentalWidth = accidentalBBox.widthInPixels(staffSpace);
      final spacing = staffSpace * 0.2; // Espaçamento mínimo
      accidentalX -= accidentalWidth + spacing;
    } else {
      // Fallback
      accidentalX -= staffSpace * 1.0;
    }

    return Offset(accidentalX, notePosition.dy);
  }

  /// Calculatestes a position de ornaments using anchors SMuFL
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

    // Fallback for posicionamento tradded
    final offset = above ? -staffSpace * 2.0 : staffSpace * 2.0;
    return Offset(notePosition.dx, notePosition.dy + offset);
  }

  /// Calculatestes a position de articulations using anchors SMuFL
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

    // Fallback for posicionamento tradded
    final offset = above ? -staffSpace * 1.5 : staffSpace * 1.5;
    return Offset(notePosition.dx, notePosition.dy + offset);
  }

  /// Calculatestes a position central óptica de um glifo
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

    // Se not há center óptico, Usesr o centro geométrico
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

/// Extensão for facilitar conversões
extension OffsetSmuflExtension on Offset {
  /// Converts um Offset de unidades SMuFL for pixels
  Offset toPixels(double staffSpace) {
    return Offset(
      SmuflCoordinates.smuflToPixels(dx, staffSpace),
      SmuflCoordinates.smuflToPixels(dy, staffSpace),
    );
  }

  /// Converts um Offset de pixels for unidades SMuFL
  Offset toSmufl(double staffSpace) {
    return Offset(
      SmuflCoordinates.pixelsToSmufl(dx, staffSpace),
      SmuflCoordinates.pixelsToSmufl(dy, staffSpace),
    );
  }
}
