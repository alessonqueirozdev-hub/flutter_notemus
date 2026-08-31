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

/// # The importer diagnostic channel (`warnings`)
///
/// Every import entry point in this file accepts an optional
/// `List<String>? warnings`. When one is supplied the importer APPENDS a
/// human-readable line for each place where it had to guess, clamp or discard
/// something in order to keep a real-world file importable.
///
/// ## Why it exists
///
/// The 2.7.1 forensic audit fed 29 deliberately malformed MusicXML documents
/// through the importer and every single one came back as a well-formed
/// [Staff] with NO exception and NO trace of the damage — measured:
/// `grep -rin "warn" lib/src/parsers/` returned 0 hits across 5935 lines.
/// Concretely: `<divisions>0</divisions>` silently fell back to 1, turning a
/// `<duration>4</duration>` quarter note into a WHOLE note (absoluteValue
/// 1.0 instead of 0.25); `<duration>` values of -16, 0, missing, `abc` and
/// 999999 ALL produced the same quarter note; and a `<backup>` reaching before
/// the barline produced a document byte-for-byte identical to a valid one, so
/// the corruption was undetectable downstream.
///
/// ## The contract
///
/// * Fail-soft behaviour is UNCHANGED. Anything that imported before still
///   imports, with the same result. The channel only makes the loss visible.
/// * `warnings` is append-only and never cleared by the importer, so one list
///   can collect a whole batch import.
/// * Passing `null` (the default) costs nothing — no string is ever built.
///
/// Modelled on `PdfExporter.warnings`, which already used this shape, so the
/// two diagnostic surfaces of the package read alike.
Staff parseNotationStaff(
  String source, {
  NotationFormat? format,
  int partIndex = 0,
  int staffIndex = 0,
  List<String>? warnings,
}) {
  final resolvedFormat = format ?? detectNotationFormat(source);
  return switch (resolvedFormat) {
    NotationFormat.json =>
      parseJsonStaff(source, staffIndex: staffIndex, warnings: warnings),
    NotationFormat.musicXml =>
      parseMusicXmlStaff(source, partIndex: partIndex, warnings: warnings),
    NotationFormat.mei =>
      parseMeiStaff(source, staffIndex: staffIndex, warnings: warnings),
  };
}

/// Reports every measure that holds more music than its meter allows.
///
/// `Measure.add` has enforced this since the model was written: adding a fifth
/// quarter to a 4/4 bar throws [MeasureCapacityException]. **None of the three
/// importers used it.** They build measures by writing straight into
/// `measure.elements`, which the dartdoc on that field already warns "bypasses
/// the capacity check in [add]" — so a document declaring five quarters in a
/// 4/4 bar imported cleanly, rendered as five crammed events, and reported
/// nothing at all. The rule was implemented, tested, and never consulted on the
/// path where documents actually arrive.
///
/// This warns rather than throws, deliberately. An importer that rejected a
/// whole file over one bad bar would be useless against real-world MusicXML,
/// where an over-full bar is usually a fixable mistake in one measure and the
/// other two hundred are fine.
///
/// A bar that is SHORT is not reported: a pickup, a cadenza and a final bar are
/// all legitimately short, and warning about them would train the reader to
/// ignore this channel.
///
/// Capacity is per VOICE, matching [Measure.add] — two independent voices may
/// each fill the bar without either overflowing.
void warnOverfullMeasures(Staff staff, List<String>? warnings) {
  if (warnings == null) return;

  TimeSignature? inForce;
  for (var index = 0; index < staff.measures.length; index++) {
    final measure = staff.measures[index];
    final declared = measure.timeSignature;
    if (declared != null) inForce = declared;
    final meter = declared ?? measure.inheritedTimeSignature ?? inForce;
    if (meter == null) continue;

    final capacity = meter.measureValue;
    measure.musicalValueByVoice.forEach((voice, value) {
      if (value <= capacity + Measure.capacityTolerance) return;
      final excess = value - capacity;
      warnings.add(
        'Measure ${index + 1} holds ${value.toStringAsFixed(4)} whole notes in'
        ' voice $voice but ${meter.numerator}/${meter.denominator} allows'
        ' ${capacity.toStringAsFixed(4)} — an excess of'
        ' ${excess.toStringAsFixed(4)}. The music was imported as written;'
        ' nothing was moved to the next bar or dropped.',
      );
    });
  }
}

Staff parseJsonStaff(
  String source, {
  int staffIndex = 0,
  List<String>? warnings,
}) {
  final dynamic decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('JSON notation root must be an object.');
  }

  final staff =
      _JsonImportParser(staffIndex: staffIndex, warnings: warnings)
          .parse(decoded);
  warnOverfullMeasures(staff, warnings);
  return staff;
}

Staff parseMusicXmlStaff(
  String source, {
  int partIndex = 0,
  List<String>? warnings,
}) {
  final document = XmlDocument.parse(source);
  final staff = _MusicXmlImportParser(partIndex: partIndex, warnings: warnings)
      .parse(document);
  warnOverfullMeasures(staff, warnings);
  return staff;
}

/// Imports every part/staff of a MusicXML document into a [Score].
Score parseMusicXmlScore(String source, {List<String>? warnings}) {
  final document = XmlDocument.parse(source);
  return _MusicXmlImportParser(partIndex: 0, warnings: warnings)
      .parseScore(document);
}

Staff parseMeiStaff(
  String source, {
  int staffIndex = 0,
  List<String>? warnings,
}) {
  final document = XmlDocument.parse(source);
  final staff = _MeiImportParser(staffIndex: staffIndex, warnings: warnings)
      .parse(document);
  warnOverfullMeasures(staff, warnings);
  return staff;
}

/// Imports every staff of an MEI document into a [Score], together with the
/// `<meiHead>` bibliographic metadata.
///
/// [parseMeiStaff] returns a bare [Staff], which has nowhere to keep a title,
/// a composer or a `<fileDesc>`; this is the route that surfaces them, in
/// [Score.meiHeader] (full header) and in [Score.title] / [Score.composer]
/// (convenience shortcuts).
///
/// Publicly reachable as `MEIParser.scoreFromMei` (which is a direct forward to
/// this function) and, for the header alone, as `MEIParser.headerFromMei`. A
/// stale comment here claimed the opposite — "still only exposes `parseMEI`, so
/// this entry point is not reachable from the package's public surface" — which
/// has not been true since `scoreFromMei` was added; measured, it round-trips a
/// `<meiHead>` title/composer into [Score].
Score parseMeiScore(String source, {List<String>? warnings}) {
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
      _MeiImportParser(staffIndex: index, warnings: warnings).parse(document),
  ];

  final composer = header?.fileDescription.contributors
      .where((c) => c.role == ResponsibilityRole.composer)
      .firstOrNull
      ?.name;

  // `<staffGrp>` carries the group's own labels, exactly as MusicXML's
  // `<part-group>` does with `<group-name>`/`<group-abbreviation>`. Measured
  // before this was read: `<staffGrp symbol="brace"><label>Piano</label>
  // <labelAbbr>Pno.</labelAbbr>` produced `StaffGroup.name = null` and
  // `abbreviation = null`, so an imported piano system lost its instrument
  // label while the MusicXML import of the same music kept it.
  final staffGrp = scoreElement?.findAllElements('staffGrp').firstOrNull;

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
        name: staffGrp == null ? null : _meiLabel(staffGrp, 'label'),
        abbreviation:
            staffGrp == null ? null : _meiLabel(staffGrp, 'labelAbbr'),
      ),
    ],
    meiHeader: header,
  );
}

