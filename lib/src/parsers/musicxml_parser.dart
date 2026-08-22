import 'package:xml/xml.dart';

import '../../core/core.dart';
import 'parser_support.dart';

/// # Round-trip fidelity (Staff -> MusicXML -> Staff)
///
/// The exporter ([MusicXMLParser.staffToMusicXML] / [MusicXMLParser.mergeStaffs])
/// writes MusicXML 4.0 partwise. This list is the *honest* contract: what is
/// written, what is written but not read back by the importer, and what is
/// simply dropped. Keep it in sync with the code — the documentation diverging
/// from the exporter is itself a defect.
///
/// ## Exported and re-imported (survives a full round trip)
/// - Pitch (`step`/`alter`/`octave`), duration in real `<divisions>` (480 per
///   quarter), `<type>`, `<dot>`s.
/// - `<tie>`, `<slur>`, `<beam>`, `<time-modification>` (tuplets).
/// - `<lyric>` verses with `<syllabic>`.
/// - `<clef>` including `<clef-octave-change>`, `<key><fifths>`, `<time>`.
/// - `<barline>` with `<bar-style>`, `<repeat>` and endings.
/// - Multi-voice measures via `<backup>` + `<voice>`.
/// - `<accidental>` cautionary/editorial bracketing.
/// - `<direction><dynamics>` and `<wedge>` hairpins, `<metronome>` tempo.
///
/// ## Exported, but currently NOT read back by the importer
/// (the markup is correct MusicXML; the loss is on the import side)
/// - `<notations><ornaments><tremolo>` — [Note.tremoloStrokes] is written but
///   the importer does not repopulate it.
/// - `<notations><technical>` — [Note.techniques] ([PlayingTechnique]) is
///   written but not parsed back.
/// - `<staff>` per note ([Note.crossStaffMove]) is written; it is only read
///   back when the source is a genuine multi-staff part.
/// - `<staff-details><staff-lines>` ([Staff.lineCount]) is written on the first
///   measure but the importer always builds a 5-line [Staff].
/// - `<sound tempo=>` is written alongside `<metronome>`; only `<metronome>`
///   is read back.
/// - [Note.dynamicElement] and [Chord.dynamic] are written as a `<direction>`
///   *before* the owning `<note>`; on import they come back as a measure-level
///   [Dynamic] element, not re-attached to the note/chord.
/// - [Measure.number] is written to `@number`; the importer renumbers
///   positionally.
/// - Dynamics with no MusicXML equivalent ([DynamicType.subito],
///   [DynamicType.custom], …) are written as `<other-dynamics>` and are not
///   parsed back; the long-form values ([DynamicType.piano], …) normalise to
///   their abbreviations ([DynamicType.p], …).
///
/// ## NOT exported at all (lost on the way out)
/// - Page/system layout: `<print>`, `<page-layout>`, `<system-layout>`,
///   `<staff-layout>`, new-page/new-system breaks.
/// - Fonts and appearance: `<defaults>`, `<font-*>`, `<appearance>`,
///   line widths, note sizes.
/// - Manual positioning: every `default-x` / `default-y` / `relative-x` /
///   `relative-y` attribute; stem direction (`<stem>`), notehead shapes
///   (`<notehead>`).
/// - Cue notes (`<cue>`) and grace-note attributes (`slash`, `steal-time-*`);
///   grace notes are exported as a bare `<grace/>` with no slash.
/// - Score metadata: `<work>`, `<identification>`/`<creator>`, `<credit>`;
///   part names are hardcoded ("Music" / "Part N") and part ids are synthetic.
/// - Instrument/MIDI data: `<score-instrument>`, `<midi-instrument>`,
///   `<transpose>`, `<measure-style>` (multi-measure rests, slashes).
/// - Spanners other than slur/tie/wedge: `<glissando>`, `<slide>`,
///   `<octave-shift>`, `<pedal>`, `<bracket>`, `<arpeggiate>`, `<fermata>`.
/// - Tablature (`Note.tabFret` / `Note.tabString`), `Note.alternatePitch`,
///   numbered [Note.slurs] (only the single unnumbered [Note.slur] is written),
///   `<harmony>` chord symbols and figured bass.
///
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
              _buildMeasureXml(builder, staff.measures[index], index + 1,
                  staffLines: staff.lineCount);
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
                  staffLines: staffs[index].lineCount,
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

