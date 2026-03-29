// lib/core/tablature.dart

import 'musical_element.dart';
import 'duration.dart';

/// Representa a afinação de a corda in noteção de tablatura.
///
/// Correspwhere às informações de afinação in `<staffDef>` no MEI v5.
class TabString {
  /// Number of the corda (1 = mais aguda / primeira corda).
  final int number;

  /// Name of the note of the corda solta (ex.: 'E', 'A', 'D', 'G', 'B').
  final String pitchName;

  /// Oitava of the corda solta.
  final int octave;

  const TabString({
    required this.number,
    required this.pitchName,
    required this.octave,
  });
}

/// Afinação de instrumento for tablatura.
///
/// Inclui afinações pré-definidas for violão, baixo e outros instrumentos.
class TabTuning {
  /// Name of the afinação (ex.: 'Standard', 'Drop D', 'Open G').
  final String name;

  /// Cordas of the afinação, ordenadas of the mais aguda (1) for a mais grave.
  final List<TabString> strings;

  const TabTuning({required this.name, required this.strings});

  /// Afinação default de violão (E2-A2-D3-G3-B3-E4).
  static const TabTuning guitarStandard = TabTuning(
    name: 'Standard',
    strings: [
      TabString(number: 1, pitchName: 'E', octave: 4),
      TabString(number: 2, pitchName: 'B', octave: 3),
      TabString(number: 3, pitchName: 'G', octave: 3),
      TabString(number: 4, pitchName: 'D', octave: 3),
      TabString(number: 5, pitchName: 'A', octave: 2),
      TabString(number: 6, pitchName: 'E', octave: 2),
    ],
  );

  /// Afinação Drop D de violão (D2-A2-D3-G3-B3-E4).
  static const TabTuning guitarDropD = TabTuning(
    name: 'Drop D',
    strings: [
      TabString(number: 1, pitchName: 'E', octave: 4),
      TabString(number: 2, pitchName: 'B', octave: 3),
      TabString(number: 3, pitchName: 'G', octave: 3),
      TabString(number: 4, pitchName: 'D', octave: 3),
      TabString(number: 5, pitchName: 'A', octave: 2),
      TabString(number: 6, pitchName: 'D', octave: 2),
    ],
  );

  /// Afinação default de baixo de 4 cordas (E1-A1-D2-G2).
  static const TabTuning bassStandard = TabTuning(
    name: 'Bass Standard',
    strings: [
      TabString(number: 1, pitchName: 'G', octave: 2),
      TabString(number: 2, pitchName: 'D', octave: 2),
      TabString(number: 3, pitchName: 'A', octave: 1),
      TabString(number: 4, pitchName: 'E', octave: 1),
    ],
  );

  /// Afinação default de alaúde renascentista in Sol (G2-C3-F3-A3-D4-G4).
  static const TabTuning luteStandard = TabTuning(
    name: 'Lute (Renaissance G)',
    strings: [
      TabString(number: 1, pitchName: 'G', octave: 4),
      TabString(number: 2, pitchName: 'D', octave: 4),
      TabString(number: 3, pitchName: 'A', octave: 3),
      TabString(number: 4, pitchName: 'F', octave: 3),
      TabString(number: 5, pitchName: 'C', octave: 3),
      TabString(number: 6, pitchName: 'G', octave: 2),
    ],
  );
}

/// Símbolo de duração in tablatura (MEI `<tabDurSym>`).
///
/// in tablatura, a duração pode ser indicada por um símbolo separado
/// acima ou abaixo dos numbers de casa. Correspwhere ao elemento
/// `<tabDurSym>` of the MEI v5.
class TabDurSym extends MusicalElement {
  /// Duração representada por this símbolo.
  final Duration duration;

  /// Indica se o símbolo é exibido acima (default) ou abaixo das cordas.
  final bool above;

  TabDurSym({required this.duration, this.above = true});
}

/// Representa a note in tablatura, correspwherendo ao elemento `<note>`
/// with atributos `@tab.fret` e `@tab.string` no MEI v5.
///
/// ```dart
/// TabNote(string: 1, fret: 0)   // primeira corda solta
/// TabNote(string: 3, fret: 2)   // terceira corda, 2ª casa
/// TabNote(string: 6, fret: 5)   // sexta corda, 5ª casa
/// ```
class TabNote extends MusicalElement {
  /// Number of the corda (1 = mais aguda). MEI `@tab.string`.
  final int string;

  /// Casa (fret). 0 = corda solta. MEI `@tab.fret`.
  final int fret;

  /// Duração of the note de tablatura.
  final Duration? duration;

  /// Indica se this note é harmonics (toque levemente a corda).
  final bool isHarmonic;

  /// Indica se há mudo (x) nesta corda.
  final bool isMuted;

  TabNote({
    required this.string,
    required this.fret,
    this.duration,
    this.isHarmonic = false,
    this.isMuted = false,
  });
}

/// Grupo de notes simultâneas in tablatura (MEI `<tabGrp>`).
///
/// Equivale a um chord in noteção convencional, mas representado como
/// numbers de casa in múltiplas cordas simultaneamente.
///
/// ```dart
/// TabGrp(
///   notes: [
///     TabNote(string: 1, fret: 0),
///     TabNote(string: 2, fret: 1),
///     TabNote(string: 3, fret: 2),
///   ],
///   duration: Duration(DurationType.quarter),
/// )
/// ```
class TabGrp extends MusicalElement {
  /// Notes of the grupo (a por corda).
  final List<TabNote> notes;

  /// Duração of the grupo.
  final Duration duration;

  TabGrp({required this.notes, required this.duration});
}
