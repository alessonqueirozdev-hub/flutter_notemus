// lib/core/staff.dart

import 'measure.dart';

/// Represents a single staff (line of music) containing an ordered list of
/// [Measure]s.
///
/// A [Staff] is the top-level musical container passed to [MusicScore] and
/// [LayoutEngine]. Measures are laid out left-to-right and wrapped into
/// systems automatically by the layout engine.
///
/// Example:
/// ```dart
/// final staff = Staff(measures: [
///   Measure()
///     ..add(Clef())
///     ..add(TimeSignature(numerator: 4, denominator: 4))
///     ..add(Note(pitch: const Pitch(step: 'C', octave: 4),
///               duration: const Duration(DurationType.quarter))),
/// ]);
/// ```
class Staff {
  /// All measures in this staff, in chronological order.
  final List<Measure> measures;

  /// Número de linhas da pauta. Padrão é 5 (CMN). Valores válidos conforme MEI:
  /// - 1: percussão / notação de linha única
  /// - 4: tablatura de 4 cordas / algumas notações históricas
  /// - 5: CMN padrão (padrão)
  /// - 6: tablatura de guitarra
  /// Corresponde ao atributo `lines` de `<staffDef>` no MEI v5.
  final int lineCount;

  /// Creates a [Staff] with the given [measures] list.
  ///
  /// [lineCount] defaults to 5 (standard CMN staff). Set to 1 for percussion,
  /// 4 for 4-string tablature, or 6 for guitar tablature.
  ///
  /// If [measures] is omitted an empty list is used, and measures can be
  /// added later via [add].
  Staff({List<Measure>? measures, this.lineCount = 5})
      : measures = measures ?? [];

  /// Appends a [Measure] to the end of this staff.
  void add(Measure measure) => measures.add(measure);
}
