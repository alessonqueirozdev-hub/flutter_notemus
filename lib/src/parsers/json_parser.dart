// lib/src/parsers/json_parser.dart

import 'dart:convert';
import '../../core/core.dart'; // Tipos do core

/// Parser para converter JSON em objetos musicais
class JsonMusicParser {

  /// Converte um JSON de partitura para um objeto Staff
  static Staff parseStaff(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return _parseStaffFromMap(json);
  }

  static Staff _parseStaffFromMap(Map<String, dynamic> json) {
    final staff = Staff();

    if (json['measures'] != null) {
      for (final measureJson in json['measures']) {
        final measure = _parseMeasureFromMap(measureJson);
        staff.add(measure);
      }
    }

    return staff;
  }

  static Measure _parseMeasureFromMap(Map<String, dynamic> json) {
    final measure = Measure();

    if (json['elements'] != null) {
      for (final elementJson in json['elements']) {
        final element = _parseElementFromMap(elementJson);
        if (element != null) {
          measure.add(element);
        }
      }
    }

    return measure;
  }

  static MusicalElement? _parseElementFromMap(Map<String, dynamic> json) {
    final String type = json['type'] ?? '';

    switch (type) {
      case 'clef':
        return Clef(type: json['clefType'] ?? 'g');

      case 'keySignature':
        return KeySignature(json['count'] ?? 0);

      case 'timeSignature':
        return TimeSignature(
          numerator: json['numerator'] ?? 4,
          denominator: json['denominator'] ?? 4,
        );

      case 'note':
        return _parseNoteFromMap(json);

      case 'rest':
        return _parseRestFromMap(json);

      case 'barline':
        return _parseBarlineFromMap(json);

      case 'dynamic':
        return _parseDynamicFromMap(json);

      case 'tempo':
        return _parseTempoFromMap(json);

      case 'breath':
        return _parseBreathFromMap(json);

      case 'caesura':
        return Caesura(type: _parseBreathType(json['breathType'] ?? 'caesura'));

      case 'chord':
        return _parseChordFromMap(json);

      case 'text':
        return _parseTextFromMap(json);

      case 'tuplet':
        return _parseTupletFromMap(json);

      case 'graceNote':
        return _parseGraceNoteFromMap(json);

      case 'ornament':
        return _parseOrnamentFromMap(json);

      default:
        return null;
    }
  }

  static Note _parseNoteFromMap(Map<String, dynamic> json) {
    final pitchJson = json['pitch'] ?? {};
    final durationJson = json['duration'] ?? {};

    final pitch = Pitch(
      step: pitchJson['step'] ?? 'C',
      octave: pitchJson['octave'] ?? 4,
      alter: pitchJson['alter']?.toDouble() ?? 0.0,
    );

    final duration = Duration(
      _parseDurationType(durationJson['type'] ?? 'quarter'),
      dots: durationJson['dots'] ?? 0,
    );

    // Parse opcional de articulações
    List<ArticulationType> articulations = [];
    if (json['articulations'] != null) {
      for (final articulation in json['articulations']) {
        switch (articulation) {
          case 'staccato':
            articulations.add(ArticulationType.staccato);
            break;
          case 'accent':
            articulations.add(ArticulationType.accent);
            break;
          case 'tenuto':
            articulations.add(ArticulationType.tenuto);
            break;
        }
      }
    }

    // Parse opcional de tie
    TieType? tie;
    if (json['tie'] != null) {
      tie = _parseTieType(json['tie']);
    }

    // Parse opcional de slur (agora com mais opções)
    SlurType? slur;
    if (json['slur'] != null) {
      slur = _parseSlurType(json['slur']);
    }

    // Parse opcional de ornamentos
    List<Ornament> ornaments = [];
    if (json['ornaments'] != null) {
      for (final ornamentJson in json['ornaments']) {
        final ornament = _parseOrnamentFromMap(ornamentJson);
        if (ornament != null) {
          ornaments.add(ornament);
        }
      }
    }

    return Note(
      pitch: pitch,
      duration: duration,
      articulations: articulations,
      tie: tie,
      slur: slur,
      ornaments: ornaments,
    );
  }

  // === NOVOS PARSERS: TUPLETS ===

