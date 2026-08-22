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

  /// Number of staff lines. Defaults to 5 (CMN). Valid values per MEI:
  /// - 1: percussion / single-line notation
  /// - 4: 4-string tablature / some historical notations
  /// - 5: standard CMN (default)
  /// - 6: guitar tablature
  /// Corresponds to the `lines` attribute of `<staffDef>` in MEI v5.
  final int lineCount;

  /// Creates a [Staff] with the given [measures] list.
  ///
  /// [lineCount] defaults to 5 (standard CMN staff). Set to 1 for percussion,
  /// 4 for 4-string tablature, or 6 for guitar tablature.
  ///
  /// If [measures] is omitted an empty list is used, and measures can be
  /// added later via [add].
  /// Display name of the part this staff carries, e.g. `'Violin I'`.
  ///
  /// Corresponds to MusicXML `<score-part><part-name>` and MEI
  /// `<staffDef><label>`. Null when the source did not name the part.
  final String? name;

  /// Short form used from the second system on, e.g. `'Vln. I'`
  /// (MusicXML `<part-abbreviation>`, MEI `<labelAbbr>`).
  final String? abbreviation;

  /// Written-to-sounding transposition of the instrument on this staff.
  ///
  /// Null for a concert-pitch instrument. See [Transposition] for why the
  /// notated pitch is NOT rewritten at import time.
  final Transposition? transposition;

  Staff({
    List<Measure>? measures,
    this.lineCount = 5,
    this.name,
    this.abbreviation,
    this.transposition,
  }) : measures = measures ?? [];

  /// Appends a [Measure] to the end of this staff.
  void add(Measure measure) => measures.add(measure);
}

/// Written-to-sounding transposition of a transposing instrument.
///
/// MusicXML `<transpose>`; MEI `<staffDef @trans.diat @trans.semi>`.
/// A B-flat clarinet is `Transposition(diatonic: -1, chromatic: -2)`: written
/// C4 sounds B-flat 3.
///
/// Why the pitch is not rewritten at import
/// ----------------------------------------
/// The notated pitch is what the engine draws, so it has to stay written; the
/// transposition is a property of the INSTRUMENT and is applied when the score
/// is turned into sound. Rewriting the pitches at import would produce a
/// correct-sounding, wrong-looking score.
///
/// Before 2.7.1 the declaration was parsed into `Score.metadata` and nothing
/// read it: `applyMusicXmlTransposition` existed but was never called from
/// `lib/`, `test/` or `example/`, so a B-flat clarinet part played back a major
/// second high with the information sitting inertly beside it.
class Transposition {
  /// Diatonic steps to add to the written pitch to obtain the sounding pitch.
  final int diatonic;

  /// Semitones to add to the written pitch to obtain the sounding pitch,
  /// EXCLUDING [octaveChange].
  final int chromatic;

  /// Extra octaves added on top of [chromatic].
  final int octaveChange;

  /// MusicXML `<double/>`: the part also sounds an octave lower.
  final bool doubled;

  const Transposition({
    this.diatonic = 0,
    this.chromatic = 0,
    this.octaveChange = 0,
    this.doubled = false,
  });

  /// Total semitone offset from written to sounding pitch.
  int get semitones => chromatic + (octaveChange * 12) + (doubled ? -12 : 0);

  /// True when this declaration leaves the pitch unchanged.
  bool get isConcertPitch => diatonic == 0 && semitones == 0;

  @override
  bool operator ==(Object other) =>
      other is Transposition &&
      other.diatonic == diatonic &&
      other.chromatic == chromatic &&
      other.octaveChange == octaveChange &&
      other.doubled == doubled;

  @override
  int get hashCode => Object.hash(diatonic, chromatic, octaveChange, doubled);

  @override
  String toString() =>
      'Transposition(diatonic: $diatonic, chromatic: $chromatic, '
      'octaveChange: $octaveChange, doubled: $doubled)';
}
