import '../../core/core.dart';
import 'parser_support.dart';

/// Parser for Convertsr JSON in objects musicais.
class JsonMusicParser {
  /// Converts um JSON de partitura for um object [Staff].
  static Staff parseStaff(String jsonString, {int staffIndex = 0}) {
    return parseJsonStaff(jsonString, staffIndex: staffIndex);
  }
}
