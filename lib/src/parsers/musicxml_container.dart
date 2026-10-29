// lib/src/parsers/musicxml_container.dart
//
// Compressed MusicXML (`.mxl`) is the format MuseScore, Finale, Sibelius and
// Dorico save and share by default: a ZIP archive whose
// `META-INF/container.xml` names the score file inside it. Every importer here
// took a String, so a `.mxl` could not be opened at all without unpacking it by
// hand first.
//
// Ported from @zamvar's fork (`codex/note-tap`, `NotemusDocument.fromBytes`).

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Decodes the bytes of a MusicXML file — compressed `.mxl` or plain
/// `.musicxml` / `.xml` — into the MusicXML text the importers read.
///
/// A ZIP signature selects the `.mxl` path: the score is the `rootfile` named
/// by `META-INF/container.xml`, or, when an archive has no container, its
/// first `.xml` / `.musicxml` entry outside `META-INF/`. Plain bytes are
/// decoded as UTF-8, or as UTF-16 when they start with a UTF-16 byte-order
/// mark; a leading UTF-8 BOM is dropped.
///
/// Throws a [FormatException] for a corrupt archive, a container that names a
/// file the archive does not hold, or an archive with no score in it.
String decodeMusicXmlBytes(List<int> bytes) {
  if (isCompressedMusicXml(bytes)) return _extractScore(bytes);
  return _decodeText(bytes);
}

/// Whether [bytes] start with a ZIP signature, i.e. are a `.mxl` container
/// rather than plain MusicXML text.
bool isCompressedMusicXml(List<int> bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x50 &&
    bytes[1] == 0x4b &&
    ((bytes[2] == 0x03 && bytes[3] == 0x04) ||
        (bytes[2] == 0x05 && bytes[3] == 0x06) ||
        (bytes[2] == 0x07 && bytes[3] == 0x08));

String _extractScore(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes, verify: true);
  } on Object catch (error) {
    throw FormatException('Invalid compressed MusicXML archive: $error');
  }

  final files = <String, ArchiveFile>{
    for (final file in archive.where((entry) => entry.isFile))
      _normalizePath(file.name): file,
  };

  String? rootPath;
  final container = files.entries
      .where((entry) => entry.key.toLowerCase() == 'meta-inf/container.xml')
      .firstOrNull
      ?.value;
  if (container != null) {
    try {
      rootPath = XmlDocument.parse(_decodeText(container.content))
          .findAllElements('rootfile')
          .firstOrNull
          ?.getAttribute('full-path');
    } on Object catch (error) {
      throw FormatException('Invalid MXL container.xml: $error');
    }
  }

  ArchiveFile? score;
  if (rootPath != null && rootPath.trim().isNotEmpty) {
    score = files[_normalizePath(rootPath)];
    if (score == null) {
      throw FormatException(
        'MXL rootfile does not exist in the archive: $rootPath',
      );
    }
  } else {
    score = files.entries
        .where((entry) {
          final path = entry.key.toLowerCase();
          return !path.startsWith('meta-inf/') &&
              (path.endsWith('.xml') || path.endsWith('.musicxml'));
        })
        .firstOrNull
        ?.value;
  }
  if (score == null) {
    throw const FormatException(
      'MXL archive does not contain a MusicXML score.',
    );
  }
  return _decodeText(score.content);
}

/// Normalises an archive entry name so `container.xml`'s `full-path` matches
/// it: forward slashes, no `.` segments, and `..` resolved — refusing one that
/// climbs out of the archive root.
String _normalizePath(String path) {
  final segments = <String>[];
  for (final segment in path.replaceAll(r'\', '/').split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) {
        throw FormatException('Archive path escapes its root: $path');
      }
      segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/');
}

String _decodeText(List<int> bytes) {
  final bool littleEndian =
      bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe;
  final bool bigEndian =
      bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff;
  if (littleEndian || bigEndian) {
    final codeUnits = <int>[
      for (var i = 2; i + 1 < bytes.length; i += 2)
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
    ];
    return String.fromCharCodes(codeUnits);
  }
  final text = utf8.decode(bytes);
  return text.startsWith('﻿') ? text.substring(1) : text;
}
