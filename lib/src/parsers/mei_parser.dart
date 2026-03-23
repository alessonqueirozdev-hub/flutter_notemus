import '../../core/core.dart';
import 'parser_support.dart';

class MEIParser {
  static Staff parseMEI(String meiString, {int staffIndex = 0}) {
    return parseMeiStaff(meiString, staffIndex: staffIndex);
  }
}
