import '../../core/core.dart';
import 'notation_format.dart';
import 'parser_support.dart';

class NotationParser {
  static NotationFormat detectFormat(String source) {
    return detectNotationFormat(source);
  }

  /// Imports one staff from JSON, MusicXML or MEI, detecting the format when
  /// [format] is omitted.
  ///
  /// Pass [warnings] to receive the importer's diagnostics; see
  /// `MusicXMLParser.parseMusicXML`.
  static Staff parseStaff(
    String source, {
    NotationFormat? format,
    int partIndex = 0,
    int staffIndex = 0,
    List<String>? warnings,
  }) {
    return parseNotationStaff(
      source,
      format: format,
      partIndex: partIndex,
      staffIndex: staffIndex,
      warnings: warnings,
    );
  }
}
