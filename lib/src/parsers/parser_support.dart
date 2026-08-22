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

/// Imports every part/staff of a MusicXML document into a [Score].
Score parseMusicXmlScore(String source) {
  final document = XmlDocument.parse(source);
  return _MusicXmlImportParser(partIndex: 0).parseScore(document);
}

Staff parseMeiStaff(String source, {int staffIndex = 0}) {
  final document = XmlDocument.parse(source);
  return _MeiImportParser(staffIndex: staffIndex).parse(document);
}

/// Imports every staff of an MEI document into a [Score], together with the
/// `<meiHead>` bibliographic metadata.
///
/// [parseMeiStaff] returns a bare [Staff], which has nowhere to keep a title,
/// a composer or a `<fileDesc>`; this is the route that surfaces them, in
/// [Score.meiHeader] (full header) and in [Score.title] / [Score.composer]
/// (convenience shortcuts).
///
/// GAP: `MEIParser` (lib/src/parsers/mei_parser.dart) still only exposes
/// `parseMEI` -> [parseMeiStaff], so this entry point is not reachable from the
/// package's public surface until that wrapper forwards to it.
Score parseMeiScore(String source) {
  final document = XmlDocument.parse(source);
  final root = document.rootElement;
  if (root.name.local != 'mei') {
    throw const FormatException('MEI root element must be <mei>.');
  }

  final header = _parseMeiHeader(root);
  final scoreElement = root.findAllElements('score').firstOrNull;
  final staffCount = scoreElement == null ? 1 : _meiStaffCount(scoreElement);
  final staves = <Staff>[
    for (var index = 0; index < staffCount; index++)
      _MeiImportParser(staffIndex: index).parse(document),
  ];

  final composer = header?.fileDescription.contributors
      .where((c) => c.role == ResponsibilityRole.composer)
      .firstOrNull
      ?.name;

  return Score(
    title: header?.fileDescription.title,
    subtitle: header?.fileDescription.subtitle,
    composer: composer,
    staffGroups: <StaffGroup>[
      StaffGroup(
        staves: staves,
        bracket: staves.length > 1 && scoreElement != null
            ? _meiStaffGrpBracket(scoreElement)
            : BracketType.none,
      ),
    ],
    meiHeader: header,
  );
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
      element is Tuplet ||
      element is Space;
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

/// The seven diatonic step letters accepted for a pitch, in MusicXML
/// `<step>`, MEI `@pname` and the JSON importer alike.
///
/// Validated locally (rather than through a `lib/core` API) so a malformed
/// source fails fast at import time with a readable [FormatException] instead
/// of crashing much later inside `Pitch.midiNumber` (F-10).
const List<String> _validPitchSteps = <String>[
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
];

/// Lowest octave number accepted by the importers.
const int _minPitchOctave = -1;

/// Highest octave number accepted by the importers.
const int _maxPitchOctave = 10;

/// Validates a raw step letter and returns it upper-cased.
///
/// [source] names the element/attribute the value came from so the thrown
/// message points at the offending part of the document.
///
/// Throws a [FormatException] when the letter is not one of C, D, E, F, G, A
/// or B (comparison is case-insensitive).
String _validatePitchStep(String raw, String source) {
  final step = raw.trim().toUpperCase();
  if (!_validPitchSteps.contains(step)) {
    throw FormatException(
      'Invalid pitch step "$raw" in $source. '
      'Expected one of ${_validPitchSteps.join(', ')}.',
    );
  }
  return step;
}

/// Validates a raw octave number and returns it unchanged.
///
/// Throws a [FormatException] when the octave falls outside
/// [_minPitchOctave]..[_maxPitchOctave].
int _validatePitchOctave(int octave, String source) {
  if (octave < _minPitchOctave || octave > _maxPitchOctave) {
    throw FormatException(
      'Invalid pitch octave "$octave" in $source. '
      'Expected $_minPitchOctave..$_maxPitchOctave.',
    );
  }
  return octave;
}

Pitch? _parsePitch(dynamic raw) {
  if (raw is String) {
    return Pitch.fromString(raw);
  }

  final map = _asMap(raw);
  if (map == null) return null;

  final rawStep = _asString(map['step']);
  final octave = _asInt(map['octave']);
  if (rawStep == null || octave == null) return null;
  final step = _validatePitchStep(rawStep, 'JSON pitch object');
  _validatePitchOctave(octave, 'JSON pitch object');

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
      // Lyrics and cross-staff routing used to be dropped on the floor here:
      // a note round-tripped through JSON came back with `syllables == null`
      // and `crossStaffMove == 0` however it went in.
      syllables: _parseSyllableList(map['syllables']),
      crossStaffMove: _asInt(map['crossStaffMove']) ?? 0,
      tabFret: _asInt(map['tabFret']),
      tabString: _asInt(map['tabString']),
    );
  }

  /// `[{"text": "Ky-", "type": "initial", "italic": false}, ...]`, or a bare
  /// list of strings for the simple case.
  List<Syllable>? _parseSyllableList(dynamic raw) {
    final list = _asList(raw);
    if (list.isEmpty) return null;
    final result = <Syllable>[];
    for (final dynamic entry in list) {
      if (entry is String) {
        result.add(Syllable(text: entry));
        continue;
      }
      final map = _asMap(entry);
      if (map == null) continue;
      final text = map['text'];
      if (text is! String) continue;
      result.add(
        Syllable(
          text: text,
          type: _parseSyllableType(map['type']),
          italic: _asBool(map['italic']) ?? false,
        ),
      );
    }
    return result.isEmpty ? null : result;
  }

  SyllableType _parseSyllableType(dynamic raw) {
    switch (_normalizeToken(raw?.toString())) {
      case 'initial':
      case 'begin':
        return SyllableType.initial;
      case 'middle':
        return SyllableType.middle;
      case 'end':
      case 'terminal':
        return SyllableType.terminal;
      default:
        return SyllableType.single;
    }
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

  /// Current `<divisions>` (ticks per quarter note) for the part being read.
  ///
  /// Declared by `<attributes><divisions>` and valid until redefined, so every
  /// measure inherits the value of the previous one. Reset to the MusicXML
  /// default of 1 at the start of each part/staff pass (F-06).
  int _divisions = 1;


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

  /// Imports EVERY part (and every staff within a part) as a Staff, grouped
  /// into a [Score] — so piano (2 staves) and SATB/ensemble (many parts) no
  /// longer collapse onto a single staff.
  Score parseScore(XmlDocument document) {
    final root = document.rootElement;
    final isPartwise = root.name.local == 'score-partwise';
    final isTimewise = root.name.local == 'score-timewise';
    if (!isPartwise && !isTimewise) {
      throw const FormatException(
        'MusicXML root must be score-partwise or score-timewise.',
      );
    }

    // Each part becomes its own StaffGroup; a multi-staff part (piano) is
    // braced as a grand staff. <part-group> spans in the <part-list> override
    // this by bracketing their member parts together.
    final groups = <StaffGroup>[];
    // <transpose> declarations, one entry per transposing staff, in the same
    // order as Score.allStaves. See _musicXmlTranspose for why the written
    // pitch is not altered here.
    final transpositions = <Map<String, dynamic>>[];
    var globalStaffIndex = 0;
    if (isPartwise) {
      final partList = _parsePartList(root);
      // Build each part's staves first, keeping its id.
      final partsData = <({String? id, List<Staff> staves, int count})>[];
      for (final part in root.findElements('part')) {
        final count = _partStaffCount(part);
        final partStaves = <Staff>[];
        for (var s = 1; s <= count; s++) {
          final filter = count == 1 ? null : s;
          // <staff-details><staff-lines> decides the staff size (1 = percussion,
          // 6 = guitar tablature); Staff.lineCount is final, so it has to be
          // known before the measures are added.
          final partId = part.getAttribute('id');
          final transposition = _musicXmlTranspose(part, staffNumber: filter);
          final staff = Staff(
            lineCount: _musicXmlStaffLines([part], staffNumber: filter),
            // <part-name>/<part-abbreviation> used to be dropped on the floor:
            // `StaffGroup.name` came back null and `Staff` had no name at all,
            // so every instrument label of an imported conductor score was
            // lost. A multi-staff part names its GROUP, not each staff.
            name: count == 1 ? partList.partName[partId] : null,
            abbreviation:
                count == 1 ? partList.partAbbreviation[partId] : null,
            transposition: _transpositionOf(transposition),
          );
          _divisions = 1; // <divisions> is per-part state; restart each pass.
          for (final m in part.findElements('measure')) {
            staff.add(_parseMeasure(m, staffFilter: filter));
          }
          if (transposition != null) {
            transpositions.add(_musicXmlTranspositionMetadata(
              transposition,
              partId: part.getAttribute('id'),
              staffIndex: globalStaffIndex,
            ));
          }
          globalStaffIndex++;
          partStaves.add(staff);
        }
        partsData.add(
          (id: part.getAttribute('id'), staves: partStaves, count: count),
        );
      }
      // Group consecutive parts that share a <part-group>.
      var i = 0;
      while (i < partsData.length) {
        final gid = partList.groupOf[partsData[i].id];
        if (gid == null) {
          groups.add(StaffGroup(
            staves: partsData[i].staves,
            bracket:
                partsData[i].count > 1 ? BracketType.brace : BracketType.none,
            // A multi-staff part (a piano) is one instrument: its <part-name>
            // labels the GROUP, drawn once beside the brace.
            name: partsData[i].count > 1
                ? partList.partName[partsData[i].id]
                : null,
            abbreviation: partsData[i].count > 1
                ? partList.partAbbreviation[partsData[i].id]
                : null,
          ));
          i++;
        } else {
          final staves = <Staff>[];
          while (i < partsData.length &&
              partList.groupOf[partsData[i].id] == gid) {
            staves.addAll(partsData[i].staves);
            i++;
          }
          groups.add(StaffGroup(
            staves: staves,
            bracket: partList.bracket[gid] ?? BracketType.bracket,
            name: partList.groupName[gid],
          ));
        }
      }
    } else {
      // Timewise: gather each part's measures across all <measure> wrappers.
      final partMeasures = <int, List<XmlElement>>{};
      var partCount = 0;
      for (final measure in root.findElements('measure')) {
        final parts = measure.findElements('part').toList();
        partCount = parts.length > partCount ? parts.length : partCount;
        for (var p = 0; p < parts.length; p++) {
          (partMeasures[p] ??= <XmlElement>[]).add(parts[p]);
        }
      }
      for (var p = 0; p < partCount; p++) {
        final partElements = partMeasures[p] ?? const <XmlElement>[];
        final staff = Staff(
          lineCount: _musicXmlStaffLines(partElements),
          transposition: _transpositionOf(
            partElements.isEmpty
                ? null
                : _musicXmlTranspose(partElements.first),
          ),
        );
        _divisions = 1;
        for (final m in partElements) {
          staff.add(_parseMeasure(m));
        }
        for (final element in partElements) {
          final transposition = _musicXmlTranspose(element);
          if (transposition != null) {
            transpositions.add(_musicXmlTranspositionMetadata(
              transposition,
              partId: element.getAttribute('id'),
              staffIndex: globalStaffIndex,
            ));
            break;
          }
        }
        globalStaffIndex++;
        groups.add(StaffGroup(staves: [staff]));
      }
    }

    if (groups.isEmpty) groups.add(StaffGroup(staves: [Staff()]));
    return Score(
      title: root.findAllElements('work-title').firstOrNull?.innerText,
      composer: root
          .findAllElements('creator')
          .where((e) => e.getAttribute('type') == 'composer')
          .firstOrNull
          ?.innerText,
      staffGroups: groups,
      // Transposing instruments: the notated pitch stays written, the
      // declaration travels as metadata so playback can reach concert pitch
      // through [applyMusicXmlTransposition].
      metadata: transpositions.isEmpty
          ? const <String, dynamic>{}
          : <String, dynamic>{'transpositions': transpositions},
    );
  }

  /// Maps each `<note>` element to its beam-group home staff and the resulting
  /// cross-staff move. A beam group's home staff is the staff of its first
  /// (beam=begin) note; notes that change `<staff>` within the group keep that
  /// home and get `move = ownStaff - homeStaff`.
  Map<XmlElement, ({int home, int move})> _crossStaffMap(
    XmlElement measureElement,
  ) {
    final map = <XmlElement, ({int home, int move})>{};
    final groupHome = <int, int>{}; // voice -> home staff while beam group open
    for (final note in measureElement.findElements('note')) {
      final staff = _asInt(_childText(note, 'staff')) ?? 1;
      final voice = _asInt(_childText(note, 'voice')) ?? 1;
      // Level 1 only: the primary beam is what decides the group's home staff.
      final beam = _musicXmlBeamText(note, 1);
      int home;
      if (beam == 'begin') {
        groupHome[voice] = staff;
        home = staff;
      } else if ((beam == 'continue' || beam == 'end') &&
          groupHome.containsKey(voice)) {
        home = groupHome[voice]!;
        if (beam == 'end') groupHome.remove(voice);
      } else {
        home = staff;
        groupHome.remove(voice);
      }
      map[note] = (home: home, move: staff - home);
    }
    return map;
  }

  /// Reads `<part-group>` spans from the `<part-list>`: maps each part id to the
  /// id of the innermost group it belongs to (or null), and each group id to its
  /// bracket type (from `<group-symbol>`).
  ({
    Map<String, int?> groupOf,
    Map<int, BracketType> bracket,
    Map<int, String> groupName,
    Map<String, String> partName,
    Map<String, String> partAbbreviation,
  }) _parsePartList(XmlElement root) {
    final groupOf = <String, int?>{};
    final bracket = <int, BracketType>{};
    final groupName = <int, String>{};
    final partName = <String, String>{};
    final partAbbreviation = <String, String>{};
    final partList = root.findElements('part-list').firstOrNull;
    if (partList == null) {
      return (
        groupOf: groupOf,
        bracket: bracket,
        groupName: groupName,
        partName: partName,
        partAbbreviation: partAbbreviation,
      );
    }

    final open = <({int number, int id})>[];
    var nextId = 0;
    for (final child in partList.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'part-group':
          final type = child.getAttribute('type');
          final number =
              int.tryParse(child.getAttribute('number') ?? '1') ?? 1;
          if (type == 'start') {
            final id = nextId++;
            bracket[id] = _groupSymbolBracket(
              child.findElements('group-symbol').firstOrNull?.innerText.trim(),
            );
            final label =
                child.findElements('group-name').firstOrNull?.innerText.trim();
            if (label != null && label.isNotEmpty) groupName[id] = label;
            open.add((number: number, id: id));
          } else if (type == 'stop') {
            for (var i = open.length - 1; i >= 0; i--) {
              if (open[i].number == number) {
                open.removeAt(i);
                break;
              }
            }
          }
          break;
        case 'score-part':
          final id = child.getAttribute('id');
          if (id != null) {
            groupOf[id] = open.isNotEmpty ? open.last.id : null;
            final label =
                child.findElements('part-name').firstOrNull?.innerText.trim();
            if (label != null && label.isNotEmpty) partName[id] = label;
            final abbr = child
                .findElements('part-abbreviation')
                .firstOrNull
                ?.innerText
                .trim();
            if (abbr != null && abbr.isNotEmpty) partAbbreviation[id] = abbr;
          }
          break;
      }
    }
    return (
      groupOf: groupOf,
      bracket: bracket,
      groupName: groupName,
      partName: partName,
      partAbbreviation: partAbbreviation,
    );
  }

  /// Converts a parsed `<transpose>` declaration into the model's
  /// [Transposition], or null when the part sounds at concert pitch.
  Transposition? _transpositionOf(MusicXmlTransposition? raw) {
    if (raw == null) return null;
    final value = Transposition(
      diatonic: raw.diatonic,
      chromatic: raw.chromatic,
      octaveChange: raw.octaveChange,
      doubled: raw.doubled,
    );
    return value.isConcertPitch ? null : value;
  }

  BracketType _groupSymbolBracket(String? symbol) {
    switch (symbol) {
      case 'brace':
        return BracketType.brace;
      case 'line':
        return BracketType.line;
      case 'bracket':
      case 'square':
        return BracketType.bracket;
      default:
        // A part-group with no explicit symbol still groups; default to bracket.
        return BracketType.bracket;
    }
  }

  /// Number of staves in a part (max `staves` or per-note `staff`; default 1).
  int _partStaffCount(XmlElement part) {
    var maxStaff = 1;
    for (final staves in part.findAllElements('staves')) {
      final n = _asInt(staves.innerText.trim());
      if (n != null && n > maxStaff) maxStaff = n;
    }
    for (final st in part.findAllElements('staff')) {
      final n = _asInt(st.innerText.trim());
      if (n != null && n > maxStaff) maxStaff = n;
    }
    return maxStaff;
  }

  Staff _parsePartwise(XmlElement root) {
    final parts = root.findElements('part').toList();
    if (parts.isEmpty) return Staff();
    if (partIndex < 0 || partIndex >= parts.length) {
      throw FormatException(
        'Requested partIndex $partIndex, but MusicXML contains ${parts.length} part(s).',
      );
    }

    final part = parts[partIndex];
    final partId = part.getAttribute('id');
    final partList = _parsePartList(root);
    final staff = Staff(
      lineCount: _musicXmlStaffLines([part]),
      name: partList.partName[partId],
      abbreviation: partList.partAbbreviation[partId],
      // `<transpose>` used to be unreachable through a bare Staff — the dartdoc
      // said so and pointed at `Score.metadata`, which nothing read either.
      // `Staff.transposition` closes both halves of that gap.
      transposition: _transpositionOf(_musicXmlTranspose(part)),
    );
    _divisions = 1;
    for (final measureElement in part.findElements('measure')) {
      staff.add(_parseMeasure(measureElement));
    }
    return staff;
  }

  Staff _parseTimewise(XmlElement root) {
    _divisions = 1;
    final selectedParts = <XmlElement>[];
    final measures = <Measure>[];
    for (final measureElement in root.findElements('measure')) {
      final parts = measureElement.findElements('part').toList();
      if (parts.isEmpty) continue;
      if (partIndex < 0 || partIndex >= parts.length) {
        throw FormatException(
          'Requested partIndex $partIndex, but a score-timewise measure contains ${parts.length} part(s).',
        );
      }
      selectedParts.add(parts[partIndex]);
      measures.add(_parseMeasure(parts[partIndex]));
    }
    return Staff(
      measures: measures,
      lineCount: _musicXmlStaffLines(selectedParts),
    );
  }

  /// Parses one MusicXML measure. When [staffFilter] is set (multi-staff part),
  /// only notes whose `staff` matches and clefs for that staff are kept.
  ///
  /// A musical time cursor (in `<divisions>` ticks from the barline) is kept
  /// while walking the children so `<backup>` and `<forward>` reposition the
  /// following notes instead of being ignored (F-07).
  Measure _parseMeasure(XmlElement measureElement, {int? staffFilter}) {
    final Map<int, _VoiceAccumulator> voices = <int, _VoiceAccumulator>{};
    final List<MusicalElement> metadataElements = <MusicalElement>[];
    TimeSignature? currentTimeSignature;

    // Musical time cursor, in <divisions> ticks from the start of the bar.
    double cursor = 0.0;
    // Per voice: the tick position where its content currently ends.
    final Map<int, double> voiceFilled = <int, double>{};
    // Files that never write <voice> get synthetic voice numbers: each
    // <backup> that rewinds the cursor opens the next voice. Multi-staff parts
    // are excluded because there <backup> switches staff, not voice.
    final bool hasExplicitVoice =
        measureElement.findAllElements('voice').isNotEmpty;
    final bool useSyntheticVoices = !hasExplicitVoice && staffFilter == null;
    int syntheticVoice = 1;
    // Padding is only emitted for gaps opened by an explicit <forward>.
    bool sawForward = false;
    // Cross-staff routing (multi-staff parts only): a beamed voice whose notes
    // change <staff> mid-beam is kept on its home (beam-start) staff with a
    // crossStaffMove so the beam survives.
    final crossStaff =
        staffFilter != null ? _crossStaffMap(measureElement) : null;

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
          final int? declaredDivisions = _asInt(_childText(child, 'divisions'));
          if (declaredDivisions != null && declaredDivisions > 0) {
            _divisions = declaredDivisions;
          }
          for (final element
              in _parseMusicXmlAttributes(child, staffFilter: staffFilter)) {
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
          final bool isChordTone = child.findElements('chord').isNotEmpty;
          final bool isGrace = child.findElements('grace').isNotEmpty;
          // Chord tones share the onset of their base note and grace notes are
          // stolen time; neither advances the cursor.
          final bool advancesTime = !isChordTone && !isGrace;
          final int tick =
              advancesTime ? (_asInt(_childText(child, 'duration')) ?? 0) : 0;

          bool keep = true;
          var move = 0;
          if (staffFilter != null) {
            final cs = crossStaff![child];
            final noteStaff = _asInt(_childText(child, 'staff')) ?? 1;
            final home = cs?.home ?? noteStaff;
            // Route the note to its home staff (cross-staff notes follow their
            // beam, not their own <staff>). Notes belonging to another staff
            // are dropped here but still move the shared cursor.
            keep = home == staffFilter;
            move = cs?.move ?? 0;
          }

          if (keep) {
            final int voiceNumber =
                _asInt(_childText(child, 'voice')) ?? syntheticVoice;
            if (advancesTime && sawForward) {
              _padVoiceToOnset(
                accumulator: voice(voiceNumber),
                voiceFilled: voiceFilled,
                voiceNumber: voiceNumber,
                onset: cursor,
              );
            }
            _parseMusicXmlNoteNode(
              child,
              voiceForNumber: voice,
              currentTimeSignature: currentTimeSignature,
              crossStaffMove: move,
              voiceNumber: voiceNumber,
              divisions: _divisions,
            );
            if (advancesTime) {
              voiceFilled[voiceNumber] = cursor + tick;
            }
          }
          cursor += tick;
          break;
        case 'backup':
          final int backupTicks = _asInt(_childText(child, 'duration')) ?? 0;
          if (backupTicks > 0) {
            cursor -= backupTicks;
            if (cursor < 0) cursor = 0;
            // Without <voice> the only signal that a second voice starts is the
            // rewind itself, so hand out the next synthetic voice number.
            if (useSyntheticVoices) syntheticVoice++;
          }
          break;
        case 'forward':
          final int forwardTicks = _asInt(_childText(child, 'duration')) ?? 0;
          if (forwardTicks > 0) {
            cursor += forwardTicks;
            sawForward = true;
          }
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

    final voiceNumbers = voices.keys.toList()..sort();
    for (final number in voiceNumbers) {
      final accumulator = voices[number]!;
      accumulator.finishTuplet();
      var elements = accumulator.elements;

      if (number == voiceNumbers.first) {
        // The bar's OPENING BLOCK is hoisted into the measure itself, and only
        // there.
        //
        // System elements used to be written to BOTH `metadataElements` (which
        // became `measure.elements`) and voice 1. That duplication existed to
        // compensate for `LayoutEngine._layoutMultiVoiceMeasure` ignoring
        // `measure.elements` entirely; now that it reads them, keeping both
        // copies draws the clef, key and meter TWICE (measured: clefs=2,
        // keys=2, times=2 on a two-voice import). The pair had to be undone
        // together.
        //
        // Only the LEADING run is hoisted. A clef/key/meter change that comes
        // after the first rhythmic event is an event in time and stays with the
        // voice that carries it — hoisting those is exactly the F-01 defect.
        var lead = 0;
        while (lead < elements.length && _isSystemElement(elements[lead])) {
          lead++;
        }
        for (var i = 0; i < lead; i++) {
          _appendElementToMeasure(measure, elements[i]);
        }
        elements = elements.sublist(lead);
      }

      measure.addVoice(Voice(number: number, elements: elements));
    }
    return measure;
  }

  /// Pads [accumulator] with invisible [Space] so its next element lands on
  /// [onset] (in `<divisions>` ticks) instead of directly after the previous
  /// one.
  ///
  /// Only called for gaps opened by an explicit `<forward>` (F-07): a
  /// `<backup>` that lands past a voice's content is an encoding artefact of
  /// multi-staff/multi-voice writing and must not shift the notes after it.
  void _padVoiceToOnset({
    required _VoiceAccumulator accumulator,
    required Map<int, double> voiceFilled,
    required int voiceNumber,
    required double onset,
  }) {
    if (_divisions <= 0) return;
    final double filled = voiceFilled[voiceNumber] ?? 0.0;
    final double gap = onset - filled;
    if (gap <= 0) return;

    for (final duration in _splitWholeNoteValue(gap / _divisions / 4.0)) {
      accumulator.append(Space(duration: duration));
    }
    voiceFilled[voiceNumber] = onset;
  }

  void _parseMusicXmlNoteNode(
    XmlElement noteElement, {
    required _VoiceAccumulator Function(int number) voiceForNumber,
    required TimeSignature? currentTimeSignature,
    int crossStaffMove = 0,
    int? voiceNumber,
    int divisions = 1,
  }) {
    final int resolvedVoice =
        voiceNumber ?? _asInt(_childText(noteElement, 'voice')) ?? 1;
    final accumulator = voiceForNumber(resolvedVoice);
    final bool isChordTone = noteElement.findElements('chord').isNotEmpty;
    final duration = _musicXmlDurationFromNote(
      noteElement,
      divisions: divisions,
      currentTimeSignature: currentTimeSignature,
    );
    final bool isGrace = noteElement.findElements('grace').isNotEmpty;

    // GAP: cue notes (`<cue/>`) are imported as ordinary notes.
    // TODO(import-gaps): a cue note is a full-duration note printed at cue
    // size. The model has no "cue"/"small" flag (adding one belongs to
    // lib/core/note.dart), and reusing [Note.isGraceNote] would be wrong:
    // grace notes are drawn without their own rhythmic slot, which would
    // corrupt the timing of a bar containing cues. So the note keeps its
    // duration and its normal size, and only the cue *appearance* is lost.
    // Wiring point when the field lands: `noteElement.findElements('cue')`.

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
        slurs: _musicXmlSlurEvents(noteElement),
        ornaments: _musicXmlOrnaments(noteElement),
        voice: resolvedVoice,
        isGraceNote: isGrace,
        syllables: _parseMusicXmlLyrics(noteElement),
        accidentalParenthesis: _musicXmlAccidentalParenthesis(noteElement),
        crossStaffMove: crossStaffMove,
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

List<MusicalElement> _parseMusicXmlAttributes(XmlElement attributesElement,
    {int? staffFilter}) {
  final List<MusicalElement> result = <MusicalElement>[];

  for (final child in attributesElement.children.whereType<XmlElement>()) {
    switch (child.name.local) {
      case 'clef':
        // <clef number="N"> is per-staff; keep only this staff's clef when
        // splitting a multi-staff part (no number = staff 1).
        if (staffFilter != null) {
          final clefStaff = _asInt(child.getAttribute('number')) ?? 1;
          if (clefStaff != staffFilter) break;
        }
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

/// A MusicXML `<attributes><transpose>` declaration for one part/staff.
typedef MusicXmlTransposition = ({
  /// `<diatonic>`: number of diatonic steps to add to the written pitch.
  int diatonic,

  /// `<chromatic>`: number of semitones to add to the written pitch.
  int chromatic,

  /// `<octave-change>`: extra octaves to add on top of [chromatic].
  int octaveChange,

  /// `<double/>`: the part also sounds an octave lower.
  bool doubled,
});

/// Reads the first `<attributes><transpose>` of [part] (optionally restricted
/// to the staff [staffNumber] via `@number`), or `null` when the part is not a
/// transposing one.
///
/// ## Why the written pitch is kept as-is
///
/// MusicXML stores the **written** (notated) pitch inside `<note><pitch>` and
/// uses `<transpose>` to say what must be *added* to it to obtain the sounding
/// pitch (MusicXML 4.0, `transpose`). A B-flat clarinet part therefore encodes
/// the notes as they appear on the page plus
/// `<diatonic>-1</diatonic><chromatic>-2</chromatic>`.
///
/// Since this library engraves what is on the page, the importer deliberately
/// keeps the written pitch untouched: transposing it here would move every
/// notehead and accidental of a transposing part to the wrong staff position.
/// The declaration itself is preserved as score metadata (see
/// [_musicXmlTranspositionMetadata]) so playback can apply
/// [applyMusicXmlTransposition] when it needs concert pitch.
MusicXmlTransposition? _musicXmlTranspose(XmlElement part, {int? staffNumber}) {
  for (final transpose in part.findAllElements('transpose')) {
    if (staffNumber != null) {
      final declared = _asInt(transpose.getAttribute('number')) ?? 1;
      if (declared != staffNumber) continue;
    }
    final chromatic = _asInt(_childText(transpose, 'chromatic'));
    final diatonic = _asInt(_childText(transpose, 'diatonic'));
    final octaveChange = _asInt(_childText(transpose, 'octave-change'));
    if (chromatic == null && diatonic == null && octaveChange == null) {
      continue;
    }
    return (
      diatonic: diatonic ?? 0,
      chromatic: chromatic ?? 0,
      octaveChange: octaveChange ?? 0,
      doubled: transpose.findElements('double').isNotEmpty,
    );
  }
  return null;
}

/// Serialises [transposition] into the plain map stored under the
/// `'transpositions'` key of [Score.metadata].
Map<String, dynamic> _musicXmlTranspositionMetadata(
  MusicXmlTransposition transposition, {
  String? partId,
  required int staffIndex,
}) {
  return <String, dynamic>{
    'partId': partId,
    'staffIndex': staffIndex,
    'diatonic': transposition.diatonic,
    'chromatic': transposition.chromatic,
    'octaveChange': transposition.octaveChange,
    'double': transposition.doubled,
  };
}

/// Semitone offset of each diatonic step above C, in [Pitch.validSteps] order.
const List<int> _diatonicStepSemitones = <int>[0, 2, 4, 5, 7, 9, 11];

/// Applies a MusicXML `<transpose>` declaration to a *written* pitch and
/// returns the **sounding** (concert) pitch.
///
/// This is the operation the importer intentionally does NOT perform (see
/// [_musicXmlTranspose]); it is exposed so that a playback layer reading
/// `Score.metadata['transpositions']` can convert on its own.
///
/// The diatonic shift picks the spelling (letter name + octave) and the
/// chromatic shift then fixes the alteration, so a written C4 on a B-flat
/// instrument (`diatonic: -1`, `chromatic: -2`) becomes B-flat 3 rather than
/// A-sharp 3.
Pitch applyMusicXmlTransposition(
  Pitch written, {
  int diatonic = 0,
  int chromatic = 0,
  int octaveChange = 0,
}) {
  final int stepIndex = Pitch.validSteps.indexOf(written.step.toUpperCase());
  if (stepIndex < 0) return written;

  final int shifted = stepIndex + diatonic;
  final int newStepIndex = ((shifted % 7) + 7) % 7;
  final int octaveCarry = (shifted - newStepIndex) ~/ 7;
  final int newOctave = written.octave + octaveCarry + octaveChange;

  final double writtenSemitone = _diatonicStepSemitones[stepIndex] +
      12 * (written.octave + 1) +
      written.alter;
  final double soundingSemitone =
      writtenSemitone + chromatic + 12 * octaveChange;
  final double naturalSemitone =
      (_diatonicStepSemitones[newStepIndex] + 12 * (newOctave + 1)).toDouble();

  return Pitch(
    step: Pitch.validSteps[newStepIndex],
    octave: newOctave,
    alter: soundingSemitone - naturalSemitone,
  );
}

/// Number of staff lines declared by `<attributes><staff-details><staff-lines>`
/// for [staffNumber] (or the first declaration when [staffNumber] is null).
///
/// Falls back to the CMN default of 5 when the part declares nothing, so a
/// 1-line percussion staff or a 6-line tablature staff now survives the import
/// instead of always being rebuilt as a 5-line staff.
int _musicXmlStaffLines(Iterable<XmlElement> parts, {int? staffNumber}) {
  for (final part in parts) {
    for (final details in part.findAllElements('staff-details')) {
      if (staffNumber != null) {
        final declared = _asInt(details.getAttribute('number')) ?? 1;
        if (declared != staffNumber) continue;
      }
      final lines = _asInt(_childText(details, 'staff-lines'));
      if (lines != null && lines > 0) return lines;
    }
  }
  return 5;
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
        case 'wedge':
          // Crescendo/diminuendo hairpin spanner; the start carries the type,
          // 'stop' just closes it (ignored here).
          final wtype = _normalizeToken(child.getAttribute('type'));
          if (wtype == 'crescendo') {
            result.add(Dynamic(type: DynamicType.crescendo, isHairpin: true));
          } else if (wtype == 'diminuendo' || wtype == 'decrescendo') {
            result.add(Dynamic(type: DynamicType.diminuendo, isHairpin: true));
          }
          break;
      }
    }
  }

  // <sound tempo="N"> is the playback-side tempo of a <direction>. It is a
  // sibling of <direction-type>, so it is read here, after the loop, and only
  // when the direction carried no <metronome>: when both are present the
  // <metronome> is the notated (graphical) mark and wins.
  //
  // MusicXML defines @tempo as quarter notes per minute, hence the fixed
  // quarter beat unit.
  if (!result.any((element) => element is TempoMark)) {
    final tempo = _musicXmlSoundTempo(directionElement);
    if (tempo != null) result.add(tempo);
  }

  return result;
}

/// [TempoMark] from a `<sound tempo="N">` child of [parent], or `null` when the
/// element has no usable `@tempo`.
TempoMark? _musicXmlSoundTempo(XmlElement parent) {
  for (final sound in parent.findElements('sound')) {
    final bpm = _asDouble(sound.getAttribute('tempo'));
    if (bpm != null && bpm > 0) {
      return TempoMark(
        beatUnit: DurationType.quarter,
        bpm: bpm.round(),
      );
    }
  }
  return null;
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

/// Parses MusicXML `<lyric number="N">` children of a note into one [Syllable]
/// per verse (ordered by `@number`). `<syllabic>` (single/begin/middle/end)
/// maps to the syllable connection type; the text comes from `<text>`.
List<Syllable>? _parseMusicXmlLyrics(XmlElement noteElement) {
  final lyrics = noteElement.findElements('lyric').toList();
  if (lyrics.isEmpty) return null;
  lyrics.sort((a, b) {
    final na = int.tryParse(a.getAttribute('number') ?? '') ?? 0;
    final nb = int.tryParse(b.getAttribute('number') ?? '') ?? 0;
    return na.compareTo(nb);
  });
  final result = <Syllable>[];
  for (final lyric in lyrics) {
    final text = _childText(lyric, 'text');
    if (text == null || text.trim().isEmpty) continue;
    result.add(
      Syllable(
        text: text.trim(),
        type: _musicXmlSyllabicType(_childText(lyric, 'syllabic')),
      ),
    );
  }
  return result.isEmpty ? null : result;
}

SyllableType _musicXmlSyllabicType(String? syllabic) {
  switch (syllabic) {
    case 'begin':
      return SyllableType.initial;
    case 'middle':
      return SyllableType.middle;
    case 'end':
      return SyllableType.terminal;
    default:
      return SyllableType.single;
  }
}

/// Reads MusicXML cautionary/editorial accidental display from the
/// `<accidental>` element's attributes. bracket/editorial -> brackets,
/// parentheses/cautionary -> parentheses.
AccidentalParenthesis _musicXmlAccidentalParenthesis(XmlElement noteElement) {
  final acc = noteElement.findElements('accidental').firstOrNull;
  if (acc == null) return AccidentalParenthesis.none;
  bool yes(String attr) => acc.getAttribute(attr)?.toLowerCase() == 'yes';
  if (yes('bracket') || yes('editorial')) return AccidentalParenthesis.brackets;
  if (yes('parentheses') || yes('cautionary')) {
    return AccidentalParenthesis.parentheses;
  }
  return AccidentalParenthesis.none;
}

/// Display pitch of a MusicXML `<unpitched>` note (percussion).
///
/// Percussion notation has no sounding pitch: `<unpitched>` only carries the
/// *graphical* line/space through `<display-step>` / `<display-octave>`, which
/// is exactly what the engraver needs to place the notehead. It is therefore
/// imported as a plain [Pitch] with no alteration.
///
/// Notes without `<display-step>`/`<display-octave>` default to B4 — the
/// middle line of a 5-line staff — the conventional fallback position.
///
/// Before this existed, `_musicXmlPitch` returned `null` for every unpitched
/// note and the caller dropped the note silently: a whole drum part imported
/// as an empty staff.
Pitch? _musicXmlUnpitchedDisplayPitch(XmlElement noteElement) {
  final unpitched = noteElement.findElements('unpitched').firstOrNull;
  if (unpitched == null) return null;

  final rawStep = _childText(unpitched, 'display-step')?.trim();
  final rawOctave = _asInt(_childText(unpitched, 'display-octave'));

  final step = rawStep == null || rawStep.isEmpty
      ? 'B'
      : _validatePitchStep(rawStep, 'MusicXML <unpitched><display-step>');
  final octave = rawOctave == null
      ? 4
      : _validatePitchOctave(rawOctave, 'MusicXML <unpitched><display-octave>');

  return Pitch(step: step, octave: octave);
}

/// Reads `<pitch>` verbatim.
///
/// No octave conversion happens here: `Pitch` IS the MusicXML `<pitch>`, i.e.
/// the pitch as it sounds through the clef (ADR-003). An octave-transposing
/// clef is honoured on the DRAWING side by `StaffPositionCalculator`, so the
/// importer has nothing to correct.
Pitch? _musicXmlPitch(XmlElement noteElement) {
  final pitchElement = noteElement.findElements('pitch').firstOrNull;
  if (pitchElement == null) {
    // Percussion / unpitched notation: no <pitch>, but <unpitched> carries the
    // staff position the note must be drawn on.
    return _musicXmlUnpitchedDisplayPitch(noteElement);
  }

  final rawStep = _childText(pitchElement, 'step');
  final octave = _asInt(_childText(pitchElement, 'octave'));

  // A <pitch> that exists but is incomplete is malformed input, not a note to
  // be skipped. Returning null here dropped the note WITHOUT A WORD — the one
  // malformed-input case that still failed silently after F-10.
  if (rawStep == null) {
    throw const FormatException(
      'MusicXML <pitch> is missing its <step> element',
    );
  }
  if (octave == null) {
    throw const FormatException(
      'MusicXML <pitch> is missing a readable <octave> element',
    );
  }

  final step = _validatePitchStep(rawStep, 'MusicXML <pitch><step>');
  _validatePitchOctave(octave, 'MusicXML <pitch><octave>');

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

/// Relative tolerance used when matching a measured duration (expressed in
/// whole notes) against a notated [DurationType] plus augmentation dots.
const double _durationMatchTolerance = 1e-3;

/// Value, in whole notes, of [type] carrying [dots] augmentation dots.
///
/// Mirrors `Duration.absoluteValue`: each dot adds half of the previous
/// increment (`base * (2 - 2^-dots)`).
double _dottedValue(DurationType type, int dots) {
  double total = type.value;
  double increment = type.value;
  for (int i = 0; i < dots; i++) {
    increment /= 2.0;
    total += increment;
  }
  return total;
}

/// Best [DurationType] + dot count (0..[maxDots]) whose dotted value equals
/// [wholeNoteValue] within [_durationMatchTolerance] (relative error).
///
/// Returns `null` when no combination is close enough, letting callers fall
/// back to the notated `<type>`/`@dur` or to a sensible default.
Duration? _durationFromWholeNoteValue(double wholeNoteValue,
    {int maxDots = 3}) {
  if (!wholeNoteValue.isFinite || wholeNoteValue <= 0) return null;

  Duration? best;
  double bestError = double.infinity;
  for (final type in DurationType.values) {
    for (int dots = 0; dots <= maxDots; dots++) {
      final double candidate = _dottedValue(type, dots);
      final double error = (candidate - wholeNoteValue).abs() / wholeNoteValue;
      if (error < bestError) {
        bestError = error;
        best = Duration(type, dots: dots);
      }
    }
  }
  return bestError <= _durationMatchTolerance ? best : null;
}

/// Splits [wholeNoteValue] into the fewest [Duration]s that add up to it.
///
/// Used to build the invisible `<space>` padding that a `<forward>` gap needs
/// (F-07). A value that maps onto a single (possibly dotted) note value yields
/// one entry; anything else is decomposed greedily from the largest value down.
List<Duration> _splitWholeNoteValue(double wholeNoteValue) {
  final exact = _durationFromWholeNoteValue(wholeNoteValue);
  if (exact != null) return <Duration>[exact];

  final List<Duration> parts = <Duration>[];
  double remaining = wholeNoteValue;
  // DurationType.values is ordered from the longest (maxima) to the shortest
  // value, so a plain descending pass terminates.
  for (final type in DurationType.values) {
    while (remaining >= type.value * (1.0 - _durationMatchTolerance)) {
      parts.add(Duration(type));
      remaining -= type.value;
    }
  }
  return parts;
}

/// The *notated* value of a MusicXML `<note>` in whole notes, derived from
/// `<duration>` and the part's current `<divisions>` (ticks per quarter note).
///
/// Any `<time-modification>` ratio is undone first, because `<duration>` holds
/// the sounding (tuplet-shortened) value while the graphical note value is the
/// unmodified one.
///
/// Returns `null` when the note carries no usable `<duration>` (grace notes) or
/// when [divisions] is not positive.
double? _musicXmlNotatedWholeNoteValue(XmlElement noteElement, int divisions) {
  if (divisions <= 0) return null;
  final int? raw = _asInt(_childText(noteElement, 'duration'));
  if (raw == null || raw <= 0) return null;

  double whole = raw / divisions / 4.0;
  final timeModification =
      noteElement.findElements('time-modification').firstOrNull;
  if (timeModification != null) {
    final int? actual = _asInt(_childText(timeModification, 'actual-notes'));
    final int? normal = _asInt(_childText(timeModification, 'normal-notes'));
    if (actual != null && normal != null && actual > 0 && normal > 0) {
      whole = whole * actual / normal;
    }
  }
  return whole;
}

/// Duration of a `<rest measure="yes"/>` that carries no `<type>`.
///
/// The length comes from the active [TimeSignature] (falling back to the
/// measured [measuredWhole] when the bar is unknown). A bar exactly one whole
/// note long keeps [DurationType.whole], the conventional measure-rest glyph.
Duration _musicXmlMeasureRestDuration(
  TimeSignature? timeSignature,
  double? measuredWhole,
) {
  final double? barValue =
      timeSignature != null && !timeSignature.isFreeTime
          ? timeSignature.measureValue
          : measuredWhole;
  if (barValue == null || !barValue.isFinite || barValue <= 0) {
    return const Duration(DurationType.whole);
  }
  if ((barValue - DurationType.whole.value).abs() <= _durationMatchTolerance) {
    return const Duration(DurationType.whole);
  }
  return _durationFromWholeNoteValue(barValue) ??
      const Duration(DurationType.whole);
}

/// Resolves the duration of a MusicXML `<note>`.
///
/// `<type>` stays authoritative for the graphical shape whenever it is present;
/// the measured value only fills in augmentation dots the source forgot to
/// encode. When `<type>` is absent the value is derived from
/// `<duration>` / `<divisions>` (F-06) — previously both elements were ignored,
/// so a `<divisions>4` + `<duration>16` whole note imported as a quarter.
///
/// [divisions] is the part's current `<divisions>` value and
/// [currentTimeSignature] the meter in force, used for whole-measure rests.
Duration _musicXmlDurationFromNote(
  XmlElement noteElement, {
  int divisions = 1,
  TimeSignature? currentTimeSignature,
}) {
  final double? notatedWhole =
      _musicXmlNotatedWholeNoteValue(noteElement, divisions);
  final DurationType? notatedType =
      _parseDurationType(_childText(noteElement, 'type'));
  final int writtenDots = noteElement.findElements('dot').length;

  if (notatedType != null) {
    // Validate the dots against the measured value, but only when the source
    // wrote none: an explicit <dot> is the engraver's intent and wins.
    if (writtenDots == 0 && notatedWhole != null) {
      for (int dots = 1; dots <= 3; dots++) {
        final double candidate = _dottedValue(notatedType, dots);
        if ((candidate - notatedWhole).abs() / notatedWhole <=
            _durationMatchTolerance) {
          return Duration(notatedType, dots: dots);
        }
      }
    }
    return Duration(notatedType, dots: writtenDots);
  }

  // A whole-measure rest without <type> takes the length of the bar.
  final rest = noteElement.findElements('rest').firstOrNull;
  if (rest != null && _normalizeToken(rest.getAttribute('measure')) == 'yes') {
    return _musicXmlMeasureRestDuration(currentTimeSignature, notatedWhole);
  }

  if (notatedWhole != null) {
    final derived = _durationFromWholeNoteValue(notatedWhole);
    if (derived != null) return derived;
  }

  return Duration(DurationType.quarter, dots: writtenDots);
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

/// All numbered `<slur>` boundaries on a note (MusicXML `<slur number=>`), so
/// concurrent/nested slurs can be matched by id. Empty when the note carries no
/// slur boundary.
List<SlurEvent> _musicXmlSlurEvents(XmlElement noteElement) {
  final events = <SlurEvent>[];
  for (final notations in noteElement.findElements('notations')) {
    for (final slurElement in notations.findElements('slur')) {
      final type = _parseSlurType(slurElement.getAttribute('type'));
      if (type == null) continue;
      final number =
          int.tryParse(slurElement.getAttribute('number') ?? '1') ?? 1;
      events.add(SlurEvent(number: number, type: type));
    }
  }
  return events;
}

/// Text of the `<beam number="N">` child of a note for beam [level], lowercased
/// and trimmed, or `null` when the note carries no beam at that level.
///
/// MusicXML numbers beams by level (1 = primary, 2+ = secondary/partial).
/// Reading simply the first `<beam>` in document order picked up whatever level
/// happened to be written first, so a file that lists level 2 before level 1
/// lost its primary beam (F-18). A `<beam>` without `@number` defaults to
/// level 1.
String? _musicXmlBeamText(XmlElement noteElement, int level) {
  XmlElement? unnumbered;
  for (final beam in noteElement.findElements('beam')) {
    final int? number = _asInt(beam.getAttribute('number'));
    if (number == level) return beam.innerText.trim().toLowerCase();
    if (number == null) unnumbered ??= beam;
  }
  return level == 1 ? unnumbered?.innerText.trim().toLowerCase() : null;
}

/// Primary (level 1) beam of a MusicXML `<note>`.
///
/// `forward hook` / `backward hook` are mapped to the nearest existing
/// [BeamType] (`inner`), since a hook only ever occurs inside an open group.
///
/// TODO(F-18): beam levels 2..4 (`<beam number="2">` and up) are still dropped
/// because the `Note` model exposes a single `BeamType? beam`. Rendering
/// secondary and partial beams requires a per-level field on `Note`, which
/// lives in `lib/core`; until then only the primary level is imported.
BeamType? _musicXmlBeamType(XmlElement noteElement) {
  final String? text = _musicXmlBeamText(noteElement, 1);
  if (text == null) return null;
  if (text == 'forward hook' || text == 'backward hook') {
    return BeamType.inner;
  }
  return _parseBeamType(text);
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

  // Measure-scoped control events resolved by @startid/@endid -> note xml:id.
  final Map<String, SlurType> _slurById = <String, SlurType>{};
  final Map<String, TieType> _tieById = <String, TieType>{};
  final Map<String, List<MusicalElement>> _afterNoteById =
      <String, List<MusicalElement>>{};

  static String? _stripHash(String? id) =>
      id == null ? null : (id.startsWith('#') ? id.substring(1) : id);

  /// Scans a measure's control events (slur/tie/dynam) and indexes them by
  /// the referenced note xml:id via @startid/@endid.
  ///
  /// The indexes are measure-scoped: they are cleared on entry so events never
  /// leak into the following measure (F-42).
  void _collectMeiControlEvents(XmlElement measureElement) {
    _slurById.clear();
    _tieById.clear();
    _afterNoteById.clear();

    for (final ev in measureElement.children.whereType<XmlElement>()) {
      final startId = _stripHash(ev.getAttribute('startid'));
      final endId = _stripHash(ev.getAttribute('endid'));
      switch (ev.name.local) {
        case 'slur':
          if (startId != null) _slurById[startId] = SlurType.start;
          if (endId != null) _slurById[endId] = SlurType.end;
          break;
        case 'tie':
          if (startId != null) _tieById[startId] = TieType.start;
          if (endId != null) _tieById[endId] = TieType.end;
          break;
        case 'dynam':
          if (startId != null) {
            final d = _parseDynamicType(ev.innerText.trim());
            if (d != null) {
              (_afterNoteById[startId] ??= <MusicalElement>[])
                  .add(Dynamic(type: d));
            }
          }
          break;
      }
    }
  }

  Staff parse(XmlDocument document) {
    final root = document.rootElement;
    if (root.name.local != 'mei') {
      throw const FormatException('MEI root element must be <mei>.');
    }

    final score = root.findAllElements('score').firstOrNull;
    if (score == null) return Staff();

    final sections = _topLevelSections(score);
    if (sections.isEmpty) return Staff();

    // MEI encodes the initial clef/key/meter in <scoreDef>/<staffDef>, not
    // inline in <staff>. Capture them and seed the first measure.
    final scoreDef = score.findAllElements('scoreDef').firstOrNull;
    final defaults =
        scoreDef == null ? const <MusicalElement>[] : _meiStaffDefaults(scoreDef);

    // <staffDef @lines> sizes the staff (1 = percussion, 6 = guitar tab);
    // Staff.lineCount is final, so it must be resolved up front.
    final staff = Staff(
      lineCount: scoreDef == null ? 5 : _meiStaffDefLines(scoreDef),
    );
    var first = true;
    // <ending> wraps the measures of a volta; a bracket is emitted on the first
    // measure of each ending. <expansion> is an empty, plist-based element and
    // simply carries no measures of its own.
    XmlElement? openEnding;
    for (final section in sections) {
      // findAllElements keeps document order and also reaches measures wrapped
      // in <ending>/<expansion> containers.
      for (final measure in section.findAllElements('measure')) {
        final ending = _meiEndingAncestor(measure, section);
        final lead = <MusicalElement>[
          if (first) ...defaults,
          if (ending != null && !identical(ending, openEnding))
            VoltaBracket(
              number: _asInt(ending.getAttribute('n')) ??
                  _asInt(ending.getAttribute('label')) ??
                  1,
              label: ending.getAttribute('label'),
              length: 0.0,
            ),
        ];
        openEnding = ending;
        staff.add(_parseMeasure(measure, leadingDefaults: lead));
        first = false;
      }
    }
    return staff;
  }

  /// Nearest `<ending>` ancestor of [measure] below [section], or `null` when
  /// the measure is not inside a volta.
  static XmlElement? _meiEndingAncestor(
    XmlElement measure,
    XmlElement section,
  ) {
    for (XmlNode? ancestor = measure.parent;
        ancestor != null && !identical(ancestor, section);
        ancestor = ancestor.parent) {
      if (ancestor is XmlElement && ancestor.name.local == 'ending') {
        return ancestor;
      }
    }
    return null;
  }

  /// `<staffDef @lines>` for this staffIndex (falling back to the first
  /// staffDef, then to the CMN default of 5).
  int _meiStaffDefLines(XmlElement scoreDef) {
    final defs = scoreDef.findAllElements('staffDef').toList();
    if (defs.isEmpty) return 5;
    XmlElement? sd;
    for (final d in defs) {
      if ((_asInt(d.getAttribute('n')) ?? 1) == staffIndex + 1) {
        sd = d;
        break;
      }
    }
    sd ??= defs[staffIndex.clamp(0, defs.length - 1)];
    final lines = _asInt(sd.getAttribute('lines'));
    return lines != null && lines > 0 ? lines : 5;
  }

  /// Every `<section>` of a `<score>`, in document order, excluding sections
  /// nested inside another section.
  ///
  /// Only the first `<section>` used to be read, so a score split into several
  /// sections lost every measure after the first one (F-17). Nested sections
  /// are skipped here because their measures are already reached through their
  /// enclosing top-level section.
  static List<XmlElement> _topLevelSections(XmlElement score) {
    final List<XmlElement> result = <XmlElement>[];
    for (final section in score.findAllElements('section')) {
      var nested = false;
      for (XmlNode? ancestor = section.parent;
          ancestor != null && !identical(ancestor, score);
          ancestor = ancestor.parent) {
        if (ancestor is XmlElement && ancestor.name.local == 'section') {
          nested = true;
          break;
        }
      }
      if (!nested) result.add(section);
    }
    return result;
  }

  /// Clef/key/meter declared in a `scoreDef`'s `staffDef` for this staffIndex
  /// (or the scoreDef itself), reading both attribute and child-element forms.
  List<MusicalElement> _meiStaffDefaults(XmlElement scoreDef) {
    final defs = scoreDef.findAllElements('staffDef').toList();
    XmlElement? sd;
    for (final d in defs) {
      if ((_asInt(d.getAttribute('n')) ?? 1) == staffIndex + 1) {
        sd = d;
        break;
      }
    }
    sd ??= defs.isNotEmpty
        ? defs[staffIndex.clamp(0, defs.length - 1)]
        : null;
    final result = <MusicalElement>[];
    final clef = (sd != null ? _meiDefClef(sd) : null) ?? _meiDefClef(scoreDef);
    if (clef != null) result.add(clef);
    final key = (sd != null ? _meiDefKey(sd) : null) ?? _meiDefKey(scoreDef);
    if (key != null) result.add(key);
    final meter =
        (sd != null ? _meiDefMeter(sd) : null) ?? _meiDefMeter(scoreDef);
    if (meter != null) result.add(meter);
    return result;
  }

  Measure _parseMeasure(
    XmlElement measureElement, {
    List<MusicalElement> leadingDefaults = const <MusicalElement>[],
  }) {
    final Map<int, _VoiceAccumulator> voices = <int, _VoiceAccumulator>{};
    final List<MusicalElement> metadataElements = <MusicalElement>[];
    TimeSignature? currentTimeSignature;

    // Resolve measure-level control events (slur/tie/dynam) that reference notes
    // by @startid/@endid, so they apply even though they sit outside <staff>.
    // The collector clears the previous measure's index first.
    _collectMeiControlEvents(measureElement);

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

    // Seed the first measure with the scoreDef/staffDef clef/key/meter, unless
    // the staff redeclares that element type inline.
    if (leadingDefaults.isNotEmpty) {
      final inlineNames =
          staffElement.children.whereType<XmlElement>().map((e) => e.name.local);
      final hasClef = inlineNames.contains('clef');
      final hasKey = inlineNames.contains('keySig');
      final hasMeter = inlineNames.contains('meterSig') ||
          inlineNames.contains('meterSigGrp');
      for (final d in leadingDefaults) {
        if (d is Clef && hasClef) continue;
        if (d is KeySignature && hasKey) continue;
        if (d is TimeSignature && hasMeter) continue;
        appendLead(d);
      }
    }

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
        case 'meterSigGrp':
          // Additive meter written as a group of <meterSig>s, e.g. (3+2+2)/8.
          final meter = _meiMeterSigGrp(child);
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

    final voiceNumbers = voices.keys.toList()..sort();
    for (final number in voiceNumbers) {
      final accumulator = voices[number]!;
      accumulator.finishTuplet();
      var elements = accumulator.elements;

      if (number == voiceNumbers.first) {
        // The bar's OPENING BLOCK is hoisted into the measure itself, and only
        // there.
        //
        // System elements used to be written to BOTH `metadataElements` (which
        // became `measure.elements`) and voice 1. That duplication existed to
        // compensate for `LayoutEngine._layoutMultiVoiceMeasure` ignoring
        // `measure.elements` entirely; now that it reads them, keeping both
        // copies draws the clef, key and meter TWICE (measured: clefs=2,
        // keys=2, times=2 on a two-voice import). The pair had to be undone
        // together.
        //
        // Only the LEADING run is hoisted. A clef/key/meter change that comes
        // after the first rhythmic event is an event in time and stays with the
        // voice that carries it — hoisting those is exactly the F-01 defect.
        var lead = 0;
        while (lead < elements.length && _isSystemElement(elements[lead])) {
          lead++;
        }
        for (var i = 0; i < lead; i++) {
          _appendElementToMeasure(measure, elements[i]);
        }
        elements = elements.sublist(lead);
      }

      measure.addVoice(Voice(number: number, elements: elements));
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
      _appendMeiChild(child, accumulator, voiceNumber, currentTimeSignature);
    }
  }

  /// Appends one MEI layer child. `<beam>`/`<tuplet>` are CONTAINERS (the common
  /// MEI 5 encoding) and are recursed into, so their child notes are not lost.
  void _appendMeiChild(
    XmlElement child,
    _VoiceAccumulator accumulator,
    int voiceNumber,
    TimeSignature? currentTimeSignature, {
    BeamType? beamOverride,
  }) {
      switch (child.name.local) {
        case 'beam':
          // Position-based beam types over the beamable (note/chord) children.
          final kids = child.children.whereType<XmlElement>().toList();
          final beamable = kids
              .where((e) => e.name.local == 'note' || e.name.local == 'chord')
              .length;
          var bi = 0;
          for (final inner in kids) {
            final isBeamable =
                inner.name.local == 'note' || inner.name.local == 'chord';
            BeamType? bo;
            if (isBeamable && beamable > 1) {
              bo = bi == 0
                  ? BeamType.start
                  : (bi == beamable - 1 ? BeamType.end : BeamType.inner);
              bi++;
            }
            _appendMeiChild(inner, accumulator, voiceNumber,
                currentTimeSignature,
                beamOverride: bo);
          }
          return;
        case 'tuplet':
          accumulator.startTuplet(
            actualNotes: _asInt(child.getAttribute('num')) ?? 3,
            normalNotes: _asInt(child.getAttribute('numbase')) ?? 2,
            timeSignature: currentTimeSignature,
          );
          for (final inner in child.children.whereType<XmlElement>()) {
            _appendMeiChild(
                inner, accumulator, voiceNumber, currentTimeSignature);
          }
          accumulator.finishTuplet();
          return;
        case 'note':
          final noteId = child.getAttribute('xml:id');
          final note = _meiNote(child,
              voiceNumber: voiceNumber,
              beamOverride: beamOverride,
              slurOverride: noteId == null ? null : _slurById[noteId],
              tieOverride: noteId == null ? null : _tieById[noteId]);
          if (note == null) return;
          final tupletInfo = _meiTupletInfo(child);
          if (tupletInfo.startsTuplet) {
            accumulator.startTuplet(
              actualNotes: tupletInfo.actualNotes,
              normalNotes: tupletInfo.normalNotes,
              timeSignature: currentTimeSignature,
            );
          }
          accumulator.append(note);
          // Control events (e.g. <dynam startid>) anchored to this note.
          if (noteId != null) {
            for (final extra in _afterNoteById[noteId] ?? const []) {
              accumulator.append(extra);
            }
          }
          if (tupletInfo.endsTuplet) {
            accumulator.finishTuplet();
          }
          return;
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
          if (chord == null) return;
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
          if (text.isEmpty) return;
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

/// Clef from a `scoreDef`/`staffDef` (child `clef` or clef.shape/clef.line).
Clef? _meiDefClef(XmlElement def) {
  final child = def.findElements('clef').firstOrNull;
  if (child != null) {
    final c = _meiClef(child);
    if (c != null) return c;
  }
  final shape = def.getAttribute('clef.shape');
  if (shape == null) return null;
  final line = _asInt(def.getAttribute('clef.line'));
  final s = _normalizeToken(shape);
  if (s == 'g') return Clef(clefType: ClefType.treble);
  if (s == 'f') {
    return Clef(
        clefType: line == 3 ? ClefType.bassThirdLine : ClefType.bass);
  }
  if (s == 'c') {
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
  if (s == 'perc') return Clef(clefType: ClefType.percussion);
  // MEI `clef.shape="TAB"` (and the older "TAB.lute" family). The staff's own
  // `lines` attribute decides between the 6- and 4-string forms; a `<staffDef>`
  // that declares TAB without lines is a guitar tablature by convention.
  // This used to fall through and return null, so a tablature staff imported
  // with NO CLEF AT ALL — and a staff with no clef in force places every note
  // on the baseline.
  if (s == 'tab' || s.startsWith('tab')) {
    final lines = _asInt(def.getAttribute('lines'));
    return Clef(clefType: lines == 4 ? ClefType.tab4 : ClefType.tab6);
  }
  return null;
}

/// Key signature from a `scoreDef`/`staffDef` (child `keySig` or key.sig).
KeySignature? _meiDefKey(XmlElement def) {
  final child = def.findElements('keySig').firstOrNull;
  if (child != null) {
    final k = _meiKeySignature(child);
    if (k != null) return k;
  }
  // MEI v5 renamed `@key.sig` to `@keysig`; both spellings are accepted.
  final sig = def.getAttribute('key.sig') ?? def.getAttribute('keysig');
  // `@key.mode` (MEI v5) / `@mode` — the tonal mode of the key signature.
  final mode = _parseKeyMode(
    def.getAttribute('key.mode') ?? def.getAttribute('mode'),
  );
  if (sig == null || sig.trim().isEmpty) return null;
  final n = sig.trim().toLowerCase();
  if (n == '0') return KeySignature(0, mode: mode);
  final m = RegExp(r'^(-?\d+)([sf])$').firstMatch(n);
  if (m == null) return null;
  final count = int.tryParse(m.group(1)!);
  if (count == null) return null;
  return KeySignature(m.group(2) == 'f' ? -count : count, mode: mode);
}

/// Meter from a `scoreDef`/`staffDef` (child `meterSigGrp`/`meterSig`, or the
/// meter.count/meter.unit attribute pair — both may be additive).
TimeSignature? _meiDefMeter(XmlElement def) {
  final grp = def.findElements('meterSigGrp').firstOrNull;
  if (grp != null) {
    final additive = _meiMeterSigGrp(grp);
    if (additive != null) return additive;
  }
  final child = def.findElements('meterSig').firstOrNull;
  if (child != null) {
    final m = _meiTimeSignature(child);
    if (m != null) return m;
  }
  return _meiTimeSignature(def); // reads meter.count/meter.unit attributes
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

/// Parses a MEI `@mode` value (`major`, `minor`, `dorian`, …) into a [KeyMode].
///
/// MEI v5 carries the mode on `<keySig @mode>` and on `<staffDef>`/`<scoreDef>`
/// as `@key.mode`. Unknown or absent values yield `null`, which [KeySignature]
/// treats as [KeyMode.none].
KeyMode? _parseKeyMode(String? raw) {
  return _parseEnumByName(
    KeyMode.values,
    raw,
    aliases: const <String, KeyMode>{
      'maj': KeyMode.major,
      'min': KeyMode.minor,
      'dor': KeyMode.dorian,
      'phr': KeyMode.phrygian,
      'lyd': KeyMode.lydian,
      'mix': KeyMode.mixolydian,
      'mixolyd': KeyMode.mixolydian,
      'aeo': KeyMode.aeolian,
      'loc': KeyMode.locrian,
    },
  );
}

KeySignature? _meiKeySignature(XmlElement keySigElement) {
  final sig = keySigElement.getAttribute('sig');
  if (sig == null || sig.trim().isEmpty) return null;
  // MEI v5 `<keySig @mode>`; `@key.mode` is accepted too for encodings that
  // copy the staffDef attribute name onto the element.
  final mode = _parseKeyMode(
    keySigElement.getAttribute('mode') ??
        keySigElement.getAttribute('key.mode'),
  );
  final normalized = sig.trim().toLowerCase();
  if (normalized == '0') {
    return KeySignature(0, mode: mode);
  }

  final match = RegExp(r'^(-?\d+)([sf])$').firstMatch(normalized);
  if (match == null) return null;
  final count = int.tryParse(match.group(1)!);
  final suffix = match.group(2);
  if (count == null) return null;
  return KeySignature(suffix == 'f' ? -count : count, mode: mode);
}

/// Parses a MEI `@meter.count` / `@count` value, which may be a plain integer
/// (`"4"`) or an additive expression (`"3+2+2"`).
///
/// Returns the individual groups; a plain integer yields a single-entry list.
/// Returns `null` when the value is not a usable meter count.
List<int>? _meiMeterCounts(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('+');
  final counts = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part.trim());
    if (value == null || value <= 0) return null;
    counts.add(value);
  }
  return counts.isEmpty ? null : counts;
}

/// Builds a [TimeSignature] from [counts] + [denominator], choosing the
/// additive form when the source declared more than one group.
TimeSignature _meiMeterFromCounts(List<int> counts, int denominator) {
  if (counts.length > 1) {
    return TimeSignature.additive(groups: counts, denominator: denominator);
  }
  return TimeSignature(numerator: counts.first, denominator: denominator);
}

/// Meter from a `<meterSigGrp>` (MEI v5), i.e. several `<meterSig>` children
/// that together describe one additive meter such as (3+2+2)/8.
///
/// The denominator comes from the first child that declares a `@unit`; groups
/// whose own `@count` is additive are flattened into the result.
TimeSignature? _meiMeterSigGrp(XmlElement grpElement) {
  final counts = <int>[];
  int? denominator;
  for (final child in grpElement.findElements('meterSig')) {
    final childCounts = _meiMeterCounts(
      child.getAttribute('count') ?? child.getAttribute('meter.count'),
    );
    if (childCounts == null) continue;
    counts.addAll(childCounts);
    denominator ??= _asInt(
      child.getAttribute('unit') ?? child.getAttribute('meter.unit'),
    );
  }
  if (counts.isEmpty || denominator == null) return null;
  return _meiMeterFromCounts(counts, denominator);
}

TimeSignature? _meiTimeSignature(XmlElement meterSigElement) {
  // `meter.count` may be additive ("3+2+2"); a plain int is the single-group
  // case of the very same syntax.
  final counts = _meiMeterCounts(
    meterSigElement.getAttribute('count') ??
        meterSigElement.getAttribute('meter.count'),
  );
  final denominator = _asInt(
    meterSigElement.getAttribute('unit') ??
        meterSigElement.getAttribute('meter.unit'),
  );
  if (counts == null || denominator == null) return null;
  return _meiMeterFromCounts(counts, denominator);
}

Note? _meiNote(XmlElement noteElement,
    {required int voiceNumber,
    BeamType? beamOverride,
    SlurType? slurOverride,
    TieType? tieOverride}) {
  final rawStep = noteElement.getAttribute('pname');
  final octave = _asInt(noteElement.getAttribute('oct'));
  // GAP: a pure tablature note (`<note tab.fret= tab.string=/>` with neither
  // @pname nor @oct) is still dropped, because Note.pitch is required and
  // non-nullable and deriving a pitch would mean inventing a tuning. Tab notes
  // that do carry @pname/@oct — the usual MEI encoding — import fully below.
  if (rawStep == null || octave == null) return null;
  final step = _validatePitchStep(rawStep, 'MEI <note @pname>');
  _validatePitchOctave(octave, 'MEI <note @oct>');

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
    beam: beamOverride ?? _parseBeamType(noteElement.getAttribute('beam')),
    articulations: _parseArticulationList(
      noteElement.getAttribute('artic')?.split(RegExp(r'\s+')),
    ),
    tie: tieOverride ?? _parseTieType(noteElement.getAttribute('tie')),
    slur: slurOverride ?? _parseSlurType(noteElement.getAttribute('slur')),
    ornaments: _parseOrnamentList(noteElement.getAttribute('ornam')),
    voice: voiceNumber,
    isGraceNote: noteElement.getAttribute('grace') != null,
    syllables: _parseMeiVerses(noteElement),
    // MEI v5 tablature attributes; null when the note is not a tab note.
    tabFret: _asInt(noteElement.getAttribute('tab.fret')),
    tabString: _asInt(noteElement.getAttribute('tab.string')),
  );
}

/// Parses MEI `<verse n="N"><syl>…</syl></verse>` lyrics attached to a note into
/// one [Syllable] per verse (ordered by `@n`). Word position comes from
/// `@wordpos` (i/m/t) or the connector `@con` (i/m/t/d), else `single`.
List<Syllable>? _parseMeiVerses(XmlElement noteElement) {
  final verses = noteElement.findElements('verse').toList();
  if (verses.isEmpty) return null;
  verses.sort(
    (a, b) => (_asInt(a.getAttribute('n')) ?? 0).compareTo(
      _asInt(b.getAttribute('n')) ?? 0,
    ),
  );
  final result = <Syllable>[];
  for (final verse in verses) {
    final syls = verse.findElements('syl');
    if (syls.isEmpty) continue;
    final syl = syls.first;
    final text = syl.innerText.trim();
    if (text.isEmpty) continue;
    final pos = syl.getAttribute('wordpos') ?? syl.getAttribute('con');
    result.add(Syllable(text: text, type: _meiSyllableType(pos)));
  }
  return result.isEmpty ? null : result;
}

SyllableType _meiSyllableType(String? pos) {
  switch (pos) {
    case 'i':
      return SyllableType.initial;
    case 'm':
      return SyllableType.middle;
    case 't':
      return SyllableType.terminal;
    case 'd':
      return SyllableType.hyphen;
    default:
      return SyllableType.single;
  }
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
          // Chord tones keep their own tablature position.
          tabFret: note.tabFret,
          tabString: note.tabString,
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

/// Number of staves an MEI `<score>` can be split into without asking
/// [_MeiImportParser] for a staff a measure does not have.
///
/// Uses the smallest `<staff>` count found across the measures (a measure with
/// fewer staves would make the per-staff parser throw); falls back to the
/// number of `<staffDef>`s when the score has no measures at all.
int _meiStaffCount(XmlElement score) {
  int? minimum;
  for (final measure in score.findAllElements('measure')) {
    final count = measure.findElements('staff').length;
    if (minimum == null || count < minimum) minimum = count;
  }
  if (minimum != null && minimum > 0) return minimum;
  final defs = score.findAllElements('staffDef').length;
  return defs > 0 ? defs : 1;
}

/// Bracket implied by the outermost `<staffGrp @symbol>` of an MEI score.
BracketType _meiStaffGrpBracket(XmlElement score) {
  final group = score.findAllElements('staffGrp').firstOrNull;
  switch (_normalizeToken(group?.getAttribute('symbol'))) {
    case 'brace':
      return BracketType.brace;
    case 'bracket':
    case 'bracketsq':
      return BracketType.bracket;
    case 'line':
      return BracketType.line;
    default:
      return BracketType.none;
  }
}

/// Trimmed text of the first [childName] descendant of [element], or `null`
/// when it is missing or blank.
String? _meiText(XmlElement? element, String childName) {
  if (element == null) return null;
  final text = element.findAllElements(childName).firstOrNull?.innerText.trim();
  return text == null || text.isEmpty ? null : text;
}

/// Maps an MEI responsibility name (`composer`, `@role="editor"`, …) to a
/// [ResponsibilityRole]; anything unrecognised becomes
/// [ResponsibilityRole.other].
ResponsibilityRole _meiResponsibilityRole(String? raw) {
  return _parseEnumByName(
        ResponsibilityRole.values,
        raw,
        aliases: const <String, ResponsibilityRole>{
          'author': ResponsibilityRole.other,
          'lyricist': ResponsibilityRole.lyricist,
          'lyrics': ResponsibilityRole.lyricist,
          'sponsor': ResponsibilityRole.funder,
        },
      ) ??
      ResponsibilityRole.other;
}

/// Contributors named inside an MEI `<titleStmt>`.
///
/// Reads both encodings MEI allows: dedicated elements (`<composer>`,
/// `<arranger>`, `<editor>`, `<lyricist>`, `<librettist>`, `<funder>`) and the
/// generic `<respStmt>` with `<persName role="…">` / `<corpName role="…">`.
List<Contributor> _parseMeiContributors(XmlElement titleStmt) {
  final result = <Contributor>[];

  void addNamed(String elementName, ResponsibilityRole role) {
    for (final element in titleStmt.findAllElements(elementName)) {
      final name = element.innerText.trim();
      if (name.isEmpty) continue;
      result.add(Contributor(
        name: name,
        role: role,
        identifier: element.getAttribute('auth.uri') ??
            element.getAttribute('codedval'),
      ));
    }
  }

  addNamed('composer', ResponsibilityRole.composer);
  addNamed('arranger', ResponsibilityRole.arranger);
  addNamed('editor', ResponsibilityRole.editor);
  addNamed('lyricist', ResponsibilityRole.lyricist);
  addNamed('librettist', ResponsibilityRole.librettist);
  addNamed('funder', ResponsibilityRole.funder);

  for (final respStmt in titleStmt.findAllElements('respStmt')) {
    for (final person in respStmt.children.whereType<XmlElement>()) {
      final local = person.name.local;
      if (local != 'persName' && local != 'corpName') continue;
      final name = person.innerText.trim();
      if (name.isEmpty) continue;
      final role = _meiResponsibilityRole(
        person.getAttribute('role') ??
            _meiText(respStmt, 'resp') ??
            person.getAttribute('type'),
      );
      // Skip duplicates already picked up from a dedicated element.
      if (result.any((c) => c.name == name && c.role == role)) continue;
      result.add(Contributor(
        name: name,
        role: role,
        identifier: person.getAttribute('auth.uri') ??
            person.getAttribute('nymref'),
      ));
    }
  }

  return result;
}

/// Builds a [MeiHeader] from the `<meiHead>` of an MEI document, or returns
/// `null` when the document carries no header.
///
/// Covers the essential of `<fileDesc>`/`<titleStmt>` (title, subtitle,
/// contributors), plus `<pubStmt>`, `<sourceDesc>`, `<encodingDesc>`,
/// `<workList>` and `<revisionDesc>` when present.
MeiHeader? _parseMeiHeader(XmlElement mei) {
  final head = mei.findAllElements('meiHead').firstOrNull;
  if (head == null) return null;

  final fileDesc = head.findAllElements('fileDesc').firstOrNull;
  final titleStmt = fileDesc?.findAllElements('titleStmt').firstOrNull;

  String? title;
  String? subtitle;
  if (titleStmt != null) {
    for (final element in titleStmt.findAllElements('title')) {
      final text = element.innerText.trim();
      if (text.isEmpty) continue;
      final type = _normalizeToken(element.getAttribute('type'));
      if (type == 'subtitle' || type == 'sub') {
        subtitle ??= text;
      } else {
        title ??= text;
      }
    }
  }
  title ??= _meiText(head, 'title');

  final contributors = titleStmt == null
      ? const <Contributor>[]
      : _parseMeiContributors(titleStmt);

  final pubStmt = fileDesc?.findAllElements('pubStmt').firstOrNull;
  PublicationStatement? publication;
  if (pubStmt != null) {
    final publisher = _meiText(pubStmt, 'publisher');
    final date = _meiText(pubStmt, 'date') ??
        pubStmt.findAllElements('date').firstOrNull?.getAttribute('isodate');
    final place = _meiText(pubStmt, 'pubPlace');
    final availability = _meiText(pubStmt, 'availability');
    if (publisher != null ||
        date != null ||
        place != null ||
        availability != null) {
      publication = PublicationStatement(
        publisher: publisher,
        date: date,
        place: place,
        availability: availability,
      );
    }
  }

  final sources = <SourceDescription>[];
  final sourceDesc = fileDesc?.findAllElements('sourceDesc').firstOrNull;
  if (sourceDesc != null) {
    for (final source in sourceDesc.findAllElements('source')) {
      sources.add(SourceDescription(
        title: _meiText(source, 'title'),
        composer: _meiText(source, 'composer'),
        date: _meiText(source, 'date'),
        publisher: _meiText(source, 'publisher'),
        identifier: _meiText(source, 'identifier') ??
            source.getAttribute('xml:id'),
      ));
    }
  }

  final encodingDesc = head.findAllElements('encodingDesc').firstOrNull;
  EncodingDescription? encoding;
  if (encodingDesc != null) {
    final applications = <String>[];
    for (final application in encodingDesc.findAllElements('application')) {
      final name = _meiText(application, 'name') ??
          application.getAttribute('label') ??
          application.getAttribute('xml:id');
      if (name != null && name.isNotEmpty) applications.add(name);
    }
    encoding = EncodingDescription(
      editorialPrinciples: _meiText(encodingDesc, 'editorialDecl'),
      meiVersion: mei.getAttribute('meiversion') ?? '5',
      applications: applications,
    );
  }

  final workListElement = head.findAllElements('workList').firstOrNull;
  WorkList? workList;
  if (workListElement != null) {
    final works = <WorkInfo>[];
    for (final work in workListElement.findAllElements('work')) {
      works.add(WorkInfo(
        title: _meiText(work, 'title'),
        composer: _meiText(work, 'composer'),
        key: _meiText(work, 'key'),
        tempo: _meiText(work, 'tempo'),
        meter: _meiText(work, 'meter'),
        date: _meiText(work, 'creation') ?? _meiText(work, 'date'),
        genre: _meiText(work, 'term') ?? _meiText(work, 'genre'),
      ));
    }
    if (works.isNotEmpty) workList = WorkList(works: works);
  }

  final revisionElement = head.findAllElements('revisionDesc').firstOrNull;
  RevisionDescription? revision;
  if (revisionElement != null) {
    final entries = <RevisionEntry>[];
    for (final change in revisionElement.findAllElements('change')) {
      final date = change.getAttribute('isodate') ??
          _meiText(change, 'date') ??
          '';
      entries.add(RevisionEntry(
        date: date,
        author: _meiText(change, 'persName') ?? _meiText(change, 'name'),
        description: _meiText(change, 'changeDesc') ??
            change.innerText.trim(),
        version: change.getAttribute('n'),
      ));
    }
    if (entries.isNotEmpty) {
      revision = RevisionDescription(entries: entries);
    }
  }

  return MeiHeader(
    // <fileDesc><titleStmt><title> is mandatory in MEI, but a malformed file
    // may omit it; an empty title keeps the header usable instead of throwing.
    fileDescription: FileDescription(
      title: title ?? '',
      subtitle: subtitle,
      contributors: contributors,
      publication: publication,
      sources: sources,
    ),
    encodingDescription: encoding,
    workList: workList,
    revisionDescription: revision,
  );
}

String? _childText(XmlElement? element, String childName) {
  return element?.findElements(childName).firstOrNull?.innerText;
}
