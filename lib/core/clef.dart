// lib/core/clef.dart

import 'musical_element.dart';

/// Tipos de claves musicais disponíveis
enum ClefType {
  /// Clave de Sol (G clef)
  treble,
  /// Clave de Sol 8ª acima
  treble8va,
  /// Clave de Sol 8ª abaixo
  treble8vb,
  /// Clave de Sol 15ª acima
  treble15ma,
  /// Clave de Sol 15ª abaixo
  treble15mb,
  /// Clave de Fá (F clef) - 4ª linha (posição padrão)
  bass,
  /// Clave de Fá na 3ª linha
  bassThirdLine,
  /// Clave de Fá 8ª acima
  bass8va,
  /// Clave de Fá 8ª abaixo
  bass8vb,
  /// Clave de Fá 15ª acima
  bass15ma,
  /// Clave de Fá 15ª abaixo
  bass15mb,

  /// Clave de Dó na 1ª linha (soprano)
  soprano,
  /// Clave de Dó na 2ª linha (mezzo-soprano)
  mezzoSoprano,
  /// Clave de Dó na 3ª linha (alto/viola)
  alto,
  /// Clave de Dó na 4ª linha (tenor)
  tenor,
  /// Clave de Dó na 5ª linha (baritono - histórico)
  baritone,
  /// Clave de Dó 8ª abaixo
  c8vb,
  /// Clave de percussão 1
  percussion,
  /// Clave de percussão 2
  percussion2,
  /// Clave de tablatura 6 cordas
  tab6,
  /// Clave de tablatura 4 cordas
  tab4,
}

/// Representa uma clave no início de uma pauta.
class Clef extends MusicalElement {
  final ClefType clefType;
  final int? staffPosition; // Para claves de Dó que podem variar de posição

  Clef({this.clefType = ClefType.treble, this.staffPosition, String? type}) {
    // Backward compatibility - se type for fornecido, converta para ClefType
    if (type != null) {
      switch (type) {
        case 'g':
          _clefType = ClefType.treble;
          break;
        case 'f':
          _clefType = ClefType.bass;
          break;
        case 'c':
          _clefType = ClefType.alto;
          break;
        default:
          _clefType = ClefType.treble;
      }
    } else {
      _clefType = clefType;
    }
  }

  ClefType _clefType = ClefType.treble;

  /// Getter para o tipo de clave atual
  ClefType get actualClefType => _clefType;

  /// Retorna o glifo SMuFL correspondente à clave
  String get glyphName {
    switch (_clefType) {
      case ClefType.treble:
        return 'gClef';
      case ClefType.treble8va:
        return 'gClef8va';
      case ClefType.treble8vb:
        return 'gClef8vb';
      case ClefType.treble15ma:
        return 'gClef15ma';
      case ClefType.treble15mb:
        return 'gClef15mb';
      case ClefType.bass:
      case ClefType.bassThirdLine:
        return 'fClef';
      case ClefType.bass8va:
        return 'fClef8va';
      case ClefType.bass8vb:
        return 'fClef8vb';
      case ClefType.bass15ma:
        return 'fClef15ma';
      case ClefType.bass15mb:
        return 'fClef15mb';
      case ClefType.soprano:
      case ClefType.mezzoSoprano:
      case ClefType.alto:
      case ClefType.tenor:
      case ClefType.baritone:
        return 'cClef';
      case ClefType.c8vb:
        return 'cClef8vb';
      case ClefType.percussion:
        return 'unpitchedPercussionClef1';
      case ClefType.percussion2:
        return 'unpitchedPercussionClef2';
      case ClefType.tab6:
        return '6stringTabClef';
      case ClefType.tab4:
        return '4stringTabClef';
    }
  }

  /// Retorna a posição da linha de referência da clave no pentagrama
  /// (0 = linha central, positivo = acima, negativo = abaixo)
  int get referenceLinePosition {
    switch (_clefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return 2; // Sol na 2ª linha
      case ClefType.bass:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return -2; // Fá na 4ª linha (posição padrão)
      case ClefType.bassThirdLine:
        return -1; // Fá na 3ª linha

      // Claves de Dó em todas as posições
      case ClefType.soprano:
        return 2; // Dó na 1ª linha
      case ClefType.mezzoSoprano:
        return 1; // Dó na 2ª linha
      case ClefType.alto:
        return 0; // Dó na 3ª linha (linha central)
      case ClefType.tenor:
        return -1; // Dó na 4ª linha
      case ClefType.baritone:
        return -2; // Dó na 5ª linha
      case ClefType.c8vb:
        return 0; // Dó na 3ª linha (oitava abaixo)
      case ClefType.percussion:
      case ClefType.percussion2:
      case ClefType.tab6:
      case ClefType.tab4:
        return 0; // Centralizada
    }
  }

  /// Retorna o deslocamento de oitava aplicado pela clave
  int get octaveShift {
    switch (_clefType) {
      case ClefType.treble8va:
      case ClefType.bass8va:
        return 1;
      case ClefType.treble8vb:
      case ClefType.bass8vb:
      case ClefType.c8vb:
        return -1;
      case ClefType.treble15ma:
      case ClefType.bass15ma:
        return 2;
      case ClefType.treble15mb:
      case ClefType.bass15mb:
        return -2;
      default:
        return 0;
    }
  }

  /// Backward compatibility - DEPRECATED: Use actualClefType instead
  @Deprecated('Use actualClefType instead. This getter will be removed in future versions.')
  String get type => _getCompatibilityType();

  String _getCompatibilityType() {
    switch (_clefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return 'g';
      case ClefType.bass:
      case ClefType.bassThirdLine:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return 'f';
      case ClefType.soprano:
      case ClefType.mezzoSoprano:
      case ClefType.alto:
      case ClefType.tenor:
      case ClefType.baritone:
      case ClefType.c8vb:
        return 'c';
      default:
        return 'g';
    }
  }

  /// Obtém a posição vertical da linha de referência da clave no pentagrama
  /// conforme especificações SMuFL (em unidades staff space)
  double get referenceLineOffsetSmufl {
    switch (_clefType) {
      case ClefType.treble:
      case ClefType.treble8va:
      case ClefType.treble8vb:
      case ClefType.treble15ma:
      case ClefType.treble15mb:
        return -1.0; // Sol na 2ª linha (1 staff space abaixo do centro)
      case ClefType.bass:
      case ClefType.bass8va:
      case ClefType.bass8vb:
      case ClefType.bass15ma:
      case ClefType.bass15mb:
        return 1.0; // Fá na 4ª linha (1 staff space acima do centro)
      case ClefType.bassThirdLine:
        return 0.0; // Fá na 3ª linha (linha central)
      case ClefType.soprano:
        return -2.0; // Dó na 1ª linha
      case ClefType.mezzoSoprano:
        return -1.0; // Dó na 2ª linha
      case ClefType.alto:
        return 0.0; // Dó na 3ª linha (linha central)
      case ClefType.tenor:
        return 1.0; // Dó na 4ª linha
      case ClefType.baritone:
        return 2.0; // Dó na 5ª linha
      case ClefType.c8vb:
        return 0.0; // Dó na 3ª linha (oitava abaixo)
      case ClefType.percussion:
      case ClefType.percussion2:
      case ClefType.tab6:
      case ClefType.tab4:
        return 0.0; // Centralizada
    }
  }
}
