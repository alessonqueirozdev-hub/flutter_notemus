// lib/src/layout/beam_grouper.dart

import '../../core/core.dart'; // 🆕 Tipos do core

/// Responsável por agrupar figuras musicais em grupos de beam
/// seguindo as regras musicais tradicionais baseadas na fórmula de compasso
class BeamGrouper {

  /// Agrupa notas em beams baseado na fórmula de compasso e configurações do compasso
  static List<BeamGroup> groupNotesForBeaming(
    List<Note> notes,
    TimeSignature timeSignature, {
    bool autoBeaming = true,
    BeamingMode beamingMode = BeamingMode.automatic,
    List<List<int>> manualBeamGroups = const [],
  }) {
    final groups = <BeamGroup>[];
    final beamableNotes = notes.where(_isBeamable).toList();

    if (beamableNotes.isEmpty) return groups;

    // Verificar se beaming está desabilitado
    if (!autoBeaming || beamingMode == BeamingMode.forceFlags) {
      return groups; // Retorna lista vazia = usar flags individuais
    }

    // Aplicar modo de beaming específico
    switch (beamingMode) {
      case BeamingMode.forceBeamAll:
        return _groupAllNotes(beamableNotes);

      case BeamingMode.conservative:
        return _groupConservative(beamableNotes);

      case BeamingMode.manual:
        return _groupManual(beamableNotes, manualBeamGroups);

      case BeamingMode.automatic:
      default:
        // Usar estratégia automática baseada na fórmula de compasso
        final strategy = _getGroupingStrategy(timeSignature);
        switch (strategy) {
          case BeamingStrategy.simple:
            return _groupSimpleTime(beamableNotes, timeSignature);
          case BeamingStrategy.compound:
            return _groupCompoundTime(beamableNotes, timeSignature);
          case BeamingStrategy.irregular:
            return _groupIrregularTime(beamableNotes, timeSignature);
        }
    }
  }

  /// Verifica se uma nota pode ser agrupada em beam
  static bool _isBeamable(Note note) {
    return note.duration.type.value <= 0.125; // Colcheia ou menor
  }

  /// Determina a estratégia de agrupamento baseado na fórmula de compasso
  static BeamingStrategy _getGroupingStrategy(TimeSignature timeSignature) {
    final denominator = timeSignature.denominator;
    final numerator = timeSignature.numerator;

    // Compassos compostos (denominador 8 e numerador divisível por 3)
    if (denominator == 8 && numerator % 3 == 0) {
      return BeamingStrategy.compound;
    }

    // Compassos simples regulares (2/4, 3/4, 4/4, etc.)
    if ([2, 3, 4].contains(numerator) && [2, 4, 8].contains(denominator)) {
      return BeamingStrategy.simple;
    }

    // Compassos irregulares (5/8, 7/8, etc.)
    return BeamingStrategy.irregular;
  }

  /// Agrupamento para compassos simples (2/4, 3/4, 4/4)
  static List<BeamGroup> _groupSimpleTime(
    List<Note> notes,
    TimeSignature timeSignature,
  ) {
    final groups = <BeamGroup>[];
    
    // Regra simples para 4/4: agrupar por tempo (quarter note = 0.25)
    // Para outros compassos simples, agrupar por beat unit
    final beatUnit = 1.0 / timeSignature.denominator;
    
    var currentGroup = <Note>[];
    var currentPosition = 0.0;

    for (final note in notes) {
      final noteDuration = note.duration.realValue;
      final noteEnd = currentPosition + noteDuration;
      
      // Determinar em qual beat esta nota começa e termina
      final startBeat = (currentPosition / beatUnit).floor();
      final endBeat = ((noteEnd - 0.0001) / beatUnit).floor(); // Tolerância
      
      // Se a nota cruza para o próximo beat, finalizar grupo atual
      if (startBeat != endBeat && currentGroup.isNotEmpty) {
        // Finalizar o grupo anterior
        if (currentGroup.length >= 2) {
          groups.add(BeamGroup(notes: List.from(currentGroup)));
        }
        currentGroup = [note]; // Iniciar novo grupo com esta nota
      } else {
        // Nota está dentro do mesmo beat, adicionar ao grupo
        currentGroup.add(note);
      }
      
      currentPosition = noteEnd;
    }

    // Adiciona grupo final se tiver pelo menos 2 notas
    if (currentGroup.length >= 2) {
      groups.add(BeamGroup(notes: currentGroup));
    }

    return groups;
  }