/// Direct `<label>` / `<labelAbbr>` child of an MEI `<staffGrp>`/`<staffDef>`.
///
/// Only DIRECT children count: `findElements` (not `findAllElements`) keeps a
/// `<staffGrp>`'s own label from being stolen from the first `<staffDef>`
/// nested inside it. Empty labels come back as null so an empty element never
/// becomes an empty instrument name.
String? _meiLabel(XmlElement element, String name) {
  final text = element.findElements(name).firstOrNull?.innerText.trim();
  return text == null || text.isEmpty ? null : text;
}

class _VoiceAccumulator {
  _VoiceAccumulator(this.number);

  final int number;
  final List<MusicalElement> elements = <MusicalElement>[];
  _TupletAccumulator? activeTuplet;

  void append(MusicalElement element) {
    if (activeTuplet != null) {
      activeTuplet!.add(element);
      return;
    }
    elements.add(element);
  }

  /// Closes an open tuplet whose notated content has reached the length the
  /// ratio calls for, and reports whether it did.
  ///
  /// Only groups opened IMPLICITLY (from `<time-modification>`, with no
  /// `<notations><tuplet>` bracket in the file) are auto-closed: when the file
  /// draws the bracket itself its `type="stop"` is authoritative and is left
  /// to do the closing. Without this, two adjacent triplets in a file that
  /// carries no `<notations>` — legal MusicXML, and what several exporters
  /// emit — would merge into one six-note "triplet".
  bool finishTupletIfComplete() {
    final open = activeTuplet;
    if (open == null || !open.implicit || !open.isComplete) return false;
    finishTuplet();
    return true;
  }

  void startTuplet({
    required int actualNotes,
    required int normalNotes,
    TupletBracket? bracketConfig,
    TupletNumber? numberConfig,
    TimeSignature? timeSignature,
    bool implicit = false,
    double? unit,
  }) {
    activeTuplet = _TupletAccumulator(
      actualNotes: actualNotes,
      normalNotes: normalNotes,
      bracketConfig: bracketConfig,
      numberConfig: numberConfig,
      timeSignature: timeSignature,
      implicit: implicit,
      unit: unit,
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
    this.implicit = false,
    this.unit,
  });

  final int actualNotes;
  final int normalNotes;
  final TupletBracket? bracketConfig;
  final TupletNumber? numberConfig;
  final TimeSignature? timeSignature;

  /// True when the group was opened from `<time-modification>` alone, with no
  /// `<notations><tuplet type="start">` bracket to delimit it (M-03).
  final bool implicit;

  /// Notated value, in whole notes, of ONE "actual" note of the ratio.
  ///
  /// Taken from `<time-modification><normal-type>` (plus `<normal-dot>`s) when
  /// the file supplies it, otherwise from the first element appended. It is
  /// what makes [isComplete] decidable: a 3:2 group of eighths is complete
  /// after 3/8, whether it is written as three eighths or as a quarter plus an
  /// eighth.
  double? unit;

  /// Sum of the notated values of the rhythmic elements collected so far.
  double filled = 0.0;

  final List<MusicalElement> elements = <MusicalElement>[];

  void add(MusicalElement element) {
    elements.add(element);
    final double value = _notatedValueOf(element);
    if (value <= 0.0) return;
    unit ??= value;
    filled += value;
  }

  /// Whether [filled] has reached `actualNotes × unit` (within the same
  /// relative tolerance the duration matcher uses).
  bool get isComplete {
    final u = unit;
    if (u == null || u <= 0.0) return false;
    final double target = u * actualNotes;
    return (filled - target).abs() <= target * _durationMatchTolerance;
  }

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
    required this.hasTimeModification,
    this.bracketConfig,
    this.numberConfig,
    this.unit,
  });

  /// `<notations><tuplet type="start">` — the BRACKET, not the ratio.
  final bool startsTuplet;

  /// `<notations><tuplet type="stop">`.
  final bool endsTuplet;

  final int actualNotes;
  final int normalNotes;

  /// A usable `<time-modification>` whose ratio actually modifies the value.
  ///
  /// This — not [startsTuplet] — is what opens a tuplet group (M-03).
  final bool hasTimeModification;

  final TupletBracket? bracketConfig;
  final TupletNumber? numberConfig;

  /// Value of `<time-modification><normal-type>` in whole notes, when given.
  final double? unit;

  bool sameRatioAs(_TupletAccumulator other) =>
      other.actualNotes == actualNotes && other.normalNotes == normalNotes;
}

