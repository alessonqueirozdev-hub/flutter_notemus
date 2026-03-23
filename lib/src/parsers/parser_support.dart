import 'dart:convert';

import 'package:xml/xml.dart';

import '../../core/core.dart';
import 'notation_format.dart';

NotationFormat detectNotationFormat(String source) {
  final trimmed = source.trimLeft();
  if (trimmed.isEmpty) {
    throw const FormatException('Notation source is empty.');
  }

  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return NotationFormat.json;
  }

  if (trimmed.startsWith('<')) {
    try {
      final document = XmlDocument.parse(source);
      final root = document.rootElement.name.local.toLowerCase();
      if (root == 'mei') {
        return NotationFormat.mei;
      }
      if (root == 'score-partwise' || root == 'score-timewise') {
        return NotationFormat.musicXml;
      }
    } catch (_) {
      // Fall through to heuristics below.
    }

    final lower = trimmed.toLowerCase();
    if (lower.contains('<mei')) return NotationFormat.mei;
    if (lower.contains('<score-partwise') ||
        lower.contains('<score-timewise')) {
      return NotationFormat.musicXml;
    }
  }

  throw const FormatException(
    'Unable to detect notation format. Expected JSON, MusicXML, or MEI.',
  );
}

Staff parseNotationStaff(
  String source, {
  NotationFormat? format,
  int partIndex = 0,
  int staffIndex = 0,
}) {
  final resolvedFormat = format ?? detectNotationFormat(source);
  return switch (resolvedFormat) {
    NotationFormat.json => parseJsonStaff(source, staffIndex: staffIndex),
    NotationFormat.musicXml => parseMusicXmlStaff(source, partIndex: partIndex),
    NotationFormat.mei => parseMeiStaff(source, staffIndex: staffIndex),
  };
}

Staff parseJsonStaff(String source, {int staffIndex = 0}) {
  final dynamic decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('JSON notation root must be an object.');
  }

  return _JsonImportParser(staffIndex: staffIndex).parse(decoded);
}

Staff parseMusicXmlStaff(String source, {int partIndex = 0}) {
  final document = XmlDocument.parse(source);
  return _MusicXmlImportParser(partIndex: partIndex).parse(document);
}

Staff parseMeiStaff(String source, {int staffIndex = 0}) {
  final document = XmlDocument.parse(source);
  return _MeiImportParser(staffIndex: staffIndex).parse(document);
}

class _VoiceAccumulator {
  _VoiceAccumulator(this.number);

  final int number;
  final List<MusicalElement> elements = <MusicalElement>[];
  _TupletAccumulator? activeTuplet;

  void append(MusicalElement element) {
    if (activeTuplet != null) {
      activeTuplet!.elements.add(element);
      return;
    }
    elements.add(element);
  }

  void startTuplet({
    required int actualNotes,
    required int normalNotes,
    TupletBracket? bracketConfig,
    TupletNumber? numberConfig,
    TimeSignature? timeSignature,
  }) {
    activeTuplet = _TupletAccumulator(
      actualNotes: actualNotes,
      normalNotes: normalNotes,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
    );
  }

  void finishTuplet() {
    if (activeTuplet == null) return;
    final completed = activeTuplet!.build();
    activeTuplet = null;
    elements.add(completed);
  }

  bool mergeChordNote(Note note) {
    final List<MusicalElement> container = activeTuplet?.elements ?? elements;
    final int targetIndex = _findMergeableChordIndex(container);
    if (targetIndex < 0) return false;

    final last = container[targetIndex];
    if (last is Note) {
      container[targetIndex] = Chord(
        notes: <Note>[last, note],
        duration: last.duration,
        articulations: last.articulations,
        tie: last.tie,
        slur: last.slur,
        beam: last.beam,
        ornaments: last.ornaments,
        dynamic: last.dynamicElement,
        voice: last.voice,
      );
      return true;
    }

    if (last is Chord) {
      container[targetIndex] = Chord(
        notes: <Note>[...last.notes, note],
        duration: last.duration,
        articulations: last.articulations,
        tie: last.tie,
        slur: last.slur,
        beam: last.beam,
        ornaments: last.ornaments,
        dynamic: last.dynamic,
        voice: last.voice,
      );
      return true;
    }

    return false;
  }

  int _findMergeableChordIndex(List<MusicalElement> container) {
    for (int index = container.length - 1; index >= 0; index--) {
      final candidate = container[index];
      if (candidate is Note || candidate is Chord) {
        return index;
      }
      if (_isRhythmicElement(candidate)) {
        return -1;
      }
    }
    return -1;
  }
}

class _TupletAccumulator {
  _TupletAccumulator({
    required this.actualNotes,
    required this.normalNotes,
    required this.bracketConfig,
    required this.numberConfig,
    required this.timeSignature,
  });

  final int actualNotes;
  final int normalNotes;
  final TupletBracket? bracketConfig;
  final TupletNumber? numberConfig;
  final TimeSignature? timeSignature;
  final List<MusicalElement> elements = <MusicalElement>[];

  Tuplet build() {
    return Tuplet(
      actualNotes: actualNotes,
      normalNotes: normalNotes,
      elements: List<MusicalElement>.from(elements),
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
    );
  }
}

class _TupletEventInfo {
  const _TupletEventInfo({
    required this.startsTuplet,
    required this.endsTuplet,
    required this.actualNotes,
    required this.normalNotes,
  });

  final bool startsTuplet;
  final bool endsTuplet;
  final int actualNotes;
  final int normalNotes;
}

bool _isSystemElement(MusicalElement element) {
  return element is Clef ||
      element is KeySignature ||
      element is TimeSignature ||
      element is TempoMark;
}

bool _isRhythmicElement(MusicalElement element) {
  return element is Note ||
      element is Rest ||
      element is Chord ||
      element is Tuplet;
}

void _appendElementToMeasure(Measure measure, MusicalElement element) {
  try {
    measure.add(element);
  } on MeasureCapacityException {
    measure.elements.add(element);
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic entry) => MapEntry(key.toString(), entry),
    );
  }
  return null;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

String? _asString(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = _normalizeToken(value);
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
  }
  return null;
}