  /// Agrupamento para compassos compostos (6/8, 9/8, 12/8)
  static List<BeamGroup> _groupCompoundTime(
    List<Note> notes,
    TimeSignature timeSignature,
  ) {
    final groups = <BeamGroup>[];
    final beatUnit = 3.0 / timeSignature.denominator; // 3 colcheias por tempo

    var currentGroup = <Note>[];
    var currentBeatPosition = 0.0;

    for (final note in notes) {
      final noteDuration = note.duration.realValue;
      final nextBeatPosition = currentBeatPosition + noteDuration;

      // Verifica se a nota atravessa um tempo ternário
      final currentBeat = (currentBeatPosition / beatUnit).floor();
      final nextBeat = (nextBeatPosition / beatUnit).floor();

      if (currentBeat != nextBeat && currentGroup.isNotEmpty) {
        // Finaliza o grupo atual se atravessa um tempo
        if (currentGroup.length >= 2) {
          groups.add(BeamGroup(notes: List.from(currentGroup)));
        }
        currentGroup.clear();
      }

      currentGroup.add(note);
      currentBeatPosition = nextBeatPosition;

      // Finaliza grupo se completou um tempo ternário
      if (_isEndOfCompoundBeat(nextBeatPosition, beatUnit) && currentGroup.length >= 2) {
        groups.add(BeamGroup(notes: List.from(currentGroup)));
        currentGroup.clear();
      }
    }

    // Adiciona grupo final se tiver pelo menos 2 notas
    if (currentGroup.length >= 2) {
      groups.add(BeamGroup(notes: currentGroup));
    }

    return groups;
  }

  /// Agrupamento para compassos irregulares (5/8, 7/8, etc.)
  static List<BeamGroup> _groupIrregularTime(
    List<Note> notes,
    TimeSignature timeSignature,
  ) {
    final groups = <BeamGroup>[];

    // Define padrões de subdivisão para compassos irregulares comuns
    final subdivisions = _getIrregularSubdivisions(timeSignature);

    var currentGroup = <Note>[];
    var currentPosition = 0.0;
    var subdivisionIndex = 0;
    var subdivisionStart = 0.0;

    for (final note in notes) {
      final noteDuration = note.duration.realValue;
      final nextPosition = currentPosition + noteDuration;

      // Verifica se ultrapassou a subdivisão atual
      if (subdivisionIndex < subdivisions.length) {
        final subdivisionEnd = subdivisionStart + subdivisions[subdivisionIndex];

        if (nextPosition > subdivisionEnd && currentGroup.isNotEmpty) {
          // Finaliza o grupo atual
          if (currentGroup.length >= 2) {
            groups.add(BeamGroup(notes: List.from(currentGroup)));
          }
          currentGroup.clear();

          // Avança para próxima subdivisão
          subdivisionStart = subdivisionEnd;
          subdivisionIndex++;
        }
      }

      currentGroup.add(note);
      currentPosition = nextPosition;
    }

    // Adiciona grupo final se tiver pelo menos 2 notas
    if (currentGroup.length >= 2) {
      groups.add(BeamGroup(notes: currentGroup));
    }

    return groups;
  }