void _buildMeasureXml(XmlBuilder builder, Measure measure, int number,
    {int staffLines = 5}) {
  builder.element(
    'measure',
    nest: () {
      // An explicit Measure.number wins over the positional index (pickup
      // bars, repeats, "number 0" anacrusis, …); `number` stays the positional
      // one so first-measure logic (divisions/staff-details) is unaffected.
      builder.attribute('number', (measure.number ?? number).toString());

      final systemElements = measure.elements.where(
        (element) =>
            element is Clef ||
            element is KeySignature ||
            element is TimeSignature,
      );

      // A non-standard staff (percussion = 1 line, tablature = 4/6 lines) is
      // declared once, on the first measure, as <staff-details><staff-lines>.
      final needsStaffDetails = number == 1 && staffLines != 5;

      // The first measure always carries <divisions>; later measures only emit
      // <attributes> when a clef/key/time actually appears.
      if (number == 1 || systemElements.isNotEmpty || needsStaffDetails) {
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
            // <staff-details> comes after <clef> in the MusicXML content model.
            if (needsStaffDetails) {
              builder.element(
                'staff-details',
                nest: () => builder.element('staff-lines', nest: staffLines),
              );
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

      // A <wedge> opened in this measure must be closed, otherwise the hairpin
      // runs to the end of the part. Without span information the safest close
      // is the end of the measure that opened it.
      final measureElements = measure is MultiVoiceMeasure
          ? measure.sortedVoices.expand((v) => v.elements)
          : measure.elements;
      if (measureElements.any(_opensHairpin)) {
        _buildWedgeStopXml(builder);
      }
    },
  );
}

/// Dispatches one measure element to its MusicXML builder, tagging notes with
/// [voiceNumber] when set (multi-voice).
void _buildMeasureElement(XmlBuilder builder, MusicalElement element,
    {int? voiceNumber}) {
  if (element is Note) {
    _buildStandaloneNoteXml(builder, element, voiceNumber: voiceNumber);
  } else if (element is Rest) {
    _buildRestXml(builder, element, voiceNumber: voiceNumber);
  } else if (element is Chord) {
    _buildChordXml(builder, element, voiceNumber: voiceNumber);
  } else if (element is Tuplet) {
    for (final inner in element.elements) {
      if (inner is Note) {
        _buildStandaloneNoteXml(builder, inner,
            tuplet: element.ratio, voiceNumber: voiceNumber);
      } else if (inner is Rest) {
        _buildRestXml(builder, inner,
            tuplet: element.ratio, voiceNumber: voiceNumber);
      } else if (inner is Chord) {
        _buildChordXml(builder, inner,
            tuplet: element.ratio, voiceNumber: voiceNumber);
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

/// Emits a note that is not part of a [Chord], preceded by the `<direction>`
/// carrying its own [Note.dynamicElement] (MusicXML puts dynamics *before* the
/// note they apply to).
void _buildStandaloneNoteXml(XmlBuilder builder, Note note,
    {TupletRatio? tuplet, int? voiceNumber}) {
  if (note.dynamicElement != null) {
    _buildDynamicXml(builder, note.dynamicElement!);
  }
  _buildNoteXml(builder, note,
      tuplet: tuplet, voiceNumber: voiceNumber ?? note.voice);
}

/// Emits a [Chord] as `<note>` + `<note><chord/>`…, hanging the chord-level
/// dynamic/articulations/ornaments off the FIRST note (MusicXML has no
/// chord-level notations container).
void _buildChordXml(XmlBuilder builder, Chord chord,
    {TupletRatio? tuplet, int? voiceNumber}) {
  if (chord.notes.isEmpty) return;
  final lead = chord.notes.first;
  final dynamicElement = chord.dynamic ?? lead.dynamicElement;
  if (dynamicElement != null) {
    _buildDynamicXml(builder, dynamicElement);
  }
  final resolvedVoice = voiceNumber ?? chord.voice ?? lead.voice;
  for (int index = 0; index < chord.notes.length; index++) {
    _buildNoteXml(builder, chord.notes[index],
        isChordTone: index > 0,
        tuplet: tuplet,
        voiceNumber: resolvedVoice,
        extraArticulations: index == 0 ? chord.articulations : const [],
        extraOrnaments: index == 0 ? chord.ornaments : const []);
  }
}

void _buildNoteXml(XmlBuilder builder, Note note,
    {bool isChordTone = false,
    TupletRatio? tuplet,
    int? voiceNumber,
    List<ArticulationType> extraArticulations = const [],
    List<Ornament> extraOrnaments = const []}) {
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
      // <tie> belongs right after <duration> in the MusicXML content model.
      if (note.tie != null) {
        builder.element(
          'tie',
          nest: () => builder.attribute(
            'type',
            note.tie == TieType.end ? 'stop' : 'start',
          ),
        );
      }
      // Explicit voice tagging, even outside a MultiVoiceMeasure: a Note that
      // declares Note.voice keeps it through the round trip.
      final resolvedVoice = voiceNumber ?? note.voice;
      if (resolvedVoice != null) {
        builder.element('voice', nest: resolvedVoice);
      }
      builder.element('type', nest: _durationTypeToString(note.duration.type));
      for (int index = 0; index < note.duration.dots; index++) {
        builder.element('dot');
      }
      // Cautionary/editorial accidental display (round-trips the parenthesis).
      if (note.accidentalParenthesis != AccidentalParenthesis.none) {
        final accName = _accidentalNameFromAlter(note.pitch.alter);
        if (accName != null) {
          builder.element(
            'accidental',
            nest: () {
              if (note.accidentalParenthesis ==
                  AccidentalParenthesis.parentheses) {
                builder.attribute('cautionary', 'yes');
                builder.attribute('parentheses', 'yes');
              } else {
                builder.attribute('editorial', 'yes');
                builder.attribute('bracket', 'yes');
              }
              builder.text(accName);
            },
          );
        }
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
      // Cross-staff display (keyboard music): the notehead is drawn on another
      // staff than its home one. Home staff is 1 in a single-Staff export.
      if (note.crossStaffMove != 0) {
        final target = 1 + note.crossStaffMove;
        builder.element('staff', nest: target < 1 ? 1 : target);
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
      final ornamentNames = <String>[
        for (final o in [...note.ornaments, ...extraOrnaments])
          if (_ornamentToString(o.type) != null) _ornamentToString(o.type)!,
      ];
      final articulations = <ArticulationType>{
        ...note.articulations,
        ...extraArticulations,
      };
      // Techniques already covered by an <articulations> child are skipped so
      // the same gesture is not written twice.
      final articulationNames = articulations.map(_articulationToString).toSet();
      final technicalTechniques = <PlayingTechnique>[
        for (final t in note.techniques)
          if (!articulationNames.contains(_techniqueToString(t.type))) t,
      ];
      final hasTremolo = note.tremoloStrokes > 0;
      if (articulations.isNotEmpty ||
          note.slur != null ||
          ornamentNames.isNotEmpty ||
          technicalTechniques.isNotEmpty ||
          hasTremolo) {
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
            if (ornamentNames.isNotEmpty || hasTremolo) {
              builder.element(
                'ornaments',
                nest: () {
                  for (final name in ornamentNames) {
                    builder.element(name);
                  }
                  // 1–5 strokes; <tremolo> is an <ornaments> child in MusicXML.
                  if (hasTremolo) {
                    final strokes =
                        note.tremoloStrokes > 8 ? 8 : note.tremoloStrokes;
                    builder.element(
                      'tremolo',
                      nest: () {
                        builder.attribute('type', 'single');
                        builder.text(strokes.toString());
                      },
                    );
                  }
                },
              );
            }
            if (technicalTechniques.isNotEmpty) {
              builder.element(
                'technical',
                nest: () {
                  for (final technique in technicalTechniques) {
                    _buildTechnicalChild(builder, technique);
                  }
                },
              );
            }
            if (articulations.isNotEmpty) {
              builder.element(
                'articulations',
                nest: () {
                  for (final articulation in articulations) {
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

/// MusicXML `<accidental>` name for a chromatic alteration in semitones.
String? _accidentalNameFromAlter(double alter) => switch (alter) {
      2.0 => 'double-sharp',
      1.0 => 'sharp',
      0.0 => 'natural',
      -1.0 => 'flat',
      -2.0 => 'flat-flat',
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

/// Emits a [Dynamic] as `<direction placement="below">`: a `<wedge>` for
/// hairpins (crescendo/diminuendo), otherwise `<dynamics>` with the matching
/// MusicXML dynamic element (`<ff/>`, `<sfz/>`, …).
void _buildDynamicXml(XmlBuilder builder, Dynamic dynamic) {
  final wedge = switch (dynamic.type) {
    DynamicType.crescendo => 'crescendo',
    DynamicType.diminuendo => 'diminuendo',
    _ => null,
  };
  builder.element(
    'direction',
    nest: () {
      builder.attribute('placement', 'below');
      builder.element(
        'direction-type',
        nest: () {
          if (_isHairpinDynamic(dynamic)) {
            builder.element(
              'wedge',
              nest: () => builder.attribute('type', wedge ?? 'crescendo'),
            );
          } else {
            builder.element(
              'dynamics',
              nest: () {
                final name = _dynamicTypeToString(dynamic.type);
                if (name == 'other-dynamics') {
                  builder.element('other-dynamics',
                      nest: dynamic.customText ?? dynamic.type.name);
                } else {
                  builder.element(name);
                }
              },
            );
          }
        },
      );
    },
  );
}

/// True when [dynamic] is exported as a `<wedge>` rather than as `<dynamics>`.
bool _isHairpinDynamic(Dynamic dynamic) =>
    dynamic.isHairpin ||
    dynamic.type == DynamicType.crescendo ||
    dynamic.type == DynamicType.diminuendo;

/// True when exporting [element] opens a `<wedge>` that still has to be closed
/// by a `<wedge type="stop"/>` before the part ends.
bool _opensHairpin(MusicalElement element) {
  if (element is Dynamic) return _isHairpinDynamic(element);
  if (element is Note) {
    final d = element.dynamicElement;
    return d != null && _isHairpinDynamic(d);
  }
  if (element is Chord) {
    final d = element.dynamic ??
        (element.notes.isEmpty ? null : element.notes.first.dynamicElement);
    return d != null && _isHairpinDynamic(d);
  }
  if (element is Tuplet) return element.elements.any(_opensHairpin);
  return false;
}

/// Closes an open hairpin: `<wedge type="stop"/>`.
void _buildWedgeStopXml(XmlBuilder builder) {
  builder.element(
    'direction',
    nest: () {
      builder.attribute('placement', 'below');
      builder.element(
        'direction-type',
        nest: () => builder.element(
          'wedge',
          nest: () => builder.attribute('type', 'stop'),
        ),
      );
    },
  );
}

void _buildTempoXml(XmlBuilder builder, TempoMark tempo) {
  builder.element(
    'direction',
    nest: () {
      builder.attribute('placement', 'above');
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
      // Playback tempo, in quarter notes per minute, for sequencer round trips.
      if (tempo.bpm != null) {
        builder.element(
          'sound',
          nest: () => builder.attribute(
            'tempo',
            _quarterNotesPerMinute(tempo).toString(),
          ),
        );
      }
    },
  );
}

/// `<sound tempo=>` is always expressed in quarter notes per minute, so a
/// `beatUnit` other than the quarter has to be converted.
int _quarterNotesPerMinute(TempoMark tempo) {
  final bpm = tempo.bpm ?? 0;
  final beat = Duration(tempo.beatUnit);
  final quarter = const Duration(DurationType.quarter).realValue;
  if (quarter <= 0 || beat.realValue <= 0) return bpm;
  final value = (bpm * beat.realValue / quarter).round();
  return value < 1 ? 1 : value;
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

/// Names that really exist as `<technical>` children in MusicXML 4.0. Anything
/// else is written as `<other-technical>` so no information is silently lost.
const Set<String> _kTechnicalElements = <String>{
  'up-bow',
  'down-bow',
  'harmonic',
  'open-string',
  'thumb-position',
  'pluck',
  'double-tongue',
  'triple-tongue',
  'stopped',
  'snap-pizzicato',
  'hammer-on',
  'pull-off',
  'bend',
  'tap',
  'heel',
  'toe',
  'fingernails',
  'brass-bend',
  'flip',
  'smear',
  'open',
  'half-muted',
  'golpe',
};

/// Canonical MusicXML-ish name for a [TechniqueType]. Also used to detect a
/// technique already emitted as an `<articulations>` child (no duplicates).
String _techniqueToString(TechniqueType type) => switch (type) {
      TechniqueType.pizzicato => 'pizzicato',
      TechniqueType.snapPizzicato => 'snap-pizzicato',
      TechniqueType.colLegno => 'col-legno',
      TechniqueType.bowOnBridge => 'bow-on-bridge',
      TechniqueType.bowOnTailpiece => 'bow-on-tailpiece',
      TechniqueType.sulTasto => 'sul-tasto',
      TechniqueType.sulPonticello => 'sul-ponticello',
      TechniqueType.martellato => 'martellato',
      TechniqueType.ricochet => 'ricochet',
      TechniqueType.jet => 'jet',
      TechniqueType.vibrato => 'vibrato',
      TechniqueType.naturalHarmonic => 'natural-harmonic',
      TechniqueType.artificialHarmonic => 'artificial-harmonic',
      TechniqueType.multiphonics => 'multiphonics',
      TechniqueType.overblowing => 'overblowing',
      TechniqueType.tongueram => 'tongue-ram',
      TechniqueType.circularBreathing => 'circular-breathing',
      TechniqueType.flutter => 'flutter',
      TechniqueType.whistle => 'whistle',
      TechniqueType.growl => 'growl',
      TechniqueType.tremolo => 'tremolo',
    };

/// Writes one `<technical>` child for [technique].
void _buildTechnicalChild(XmlBuilder builder, PlayingTechnique technique) {
  final name = _techniqueToString(technique.type);
  switch (technique.type) {
    case TechniqueType.naturalHarmonic:
      builder.element(
        'harmonic',
        nest: () => builder.element('natural'),
      );
      return;
    case TechniqueType.artificialHarmonic:
      builder.element(
        'harmonic',
        nest: () => builder.element('artificial'),
      );
      return;
    default:
      if (_kTechnicalElements.contains(name)) {
        builder.element(name);
      } else {
        // No dedicated element exists: keep the name (and any free text) in
        // <other-technical> instead of dropping the technique.
        final text = technique.text;
        builder.element('other-technical',
            nest: text == null || text.isEmpty ? name : '$name: $text');
      }
  }
}

/// MusicXML `<dynamics>` child name for [type].
///
/// The long-form enum values (`piano`, `forte`, …) collapse onto their
/// abbreviations because MusicXML only defines the abbreviated elements; a
/// round trip therefore normalises `DynamicType.piano` to `DynamicType.p`.
/// Values with no MusicXML equivalent return `other-dynamics`, which the caller
/// writes as `<other-dynamics>text</other-dynamics>` instead of dropping them.
String _dynamicTypeToString(DynamicType type) {
  return switch (type) {
    DynamicType.p || DynamicType.piano => 'p',
    DynamicType.pp || DynamicType.pianissimo => 'pp',
    DynamicType.ppp || DynamicType.pianississimo => 'ppp',
    DynamicType.pppp => 'pppp',
    DynamicType.ppppp => 'ppppp',
    DynamicType.pppppp => 'pppppp',
    DynamicType.mp || DynamicType.mezzoPiano => 'mp',
    DynamicType.mf || DynamicType.mezzoForte => 'mf',
    DynamicType.f || DynamicType.forte => 'f',
    DynamicType.ff || DynamicType.fortissimo => 'ff',
    DynamicType.fff || DynamicType.fortississimo => 'fff',
    DynamicType.ffff => 'ffff',
    DynamicType.fffff => 'fffff',
    DynamicType.ffffff => 'ffffff',
    DynamicType.sforzando => 'sfz',
    DynamicType.sforzandoFF => 'sffz',
    DynamicType.sforzandoPiano => 'sfp',
    DynamicType.sforzandoPianissimo => 'sfpp',
    DynamicType.rinforzando => 'rfz',
    DynamicType.fortePiano => 'fp',
    DynamicType.niente => 'n',
    // crescendo/diminuendo are emitted as <wedge>, never as <dynamics>.
    _ => 'other-dynamics',
  };
}