String _normalizeToken(String? raw) {
  if (raw == null) return '';
  return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

T? _parseEnumByName<T extends Enum>(
  Iterable<T> values,
  String? raw, {
  Map<String, T> aliases = const {},
}) {
  final normalized = _normalizeToken(raw);
  if (normalized.isEmpty) return null;
  final aliased = aliases[normalized];
  if (aliased != null) return aliased;

  for (final value in values) {
    if (_normalizeToken(value.name) == normalized) {
      return value;
    }
  }
  return null;
}

Iterable<dynamic> _normalizeDynamicList(dynamic raw) sync* {
  if (raw == null) return;
  if (raw is List) {
    for (final item in raw) {
      yield item;
    }
    return;
  }
  yield raw;
}

String? _inferElementType(Map<String, dynamic> map) {
  if (map.containsKey('pitch')) return 'note';
  if (map.containsKey('notes')) return 'chord';
  if (map.containsKey('numerator') && map.containsKey('denominator')) {
    return 'timeSignature';
  }
  if (map.containsKey('clefType')) return 'clef';
  if (map.containsKey('repeatType')) return 'repeatMark';
  if (map.containsKey('octaveType')) return 'octaveMark';
  return null;
}

DurationType? _parseDurationType(String? raw) {
  return _parseEnumByName<DurationType>(
    DurationType.values,
    raw,
    aliases: <String, DurationType>{
      '1': DurationType.whole,
      '2': DurationType.half,
      '4': DurationType.quarter,
      '8': DurationType.eighth,
      '16': DurationType.sixteenth,
      '16th': DurationType.sixteenth,
      '32': DurationType.thirtySecond,
      '32nd': DurationType.thirtySecond,
      '64': DurationType.sixtyFourth,
      '64th': DurationType.sixtyFourth,
      '128': DurationType.oneHundredTwentyEighth,
      '128th': DurationType.oneHundredTwentyEighth,
      'semibreve': DurationType.whole,
      'minim': DurationType.half,
      'crotchet': DurationType.quarter,
      'quaver': DurationType.eighth,
    },
  );
}

TieType? _parseTieType(dynamic raw) {
  return _parseEnumByName<TieType>(
    TieType.values,
    _asString(raw),
    aliases: <String, TieType>{
      'stop': TieType.end,
      'continue': TieType.inner,
      'm': TieType.inner,
      'i': TieType.start,
      't': TieType.end,
    },
  );
}

SlurType? _parseSlurType(dynamic raw) {
  return _parseEnumByName<SlurType>(
    SlurType.values,
    _asString(raw),
    aliases: <String, SlurType>{
      'stop': SlurType.end,
      'continue': SlurType.inner,
      'm': SlurType.inner,
      'i': SlurType.start,
      't': SlurType.end,
    },
  );
}

BeamType? _parseBeamType(dynamic raw) {
  return _parseEnumByName<BeamType>(
    BeamType.values,
    _asString(raw),
    aliases: <String, BeamType>{
      'begin': BeamType.start,
      'continue': BeamType.inner,
      'stop': BeamType.end,
    },
  );
}

BeamingMode? _parseBeamingMode(dynamic raw) {
  return _parseEnumByName<BeamingMode>(BeamingMode.values, _asString(raw));
}

StemDirection? _parseStemDirection(dynamic raw) {
  return _parseEnumByName<StemDirection>(StemDirection.values, _asString(raw));
}

BracketSide? _parseBracketSide(dynamic raw) {
  return _parseEnumByName<BracketSide>(BracketSide.values, _asString(raw));
}

List<List<int>> _parseManualBeamGroups(dynamic raw) {
  final List<List<int>> groups = <List<int>>[];
  for (final dynamic group in _asList(raw)) {
    final List<int> parsed = <int>[];
    for (final dynamic value in _asList(group)) {
      final int? index = _asInt(value);
      if (index != null) parsed.add(index);
    }
    if (parsed.isNotEmpty) {
      groups.add(parsed);
    }
  }
  return groups;
}

AccidentalType? _parseAccidentalType(dynamic raw) {
  return _parseEnumByName<AccidentalType>(
    AccidentalType.values,
    _asString(raw),
    aliases: <String, AccidentalType>{
      'n': AccidentalType.natural,
      'natural': AccidentalType.natural,
      's': AccidentalType.sharp,
      'sharp': AccidentalType.sharp,
      'f': AccidentalType.flat,
      'flat': AccidentalType.flat,
      'ss': AccidentalType.doubleSharp,
      'doublesharp': AccidentalType.doubleSharp,
      'x': AccidentalType.doubleSharp,
      'ff': AccidentalType.doubleFlat,
      'doubleflat': AccidentalType.doubleFlat,
      'ts': AccidentalType.tripleSharp,
      'tf': AccidentalType.tripleFlat,
      'quartertonesharp': AccidentalType.quarterToneSharp,
      'quartertoneflat': AccidentalType.quarterToneFlat,
    },
  );
}

ClefType? _parseClefType(dynamic raw) {
  return _parseEnumByName<ClefType>(
    ClefType.values,
    _asString(raw),
    aliases: <String, ClefType>{
      'g': ClefType.treble,
      'g2': ClefType.treble,
      'f': ClefType.bass,
      'f4': ClefType.bass,
      'f3': ClefType.bassThirdLine,
      'c': ClefType.alto,
      'c3': ClefType.alto,
      'c4': ClefType.tenor,
      'c1': ClefType.soprano,
      'c2': ClefType.mezzoSoprano,
      'c5': ClefType.baritone,
      'percussion': ClefType.percussion,
      'tab': ClefType.tab6,
      'tab6': ClefType.tab6,
      'tab4': ClefType.tab4,
    },
  );
}

BarlineType? _parseBarlineType(dynamic raw) {
  return _parseEnumByName<BarlineType>(
    BarlineType.values,
    _asString(raw),
    aliases: <String, BarlineType>{
      'final': BarlineType.final_,
      'finalbar': BarlineType.final_,
      'repeatforward': BarlineType.repeatForward,
      'repeatbackward': BarlineType.repeatBackward,
      'repeatboth': BarlineType.repeatBoth,
      'lightlight': BarlineType.double,
      'lightheavy': BarlineType.final_,
      'heavylight': BarlineType.heavyLight,
      'heavyheavy': BarlineType.heavyHeavy,
      'short': BarlineType.short_,
      'regular': BarlineType.single,
      'dbl': BarlineType.double,
      'end': BarlineType.final_,
      'rptstart': BarlineType.repeatForward,
      'rptend': BarlineType.repeatBackward,
      'rptboth': BarlineType.repeatBoth,
      'dbldashed': BarlineType.double,
      'dbldotted': BarlineType.double,
      'dblheavy': BarlineType.heavy,
      'dotted': BarlineType.dashed,
      'invis': BarlineType.none,
    },
  );
}

DynamicType? _parseDynamicType(dynamic raw) {
  return _parseEnumByName<DynamicType>(
    DynamicType.values,
    _asString(raw),
    aliases: <String, DynamicType>{
      'pppp': DynamicType.pppp,
      'ppppp': DynamicType.ppppp,
      'ppp': DynamicType.ppp,
      'pp': DynamicType.pp,
      'p': DynamicType.p,
      'mp': DynamicType.mp,
      'mf': DynamicType.mf,
      'f': DynamicType.f,
      'ff': DynamicType.ff,
      'fff': DynamicType.fff,
      'ffff': DynamicType.ffff,
      'fffff': DynamicType.fffff,
      'ffffff': DynamicType.ffffff,
      'sf': DynamicType.sforzando,
      'sfz': DynamicType.sforzando,
      'sfp': DynamicType.sforzandoPiano,
      'sfpp': DynamicType.sforzandoPianissimo,
      'rfz': DynamicType.rinforzando,
      'fp': DynamicType.fortePiano,
      'crescendo': DynamicType.crescendo,
      'diminuendo': DynamicType.diminuendo,
      'niente': DynamicType.niente,
    },
  );
}

RepeatType? _parseRepeatType(dynamic raw) {
  return _parseEnumByName<RepeatType>(
    RepeatType.values,
    _asString(raw),
    aliases: <String, RepeatType>{
      'forward': RepeatType.start,
      'backward': RepeatType.end,
      'dalsegno': RepeatType.dalSegno,
      'dsalcoda': RepeatType.dalSegnoAlCoda,
      'dsalfine': RepeatType.dalSegnoAlFine,
      'dacapo': RepeatType.daCapo,
      'dcalcoda': RepeatType.daCapoAlCoda,
      'dcalfine': RepeatType.daCapoAlFine,
      'tocoda': RepeatType.toCoda,
    },
  );
}

BreathType? _parseBreathType(dynamic raw) {
  return _parseEnumByName<BreathType>(
    BreathType.values,
    _asString(raw),
    aliases: <String, BreathType>{
      'breath': BreathType.comma,
      'breathmark': BreathType.comma,
      'comma': BreathType.comma,
      'tick': BreathType.tick,
      'upbow': BreathType.upbow,
      'caesura': BreathType.caesura,
      'shortcaesura': BreathType.shortCaesura,
      'longcaesura': BreathType.longCaesura,
    },
  );
}

OctaveType? _parseOctaveType(dynamic raw) {
  return _parseEnumByName<OctaveType>(
    OctaveType.values,
    _asString(raw),
    aliases: <String, OctaveType>{
      '8va': OctaveType.va8,
      '8vb': OctaveType.vb8,
      '15ma': OctaveType.va15,
      '15mb': OctaveType.vb15,
      '22da': OctaveType.va22,
      '22db': OctaveType.vb22,
    },
  );
}

TextType? _parseTextType(dynamic raw) {
  return _parseEnumByName<TextType>(
    TextType.values,
    _asString(raw),
    aliases: <String, TextType>{
      'words': TextType.expression,
      'direction': TextType.expression,
      'rehearsalmark': TextType.rehearsal,
      'chordsymbol': TextType.chord,
    },
  );
}

TextPlacement? _parseTextPlacement(dynamic raw) {
  return _parseEnumByName<TextPlacement>(TextPlacement.values, _asString(raw));
}

OrnamentType? _parseOrnamentType(dynamic raw) {
  return _parseEnumByName<OrnamentType>(
    OrnamentType.values,
    _asString(raw),
    aliases: <String, OrnamentType>{
      'trillmark': OrnamentType.trill,
      'mordentupper': OrnamentType.invertedMordent,
      'mordentlower': OrnamentType.mordent,
      'turnregular': OrnamentType.turn,
      'invertedturn': OrnamentType.turnInverted,
      'turnslash': OrnamentType.turnSlash,
      'acciaccatura': OrnamentType.acciaccatura,
      'appoggiatura': OrnamentType.appoggiaturaUp,
      'fermata': OrnamentType.fermata,
    },
  );
}

TechniqueType? _parseTechniqueType(dynamic raw) {
  return _parseEnumByName<TechniqueType>(TechniqueType.values, _asString(raw));
}

Pitch? _parsePitch(dynamic raw) {
  if (raw is String) {
    return Pitch.fromString(raw);
  }

  final map = _asMap(raw);
  if (map == null) return null;

  final step = _asString(map['step'])?.toUpperCase();
  final octave = _asInt(map['octave']);
  if (step == null || octave == null) return null;

  final accidentalType = _parseAccidentalType(
    map['accidentalType'] ?? map['accidental'],
  );

  return Pitch(
    step: step,
    octave: octave,
    alter: _asDouble(map['alter']) ?? accidentalToAlter[accidentalType] ?? 0.0,
    accidentalType: accidentalType,
    customAccidentalGlyph: _asString(map['customAccidentalGlyph']),
  );
}

Duration _parseDuration(dynamic raw, {bool grace = false}) {
  if (raw is String) {
    return Duration(
      _parseDurationType(raw) ??
          (grace ? DurationType.eighth : DurationType.quarter),
    );
  }

  final map = _asMap(raw);
  if (map == null) {
    return Duration(grace ? DurationType.eighth : DurationType.quarter);
  }

  return Duration(
    _parseDurationType(
          _asString(map['type']) ??
              _asString(map['durationType']) ??
              _asString(map['dur']),
        ) ??
        (grace ? DurationType.eighth : DurationType.quarter),
    dots: _asInt(map['dots']) ?? 0,
  );
}

List<ArticulationType> _parseArticulationList(dynamic raw) {
  final List<ArticulationType> articulations = <ArticulationType>[];
  for (final dynamic item in _normalizeDynamicList(raw)) {
    final map = _asMap(item);
    final candidate = _parseEnumByName<ArticulationType>(
      ArticulationType.values,
      _asString(map != null ? map['type'] ?? map['value'] : item),
      aliases: <String, ArticulationType>{
        'strongaccent': ArticulationType.strongAccent,
        'upbow': ArticulationType.upBow,
        'downbow': ArticulationType.downBow,
        'halfstopped': ArticulationType.halfStopped,
        'snappizzicato': ArticulationType.snap,
      },
    );
    if (candidate != null) {
      articulations.add(candidate);
    }
  }
  return articulations;
}

List<Ornament> _parseOrnamentList(dynamic raw) {
  final List<Ornament> ornaments = <Ornament>[];
  for (final dynamic item in _normalizeDynamicList(raw)) {
    final map = _asMap(item);
    final type = _parseOrnamentType(
      _asString(
        map != null ? map['type'] ?? map['ornamentType'] ?? map['value'] : item,
      ),
    );
    if (type == null) continue;
    ornaments.add(
      Ornament(
        type: type,
        above: map == null ? true : (_asBool(map['above']) ?? true),
        text: map == null ? null : _asString(map['text']),
        alternatePitch: map == null ? null : _parsePitch(map['alternatePitch']),
      ),
    );
  }
  return ornaments;
}

List<PlayingTechnique> _parseTechniqueList(dynamic raw) {
  final List<PlayingTechnique> techniques = <PlayingTechnique>[];
  for (final dynamic item in _normalizeDynamicList(raw)) {
    final map = _asMap(item);
    final type = _parseTechniqueType(
      _asString(map != null ? map['type'] ?? map['value'] : item),
    );
    if (type == null) continue;
    techniques.add(
      PlayingTechnique(
        type: type,
        text: map == null ? null : _asString(map['text']),
      ),
    );
  }
  return techniques;
}

TimeSignature? _parseTimeSignatureMap(Map<String, dynamic>? map) {
  if (map == null) return null;
  final numerator = _asInt(map['numerator']) ?? _asInt(map['count']);
  final denominator = _asInt(map['denominator']) ?? _asInt(map['unit']);
  if (numerator == null || denominator == null) return null;
  return TimeSignature(numerator: numerator, denominator: denominator);
}

class _JsonImportParser {
  _JsonImportParser({required this.staffIndex});

  final int staffIndex;

  Staff parse(Map<String, dynamic> root) {
    if (root.containsKey('score')) {
      final scoreRoot = _asMap(root['score']);
      if (scoreRoot != null) {
        return _parseScoreRoot(scoreRoot);
      }
    }

    if (root.containsKey('staff')) {
      final staffRoot = _asMap(root['staff']);
      if (staffRoot != null) {
        return _parseStaffRoot(staffRoot);
      }
    }

    if (root.containsKey('staves')) {
      return _selectStaffFromList(_asList(root['staves']));
    }

    return _parseStaffRoot(root);
  }

  Staff _parseScoreRoot(Map<String, dynamic> json) {
    if (json.containsKey('staffGroups')) {
      final List<Map<String, dynamic>> flattenedStaffs =
          <Map<String, dynamic>>[];
      for (final dynamic group in _asList(json['staffGroups'])) {
        final groupMap = _asMap(group);
        if (groupMap == null) continue;
        for (final dynamic staff in _asList(groupMap['staves'])) {
          final staffMap = _asMap(staff);
          if (staffMap != null) {
            flattenedStaffs.add(staffMap);
          }
        }
      }
      return _selectStaffFromMaps(flattenedStaffs);
    }

    if (json.containsKey('staves')) {
      return _selectStaffFromList(_asList(json['staves']));
    }

    return _parseStaffRoot(json);
  }

  Staff _selectStaffFromList(List<dynamic> staves) {
    final List<Map<String, dynamic>> maps = <Map<String, dynamic>>[];
    for (final dynamic item in staves) {
      final map = _asMap(item);
      if (map != null) {
        maps.add(map);
      }
    }
    return _selectStaffFromMaps(maps);
  }

  Staff _selectStaffFromMaps(List<Map<String, dynamic>> staffs) {
    if (staffs.isEmpty) return Staff();
    if (staffIndex < 0 || staffIndex >= staffs.length) {
      throw FormatException(
        'Requested staffIndex $staffIndex, but JSON contains ${staffs.length} staff/staves.',
      );
    }
    return _parseStaffRoot(staffs[staffIndex]);
  }

  Staff _parseStaffRoot(Map<String, dynamic> json) {
    final staff = Staff();
    for (final dynamic measureJson in _asList(json['measures'])) {
      final measureMap = _asMap(measureJson);
      if (measureMap == null) continue;
      staff.add(_parseMeasure(measureMap));
    }
    return staff;
  }

  Measure _parseMeasure(Map<String, dynamic> json) {
    final bool hasVoices = _asList(json['voices']).isNotEmpty;

    final Measure measure = hasVoices
        ? MultiVoiceMeasure()
        : Measure(
            autoBeaming: _asBool(json['autoBeaming']) ?? true,
            beamingMode:
                _parseBeamingMode(json['beamingMode']) ?? BeamingMode.automatic,
            manualBeamGroups: _parseManualBeamGroups(json['manualBeamGroups']),
          );

    final List<MusicalElement> leadingElements = <MusicalElement>[];
    for (final dynamic elementJson in _asList(json['elements'])) {
      final element = _parseElement(elementJson);
      if (element != null) {
        leadingElements.add(element);
      }
    }

    if (measure is MultiVoiceMeasure) {
      for (final element in leadingElements.where(_isSystemElement)) {
        _appendElementToMeasure(measure, element);
      }

      final voices = _asList(json['voices']);
      for (int index = 0; index < voices.length; index++) {
        final voiceMap = _asMap(voices[index]);
        if (voiceMap == null) continue;
        measure.addVoice(_parseVoice(voiceMap, index + 1, leadingElements));
      }
    } else {
      for (final element in leadingElements) {
        _appendElementToMeasure(measure, element);
      }
    }

    return measure;
  }

  Voice _parseVoice(
    Map<String, dynamic> json,
    int fallbackNumber,
    List<MusicalElement> leadingElements,
  ) {
    final int number = _asInt(json['number']) ?? fallbackNumber;
    final voice = Voice(
      number: number,
      name: _asString(json['name']),
      forcedStemDirection: _parseStemDirection(json['forcedStemDirection']),
      horizontalOffset: _asDouble(json['horizontalOffset']),
      color: _asString(json['color']),
    );

    if (number == 1) {
      for (final element in leadingElements) {
        voice.add(element);
      }
    }

    for (final dynamic elementJson in _asList(json['elements'])) {
      final element = _parseElement(elementJson);
      if (element != null) {
        voice.add(element);
      }
    }

    return voice;
  }

  MusicalElement? _parseElement(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;

    final type = _normalizeToken(
      _asString(map['type']) ?? _inferElementType(map),
    );

    switch (type) {
      case 'clef':
        return _parseClef(map);
      case 'keysignature':
        return KeySignature(
          _asInt(map['count']) ?? 0,
          previousCount: _asInt(map['previousCount']),
        );
      case 'timesignature':
        return TimeSignature(
          numerator: _asInt(map['numerator']) ?? 4,
          denominator: _asInt(map['denominator']) ?? 4,
        );
      case 'note':
      case 'gracenote':
        return _parseNote(map, forceGrace: type == 'gracenote');
      case 'rest':
        return _parseRest(map);
      case 'barline':
        return Barline(
          type:
              _parseBarlineType(map['barlineType'] ?? map['style']) ??
              BarlineType.single,
        );
      case 'dynamic':
        return _parseDynamic(map);
      case 'tempo':
      case 'tempomark':
        return _parseTempo(map);
      case 'text':
      case 'musictext':
        return _parseMusicText(map);
      case 'breath':
        return Breath(
          type:
              _parseBreathType(map['breathType'] ?? map['placement']) ??
              BreathType.comma,
        );
      case 'caesura':
        return Caesura(
          type:
              _parseBreathType(map['breathType'] ?? 'caesura') ??
              BreathType.caesura,
        );
      case 'chord':
        return _parseChord(map);
      case 'tuplet':
        return _parseTuplet(map);
      case 'repeatmark':
      case 'repeat':
        return RepeatMark(
          type:
              _parseRepeatType(map['repeatType'] ?? map['value']) ??
              RepeatType.start,
          label: _asString(map['label']),
          times: _asInt(map['times']),
        );
      case 'octavemark':
      case 'octave':
        return OctaveMark(
          type:
              _parseOctaveType(map['octaveType'] ?? map['value']) ??
              OctaveType.va8,
          startMeasure: _asInt(map['startMeasure']) ?? 0,
          endMeasure: _asInt(map['endMeasure']) ?? 0,
          startNote: _asInt(map['startNote']),
          endNote: _asInt(map['endNote']),
          length: _asDouble(map['length']) ?? 0.0,
          showBracket: _asBool(map['showBracket']) ?? true,
        );
      case 'voltabracket':
      case 'volta':
        return VoltaBracket(
          number: _asInt(map['number']) ?? 1,
          length: _asDouble(map['length']) ?? 0.0,
          hasOpenEnd: _asBool(map['hasOpenEnd']) ?? false,
          label: _asString(map['label']),
        );
      default:
        return null;
    }
  }

  Clef _parseClef(Map<String, dynamic> map) {
    final clefType =
        _parseClefType(map['clefType'] ?? map['value'] ?? map['typeName']) ??
        ClefType.treble;
    return Clef(
      clefType: clefType,
      staffPosition: _asInt(map['staffPosition']),
    );
  }

  Note _parseNote(Map<String, dynamic> map, {bool forceGrace = false}) {
    final pitch =
        _parsePitch(map['pitch']) ?? const Pitch(step: 'C', octave: 4);
    final isGrace = forceGrace || (_asBool(map['isGraceNote']) ?? false);

    return Note(
      pitch: pitch,
      duration: _parseDuration(map['duration'], grace: isGrace),
      beam: _parseBeamType(map['beam']),
      articulations: _parseArticulationList(map['articulations']),
      tie: _parseTieType(map['tie']),
      slur: _parseSlurType(map['slur']),
      ornaments: _parseOrnamentList(map['ornaments']),
      dynamicElement: _parseDynamicMap(map['dynamic'] ?? map['dynamicElement']),
      techniques: _parseTechniqueList(map['techniques']),
      voice: _asInt(map['voice']),
      tremoloStrokes: _asInt(map['tremoloStrokes']) ?? 0,
      isGraceNote: isGrace,
      alternatePitch: _parsePitch(map['alternatePitch']),
    );
  }

  Rest _parseRest(Map<String, dynamic> map) {
    return Rest(
      duration: _parseDuration(map['duration']),
      ornaments: _parseOrnamentList(map['ornaments']),
    );
  }

  Chord _parseChord(Map<String, dynamic> map) {
    final duration = _parseDuration(map['duration']);
    final List<Note> notes = <Note>[];

    for (final dynamic rawNote in _asList(map['notes'])) {
      final noteMap = _asMap(rawNote);
      if (noteMap == null) continue;
      final noteDuration = noteMap.containsKey('duration')
          ? _parseDuration(noteMap['duration'])
          : duration;
      notes.add(
        Note(
          pitch:
              _parsePitch(noteMap['pitch']) ??
              const Pitch(step: 'C', octave: 4),
          duration: noteDuration,
          articulations: _parseArticulationList(noteMap['articulations']),
          tie: _parseTieType(noteMap['tie']),
          slur: _parseSlurType(noteMap['slur']),
          ornaments: _parseOrnamentList(noteMap['ornaments']),
          dynamicElement: _parseDynamicMap(
            noteMap['dynamic'] ?? noteMap['dynamicElement'],
          ),
          techniques: _parseTechniqueList(noteMap['techniques']),
          voice: _asInt(noteMap['voice']) ?? _asInt(map['voice']),
          isGraceNote: _asBool(noteMap['isGraceNote']) ?? false,
          alternatePitch: _parsePitch(noteMap['alternatePitch']),
        ),
      );
    }

    return Chord(
      notes: notes,
      duration: duration,
      articulations: _parseArticulationList(map['articulations']),
      tie: _parseTieType(map['tie']),
      slur: _parseSlurType(map['slur']),
      beam: _parseBeamType(map['beam']),
      ornaments: _parseOrnamentList(map['ornaments']),
      dynamic: _parseDynamicMap(map['dynamic']),
      voice: _asInt(map['voice']),
    );
  }

  Tuplet _parseTuplet(Map<String, dynamic> map) {
    final List<MusicalElement> elements = <MusicalElement>[];
    for (final dynamic rawElement in _asList(map['elements'])) {
      final element = _parseElement(rawElement);
      if (element != null) {
        elements.add(element);
      }
    }

    final bracketMap = _asMap(map['bracket']);
    final numberMap = _asMap(map['number']);

    return Tuplet(
      actualNotes: _asInt(map['actualNotes']) ?? 3,
      normalNotes: _asInt(map['normalNotes']) ?? 2,
      elements: elements,
      bracketConfig: bracketMap == null
          ? null
          : TupletBracket(
              show: _asBool(bracketMap['show']) ?? true,
              thickness: _asDouble(bracketMap['thickness']) ?? 0.125,
              hookLength: _asDouble(bracketMap['hookLength']) ?? 0.9,
              side: _parseBracketSide(bracketMap['side']) ?? BracketSide.stem,
              slope: _asDouble(bracketMap['slope']) ?? 0.0,
              minDistanceFromNotes:
                  _asDouble(bracketMap['minDistanceFromNotes']) ?? 0.75,
            ),
      numberConfig: numberMap == null
          ? null
          : TupletNumber(
              fontSize: _asDouble(numberMap['fontSize']) ?? 1.2,
              gapLeft: _asDouble(numberMap['gapLeft']) ?? 0.4,
              gapRight: _asDouble(numberMap['gapRight']) ?? 0.5,
              showAsRatio: _asBool(numberMap['showAsRatio']) ?? false,
              showNoteValue: _asBool(numberMap['showNoteValue']) ?? false,
            ),
      isNested: _asBool(map['isNested']) ?? false,
      timeSignature: _parseTimeSignatureMap(_asMap(map['timeSignature'])),
    );
  }

  Dynamic? _parseDynamicMap(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return null;
    return _parseDynamic(map);
  }

  Dynamic _parseDynamic(Map<String, dynamic> map) {
    final rawType =
        _asString(map['dynamicType']) ??
        _asString(map['value']) ??
        _asString(map['mark']);
    final dynamicType = _parseDynamicType(rawType) ?? DynamicType.mf;
    return Dynamic(
      type: dynamicType,
      customText: _asString(map['customText']) ?? _asString(map['text']),
      isHairpin: _asBool(map['isHairpin']) ?? false,
      length: _asDouble(map['length']),
    );
  }

  TempoMark _parseTempo(Map<String, dynamic> map) {
    return TempoMark(
      beatUnit:
          _parseDurationType(
            _asString(map['beatUnit']) ?? _asString(map['unit']),
          ) ??
          DurationType.quarter,
      bpm: _asInt(map['bpm']),
      text: _asString(map['text']),
      showMetronome: _asBool(map['showMetronome']) ?? true,
    );
  }

  MusicText _parseMusicText(Map<String, dynamic> map) {
    return MusicText(
      text: _asString(map['text']) ?? '',
      type:
          _parseTextType(map['textType'] ?? map['value']) ??
          TextType.expression,
      placement: _parseTextPlacement(map['placement']) ?? TextPlacement.above,
      fontFamily: _asString(map['fontFamily']),
      fontSize: _asDouble(map['fontSize']),
      bold: _asBool(map['bold']),
      italic: _asBool(map['italic']),
    );
  }
}

class _MusicXmlImportParser {
  _MusicXmlImportParser({required this.partIndex});

  final int partIndex;

  Staff parse(XmlDocument document) {
    final root = document.rootElement;
    switch (root.name.local) {
      case 'score-partwise':
        return _parsePartwise(root);
      case 'score-timewise':
        return _parseTimewise(root);
      default:
        throw const FormatException(
          'MusicXML root must be score-partwise or score-timewise.',
        );
    }
  }

  Staff _parsePartwise(XmlElement root) {
    final parts = root.findElements('part').toList();
    if (parts.isEmpty) return Staff();
    if (partIndex < 0 || partIndex >= parts.length) {
      throw FormatException(
        'Requested partIndex $partIndex, but MusicXML contains ${parts.length} part(s).',
      );
    }

    final staff = Staff();
    for (final measureElement in parts[partIndex].findElements('measure')) {
      staff.add(_parseMeasure(measureElement));
    }
    return staff;
  }

  Staff _parseTimewise(XmlElement root) {
    final staff = Staff();
    for (final measureElement in root.findElements('measure')) {
      final parts = measureElement.findElements('part').toList();
      if (parts.isEmpty) continue;
      if (partIndex < 0 || partIndex >= parts.length) {
        throw FormatException(
          'Requested partIndex $partIndex, but a score-timewise measure contains ${parts.length} part(s).',
        );
      }
      staff.add(_parseMeasure(parts[partIndex]));
    }
    return staff;
  }

  Measure _parseMeasure(XmlElement measureElement) {
    final Map<int, _VoiceAccumulator> voices = <int, _VoiceAccumulator>{};
    final List<MusicalElement> metadataElements = <MusicalElement>[];
    TimeSignature? currentTimeSignature;

    _VoiceAccumulator voice(int number) {
      return voices.putIfAbsent(number, () => _VoiceAccumulator(number));
    }

    void appendLeadElement(MusicalElement element) {
      voice(1).append(element);
      if (_isSystemElement(element)) {
        metadataElements.add(element);
      }
      if (element is TimeSignature) {
        currentTimeSignature = element;
      }
    }

    for (final child in measureElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'attributes':
          for (final element in _parseMusicXmlAttributes(child)) {
            appendLeadElement(element);
          }
          break;
        case 'direction':
          for (final element in _parseMusicXmlDirections(child)) {
            appendLeadElement(element);
          }
          break;
        case 'barline':
          for (final element in _parseMusicXmlBarline(child)) {
            appendLeadElement(element);
          }
          break;
        case 'note':
          _parseMusicXmlNoteNode(
            child,
            voiceForNumber: voice,
            currentTimeSignature: currentTimeSignature,
          );
          break;
        case 'backup':
        case 'forward':
          break;
      }
    }

    if (voices.isEmpty || (voices.length == 1 && !voices.containsKey(2))) {
      final measure = Measure();
      for (final element in voice(1).elements) {
        _appendElementToMeasure(measure, element);
      }
      return measure;
    }

    final measure = MultiVoiceMeasure();
    for (final element in metadataElements.where(_isSystemElement)) {
      _appendElementToMeasure(measure, element);
    }

    final voiceNumbers = voices.keys.toList()..sort();
    for (final number in voiceNumbers) {
      final accumulator = voices[number]!;
      accumulator.finishTuplet();
      measure.addVoice(Voice(number: number, elements: accumulator.elements));
    }
    return measure;
  }

  void _parseMusicXmlNoteNode(
    XmlElement noteElement, {
    required _VoiceAccumulator Function(int number) voiceForNumber,
    required TimeSignature? currentTimeSignature,
  }) {
    final int voiceNumber = _asInt(_childText(noteElement, 'voice')) ?? 1;
    final accumulator = voiceForNumber(voiceNumber);
    final bool isChordTone = noteElement.findElements('chord').isNotEmpty;
    final duration = _musicXmlDurationFromNote(noteElement);
    final bool isGrace = noteElement.findElements('grace').isNotEmpty;

    MusicalElement? baseElement;
    if (noteElement.findElements('rest').isNotEmpty) {
      baseElement = Rest(
        duration: duration,
        ornaments: _musicXmlOrnaments(noteElement, onRest: true),
      );
    } else {
      final pitch = _musicXmlPitch(noteElement);
      if (pitch == null) return;
      final note = Note(
        pitch: pitch,
        duration: duration,
        beam: _musicXmlBeamType(noteElement),
        articulations: _musicXmlArticulations(noteElement),
        tie: _musicXmlTieType(noteElement),
        slur: _musicXmlSlurType(noteElement),
        ornaments: _musicXmlOrnaments(noteElement),
        voice: voiceNumber,
        isGraceNote: isGrace,
      );
      if (isChordTone) {
        if (!accumulator.mergeChordNote(note)) {
          baseElement = note;
        }
      } else {
        baseElement = note;
      }
    }

    final tuplets = _musicXmlTupletInfo(noteElement);
    if (tuplets.startsTuplet) {
      accumulator.startTuplet(
        actualNotes: tuplets.actualNotes,
        normalNotes: tuplets.normalNotes,
        timeSignature: currentTimeSignature,
      );
    }

    if (baseElement != null) {
      accumulator.append(baseElement);
    }

    for (final extra in _musicXmlPostNoteElements(noteElement)) {
      accumulator.append(extra);
    }

    if (tuplets.endsTuplet) {
      accumulator.finishTuplet();
    }
  }
}