  /// Retorna subdivisões para compassos irregulares
  static List<double> _getIrregularSubdivisions(TimeSignature timeSignature) {
    final numerator = timeSignature.numerator;
    final denominator = timeSignature.denominator;
    final eighthNote = 1.0 / 8;

    switch ('$numerator/$denominator') {
      case '5/8':
        return [2 * eighthNote, 3 * eighthNote]; // 2+3 ou 3+2 (padrão 2+3)
      case '7/8':
        return [2 * eighthNote, 2 * eighthNote, 3 * eighthNote]; // 2+2+3
      case '5/4':
        return [1.0, 1.0]; // 2+3 semínimas
      default:
        // Padrão: grupos de 2 ou 3 baseado no numerador
        final subdivisions = <double>[];
        var remaining = numerator;
        final unit = 1.0 / denominator;

        while (remaining > 0) {
          if (remaining >= 3) {
            subdivisions.add(3 * unit);
            remaining -= 3;
          } else {
            subdivisions.add(remaining * unit);
            remaining = 0;
          }
        }
        return subdivisions;
    }
  }

  /// Verifica se chegou ao final de um tempo composto
  static bool _isEndOfCompoundBeat(double position, double beatUnit) {
    const tolerance = 0.0001;
    return (position % beatUnit).abs() < tolerance;
  }

  /// Agrupa todas as notas possíveis em um único beam
  static List<BeamGroup> _groupAllNotes(List<Note> notes) {
    if (notes.length < 2) return [];
    return [BeamGroup(notes: notes)];
  }

  /// Agrupamento conservador - apenas grupos óbvios de 2 notas consecutivas
  static List<BeamGroup> _groupConservative(List<Note> notes) {
    final groups = <BeamGroup>[];

    for (int i = 0; i < notes.length - 1; i += 2) {
      final currentNote = notes[i];
      final nextNote = notes[i + 1];

      // Agrupar apenas se ambas têm duração igual
      if (currentNote.duration.type == nextNote.duration.type) {
        groups.add(BeamGroup(notes: [currentNote, nextNote]));
      }
    }

    return groups;
  }

  /// Agrupamento manual baseado em índices especificados
  static List<BeamGroup> _groupManual(List<Note> notes, List<List<int>> manualGroups) {
    final groups = <BeamGroup>[];

    for (final groupIndices in manualGroups) {
      if (groupIndices.length < 2) continue; // Precisa de pelo menos 2 notas

      final groupNotes = <Note>[];
      for (final index in groupIndices) {
        if (index >= 0 && index < notes.length) {
          groupNotes.add(notes[index]);
        }
      }

      // Só criar o grupo se todas as notas forem beamáveis e tivermos pelo menos 2
      if (groupNotes.length >= 2 && groupNotes.every(_isBeamable)) {
        groups.add(BeamGroup(notes: groupNotes));
      }
    }

    return groups;
  }
}

/// Estratégias de agrupamento
enum BeamingStrategy {
  simple,    // Compassos simples (2/4, 3/4, 4/4)
  compound,  // Compassos compostos (6/8, 9/8, 12/8)
  irregular, // Compassos irregulares (5/8, 7/8, etc.)
}

/// Representa um grupo de notas que devem ser unidas por beam
class BeamGroup {
  final List<Note> notes;
  final BeamGroupType type;

  BeamGroup({
    required this.notes,
    this.type = BeamGroupType.primary,
  });

  /// Retorna true se o grupo tem pelo menos 2 notas
  bool get isValid => notes.length >= 2;

  /// Retorna a duração mais curta no grupo
  DurationType get shortestDuration {
    return notes.map((n) => n.duration.type).reduce((a, b) {
      return a.value < b.value ? a : b;
    });
  }

  /// Retorna o número de beams necessárias para este grupo
  int get numberOfBeams {
    switch (shortestDuration) {
      case DurationType.eighth:
        return 1;
      case DurationType.sixteenth:
        return 2;
      case DurationType.thirtySecond:
        return 3;
      case DurationType.sixtyFourth:
        return 4;
      default:
        return 1;
    }
  }

  /// Verifica se todas as notas no grupo têm a mesma duração
  bool get hasUniformDuration {
    if (notes.isEmpty) return true;
    final firstDuration = notes.first.duration.type;
    return notes.every((note) => note.duration.type == firstDuration);
  }
}

/// Tipos de beam para diferentes situações
enum BeamGroupType {
  primary,    // Beam principal
  secondary,  // Beam secundária (para subdivisões)
  partial,    // Beam parcial (para mistura de durações)
}