/// Notated value of a rhythmic element in whole notes, or 0 for anything that
/// does not occupy time of its own (grace notes, clefs, dynamics…).
double _notatedValueOf(MusicalElement element) {
  if (element is Note) return element.isGraceNote ? 0.0 : element.duration.realValue;
  if (element is Rest) return element.duration.realValue;
  if (element is Chord) return element.duration.realValue;
  if (element is Space) return element.duration.realValue;
  return 0.0;
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
  _JsonImportParser({required this.staffIndex, this.warnings});

  final int staffIndex;

  /// Diagnostic sink; see the dartdoc on [parseNotationStaff].
  final List<String>? warnings;

  void _warn(String message) => warnings?.add(message);

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

  /// Reads a staff object, INCLUDING the four staff-level fields the exporter
  /// writes.
  ///
  /// `JsonMusicExporter.staffToMap` emits `lineCount`, `name`, `abbreviation`
  /// and `transposition`, but this used to build a bare `Staff()` and read
  /// only `measures`, so all four were dropped on the way back in: measured,
  /// `parseStaff(staffToJson(s))` returned `name = null`, `abbreviation =
  /// null`, `lineCount = 5` (whatever the source said) and `transposition =
  /// null` for a B-flat instrument. All four are final on [Staff], so they have
  /// to be resolved before the measures are added.
  Staff _parseStaffRoot(Map<String, dynamic> json) {
    final int? declaredLines = _asInt(json['lineCount']);
    if (declaredLines != null && declaredLines <= 0) {
      _warn(
        'JSON staff declares lineCount $declaredLines, which is not positive;'
        ' the CMN default of 5 lines was used.',
      );
    }
    final staff = Staff(
      lineCount:
          declaredLines != null && declaredLines > 0 ? declaredLines : 5,
      name: _asString(json['name']),
      abbreviation: _asString(json['abbreviation']),
      transposition: _parseTranspositionMap(_asMap(json['transposition'])),
    );
    for (final dynamic measureJson in _asList(json['measures'])) {
      final measureMap = _asMap(measureJson);
      if (measureMap == null) continue;
      staff.add(_parseMeasure(measureMap));
    }
    return staff;
  }

  /// `{"diatonic":…, "chromatic":…, "octaveChange":…, "doubled":…,
  /// "doubledAbove":…}` as written by `JsonMusicExporter.staffToMap`.
  Transposition? _parseTranspositionMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final value = Transposition(
      diatonic: _asInt(map['diatonic']) ?? 0,
      chromatic: _asInt(map['chromatic']) ?? 0,
      octaveChange: _asInt(map['octaveChange']) ?? 0,
      doubled: _asBool(map['doubled']) ?? false,
      doubledAbove: _asBool(map['doubledAbove']) ?? false,
    );
    return value.isConcertPitch ? null : value;
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
      // The bar's OPENING BLOCK belongs to the measure and NOWHERE ELSE.
      //
      // This importer used to write the leading run into `measure.elements`
      // AND re-add every one of them to voice 1, which is exactly the
      // duplication ADR-004 removed from the MusicXML and MEI importers — the
      // JSON importer was simply missed. Measured on a round-tripped
      // polyphonic bar: `measure.elements = [Clef, Key, Time]` and
      // `voice1 = [Clef, Key, Time, Note, …]`, and the layout engine (which
      // reads both) drew each of them twice:
      // Clef@30.0, Key@68.2, Time@99.4, Clef@147.4, Key@227.6, Time@300.7.
      //
      // Only the LEADING RUN of system elements is hoisted, matching
      // `_MusicXmlImportParser._parseMeasure`: an element after the first
      // non-system one is an event in time and stays with voice 1.
      var lead = 0;
      while (lead < leadingElements.length &&
          _isSystemElement(leadingElements[lead])) {
        lead++;
      }
      for (var i = 0; i < lead; i++) {
        _appendElementToMeasure(measure, leadingElements[i]);
      }
      final trailing = leadingElements.sublist(lead);

      final voices = _asList(json['voices']);
      for (int index = 0; index < voices.length; index++) {
        final voiceMap = _asMap(voices[index]);
        if (voiceMap == null) continue;
        measure.addVoice(_parseVoice(voiceMap, index + 1, trailing));
      }
    } else {
      for (final element in leadingElements) {
        _appendElementToMeasure(measure, element);
      }
    }

    return measure;
  }

  /// Builds one voice.
  ///
  /// [leadingElements] holds only what could NOT be hoisted into the measure
  /// (see `_parseMeasure`): the leading run of clef/key/meter is the measure's
  /// and is deliberately absent here.
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
    // A note with no readable pitch used to become a middle C, in silence.
    //
    // That is not a hypothetical. Fed a document written in the wrong shape —
    // `{"type": "note", "step": "C", "octave": 5}` with the pitch fields at the
    // TOP level instead of nested under `"pitch"` — every note in the bar came
    // back as C4 and `warnings` was empty. Four different pitches, one answer,
    // nothing said. A reader editing the document would change the octave, see
    // the staff not move, and reasonably conclude the editor was broken.
    //
    // It still falls back, because losing one note is better than losing the
    // document, but it says so and names the shape it expected.
    final parsedPitch = _parsePitch(map['pitch']);
    if (parsedPitch == null) {
      _warn(
        'A <note> has no readable pitch, so middle C was assumed. Expected'
        ' either "pitch": {"step": "C", "octave": 5} or the shorthand'
        ' "pitch": "C5"'
        '${map.containsKey('step') || map.containsKey('octave') ? ' — this'
            ' element carries "step"/"octave" at the top level, which is not'
            ' the shape this parser reads' : ''}.',
      );
    }
    final pitch = parsedPitch ?? const Pitch(step: 'C', octave: 4);

    if (map['duration'] == null) {
      _warn(
        'A <note> has no "duration", so a quarter note was assumed. Expected'
        ' either "duration": {"type": "quarter"} or the shorthand'
        ' "duration": "quarter".',
      );
    }
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
  _MusicXmlImportParser({required this.partIndex, this.warnings});

  final int partIndex;

  /// Diagnostic sink; see the dartdoc on [parseNotationStaff]. Null disables
  /// diagnostics entirely (no message is even built).
  final List<String>? warnings;

  void _warn(String message) => warnings?.add(message);

  /// Measure number currently being read, used to locate a warning.
  String _measureLabel = '?';

  /// Current `<divisions>` (ticks per quarter note) for the part being read.
  ///
  /// Declared by `<attributes><divisions>` and valid until redefined, so every
  /// measure inherits the value of the previous one. Reset to the MusicXML
  /// default of 1 at the start of each part/staff pass (F-06).
  int _divisions = 1;

  /// Whether the part being read ever declared a usable `<divisions>`.
  ///
  /// A part that never declares one is legal only if it also carries no
  /// `<duration>`; otherwise every duration is silently measured against the
  /// MusicXML default of 1 tick per quarter. Reset together with [_divisions].
  bool _divisionsDeclared = false;


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
          _divisionsDeclared = false;
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
          final groupBracket = partList.bracket[gid] ?? BracketType.bracket;
          groups.add(StaffGroup(
            staves: staves,
            bracket: groupBracket,
            name: partList.groupName[gid],
            abbreviation: partList.groupAbbreviation[gid],
            // Default: barlines join whenever a bracket is drawn. An explicit
            // <group-barline> overrides that, so `bracket` + `no` survives.
            connectBarlines: partList.groupBarline[gid],
          ));
        }
      }
    } else {
      // Timewise: gather each part's measures across all <measure> wrappers.
      //
      // `<part-list>` is NOT partwise-only — score-timewise carries the very
      // same element, and this branch used to ignore it: measured, two NAMED
      // parts came back with `name = null` and `abbreviation = null`, while
      // the identical music in score-partwise kept both. Each `<part>` inside
      // a `<measure>` carries the `@id` that indexes the list.
      final partList = _parsePartList(root);
      final partMeasures = <int, List<XmlElement>>{};
      final partIds = <int, String>{};
      var partCount = 0;
      for (final measure in root.findElements('measure')) {
        final parts = measure.findElements('part').toList();
        partCount = parts.length > partCount ? parts.length : partCount;
        for (var p = 0; p < parts.length; p++) {
          (partMeasures[p] ??= <XmlElement>[]).add(parts[p]);
          final id = parts[p].getAttribute('id');
          if (id != null) partIds[p] = id;
        }
      }
      for (var p = 0; p < partCount; p++) {
        final partElements = partMeasures[p] ?? const <XmlElement>[];
        final partId = partIds[p];
        final staff = Staff(
          lineCount: _musicXmlStaffLines(partElements),
          name: partList.partName[partId],
          abbreviation: partList.partAbbreviation[partId],
          transposition: _transpositionOf(
            partElements.isEmpty
                ? null
                : _musicXmlTranspose(partElements.first),
          ),
        );
        _divisions = 1;
        _divisionsDeclared = false;
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
        final gid = partList.groupOf[partId];
        groups.add(StaffGroup(
          staves: [staff],
          bracket: gid == null
              ? BracketType.none
              : (partList.bracket[gid] ?? BracketType.bracket),
          name: gid == null ? null : partList.groupName[gid],
          abbreviation: gid == null ? null : partList.groupAbbreviation[gid],
          connectBarlines: gid == null ? null : partList.groupBarline[gid],
        ));
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
    Map<int, String> groupAbbreviation,
    Map<int, bool> groupBarline,
    Map<String, String> partName,
    Map<String, String> partAbbreviation,
  }) _parsePartList(XmlElement root) {
    final groupOf = <String, int?>{};
    final bracket = <int, BracketType>{};
    final groupName = <int, String>{};
    final groupAbbreviation = <int, String>{};
    final groupBarline = <int, bool>{};
    final partName = <String, String>{};
    final partAbbreviation = <String, String>{};
    final partList = root.findElements('part-list').firstOrNull;
    if (partList == null) {
      return (
        groupOf: groupOf,
        bracket: bracket,
        groupName: groupName,
        groupAbbreviation: groupAbbreviation,
        groupBarline: groupBarline,
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
            // `<group-abbreviation>` is the short label drawn from the second
            // system on. It was never read (nor written), so measured, all
            // three groups of a round-tripped conductor score came back with
            // `abbreviation = null`.
            final shortLabel = child
                .findElements('group-abbreviation')
                .firstOrNull
                ?.innerText
                .trim();
            if (shortLabel != null && shortLabel.isNotEmpty) {
              groupAbbreviation[id] = shortLabel;
            }
            // `<group-barline>` is independent of `<group-symbol>`: a group
            // may be bracketed without its barlines joining, and vice versa.
            final barline = _normalizeToken(
              child.findElements('group-barline').firstOrNull?.innerText,
            );
            if (barline == 'yes') groupBarline[id] = true;
            if (barline == 'no') groupBarline[id] = false;
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
      groupAbbreviation: groupAbbreviation,
      groupBarline: groupBarline,
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
      doubledAbove: raw.doubledAbove,
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
      case 'none':
        // `none` is a legal MusicXML group-symbol-value and it is the ONE the
        // default below cannot stand in for: measured, a BracketType.none
        // group came back as BracketType.bracket, which also flipped
        // StaffGroup.connectBarlines from false to true, so a bracket was
        // drawn and the barlines joined where the author asked for neither.
        return BracketType.none;
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
    _divisionsDeclared = false;
    for (final measureElement in part.findElements('measure')) {
      staff.add(_parseMeasure(measureElement));
    }
    return staff;
  }

  Staff _parseTimewise(XmlElement root) {
    _divisions = 1;
    _divisionsDeclared = false;
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
    // `<part-list>` exists in score-timewise too; the part id lives on each
    // `<part>` inside a `<measure>`.
    final partList = _parsePartList(root);
    final partId = selectedParts.firstOrNull?.getAttribute('id');
    return Staff(
      measures: measures,
      lineCount: _musicXmlStaffLines(selectedParts),
      name: partList.partName[partId],
      abbreviation: partList.partAbbreviation[partId],
      transposition: _transpositionOf(
        selectedParts.isEmpty ? null : _musicXmlTranspose(selectedParts.first),
      ),
    );
  }

  /// Parses one MusicXML measure. When [staffFilter] is set (multi-staff part),
  /// only notes whose `staff` matches and clefs for that staff are kept.
  ///
  /// A musical time cursor (in `<divisions>` ticks from the barline) is kept
  /// while walking the children so `<backup>` and `<forward>` reposition the
  /// following notes instead of being ignored (F-07).
  Measure _parseMeasure(XmlElement measureElement, {int? staffFilter}) {
    _measureLabel = measureElement.getAttribute('number') ?? '?';
    final Map<int, _VoiceAccumulator> voices = <int, _VoiceAccumulator>{};
    final List<MusicalElement> metadataElements = <MusicalElement>[];
    TimeSignature? currentTimeSignature;

    // Musical time cursor, in <divisions> ticks from the start of the bar.
    double cursor = 0.0;
    // Furthest point the cursor ever reached: the bar's encoded length, used
    // to cross-check the model against the file (see the value validation at
    // the end of this method).
    double maxCursor = 0.0;
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
          // `<divisions>` is the denominator of EVERY `<duration>` in the
          // part, so a rejected declaration is not a cosmetic loss: measured,
          // `<divisions>0</divisions>` left _divisions at the MusicXML default
          // of 1 and imported `<duration>4</duration>` as a WHOLE note
          // (absoluteValue 1.0) where the file meant a quarter (0.25). The
          // guard stays — falling back keeps the file importable — but the
          // substitution is now reported.
          final String? rawDivisions = _childText(child, 'divisions');
          final int? declaredDivisions = _asInt(rawDivisions);
          if (declaredDivisions != null && declaredDivisions > 0) {
            _divisions = declaredDivisions;
            _divisionsDeclared = true;
          } else if (rawDivisions != null && rawDivisions.trim().isNotEmpty) {
            _warn(
              'Measure $_measureLabel: <divisions> is "${rawDivisions.trim()}",'
              ' which is not a positive integer; keeping divisions=$_divisions.'
              ' Every <duration> in this part is scaled by that value, so note'
              ' lengths may be wrong.',
            );
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
          final String? rawDuration = _childText(child, 'duration');
          final int? parsedDuration = _asInt(rawDuration);
          final int tick = advancesTime ? (parsedDuration ?? 0) : 0;
          if (advancesTime) {
            // `<duration>` is the ONLY carrier of a note's position in the bar.
            // Measured, values of -16, 0, missing and "abc" all produced the
            // same quarter note as a well-formed file, because the fallback
            // chain ends at DurationType.quarter with nothing said about it.
            if (rawDuration == null || rawDuration.trim().isEmpty) {
              _warn(
                'Measure $_measureLabel: a <note> has no <duration>; its'
                ' position in the bar was taken as 0 ticks and its value fell'
                ' back to <type> (or a quarter note).',
              );
            } else if (parsedDuration == null) {
              _warn(
                'Measure $_measureLabel: <duration> is "${rawDuration.trim()}",'
                ' which is not an integer; the note was placed at 0 ticks and'
                ' its value fell back to <type> (or a quarter note).',
              );
            } else if (parsedDuration <= 0) {
              _warn(
                'Measure $_measureLabel: <duration> is $parsedDuration, which'
                ' is not positive; the note occupies no time in the bar and its'
                ' value fell back to <type> (or a quarter note).',
              );
            } else if (!_divisionsDeclared) {
              _warn(
                'Measure $_measureLabel: a <note> carries <duration>'
                ' $parsedDuration but the part never declared <divisions>;'
                ' the MusicXML default of 1 tick per quarter was assumed, which'
                ' makes that note ${parsedDuration / 4.0} whole notes long.',
              );
            }
          }

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
          if (cursor > maxCursor) maxCursor = cursor;
          break;
        case 'backup':
          final int backupTicks = _asInt(_childText(child, 'duration')) ?? 0;
          if (backupTicks > 0) {
            cursor -= backupTicks;
            if (cursor < 0) {
              // A `<backup>` reaching before the barline is illegal MusicXML.
              // Measured, `<backup><duration>9999</duration></backup>` at the
              // start of a bar was clamped to 0 AND opened a phantom synthetic
              // voice, producing a Staff byte-for-byte identical to the one a
              // legal backup produces (audit case B03 == B04) — undetectable
              // downstream. The clamp stays (it is what keeps the bar
              // importable); the overshoot is now reported.
              _warn(
                'Measure $_measureLabel: <backup> of $backupTicks ticks reaches'
                ' ${(-cursor).round()} ticks before the start of the bar; it'
                ' was clamped to the barline.',
              );
              cursor = 0;
            }
            // Without <voice> the only signal that a second voice starts is the
            // rewind itself, so hand out the next synthetic voice number.
            if (useSyntheticVoices) syntheticVoice++;
          }
          break;
        case 'forward':
          final int forwardTicks = _asInt(_childText(child, 'duration')) ?? 0;
          if (forwardTicks > 0) {
            cursor += forwardTicks;
            if (cursor > maxCursor) maxCursor = cursor;
            sawForward = true;
            // A `<forward>` is padded with invisible Space, so an absurd one
            // does not throw — it inflates the bar. Measured,
            // `<forward><duration>400</duration></forward>` at divisions=4
            // injected 25 whole notes of Space into a single 4/4 bar.
            final double whole =
                _divisions > 0 ? forwardTicks / _divisions / 4.0 : 0.0;
            final double? capacity = currentTimeSignature != null &&
                    !currentTimeSignature!.isFreeTime
                ? currentTimeSignature!.measureValue
                : null;
            if (capacity != null && whole > capacity) {
              _warn(
                'Measure $_measureLabel: <forward> of $forwardTicks ticks'
                ' (${whole.toStringAsFixed(3)} whole notes) is longer than the'
                ' whole bar (${capacity.toStringAsFixed(3)}); the gap was'
                ' filled with invisible Space anyway.',
              );
            }
          }
          break;
      }
    }

    if (voices.isEmpty || (voices.length == 1 && !voices.containsKey(2))) {
      // A tuplet still open at the barline has to be closed here too. The
      // multi-voice branch below always did; this one did not, and once M-03
      // let `<time-modification>` open groups without a `<tuplet type="stop">`
      // to close them, a triplet ending a bar would have been dropped whole.
      voice(1).finishTuplet();
      final measure = Measure();
      for (final element in voice(1).elements) {
        _appendElementToMeasure(measure, element);
      }
      _validateMeasureValue(measure, maxCursor);
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
    _validateMeasureValue(measure, maxCursor);
    return measure;
  }

  /// Cross-checks the model the importer just built against the arithmetic the
  /// FILE states, and reports a mismatch through the diagnostic channel.
  ///
  /// [encodedTicks] is how far the `<duration>` / `<backup>` / `<forward>`
  /// cursor ever reached, so `encodedTicks / divisions / 4` is the bar length
  /// in whole notes according to the source. [Measure.currentMusicalValue] is
  /// the same length according to the imported elements. They must agree, and
  /// when they do not exactly one of the two readings is wrong.
  ///
  /// This is the check that would have caught M-03 on its own: before
  /// `<time-modification>` opened tuplet groups, a bar of three triplet
  /// quarters plus a half measured 1.25 whole notes against an encoded 1.0.
  void _validateMeasureValue(Measure measure, double encodedTicks) {
    if (warnings == null) return;
    if (_divisions <= 0 || encodedTicks <= 0) return;
    final double encodedWhole = encodedTicks / _divisions / 4.0;
    final double modelWhole = measure.currentMusicalValue;
    if ((modelWhole - encodedWhole).abs() <=
        encodedWhole * _durationMatchTolerance) {
      return;
    }
    _warn(
      'Measure $_measureLabel: the imported bar is'
      ' ${modelWhole.toStringAsFixed(4)} whole notes long but its <duration>'
      ' values add up to ${encodedWhole.toStringAsFixed(4)}'
      ' (${encodedTicks.round()} ticks at <divisions>$_divisions).',
    );
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
      if (pitch == null) {
        // Neither <pitch>, nor <unpitched>, nor <rest>: there is nothing to
        // draw. The note is still dropped (it carries no engravable content)
        // but it no longer vanishes without a word — measured, such a <note>
        // disappeared leaving the bar short by its own <duration>.
        _warn(
          'Measure $_measureLabel: a <note> has neither <pitch>, <unpitched>'
          ' nor <rest>; it was dropped, and the bar is shorter by its'
          ' <duration>.',
        );
        return;
      }
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

    // ── Tuplet grouping (M-03) ────────────────────────────────────────────
    // The RATIO opens and closes the group; `<notations><tuplet>` only draws
    // it. A chord tone is not an event of its own — it merged into the note
    // that already decided the group — so it never changes the state.
    if (!isChordTone) {
      final open = accumulator.activeTuplet;
      if (tuplets.startsTuplet && open != null && open.elements.isNotEmpty) {
        // An explicit bracket starts HERE, so whatever is still open belongs
        // to the previous group. This is what separates two adjacent triplets
        // that share the same ratio.
        accumulator.finishTuplet();
      } else if (open != null &&
          tuplets.hasTimeModification &&
          !tuplets.sameRatioAs(open)) {
        // The ratio changed mid-run: a triplet followed by a quintuplet with
        // no bracket between them.
        accumulator.finishTuplet();
      } else if (open != null &&
          open.implicit &&
          !tuplets.hasTimeModification) {
        // Back to unmodified values: the implicit group ends before this note.
        accumulator.finishTuplet();
      }

      if (accumulator.activeTuplet == null &&
          (tuplets.hasTimeModification || tuplets.startsTuplet)) {
        accumulator.startTuplet(
          actualNotes: tuplets.actualNotes,
          normalNotes: tuplets.normalNotes,
          bracketConfig: tuplets.bracketConfig,
          numberConfig: tuplets.numberConfig,
          timeSignature: currentTimeSignature,
          implicit: !tuplets.startsTuplet,
          unit: tuplets.unit,
        );
      }
    }

    if (baseElement != null) {
      accumulator.append(baseElement);
    }

    for (final extra in _musicXmlPostNoteElements(noteElement)) {
      accumulator.append(extra);
    }

    if (tuplets.endsTuplet) {
      accumulator.finishTuplet();
    } else if (!isChordTone) {
      accumulator.finishTupletIfComplete();
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

  /// `<double/>`: the part also sounds an octave away.
  bool doubled,

  /// `<double above="yes"/>` (MusicXML 4.0): the doubling is an octave UP.
  ///
  /// The attribute is optional and defaults to `no`, so a bare `<double/>`
  /// means an octave DOWN. Wave 1 added [Transposition.doubledAbove] for this
  /// and nothing set it: measured, `<double above="yes"/>` came back as
  /// `doubledAbove: false` and `semitones: -14` where the part sounds +10.
  bool doubledAbove,
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
    final double_ = transpose.findElements('double').firstOrNull;
    return (
      diatonic: diatonic ?? 0,
      chromatic: chromatic ?? 0,
      octaveChange: octaveChange ?? 0,
      doubled: double_ != null,
      doubledAbove: double_?.getAttribute('above') == 'yes',
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
    'doubleAbove': transposition.doubledAbove,
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

/// Reads everything a `<note>` says about tuplet membership.
///
/// ## Why `<time-modification>` and not `<notations><tuplet>`
///
/// MusicXML separates the two deliberately: `<time-modification>` is the
/// ARITHMETIC (it is what makes `<duration>` and `<type>` agree), while
/// `<notations><tuplet>` is only the printed BRACKET and NUMBER, and is
/// optional. A file may legally carry the first without the second, and
/// several exporters emit exactly that.
///
/// Measured before this split: three triplet quarters written as
/// `<divisions>6</divisions>`, `<duration>4</duration>`, `<type>quarter</type>`
/// and `<time-modification>3/2` imported as three FULL quarters — the bar
/// measured 1.25 whole notes where the file says 1.0, and MIDI emitted 960
/// ticks per note instead of 640 — because the group was opened only by the
/// `<tuplet>` notation, which the file never wrote.
_TupletEventInfo _musicXmlTupletInfo(XmlElement noteElement) {
  final timeModification = noteElement
      .findElements('time-modification')
      .firstOrNull;
  final int? declaredActual =
      _asInt(_childText(timeModification, 'actual-notes'));
  final int? declaredNormal =
      _asInt(_childText(timeModification, 'normal-notes'));
  // A ratio is only usable when both halves are positive AND actually modify
  // the value; `3:3` is a no-op and must not open a group.
  final bool hasTimeModification = declaredActual != null &&
      declaredNormal != null &&
      declaredActual > 0 &&
      declaredNormal > 0 &&
      declaredActual != declaredNormal;

  int actualNotes = declaredActual ?? 3;
  int normalNotes = declaredNormal ?? 2;

  // `<normal-type>` names the note value the ratio counts in, which is what
  // makes a heterogeneous group (quarter + eighth as a triplet of eighths)
  // measurable. Falls back to the first element of the group when absent.
  final DurationType? normalType =
      _parseDurationType(_childText(timeModification, 'normal-type'));
  final int normalDots =
      timeModification?.findElements('normal-dot').length ?? 0;
  final double? unit =
      normalType == null ? null : _dottedValue(normalType, normalDots);

  bool starts = false;
  bool ends = false;
  TupletBracket? bracketConfig;
  TupletNumber? numberConfig;

  for (final notations in noteElement.findElements('notations')) {
    for (final tuplet in notations.findElements('tuplet')) {
      final type = _normalizeToken(tuplet.getAttribute('type'));
      if (type == 'start') starts = true;
      if (type == 'stop') ends = true;
      actualNotes = _asInt(tuplet.getAttribute('actual-notes')) ?? actualNotes;
      normalNotes = _asInt(tuplet.getAttribute('normal-notes')) ?? normalNotes;
      if (type == 'start') {
        // `bracket="no"` and `show-number="both"` are the display half of the
        // element — the only half this library takes from it now.
        if (_normalizeToken(tuplet.getAttribute('bracket')) == 'no') {
          bracketConfig = const TupletBracket(show: false);
        }
        if (_normalizeToken(tuplet.getAttribute('show-number')) == 'both') {
          numberConfig = const TupletNumber(showAsRatio: true);
        }
      }
    }
  }

  return _TupletEventInfo(
    startsTuplet: starts,
    endsTuplet: ends,
    actualNotes: actualNotes,
    normalNotes: normalNotes,
    hasTimeModification: hasTimeModification,
    bracketConfig: bracketConfig,
    numberConfig: numberConfig,
    unit: unit,
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

/// Reads a MusicXML `<octave-shift>` START into an [OctaveMark].
///
/// ## Why `type="down"` is 8va (the mapping used to be inverted, both ways)
///
/// The MusicXML spec defines `<octave-shift>` as the amount the notes are
/// shifted FROM the pitches they perform, because `<pitch>` in MusicXML is
/// always the SOUNDING pitch (the same rule this package adopted in ADR-003):
/// "the octave-shift element indicates where notes are shifted up or down from
/// their performed values because of printing difficulty. Thus a treble clef
/// line noted with 8va will be indicated with an octave-shift down from the
/// pitch data indicated in the notes."
///
/// So `type="down"` is the marking whose notes are PRINTED an octave below what
/// they sound — that is exactly 8va — and `type="up"` is 8vb. `size` is the
/// interval label, not a count of octaves: 8 = one octave, 15 = two, 22 = three.
///
/// The previous switch had it backwards on every arm: `'8:down'` produced
/// [OctaveType.vb8], `'15:up'` produced `va15`, `'22:up'` produced `va22`, and
/// `'8:up'` fell through the default to `va8`. On top of that it keyed the
/// switch on `placement ?? type`, and `placement` is "above"/"below" in
/// MusicXML, never "up"/"down" — so ANY document that carried an explicit
/// `placement` attribute missed every arm and fell through to `va8` regardless
/// of direction. Both are fixed here: the direction now comes from `type`
/// alone, which is the only attribute the spec makes authoritative.
///
/// (MEI, handled by [_meiOctaveMark], states the same thing the other way
/// round: `@dis.place="above"` means the notes sound an octave higher than
/// written, i.e. 8va — that mapping was already correct and is unchanged.)
///
/// ## How a span ENDS
///
/// A `type="stop"` (and `type="continue"`) direction returns `null` here, so no
/// element is emitted and the span length is not recorded anywhere: [OctaveMark]
/// is built with `startMeasure: 0, endMeasure: 0`. `OctaveSpanTracker` reads
/// that degenerate span as "ends at the end of the measure the mark was found
/// in", which is the conservative choice — over-extending a bracket would
/// silently reprint music the author never marked. Honouring a multi-measure
/// `<octave-shift>` requires this importer to pair the stop with its start and
/// fill in `endMeasure`.
OctaveMark? _musicXmlOctaveShift(XmlElement octaveShiftElement) {
  final type = _normalizeToken(octaveShiftElement.getAttribute('type'));
  if (type == 'stop' || type == 'continue') return null;
  final size = _asInt(octaveShiftElement.getAttribute('size')) ?? 8;

  return OctaveMark(
    type: switch ('$size:$type') {
      '8:up' => OctaveType.vb8,
      '15:down' => OctaveType.va15,
      '15:up' => OctaveType.vb15,
      '22:down' => OctaveType.va22,
      '22:up' => OctaveType.vb22,
      _ => OctaveType.va8,
    },
    startMeasure: 0,
    endMeasure: 0,
    length: 0.0,
  );
}

class _MeiImportParser {
  _MeiImportParser({required this.staffIndex, this.warnings});

  final int staffIndex;

  /// Diagnostic sink; see the dartdoc on [parseNotationStaff].
  final List<String>? warnings;

  void _warn(String message) => warnings?.add(message);

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
    if (score == null) {
      _warn('MEI document has no <score>; an empty staff was returned.');
      return Staff();
    }

    final sections = _topLevelSections(score);
    if (sections.isEmpty) {
      _warn('MEI <score> has no <section>; an empty staff was returned.');
      return Staff();
    }

    // MEI encodes the initial clef/key/meter in <scoreDef>/<staffDef>, not
    // inline in <staff>. Capture them and seed the first measure.
    final scoreDef = score.findAllElements('scoreDef').firstOrNull;
    final defaults =
        scoreDef == null ? const <MusicalElement>[] : _meiStaffDefaults(scoreDef);

    // <staffDef @lines> sizes the staff (1 = percussion, 6 = guitar tab);
    // Staff.lineCount is final, so it must be resolved up front — and so are
    // the label and the instrument transposition.
    final staffDef = scoreDef == null ? null : _staffDefFor(scoreDef);
    final staff = Staff(
      lineCount: scoreDef == null ? 5 : _meiStaffDefLines(scoreDef),
      name: staffDef == null ? null : _meiLabel(staffDef, 'label'),
      abbreviation: staffDef == null ? null : _meiLabel(staffDef, 'labelAbbr'),
      transposition: staffDef == null ? null : _meiTransposition(staffDef),
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

  /// The `<staffDef>` of [scoreDef] that describes this [staffIndex].
  ///
  /// Matched on `@n` (1-based in MEI) and falling back to position, which is
  /// what the three call sites — lines, defaults, transposition — all need.
  XmlElement? _staffDefFor(XmlElement scoreDef) {
    final defs = scoreDef.findAllElements('staffDef').toList();
    if (defs.isEmpty) return null;
    for (final d in defs) {
      if ((_asInt(d.getAttribute('n')) ?? 1) == staffIndex + 1) return d;
    }
    return defs[staffIndex.clamp(0, defs.length - 1)];
  }

  /// `<staffDef @lines>` for this staffIndex (falling back to the first
  /// staffDef, then to the CMN default of 5).
  int _meiStaffDefLines(XmlElement scoreDef) {
    final sd = _staffDefFor(scoreDef);
    if (sd == null) return 5;
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
    final sd = _staffDefFor(scoreDef);
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
              tieOverride: noteId == null ? null : _tieById[noteId],
              warnings: warnings);
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
          final chord =
              _meiChord(child, voiceNumber: voiceNumber, warnings: warnings);
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
///
/// ## `@clef.dis` / `@clef.dis.place`
///
/// MEI carries octave-transposing clefs in TWO interchangeable places: the
/// `<clef>` child element (`@dis`, `@dis.place`) and the `<staffDef>`
/// attribute form (`@clef.dis`, `@clef.dis.place`). [_meiClef] has always read
/// the first; the second was ignored, so measured, `<staffDef clef.shape="G"
/// clef.line="2" clef.dis="8" clef.dis.place="below"/>` imported as a PLAIN
/// treble clef (octaveShift 0) and every note of that staff printed an octave
/// wrong — the same defect ADR-003 fixed on the MusicXML `<clef-octave-change>`
/// side.
///
/// Direction: per the MEI Guidelines, `@dis.place` records "the direction of
/// octave displacement", i.e. where the SOUNDING pitch lies relative to the
/// written notes. `dis.place="below"` therefore means the staff sounds an
/// octave lower than written — a treble-8vb (tenor "G8" clef), which is the
/// common case this encodes. `"above"` is 8va. That is also exactly what
/// [_meiClef] already does for the element form, so the two spellings of the
/// same clef can no longer disagree: both now go through
/// [_meiClefFromParts].
Clef? _meiDefClef(XmlElement def) {
  final child = def.findElements('clef').firstOrNull;
  if (child != null) {
    final c = _meiClef(child);
    if (c != null) return c;
  }
  final shape = def.getAttribute('clef.shape');
  if (shape == null) return null;
  return _meiClefFromParts(
    sign: shape,
    line: _asInt(def.getAttribute('clef.line')),
    dis: _asInt(def.getAttribute('clef.dis')) ?? 0,
    disPlace: _normalizeToken(def.getAttribute('clef.dis.place')),
    staffLines: _asInt(def.getAttribute('lines')),
  );
}

/// Written-to-sounding transposition declared on an MEI `<staffDef>`.
///
/// MEI puts on `<staffDef>` what MusicXML puts in `<transpose>`:
/// `@trans.semi` is the semitone offset (MusicXML `<chromatic>`) and
/// `@trans.diat` the diatonic-step offset (MusicXML `<diatonic>`). Measured
/// before this was read: `trans.semi="-2" trans.diat="-1"` on a B-flat
/// instrument gave `staff.transposition = null` and MIDI note 60 where concert
/// pitch is 58.
///
/// Octaves: MEI has no separate `octave-change`, the whole offset lives in
/// `@trans.semi`, so [Transposition.octaveChange] stays 0 and the semitones
/// are kept whole. `isConcertPitch` declarations come back as null, matching
/// `_transpositionOf` on the MusicXML side.
Transposition? _meiTransposition(XmlElement def) {
  final semi = _asInt(def.getAttribute('trans.semi'));
  final diat = _asInt(def.getAttribute('trans.diat'));
  if (semi == null && diat == null) return null;
  final value = Transposition(
    diatonic: diat ?? 0,
    chromatic: semi ?? 0,
  );
  return value.isConcertPitch ? null : value;
}

/// Builds a [Clef] from the pieces both MEI spellings decompose into.
///
/// [sign] is `@shape`/`@clef.shape`, [line] is `@line`/`@clef.line`, [dis] and
/// [disPlace] are the octave displacement (0 when none), and [staffLines] is
/// the `<staffDef @lines>` used to tell 4- from 6-string tablature apart.
Clef? _meiClefFromParts({
  required String? sign,
  required int? line,
  required int dis,
  required String disPlace,
  int? staffLines,
}) {
  if (sign == null) return null;
  final s = _normalizeToken(sign);

  if (s == 'g') {
    if (dis == 8 && disPlace == 'above') return Clef(clefType: ClefType.treble8va);
    if (dis == 8 && disPlace == 'below') return Clef(clefType: ClefType.treble8vb);
    if (dis == 15 && disPlace == 'above') {
      return Clef(clefType: ClefType.treble15ma);
    }
    if (dis == 15 && disPlace == 'below') {
      return Clef(clefType: ClefType.treble15mb);
    }
    return Clef(clefType: ClefType.treble);
  }

  if (s == 'f') {
    if (line == 3) return Clef(clefType: ClefType.bassThirdLine);
    if (dis == 8 && disPlace == 'above') return Clef(clefType: ClefType.bass8va);
    if (dis == 8 && disPlace == 'below') return Clef(clefType: ClefType.bass8vb);
    if (dis == 15 && disPlace == 'above') {
      return Clef(clefType: ClefType.bass15ma);
    }
    if (dis == 15 && disPlace == 'below') {
      return Clef(clefType: ClefType.bass15mb);
    }
    return Clef(clefType: ClefType.bass);
  }

  if (s == 'c') {
    // A 4th-line C clef displaced an octave down is the tenor-voice "C8vb"
    // clef; the other C-clef lines have no displaced variant in [ClefType].
    if (dis == 8 && disPlace == 'below' && (line == null || line == 4)) {
      return Clef(clefType: ClefType.c8vb);
    }
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
    return Clef(clefType: staffLines == 4 ? ClefType.tab4 : ClefType.tab6);
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

/// Clef from an MEI `<clef>` element (`@shape`/`@sign`, `@line`, `@dis`,
/// `@dis.place`). Shares [_meiClefFromParts] with the `<staffDef @clef.*>`
/// attribute form so the two spellings can never diverge.
Clef? _meiClef(XmlElement clefElement) {
  return _meiClefFromParts(
    sign: clefElement.getAttribute('shape') ?? clefElement.getAttribute('sign'),
    line: _asInt(clefElement.getAttribute('line')),
    dis: _asInt(clefElement.getAttribute('dis')) ?? 0,
    disPlace: _normalizeToken(clefElement.getAttribute('dis.place')),
    staffLines: _asInt(clefElement.getAttribute('lines')),
  );
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

/// Builds a [Note] from an MEI `<note>`.
///
/// ## Malformed input is not the same thing as a tablature note
///
/// The two cases this used to conflate both reach the same `@pname`/`@oct`
/// test, and returning `null` for both meant the caller dropped the element
/// with no exception and no message. Measured: `<note pname="c" dur="4"/>`
/// with no `@oct` produced a measure with n=0 notes and complete silence,
/// while the MusicXML equivalent — a `<pitch>` missing its `<octave>` — threw
/// `FormatException`. That asymmetry is the defect.
///
/// * A pure TABLATURE note (`@tab.fret`/`@tab.string`, no pitch at all) is
///   legitimate MEI. It is still dropped, because [Note.pitch] is required and
///   non-nullable and deriving one would mean inventing a tuning — but the
///   loss is now reported through [warnings].
/// * A CMN note missing `@pname` or `@oct` is malformed input and now throws
///   [FormatException], with a message naming the missing attribute, matching
///   what `_musicXmlPitch` does.
Note? _meiNote(XmlElement noteElement,
    {required int voiceNumber,
    BeamType? beamOverride,
    SlurType? slurOverride,
    TieType? tieOverride,
    List<String>? warnings}) {
  final rawStep = noteElement.getAttribute('pname');
  final octave = _asInt(noteElement.getAttribute('oct'));
  if (rawStep == null || octave == null) {
    final bool isTablatureNote =
        noteElement.getAttribute('tab.fret') != null ||
            noteElement.getAttribute('tab.string') != null;
    if (isTablatureNote) {
      warnings?.add(
        'MEI <note> is a tablature-only note (tab.fret'
        '="${noteElement.getAttribute('tab.fret')}" tab.string'
        '="${noteElement.getAttribute('tab.string')}") with no @pname/@oct;'
        ' it was dropped because a Note requires a pitch and no tuning is'
        ' declared.',
      );
      return null;
    }
    final missing = <String>[
      if (rawStep == null) '@pname',
      if (noteElement.getAttribute('oct') == null)
        '@oct'
      else if (octave == null)
        '@oct (value "${noteElement.getAttribute('oct')}" is not an integer)',
    ].join(' and ');
    throw FormatException(
      'MEI <note> is missing $missing. A note with neither a pitch nor'
      ' tablature coordinates (@tab.fret/@tab.string) cannot be engraved.',
    );
  }
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

Chord? _meiChord(XmlElement chordElement,
    {required int voiceNumber, List<String>? warnings}) {
  final duration = Duration(
    _parseDurationType(chordElement.getAttribute('dur')) ??
        DurationType.quarter,
    dots: _asInt(chordElement.getAttribute('dots')) ?? 0,
  );

  final List<Note> notes = <Note>[];
  for (final child in chordElement.findElements('note')) {
    final note =
        _meiNote(child, voiceNumber: voiceNumber, warnings: warnings);
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
    // MEI has no `<time-modification>`: `@num`/`@numbase` (or the `<tuplet>`
    // container) are BOTH the ratio and the bracket, so the implicit grouping
    // M-03 added on the MusicXML side has nothing to key off here.
    hasTimeModification: false,
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