List<MusicalElement> _parseMusicXmlAttributes(XmlElement attributesElement) {
  final List<MusicalElement> result = <MusicalElement>[];

  for (final child in attributesElement.children.whereType<XmlElement>()) {
    switch (child.name.local) {
      case 'clef':
        final clef = _musicXmlClef(child);
        if (clef != null) result.add(clef);
        break;
      case 'key':
        final fifths = _asInt(_childText(child, 'fifths'));
        if (fifths != null) {
          result.add(KeySignature(fifths));
        }
        break;
      case 'time':
        final beats = _asInt(_childText(child, 'beats'));
        final beatType = _asInt(_childText(child, 'beat-type'));
        if (beats != null && beatType != null) {
          result.add(TimeSignature(numerator: beats, denominator: beatType));
        }
        break;
    }
  }

  return result;
}

List<MusicalElement> _parseMusicXmlDirections(XmlElement directionElement) {
  final List<MusicalElement> result = <MusicalElement>[];
  for (final directionType in directionElement.findElements('direction-type')) {
    for (final child in directionType.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'dynamics':
          final dynamicType = _parseDynamicType(
            child.children.whereType<XmlElement>().firstOrNull?.name.local,
          );
          if (dynamicType != null) {
            result.add(Dynamic(type: dynamicType));
          }
          break;
        case 'words':
          final text = child.innerText.trim();
          if (text.isEmpty) break;
          final repeatType = _parseRepeatType(text);
          if (repeatType != null) {
            result.add(RepeatMark(type: repeatType, label: text));
          } else {
            result.add(MusicText(text: text, type: TextType.expression));
          }
          break;
        case 'metronome':
          result.add(
            TempoMark(
              beatUnit:
                  _parseDurationType(_childText(child, 'beat-unit')) ??
                  DurationType.quarter,
              bpm: _asInt(_childText(child, 'per-minute')),
            ),
          );
          break;
        case 'segno':
          result.add(RepeatMark(type: RepeatType.segno));
          break;
        case 'coda':
          result.add(RepeatMark(type: RepeatType.coda));
          break;
        case 'rehearsal':
          final text = child.innerText.trim();
          if (text.isNotEmpty) {
            result.add(MusicText(text: text, type: TextType.rehearsal));
          }
          break;
        case 'octave-shift':
          final octave = _musicXmlOctaveShift(child);
          if (octave != null) {
            result.add(octave);
          }
          break;
      }
    }
  }

  return result;
}

