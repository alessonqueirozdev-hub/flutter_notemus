// lib/src/parsers/musicxml_parser.dart

import 'package:xml/xml.dart';
import '../../core/core.dart'; // 🆕 Tipos do core

/// Parser robusto e otimizado para MusicXML
class MusicXMLParser {
  /// Converte MusicXML para objetos musicais
  static Staff parseMusicXML(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    return _parseScore(document);
  }

  /// Parse do elemento principal score-partwise ou score-timewise
  static Staff _parseScore(XmlDocument document) {
    final staff = Staff();

    // Suporte para score-partwise (mais comum)
    final scorePartwise = document.findElements('score-partwise').firstOrNull;
    if (scorePartwise != null) {
      return _parseScorePartwise(scorePartwise);
    }

    // Suporte para score-timewise
    final scoreTimewise = document.findElements('score-timewise').firstOrNull;
    if (scoreTimewise != null) {
      return _parseScoreTimewise(scoreTimewise);
    }

    return staff;
  }

  /// Parse de score-partwise (organizado por partes)
  static Staff _parseScorePartwise(XmlElement scorePartwise) {
    final staff = Staff();

    // Pega a primeira parte por simplicidade
    final part = scorePartwise.findElements('part').firstOrNull;
    if (part == null) return staff;

    // Processa cada measure
    for (final measureElement in part.findElements('measure')) {
      final measure = _parseMeasure(measureElement);
      staff.add(measure);
    }

    return staff;
  }

  /// Parse de score-timewise (organizado por tempo)
  static Staff _parseScoreTimewise(XmlElement scoreTimewise) {
    final staff = Staff();

    // Para score-timewise, organizamos por measure primeiro
    for (final measureElement in scoreTimewise.findElements('measure')) {
      final measure = Measure();

      // Processa todas as partes neste measure
      for (final partElement in measureElement.findElements('part')) {
        _processPartInMeasure(partElement, measure);
      }

      staff.add(measure);
    }

    return staff;
  }

  /// Processa um measure (compasso)
  static Measure _parseMeasure(XmlElement measureElement) {
    final measure = Measure();

    for (final child in measureElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'attributes':
          _parseAttributes(child, measure);
          break;
        case 'note':
          final note = _parseNote(child);
          if (note != null) measure.add(note);
          break;
        case 'rest':
          final rest = _parseRest(child);
          if (rest != null) measure.add(rest);
          break;
        case 'backup':
          // Implementar backup se necessário
          break;
        case 'forward':
          // Implementar forward se necessário
          break;
        case 'direction':
          final direction = _parseDirection(child);
          if (direction != null) measure.add(direction);
          break;
        case 'harmony':
          // Implementar acordes se necessário
          break;
        case 'barline':
          final barline = _parseBarline(child);
          if (barline != null) measure.add(barline);
          break;
      }
    }

