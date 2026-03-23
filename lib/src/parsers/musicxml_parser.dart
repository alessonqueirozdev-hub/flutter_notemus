import 'package:xml/xml.dart';

import '../../core/core.dart';
import 'parser_support.dart';

/// Parser e utilidades para MusicXML.
class MusicXMLParser {
  /// Converte MusicXML para um [Staff].
  static Staff parseMusicXML(String xmlString, {int partIndex = 0}) {
    return parseMusicXmlStaff(xmlString, partIndex: partIndex);
  }

  /// Converte um [Staff] para MusicXML partwise.
  static String staffToMusicXML(Staff staff) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'score-partwise',
      nest: () {
        builder.attribute('version', '4.0');
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

        builder.element(
          'part',
          nest: () {
            builder.attribute('id', 'P1');
            for (int index = 0; index < staff.measures.length; index++) {
              _buildMeasureXml(builder, staff.measures[index], index + 1);
            }
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  static bool validateMusicXML(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement.name.local;
      return root == 'score-partwise' || root == 'score-timewise';
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> extractMetadata(String xmlContent) {
    final metadata = <String, dynamic>{};
    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;

      metadata['title'] = root
          .findAllElements('work-title')
          .firstOrNull
          ?.innerText;
      metadata['composer'] = root
          .findAllElements('creator')
          .where((e) => e.getAttribute('type') == 'composer')
          .firstOrNull
          ?.innerText;
      metadata['partCount'] = root.findAllElements('part').length;
      metadata['measureCount'] =
          root
              .findAllElements('part')
              .firstOrNull
              ?.findElements('measure')
              .length ??
          0;
    } catch (error) {
      metadata['error'] = error.toString();
    }
    return metadata;
  }

  static String convertPartwiseToTimewise(String partwiseXml) {
    final staff = parseMusicXML(partwiseXml);
    return staffToMusicXML(staff);
  }

  static String optimizeXML(String xmlContent) {
    try {
      return XmlDocument.parse(xmlContent).toXmlString(pretty: false);
    } catch (_) {
      return xmlContent;
    }
  }

  static String mergeStaffs(List<Staff> staffs) {
    if (staffs.isEmpty) return '';

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'score-partwise',
      nest: () {
        builder.attribute('version', '4.0');
        builder.element(
          'part-list',
          nest: () {
            for (int index = 0; index < staffs.length; index++) {
              builder.element(
                'score-part',
                nest: () {
                  builder.attribute('id', 'P${index + 1}');
                  builder.element('part-name', nest: 'Part ${index + 1}');
                },
              );
            }
          },
        );

        for (int index = 0; index < staffs.length; index++) {
          builder.element(
            'part',
            nest: () {
              builder.attribute('id', 'P${index + 1}');
              for (
                int measureIndex = 0;
                measureIndex < staffs[index].measures.length;
                measureIndex++
              ) {
                _buildMeasureXml(
                  builder,
                  staffs[index].measures[measureIndex],
                  measureIndex + 1,
                );
              }
            },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }
}

void _buildMeasureXml(XmlBuilder builder, Measure measure, int number) {
  builder.element(
    'measure',
    nest: () {
      builder.attribute('number', number.toString());

      final systemElements = measure.elements.where(
        (element) =>
            element is Clef ||
            element is KeySignature ||
            element is TimeSignature,
      );

      if (systemElements.isNotEmpty) {
        builder.element(
          'attributes',
          nest: () {
            for (final element in systemElements) {
              if (element is Clef) {
                builder.element(
                  'clef',
                  nest: () {
                    final type = element.actualClefType;
                    final sign = type.name.startsWith('treble')
                        ? 'G'
                        : type.name.startsWith('bass')
                        ? 'F'
                        : 'C';
                    final line = switch (type) {
                      ClefType.soprano => '1',
                      ClefType.mezzoSoprano => '2',
                      ClefType.tenor => '4',
                      ClefType.baritone => '5',
                      ClefType.bassThirdLine => '3',
                      ClefType.bass => '4',
                      _ => '2',
                    };
                    builder.element('sign', nest: sign);
                    builder.element('line', nest: line);
                  },
                );
              } else if (element is KeySignature) {
                builder.element(
                  'key',
                  nest: () => builder.element('fifths', nest: element.count),
                );
              } else if (element is TimeSignature) {
                builder.element(
                  'time',
                  nest: () {
                    builder.element('beats', nest: element.numerator);
                    builder.element('beat-type', nest: element.denominator);
                  },
                );
              }
            }
          },
        );
      }

      for (final element in measure.elements) {
        if (element is Note) {
          _buildNoteXml(builder, element);
        } else if (element is Rest) {
          _buildRestXml(builder, element);
        } else if (element is Chord) {
          for (int index = 0; index < element.notes.length; index++) {
            _buildNoteXml(
              builder,
              element.notes[index],
              isChordTone: index > 0,
            );
          }
        } else if (element is Dynamic) {
          _buildDynamicXml(builder, element);
        } else if (element is TempoMark) {
          _buildTempoXml(builder, element);
        } else if (element is MusicText) {
          builder.element(
            'direction',
            nest: () {
              builder.element(
                'direction-type',
                nest: () => builder.element('words', nest: element.text),
              );
            },
          );
        }
      }
    },
  );
}

void _buildNoteXml(XmlBuilder builder, Note note, {bool isChordTone = false}) {
  builder.element(
    'note',
    nest: () {
      if (isChordTone) {
        builder.element('chord');
      }
      builder.element(
        'pitch',
        nest: () {
          builder.element('step', nest: note.pitch.step);
          if (note.pitch.alter != 0) {
            builder.element('alter', nest: note.pitch.alter);
          }
          builder.element('octave', nest: note.pitch.octave);
        },
      );
      builder.element('duration', nest: '1');
      builder.element('type', nest: _durationTypeToString(note.duration.type));
      for (int index = 0; index < note.duration.dots; index++) {
        builder.element('dot');
      }
      if (note.tie != null) {
        builder.element(
          'tie',
          nest: () => builder.attribute(
            'type',
            note.tie == TieType.end ? 'stop' : 'start',
          ),
        );
      }
      if (note.articulations.isNotEmpty || note.slur != null) {
        builder.element(
          'notations',
          nest: () {
            if (note.slur != null) {
              builder.element(
                'slur',
                nest: () => builder.attribute(
                  'type',
                  note.slur == SlurType.end ? 'stop' : 'start',
                ),
              );
            }
            if (note.articulations.isNotEmpty) {
              builder.element(
                'articulations',
                nest: () {
                  for (final articulation in note.articulations) {
                    builder.element(_articulationToString(articulation));
                  }
                },
              );
            }
          },
        );
      }
    },
  );
}

void _buildRestXml(XmlBuilder builder, Rest rest) {
  builder.element(
    'note',
    nest: () {
      builder.element('rest');
      builder.element('duration', nest: '1');
      builder.element('type', nest: _durationTypeToString(rest.duration.type));
      for (int index = 0; index < rest.duration.dots; index++) {
        builder.element('dot');
      }
    },
  );
}

void _buildDynamicXml(XmlBuilder builder, Dynamic dynamic) {
  builder.element(
    'direction',
    nest: () {
      builder.element(
        'direction-type',
        nest: () {
          builder.element(
            'dynamics',
            nest: () => builder.element(_dynamicTypeToString(dynamic.type)),
          );
        },
      );
    },
  );
}

void _buildTempoXml(XmlBuilder builder, TempoMark tempo) {
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
                builder.element('per-minute', nest: tempo.bpm);
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

String _durationTypeToString(DurationType type) {
  return switch (type) {
    DurationType.maxima => 'maxima',
    DurationType.long => 'long',
    DurationType.breve => 'breve',
    DurationType.whole => 'whole',
    DurationType.half => 'half',
    DurationType.quarter => 'quarter',
    DurationType.eighth => 'eighth',
    DurationType.sixteenth => '16th',
    DurationType.thirtySecond => '32nd',
    DurationType.sixtyFourth => '64th',
    DurationType.oneHundredTwentyEighth => '128th',
    DurationType.twoHundredFiftySixth => '256th',
    DurationType.fiveHundredTwelfth => '512th',
    DurationType.thousandTwentyFourth => '1024th',
    DurationType.twoThousandFortyEighth => '2048th',
  };
}

String _articulationToString(ArticulationType type) {
  return switch (type) {
    ArticulationType.staccato => 'staccato',
    ArticulationType.staccatissimo => 'staccatissimo',
    ArticulationType.accent => 'accent',
    ArticulationType.strongAccent => 'strong-accent',
    ArticulationType.tenuto => 'tenuto',
    ArticulationType.marcato => 'marcato',
    ArticulationType.legato => 'legato',
    ArticulationType.portato => 'portato',
    ArticulationType.upBow => 'up-bow',
    ArticulationType.downBow => 'down-bow',
    ArticulationType.harmonics => 'harmonics',
    ArticulationType.pizzicato => 'pizzicato',
    ArticulationType.snap => 'snap-pizzicato',
    ArticulationType.thumb => 'thumb-position',
    ArticulationType.stopped => 'stopped',
    ArticulationType.open => 'open-string',
    ArticulationType.halfStopped => 'half-muted',
  };
}

String _dynamicTypeToString(DynamicType type) {
  return switch (type) {
    DynamicType.p => 'p',
    DynamicType.pp => 'pp',
    DynamicType.ppp => 'ppp',
    DynamicType.pppp => 'pppp',
    DynamicType.mp => 'mp',
    DynamicType.mf => 'mf',
    DynamicType.f => 'f',
    DynamicType.ff => 'ff',
    DynamicType.fff => 'fff',
    DynamicType.ffff => 'ffff',
    DynamicType.sforzando => 'sfz',
    DynamicType.sforzandoPiano => 'sfp',
    DynamicType.sforzandoPianissimo => 'sfpp',
    DynamicType.rinforzando => 'rfz',
    DynamicType.fortePiano => 'fp',
    _ => 'mf',
  };
}