List<MusicalElement> _parseMusicXmlBarline(XmlElement barlineElement) {
  final List<MusicalElement> result = <MusicalElement>[];
  BarlineType? type = _parseBarlineType(
    _childText(barlineElement, 'bar-style'),
  );

  final repeat = barlineElement.findElements('repeat').firstOrNull;
  if (repeat != null) {
    final direction = _normalizeToken(repeat.getAttribute('direction'));
    if (direction == 'forward') {
      type = type == BarlineType.repeatBackward
          ? BarlineType.repeatBoth
          : BarlineType.repeatForward;
    } else if (direction == 'backward') {
      type = type == BarlineType.repeatForward
          ? BarlineType.repeatBoth
          : BarlineType.repeatBackward;
    }
  }

  result.add(Barline(type: type ?? BarlineType.single));

  final ending = barlineElement.findElements('ending').firstOrNull;
  if (ending != null) {
    result.add(
      VoltaBracket(
        number: _asInt(ending.getAttribute('number')) ?? 1,
        label: ending.innerText.trim().isEmpty ? null : ending.innerText.trim(),
        hasOpenEnd: _normalizeToken(ending.getAttribute('type')) != 'stop',
        length: 0.0,
      ),
    );
  }

  return result;
}

Barline? _meiBarlineFromToken(String? raw) {
  final type = _parseBarlineType(raw);
  if (type == null || type == BarlineType.none) {
    return null;
  }
  return Barline(type: type);
}

