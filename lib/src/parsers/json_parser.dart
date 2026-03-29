import '../../core/core.dart';
import 'parser_support.dart';

/// Parser for Convertsr JSON in objects musicais.
class JsonMusicParser {
  /// Converts a JSON de partitura for a object [Staff].
  static Staff parseStaff(String jsonString, {int staffIndex = 0}) {
    return parseJsonStaff(jsonString, staffIndex: staffIndex);
  }
}
