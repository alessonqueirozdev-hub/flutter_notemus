import 'package:xml/xml.dart';

import '../../core/core.dart';
import 'parser_support.dart';

/// Parser and utilidades for MusicXML.
class MusicXMLParser {
  /// Converts MusicXML for a [Staff].
  /// Imports every part (and every staff within a part) of a MusicXML document
  /// into a [Score] — multi-part (SATB/ensemble) and multi-staff (piano) scores
  /// no longer collapse onto a single staff.
  static Score scoreFromMusicXML(String xmlString) =>
      parseMusicXmlScore(xmlString);

  static Staff parseMusicXML(String xmlString, {int partIndex = 0}) {
    return parseMusicXmlStaff(xmlString, partIndex: partIndex);
  }

  /// Converts a [Staff] for MusicXML partwise.
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

/// Divisions per quarter note for the exported MusicXML. 480 is divisible by
/// 2/3/4/5/6/8/… so common durations and tuplets map to whole tick counts.
const int _kDivisions = 480;

/// Duration of [d] in MusicXML divisions, optionally scaled by a tuplet factor.
int _durationDivisions(Duration d, [double factor = 1.0]) {
  final v = (d.realValue * 4 * _kDivisions * factor).round();
  return v < 1 ? 1 : v;
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

      // The first measure always carries <divisions>; later measures only emit
      // <attributes> when a clef/key/time actually appears.
      if (number == 1 || systemElements.isNotEmpty) {
        builder.element(
          'attributes',
          nest: () {
            if (number == 1) {
              builder.element('divisions', nest: _kDivisions);
            }
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
                      ClefType.alto => '3',
                      ClefType.tenor || ClefType.c8vb => '4',
                      ClefType.baritone => '5',
                      ClefType.bassThirdLine => '3',
                      // treble family -> line 2 (G), bass family -> line 4 (F).
                      _ => sign == 'G' ? '2' : (sign == 'F' ? '4' : '3'),
                    };
                    // The original clef type (actualClefType collapses octave
                    // variants to treble/bass).
                    final octaveChange = switch (element.clefType) {
                      ClefType.treble8va || ClefType.bass8va => 1,
                      ClefType.treble8vb ||
                      ClefType.bass8vb ||
                      ClefType.c8vb =>
                        -1,
                      ClefType.treble15ma || ClefType.bass15ma => 2,
                      ClefType.treble15mb || ClefType.bass15mb => -2,
                      _ => 0,
                    };
                    builder.element('sign', nest: sign);
                    builder.element('line', nest: line);
                    if (octaveChange != 0) {
                      builder.element('clef-octave-change',
                          nest: octaveChange);
                    }
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

      if (measure is MultiVoiceMeasure) {
        // Emit each voice in turn, backing up the cursor to the measure start
        // between voices (MusicXML polyphony).
        final voices = measure.sortedVoices;
        for (var vi = 0; vi < voices.length; vi++) {
          if (vi > 0) {
            final back = _voiceDurationDivisions(voices[vi - 1]);
            if (back > 0) {
              builder.element('backup',
                  nest: () => builder.element('duration', nest: back));
            }
          }
          for (final element in voices[vi].elements) {
            _buildMeasureElement(builder, element,
                voiceNumber: voices[vi].number);
          }
        }
      } else {
        for (final element in measure.elements) {
          _buildMeasureElement(builder, element);
        }
      }
    },
  );
}

/// Dispatches one measure element to its MusicXML builder, tagging notes with
/// [voiceNumber] when set (multi-voice).
void _buildMeasureElement(XmlBuilder builder, MusicalElement element,
    {int? voiceNumber}) {
  if (element is Note) {
    _buildNoteXml(builder, element, voiceNumber: voiceNumber);
  } else if (element is Rest) {
    _buildRestXml(builder, element, voiceNumber: voiceNumber);
  } else if (element is Chord) {
    for (int index = 0; index < element.notes.length; index++) {
      _buildNoteXml(builder, element.notes[index],
          isChordTone: index > 0, voiceNumber: voiceNumber);
    }
  } else if (element is Tuplet) {
    for (final inner in element.elements) {
      if (inner is Note) {
        _buildNoteXml(builder, inner,
            tuplet: element.ratio, voiceNumber: voiceNumber);
      } else if (inner is Rest) {
        _buildRestXml(builder, inner,
            tuplet: element.ratio, voiceNumber: voiceNumber);
      } else if (inner is Chord) {
        for (int i = 0; i < inner.notes.length; i++) {
          _buildNoteXml(builder, inner.notes[i],
              isChordTone: i > 0,
              tuplet: element.ratio,
              voiceNumber: voiceNumber);
        }
      }
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
  } else if (element is Barline) {
    _buildBarlineXml(builder, element);
  }
}

/// Total sounding duration of a voice in MusicXML divisions (for `backup`).
int _voiceDurationDivisions(Voice voice) {
  var total = 0;
  void add(MusicalElement el, [double factor = 1.0]) {
    if (el is Note && !el.isGraceNote) {
      total += _durationDivisions(el.duration, factor);
    } else if (el is Rest) {
      total += _durationDivisions(el.duration, factor);
    } else if (el is Chord) {
      total += _durationDivisions(el.duration, factor);
    } else if (el is Tuplet) {
      for (final inner in el.elements) {
        add(inner, el.ratio.modifier);
      }
    }
  }

  for (final el in voice.elements) {
    add(el);
  }
  return total;
}

void _buildBarlineXml(XmlBuilder builder, Barline barline) {
  if (barline.type == BarlineType.single) return; // implicit between measures
  final repeatDir = switch (barline.type) {
    BarlineType.repeatForward => 'forward',
    BarlineType.repeatBackward || BarlineType.repeatBoth => 'backward',
    _ => null,
  };
  final barStyle = switch (barline.type) {
    BarlineType.double || BarlineType.lightLight => 'light-light',
    BarlineType.final_ ||
    BarlineType.lightHeavy ||
    BarlineType.repeatBackward ||
    BarlineType.repeatBoth =>
      'light-heavy',
    BarlineType.repeatForward || BarlineType.heavyLight => 'heavy-light',
    BarlineType.heavyHeavy => 'heavy-heavy',
    BarlineType.dashed => 'dashed',
    BarlineType.heavy => 'heavy',
    BarlineType.tick => 'tick',
    BarlineType.short_ => 'short',
    BarlineType.none => 'none',
    BarlineType.single => 'regular',
  };
  builder.element(
    'barline',
    nest: () {
      builder.attribute('location', repeatDir == 'forward' ? 'left' : 'right');
      builder.element('bar-style', nest: barStyle);
      if (repeatDir != null) {
        builder.element(
          'repeat',
          nest: () => builder.attribute('direction', repeatDir),
        );
      }
    },
  );
}

void _buildNoteXml(XmlBuilder builder, Note note,
    {bool isChordTone = false, TupletRatio? tuplet, int? voiceNumber}) {
  builder.element(
    'note',
    nest: () {
      if (note.isGraceNote) {
        builder.element('grace');
      }
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
      // Grace notes carry no <duration> in MusicXML.
      if (!note.isGraceNote) {
        builder.element('duration',
            nest: _durationDivisions(note.duration, tuplet?.modifier ?? 1.0));
      }
      if (voiceNumber != null) {
        builder.element('voice', nest: voiceNumber);
      }
      builder.element('type', nest: _durationTypeToString(note.duration.type));
      for (int index = 0; index < note.duration.dots; index++) {
        builder.element('dot');
      }
      if (tuplet != null) {
        builder.element(
          'time-modification',
          nest: () {
            builder.element('actual-notes', nest: tuplet.actualNotes);
            builder.element('normal-notes', nest: tuplet.normalNotes);
          },
        );
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
      // Beam (begin/continue/end) — before notations, per MusicXML order.
      if (note.beam != null) {
        builder.element(
          'beam',
          nest: () {
            builder.attribute('number', '1');
            builder.text(switch (note.beam!) {
              BeamType.start => 'begin',
              BeamType.inner => 'continue',
              BeamType.end => 'end',
            });
          },
        );
      }
      final ornamentNames = [
        for (final o in note.ornaments)
          if (_ornamentToString(o.type) != null) _ornamentToString(o.type)!,
      ];
      if (note.articulations.isNotEmpty ||
          note.slur != null ||
          ornamentNames.isNotEmpty) {
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
            if (ornamentNames.isNotEmpty) {
              builder.element(
                'ornaments',
                nest: () {
                  for (final name in ornamentNames) {
                    builder.element(name);
                  }
                },
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
      // Lyric verses (one <lyric> per syllable, numbered by verse).
      final syllables = note.syllables;
      if (syllables != null) {
        for (var v = 0; v < syllables.length; v++) {
          final syl = syllables[v];
          if (syl.text.isEmpty) continue;
          builder.element(
            'lyric',
            nest: () {
              builder.attribute('number', '${v + 1}');
              builder.element('syllabic', nest: _syllabicToString(syl.type));
              builder.element('text', nest: syl.text);
            },
          );
        }
      }
    },
  );
}

String? _ornamentToString(OrnamentType type) => switch (type) {
      OrnamentType.trill ||
      OrnamentType.trillNatural ||
      OrnamentType.trillSharp ||
      OrnamentType.trillFlat ||
      OrnamentType.shortTrill ||
      OrnamentType.pralltriller =>
        'trill-mark',
      OrnamentType.mordent => 'mordent',
      OrnamentType.invertedMordent => 'inverted-mordent',
      OrnamentType.turn => 'turn',
      OrnamentType.turnInverted || OrnamentType.invertedTurn => 'inverted-turn',
      OrnamentType.turnSlash => 'turn',
      _ => null,
    };

String _syllabicToString(SyllableType type) => switch (type) {
      SyllableType.single => 'single',
      SyllableType.initial => 'begin',
      SyllableType.middle => 'middle',
      SyllableType.hyphen => 'middle',
      SyllableType.terminal => 'end',
    };

void _buildRestXml(XmlBuilder builder, Rest rest,
    {TupletRatio? tuplet, int? voiceNumber}) {
  builder.element(
    'note',
    nest: () {
      builder.element('rest');
      builder.element('duration',
          nest: _durationDivisions(rest.duration, tuplet?.modifier ?? 1.0));
      if (voiceNumber != null) {
        builder.element('voice', nest: voiceNumber);
      }
      builder.element('type', nest: _durationTypeToString(rest.duration.type));
      for (int index = 0; index < rest.duration.dots; index++) {
        builder.element('dot');
      }
      if (tuplet != null) {
        builder.element(
          'time-modification',
          nest: () {
            builder.element('actual-notes', nest: tuplet.actualNotes);
            builder.element('normal-notes', nest: tuplet.normalNotes);
          },
        );
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