Barline? _meiBarline(XmlElement element) {
  return _meiBarlineFromToken(
    element.getAttribute('form') ??
        element.getAttribute('right') ??
        element.getAttribute('left'),
  );
}

RepeatMark? _meiRepeatMark(XmlElement element) {
  final label = element.innerText.trim().isEmpty
      ? element.getAttribute('label')
      : element.innerText.trim();
  final type = _parseRepeatType(
    element.getAttribute('func') ??
        element.getAttribute('glyph.name') ??
        element.getAttribute('type') ??
        label,
  );
  if (type == null) return null;
  return RepeatMark(
    type: type,
    label: label == null || label.trim().isEmpty ? null : label.trim(),
  );
}

Pitch? _musicXmlPitch(XmlElement noteElement) {
  final pitchElement = noteElement.findElements('pitch').firstOrNull;
  if (pitchElement == null) return null;

  final step = _childText(pitchElement, 'step')?.toUpperCase();
  final octave = _asInt(_childText(pitchElement, 'octave'));
  if (step == null || octave == null) return null;

  final accidentalType = _parseAccidentalType(
    _childText(noteElement, 'accidental'),
  );

  return Pitch(
    step: step,
    octave: octave,
    alter:
        _asDouble(_childText(pitchElement, 'alter')) ??
        accidentalToAlter[accidentalType] ??
        0.0,
    accidentalType: accidentalType,
  );
}

