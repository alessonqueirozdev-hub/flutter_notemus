// lib/src/parsers/simple_json_parser.dart

import 'dart:convert';
import '../../core/core.dart';

/// Parser para formato JSON simplificado com suporte a letras (lyrics)
/// 
/// Formato aceito:
/// ```json
/// [
///   {
///     "note": "C4",
///     "lyric": "Dó",
///     "duration": "quarter"
///   }
/// ]
/// ```
class SimpleJsonParser {
  
  /// Converte array JSON simplificado para Staff completo
  /// 
  /// Exemplo:
  /// ```dart
  /// final jsonString = '''
  /// [
  ///   {"note": "C4", "lyric": "Dó", "duration": "quarter"},
  ///   {"note": "D4", "lyric": "Ré", "duration": "half"}
  /// ]
  /// ''';
  /// 
  /// final staff = SimpleJsonParser.parseSimpleNotes(jsonString);
  /// ```
  static Staff parseSimpleNotes(String jsonString, {
    ClefType clefType = ClefType.treble,
    int keySignatureFifths = 0,
    int timeSignatureNumerator = 4,
    int timeSignatureDenominator = 4,
    bool autoBarlines = true,
  }) {
    final List<dynamic> notesJson = jsonDecode(jsonString);
    final staff = Staff();
    
    // Criar primeiro compasso com atributos
    var currentMeasure = Measure();
    currentMeasure.add(Clef(clefType: clefType));
    currentMeasure.add(KeySignature(keySignatureFifths));
    currentMeasure.add(TimeSignature(
      numerator: timeSignatureNumerator,
      denominator: timeSignatureDenominator,
    ));
    
    double currentDuration = 0.0;
    final measureCapacity = timeSignatureNumerator / timeSignatureDenominator;
    
    for (final noteJson in notesJson) {
      final note = _parseSimpleNote(noteJson);
      if (note == null) continue;
      
      final noteDuration = note.duration.realValue;
      
      // Se a nota não cabe no compasso atual, criar novo compasso
      if (currentDuration + noteDuration > measureCapacity) {
        if (autoBarlines) {
          currentMeasure.add(Barline(type: BarlineType.single));
        }
        staff.add(currentMeasure);
        
        currentMeasure = Measure();
        currentDuration = 0.0;
      }
      
      currentMeasure.add(note);
      currentDuration += noteDuration;
      
      // Se completou o compasso exatamente, iniciar novo
      if (currentDuration >= measureCapacity) {
        if (autoBarlines) {
          currentMeasure.add(Barline(type: BarlineType.single));
        }
        staff.add(currentMeasure);
        
        currentMeasure = Measure();
        currentDuration = 0.0;
      }
    }
    
    // Adicionar último compasso se tiver notas
    if (currentMeasure.elements.isNotEmpty) {
      if (autoBarlines) {
        currentMeasure.add(Barline(type: BarlineType.final_));
      }
      staff.add(currentMeasure);
    }
    
    return staff;
  }
  
  /// Parse de uma nota no formato simplificado
  static Note? _parseSimpleNote(Map<String, dynamic> json) {
    final String? noteString = json['note'];
    if (noteString == null) return null;
    
    final pitch = _parsePitchFromString(noteString);
    if (pitch == null) return null;
    
    final String durationString = json['duration'] ?? 'quarter';
    final duration = _parseDuration(durationString);
    
    return Note(
      pitch: pitch,
      duration: duration,
    );
  }
  
  /// Converte string de nota para objeto Pitch
  /// 
  /// Formatos aceitos:
  /// - "C4" → Dó na 4ª oitava
  /// - "C#4" → Dó sustenido na 4ª oitava
  /// - "Db4" → Ré bemol na 4ª oitava
  /// - "C##4" → Dó dobrado sustenido
  /// - "Cbb4" → Dó dobrado bemol
  static Pitch? _parsePitchFromString(String noteString) {
    if (noteString.isEmpty) return null;
    
    // Extrair step (primeira letra)
    final step = noteString[0].toUpperCase();
    if (!'ABCDEFG'.contains(step)) return null;
    
    // Extrair alteração e oitava
    double alter = 0.0;
    int octave = 4; // Padrão
    
    int index = 1;
    
    // Parse de alterações (#, b)
    while (index < noteString.length) {
      if (noteString[index] == '#') {
        alter += 1.0;
        index++;
      } else if (noteString[index] == 'b') {
        alter -= 1.0;
        index++;
      } else {
        break;
      }
    }
    
    // Parse de oitava (resto da string)
    if (index < noteString.length) {
      octave = int.tryParse(noteString.substring(index)) ?? 4;
    }
    
    return Pitch(
      step: step,
      octave: octave,
      alter: alter,
    );
  }
  
