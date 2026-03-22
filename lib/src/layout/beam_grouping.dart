// lib/src/layout/beam_grouping.dart

import '../../core/core.dart';

/// Lógica inteligente de agrupamento de barras (beams) para figuras rítmicas
/// Segue as regras tradicionais de notação musical
class BeamGrouping {
  /// Agrupa notas em beams baseado na fórmula de compasso e posição no compasso
  static List<MusicalElement> groupBeams(
    List<MusicalElement> elements,
    TimeSignature? timeSignature,
  ) {
    if (timeSignature == null) {
      return _groupBeamsSimple(elements);
    }

    switch (timeSignature.denominator) {
      case 4: // Compassos simples (2/4, 3/4, 4/4)
        return _groupBeamsSimple(elements, beatValue: 0.25);
      case 8: // Compassos compostos (6/8, 9/8, 12/8)
        return _groupBeamsCompound(elements, timeSignature);
      default:
        return _groupBeamsIrregular(elements, timeSignature);
    }
  }

  /// Agrupamento para compassos simples (2/4, 3/4, 4/4)
  /// Regra: agrupar por tempo (cada semínima = um grupo)
  static List<MusicalElement> _groupBeamsSimple(
    List<MusicalElement> elements, {
    double beatValue = 0.25, // Valor de um tempo (semínima)
  }) {
    final result = <MusicalElement>[];
    final beamableNotes = <Note>[];
    double currentBeatPosition = 0.0;

    for (final element in elements) {
      if (element is Note && _isBeamable(element)) {
        // Verificar se a nota cruza a barreira do tempo
        final noteEnd = currentBeatPosition + element.duration.realValue;
        final currentBeat = (currentBeatPosition / beatValue).floor();
        final noteBeat = (noteEnd / beatValue).floor();

        if (currentBeat != noteBeat && beamableNotes.isNotEmpty) {
          // Nota cruza tempo - finalizar grupo atual
          result.addAll(_createBeamGroup(beamableNotes));
          beamableNotes.clear();
        }

        beamableNotes.add(element);
        currentBeatPosition += element.duration.realValue;
      } else {
        // Finalizar grupo atual se houver
        if (beamableNotes.isNotEmpty) {
          result.addAll(_createBeamGroup(beamableNotes));
          beamableNotes.clear();
        }
        
        result.add(element);
        
        // Atualizar posição no compasso
        if (element is Note) {
          currentBeatPosition += element.duration.realValue;
        } else if (element is Rest) {
          currentBeatPosition += element.duration.realValue;
        }
      }
    }

    // Finalizar último grupo
    if (beamableNotes.isNotEmpty) {
      result.addAll(_createBeamGroup(beamableNotes));
    }

    return result;
  }

  /// Agrupamento para compassos compostos (6/8, 9/8, 12/8)
  /// Regra: agrupar por tempo ternário (3 colcheias = um grupo)
  static List<MusicalElement> _groupBeamsCompound(
    List<MusicalElement> elements,
    TimeSignature timeSignature,
  ) {
    final result = <MusicalElement>[];
    final beamableNotes = <Note>[];
    double currentPosition = 0.0;
    final ternaryBeatValue = 3 * 0.125; // 3 colcheias = um tempo composto

    for (final element in elements) {
      if (element is Note && _isBeamable(element)) {
        // Verificar se a nota cruza a barreira do tempo ternário
        final noteEnd = currentPosition + element.duration.realValue;
        final currentBeat = (currentPosition / ternaryBeatValue).floor();
        final noteBeat = (noteEnd / ternaryBeatValue).floor();

        if (currentBeat != noteBeat && beamableNotes.isNotEmpty) {
          // Finalizar grupo atual
          result.addAll(_createBeamGroup(beamableNotes));
          beamableNotes.clear();
        }

        beamableNotes.add(element);
        currentPosition += element.duration.realValue;
      } else {
        // Finalizar grupo atual
        if (beamableNotes.isNotEmpty) {
          result.addAll(_createBeamGroup(beamableNotes));
          beamableNotes.clear();
        }
        
        result.add(element);
        
        if (element is Note) {
          currentPosition += element.duration.realValue;
        } else if (element is Rest) {
          currentPosition += element.duration.realValue;
        }
      }
    }

    if (beamableNotes.isNotEmpty) {
      result.addAll(_createBeamGroup(beamableNotes));
    }

    return result;
  }