Duration _musicXmlDurationFromNote(XmlElement noteElement) {
  return Duration(
    _parseDurationType(_childText(noteElement, 'type')) ?? DurationType.quarter,
    dots: noteElement.findElements('dot').length,
  );
}

List<ArticulationType> _musicXmlArticulations(XmlElement noteElement) {
  final List<ArticulationType> articulations = <ArticulationType>[];
  final notations = noteElement.findElements('notations').firstOrNull;
  final articulationParent = notations
      ?.findElements('articulations')
      .firstOrNull;
  if (articulationParent == null) return articulations;

  for (final child in articulationParent.children.whereType<XmlElement>()) {
    final type = _parseEnumByName<ArticulationType>(
      ArticulationType.values,
      child.name.local,
      aliases: <String, ArticulationType>{
        'strongaccent': ArticulationType.strongAccent,
        'upbow': ArticulationType.upBow,
        'downbow': ArticulationType.downBow,
        'halfstopped': ArticulationType.halfStopped,
      },
    );
    if (type != null) {
      articulations.add(type);
    }
  }

  return articulations;
}

List<Ornament> _musicXmlOrnaments(
  XmlElement noteElement, {
  bool onRest = false,
}) {
  final List<Ornament> ornaments = <Ornament>[];
  for (final notations in noteElement.findElements('notations')) {
    final ornamentsElement = notations.findElements('ornaments').firstOrNull;
    if (ornamentsElement != null) {
      for (final child in ornamentsElement.children.whereType<XmlElement>()) {
        final type = _parseOrnamentType(child.name.local);
        if (type != null) {
          ornaments.add(Ornament(type: type));
        }
      }
    }

    for (final fermata in notations.findElements('fermata')) {
      ornaments.add(
        Ornament(
          type: _normalizeToken(fermata.getAttribute('type')) == 'inverted'
              ? OrnamentType.fermataBelow
              : OrnamentType.fermata,
        ),
      );
    }
  }
  return ornaments;
}

TieType? _musicXmlTieType(XmlElement noteElement) {
  TieType? tie;
  for (final tieElement in noteElement.findElements('tie')) {
    final parsed = _parseTieType(tieElement.getAttribute('type'));
    tie = parsed ?? tie;
  }
  return tie;
}

SlurType? _musicXmlSlurType(XmlElement noteElement) {
  SlurType? slur;
  for (final notations in noteElement.findElements('notations')) {
    for (final slurElement in notations.findElements('slur')) {
      final parsed = _parseSlurType(slurElement.getAttribute('type'));
      slur = parsed ?? slur;
    }
  }
  return slur;
}

BeamType? _musicXmlBeamType(XmlElement noteElement) {
  final beamElement = noteElement.findElements('beam').firstOrNull;
  return beamElement == null ? null : _parseBeamType(beamElement.innerText);
}

_TupletEventInfo _musicXmlTupletInfo(XmlElement noteElement) {
  final timeModification = noteElement
      .findElements('time-modification')
      .firstOrNull;
  int actualNotes = _asInt(_childText(timeModification, 'actual-notes')) ?? 3;
  int normalNotes = _asInt(_childText(timeModification, 'normal-notes')) ?? 2;
  bool starts = false;
  bool ends = false;

  for (final notations in noteElement.findElements('notations')) {
    for (final tuplet in notations.findElements('tuplet')) {
      final type = _normalizeToken(tuplet.getAttribute('type'));
      if (type == 'start') starts = true;
      if (type == 'stop') ends = true;
      actualNotes = _asInt(tuplet.getAttribute('actual-notes')) ?? actualNotes;
      normalNotes = _asInt(tuplet.getAttribute('normal-notes')) ?? normalNotes;
    }
  }

  return _TupletEventInfo(
    startsTuplet: starts,
    endsTuplet: ends,
    actualNotes: actualNotes,
    normalNotes: normalNotes,
  );
}

List<MusicalElement> _musicXmlPostNoteElements(XmlElement noteElement) {
  final List<MusicalElement> extras = <MusicalElement>[];
  for (final notations in noteElement.findElements('notations')) {
    final articulations = notations.findElements('articulations').firstOrNull;
    if (articulations == null) continue;
    for (final child in articulations.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'breath-mark':
          extras.add(Breath(type: BreathType.comma));
          break;
        case 'caesura':
          extras.add(Caesura());
          break;
      }
    }
  }
  return extras;
}

Clef? _musicXmlClef(XmlElement clefElement) {
  final sign = _childText(clefElement, 'sign');
  final line = _asInt(_childText(clefElement, 'line'));
  final octaveChange =
      _asInt(_childText(clefElement, 'clef-octave-change')) ?? 0;

  if (sign == null) return null;
  final normalizedSign = _normalizeToken(sign);
  ClefType? clefType;

  if (normalizedSign == 'g') {
    clefType = switch (octaveChange) {
      1 => ClefType.treble8va,
      -1 => ClefType.treble8vb,
      2 => ClefType.treble15ma,
      -2 => ClefType.treble15mb,
      _ => ClefType.treble,
    };
  } else if (normalizedSign == 'f') {
    if (line == 3) {
      clefType = ClefType.bassThirdLine;
    } else {
      clefType = switch (octaveChange) {
        1 => ClefType.bass8va,
        -1 => ClefType.bass8vb,
        2 => ClefType.bass15ma,
        -2 => ClefType.bass15mb,
        _ => ClefType.bass,
      };
    }
  } else if (normalizedSign == 'c') {
    clefType = switch (line) {
      1 => ClefType.soprano,
      2 => ClefType.mezzoSoprano,
      4 => ClefType.tenor,
      5 => ClefType.baritone,
      _ => ClefType.alto,
    };
  } else if (normalizedSign == 'percussion') {
    clefType = ClefType.percussion;
  } else if (normalizedSign == 'tab') {
    clefType = ClefType.tab6;
  }

  return clefType == null ? null : Clef(clefType: clefType);
}