  static Tuplet? _parseTupletFromMap(Map<String, dynamic> json) {
    final int actualNotes = json['actualNotes'] ?? 3;
    final int normalNotes = json['normalNotes'] ?? 2;

    final List<MusicalElement> elements = [];
    if (json['elements'] != null) {
      for (final elementJson in json['elements']) {
        final element = _parseElementFromMap(elementJson);
        if (element != null) {
          elements.add(element);
        }
      }
    }

    if (elements.isEmpty) return null;

    // TimeSignature padrão (pode ser extraído do contexto)
    final timeSignature = TimeSignature(
      numerator: json['timeSignatureNumerator'] ?? 4,
      denominator: json['timeSignatureDenominator'] ?? 4,
    );

    // Configurações opcionais
    TupletBracket? bracketConfig;
    if (json['bracket'] != null) {
      final bracketJson = json['bracket'];
      bracketConfig = TupletBracket(
        show: bracketJson['show'] ?? true,
        thickness: (bracketJson['thickness'] ?? 0.125).toDouble(),
      );
    }

    TupletNumber? numberConfig;
    if (json['number'] != null) {
      final numberJson = json['number'];
      numberConfig = TupletNumber(
        showAsRatio: numberJson['showAsRatio'] ?? false,
        fontSize: (numberJson['fontSize'] ?? 1.0).toDouble(),
        showNoteValue: numberJson['showNoteValue'] ?? false,
      );
    }

    return Tuplet(
      actualNotes: actualNotes,
      normalNotes: normalNotes,
      elements: elements,
      timeSignature: timeSignature,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
    );
  }

  // === NOVOS PARSERS: GRACE NOTES ===

  static Note? _parseGraceNoteFromMap(Map<String, dynamic> json) {
    final pitchJson = json['pitch'] ?? {};
    final pitch = Pitch(
      step: pitchJson['step'] ?? 'C',
      octave: pitchJson['octave'] ?? 4,
      alter: pitchJson['alter']?.toDouble() ?? 0.0,
    );

    final durationJson = json['duration'] ?? {};
    final duration = Duration(
      _parseDurationType(durationJson['type'] ?? 'eighth'),
      dots: durationJson['dots'] ?? 0,
    );

    // Grace notes são notas pequenas decorativas
    // TODO: Adicionar campo 'isGraceNote' na classe Note se necessário
    return Note(
      pitch: pitch,
      duration: duration,
    );
  }

  // === NOVOS PARSERS: ORNAMENTOS ===

  static Ornament? _parseOrnamentFromMap(Map<String, dynamic> json) {
    final String ornamentTypeString = json['ornamentType'] ?? 'trill';
    final OrnamentType ornamentType = _parseOrnamentType(ornamentTypeString);

    return Ornament(
      type: ornamentType,
      above: json['above'] ?? true,
      text: json['text'],
    );
  }

  static OrnamentType _parseOrnamentType(String type) {
    switch (type) {
      case 'trill': return OrnamentType.trill;
      case 'trillSharp': return OrnamentType.trillSharp;
      case 'trillFlat': return OrnamentType.trillFlat;
      case 'trillNatural': return OrnamentType.trillNatural;
      case 'turn': return OrnamentType.turn;
      case 'invertedTurn': return OrnamentType.invertedTurn;
      case 'turnInverted': return OrnamentType.turnInverted;
      case 'mordent': return OrnamentType.mordent;
      case 'invertedMordent': return OrnamentType.invertedMordent;
      case 'shortTrill': return OrnamentType.shortTrill;
      case 'fermata': return OrnamentType.fermata;
      case 'fermataBelow': return OrnamentType.fermataBelow;
      case 'acciaccatura': return OrnamentType.acciaccatura;
      case 'glissando': return OrnamentType.glissando;
      case 'portamento': return OrnamentType.portamento;
      case 'pralltriller': return OrnamentType.pralltriller;
      default: return OrnamentType.trill;
    }
  }

  // === NOVOS PARSERS: TIE E SLUR TYPES ===

  static TieType _parseTieType(dynamic value) {
    if (value is String) {
      switch (value) {
        case 'start': return TieType.start;
        case 'stop':
        case 'end': return TieType.end;
        default: return TieType.start;
      }
    }
    return TieType.start;
  }

  static SlurType _parseSlurType(dynamic value) {
    if (value is String) {
      switch (value) {
        case 'start': return SlurType.start;
        case 'stop':
        case 'end': return SlurType.end;
        default: return SlurType.start;
      }
    }
    return SlurType.start;
  }

  static Rest _parseRestFromMap(Map<String, dynamic> json) {
    final durationJson = json['duration'] ?? {};
    final duration = Duration(
      _parseDurationType(durationJson['type'] ?? 'quarter'),
      dots: durationJson['dots'] ?? 0,
    );
    return Rest(duration: duration);
  }

  static Barline _parseBarlineFromMap(Map<String, dynamic> json) {
    final String barlineTypeString = json['barlineType'] ?? 'single';
    final BarlineType barlineType = _parseBarlineType(barlineTypeString);
    return Barline(type: barlineType);
  }

