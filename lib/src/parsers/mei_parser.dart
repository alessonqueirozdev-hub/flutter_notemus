import '../../core/core.dart';
import 'parser_support.dart';

/// Entry points for MEI v5 import.
///
/// [parseMEI] returns a single [Staff] — convenient, but it discards every
/// other staff of the document and the whole `<meiHead>`. [scoreFromMei]
/// returns the complete [Score]: all staves grouped as the `<staffGrp>`
/// describes, plus the header metadata (title, subtitle, composer,
/// `Score.meiHeader`).
///
/// Which import path is right depends on what you are rendering:
/// `MusicScore` takes a `Staff`, while `ScoreView`/`GrandStaff` take a `Score`.
class MEIParser {
  /// Imports one staff (default: the first) of an MEI document.
  ///
  /// Everything outside that staff — the other parts, the `<meiHead>`, the
  /// staff grouping — is dropped. Use [scoreFromMei] to keep it.
  static Staff parseMEI(String meiString, {int staffIndex = 0}) {
    return parseMeiStaff(meiString, staffIndex: staffIndex);
  }

  /// Imports a whole MEI document: every staff, the `<staffGrp>` bracketing and
  /// the `<meiHead>` metadata.
  ///
  /// Mirrors [MusicXMLParser.scoreFromMusicXML] on the MusicXML side.
  static Score scoreFromMei(String meiString) => parseMeiScore(meiString);

  /// Reads only the `<meiHead>` of a document.
  ///
  /// Useful for building a library index without paying for the full parse.
  static MeiHeader? headerFromMei(String meiString) =>
      scoreFromMei(meiString).meiHeader;
}