OctaveMark? _musicXmlOctaveShift(XmlElement octaveShiftElement) {
  final type = _normalizeToken(octaveShiftElement.getAttribute('type'));
  if (type == 'stop') return null;
  final size = _asInt(octaveShiftElement.getAttribute('size')) ?? 8;
  final placement = _normalizeToken(
    octaveShiftElement.getAttribute('placement') ??
        octaveShiftElement.getAttribute('type'),
  );

  return OctaveMark(
    type: switch ('$size:$placement') {
      '8:down' => OctaveType.vb8,
      '15:up' => OctaveType.va15,
      '15:down' => OctaveType.vb15,
      '22:up' => OctaveType.va22,
      '22:down' => OctaveType.vb22,
      _ => OctaveType.va8,
    },
    startMeasure: 0,
    endMeasure: 0,
    length: 0.0,
  );
}

class _MeiImportParser {
  _MeiImportParser({required this.staffIndex});

  final int staffIndex;

  Staff parse(XmlDocument document) {
    final root = document.rootElement;
    if (root.name.local != 'mei') {
      throw const FormatException('MEI root element must be <mei>.');
    }

    final score = root.findAllElements('score').firstOrNull;
    if (score == null) return Staff();

    final section = score.findAllElements('section').firstOrNull;
    if (section == null) return Staff();

    final staff = Staff();
    for (final measure in section.findElements('measure')) {
      staff.add(_parseMeasure(measure));
    }
    return staff;
  }

  Measure _parseMeasure(XmlElement measureElement) {
    final Map<int, _VoiceAccumulator> voices = <int, _VoiceAccumulator>{};
    final List<MusicalElement> metadataElements = <MusicalElement>[];
    TimeSignature? currentTimeSignature;

    _VoiceAccumulator voice(int number) {
      return voices.putIfAbsent(number, () => _VoiceAccumulator(number));
    }

    void appendLead(MusicalElement element) {
      voice(1).append(element);
      if (_isSystemElement(element)) {
        metadataElements.add(element);
      }
      if (element is TimeSignature) {
        currentTimeSignature = element;
      }
    }

    final staffElements = measureElement.findElements('staff').toList();
    if (staffElements.isEmpty) {
      return Measure();
    }
    if (staffIndex < 0 || staffIndex >= staffElements.length) {
      throw FormatException(
        'Requested staffIndex $staffIndex, but MEI measure contains ${staffElements.length} staff/staves.',
      );
    }

    final staffElement = staffElements[staffIndex];

    final leftBarline = _meiBarlineFromToken(
      measureElement.getAttribute('left'),
    );
    if (leftBarline != null) {
      appendLead(leftBarline);
    }

    for (final child in staffElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'clef':
          final clef = _meiClef(child);
          if (clef != null) appendLead(clef);
          break;
        case 'keySig':
          final key = _meiKeySignature(child);
          if (key != null) appendLead(key);
          break;
        case 'meterSig':
          final meter = _meiTimeSignature(child);
          if (meter != null) appendLead(meter);
          break;
        case 'layer':
          _parseMeiLayer(
            child,
            voiceForNumber: voice,
            currentTimeSignature: currentTimeSignature,
          );
          break;
        case 'dir':
          final text = child.innerText.trim();
          if (text.isNotEmpty) {
            final repeatType = _parseRepeatType(text);
            if (repeatType != null) {
              appendLead(RepeatMark(type: repeatType, label: text));
            } else {
              appendLead(MusicText(text: text, type: TextType.expression));
            }
          }
          break;
        case 'dynam':
          appendLead(
            Dynamic(
              type: _parseDynamicType(child.innerText.trim()) ?? DynamicType.mf,
            ),
          );
          break;
        case 'tempo':
          appendLead(
            TempoMark(
              beatUnit:
                  _parseDurationType(child.getAttribute('unit')) ??
                  DurationType.quarter,
              bpm: _asInt(
                child.getAttribute('mm') ?? child.getAttribute('midi.bpm'),
              ),
              text: child.innerText.trim().isEmpty
                  ? null
                  : child.innerText.trim(),
            ),
          );
          break;
        case 'breath':
          appendLead(Breath(type: BreathType.comma));
          break;
        case 'caesura':
          appendLead(Caesura());
          break;
        case 'octave':
        case 'octaveshift':
          final octave = _meiOctaveMark(child);
          if (octave != null) appendLead(octave);
          break;
        case 'ending':
          appendLead(
            VoltaBracket(
              number: _asInt(child.getAttribute('n')) ?? 1,
              label: child.getAttribute('label'),
              length: 0.0,
            ),
          );
          break;
        case 'repeatMark':
          final repeatMark = _meiRepeatMark(child);
          if (repeatMark != null) appendLead(repeatMark);
          break;
        case 'barLine':
          final barline = _meiBarline(child);
          if (barline != null) appendLead(barline);
          break;
      }
    }

    final rightBarline = _meiBarlineFromToken(
      measureElement.getAttribute('right'),
    );
    if (rightBarline != null) {
      appendLead(rightBarline);
    }

    if (voices.isEmpty || (voices.length == 1 && !voices.containsKey(2))) {
      final measure = Measure();
      for (final element in voice(1).elements) {
        _appendElementToMeasure(measure, element);
      }
      return measure;
    }

    final measure = MultiVoiceMeasure();
    for (final element in metadataElements.where(_isSystemElement)) {
      _appendElementToMeasure(measure, element);
    }

    final voiceNumbers = voices.keys.toList()..sort();
    for (final number in voiceNumbers) {
      final accumulator = voices[number]!;
      accumulator.finishTuplet();
      measure.addVoice(Voice(number: number, elements: accumulator.elements));
    }
    return measure;
  }

  void _parseMeiLayer(
    XmlElement layerElement, {
    required _VoiceAccumulator Function(int number) voiceForNumber,
    required TimeSignature? currentTimeSignature,
  }) {
    final int voiceNumber = _asInt(layerElement.getAttribute('n')) ?? 1;
    final accumulator = voiceForNumber(voiceNumber);

    for (final child in layerElement.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'note':
          final note = _meiNote(child, voiceNumber: voiceNumber);
          if (note == null) continue;
          final tupletInfo = _meiTupletInfo(child);
          if (tupletInfo.startsTuplet) {
            accumulator.startTuplet(
              actualNotes: tupletInfo.actualNotes,
              normalNotes: tupletInfo.normalNotes,
              timeSignature: currentTimeSignature,
            );
          }
          accumulator.append(note);
          if (tupletInfo.endsTuplet) {
            accumulator.finishTuplet();
          }
          break;
        case 'rest':
          final rest = _meiRest(child);
          final tupletInfo = _meiTupletInfo(child);
          if (tupletInfo.startsTuplet) {
            accumulator.startTuplet(
              actualNotes: tupletInfo.actualNotes,
              normalNotes: tupletInfo.normalNotes,
              timeSignature: currentTimeSignature,
            );
          }
          accumulator.append(rest);
          if (tupletInfo.endsTuplet) {
            accumulator.finishTuplet();
          }
          break;
        case 'chord':
          final chord = _meiChord(child, voiceNumber: voiceNumber);
          if (chord == null) continue;
          final tupletInfo = _meiTupletInfo(child);
          if (tupletInfo.startsTuplet) {
            accumulator.startTuplet(
              actualNotes: tupletInfo.actualNotes,
              normalNotes: tupletInfo.normalNotes,
              timeSignature: currentTimeSignature,
            );
          }
          accumulator.append(chord);
          if (tupletInfo.endsTuplet) {
            accumulator.finishTuplet();
          }
          break;
        case 'dynam':
          accumulator.append(
            Dynamic(
              type: _parseDynamicType(child.innerText.trim()) ?? DynamicType.mf,
            ),
          );
          break;
        case 'tempo':
          accumulator.append(
            TempoMark(
              beatUnit:
                  _parseDurationType(child.getAttribute('unit')) ??
                  DurationType.quarter,
              bpm: _asInt(
                child.getAttribute('mm') ?? child.getAttribute('midi.bpm'),
              ),
              text: child.innerText.trim().isEmpty
                  ? null
                  : child.innerText.trim(),
            ),
          );
          break;
        case 'dir':
          final text = child.innerText.trim();
          if (text.isEmpty) continue;
          final repeatType = _parseRepeatType(text);
          if (repeatType != null) {
            accumulator.append(RepeatMark(type: repeatType, label: text));
          } else {
            accumulator.append(
              MusicText(text: text, type: TextType.expression),
            );
          }
          break;
        case 'breath':
          accumulator.append(Breath(type: BreathType.comma));
          break;
        case 'caesura':
          accumulator.append(Caesura());
          break;
        case 'repeatMark':
          final repeatMark = _meiRepeatMark(child);
          if (repeatMark != null) {
            accumulator.append(repeatMark);
          }
          break;
        case 'barLine':
          final barline = _meiBarline(child);
          if (barline != null) {
            accumulator.append(barline);
          }
          break;
      }
    }
  }
}

