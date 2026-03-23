import '../../core/core.dart';
import 'notation_format.dart';
import 'parser_support.dart';

class NotationParser {
  static NotationFormat detectFormat(String source) {
    return detectNotationFormat(source);
  }

  static Staff parseStaff(
    String source, {
    NotationFormat? format,
    int partIndex = 0,
    int staffIndex = 0,
  }) {
    return parseNotationStaff(
      source,
      format: format,
      partIndex: partIndex,
      staffIndex: staffIndex,
    );
  }
}
