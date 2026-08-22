// lib/src/parsers/json_exporter.dart

import 'dart:convert';

import '../../core/core.dart';

/// Serialises a [Staff] or [Score] to the JSON shape `JsonMusicParser` reads.
///
/// Why this file exists
/// --------------------
/// There was no JSON exporter at all. `JsonMusicParser` could only parse, so
/// "JSON round trip" was not a lossy operation — it was an impossible one, and
/// the audit that scored JSON at 6/10 for being "tolerant" had never been able
/// to test a round trip.
///
/// The contract is symmetric with the importer: anything the importer reads,
/// this writes, so `parse(export(staff))` preserves the model. Fields the
/// importer ignores are deliberately not emitted, so the JSON never claims to
/// carry information that would be lost on the way back.
class JsonMusicExporter {
  const JsonMusicExporter._();

  /// A [Staff] as an indented JSON document.
  static String staffToJson(Staff staff, {bool pretty = true}) {
    final encoder = pretty ? const JsonEncoder.withIndent('  ') : null;
    final map = staffToMap(staff);
    return encoder == null ? jsonEncode(map) : encoder.convert(map);
  }

  /// A [Score] as an indented JSON document (`{"staves": [...]}`).
  static String scoreToJson(Score score, {bool pretty = true}) {
    final map = <String, dynamic>{
      if (score.title != null) 'title': score.title,
      if (score.composer != null) 'composer': score.composer,
      'staves': [for (final staff in score.allStaves) staffToMap(staff)],
    };
    final encoder = pretty ? const JsonEncoder.withIndent('  ') : null;
    return encoder == null ? jsonEncode(map) : encoder.convert(map);
  }

  static Map<String, dynamic> staffToMap(Staff staff) => <String, dynamic>{
        'lineCount': staff.lineCount,
        if (staff.name != null) 'name': staff.name,
        if (staff.abbreviation != null) 'abbreviation': staff.abbreviation,
        if (staff.transposition != null)
          'transposition': <String, dynamic>{
            'diatonic': staff.transposition!.diatonic,
            'chromatic': staff.transposition!.chromatic,
            'octaveChange': staff.transposition!.octaveChange,
            'doubled': staff.transposition!.doubled,
          },
        'measures': [for (final measure in staff.measures) _measure(measure)],
      };

  static Map<String, dynamic> _measure(Measure measure) {
    final map = <String, dynamic>{
      if (measure.number != null) 'number': measure.number,
      if (!measure.autoBeaming) 'autoBeaming': false,
      'elements': [
        for (final element in measure.elements) ...[
          if (_element(element) != null) _element(element)!,
        ],
      ],
    };
    if (measure is MultiVoiceMeasure) {
      map['voices'] = [
        for (final voice in measure.sortedVoices)
          <String, dynamic>{
            'number': voice.number,
            if (voice.name != null) 'name': voice.name,
            'elements': [
              for (final element in voice.elements) ...[
                if (_element(element) != null) _element(element)!,
              ],
            ],
          },
      ];
    }
    return map;
  }

  static Map<String, dynamic>? _element(MusicalElement element) {
    if (element is Note) return _note(element);
    if (element is Rest) {
      return <String, dynamic>{
        'type': 'rest',
        'duration': _duration(element.duration),
      };
    }
    if (element is Chord) {
      return <String, dynamic>{
        'type': 'chord',
        'duration': _duration(element.duration),
        'notes': [for (final note in element.notes) _note(note)],
        if (element.voice != null) 'voice': element.voice,
      };
    }
    if (element is Clef) {
      return <String, dynamic>{
        'type': 'clef',
        'clefType': element.clefType.name,
      };
    }
    if (element is KeySignature) {
      return <String, dynamic>{
        'type': 'keysignature',
        'count': element.count,
        if (element.previousCount != null)
          'previousCount': element.previousCount,
      };
    }
    if (element is TimeSignature) {
      return <String, dynamic>{
        'type': 'timesignature',
        'numerator': element.numerator,
        'denominator': element.denominator,
        if (element.isFreeTime) 'isFreeTime': true,
        if (element.isAdditive)
          'additiveGroups': [
            for (final group in element.additiveGroups!) group.numerator,
          ],
      };
    }
    if (element is Barline) {
      return <String, dynamic>{
        'type': 'barline',
        'barlineType': element.type.name,
      };
    }
    if (element is Tuplet) {
      return <String, dynamic>{
        'type': 'tuplet',
        'actualNotes': element.actualNotes,
        'normalNotes': element.normalNotes,
        'elements': [
          for (final inner in element.elements) ...[
            if (_element(inner) != null) _element(inner)!,
          ],
        ],
      };
    }
    // Anything the importer cannot read back is omitted rather than written as
    // a shape that would silently vanish on re-import.
    return null;
  }

  static Map<String, dynamic> _note(Note note) => <String, dynamic>{
        'type': 'note',
        'pitch': <String, dynamic>{
          'step': note.pitch.step,
          'octave': note.pitch.octave,
          if (note.pitch.alter != 0) 'alter': note.pitch.alter,
        },
        'duration': _duration(note.duration),
        if (note.beam != null) 'beam': note.beam!.name,
        if (note.articulations.isNotEmpty)
          'articulations': [for (final a in note.articulations) a.name],
        if (note.tie != null) 'tie': note.tie!.name,
        if (note.slur != null) 'slur': note.slur!.name,
        if (note.voice != null) 'voice': note.voice,
        if (note.tremoloStrokes != 0) 'tremoloStrokes': note.tremoloStrokes,
        if (note.isGraceNote) 'isGraceNote': true,
        if (note.crossStaffMove != 0) 'crossStaffMove': note.crossStaffMove,
        if (note.tabFret != null) 'tabFret': note.tabFret,
        if (note.tabString != null) 'tabString': note.tabString,
        if (note.syllables != null && note.syllables!.isNotEmpty)
          'syllables': [
            for (final syllable in note.syllables!)
              <String, dynamic>{
                'text': syllable.text,
                'type': syllable.type.name,
                if (syllable.italic) 'italic': true,
              },
          ],
      };

  static Map<String, dynamic> _duration(Duration duration) => <String, dynamic>{
        'type': duration.type.name,
        if (duration.dots != 0) 'dots': duration.dots,
      };
}