  static BarlineType _parseBarlineType(String type) {
    switch (type) {
      case 'single':
        return BarlineType.single;
      case 'double':
        return BarlineType.double;
      case 'final_':
        return BarlineType.final_;
      case 'heavy':
        return BarlineType.heavy;
      case 'repeatForward':
        return BarlineType.repeatForward;
      case 'repeatBackward':
        return BarlineType.repeatBackward;
      case 'repeatBoth':
        return BarlineType.repeatBoth;
      case 'dashed':
        return BarlineType.dashed;
      case 'tick':
        return BarlineType.tick;
      case 'short_':
        return BarlineType.short_;
      case 'lightLight':
        return BarlineType.lightLight;
      case 'lightHeavy':
        return BarlineType.lightHeavy;
      case 'heavyLight':
        return BarlineType.heavyLight;
      case 'heavyHeavy':
        return BarlineType.heavyHeavy;
      case 'none':
        return BarlineType.none;
      default:
        return BarlineType.single;
    }
  }

  static DurationType _parseDurationType(String type) {
    switch (type) {
      case 'whole':
        return DurationType.whole;
      case 'half':
        return DurationType.half;
      case 'quarter':
        return DurationType.quarter;
      case 'eighth':
        return DurationType.eighth;
      case 'sixteenth':
        return DurationType.sixteenth;
      default:
        return DurationType.quarter;
    }
  }

  // === PARSERS PARA ELEMENTOS ADICIONAIS ===

  static Dynamic _parseDynamicFromMap(Map<String, dynamic> json) {
    final String dynamicTypeString = json['dynamicType'] ?? 'mezzoForte';
    final DynamicType dynamicType = _parseDynamicType(dynamicTypeString);
    
    return Dynamic(
      type: dynamicType,
      customText: json['customText'],
      isHairpin: json['isHairpin'] ?? false,
      length: (json['length'] ?? 0.0).toDouble(),
    );
  }

  static DynamicType _parseDynamicType(String type) {
    switch (type) {
      case 'pianissimo': return DynamicType.pianissimo;
      case 'piano': return DynamicType.piano;
      case 'mezzoPiano': return DynamicType.mezzoPiano;
      case 'mezzoForte': return DynamicType.mezzoForte;
      case 'forte': return DynamicType.forte;
      case 'fortissimo': return DynamicType.fortissimo;
      case 'sforzando': return DynamicType.sforzando;
      case 'crescendo': return DynamicType.crescendo;
      case 'diminuendo': return DynamicType.diminuendo;
      case 'pp': return DynamicType.pp;
      case 'p': return DynamicType.p;
      case 'mp': return DynamicType.mp;
      case 'mf': return DynamicType.mf;
      case 'f': return DynamicType.f;
      case 'ff': return DynamicType.ff;
      default: return DynamicType.mezzoForte;
    }
  }

  static TempoMark _parseTempoFromMap(Map<String, dynamic> json) {
    return TempoMark(
      text: json['text'],
      beatUnit: _parseDurationType(json['beatUnit'] ?? 'quarter'),
      bpm: json['bpm'],
    );
  }

  static Breath _parseBreathFromMap(Map<String, dynamic> json) {
    final String breathTypeString = json['breathType'] ?? 'comma';
    return Breath(type: _parseBreathType(breathTypeString));
  }

  static BreathType _parseBreathType(String type) {
    switch (type) {
      case 'comma': return BreathType.comma;
      case 'tick': return BreathType.tick;
      case 'upbow': return BreathType.upbow;
      case 'caesura': return BreathType.caesura;
      default: return BreathType.comma;
    }
  }

  static Chord _parseChordFromMap(Map<String, dynamic> json) {
    final durationJson = json['duration'] ?? {};
    final duration = Duration(
      _parseDurationType(durationJson['type'] ?? 'quarter'),
      dots: durationJson['dots'] ?? 0,
    );

    final List<Note> notes = [];
    if (json['notes'] != null) {
      for (final noteJson in json['notes']) {
        final pitch = Pitch(
          step: noteJson['step'] ?? 'C',
          octave: noteJson['octave'] ?? 4,
          alter: noteJson['alter']?.toDouble() ?? 0.0,
        );
        notes.add(Note(pitch: pitch, duration: duration));
      }
    }

    // Parse articulations
    List<ArticulationType> articulations = [];
    if (json['articulations'] != null) {
      for (final articulation in json['articulations']) {
        switch (articulation) {
          case 'staccato':
            articulations.add(ArticulationType.staccato);
            break;
          case 'accent':
            articulations.add(ArticulationType.accent);
            break;
          case 'tenuto':
            articulations.add(ArticulationType.tenuto);
            break;
          case 'marcato':
            articulations.add(ArticulationType.marcato);
            break;
        }
      }
    }

    return Chord(
      notes: notes,
      duration: duration,
      articulations: articulations,
    );
  }

