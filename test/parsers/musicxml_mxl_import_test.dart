// test/parsers/musicxml_mxl_import_test.dart
//
// Compressed MusicXML (`.mxl`) is what MuseScore, Finale, Sibelius and Dorico
// save by default, and nothing here could open it: every importer took a
// String. `MusicXMLParser.scoreFromBytes` takes the file's bytes and tells
// `.mxl` from plain MusicXML by its ZIP signature.
//
// The fixture pair is @zamvar's MuseScore Studio 4.7.4 reference export
// (CC0-1.0), from their fork's `codex/note-tap`: the same score saved once as
// `.mxl` and once as uncompressed `.musicxml`.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

const _dir = 'test/parsers/fixtures/musescore_4_7_4';

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, utf8.encode(entry.value)));
  }
  return ZipEncoder().encodeBytes(archive);
}

const _tinyScore = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>A</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>1</divisions>
      <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    <note><pitch><step>G</step><octave>4</octave></pitch>
      <duration>4</duration><type>whole</type></note>
  </measure></part>
</score-partwise>''';

const _container = '''<?xml version="1.0" encoding="UTF-8"?>
<container><rootfiles>
  <rootfile full-path="nested/score.xml"/>
</rootfiles></container>''';

/// Pitches of every note, bar by bar, for comparing two imports.
List<String> _signature(Score score) => [
      for (final staff in score.allStaves)
        for (final measure in staff.measures)
          [
            for (final e in measure.allElements)
              if (e is Note)
                '${e.pitch.step}${e.pitch.octave}:${e.duration.type.name}'
              else if (e is Chord)
                'chord${e.notes.length}',
          ].join(' '),
    ];

void main() {
  group('MuseScore 4.7.4 reference', () {
    final mxl = File('$_dir/notemus_reference.mxl').readAsBytesSync();
    final plain = File('$_dir/notemus_reference.musicxml').readAsBytesSync();

    test('the .mxl imports as the same score as its uncompressed twin', () {
      final fromMxl = MusicXMLParser.scoreFromBytes(mxl);
      final fromPlain = MusicXMLParser.scoreFromBytes(plain);
      final signature = _signature(fromMxl);
      expect(signature.join().trim(), isNotEmpty);
      expect(signature, _signature(fromPlain));
      expect(
        _signature(fromPlain),
        _signature(MusicXMLParser.scoreFromMusicXML(
            File('$_dir/notemus_reference.musicxml').readAsStringSync())),
      );
    });

    test('the bytes are told apart by signature, not by name', () {
      expect(MusicXMLParser.decodeBytes(mxl), startsWith('<?xml'));
      expect(MusicXMLParser.decodeBytes(mxl), contains('<score-partwise'));
      expect(MusicXMLParser.decodeBytes(plain), contains('<score-partwise'));
    });

    test('parseMusicXMLBytes imports one part', () {
      final staff = MusicXMLParser.parseMusicXMLBytes(mxl);
      expect(staff.measures, isNotEmpty);
    });
  });

  group('container', () {
    test('follows container.xml to a nested rootfile', () {
      final bytes = _zip({
        'META-INF/container.xml': _container,
        'decoy.xml': '<score-partwise version="4.0"/>',
        'nested/score.xml': _tinyScore,
      });
      final staff = MusicXMLParser.parseMusicXMLBytes(bytes);
      final note = staff.measures.single.elements.whereType<Note>().single;
      expect(note.pitch.step, 'G');
    });

    test('without a container, takes the first score outside META-INF', () {
      final bytes = _zip({'score.musicxml': _tinyScore});
      expect(MusicXMLParser.parseMusicXMLBytes(bytes).measures, hasLength(1));
    });

    test('a rootfile the archive does not hold is a FormatException', () {
      final bytes = _zip({'META-INF/container.xml': _container});
      expect(() => MusicXMLParser.decodeBytes(bytes),
          throwsA(isA<FormatException>()));
    });

    test('a container naming no rootfile is a FormatException', () {
      // Falling back to "the first .xml" here could pick a decoy over the
      // score; a container that exists but is malformed is not "no container".
      for (final container in [
        '<container><rootfiles/></container>',
        '<container><rootfiles><rootfile full-path=" "/></rootfiles></container>',
      ]) {
        final bytes = _zip({
          'META-INF/container.xml': container,
          'decoy.xml': '<score-partwise version="4.0"/>',
          'score.xml': _tinyScore,
        });
        expect(() => MusicXMLParser.decodeBytes(bytes),
            throwsA(isA<FormatException>()));
      }
    });

    test('a rootfile climbing out of the archive is refused', () {
      final bytes = _zip({
        'META-INF/container.xml':
            _container.replaceFirst('nested/score.xml', '../../etc/score.xml'),
        'score.xml': _tinyScore,
      });
      expect(() => MusicXMLParser.decodeBytes(bytes),
          throwsA(isA<FormatException>()));
    });

    test('an archive with no score is a FormatException', () {
      final bytes = _zip({'readme.txt': 'nothing here'});
      expect(() => MusicXMLParser.decodeBytes(bytes),
          throwsA(isA<FormatException>()));
    });

    test('a truncated archive is a FormatException', () {
      final bytes = _zip({'score.xml': _tinyScore});
      expect(
          () => MusicXMLParser.decodeBytes(
              Uint8List.sublistView(bytes, 0, bytes.length ~/ 2)),
          throwsA(isA<FormatException>()));
    });
  });

  group('plain text encodings', () {
    test('a UTF-8 BOM is dropped', () {
      final bytes = Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(_tinyScore)]);
      expect(MusicXMLParser.decodeBytes(bytes), startsWith('<?xml'));
    });

    test('UTF-16 with a byte-order mark is decoded, either endianness', () {
      final units = _tinyScore.codeUnits;
      final le = Uint8List.fromList([
        0xff, 0xfe,
        for (final u in units) ...[u & 0xff, u >> 8],
      ]);
      final be = Uint8List.fromList([
        0xfe, 0xff,
        for (final u in units) ...[u >> 8, u & 0xff],
      ]);
      expect(MusicXMLParser.decodeBytes(le), _tinyScore);
      expect(MusicXMLParser.decodeBytes(be), _tinyScore);
    });
  });
}
