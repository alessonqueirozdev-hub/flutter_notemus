// lib/core/measure.dart

import 'musical_element.dart';
import 'note.dart';
import 'rest.dart';
import 'time_signature.dart';
import 'duration.dart';

/// Representa um compasso, que contém elementos musicais.
class Measure {
  final List<MusicalElement> elements = [];

  /// Controla se as notas devem ser automaticamente agrupadas com beams
  /// true = auto-beaming ativo (padrão)
  /// false = usar bandeirolas individuais (flags)
  bool autoBeaming;

  /// Estratégia específica de beaming para casos especiais
  BeamingMode beamingMode;

  /// Grupos manuais de beams - lista de listas de índices de notas a serem agrupadas
  /// Exemplo: [[0, 1, 2], [3, 4]] = agrupa notas 0,1,2 em um beam e 3,4 em outro
  List<List<int>> manualBeamGroups;

  /// TimeSignature herdado de compasso anterior (usado para validação preventiva)
  TimeSignature? inheritedTimeSignature;

  Measure({
    this.autoBeaming = true,
    this.beamingMode = BeamingMode.automatic,
    this.manualBeamGroups = const [],
    this.inheritedTimeSignature,
  });

  /// Adiciona um elemento musical ao compasso.
  /// 
  /// **VALIDAÇÃO RIGOROSA**: Se o compasso tiver TimeSignature, valida ANTES
  /// de adicionar para garantir que não excede a capacidade do compasso.
  /// 
  /// Lança [MeasureCapacityException] se tentar adicionar figura que exceda.
  void add(MusicalElement element) {
    // Verificar se é um elemento que ocupa tempo musical
    final elementDuration = _getElementDuration(element);
    
    if (elementDuration > 0) {
      // Buscar TimeSignature no compasso ou usar o herdado
      final ts = timeSignature ?? inheritedTimeSignature;
      
      if (ts != null) {
        // Calcular se há espaço
        final currentValue = currentMusicalValue;
        final measureCapacity = ts.measureValue;
        final afterAdding = currentValue + elementDuration;
        
        // Tolerância para erros de ponto flutuante
        const tolerance = 0.0001;
        
        if (afterAdding > measureCapacity + tolerance) {
          // PROIBIDO: Excede capacidade!
          final excess = afterAdding - measureCapacity;
          throw MeasureCapacityException(
            'Não é possível adicionar ${element.runtimeType} ao compasso!\n'
            'Compasso ${ts.numerator}/${ts.denominator} (capacidade: $measureCapacity unidades)\n'
            'Valor atual: $currentValue unidades\n'
            'Tentando adicionar: $elementDuration unidades\n'
            'Total seria: $afterAdding unidades\n'
            'EXCESSO: ${excess.toStringAsFixed(4)} unidades\n'
            '❌ OPERAÇÃO BLOQUEADA - Remova figuras ou crie novo compasso!'
          );
        }
      }
    }
    
    // Adicionar elemento
    elements.add(element);
  }

  /// Calcula o valor total atual das figuras musicais no compasso.
  double get currentMusicalValue {
    double total = 0.0;
    for (final element in elements) {
      if (element is Note) {
        total += element.duration.realValue;
      } else if (element is Rest) {
        total += element.duration.realValue;
      } else if (element.runtimeType.toString() == 'Chord') {
        // Usar reflexão para evitar import circular
        final dynamic chord = element;
        if (chord.duration != null) {
          total += chord.duration.realValue;
        }
      } else if (element.runtimeType.toString() == 'Tuplet') {
        // Calcular valor da quiáltera baseado na razão
        final dynamic tuplet = element;
        double tupletValue = 0.0;

        // Somar duração de todas as notas da quiáltera
        for (final tupletElement in tuplet.elements) {
          if (tupletElement is Note) {
            tupletValue += tupletElement.duration.realValue;
          } else if (tupletElement.runtimeType.toString() == 'Chord') {
            final dynamic chord = tupletElement;
            if (chord.duration != null) {
              tupletValue += chord.duration.realValue;
            }
          }
        }

        // Aplicar a razão da quiáltera (normalNotes / actualNotes)
        if (tuplet.actualNotes > 0) {
          tupletValue = tupletValue * (tuplet.normalNotes / tuplet.actualNotes);
        }

        total += tupletValue;
      }
    }
    return total;
  }

  /// Obtém a fórmula de compasso ativa neste compasso.
  TimeSignature? get timeSignature {
    for (final element in elements) {
      if (element is TimeSignature) {
        return element;
      }
    }
    return null;
  }

  /// Verifica se o compasso está corretamente preenchido.
  bool get isValidlyFilled {
    final ts = timeSignature;
    if (ts == null) return true; // Sem fórmula = sem validação
    return currentMusicalValue == ts.measureValue;
  }

  /// Verifica se ainda há espaço para adicionar uma duração específica.
  bool canAddDuration(Duration duration) {
    final ts = timeSignature;
    if (ts == null) return true; // Sem fórmula = sempre pode adicionar
    return currentMusicalValue + duration.realValue <= ts.measureValue;
  }

  /// Calcula quanto tempo ainda resta no compasso.
  double get remainingValue {
    final ts = timeSignature;
    if (ts == null) return double.infinity;
    return ts.measureValue - currentMusicalValue;
  }

  /// Calcula a duração de um elemento musical (helper privado)
  double _getElementDuration(MusicalElement element) {
    if (element is Note) {
      return element.duration.realValue;
    } else if (element is Rest) {
      return element.duration.realValue;
    } else if (element.runtimeType.toString() == 'Chord') {
      final dynamic chord = element;
      return chord.duration?.realValue ?? 0.0;
    } else if (element.runtimeType.toString() == 'Tuplet') {
      final dynamic tuplet = element;
      double tupletValue = 0.0;
      for (final tupletElement in tuplet.elements) {
        tupletValue += _getElementDuration(tupletElement);
      }
      // Aplicar proporção da quiáltera
      if (tuplet.actualNotes > 0) {
        tupletValue = tupletValue * (tuplet.normalNotes / tuplet.actualNotes);
      }
      return tupletValue;
    }
    return 0.0; // Elementos sem duração (clef, key signature, etc.)
  }
}

/// Exceção lançada quando se tenta adicionar figura que excede capacidade do compasso
class MeasureCapacityException implements Exception {
  final String message;
  
  MeasureCapacityException(this.message);
  
  @override
  String toString() => 'MeasureCapacityException: $message';
}