  static MusicText _parseTextFromMap(Map<String, dynamic> json) {
    final String textTypeString = json['textType'] ?? 'expression';
    final TextType textType = _parseTextType(textTypeString);
    
    final String placementString = json['placement'] ?? 'above';
    final TextPlacement placement = _parseTextPlacement(placementString);

    return MusicText(
      text: json['text'] ?? '',
      type: textType,
      placement: placement,
      fontSize: (json['fontSize'] ?? 12.0).toDouble(),
    );
  }

  static TextType _parseTextType(String type) {
    switch (type) {
      case 'expression': return TextType.expression;
      case 'instruction': return TextType.instruction;
      case 'lyrics': return TextType.lyrics;
      case 'rehearsal': return TextType.rehearsal;
      case 'chord': return TextType.chord;
      case 'tempo': return TextType.tempo;
      case 'dynamics': return TextType.dynamics;
      case 'title': return TextType.title;
      case 'subtitle': return TextType.subtitle;
      case 'composer': return TextType.composer;
      default: return TextType.expression;
    }
  }

  static TextPlacement _parseTextPlacement(String placement) {
    switch (placement) {
      case 'above': return TextPlacement.above;
      case 'below': return TextPlacement.below;
      case 'inside': return TextPlacement.inside;
      default: return TextPlacement.above;
    }
  }

  /// Converte um Staff para JSON
  static String staffToJson(Staff staff) {
    final Map<String, dynamic> json = {
      'measures': staff.measures.map((measure) => _measureToMap(measure)).toList(),
    };
    return jsonEncode(json);
  }

  static Map<String, dynamic> _measureToMap(Measure measure) {
    return {
      'elements': measure.elements.map((element) => _elementToMap(element)).toList(),
    };
  }

  static Map<String, dynamic> _elementToMap(MusicalElement element) {
    if (element is Clef) {
      return {'type': 'clef', 'clefType': element.actualClefType.name};
    } else if (element is KeySignature) {
      return {'type': 'keySignature', 'count': element.count};
    } else if (element is TimeSignature) {
      return {
        'type': 'timeSignature',
        'numerator': element.numerator,
        'denominator': element.denominator,
      };
    } else if (element is Note) {
      return _noteToMap(element);
    } else if (element is Rest) {
      return _restToMap(element);
    } else if (element is Tuplet) {
      return _tupletToMap(element);
    }
    return {'type': 'unknown'};
  }

  static Map<String, dynamic> _noteToMap(Note note) {
    return {
      'type': 'note',
      'pitch': {
        'step': note.pitch.step,
        'octave': note.pitch.octave,
        'alter': note.pitch.alter,
      },
      'duration': {
        'type': _durationTypeToString(note.duration.type),
        'dots': note.duration.dots,
      },
      'articulations': note.articulations.map((a) => _articulationToString(a)).toList(),
      if (note.tie != null) 'tie': _tieTypeToString(note.tie!),
      if (note.slur != null) 'slur': _slurTypeToString(note.slur!),
      if (note.ornaments.isNotEmpty) 'ornaments': note.ornaments.map((o) => {
        'ornamentType': _ornamentTypeToString(o.type),
        'above': o.above,
        if (o.text != null) 'text': o.text,
      }).toList(),
    };
  }

  static Map<String, dynamic> _tupletToMap(Tuplet tuplet) {
    return {
      'type': 'tuplet',
      'actualNotes': tuplet.actualNotes,
      'normalNotes': tuplet.normalNotes,
      'elements': tuplet.elements.map((e) => _elementToMap(e)).toList(),
      if (tuplet.bracketConfig != null) 'bracket': {
        'show': tuplet.bracketConfig!.show,
        'thickness': tuplet.bracketConfig!.thickness,
      },
      if (tuplet.numberConfig != null) 'number': {
        'showAsRatio': tuplet.numberConfig!.showAsRatio,
        'fontSize': tuplet.numberConfig!.fontSize,
        'showNoteValue': tuplet.numberConfig!.showNoteValue,
      },
    };
  }

  static String _tieTypeToString(TieType type) {
    switch (type) {
      case TieType.start: return 'start';
      case TieType.end: return 'end';
    }
  }