    return measure;
  }

  /// Processa uma parte dentro de um measure (para score-timewise)
  static void _processPartInMeasure(XmlElement partElement, Measure measure) {
    for (final child in partElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'note':
          final note = _parseNote(child);
          if (note != null) measure.add(note);
          break;
        case 'rest':
          final rest = _parseRest(child);
          if (rest != null) measure.add(rest);
          break;
        // Adicionar outros elementos conforme necessário
      }
    }
  }

  /// Parse de atributos (clave, armadura, fórmula de compasso)
  static void _parseAttributes(XmlElement attributesElement, Measure measure) {
    for (final child in attributesElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'clef':
          final clef = _parseClef(child);
          if (clef != null) measure.add(clef);
          break;
        case 'key':
          final keySignature = _parseKeySignature(child);
          if (keySignature != null) measure.add(keySignature);
          break;
        case 'time':
          final timeSignature = _parseTimeSignature(child);
          if (timeSignature != null) measure.add(timeSignature);
          break;
      }
    }
  }

  /// Parse de clave
  static Clef? _parseClef(XmlElement clefElement) {
    final sign = clefElement.findElements('sign').firstOrNull?.innerText;

    String clefType = 'g'; // Padrão

    if (sign != null) {
      switch (sign.toLowerCase()) {
        case 'g':
          clefType = 'g';
          break;
        case 'f':
          clefType = 'f';
          break;
        case 'c':
          clefType = 'c';
          break;
        case 'percussion':
          clefType = 'percussion';
          break;
        case 'tab':
          clefType = 'tab';
          break;
      }
    }

    return Clef(type: clefType);
  }

  /// Parse de armadura de clave
  static KeySignature? _parseKeySignature(XmlElement keyElement) {
    final fifthsElement = keyElement.findElements('fifths').firstOrNull;
    if (fifthsElement == null) return null;

    final fifths = int.tryParse(fifthsElement.innerText) ?? 0;
    return KeySignature(fifths);
  }

  /// Parse de fórmula de compasso
  static TimeSignature? _parseTimeSignature(XmlElement timeElement) {
    final beatsElement = timeElement.findElements('beats').firstOrNull;
    final beatTypeElement = timeElement.findElements('beat-type').firstOrNull;

    if (beatsElement == null || beatTypeElement == null) return null;

    final numerator = int.tryParse(beatsElement.innerText) ?? 4;
    final denominator = int.tryParse(beatTypeElement.innerText) ?? 4;

    return TimeSignature(numerator: numerator, denominator: denominator);
  }

  /// Parse de nota
  static Note? _parseNote(XmlElement noteElement) {
    // Parse da altura
    final pitchElement = noteElement.findElements('pitch').firstOrNull;
    if (pitchElement == null) return null;

    final pitch = _parsePitch(pitchElement);
    if (pitch == null) return null;

    // Parse da duração
    final durationElement = noteElement.findElements('duration').firstOrNull;
    final typeElement = noteElement.findElements('type').firstOrNull;

    final duration = _parseDuration(durationElement, typeElement);

    // Parse de articulações
    final articulations = _parseArticulations(noteElement);

    // Parse de tie
    TieType? tie;
    final tieElements = noteElement.findElements('tie');
    for (final tieElement in tieElements) {
      final type = tieElement.getAttribute('type');
      if (type == 'start') {
        tie = TieType.start;
      } else if (type == 'stop') {
        tie = TieType.end;
      }
    }

    // Parse de slur
    SlurType? slur;
    final slurElements = noteElement.findElements('slur');
    for (final slurElement in slurElements) {
      final type = slurElement.getAttribute('type');
      if (type == 'start') {
        slur = SlurType.start;
      } else if (type == 'stop') {
        slur = SlurType.end;
      }
    }

    return Note(
      pitch: pitch,
      duration: duration,
      articulations: articulations,
      tie: tie,
      slur: slur,
    );
  }

  /// Parse de altura (pitch)
  static Pitch? _parsePitch(XmlElement pitchElement) {
    final stepElement = pitchElement.findElements('step').firstOrNull;
    final octaveElement = pitchElement.findElements('octave').firstOrNull;
    final alterElement = pitchElement.findElements('alter').firstOrNull;

    if (stepElement == null || octaveElement == null) return null;

    final step = stepElement.innerText;
    final octave = int.tryParse(octaveElement.innerText) ?? 4;
    final alter = double.tryParse(alterElement?.innerText ?? '0') ?? 0.0;

    return Pitch(step: step, octave: octave, alter: alter);
  }

  /// Parse de duração
  static Duration _parseDuration(
    XmlElement? durationElement,
    XmlElement? typeElement,
  ) {
    DurationType durationType = DurationType.quarter; // Padrão

    if (typeElement != null) {
      final typeText = typeElement.innerText;
      switch (typeText) {
        case 'whole':
          durationType = DurationType.whole;
          break;
        case 'half':
          durationType = DurationType.half;
          break;
        case 'quarter':
          durationType = DurationType.quarter;
          break;
        case 'eighth':
          durationType = DurationType.eighth;
          break;
        case '16th':
          durationType = DurationType.sixteenth;
          break;
        case '32nd':
          durationType = DurationType.thirtySecond;
          break;
        case '64th':
          durationType = DurationType.sixtyFourth;
          break;
      }
    }

    return Duration(durationType);
  }

  /// Parse de articulações
  static List<ArticulationType> _parseArticulations(XmlElement noteElement) {
    final articulations = <ArticulationType>[];

    final notationsElement = noteElement.findElements('notations').firstOrNull;
    if (notationsElement == null) return articulations;

    final articulationsElement = notationsElement
        .findElements('articulations')
        .firstOrNull;
    if (articulationsElement == null) return articulations;

    for (final child in articulationsElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'staccato':
          articulations.add(ArticulationType.staccato);
          break;
        case 'staccatissimo':
          articulations.add(ArticulationType.staccatissimo);
          break;
        case 'accent':
          articulations.add(ArticulationType.accent);
          break;
        case 'strong-accent':
          articulations.add(ArticulationType.strongAccent);
          break;
        case 'tenuto':
          articulations.add(ArticulationType.tenuto);
          break;
        case 'marcato':
          articulations.add(ArticulationType.marcato);
          break;
        case 'legato':
          articulations.add(ArticulationType.legato);
          break;
        case 'portato':
          articulations.add(ArticulationType.portato);
          break;
        case 'up-bow':
          articulations.add(ArticulationType.upBow);
          break;
        case 'down-bow':
          articulations.add(ArticulationType.downBow);
          break;
        case 'harmonics':
          articulations.add(ArticulationType.harmonics);
          break;
        case 'pizzicato':
          articulations.add(ArticulationType.pizzicato);
          break;
        case 'snap':
          articulations.add(ArticulationType.snap);
          break;
        case 'thumb':
          articulations.add(ArticulationType.thumb);
          break;
        case 'stopped':
          articulations.add(ArticulationType.stopped);
          break;
        case 'open':
          articulations.add(ArticulationType.open);
          break;
        case 'half-stopped':
          articulations.add(ArticulationType.halfStopped);
          break;
      }
    }

    return articulations;
  }

  /// Parse de pausa
  static Rest? _parseRest(XmlElement restElement) {
    final durationElement = restElement.findElements('duration').firstOrNull;
    final typeElement = restElement.findElements('type').firstOrNull;

    final duration = _parseDuration(durationElement, typeElement);
    return Rest(duration: duration);
  }

  /// Parse de direções (dinâmicas, tempos, etc.)
  static MusicalElement? _parseDirection(XmlElement directionElement) {
    final directionTypeElement = directionElement
        .findElements('direction-type')
        .firstOrNull;
    if (directionTypeElement == null) return null;

    // Parse de dinâmicas
    final dynamicsElement = directionTypeElement
        .findElements('dynamics')
        .firstOrNull;
    if (dynamicsElement != null) {
      return _parseDynamics(dynamicsElement);
    }

    // Parse de texto
    final wordsElement = directionTypeElement.findElements('words').firstOrNull;
    if (wordsElement != null) {
      return MusicText(text: wordsElement.innerText, type: TextType.expression);
    }

    // Parse de metrônomo
    final metronomeElement = directionTypeElement
        .findElements('metronome')
        .firstOrNull;
    if (metronomeElement != null) {
      return _parseMetronome(metronomeElement);
    }

    return null;
  }

  /// Parse de dinâmicas
  static Dynamic? _parseDynamics(XmlElement dynamicsElement) {
    for (final child in dynamicsElement.children.whereType<XmlElement>()) {
      DynamicType? type;
      switch (child.name.local) {
        case 'p':
          type = DynamicType.piano;
          break;
        case 'pp':
          type = DynamicType.pianissimo;
          break;
        case 'ppp':
          type = DynamicType.pianississimo;
          break;
        case 'f':
          type = DynamicType.forte;
          break;
        case 'ff':
          type = DynamicType.fortissimo;
          break;
        case 'fff':
          type = DynamicType.fortississimo;
          break;
        case 'mp':
          type = DynamicType.mezzoPiano;
          break;
        case 'mf':
          type = DynamicType.mezzoForte;
          break;
        case 'sf':
        case 'sfz':
          type = DynamicType.sforzando;
          break;
      }

      if (type != null) {
        return Dynamic(type: type);
      }
    }

    return null;
  }

  /// Parse de metrônomo
  static TempoMark? _parseMetronome(XmlElement metronomeElement) {
    final beatUnitElement = metronomeElement
        .findElements('beat-unit')
        .firstOrNull;
    final perMinuteElement = metronomeElement
        .findElements('per-minute')
        .firstOrNull;

    if (beatUnitElement == null || perMinuteElement == null) return null;

    DurationType beatUnit = DurationType.quarter; // Padrão
    switch (beatUnitElement.innerText) {
      case 'whole':
        beatUnit = DurationType.whole;
        break;
      case 'half':
        beatUnit = DurationType.half;
        break;
      case 'quarter':
        beatUnit = DurationType.quarter;
        break;
      case 'eighth':
        beatUnit = DurationType.eighth;
        break;
      case '16th':
        beatUnit = DurationType.sixteenth;
        break;
      case '32nd':
        beatUnit = DurationType.thirtySecond;
        break;
      case '64th':
        beatUnit = DurationType.sixtyFourth;
        break;
    }

    final bpm = int.tryParse(perMinuteElement.innerText);

    return TempoMark(beatUnit: beatUnit, bpm: bpm);
  }

  /// Parse de barra de compasso
  static Barline? _parseBarline(XmlElement barlineElement) {
    // Implementação básica
    return Barline();
  }

  /// Converte objetos musicais para MusicXML
  static String staffToMusicXML(Staff staff) {
    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'score-partwise',
      nest: () {
        builder.attribute('version', '3.1');

        // Part list
        builder.element(
          'part-list',
          nest: () {
            builder.element(
              'score-part',
              nest: () {
                builder.attribute('id', 'P1');
                builder.element('part-name', nest: 'Music');
              },
            );
          },
        );

        // Part
        builder.element(
          'part',
          nest: () {
            builder.attribute('id', 'P1');

            int measureNumber = 1;
            for (final measure in staff.measures) {
              _buildMeasureXML(builder, measure, measureNumber++);
            }
          },
        );
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Constrói XML para um measure
  static void _buildMeasureXML(
    XmlBuilder builder,
    Measure measure,
    int number,
  ) {
    builder.element(
      'measure',
      nest: () {
        builder.attribute('number', number.toString());

        bool firstElement = true;
        for (final element in measure.elements) {
          if (element is Clef ||
              element is KeySignature ||
              element is TimeSignature) {
            if (firstElement) {
              builder.element(
                'attributes',
                nest: () {
                  _buildAttributesXML(builder, measure);
                },
              );
              firstElement = false;
            }
          } else if (element is Note) {
            _buildNoteXML(builder, element);
          } else if (element is Rest) {
            _buildRestXML(builder, element);
          } else if (element is Dynamic) {
            _buildDynamicXML(builder, element);
          } else if (element is TempoMark) {
            _buildTempoXML(builder, element);
          }
        }
      },
    );
  }

  /// Constrói XML para atributos
  static void _buildAttributesXML(XmlBuilder builder, Measure measure) {
    for (final element in measure.elements) {
      if (element is Clef) {
        builder.element(
          'clef',
          nest: () {
            final clefSign = element.actualClefType.name.startsWith('treble') ? 'G' :
                           element.actualClefType.name.startsWith('bass') ? 'F' : 'C';
            final clefLine = element.actualClefType.name.startsWith('treble') ? '2' :
                           element.actualClefType.name.startsWith('bass') ? '4' : '3';
            builder.element('sign', nest: clefSign);
            builder.element('line', nest: clefLine);
          },
        );
      } else if (element is KeySignature) {
        builder.element(
          'key',
          nest: () {
            builder.element('fifths', nest: element.count.toString());
          },
        );
      } else if (element is TimeSignature) {
        builder.element(
          'time',
          nest: () {
            builder.element('beats', nest: element.numerator.toString());
            builder.element('beat-type', nest: element.denominator.toString());
          },
        );
      }
    }
  }

  /// Constrói XML para nota
  static void _buildNoteXML(XmlBuilder builder, Note note) {
    builder.element(
      'note',
      nest: () {
        // Pitch
        builder.element(
          'pitch',
          nest: () {
            builder.element('step', nest: note.pitch.step);
            if (note.pitch.alter != 0) {
              builder.element('alter', nest: note.pitch.alter.toString());
            }
            builder.element('octave', nest: note.pitch.octave.toString());
          },
        );

        // Duration
        builder.element('duration', nest: '1'); // Simplificado
        builder.element(
          'type',
          nest: _durationTypeToString(note.duration.type),
        );

        // Articulações
        if (note.articulations.isNotEmpty) {
          builder.element(
            'notations',
            nest: () {
              builder.element(
                'articulations',
                nest: () {
                  for (final articulation in note.articulations) {
                    builder.element(_articulationToString(articulation));
                  }
                },
              );
            },
          );
        }

        // Tie
        if (note.tie != null) {
          final tieType = note.tie == TieType.start ? 'start' : 'stop';
          builder.element(
            'tie',
            nest: () {
              builder.attribute('type', tieType);
            },
          );
        }

        // Slur
        if (note.slur != null) {
          builder.element(
            'notations',
            nest: () {
              final slurType = note.slur == SlurType.start ? 'start' : 'stop';
              builder.element(
                'slur',
                nest: () {
                  builder.attribute('type', slurType);
                },
              );
            },
          );
        }
      },
    );
  }

  /// Constrói XML para pausa
  static void _buildRestXML(XmlBuilder builder, Rest rest) {
    builder.element(
      'note',
      nest: () {
        builder.element('rest');
        builder.element('duration', nest: '1'); // Simplificado
        builder.element(
          'type',
          nest: _durationTypeToString(rest.duration.type),
        );
      },
    );
  }

  /// Constrói XML para dinâmica
  static void _buildDynamicXML(XmlBuilder builder, Dynamic dynamic) {
    builder.element(
      'direction',
      nest: () {
        builder.element(
          'direction-type',
          nest: () {
            builder.element(
              'dynamics',
              nest: () {
                builder.element(_dynamicTypeToString(dynamic.type));
              },
            );
          },
        );
      },
    );
  }

  /// Constrói XML para tempo
  static void _buildTempoXML(XmlBuilder builder, TempoMark tempo) {
    builder.element(
      'direction',
      nest: () {
        builder.element(
          'direction-type',
          nest: () {
            if (tempo.bpm != null) {
              builder.element(
                'metronome',
                nest: () {
                  builder.element(
                    'beat-unit',
                    nest: _durationTypeToString(tempo.beatUnit),
                  );
                  builder.element('per-minute', nest: tempo.bpm.toString());
                },
              );
            }
            if (tempo.text != null) {
              builder.element('words', nest: tempo.text);
            }
          },
        );
      },
    );
  }

  // Métodos utilitários para conversão
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
        return '16th';
      case DurationType.thirtySecond:
        return '32nd';
      case DurationType.sixtyFourth:
        return '64th';
      case DurationType.oneHundredTwentyEighth:
        return '128th';
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
        return 'strong-accent';
      case ArticulationType.tenuto:
        return 'tenuto';
      case ArticulationType.marcato:
        return 'marcato';
      case ArticulationType.legato:
        return 'legato';
      case ArticulationType.portato:
        return 'portato';
      case ArticulationType.upBow:
        return 'up-bow';
      case ArticulationType.downBow:
        return 'down-bow';
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
        return 'half-stopped';
    }
  }

  static String _dynamicTypeToString(DynamicType type) {
    switch (type) {
      case DynamicType.piano:
        return 'p';
      case DynamicType.pianissimo:
        return 'pp';
      case DynamicType.pianississimo:
        return 'ppp';
      case DynamicType.forte:
        return 'f';
      case DynamicType.fortissimo:
        return 'ff';
      case DynamicType.fortississimo:
        return 'fff';
      case DynamicType.mezzoPiano:
        return 'mp';
      case DynamicType.mezzoForte:
        return 'mf';
      case DynamicType.sforzando:
        return 'sf';
      default:
        return 'mf';
    }
  }

  // Método para validar estrutura MusicXML
  static bool validateMusicXML(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;

      // Verifica se é score-partwise ou score-timewise
      if (root.name.local != 'score-partwise' &&
          root.name.local != 'score-timewise') {
        return false;
      }

      // Verifica elementos obrigatórios
      final partList = root.findElements('part-list').firstOrNull;
      if (partList == null) return false;

      final parts = root.findElements('part');
      if (parts.isEmpty) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  // Método para extrair metadados do MusicXML
  static Map<String, dynamic> extractMetadata(String xmlContent) {
    final metadata = <String, dynamic>{};

    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;

      // Título da obra
      final workTitle = root
          .findElements('work')
          .expand((e) => e.findElements('work-title'))
          .firstOrNull
          ?.innerText;
      if (workTitle != null) metadata['title'] = workTitle;

      // Compositor
      final composer = root
          .findElements('identification')
          .expand((e) => e.findElements('creator'))
          .where((e) => e.getAttribute('type') == 'composer')
          .firstOrNull
          ?.innerText;
      if (composer != null) metadata['composer'] = composer;

      // Software
      final software = root
          .findElements('identification')
          .expand((e) => e.findElements('creator'))
          .where((e) => e.getAttribute('type') == 'software')
          .firstOrNull
          ?.innerText;
      if (software != null) metadata['software'] = software;

      // Número de partes
      final partCount = root
          .findElements('part-list')
          .expand((e) => e.findElements('score-part'))
          .length;
      metadata['partCount'] = partCount;

      // Número de compassos (primeira parte)
      final measureCount =
          root
              .findElements('part')
              .firstOrNull
              ?.findElements('measure')
              .length ??
          0;
      metadata['measureCount'] = measureCount;
    } catch (e) {
      metadata['error'] = 'Erro ao extrair metadados: $e';
    }

    return metadata;
  }

  // Método para converter entre formatos MusicXML
  static String convertPartwiseToTimewise(String partwiseXml) {
    final staff = parseMusicXML(partwiseXml);
    return staffToMusicXML(staff); // Por enquanto retorna partwise
  }

  // Método para otimizar XML para tamanho
  static String optimizeXML(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      return document.toXmlString(pretty: false); // Remove espaçamento
    } catch (e) {
      return xmlContent;
    }
  }

  // Método para mesclar múltiplas partes em um arquivo MusicXML
  static String mergeStaffs(List<Staff> staffs) {
    if (staffs.isEmpty) return '';

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'score-partwise',
      nest: () {
        builder.attribute('version', '3.1');

        // Lista de partes
        builder.element(
          'part-list',
          nest: () {
            for (int i = 0; i < staffs.length; i++) {
              builder.element(
                'score-part',
                nest: () {
                  builder.attribute('id', 'P${i + 1}');
                  builder.element('part-name', nest: 'Part ${i + 1}');
                },
              );
            }
          },
        );

        // Partes musicais
        for (int i = 0; i < staffs.length; i++) {
          final staff = staffs[i];
          builder.element(
            'part',
            nest: () {
              builder.attribute('id', 'P${i + 1}');

              for (int j = 0; j < staff.measures.length; j++) {
                _buildMeasureXML(builder, staff.measures[j], j + 1);
              }
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  // Método para obter informações de performance
  static Map<String, dynamic> getPerformanceInfo(String xmlContent) {
    final info = <String, dynamic>{};

    try {
      final document = XmlDocument.parse(xmlContent);
      final startTime = DateTime.now().millisecondsSinceEpoch;

      // Conta elementos
      final allElements = document.descendants.whereType<XmlElement>();
      final noteCount = allElements.where((e) => e.name.local == 'note').length;
      final measureCount = allElements
          .where((e) => e.name.local == 'measure')
          .length;

      final endTime = DateTime.now().millisecondsSinceEpoch;

      info['parseTimeMs'] = endTime - startTime;
      info['noteCount'] = noteCount;
      info['measureCount'] = measureCount;
      info['elementCount'] = allElements.length;
      info['xmlSize'] = xmlContent.length;
    } catch (e) {
      info['error'] = 'Erro ao analisar performance: $e';
    }

    return info;
  }
}