Clef? _meiClef(XmlElement clefElement) {
  final sign =
      clefElement.getAttribute('shape') ?? clefElement.getAttribute('sign');
  final line = _asInt(clefElement.getAttribute('line'));
  final dis = _asInt(clefElement.getAttribute('dis')) ?? 0;
  final disPlace = _normalizeToken(clefElement.getAttribute('dis.place'));

  if (sign == null) return null;
  final normalizedSign = _normalizeToken(sign);

  if (normalizedSign == 'g') {
    if (dis == 8 && disPlace == 'above') {
      return Clef(clefType: ClefType.treble8va);
    }
    if (dis == 8 && disPlace == 'below') {
      return Clef(clefType: ClefType.treble8vb);
    }
    if (dis == 15 && disPlace == 'above') {
      return Clef(clefType: ClefType.treble15ma);
    }
    if (dis == 15 && disPlace == 'below') {
      return Clef(clefType: ClefType.treble15mb);
    }
    return Clef(clefType: ClefType.treble);
  }

  if (normalizedSign == 'f') {
    if (line == 3) return Clef(clefType: ClefType.bassThirdLine);
    if (dis == 8 && disPlace == 'above') {
      return Clef(clefType: ClefType.bass8va);
    }
    if (dis == 8 && disPlace == 'below') {
      return Clef(clefType: ClefType.bass8vb);
    }
    if (dis == 15 && disPlace == 'above') {
      return Clef(clefType: ClefType.bass15ma);
    }
    if (dis == 15 && disPlace == 'below') {
      return Clef(clefType: ClefType.bass15mb);
    }
    return Clef(clefType: ClefType.bass);
  }

  if (normalizedSign == 'c') {
    return Clef(
      clefType: switch (line) {
        1 => ClefType.soprano,
        2 => ClefType.mezzoSoprano,
        4 => ClefType.tenor,
        5 => ClefType.baritone,
        _ => ClefType.alto,
      },
    );
  }

  if (normalizedSign == 'perc') {
    return Clef(clefType: ClefType.percussion);
  }

  if (normalizedSign == 'tab') {
    return Clef(clefType: ClefType.tab6);
  }

  return null;
}

KeySignature? _meiKeySignature(XmlElement keySigElement) {
  final sig = keySigElement.getAttribute('sig');
  if (sig == null || sig.trim().isEmpty) return null;
  final normalized = sig.trim().toLowerCase();
  if (normalized == '0') {
    return KeySignature(0);
  }

  final match = RegExp(r'^(-?\d+)([sf])$').firstMatch(normalized);
  if (match == null) return null;
  final count = int.tryParse(match.group(1)!);
  final suffix = match.group(2);
  if (count == null) return null;
  return KeySignature(suffix == 'f' ? -count : count);
}

TimeSignature? _meiTimeSignature(XmlElement meterSigElement) {
  final numerator = _asInt(
    meterSigElement.getAttribute('count') ??
        meterSigElement.getAttribute('meter.count'),
  );
  final denominator = _asInt(
    meterSigElement.getAttribute('unit') ??
        meterSigElement.getAttribute('meter.unit'),
  );
  if (numerator == null || denominator == null) return null;
  return TimeSignature(numerator: numerator, denominator: denominator);
}

Note? _meiNote(XmlElement noteElement, {required int voiceNumber}) {
  final step = noteElement.getAttribute('pname')?.toUpperCase();
  final octave = _asInt(noteElement.getAttribute('oct'));
  if (step == null || octave == null) return null;

  final accidentalType = _parseAccidentalType(
    noteElement.getAttribute('accid') ?? noteElement.getAttribute('accid.ges'),
  );

  return Note(
    pitch: Pitch(
      step: step,
      octave: octave,
      alter: accidentalToAlter[accidentalType] ?? 0.0,
      accidentalType: accidentalType,
    ),
    duration: Duration(
      _parseDurationType(noteElement.getAttribute('dur')) ??
          DurationType.quarter,
      dots: _asInt(noteElement.getAttribute('dots')) ?? 0,
    ),
    beam: _parseBeamType(noteElement.getAttribute('beam')),
    articulations: _parseArticulationList(
      noteElement.getAttribute('artic')?.split(RegExp(r'\s+')),
    ),
    tie: _parseTieType(noteElement.getAttribute('tie')),
    slur: _parseSlurType(noteElement.getAttribute('slur')),
    ornaments: _parseOrnamentList(noteElement.getAttribute('ornam')),
    voice: voiceNumber,
    isGraceNote: noteElement.getAttribute('grace') != null,
  );
}

Rest _meiRest(XmlElement restElement) {
  return Rest(
    duration: Duration(
      _parseDurationType(restElement.getAttribute('dur')) ??
          DurationType.quarter,
      dots: _asInt(restElement.getAttribute('dots')) ?? 0,
    ),
    ornaments: _parseOrnamentList(restElement.getAttribute('ornam')),
  );
}

Chord? _meiChord(XmlElement chordElement, {required int voiceNumber}) {
  final duration = Duration(
    _parseDurationType(chordElement.getAttribute('dur')) ??
        DurationType.quarter,
    dots: _asInt(chordElement.getAttribute('dots')) ?? 0,
  );

  final List<Note> notes = <Note>[];
  for (final child in chordElement.findElements('note')) {
    final note = _meiNote(child, voiceNumber: voiceNumber);
    if (note != null) {
      notes.add(
        Note(
          pitch: note.pitch,
          duration: duration,
          articulations: note.articulations,
          tie: note.tie,
          slur: note.slur,
          ornaments: note.ornaments,
          voice: voiceNumber,
          isGraceNote: note.isGraceNote,
        ),
      );
    }
  }

  if (notes.isEmpty) return null;

  return Chord(
    notes: notes,
    duration: duration,
    articulations: _parseArticulationList(
      chordElement.getAttribute('artic')?.split(RegExp(r'\s+')),
    ),
    tie: _parseTieType(chordElement.getAttribute('tie')),
    slur: _parseSlurType(chordElement.getAttribute('slur')),
    beam: _parseBeamType(chordElement.getAttribute('beam')),
    ornaments: _parseOrnamentList(chordElement.getAttribute('ornam')),
    voice: voiceNumber,
  );
}

OctaveMark? _meiOctaveMark(XmlElement element) {
  final size = _asInt(element.getAttribute('dis')) ?? 8;
  final placement = _normalizeToken(
    element.getAttribute('dis.place') ?? element.getAttribute('place'),
  );
  return OctaveMark(
    type: switch ('$size:$placement') {
      '8:below' => OctaveType.vb8,
      '15:above' => OctaveType.va15,
      '15:below' => OctaveType.vb15,
      '22:above' => OctaveType.va22,
      '22:below' => OctaveType.vb22,
      _ => OctaveType.va8,
    },
    startMeasure: 0,
    endMeasure: 0,
    length: 0.0,
  );
}

_TupletEventInfo _meiTupletInfo(XmlElement element) {
  final num = _asInt(element.getAttribute('num'));
  final numbase = _asInt(element.getAttribute('numbase'));
  final tupletState = _normalizeToken(element.getAttribute('tuplet'));

  return _TupletEventInfo(
    startsTuplet:
        (tupletState == 'start' || element.name.local == 'tuplet') &&
        num != null &&
        numbase != null,
    endsTuplet:
        (tupletState == 'end' || element.name.local == 'tuplet') &&
        num != null &&
        numbase != null,
    actualNotes: num ?? 3,
    normalNotes: numbase ?? 2,
  );
}

String? _childText(XmlElement? element, String childName) {
  return element?.findElements(childName).firstOrNull?.innerText;
}
