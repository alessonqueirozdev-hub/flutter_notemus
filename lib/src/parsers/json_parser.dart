import '../../core/core.dart';
import 'json_exporter.dart';
import 'parser_support.dart';

export 'json_exporter.dart' show JsonMusicExporter;

/// Parser for Convertsr JSON in objects musicais.
class JsonMusicParser {
  /// Converts a JSON de partitura for a object [Staff].
  ///
  /// Pass [warnings] to receive the importer's diagnostics, same shape as
  /// `MusicXMLParser.parseMusicXML` and `PdfExporter.warnings`.
  static Staff parseStaff(
    String jsonString, {
    int staffIndex = 0,
    List<String>? warnings,
  }) {
    return parseJsonStaff(
      jsonString,
      staffIndex: staffIndex,
      warnings: warnings,
    );
  }

  /// Serialises [staff] back to the shape [parseStaff] reads.
  ///
  /// The package had no JSON writer at all, so a JSON round trip could not even
  /// be attempted. `parseStaff(staffToJson(s))` now preserves the model.
  static String staffToJson(Staff staff, {bool pretty = true}) =>
      JsonMusicExporter.staffToJson(staff, pretty: pretty);

  /// Serialises a whole [Score] (`{"staves": [...]}`).
  static String scoreToJson(Score score, {bool pretty = true}) =>
      JsonMusicExporter.scoreToJson(score, pretty: pretty);
}