  /// Converte string de duração para objeto Duration
  static Duration _parseDuration(String durationString) {
    DurationType type;
    
    switch (durationString.toLowerCase()) {
      case 'whole':
      case 'semibreve':
        type = DurationType.whole;
        break;
      case 'half':
      case 'minima':
        type = DurationType.half;
        break;
      case 'quarter':
      case 'seminima':
        type = DurationType.quarter;
        break;
      case 'eighth':
      case 'colcheia':
        type = DurationType.eighth;
        break;
      case 'sixteenth':
      case 'semicolcheia':
        type = DurationType.sixteenth;
        break;
      case '32nd':
      case 'fusa':
        type = DurationType.thirtySecond;
        break;
      case '64th':
      case 'semifusa':
        type = DurationType.sixtyFourth;
        break;
      default:
        type = DurationType.quarter;
    }
    
    return Duration(type);
  }
  
  /// Renderiza APENAS um elemento isolado (ex: clave de sol)
  /// 
  /// Exemplo:
  /// ```dart
  /// final clefJson = '{"type": "clef", "clefType": "treble"}';
  /// final element = SimpleJsonParser.parseSingleElement(clefJson);
  /// ```
  static MusicalElement? parseSingleElement(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    final String type = json['type'] ?? '';
    
    switch (type) {
      case 'clef':
        return _parseClef(json);
        
      case 'keySignature':
        return _parseKeySignature(json);
        
      case 'timeSignature':
        return _parseTimeSignature(json);
        
      case 'note':
        return _parseSimpleNote(json);
        
      case 'rest':
        return _parseRest(json);
        
      case 'barline':
        return _parseBarline(json);
        
      default:
        return null;
    }
  }
  
  static Clef? _parseClef(Map<String, dynamic> json) {
    final String clefTypeString = json['clefType'] ?? 'treble';
    
    ClefType type;
    switch (clefTypeString.toLowerCase()) {
      case 'treble':
      case 'g':
      case 'sol':
        type = ClefType.treble;
        break;
      case 'bass':
      case 'f':
      case 'fa':
        type = ClefType.bass;
        break;
      case 'alto':
      case 'c':
      case 'do':
        type = ClefType.alto;
        break;
      case 'tenor':
        type = ClefType.tenor;
        break;
      case 'percussion':
        type = ClefType.percussion;
        break;
      case 'tab':
      case 'tab6':
        type = ClefType.tab6;
        break;
      case 'tab4':
        type = ClefType.tab4;
        break;
      default:
        type = ClefType.treble;
    }
    
    return Clef(clefType: type);
  }
  
  static KeySignature? _parseKeySignature(Map<String, dynamic> json) {
    final int fifths = json['fifths'] ?? 0;
    return KeySignature(fifths);
  }
  
  static TimeSignature? _parseTimeSignature(Map<String, dynamic> json) {
    final int numerator = json['numerator'] ?? 4;
    final int denominator = json['denominator'] ?? 4;
    return TimeSignature(numerator: numerator, denominator: denominator);
  }
  
  static Rest? _parseRest(Map<String, dynamic> json) {
    final String durationString = json['duration'] ?? 'quarter';
    final duration = _parseDuration(durationString);
    return Rest(duration: duration);
  }
  
  static Barline? _parseBarline(Map<String, dynamic> json) {
    final String typeString = json['barlineType'] ?? 'single';
    
    BarlineType type;
    switch (typeString.toLowerCase()) {
      case 'single':
        type = BarlineType.single;
        break;
      case 'double':
        type = BarlineType.double;
        break;
      case 'final':
        type = BarlineType.final_;
        break;
      case 'repeatforward':
        type = BarlineType.repeatForward;
        break;
      case 'repeatbackward':
        type = BarlineType.repeatBackward;
        break;
      case 'repeatboth':
        type = BarlineType.repeatBoth;
        break;
      default:
        type = BarlineType.single;
    }
    
    return Barline(type: type);
  }
  
  /// Converte array de notas simples para JSON
  static String notesToSimpleJson(List<Note> notes) {
    final List<Map<String, dynamic>> jsonArray = [];
    
    for (final note in notes) {
      jsonArray.add({
        'note': _pitchToString(note.pitch),
        'duration': _durationToString(note.duration.type),
      });
    }
    
    return jsonEncode(jsonArray);
  }
  
  static String _pitchToString(Pitch pitch) {
    String result = pitch.step;
    
    // Adicionar alterações
    if (pitch.alter > 0) {
      result += '#' * pitch.alter.toInt();
    } else if (pitch.alter < 0) {
      result += 'b' * (-pitch.alter).toInt();
    }
    
    result += pitch.octave.toString();
    
    return result;
  }
  
  static String _durationToString(DurationType type) {
    switch (type) {
      case DurationType.whole:
        return 'whole';
      case DurationType.half:
        return 'half';
      case DurationType.quarter:
        return 'quarter';
      case DurationType.eighth:
        return 'eighth';
      case DurationType.sixteenth:
        return 'sixteenth';
      case DurationType.thirtySecond:
        return '32nd';
      case DurationType.sixtyFourth:
        return '64th';
      default:
        return 'quarter';
    }
  }
}