  static String _slurTypeToString(SlurType type) {
    switch (type) {
      case SlurType.start: return 'start';
      case SlurType.end: return 'end';
    }
  }

  static String _ornamentTypeToString(OrnamentType type) {
    switch (type) {
      case OrnamentType.trill: return 'trill';
      case OrnamentType.trillSharp: return 'trillSharp';
      case OrnamentType.trillFlat: return 'trillFlat';
      case OrnamentType.trillNatural: return 'trillNatural';
      case OrnamentType.turn: return 'turn';
      case OrnamentType.invertedTurn: return 'invertedTurn';
      case OrnamentType.turnInverted: return 'turnInverted';
      case OrnamentType.turnSlash: return 'turnSlash';
      case OrnamentType.mordent: return 'mordent';
      case OrnamentType.invertedMordent: return 'invertedMordent';
      case OrnamentType.shortTrill: return 'shortTrill';
      case OrnamentType.fermata: return 'fermata';
      case OrnamentType.fermataBelow: return 'fermataBelow';
      case OrnamentType.fermataBelowInverted: return 'fermataBelowInverted';
      case OrnamentType.acciaccatura: return 'acciaccatura';
      case OrnamentType.appoggiaturaUp: return 'appoggiaturaUp';
      case OrnamentType.appoggiaturaDown: return 'appoggiaturaDown';
      case OrnamentType.glissando: return 'glissando';
      case OrnamentType.portamento: return 'portamento';
      case OrnamentType.slide: return 'slide';
      case OrnamentType.scoop: return 'scoop';
      case OrnamentType.fall: return 'fall';
      case OrnamentType.doit: return 'doit';
      case OrnamentType.plop: return 'plop';
      case OrnamentType.bend: return 'bend';
      case OrnamentType.shake: return 'shake';
      case OrnamentType.wavyLine: return 'wavyLine';
      case OrnamentType.zigzagLine: return 'zigzagLine';
      case OrnamentType.schleifer: return 'schleifer';
      case OrnamentType.mordentUpperPrefix: return 'mordentUpperPrefix';
      case OrnamentType.mordentLowerPrefix: return 'mordentLowerPrefix';
      case OrnamentType.trillLigature: return 'trillLigature';
      case OrnamentType.haydn: return 'haydn';
      case OrnamentType.zigZagLineNoRightEnd: return 'zigZagLineNoRightEnd';
      case OrnamentType.zigZagLineWithRightEnd: return 'zigZagLineWithRightEnd';
      case OrnamentType.arpeggio: return 'arpeggio';
      case OrnamentType.grace: return 'grace';
      case OrnamentType.pralltriller: return 'pralltriller';
      case OrnamentType.mordentWithUpperPrefix: return 'mordentWithUpperPrefix';
      case OrnamentType.slideUp: return 'slideUp';
      case OrnamentType.slideDown: return 'slideDown';
      case OrnamentType.doubleTongue: return 'doubleTongue';
      case OrnamentType.tripleTongue: return 'tripleTongue';
    }
  }

  static Map<String, dynamic> _restToMap(Rest rest) {
    return {
      'type': 'rest',
      'duration': {
        'type': _durationTypeToString(rest.duration.type),
      },
    };
  }

  static String _durationTypeToString(DurationType type) {
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
        return 'thirtySecond';
      case DurationType.sixtyFourth:
        return 'sixtyFourth';
      case DurationType.oneHundredTwentyEighth:
        return 'oneHundredTwentyEighth';
    }
  }

  static String _articulationToString(ArticulationType type) {
    switch (type) {
      case ArticulationType.staccato:
        return 'staccato';
      case ArticulationType.staccatissimo:
        return 'staccatissimo';
      case ArticulationType.accent:
        return 'accent';
      case ArticulationType.strongAccent:
        return 'strongAccent';
      case ArticulationType.tenuto:
        return 'tenuto';
      case ArticulationType.marcato:
        return 'marcato';
      case ArticulationType.legato:
        return 'legato';
      case ArticulationType.portato:
        return 'portato';
      case ArticulationType.upBow:
        return 'upBow';
      case ArticulationType.downBow:
        return 'downBow';
      case ArticulationType.harmonics:
        return 'harmonics';
      case ArticulationType.pizzicato:
        return 'pizzicato';
      case ArticulationType.snap:
        return 'snap';
      case ArticulationType.thumb:
        return 'thumb';
      case ArticulationType.stopped:
        return 'stopped';
      case ArticulationType.open:
        return 'open';
      case ArticulationType.halfStopped:
        return 'halfStopped';
    }
  }
}