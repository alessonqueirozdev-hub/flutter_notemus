import '../../core/core.dart';
import 'parser_support.dart';

/// Parser para converter JSON em objetos musicais.
class JsonMusicParser {
  /// Converte um JSON de partitura para um objeto [Staff].
  static Staff parseStaff(String jsonString, {int staffIndex = 0}) {
    return parseJsonStaff(jsonString, staffIndex: staffIndex);
  }
}