  /// Agrupamento para compassos irregulares (5/8, 7/8, etc.)
  /// Usa padrões predefinidos baseados na tradição musical
  static List<MusicalElement> _groupBeamsIrregular(
    List<MusicalElement> elements,
    TimeSignature timeSignature,
  ) {
    final patterns = _getIrregularPattern(timeSignature);
    
    final result = <MusicalElement>[];
    final beamableNotes = <Note>[];
    double currentPosition = 0.0;
    int currentPatternIndex = 0;
    double currentPatternEnd = patterns.isNotEmpty ? patterns[0] : 0.0;

    for (final element in elements) {
      if (element is Note && _isBeamable(element)) {
        final noteEnd = currentPosition + element.duration.realValue;
        
        // Verificar se cruza padrão
        if (noteEnd > currentPatternEnd && beamableNotes.isNotEmpty) {
          result.addAll(_createBeamGroup(beamableNotes));
          beamableNotes.clear();
          
          // Avançar para próximo padrão
          currentPatternIndex++;
          if (currentPatternIndex < patterns.length) {
            currentPatternEnd += patterns[currentPatternIndex];
          }
        }

        beamableNotes.add(element);
        currentPosition += element.duration.realValue;
      } else {
        if (beamableNotes.isNotEmpty) {
          result.addAll(_createBeamGroup(beamableNotes));
          beamableNotes.clear();
        }
        
        result.add(element);
        
        if (element is Note) {
          currentPosition += element.duration.realValue;
        } else if (element is Rest) {
          currentPosition += element.duration.realValue;
        }
      }
    }

    if (beamableNotes.isNotEmpty) {
      result.addAll(_createBeamGroup(beamableNotes));
    }

    return result;
  }

  /// Retorna padrões de agrupamento para compassos irregulares
  static List<double> _getIrregularPattern(TimeSignature timeSignature) {
    final key = '${timeSignature.numerator}/${timeSignature.denominator}';
    
    switch (key) {
      case '5/8':
        return [0.375, 0.25]; // (3+2) ou [0.25, 0.375] para (2+3)
      case '7/8':
        return [0.25, 0.25, 0.375]; // (2+2+3)
      case '5/4':
        return [0.5, 0.75]; // (2+3) em semínimas
      default:
        // Padrão genérico: dividir igualmente
        final totalValue = timeSignature.measureValue;
        final parts = (totalValue / 0.25).round(); // Dividir em tempos de semínima
        return List.filled(parts, 0.25);
    }
  }

  /// Verifica se uma nota pode ser agrupada em beam
  static bool _isBeamable(Note note) {
    return note.duration.type == DurationType.eighth ||
           note.duration.type == DurationType.sixteenth ||
           note.duration.type == DurationType.thirtySecond ||
           note.duration.type == DurationType.sixtyFourth;
  }

  /// Cria um grupo de beam com as notas fornecidas
  static List<Note> _createBeamGroup(List<Note> notes) {
    if (notes.length <= 1) {
      return notes; // Não agrupar notas isoladas
    }

    final result = <Note>[];
    for (int i = 0; i < notes.length; i++) {
      BeamType beamType;
      if (i == 0) {
        beamType = BeamType.start;
      } else if (i == notes.length - 1) {
        beamType = BeamType.end;
      } else {
        beamType = BeamType.inner;
      }

      result.add(_cloneNoteWithBeam(notes[i], beamType));
    }

    return result;
  }

  /// Clona uma nota adicionando informação de beam
  static Note _cloneNoteWithBeam(Note original, BeamType beamType) {
    return Note(
      pitch: original.pitch,
      duration: original.duration,
      beam: beamType,
      articulations: original.articulations,
      tie: original.tie,
      slur: original.slur,
      ornaments: original.ornaments,
      dynamicElement: original.dynamicElement,
      techniques: original.techniques,
    );
  }
}